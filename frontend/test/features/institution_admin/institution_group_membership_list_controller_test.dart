import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_list_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_membership_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_repository.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'Teacher and Student list owners load independently for active or archived Group',
    () async {
      final repository = _FakeMembershipRepository();
      final container = _container(repository);
      final teacher = _listen(container, InstitutionGroupMemberKind.teacher);
      final student = _listen(container, InstitutionGroupMemberKind.student);
      await _flush();

      expect(repository.fetches, hasLength(2));
      expect(repository.fetches.map((call) => call.kind).toSet(), {
        InstitutionGroupMemberKind.teacher,
        InstitutionGroupMemberKind.student,
      });
      expect(teacher.read().status, InstitutionGroupMembershipListStatus.data);
      expect(student.read().status, InstitutionGroupMembershipListStatus.data);

      final archivedRepository = _FakeMembershipRepository();
      final archived = _container(
        archivedRepository,
        group: testGroup(
          status: InstitutionGroupStatus.archived,
          archivedAt: DateTime.utc(2026, 8, 21),
        ),
      );
      final archivedTeacher = _listen(
        archived,
        InstitutionGroupMemberKind.teacher,
      );
      await _flush();
      expect(
        archivedTeacher.read().status,
        InstitutionGroupMembershipListStatus.data,
      );
    },
  );

  test(
    'exact debounce pending actions invalid draft and clear follow query contract',
    () async {
      final repository = _FakeMembershipRepository();
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      await _flush();
      final controller = container.read(
        institutionGroupMembershipListControllerProvider(
          _key(InstitutionGroupMemberKind.teacher),
        ).notifier,
      );

      controller.updateSearchDraft('  Ali % _  ');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(repository.fetches, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(repository.fetches.last.query.search, 'Ali % _');

      controller.updateSearchDraft('Merged');
      controller.setStatus(InstitutionGroupMembershipStatusFilter.inactive);
      await _flush();
      expect(repository.fetches.last.query.search, 'Merged');
      expect(
        repository.fetches.last.query.status,
        InstitutionGroupMembershipStatusFilter.inactive,
      );
      final beforeInvalid = repository.fetches.length;
      controller.updateSearchDraft(List.filled(255, '😀').join());
      controller.commitSearchNow();
      controller.toggleSort(InstitutionGroupMembershipSort.startedAt);
      controller.setPerPage(50);
      controller.nextPage();
      controller.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repository.fetches, hasLength(beforeInvalid));
      expect(
        subscription.read().searchErrorText,
        'Search must be 254 characters or fewer.',
      );
      controller.clearFilters();
      await _flush();
      expect(subscription.read().searchErrorText, isNull);
      expect(subscription.read().query.search, isNull);
      expect(subscription.read().query.status, isNull);
    },
  );

  test(
    'one empty page correction preserves query and never corrects twice',
    () async {
      var correction = false;
      final repository = _FakeMembershipRepository(
        onFetch: (kind, query) async {
          if (query.page == 2 && !correction) {
            correction = true;
            return _page(
              kind,
              query,
              memberships: const [],
              total: 21,
              lastPage: 2,
            );
          }
          if (correction && query.page == 1) {
            return _page(
              kind,
              query,
              memberships: const [],
              total: 21,
              lastPage: 2,
            );
          }
          return _page(kind, query, total: 21, lastPage: 2);
        },
      );
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      await _flush();
      final controller = container.read(
        institutionGroupMembershipListControllerProvider(
          _key(InstitutionGroupMemberKind.teacher),
        ).notifier,
      );
      controller.nextPage();
      await _flush();
      expect(repository.fetches.map((call) => call.query.page), [1, 2, 1]);
      expect(subscription.read().query.page, 1);
      expect(
        subscription.read().status,
        InstitutionGroupMembershipListStatus.emptyPage,
      );
    },
  );

  test(
    'mutation checking discards stale rows on read failure and Retry is exact',
    () async {
      var fail = false;
      final repository = _FakeMembershipRepository(
        onFetch: (kind, query) async {
          if (fail) {
            fail = false;
            throw ApiRequestException(
              ApiFailure.local(
                kind: ApiFailureKind.connection,
                message: 'private',
              ),
            );
          }
          return _page(kind, query);
        },
      );
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      await _flush();
      final controller = container.read(
        institutionGroupMembershipListControllerProvider(
          _key(InstitutionGroupMemberKind.teacher),
        ).notifier,
      );
      final query = subscription.read().query;
      fail = true;
      controller.markCheckingAndReload();
      expect(
        subscription.read().status,
        InstitutionGroupMembershipListStatus.checkingCurrentState,
      );
      expect(subscription.read().result, isNotNull);
      await _flush();
      expect(
        subscription.read().status,
        InstitutionGroupMembershipListStatus.error,
      );
      expect(subscription.read().result, isNull);
      controller.retry();
      await _flush();
      expect(repository.fetches.last.query, query);
      expect(
        subscription.read().status,
        InstitutionGroupMembershipListStatus.data,
      );
    },
  );

  test(
    'new query supersedes stale completion and disposed owner cannot publish',
    () async {
      final first = Completer<InstitutionGroupMembershipListPage>();
      final second = Completer<InstitutionGroupMembershipListPage>();
      final repository = _FakeMembershipRepository();
      repository.onFetch = (kind, query) =>
          repository.fetches.length == 1 ? first.future : second.future;
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      await _flush();
      final controller = container.read(
        institutionGroupMembershipListControllerProvider(
          _key(InstitutionGroupMemberKind.teacher),
        ).notifier,
      );
      controller.updateSearchDraft('new');
      controller.commitSearchNow();
      await _flush();
      second.complete(
        _page(
          InstitutionGroupMemberKind.teacher,
          repository.fetches.last.query,
          membership: testMembership(fullName: 'New'),
        ),
      );
      await _flush();
      first.completeError(StateError('stale'));
      await _flush();
      expect(subscription.read().result!.memberships.single.fullName, 'New');

      subscription.close();
      await _flush();
    },
  );
}

