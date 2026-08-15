import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_create_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_create_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_dashboard_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_create_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';

void main() {
  test(
    'local validation sends no request and keeps password out of state',
    () async {
      final create = _FakeCreateRepository();
      final container = _container(create: create);
      final subscription = _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );

      await controller.submit(password: 'private-password');

      expect(create.requests, isEmpty);
      expect(
        subscription.read().status,
        InstitutionUserCreateStatus.localValidationFailure,
      );
      expect(subscription.read().fieldErrors.keys, [
        InstitutionUserCreateField.role,
        InstitutionUserCreateField.fullName,
        InstitutionUserCreateField.loginName,
      ]);
      expect(
        subscription.read().toString(),
        isNot(contains('private-password')),
      );
    },
  );

  test(
    'submits once, suppresses duplicate submit, and confirms returned UUID',
    () async {
      final response = Completer<InstitutionUser>();
      final create = _FakeCreateRepository(onCreate: (_) => response.future);
      final container = _container(create: create);
      final subscription = _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);

      final first = controller.submit(password: 'private-password');
      final second = controller.submit(password: 'private-password');
      expect(create.requests, hasLength(1));
      expect(
        subscription.read().status,
        InstitutionUserCreateStatus.submitting,
      );
      expect(create.requests.single.toJson(), {
        'role': 'teacher',
        'full_name': 'Teacher Name',
        'login_name': 'teacher01',
        'email': null,
        'phone': null,
        'password': 'private-password',
      });

      response.complete(_createdUser());
      await first;
      await second;

      expect(create.requests, hasLength(1));
      expect(
        subscription.read().status,
        InstitutionUserCreateStatus.confirmedSuccess,
      );
      expect(subscription.read().confirmedUserId, _userId);
      expect(subscription.read().passwordWipeGeneration, greaterThan(1));
    },
  );

  test(
    'uses safe local validation copy and never exposes backend messages',
    () async {
      final failure = ApiFailure(
        kind: ApiFailureKind.validation,
        statusCode: 422,
        serverCode: ApiErrorCodes.validationFailed,
        message: 'Private backend form message.',
        fieldErrors: const {
          'login_name': ['Private duplicate login detail.'],
          'password': ['Private password detail.'],
        },
      );
      final create = _FakeCreateRepository(
        onCreate: (_) => Future.error(ApiRequestException(failure)),
      );
      final container = _container(create: create);
      final subscription = _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);

      await controller.submit(password: 'private-password');

      final state = subscription.read();
      expect(state.status, InstitutionUserCreateStatus.serverValidationFailure);
      expect(
        state.errorTextFor(InstitutionUserCreateField.loginName),
        'Review the login name; it may already be in use.',
      );
      expect(
        state.errorTextFor(InstitutionUserCreateField.password),
        'Re-enter a valid initial password.',
      );
      expect(state.toString(), isNot(contains('Private')));
    },
  );

  test(
    'unknown outcome performs one exact diagnostic GET without replaying POST',
    () async {
      final create = _FakeCreateRepository(
        onCreate: (_) =>
            Future.error(const InstitutionUserCreateOutcomeUnknownException()),
      );
      final users = _FakeListRepository(
        page: InstitutionUserListPage(
          users: [_createdUser()],
          pagination: const InstitutionUserListPagination(
            page: 1,
            perPage: 100,
            total: 1,
            lastPage: 1,
          ),
        ),
      );
      final container = _container(create: create, users: users);
      final subscription = _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);

      await controller.submit(password: 'private-password');

      expect(create.requests, hasLength(1));
      expect(users.queries, hasLength(1));
      expect(users.queries.single.toQueryParameters(), {
        'page': 1,
        'per_page': 100,
        'sort': 'login_name',
        'direction': 'asc',
        'role': 'teacher',
        'search': 'teacher01',
      });
      expect(
        subscription.read().status,
        InstitutionUserCreateStatus.unknownPossibleMatch,
      );
      expect(subscription.read().confirmedUserId, isNull);
      expect(subscription.read().canSubmit, isFalse);
    },
  );

  test(
    'an auth-user instance change invalidates a pending completion',
    () async {
      final response = Completer<InstitutionUser>();
      final auth = _FakeAuthSessionController(
        AuthSessionState.authenticated(_admin()),
      );
      final create = _FakeCreateRepository(onCreate: (_) => response.future);
      final container = _container(create: create, auth: auth);
      final subscription = _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);
      final operation = controller.submit(password: 'private-password');

      auth.setSession(AuthSessionState.authenticated(_freshAdmin()));
      await _flush();
      response.complete(_createdUser());
      await operation;

      expect(subscription.read().status, InstitutionUserCreateStatus.editing);
      expect(subscription.read().confirmedUserId, isNull);
      expect(subscription.read().form.fullName, isEmpty);
    },
  );

  test('complete ineligible session matrix sends no product request', () async {
    final cases = <({AuthSessionState session, AppDeviceSurface surface})>[
      (
        session: const AuthSessionState.initial(),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: const AuthSessionState.unauthenticated(),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _adminWith(role: UserRole.teacher),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(_adminWith(isActive: false)),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _adminWith(mustChangePassword: true),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _adminWith(institutionId: null),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _adminWith(institutionStatus: 'inactive'),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(_freshAdmin()),
        surface: AppDeviceSurface.mobile,
      ),
      (
        session: AuthSessionState.authenticated(_freshAdmin()),
        surface: AppDeviceSurface.unsupported,
      ),
    ];

    for (final value in cases) {
      final create = _FakeCreateRepository();
      final users = _FakeListRepository();
      final container = _container(
        create: create,
        users: users,
        auth: _FakeAuthSessionController(value.session),
        surface: value.surface,
      );
      _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);
      await controller.submit(password: 'private-password');

      expect(create.requests, isEmpty, reason: '${value.session.status}');
      expect(users.queries, isEmpty, reason: '${value.surface}');
    }
  });

  test(
    'maps every known validation field safely and unknown keys at form level',
    () async {
      final failure = ApiFailure(
        kind: ApiFailureKind.validation,
        statusCode: 422,
        serverCode: ApiErrorCodes.validationFailed,
        message: 'Private backend form message.',
        fieldErrors: const {
          'role': ['private'],
          'full_name': ['private'],
          'login_name': ['private'],
          'email': ['private'],
          'phone': ['private'],
          'password': ['private'],
          'institution_id': ['private tenant detail'],
        },
      );
      final container = _container(
        create: _FakeCreateRepository(
          onCreate: (_) => Future.error(ApiRequestException(failure)),
        ),
      );
      final subscription = _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);
      await controller.submit(password: 'private-password');

      final state = subscription.read();
      expect(state.fieldErrors.keys, InstitutionUserCreateField.values);
      expect(state.firstErrorField, InstitutionUserCreateField.role);
      expect(state.formError, 'The user could not be created.');
      expect(state.toString(), isNot(contains('private')));
    },
  );

  test(
    'all non-exact diagnostic results stay inconclusive with one GET',
    () async {
      final pages = <InstitutionUserListPage>[
        _listPage(users: [], total: 0),
        _listPage(users: [_createdUser(), _createdUser()], total: 2),
        _listPage(users: [_createdUser()], total: 2, lastPage: 2),
        _listPage(users: [_createdUser(fullName: 'Different')], total: 1),
      ];

      for (final page in pages) {
        final create = _FakeCreateRepository(
          onCreate: (_) => Future.error(
            const InstitutionUserCreateOutcomeUnknownException(),
          ),
        );
        final users = _FakeListRepository(page: page);
        final container = _container(create: create, users: users);
        final subscription = _listen(container);
        final controller = container.read(
          institutionUserCreateControllerProvider.notifier,
        );
        _fill(controller);
        await controller.submit(password: 'private-password');

        expect(create.requests, hasLength(1));
        expect(users.queries, hasLength(1));
        expect(
          subscription.read().status,
          InstitutionUserCreateStatus.unknownInconclusive,
        );
        expect(subscription.read().confirmedUserId, isNull);
      }
    },
  );

  test(
    'diagnostic GET failure remains inconclusive and is never retried',
    () async {
      final create = _FakeCreateRepository(
        onCreate: (_) =>
            Future.error(const InstitutionUserCreateOutcomeUnknownException()),
      );
      final users = _FakeListRepository(
        onFetch: (_) => Future.error(
          ApiRequestException(
            ApiFailure.local(
              kind: ApiFailureKind.connection,
              message: 'Private diagnostic detail.',
            ),
          ),
        ),
      );
      final container = _container(create: create, users: users);
      final subscription = _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);
      await controller.submit(password: 'private-password');

      expect(create.requests, hasLength(1));
      expect(users.queries, hasLength(1));
      expect(
        subscription.read().status,
        InstitutionUserCreateStatus.unknownInconclusive,
      );
      expect(subscription.read().toString(), isNot(contains('Private')));
    },
  );

  test(
    'POST start refreshes list and dashboard while preserving retained query',
    () async {
      final response = Completer<InstitutionUser>();
      final create = _FakeCreateRepository(onCreate: (_) => response.future);
      final users = _FakeListRepository(
        onFetch: (query) async => InstitutionUserListPage(
          users: const [],
          pagination: InstitutionUserListPagination(
            page: query.page,
            perPage: query.perPage,
            total: 0,
            lastPage: 1,
          ),
        ),
      );
      final dashboard = _FakeDashboardRepository();
      final container = _container(
        create: create,
        users: users,
        dashboard: dashboard,
      );
      final listSubscription = container.listen(
        institutionUserListControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final dashboardSubscription = container.listen(
        institutionDashboardControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(listSubscription.close);
      addTearDown(dashboardSubscription.close);
      _listen(container);
      await _flush();

      final listController = container.read(
        institutionUserListControllerProvider.notifier,
      );
      listController.updateSearchDraft('Retained');
      listController.commitSearchNow();
      await _flush();
      final usersBeforeSubmit = users.queries.length;
      final dashboardBeforeSubmit = dashboard.fetchCalls;

      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);
      final operation = controller.submit(password: 'private-password');
      await _flush();

      expect(users.queries.length, usersBeforeSubmit + 1);
      expect(users.queries.last.search, 'Retained');
      expect(dashboard.fetchCalls, dashboardBeforeSubmit + 1);
      expect(create.requests, hasLength(1));

      response.complete(_createdUser());
      await operation;
    },
  );

  test(
    'authentication and lifecycle failures clear state and reconcile',
    () async {
      for (final code in const [
        ApiErrorCodes.authenticationRequired,
        ApiErrorCodes.passwordChangeRequired,
        ApiErrorCodes.userInactive,
        ApiErrorCodes.institutionInactive,
      ]) {
        final auth = _FakeAuthSessionController(
          AuthSessionState.authenticated(_freshAdmin()),
        );
        final failure = ApiFailure(
          kind: ApiFailureKind.server,
          statusCode: code == ApiErrorCodes.authenticationRequired ? 401 : 403,
          serverCode: code,
          message: 'Private lifecycle detail.',
        );
        final container = _container(
          create: _FakeCreateRepository(
            onCreate: (_) => Future.error(ApiRequestException(failure)),
          ),
          auth: auth,
        );
        final subscription = _listen(container);
        final controller = container.read(
          institutionUserCreateControllerProvider.notifier,
        );
        _fill(controller);
        await controller.submit(password: 'private-password');
        await _flush();

        expect(subscription.read().status, InstitutionUserCreateStatus.editing);
        expect(subscription.read().form.fullName, isEmpty);
        expect(subscription.read().toString(), isNot(contains('Private')));
        expect(
          auth.bootstrapCalls,
          code == ApiErrorCodes.authenticationRequired ? 0 : 1,
        );
      }
    },
  );

  test('forbidden and rate limit use exact safe retry copy', () async {
    final cases = <({String code, String copy})>[
      (
        code: ApiErrorCodes.forbidden,
        copy: 'You do not have permission to create users.',
      ),
      (
        code: ApiErrorCodes.rateLimited,
        copy: 'Too many requests. Wait before trying again.',
      ),
    ];

    for (final value in cases) {
      final failure = ApiFailure(
        kind: ApiFailureKind.server,
        statusCode: value.code == ApiErrorCodes.rateLimited ? 429 : 403,
        serverCode: value.code,
        message: 'Private server detail.',
      );
      final container = _container(
        create: _FakeCreateRepository(
          onCreate: (_) => Future.error(ApiRequestException(failure)),
        ),
      );
      final subscription = _listen(container);
      final controller = container.read(
        institutionUserCreateControllerProvider.notifier,
      );
      _fill(controller);
      final before = subscription.read().passwordWipeGeneration;
      await controller.submit(password: 'private-password');

      expect(
        subscription.read().status,
        InstitutionUserCreateStatus.definiteFailure,
      );
      expect(subscription.read().formError, value.copy);
      expect(subscription.read().form.loginName, 'teacher01');
      expect(subscription.read().passwordWipeGeneration, before + 1);
      expect(subscription.read().toString(), isNot(contains('Private')));
    }
  });
}

