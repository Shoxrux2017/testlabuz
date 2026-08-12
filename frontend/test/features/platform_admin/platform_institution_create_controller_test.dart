import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_dashboard_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_create_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_create_state.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_list_controller.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_create_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_create_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('PlatformInstitutionCreateController', () {
    test(
      'initial state sends no request and local invalid submit sends none',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionCreateRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          createRepository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);

        expect(
          subscription.read().status,
          PlatformInstitutionCreateStatus.editing,
        );
        expect(repository.createCalls, 0);

        await container
            .read(platformInstitutionCreateControllerProvider(key).notifier)
            .submit();
        await _flush();

        expect(repository.createCalls, 0);
        expect(
          subscription.read().status,
          PlatformInstitutionCreateStatus.validationFailure,
        );
        expect(
          subscription.read().fieldErrors.keys,
          containsAll([
            PlatformInstitutionCreateField.name,
            PlatformInstitutionCreateField.type,
            PlatformInstitutionCreateField.status,
          ]),
        );
      },
    );

    test(
      'one valid submit sends one request and duplicate in-flight submits do not',
      () async {
        final owner = _owner('owner-a');
        final completer = Completer<PlatformInstitutionCreateResult>();
        final repository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) => completer.future,
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          createRepository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionCreateControllerProvider(key).notifier,
        );

        _fillValid(controller);
        final submitA = controller.submit();
        final submitB = controller.submit();
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionCreateStatus.submitting,
        );
        expect(repository.createCalls, 1);
        expect(repository.requests.single.toJson(), {
          'name': 'Example School',
          'type': 'school',
          'contact_email': 'info@example.uz',
          'contact_phone': '+998901234567',
          'address': 'Samarkand',
          'description': 'Optional notes',
          'status': 'active',
        });

        completer.complete(_result());
        await submitA;
        await submitB;
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionCreateStatus.success,
        );
        expect(repository.createCalls, 1);
      },
    );

    test(
      'server validation maps exact fields and clears only edited field',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) async => throw _serverValidationFailure(),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          createRepository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionCreateControllerProvider(key).notifier,
        );

        _fillValid(controller);
        await controller.submit();

        expect(
          subscription.read().fieldErrors.keys,
          containsAll([
            PlatformInstitutionCreateField.name,
            PlatformInstitutionCreateField.contactEmail,
          ]),
        );
        expect(subscription.read().formError, isNotNull);

        controller.updateName('Corrected');

        expect(
          subscription.read().fieldErrors.keys,
          isNot(contains(PlatformInstitutionCreateField.name)),
        );
        expect(
          subscription.read().fieldErrors.keys,
          contains(PlatformInstitutionCreateField.contactEmail),
        );
        expect(subscription.read().form.name, 'Corrected');
      },
    );

    test(
      'definite failure preserves form and performs no invalidation',
      () async {
        final owner = _owner('owner-a');
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();
        final repository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) async =>
              throw _serverFailure(ApiErrorCodes.serverError, statusCode: 500),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          createRepository: repository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final listSubscription = container.listen(
          platformInstitutionListControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final dashboardSubscription = container.listen(
          platformDashboardControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(listSubscription.close);
        addTearDown(dashboardSubscription.close);
        await _flush();
        final initialListCalls = listRepository.fetchCalls;
        final initialDashboardCalls = dashboardRepository.fetchCalls;

        final controller = container.read(
          platformInstitutionCreateControllerProvider(key).notifier,
        );
        _fillValid(controller);
        await controller.submit();

        expect(
          subscription.read().status,
          PlatformInstitutionCreateStatus.failure,
        );
        expect(subscription.read().form.name, 'Example School');
        expect(listRepository.fetchCalls, initialListCalls);
        expect(dashboardRepository.fetchCalls, initialDashboardCalls);
      },
    );

    test(
      'unknown outcome preserves form and exposes no success state',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) async =>
              throw const PlatformInstitutionCreateOutcomeUnknownException(
                'unknown',
              ),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          createRepository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionCreateControllerProvider(key).notifier,
        );

        _fillValid(controller);
        await controller.submit();

        expect(
          subscription.read().status,
          PlatformInstitutionCreateStatus.outcomeUnknown,
        );
        expect(subscription.read().form.name, 'Example School');
        expect(subscription.read().canSubmit, isFalse);
      },
    );

    test(
      'success does not issue hidden list or dashboard refresh requests',
      () async {
        final owner = _owner('owner-a');
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();
        final repository = FakePlatformInstitutionCreateRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          createRepository: repository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);

        final controller = container.read(
          platformInstitutionCreateControllerProvider(key).notifier,
        );
        _fillValid(controller);
        await controller.submit();
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionCreateStatus.success,
        );
        expect(listRepository.fetchCalls, 0);
        expect(dashboardRepository.fetchCalls, 0);
        expect(repository.createCalls, 1);

        final listSubscription = container.listen(
          platformInstitutionListControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final dashboardSubscription = container.listen(
          platformDashboardControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(listSubscription.close);
        addTearDown(dashboardSubscription.close);
        await _flush();

        expect(listRepository.fetchCalls, 1);
        expect(dashboardRepository.fetchCalls, 1);
      },
    );

    test('auth failures request accepted reconciliation', () async {
      final cases = [
        (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
        (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
        (statusCode: 403, code: ApiErrorCodes.userInactive),
      ];

      for (final testCase in cases) {
        final owner = _owner('owner-a');
        final authController = FakeAuthSessionController.authenticated(owner)
          ..onBootstrap = () =>
              testCase.code == ApiErrorCodes.passwordChangeRequired
              ? AuthSessionState.authenticated(
                  _owner('owner-a', mustChangePassword: true),
                )
              : const AuthSessionState.unauthenticated();
        final repository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) async => throw _serverFailure(
            testCase.code,
            statusCode: testCase.statusCode,
          ),
        );
        final container = _container(
          authController: authController,
          createRepository: repository,
        );
        final key = _key(owner);
        final controller = container.read(
          platformInstitutionCreateControllerProvider(key).notifier,
        );

        _fillValid(controller);
        await controller.submit();
        await _flush();

        expect(authController.bootstrapCalls, 1);
      }
    });

    test('late completion after logout or account switch is ignored', () async {
      final ownerA = _owner('owner-a');
      final completer = Completer<PlatformInstitutionCreateResult>();
      final repository = FakePlatformInstitutionCreateRepository(
        onCreate: (_) => completer.future,
      );
      final authController = FakeAuthSessionController.authenticated(ownerA);
      final container = _container(
        authController: authController,
        createRepository: repository,
      );
      final keyA = _key(ownerA);
      final subscription = _listen(container, keyA);
      final controller = container.read(
        platformInstitutionCreateControllerProvider(keyA).notifier,
      );

      _fillValid(controller);
      final submit = controller.submit();
      await _flush();
      await authController.signOut();
      completer.complete(_result(name: 'Old Owner School'));
      await submit;
      await _flush();

      expect(
        subscription.read().status,
        PlatformInstitutionCreateStatus.editing,
      );
      expect(subscription.read().result, isNull);

      final ownerB = _owner('owner-b');
      authController.state = AuthSessionState.authenticated(ownerB);
      final keyB = _key(ownerB);
      final stateB = container.read(
        platformInstitutionCreateControllerProvider(keyB),
      );
      expect(stateB.form.name, '');
      expect(stateB.result, isNull);
    });
  });
}