ProviderContainer _container(
  _FakeMembershipRepository repository, {
  InstitutionGroup? group,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(TestAuthSessionController.new),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionGroupDetailRepositoryProvider.overrideWithValue(
        _FakeDetailRepository(group ?? testGroup()),
      ),
      institutionGroupMembershipRepositoryProvider.overrideWithValue(
        repository,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<InstitutionGroupMembershipListState> _listen(
  ProviderContainer container,
  InstitutionGroupMemberKind kind,
) {
  final subscription = container.listen(
    institutionGroupMembershipListControllerProvider(_key(kind)),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return subscription;
}

InstitutionGroupMembershipListKey _key(InstitutionGroupMemberKind kind) =>
    InstitutionGroupMembershipListKey(groupId: testGroupId, kind: kind);

Future<void> _flush() async {
  for (var index = 0; index < 6; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

InstitutionGroupMembershipListPage _page(
  InstitutionGroupMemberKind kind,
  InstitutionGroupMembershipQuery query, {
  InstitutionGroupMembership? membership,
  List<InstitutionGroupMembership>? memberships,
  int total = 1,
  int lastPage = 1,
}) => InstitutionGroupMembershipListPage(
  memberships:
      memberships ??
      [
        membership ??
            testMembership(
              id: kind == InstitutionGroupMemberKind.teacher
                  ? testTeacherId
                  : testStudentId,
              fullName: kind.singularTitle,
            ),
      ],
  pagination: InstitutionGroupMembershipListPagination(
    page: query.page,
    perPage: query.perPage,
    total: total,
    lastPage: lastPage,
  ),
);

class _FakeDetailRepository implements InstitutionGroupDetailRepository {
  _FakeDetailRepository(this.group);
  final InstitutionGroup group;

  @override
  Future<InstitutionGroup> fetchGroup(String groupId) async => group;
}

class _MembershipFetch {
  const _MembershipFetch(this.kind, this.query);
  final InstitutionGroupMemberKind kind;
  final InstitutionGroupMembershipQuery query;
}

class _FakeMembershipRepository
    implements InstitutionGroupMembershipRepository {
  _FakeMembershipRepository({this.onFetch});

  Future<InstitutionGroupMembershipListPage> Function(
    InstitutionGroupMemberKind kind,
    InstitutionGroupMembershipQuery query,
  )?
  onFetch;
  final fetches = <_MembershipFetch>[];

  @override
  Future<InstitutionGroupMembershipListPage> fetchMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipQuery query,
  }) {
    fetches.add(_MembershipFetch(kind, query));
    return onFetch?.call(kind, query) ?? Future.value(_page(kind, query));
  }

  @override
  Future<List<InstitutionGroupMembership>> assignMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipAssignmentRequest request,
  }) => throw UnimplementedError();

  @override
  Future<void> removeMembership({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required String memberId,
  }) => throw UnimplementedError();
}