ProviderContainer _container({
  required _FakeCreateRepository create,
  _FakeListRepository? users,
  _FakeDashboardRepository? dashboard,
  _FakeAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () =>
            auth ??
            _FakeAuthSessionController(
              AuthSessionState.authenticated(_admin()),
            ),
      ),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      institutionUserCreateRepositoryProvider.overrideWithValue(create),
      institutionUserListRepositoryProvider.overrideWithValue(
        users ?? _FakeListRepository(),
      ),
      institutionDashboardRepositoryProvider.overrideWithValue(
        dashboard ?? _FakeDashboardRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<InstitutionUserCreateState> _listen(
  ProviderContainer container,
) {
  final subscription = container.listen(
    institutionUserCreateControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return subscription;
}

void _fill(InstitutionUserCreateController controller) {
  controller.updateRole(InstitutionUserRole.teacher);
  controller.updateFullName('  Teacher Name  ');
  controller.updateLoginName('  teacher01  ');
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _userId = '00000000-0000-0000-0000-000000000001';

InstitutionUser _createdUser({String fullName = 'Teacher Name'}) =>
    InstitutionUser(
      id: _userId,
      role: InstitutionUserRole.teacher,
      fullName: fullName,
      loginName: 'teacher01',
      email: null,
      phone: null,
      isActive: true,
      mustChangePassword: true,
      lastLoginAt: null,
      deactivatedAt: null,
      createdAt: DateTime.utc(2026, 8, 15, 8),
      updatedAt: DateTime.utc(2026, 8, 15, 8),
    );

AuthUser _admin() => const AuthUser(
  id: 'admin-a',
  institutionId: 'institution-a',
  role: UserRole.institutionAdmin,
  fullName: 'Admin User',
  loginName: 'admin',
  email: null,
  phone: null,
  isActive: true,
  mustChangePassword: false,
  institution: AuthInstitution(
    id: 'institution-a',
    name: 'Institution A',
    status: 'active',
    timezone: 'Asia/Tashkent',
  ),
);

AuthUser _freshAdmin() => AuthUser(
  id: 'admin-a',
  institutionId: 'institution-a',
  role: UserRole.institutionAdmin,
  fullName: 'Admin User',
  loginName: 'admin',
  email: null,
  phone: null,
  isActive: true,
  mustChangePassword: false,
  institution: const AuthInstitution(
    id: 'institution-a',
    name: 'Institution A',
    status: 'active',
    timezone: 'Asia/Tashkent',
  ),
);

AuthUser _adminWith({
  String? institutionId = 'institution-a',
  UserRole role = UserRole.institutionAdmin,
  bool isActive = true,
  bool mustChangePassword = false,
  String institutionStatus = 'active',
}) => AuthUser(
  id: 'admin-a',
  institutionId: institutionId,
  role: role,
  fullName: 'Admin User',
  loginName: 'admin',
  email: null,
  phone: null,
  isActive: isActive,
  mustChangePassword: mustChangePassword,
  institution: AuthInstitution(
    id: 'institution-a',
    name: 'Institution A',
    status: institutionStatus,
    timezone: 'Asia/Tashkent',
  ),
);

InstitutionUserListPage _listPage({
  required List<InstitutionUser> users,
  required int total,
  int lastPage = 1,
}) => InstitutionUserListPage(
  users: users,
  pagination: InstitutionUserListPagination(
    page: 1,
    perPage: 100,
    total: total,
    lastPage: lastPage,
  ),
);

class _FakeCreateRepository implements InstitutionUserCreateRepository {
  _FakeCreateRepository({this.onCreate});

  final Future<InstitutionUser> Function(InstitutionUserCreateRequest request)?
  onCreate;
  final requests = <InstitutionUserCreateRequest>[];

  @override
  Future<InstitutionUser> createUser(InstitutionUserCreateRequest request) {
    requests.add(request);
    return onCreate?.call(request) ?? Future.value(_createdUser());
  }
}

class _FakeListRepository implements InstitutionUserListRepository {
  _FakeListRepository({
    this.page = const InstitutionUserListPage(
      users: [],
      pagination: InstitutionUserListPagination(
        page: 1,
        perPage: 100,
        total: 0,
        lastPage: 1,
      ),
    ),
    this.onFetch,
  });

  final InstitutionUserListPage page;
  final Future<InstitutionUserListPage> Function(
    InstitutionUserListQuery query,
  )?
  onFetch;
  final queries = <InstitutionUserListQuery>[];

  @override
  Future<InstitutionUserListPage> fetchUsers(
    InstitutionUserListQuery query,
  ) async {
    queries.add(query);
    return onFetch?.call(query) ?? page;
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.initialState);

  final AuthSessionState initialState;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => initialState;

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
  }

  void setSession(AuthSessionState nextState) {
    state = nextState;
  }
}

class _FakeDashboardRepository implements InstitutionDashboardRepository {
  var fetchCalls = 0;

  @override
  Future<InstitutionDashboard> fetchDashboard() async {
    fetchCalls += 1;
    return const InstitutionDashboard(teachers: 1, students: 2, parents: 3);
  }
}
