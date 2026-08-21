import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_detail_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_candidate_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_candidate_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_membership_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'uses exact fixed User query without touching Users retained state',
    () async {
      final repository = _FakeUserRepository();
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      await _open(container, InstitutionGroupMemberKind.teacher);

      final query = repository.queries.single;
      expect(query.role, InstitutionUserRole.teacher);
      expect(query.status, InstitutionUserStatusFilter.active);
      expect(query.sort, InstitutionUserListSort.fullName);
      expect(query.direction, InstitutionUserSortDirection.asc);
      expect(query.perPage, 20);
      expect(
        subscription.read().status,
        InstitutionGroupMembershipCandidateStatus.data,
      );
      expect(
        container.read(institutionUserListRetainedQueryProvider).value,
        isNull,
      );
    },
  );

  test(
    'rejects wrong-role inactive or duplicate purpose rows as invalidResponse',
    () async {
      for (final users in <List<InstitutionUser>>[
        [testCandidate(role: InstitutionUserRole.student)],
        [testCandidate(isActive: false)],
        [
          testCandidate(id: testGroupIdUpper),
          testCandidate(id: testGroupIdUpper.toLowerCase()),
        ],
      ]) {
        final repository = _FakeUserRepository(
          onFetch: (query) async =>
              _page(query, users: users, total: users.length),
        );
        final container = _container(repository);
        final subscription = _listen(
          container,
          InstitutionGroupMemberKind.teacher,
        );
        await _open(container, InstitutionGroupMemberKind.teacher);
        expect(
          subscription.read().status,
          InstitutionGroupMembershipCandidateStatus.error,
        );
        expect(
          subscription.read().failure?.kind,
          ApiFailureKind.invalidResponse,
        );
      }
    },
  );

  test('300 ms search Retry and one correction preserve selection', () async {
    var fail = false;
    final repository = _FakeUserRepository(
      onFetch: (query) async {
        if (fail) {
          fail = false;
          throw StateError('candidate failure');
        }
        if (query.page == 2) {
          return _page(query, users: const [], total: 21, lastPage: 2);
        }
        return _page(query, total: 21, lastPage: 2);
      },
    );
    final container = _container(repository);
    final subscription = _listen(container, InstitutionGroupMemberKind.teacher);
    await _open(container, InstitutionGroupMemberKind.teacher);
    final controller = _controller(
      container,
      InstitutionGroupMemberKind.teacher,
    );
    controller.toggleSelection(subscription.read().result!.users.single, true);

    controller.updateSearchDraft('  Search % _  ');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(repository.queries, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 130));
    expect(repository.queries.last.search, 'Search % _');
    expect(subscription.read().selected, hasLength(1));

    controller.nextPage();
    await _flush();
    expect(
      repository.queries.map((query) => query.page).toList(),
      containsAllInOrder([2, 1]),
    );
    expect(subscription.read().selected, hasLength(1));

    fail = true;
    controller.updateSearchDraft('failure');
    controller.commitSearchNow();
    await _flush();
    expect(
      subscription.read().status,
      InstitutionGroupMembershipCandidateStatus.error,
    );
    expect(subscription.read().selected, hasLength(1));
    final failed = subscription.read().query;
    controller.retry();
    await _flush();
    expect(repository.queries.last, failed);
    expect(subscription.read().selected, hasLength(1));
  });

  test(
    'ordered cross-page selection tray supports off-page removal and max 100',
    () async {
      final repository = _FakeUserRepository(
        onFetch: (query) async => _page(
          query,
          users: List.generate(
            query.page <= 5 ? 20 : 1,
            (index) => testCandidate(
              id: _candidateId((query.page - 1) * 20 + index + 1),
              fullName: 'Candidate ${(query.page - 1) * 20 + index + 1}',
              loginName: 'candidate.${(query.page - 1) * 20 + index + 1}',
            ),
          ),
          total: 101,
          lastPage: 6,
        ),
      );
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      await _open(container, InstitutionGroupMemberKind.teacher);
      final controller = _controller(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      final first = subscription.read().result!.users.first;
      for (var page = 1; page <= 5; page += 1) {
        for (final user in subscription.read().result!.users) {
          controller.toggleSelection(user, true);
        }
        if (page < 5) {
          controller.nextPage();
          await _flush();
        }
      }
      expect(subscription.read().selected, hasLength(100));
      expect(subscription.read().selected.first.id, first.id);
      controller.nextPage();
      await _flush();
      controller.toggleSelection(
        subscription.read().result!.users.single,
        true,
      );
      expect(subscription.read().selected, hasLength(100));
      controller.removeSelected(first);
      expect(subscription.read().selected, hasLength(99));
      expect(
        subscription.read().selected.any((user) => user.id == first.id),
        isFalse,
      );
    },
  );

  test(
    'close and authoritative Group object replacement destroy query and selection',
    () async {
      final pending = Completer<InstitutionUserListPage>();
      final repository = _FakeUserRepository(onFetch: (_) => pending.future);
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      await _openWithoutWaiting(container, InstitutionGroupMemberKind.teacher);
      final selected = container
          .read(institutionGroupDetailControllerProvider(testGroupId))
          .group!;
      final replacement = testGroup(name: 'Replacement');
      expect(
        container
            .read(
              institutionGroupDetailControllerProvider(testGroupId).notifier,
            )
            .replaceFromMutation(selected, replacement),
        isTrue,
      );
      await _flush();
      expect(
        subscription.read().status,
        InstitutionGroupMembershipCandidateStatus.closed,
      );
      expect(subscription.read().selected, isEmpty);
      pending.complete(_page(const InstitutionUserListQuery.initial()));
      await _flush();
      expect(
        subscription.read().status,
        InstitutionGroupMembershipCandidateStatus.closed,
      );
    },
  );

  test(
    'new candidate search supersedes an older in-flight completion',
    () async {
      final first = Completer<InstitutionUserListPage>();
      final second = Completer<InstitutionUserListPage>();
      var calls = 0;
      final repository = _FakeUserRepository(
        onFetch: (_) {
          calls += 1;
          return calls == 1 ? first.future : second.future;
        },
      );
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      await _openWithoutWaiting(container, InstitutionGroupMemberKind.teacher);
      final controller = _controller(
        container,
        InstitutionGroupMemberKind.teacher,
      );
      controller.updateSearchDraft('new query');
      controller.commitSearchNow();
      await _flush();
      second.complete(
        _page(
          repository.queries.last,
          users: [testCandidate(fullName: 'New Candidate')],
        ),
      );
      await _flush();
      first.complete(
        _page(
          repository.queries.first,
          users: [testCandidate(fullName: 'Old Candidate')],
        ),
      );
      await _flush();

      expect(
        subscription.read().result!.users.single.fullName,
        'New Candidate',
      );
      expect(subscription.read().query!.search, 'new query');
    },
  );
}

