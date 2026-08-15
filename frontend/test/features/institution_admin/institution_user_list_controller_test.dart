import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_list_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';

void main() {
  group('InstitutionUserListController', () {
    test('eligible Admin loads once and classifies result states', () async {
      final repository = _FakeUserListRepository();
      final container = _container(repository: repository);
      final subscription = _listen(container);

      await _flush();

      expect(repository.fetchCalls, 1);
      expect(
        repository.queries.single,
        const InstitutionUserListQuery.initial(),
      );
      expect(subscription.read().status, InstitutionUserListStatus.data);
      container.read(institutionUserListControllerProvider);
      expect(repository.fetchCalls, 1);

      expect(
        InstitutionUserListState.fromResult(
          query: const InstitutionUserListQuery.initial(),
          searchDraft: '',
          result: _page(rows: const [], total: 0),
        ).status,
        InstitutionUserListStatus.globalEmpty,
      );
      expect(
        InstitutionUserListState.fromResult(
          query: const InstitutionUserListQuery.initial().withRole(
            InstitutionUserRole.teacher,
          ),
          searchDraft: '',
          result: _page(rows: const [], total: 0),
        ).status,
        InstitutionUserListStatus.filteredEmpty,
      );
      expect(
        InstitutionUserListState.fromResult(
          query: const InstitutionUserListQuery.initial().copyWith(page: 2),
          searchDraft: '',
          result: _page(rows: const [], page: 2, total: 21, lastPage: 2),
        ).status,
        InstitutionUserListStatus.emptyPage,
      );
    });

    test(
      '300 ms debounce, Enter, pending merge, and invalid blocking are exact',
      () async {
        final repository = _FakeUserListRepository();
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await _flush();
        final controller = container.read(
          institutionUserListControllerProvider.notifier,
        );

        controller.updateSearchDraft('  Ali  ');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(repository.fetchCalls, 1);
        await Future<void>.delayed(const Duration(milliseconds: 140));
        expect(repository.fetchCalls, 2);
        expect(repository.queries.last.search, 'Ali');

        controller.updateSearchDraft('  Vali % _  ');
        controller.commitSearchNow();
        await _flush();
        expect(repository.fetchCalls, 3);
        expect(repository.queries.last.search, 'Vali % _');
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repository.fetchCalls, 3);

        controller.updateSearchDraft('Merged');
        controller.setRole(InstitutionUserRole.student);
        await _flush();
        expect(repository.fetchCalls, 4);
        expect(repository.queries.last.search, 'Merged');
        expect(repository.queries.last.role, InstitutionUserRole.student);

        controller.updateSearchDraft(List.filled(255, '😀').join());
        controller.setStatus(InstitutionUserStatusFilter.inactive);
        controller.toggleSort(InstitutionUserListSort.createdAt);
        controller.setPerPage(50);
        controller.refresh();
        controller.nextPage();
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repository.fetchCalls, 4);
        expect(subscription.read().searchErrorText, contains('254'));

        controller.clearFilters();
        await _flush();
        expect(repository.fetchCalls, 5);
        expect(repository.queries.last.search, isNull);
        expect(repository.queries.last.role, isNull);
        expect(repository.queries.last.status, isNull);
        expect(subscription.read().searchErrorText, isNull);
      },
    );

    test(
      'filter sort size and pagination serialize approved transitions',
      () async {
        final repository = _FakeUserListRepository(
          onFetch: (query) async => _page(
            page: query.page,
            perPage: query.perPage,
            total: query.perPage * 3,
            lastPage: 3,
          ),
        );
        final container = _container(repository: repository);
        _listen(container);
        await _flush();
        final controller = container.read(
          institutionUserListControllerProvider.notifier,
        );

        controller.setStatus(InstitutionUserStatusFilter.inactive);
        await _flush();
        controller.setRole(InstitutionUserRole.parent);
        await _flush();
        controller.toggleSort(InstitutionUserListSort.loginName);
        await _flush();
        controller.toggleSort(InstitutionUserListSort.loginName);
        await _flush();
        controller.setPerPage(50);
        await _flush();
        controller.nextPage();
        await _flush();
        controller.previousPage();
        await _flush();

        expect(repository.queries.map((query) => query.toQueryParameters()), [
          {'page': 1, 'per_page': 20, 'sort': 'full_name', 'direction': 'asc'},
          {
            'page': 1,
            'per_page': 20,
            'sort': 'full_name',
            'direction': 'asc',
            'status': 'inactive',
          },
          {
            'page': 1,
            'per_page': 20,
            'sort': 'full_name',
            'direction': 'asc',
            'role': 'parent',
            'status': 'inactive',
          },
          {
            'page': 1,
            'per_page': 20,
            'sort': 'login_name',
            'direction': 'asc',
            'role': 'parent',
            'status': 'inactive',
          },
          {
            'page': 1,
            'per_page': 20,
            'sort': 'login_name',
            'direction': 'desc',
            'role': 'parent',
            'status': 'inactive',
          },
          {
            'page': 1,
            'per_page': 50,
            'sort': 'login_name',
            'direction': 'desc',
            'role': 'parent',
            'status': 'inactive',
          },
          {
            'page': 2,
            'per_page': 50,
            'sort': 'login_name',
            'direction': 'desc',
            'role': 'parent',
            'status': 'inactive',
          },
          {
            'page': 1,
            'per_page': 50,
            'sort': 'login_name',
            'direction': 'desc',
            'role': 'parent',
            'status': 'inactive',
          },
        ]);
      },
    );

    test(
      'latest query completion wins and old success or error is ignored',
      () async {
        final first = Completer<InstitutionUserListPage>();
        final second = Completer<InstitutionUserListPage>();
        final repository = _FakeUserListRepository(
          onFetch: (_) => throw StateError('handler replaced below'),
        );
        repository.onFetch = (_) =>
            repository.fetchCalls == 1 ? first.future : second.future;
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await _flush();

        final controller = container.read(
          institutionUserListControllerProvider.notifier,
        );
        controller.updateSearchDraft('New');
        controller.commitSearchNow();
        await _flush();
        expect(
          subscription.read().status,
          InstitutionUserListStatus.queryLoading,
        );
        expect(subscription.read().result, isNull);

        second.complete(_page(label: 'New'));
        await _flush();
        expect(subscription.read().result?.users.single.fullName, 'New User');
        first.completeError(_localFailure(ApiFailureKind.connection));
        await _flush();
        expect(subscription.read().status, InstitutionUserListStatus.data);
        expect(subscription.read().result?.users.single.fullName, 'New User');
      },
    );

    test(
      'per logical query performs only one bounded empty-page correction',
      () async {
        final repository = _FakeUserListRepository();
        repository.onFetch = (query) async {
          if (query.page == 3) {
            return _page(rows: const [], page: 3, total: 41, lastPage: 3);
          }
          if (query.page == 2 && repository.fetchCalls >= 4) {
            return _page(rows: const [], page: 2, total: 41, lastPage: 3);
          }

          return _page(page: query.page, total: 41, lastPage: 3);
        };
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await _flush();
        final controller = container.read(
          institutionUserListControllerProvider.notifier,
        );

        controller.nextPage();
        await _flush();
        controller.nextPage();
        await _flush();

        expect(repository.queries.map((query) => query.page), [1, 2, 3, 2]);
        expect(subscription.read().query.page, 2);
        expect(subscription.read().status, InstitutionUserListStatus.emptyPage);
        expect(repository.fetchCalls, 4);
      },
    );

    test(
      'refresh keeps same-query rows and retry is duplicate-protected',
      () async {
        final refresh = Completer<InstitutionUserListPage>();
        final repository = _FakeUserListRepository();
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await _flush();
        repository.onFetch = (_) => refresh.future;

        final controller = container.read(
          institutionUserListControllerProvider.notifier,
        );
        controller.refresh();
        controller.refresh();
        expect(repository.fetchCalls, 2);
        expect(
          subscription.read().status,
          InstitutionUserListStatus.refreshing,
        );
        expect(
          subscription.read().result?.users.single.fullName,
          'Example User',
        );
        refresh.completeError(_localFailure(ApiFailureKind.timeout));
        await _flush();
        expect(subscription.read().status, InstitutionUserListStatus.error);
        expect(subscription.read().result, isNull);

        final retry = Completer<InstitutionUserListPage>();
        repository.onFetch = (_) => retry.future;
        controller.retry();
        controller.retry();
        expect(repository.fetchCalls, 3);
        expect(subscription.read().isRetryInFlight, isTrue);
        retry.complete(_page(label: 'Retry'));
        await _flush();
        expect(subscription.read().result?.users.single.fullName, 'Retry User');
      },
    );

    test(
      'correction can resolve to rows or total-zero page 1 exactly once',
      () async {
        for (final totalZero in [false, true]) {
          final repository = _FakeUserListRepository();
          repository.onFetch = (query) async {
            if (query.page == 3) {
              return _page(
                rows: const [],
                page: 3,
                total: totalZero ? 0 : 41,
                lastPage: totalZero ? 1 : 3,
              );
            }
            if (repository.fetchCalls == 4) {
              return totalZero
                  ? _page(rows: const [], page: 1, total: 0)
                  : _page(page: 2, total: 41, lastPage: 3, label: 'Corrected');
            }

            return _page(page: query.page, total: 41, lastPage: 3);
          };
          final container = _container(repository: repository);
          final subscription = _listen(container);
          await _flush();
          final controller = container.read(
            institutionUserListControllerProvider.notifier,
          );

          controller.nextPage();
          await _flush();
          controller.nextPage();
          await _flush();

          expect(
            repository.queries.map((query) => query.page),
            totalZero ? [1, 2, 3, 1] : [1, 2, 3, 2],
          );
          expect(
            subscription.read().status,
            totalZero
                ? InstitutionUserListStatus.globalEmpty
                : InstitutionUserListStatus.data,
          );
          subscription.close();
          container.dispose();
        }
      },
    );

    test(
      'pending Refresh commits the draft and identical intents deduplicate',
      () async {
        final repository = _FakeUserListRepository();
        final container = _container(repository: repository);
        _listen(container);
        await _flush();
        final controller = container.read(
          institutionUserListControllerProvider.notifier,
        );

        controller.setRole(null);
        controller.commitSearchNow();
        await _flush();
        expect(repository.fetchCalls, 1);

        controller.updateSearchDraft('  Refresh merge  ');
        controller.refresh();
        controller.refresh();
        await _flush();
        expect(repository.fetchCalls, 2);
        expect(repository.queries.last.search, 'Refresh merge');
      },
    );

    test('disposal cancels a pending debounce before it can request', () async {
      final repository = _FakeUserListRepository();
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await _flush();
      container
          .read(institutionUserListControllerProvider.notifier)
          .updateSearchDraft('Disposed');
      subscription.close();
      await _flush();
      await Future<void>.delayed(const Duration(milliseconds: 340));

      expect(repository.fetchCalls, 1);
    });

    test(
      'same identity retains query only, while account change clears it',
      () async {
        final auth = _FakeAuthSessionController.authenticated(
          _admin('admin-a'),
        );
        final repository = _FakeUserListRepository();
        final container = _container(repository: repository, auth: auth);
        var subscription = _listen(container);
        await _flush();
        final controller = container.read(
          institutionUserListControllerProvider.notifier,
        );
        controller.updateSearchDraft('Retained');
        controller.commitSearchNow();
        await _flush();
        subscription.close();
        await _flush();

        subscription = _listen(container);
        await _flush();
        expect(repository.queries.last.search, 'Retained');
        expect(
          subscription.read().result?.users.single.fullName,
          'Example User',
        );

        auth.replaceUser(_admin('admin-b'));
        await _flush();
        expect(repository.queries.last.search, isNull);
        expect(subscription.read().searchDraft, '');
        expect(
          subscription.read().query,
          const InstitutionUserListQuery.initial(),
        );
      },
    );

    test(
      'ineligible session never loads and logout rejects stale completion',
      () async {
        for (final user in [
          _admin('inactive', isActive: false),
          _admin('password', mustChangePassword: true),
          _admin('wrong-institution', nestedInstitutionId: 'institution-2'),
          _admin('inactive-institution', institutionStatus: 'inactive'),
          _user('teacher', UserRole.teacher),
        ]) {
          final repository = _FakeUserListRepository();
          final container = _container(
            repository: repository,
            auth: _FakeAuthSessionController.authenticated(user),
          );
          final subscription = _listen(container);
          await _flush();
          expect(repository.fetchCalls, 0);
          expect(subscription.read().status, InstitutionUserListStatus.initial);
          subscription.close();
          container.dispose();
        }

        final mobileRepository = _FakeUserListRepository();
        final mobileContainer = _container(
          repository: mobileRepository,
          surface: AppDeviceSurface.mobile,
        );
        final mobileSubscription = _listen(mobileContainer);
        await _flush();
        expect(mobileRepository.fetchCalls, 0);
        expect(
          mobileSubscription.read().status,
          InstitutionUserListStatus.initial,
        );

        final pending = Completer<InstitutionUserListPage>();
        final repository = _FakeUserListRepository(
          onFetch: (_) => pending.future,
        );
        final auth = _FakeAuthSessionController.authenticated(
          _admin('admin-a'),
        );
        final container = _container(repository: repository, auth: auth);
        final subscription = _listen(container);
        await _flush();
        await auth.signOut();
        await _flush();
        pending.complete(_page(label: 'Old'));
        await _flush();
        expect(subscription.read().status, InstitutionUserListStatus.initial);
        expect(subscription.read().result, isNull);
      },
    );

    test(
      'session failures clear rows and reconcile accepted auth state',
      () async {
        for (final code in [
          ApiErrorCodes.authenticationRequired,
          ApiErrorCodes.passwordChangeRequired,
          ApiErrorCodes.userInactive,
          ApiErrorCodes.institutionInactive,
        ]) {
          final auth = _FakeAuthSessionController.authenticated(
            _admin('admin-a'),
          );
          auth.onBootstrap = () => const AuthSessionState.unauthenticated();
          final repository = _FakeUserListRepository(
            onFetch: (_) async => throw _serverFailure(code),
          );
          final container = _container(repository: repository, auth: auth);
          final subscription = _listen(container);
          await _flush();

          expect(subscription.read().result, isNull);
          expect(subscription.read().status, InstitutionUserListStatus.initial);
          expect(
            auth.bootstrapCalls,
            code == ApiErrorCodes.authenticationRequired ? 0 : 1,
          );
          subscription.close();
          container.dispose();
        }
      },
    );
  });
}

