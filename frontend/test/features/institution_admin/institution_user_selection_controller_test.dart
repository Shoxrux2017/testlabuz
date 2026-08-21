import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_selection_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_selection_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_selection.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  test(
    'anchors are all-status and connect selectors are active-only',
    () async {
      for (final purpose in InstitutionUserSelectionPurpose.values) {
        final repository = _FakeUserRepository();
        final container = _container(repository);
        final subscription = _listen(container, purpose);
        final controller = _controller(container, purpose);
        expect(controller.open(), isTrue);
        await _flush();
        final query = repository.queries.single;
        expect(query.role, purpose.role);
        expect(
          query.status,
          purpose.activeOnly ? InstitutionUserStatusFilter.active : null,
        );
        expect(query.sort, InstitutionUserListSort.fullName);
        expect(query.direction, InstitutionUserSortDirection.asc);
        expect(query.perPage, 20);
        expect(subscription.read().status, InstitutionUserSelectionStatus.data);
        expect(
          container.read(institutionUserListRetainedQueryProvider).value,
          isNull,
        );
      }
    },
  );

  test(
    'wrong role inactive active-purpose and duplicate IDs fail whole page',
    () async {
      for (final users in <List<InstitutionUser>>[
        [testInstitutionUser(role: InstitutionUserRole.student)],
        [testInstitutionUser(isActive: false)],
        [
          testInstitutionUser(),
          testInstitutionUser(id: testParentId.toUpperCase()),
        ],
      ]) {
        final repository = _FakeUserRepository(
          onFetch: (query) async => _page(query, users: users),
        );
        final container = _container(repository);
        final subscription = _listen(
          container,
          InstitutionUserSelectionPurpose.activeParent,
        );
        _controller(
          container,
          InstitutionUserSelectionPurpose.activeParent,
        ).open();
        await _flush();
        expect(
          subscription.read().status,
          InstitutionUserSelectionStatus.error,
        );
        expect(
          subscription.read().failure?.kind,
          ApiFailureKind.invalidResponse,
        );
      }
    },
  );

  test(
    'search debounce correction Retry and selection persistence are exact',
    () async {
      var fail = false;
      final repository = _FakeUserRepository(
        onFetch: (query) async {
          if (fail) {
            fail = false;
            throw StateError('failure');
          }
          if (query.page == 2) {
            return _page(query, users: const [], total: 21, lastPage: 2);
          }
          return _page(query, total: 21, lastPage: 2);
        },
      );
      final container = _container(repository);
      final purpose = InstitutionUserSelectionPurpose.activeParent;
      final subscription = _listen(container, purpose);
      final controller = _controller(container, purpose);
      controller.open();
      await _flush();
      final selected = subscription.read().result!.users.single;
      controller.select(selected);

      controller.updateSearchDraft('  Search % _  ');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(repository.queries, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(repository.queries.last.search, 'Search % _');
      expect(subscription.read().selected, same(selected));

      controller.nextPage();
      await _flush();
      expect(
        repository.queries.map((query) => query.page),
        containsAllInOrder([2, 1]),
      );
      expect(subscription.read().selected, same(selected));

      fail = true;
      controller.updateSearchDraft('failure');
      controller.commitSearchNow();
      await _flush();
      final failedQuery = subscription.read().query;
      expect(subscription.read().status, InstitutionUserSelectionStatus.error);
      controller.retry();
      await _flush();
      expect(repository.queries.last, failedQuery);
      expect(subscription.read().selected, same(selected));
    },
  );
}

ProviderContainer _container(_FakeUserRepository repository) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(TestAuthSessionController.new),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionUserListRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<InstitutionUserSelectionState> _listen(
  ProviderContainer container,
  InstitutionUserSelectionPurpose purpose,
) {
  final subscription = container.listen(
    institutionUserSelectionControllerProvider(purpose),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return subscription;
}

InstitutionUserSelectionController _controller(
  ProviderContainer container,
  InstitutionUserSelectionPurpose purpose,
) => container.read(
  institutionUserSelectionControllerProvider(purpose).notifier,
);

Future<void> _flush() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

InstitutionUserListPage _page(
  InstitutionUserListQuery query, {
  List<InstitutionUser>? users,
  int? total,
  int lastPage = 1,
}) {
  final values = users ?? [testInstitutionUser()];
  return InstitutionUserListPage(
    users: values,
    pagination: InstitutionUserListPagination(
      page: query.page,
      perPage: query.perPage,
      total: total ?? values.length,
      lastPage: lastPage,
    ),
  );
}

class _FakeUserRepository implements InstitutionUserListRepository {
  _FakeUserRepository({this.onFetch});

  final Future<InstitutionUserListPage> Function(
    InstitutionUserListQuery query,
  )?
  onFetch;
  final queries = <InstitutionUserListQuery>[];

  @override
  Future<InstitutionUserListPage> fetchUsers(InstitutionUserListQuery query) {
    queries.add(query);
    final role = query.role ?? InstitutionUserRole.parent;
    final fallback = role == InstitutionUserRole.student
        ? testInstitutionUser(
            id: testStudentId,
            role: role,
            fullName: 'Student One',
            loginName: 'student.one',
          )
        : testInstitutionUser(role: role);
    return onFetch?.call(query) ??
        Future.value(_page(query, users: [fallback]));
  }
}
