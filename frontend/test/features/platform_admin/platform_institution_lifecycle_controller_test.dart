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
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_lifecycle_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_lifecycle_state.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_lifecycle_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_lifecycle.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_lifecycle_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('PlatformInstitutionLifecycleController', () {
    test(
      'active and inactive details open exact target confirmation',
      () async {
        final owner = _owner('owner-a');
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionLifecycleControllerProvider(key).notifier,
        );

        expect(controller.beginConfirmation(_detail()), isTrue);
        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.confirming,
        );
        expect(
          subscription.read().operation?.action,
          PlatformInstitutionLifecycleAction.deactivate,
        );
        expect(
          subscription.read().operation?.sourceStatus,
          PlatformInstitutionStatus.active,
        );
        expect(
          subscription.read().operation?.targetStatus,
          PlatformInstitutionStatus.inactive,
        );
        expect(controller.beginConfirmation(_detail()), isFalse);

        controller.dismiss();
        expect(
          controller.beginConfirmation(
            _detail(status: PlatformInstitutionStatus.inactive),
          ),
          isTrue,
        );
        expect(
          subscription.read().operation?.action,
          PlatformInstitutionLifecycleAction.activate,
        );
        expect(
          subscription.read().operation?.targetStatus,
          PlatformInstitutionStatus.active,
        );
      },
    );

    test(
      'one confirmation creates one lifecycle request and confirmed state',
      () async {
        final owner = _owner('owner-a');
        final completer = Completer<PlatformInstitutionLifecycleResult>();
        final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
          onDeactivate: (_) => completer.future,
        );
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          lifecycleRepository: lifecycleRepository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionLifecycleControllerProvider(key).notifier,
        );

        expect(controller.beginConfirmation(_detail()), isTrue);
        final confirmA = controller.confirm();
        final confirmB = controller.confirm();
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.submitting,
        );
        expect(lifecycleRepository.deactivateCalls, 1);
        expect(lifecycleRepository.activateCalls, 0);

        completer.complete(_result(status: PlatformInstitutionStatus.inactive));
        await confirmA;
        await confirmB;
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.confirmed,
        );
        expect(
          subscription.read().result?.status,
          PlatformInstitutionStatus.inactive,
        );
        expect(
          subscription.read().result?.message,
          'Institution deactivated successfully.',
        );
        expect(lifecycleRepository.deactivateCalls, 1);
        expect(listRepository.fetchCalls, 0);
        expect(dashboardRepository.fetchCalls, 0);
      },
    );

    test(
      'acknowledged refreshed detail clears confirmed state for new action',
      () async {
        final owner = _owner('owner-a');
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionLifecycleControllerProvider(key).notifier,
        );

        controller.beginConfirmation(_detail());
        await controller.confirm();
        await _flush();
        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.confirmed,
        );

        controller.acknowledgeRefreshedDetail(
          _detail(status: PlatformInstitutionStatus.inactive),
        );
        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.idle,
        );
        expect(
          controller.beginConfirmation(
            _detail(status: PlatformInstitutionStatus.inactive),
          ),
          isTrue,
        );
      },
    );

    test('definite failures are recoverable and auth failures bootstrap', () async {
      final owner = _owner('owner-a');
      final cases = [
        (
          exception: _serverFailure(ApiErrorCodes.forbidden, statusCode: 403),
          bootstrap: false,
          message:
              'You do not have permission to change this institution status.',
        ),
        (
          exception: _serverFailure(
            ApiErrorCodes.validationFailed,
            statusCode: 422,
          ),
          bootstrap: false,
          message:
              'The institution lifecycle request did not match the API contract.',
        ),
        (
          exception: _serverFailure(ApiErrorCodes.serverError, statusCode: 500),
          bootstrap: false,
          message:
              'The institution status could not be changed. No change was confirmed.',
        ),
        (
          exception: _serverFailure(
            ApiErrorCodes.authenticationRequired,
            statusCode: 401,
          ),
          bootstrap: true,
          message: 'Please sign in again.',
        ),
      ];

      for (final testCase in cases) {
        final authController = FakeAuthSessionController.authenticated(owner);
        final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
          onDeactivate: (_) async => throw testCase.exception,
        );
        final container = _container(
          authController: authController,
          lifecycleRepository: lifecycleRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionLifecycleControllerProvider(key).notifier,
        );

        controller.beginConfirmation(_detail());
        await controller.confirm();
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.definiteFailure,
        );
        expect(subscription.read().message, testCase.message);
        expect(authController.bootstrapCalls, testCase.bootstrap ? 1 : 0);
        expect(lifecycleRepository.deactivateCalls, 1);

        controller.dismiss();
        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.idle,
        );
      }
    });

    test(
      '409 conflict reconciles current detail without claiming success',
      () async {
        final owner = _owner('owner-a');
        final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
          onDeactivate: (_) async =>
              throw _serverFailure('lifecycle_conflict', statusCode: 409),
        );
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (_) async =>
              _detail(status: PlatformInstitutionStatus.active),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          lifecycleRepository: lifecycleRepository,
          detailRepository: detailRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionLifecycleControllerProvider(key).notifier,
        );

        controller.beginConfirmation(_detail());
        await controller.confirm();
        await _flush();

        expect(detailRepository.fetchCalls, 1);
        expect(lifecycleRepository.deactivateCalls, 1);
        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.definiteFailure,
        );
        expect(
          subscription.read().currentStatus,
          PlatformInstitutionStatus.active,
        );
        expect(subscription.read().result, isNull);
        expect(
          subscription.read().message,
          contains('Current server status is active.'),
        );
      },
    );

    test(
      'unknown outcome reconciles target through one GET and no second POST',
      () async {
        final owner = _owner('owner-a');
        final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
          onDeactivate: (_) async =>
              throw const PlatformInstitutionLifecycleOutcomeUnknownException(
                'unknown',
              ),
        );
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (_) async =>
              _detail(status: PlatformInstitutionStatus.inactive),
        );
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          lifecycleRepository: lifecycleRepository,
          detailRepository: detailRepository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionLifecycleControllerProvider(key).notifier,
        );

        controller.beginConfirmation(_detail());
        await controller.confirm();
        await _flush();
        await controller.confirm();

        expect(lifecycleRepository.deactivateCalls, 1);
        expect(detailRepository.fetchCalls, 1);
        expect(
          subscription.read().status,
          PlatformInstitutionLifecycleStatus.unknownOutcome,
        );
        expect(
          subscription.read().currentStatus,
          PlatformInstitutionStatus.inactive,
        );
        expect(
          subscription.read().message,
          'Current server status is inactive.',
        );
        expect(subscription.read().canCheckStatus, isFalse);
        expect(listRepository.fetchCalls, 0);
        expect(dashboardRepository.fetchCalls, 0);
      },
    );

    test(
      'unknown outcome original status allows only new confirmed gesture',
      () async {
        final owner = _owner('owner-a');
        final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
          onDeactivate: (_) async =>
              throw const PlatformInstitutionLifecycleOutcomeUnknownException(
                'unknown',
              ),
        );
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (_) async =>
              _detail(status: PlatformInstitutionStatus.active),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          lifecycleRepository: lifecycleRepository,
          detailRepository: detailRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionLifecycleControllerProvider(key).notifier,
        );

        controller.beginConfirmation(_detail());
        await controller.confirm();
        await _flush();

        expect(lifecycleRepository.deactivateCalls, 1);
        expect(
          subscription.read().currentStatus,
          PlatformInstitutionStatus.active,
        );
        expect(
          subscription.read().message,
          contains('No lifecycle change was confirmed.'),
        );
        expect(controller.beginConfirmation(_detail()), isFalse);
        controller.dismiss();
        expect(controller.beginConfirmation(_detail()), isTrue);
      },
    );

    test('failed reconciliation exposes GET-only check status', () async {
      final owner = _owner('owner-a');
      final statusCompleter = Completer<PlatformInstitutionDetail>();
      final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
        onDeactivate: (_) async =>
            throw const PlatformInstitutionLifecycleOutcomeUnknownException(
              'unknown',
            ),
      );
      final detailRepository = FakePlatformInstitutionDetailRepository();
      detailRepository.onFetch = (_) {
        if (detailRepository.fetchCalls == 1) {
          throw _localFailure(ApiFailureKind.connection);
        }

        return statusCompleter.future;
      };
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        lifecycleRepository: lifecycleRepository,
        detailRepository: detailRepository,
      );
      final key = _key(owner);
      final subscription = _listen(container, key);
      final controller = container.read(
        platformInstitutionLifecycleControllerProvider(key).notifier,
      );

      controller.beginConfirmation(_detail());
      await controller.confirm();
      await _flush();

      expect(subscription.read().canCheckStatus, isTrue);
      expect(lifecycleRepository.deactivateCalls, 1);
      expect(detailRepository.fetchCalls, 1);

      final checkA = controller.checkStatus();
      final checkB = controller.checkStatus();
      await _flush();
      expect(detailRepository.fetchCalls, 2);
      expect(lifecycleRepository.deactivateCalls, 1);
      expect(
        subscription.read().status,
        PlatformInstitutionLifecycleStatus.reconciling,
      );

      statusCompleter.complete(
        _detail(status: PlatformInstitutionStatus.inactive),
      );
      await checkA;
      await checkB;
      await _flush();

      expect(detailRepository.fetchCalls, 2);
      expect(lifecycleRepository.deactivateCalls, 1);
      expect(
        subscription.read().currentStatus,
        PlatformInstitutionStatus.inactive,
      );
    });

    test('late completion after route or session change is ignored', () async {
      final ownerA = _owner('owner-a');
      final lifecycleCompleter =
          Completer<PlatformInstitutionLifecycleResult>();
      final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
        onDeactivate: (_) => lifecycleCompleter.future,
      );
      final authController = FakeAuthSessionController.authenticated(ownerA);
      final container = _container(
        authController: authController,
        lifecycleRepository: lifecycleRepository,
      );
      final keyA = _key(ownerA, institutionId: _institutionIdA);
      final subscriptionA = _listen(container, keyA);
      final controllerA = container.read(
        platformInstitutionLifecycleControllerProvider(keyA).notifier,
      );

      controllerA.beginConfirmation(_detail(id: _institutionIdA));
      final submit = controllerA.confirm();
      await _flush();
      await authController.signOut();
      await _flush();

      lifecycleCompleter.complete(
        _result(
          id: _institutionIdA,
          status: PlatformInstitutionStatus.inactive,
        ),
      );
      await submit;
      await _flush();

      expect(
        subscriptionA.read().status,
        PlatformInstitutionLifecycleStatus.idle,
      );
      expect(subscriptionA.read().result, isNull);

      final ownerB = _owner('owner-b');
      authController.setAuthenticated(ownerB);
      final keyB = _key(ownerB, institutionId: _institutionIdB);
      final subscriptionB = _listen(container, keyB);
      await _flush();
      expect(
        subscriptionB.read().status,
        PlatformInstitutionLifecycleStatus.idle,
      );
      expect(subscriptionB.read().result, isNull);
    });
  });
}