ProviderContainer _container({
  required _FakeUserListRepository repository,
  _FakeAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () =>
            auth ?? _FakeAuthSessionController.authenticated(_admin('admin-a')),
      ),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      institutionUserListRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<InstitutionUserListState> _listen(
  ProviderContainer container,
) {
  final subscription = container.listen(
    institutionUserListControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  return subscription;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

InstitutionUserListPage _page({
  String label = 'Example',
  List<InstitutionUser>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) {
  return InstitutionUserListPage(
    users: rows ?? [_institutionUser(fullName: '$label User')],
    pagination: InstitutionUserListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

InstitutionUser _institutionUser({
  String id = '00000000-0000-0000-0000-000000000001',
  String fullName = 'Example User',
}) {
  return InstitutionUser(
    id: id,
    role: InstitutionUserRole.teacher,
    fullName: fullName,
    loginName: 'teacher01',
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    lastLoginAt: null,
    deactivatedAt: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
  );
}

AuthUser _admin(
  String loginName, {
  bool isActive = true,
  bool mustChangePassword = false,
  String nestedInstitutionId = 'institution-1',
  String institutionStatus = 'active',
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: 'institution-1',
    role: UserRole.institutionAdmin,
    fullName: '$loginName User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    institution: AuthInstitution(
      id: nestedInstitutionId,
      name: 'Example School',
      status: institutionStatus,
      timezone: 'Asia/Tashkent',
    ),
  );
}

AuthUser _user(String loginName, UserRole role) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: 'institution-1',
    role: role,
    fullName: '$loginName User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: const AuthInstitution(
      id: 'institution-1',
      name: 'Example School',
      status: 'active',
      timezone: 'Asia/Tashkent',
    ),
  );
}

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Raw local failure.'),
  );
}