ProviderContainer _container(_FakeUserRepository repository) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(TestAuthSessionController.new),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionGroupDetailRepositoryProvider.overrideWithValue(
        _FakeDetailRepository(),
      ),
      institutionUserListRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<InstitutionGroupMembershipCandidateState> _listen(
  ProviderContainer container,
  InstitutionGroupMemberKind kind,
) {
  final subscription = container.listen(
    institutionGroupMembershipCandidateControllerProvider(_key(kind)),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return subscription;
}

Future<void> _open(
  ProviderContainer container,
  InstitutionGroupMemberKind kind,
) async {
  await _openWithoutWaiting(container, kind);
  await _flush();
}

Future<void> _openWithoutWaiting(
  ProviderContainer container,
  InstitutionGroupMemberKind kind,
) async {
  await _flush();
  final group = container
      .read(institutionGroupDetailControllerProvider(testGroupId))
      .group!;
  expect(_controller(container, kind).open(group), isTrue);
}

InstitutionGroupMembershipCandidateController _controller(
  ProviderContainer container,
  InstitutionGroupMemberKind kind,
) => container.read(
  institutionGroupMembershipCandidateControllerProvider(_key(kind)).notifier,
);

InstitutionGroupMembershipListKey _key(InstitutionGroupMemberKind kind) =>
    InstitutionGroupMembershipListKey(groupId: testGroupId, kind: kind);

Future<void> _flush() async {
  for (var index = 0; index < 6; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

String _candidateId(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

InstitutionUserListPage _page(
  InstitutionUserListQuery query, {
  List<InstitutionUser>? users,
  int total = 1,
  int lastPage = 1,
}) => InstitutionUserListPage(
  users: users ?? [testCandidate()],
  pagination: InstitutionUserListPagination(
    page: query.page,
    perPage: query.perPage,
    total: total,
    lastPage: lastPage,
  ),
);

class _FakeDetailRepository implements InstitutionGroupDetailRepository {
  @override
  Future<InstitutionGroup> fetchGroup(String groupId) async => testGroup();
}

class _FakeUserRepository implements InstitutionUserListRepository {
  _FakeUserRepository({this.onFetch});

  Future<InstitutionUserListPage> Function(InstitutionUserListQuery query)?
  onFetch;
  final queries = <InstitutionUserListQuery>[];

  @override
  Future<InstitutionUserListPage> fetchUsers(InstitutionUserListQuery query) {
    queries.add(query);
    return onFetch?.call(query) ?? Future.value(_page(query));
  }
}