ProviderContainer _container({
  required FakeAuthSessionController authController,
  FakePlatformInstitutionLifecycleRepository? lifecycleRepository,
  FakePlatformInstitutionDetailRepository? detailRepository,
  FakePlatformInstitutionListRepository? listRepository,
  FakePlatformDashboardRepository? dashboardRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      platformInstitutionLifecycleRepositoryProvider.overrideWithValue(
        lifecycleRepository ?? FakePlatformInstitutionLifecycleRepository(),
      ),
      platformInstitutionDetailRepositoryProvider.overrideWithValue(
        detailRepository ?? FakePlatformInstitutionDetailRepository(),
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

ProviderSubscription<PlatformInstitutionLifecycleState> _listen(
  ProviderContainer container,
  PlatformInstitutionLifecycleKey key,
) {
  final subscription = container.listen(
    platformInstitutionLifecycleControllerProvider(key),
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

PlatformInstitutionLifecycleKey _key(
  AuthUser user, {
  String institutionId = _institutionIdA,
}) {
  return PlatformInstitutionLifecycleKey(
    sessionUserId: user.id,
    sessionInstanceId: identityHashCode(user),
    institutionId: institutionId,
  );
}

PlatformInstitutionDetail _detail({
  String id = _institutionIdA,
  String name = 'Example School',
  PlatformInstitutionType type = PlatformInstitutionType.school,
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
}) {
  return PlatformInstitutionDetail(
    id: id,
    name: name,
    type: type,
    status: status,
    contactEmail: 'info@example.uz',
    contactPhone: '+998901234567',
    address: 'Samarkand',
    description: 'Optional notes',
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    userCounts: const PlatformInstitutionUserCounts(total: 42, active: 40),
  );
}

PlatformInstitutionLifecycleResult _result({
  String id = _institutionIdA,
  String name = 'Example School',
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
}) {
  final message = status == PlatformInstitutionStatus.active
      ? 'Institution activated successfully.'
      : 'Institution deactivated successfully.';

  return PlatformInstitutionLifecycleResult(
    id: id,
    name: name,
    type: PlatformInstitutionType.school,
    status: status,
    contactEmail: 'info@example.uz',
    contactPhone: '+998901234567',
    address: 'Samarkand',
    description: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 10, 12),
    message: message,
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
        message: 'Server message must not control lifecycle flow.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Local lifecycle failure.'),
  );
}

class FakePlatformInstitutionLifecycleRepository
    implements PlatformInstitutionLifecycleRepository {
  FakePlatformInstitutionLifecycleRepository({
    this.onActivate,
    this.onDeactivate,
  });

  Future<PlatformInstitutionLifecycleResult> Function(String institutionId)?
  onActivate;
  Future<PlatformInstitutionLifecycleResult> Function(String institutionId)?
  onDeactivate;
  final activateInstitutionIds = <String>[];
  final deactivateInstitutionIds = <String>[];

  int get activateCalls => activateInstitutionIds.length;
  int get deactivateCalls => deactivateInstitutionIds.length;

  @override
  Future<PlatformInstitutionLifecycleResult> activateInstitution(
    String institutionId,
  ) {
    activateInstitutionIds.add(institutionId);

    return onActivate?.call(institutionId) ??
        Future.value(_result(id: institutionId));
  }

  @override
  Future<PlatformInstitutionLifecycleResult> deactivateInstitution(
    String institutionId,
  ) {
    deactivateInstitutionIds.add(institutionId);

    return onDeactivate?.call(institutionId) ??
        Future.value(
          _result(
            id: institutionId,
            status: PlatformInstitutionStatus.inactive,
          ),
        );
  }
}

class FakePlatformInstitutionDetailRepository
    implements PlatformInstitutionDetailRepository {
  FakePlatformInstitutionDetailRepository({this.onFetch});

  Future<PlatformInstitutionDetail> Function(String institutionId)? onFetch;
  final institutionIds = <String>[];

  int get fetchCalls => institutionIds.length;

  @override
  Future<PlatformInstitutionDetail> fetchInstitutionDetail(
    String institutionId,
  ) {
    institutionIds.add(institutionId);

    return onFetch?.call(institutionId) ??
        Future.value(_detail(id: institutionId));
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

  void setAuthenticated(AuthUser user) {
    state = AuthSessionState.authenticated(user);
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

const _institutionIdA = '550e8400-e29b-41d4-a716-446655440000';
const _institutionIdB = '550e8400-e29b-41d4-a716-446655440001';