ApiRequestException _serverFailure(String code) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: code == ApiErrorCodes.authenticationRequired ? 401 : 403,
      error: ApiErrorResponse(
        message: 'Raw server failure.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

class _FakeUserListRepository implements InstitutionUserListRepository {
  _FakeUserListRepository({this.onFetch});

  Future<InstitutionUserListPage> Function(InstitutionUserListQuery query)?
  onFetch;
  final queries = <InstitutionUserListQuery>[];

  int get fetchCalls => queries.length;

  @override
  Future<InstitutionUserListPage> fetchUsers(InstitutionUserListQuery query) {
    queries.add(query);

    return onFetch?.call(query) ??
        Future.value(_page(page: query.page, perPage: query.perPage));
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.initialState);

  factory _FakeAuthSessionController.authenticated(AuthUser user) {
    return _FakeAuthSessionController(AuthSessionState.authenticated(user));
  }

  final AuthSessionState initialState;
  AuthSessionState Function()? onBootstrap;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => initialState;

  void replaceUser(AuthUser user) {
    state = AuthSessionState.authenticated(user);
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
    final next = onBootstrap?.call();
    if (next != null) {
      state = next;
    }
  }

  @override
  Future<void> signIn({required String login, required String password}) async {
    state = AuthSessionState.authenticated(_admin(login));
  }

  @override
  Future<void> signOut() async {
    state = const AuthSessionState.unauthenticated();
  }
}