ProviderContainer _container({
  required FakeAuthSessionController authController,
  required FakePlatformInstitutionCreateRepository createRepository,
  FakePlatformInstitutionListRepository? listRepository,
  FakePlatformDashboardRepository? dashboardRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      platformInstitutionCreateRepositoryProvider.overrideWithValue(
        createRepository,
      ),
      platformInstitutionListRepositoryProvider.overrideWithValue(
        listRepository ?? FakePlatformInstitutionListRepository(),
      ),
      platformDashboardRepositoryProvider.overrideWithValue(
        dashboardRepository ?? FakePlatformDashboardRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<PlatformInstitutionCreateState> _listen(
  ProviderContainer container,
  PlatformInstitutionCreateKey key,
) {
  final subscription = container.listen(
    platformInstitutionCreateControllerProvider(key),
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

void _fillValid(PlatformInstitutionCreateController controller) {
  controller
    ..updateName('Example School')
    ..updateType(PlatformInstitutionType.school)
    ..updateContactEmail('info@example.uz')
    ..updateContactPhone('+998901234567')
    ..updateAddress('Samarkand')
    ..updateDescription('Optional notes')
    ..updateStatus(PlatformInstitutionStatus.active);
}

PlatformInstitutionCreateKey _key(AuthUser user) {
  return PlatformInstitutionCreateKey(
    sessionUserId: user.id,
    sessionInstanceId: identityHashCode(user),
  );
}

PlatformInstitutionCreateResult _result({String name = 'Example School'}) {
  return PlatformInstitutionCreateResult(
    id: '550e8400-e29b-41d4-a716-446655440000',
    name: name,
    type: PlatformInstitutionType.school,
    status: PlatformInstitutionStatus.active,
    contactEmail: 'info@example.uz',
    contactPhone: '+998901234567',
    address: 'Samarkand',
    description: 'Optional notes',
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    message: 'Institution created successfully.',
  );
}

PlatformInstitutionListPage _page() {
  return PlatformInstitutionListPage(
    institutions: const [],
    pagination: const PlatformInstitutionPagination(
      page: 1,
      perPage: 20,
      total: 0,
      lastPage: 1,
    ),
  );
}

PlatformDashboard _dashboard() {
  return PlatformDashboard(
    institutions: const PlatformInstitutionCounts(
      total: 20,
      active: 18,
      inactive: 2,
    ),
    users: const PlatformUserCounts(total: 2800, active: 2720),
    recentInstitutions: const [],
  );
}

AuthUser _owner(String loginName, {bool mustChangePassword = false}) {
  return _user(
    loginName: loginName,
    role: UserRole.platformOwner,
    mustChangePassword: mustChangePassword,
  );
}

AuthUser _user({
  required String loginName,
  required UserRole role,
  bool mustChangePassword = false,
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: role == UserRole.platformOwner ? null : 'institution-1',
    role: role,
    fullName: '$loginName User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: mustChangePassword,
    institution: role == UserRole.platformOwner
        ? null
        : const AuthInstitution(
            id: 'institution-1',
            name: 'Example School',
            status: 'active',
            timezone: 'Asia/Tashkent',
          ),
  );
}

ApiRequestException _serverFailure(String code, {required int statusCode}) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: statusCode,
      error: ApiErrorResponse(
        message: 'Server message must not control create flow.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _serverValidationFailure() {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: 422,
      error: ApiErrorResponse(
        message: 'Invalid data.',
        code: ApiErrorCodes.validationFailed,
        fieldErrors: {
          'name': ['The name has already been used in this fixture.'],
          'contact_email': ['The contact email must be valid.'],
          'settings': ['This field is not allowed.'],
        },
        requestId: 'req-1',
      ),
    ),
  );
}

class FakePlatformInstitutionCreateRepository
    implements PlatformInstitutionCreateRepository {
  FakePlatformInstitutionCreateRepository({this.onCreate});

  Future<PlatformInstitutionCreateResult> Function(
    PlatformInstitutionCreateRequest request,
  )?
  onCreate;
  final requests = <PlatformInstitutionCreateRequest>[];

  int get createCalls => requests.length;

  @override
  Future<PlatformInstitutionCreateResult> createInstitution(
    PlatformInstitutionCreateRequest request,
  ) {
    requests.add(request);

    return onCreate?.call(request) ?? Future.value(_result());
  }
}

class FakePlatformInstitutionListRepository
    implements PlatformInstitutionListRepository {
  final queries = <PlatformInstitutionListQuery>[];

  int get fetchCalls => queries.length;

  @override
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) {
    queries.add(query);

    return Future.value(_page());
  }
}

class FakePlatformDashboardRepository implements PlatformDashboardRepository {
  var fetchCalls = 0;

  @override
  Future<PlatformDashboard> fetchDashboard() {
    fetchCalls += 1;

    return Future.value(_dashboard());
  }
}

class FakeAuthSessionController extends AuthSessionController {
  FakeAuthSessionController(this.initialState);

  factory FakeAuthSessionController.authenticated(AuthUser user) {
    return FakeAuthSessionController(AuthSessionState.authenticated(user));
  }

  final AuthSessionState initialState;
  AuthSessionState Function()? onBootstrap;
  var bootstrapCalls = 0;
  var signOutCalls = 0;

  @override
  AuthSessionState build() {
    return initialState;
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
    final nextState = onBootstrap?.call();
    if (nextState != null) {
      state = nextState;
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    state = const AuthSessionState.unauthenticated();
  }
}
