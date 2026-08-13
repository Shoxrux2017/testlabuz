import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_admin_create_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_admin_create_state.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_admin_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_lifecycle.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_update.dart';

void main() {
  group('PlatformInstitutionAdminCreateController', () {
    test(
      'initial state sends no request and invalid submit sends none',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);

        expect(
          subscription.read().status,
          PlatformInstitutionAdminCreateStatus.editing,
        );

        await container
            .read(
              platformInstitutionAdminCreateControllerProvider(key).notifier,
            )
            .submit(password: 'short');
        await _flush();

        expect(repository.createCalls, isEmpty);
        expect(
          subscription.read().status,
          PlatformInstitutionAdminCreateStatus.validationFailure,
        );
        expect(
          subscription.read().fieldErrors.keys,
          containsAll([
            PlatformInstitutionAdminCreateField.fullName,
            PlatformInstitutionAdminCreateField.loginName,
            PlatformInstitutionAdminCreateField.password,
          ]),
        );
      },
    );

    test(
      'one valid submit sends one exact request and ignores duplicate',
      () async {
        final owner = _owner('owner-a');
        final completer = Completer<PlatformInstitutionAdminCreateResult>();
        final repository = FakePlatformInstitutionAdminRepository(
          onCreate: (institutionId, request) => completer.future,
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminCreateControllerProvider(key).notifier,
        );

        _fillValid(controller);
        final submitA = controller.submit(password: 'valid-password');
        final submitB = controller.submit(password: 'valid-password');
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionAdminCreateStatus.submitting,
        );
        expect(repository.createCalls, hasLength(1));
        expect(repository.createCalls.single.institutionId, 'institution-a');
        expect(repository.createCalls.single.request.toJson(), {
          'full_name': 'Ali Valiyev',
          'login_name': 'Admin.MixedCase',
          'email': 'ali@example.uz',
          'phone': null,
          'password': 'valid-password',
        });

        completer.complete(_result());
        await submitA;
        await submitB;
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionAdminCreateStatus.success,
        );
        expect(repository.createCalls, hasLength(1));
        expect(subscription.read().passwordWipeGeneration, 1);
      },
    );

    test(
      'server validation maps only approved fields and form error',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository(
          onCreate: (institutionId, request) async =>
              throw _serverValidationFailure(),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminCreateControllerProvider(key).notifier,
        );

        _fillValid(controller);
        await controller.submit(password: 'valid-password');

        expect(
          subscription.read().fieldErrors.keys,
          containsAll([
            PlatformInstitutionAdminCreateField.loginName,
            PlatformInstitutionAdminCreateField.email,
            PlatformInstitutionAdminCreateField.password,
          ]),
        );
        expect(
          subscription.read().fieldErrors.keys,
          isNot(contains(PlatformInstitutionAdminCreateField.phone)),
        );
        expect(subscription.read().formError, isNotNull);

        controller.updateLoginName('Corrected.MixedCase');
        expect(
          subscription.read().fieldErrors.keys,
          isNot(contains(PlatformInstitutionAdminCreateField.loginName)),
        );
        expect(subscription.read().form.loginName, 'Corrected.MixedCase');
      },
    );

    test(
      'unknown outcome wipes password signal and preserves nonsecret form',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository(
          onCreate: (institutionId, request) async =>
              throw const PlatformInstitutionAdminCreateOutcomeUnknownException(
                'unknown',
              ),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminCreateControllerProvider(key).notifier,
        );

        _fillValid(controller);
        await controller.submit(password: 'valid-password');

        expect(
          subscription.read().status,
          PlatformInstitutionAdminCreateStatus.outcomeUnknown,
        );
        expect(subscription.read().form.fullName, 'Ali Valiyev');
        expect(subscription.read().form.loginName, 'Admin.MixedCase');
        expect(subscription.read().passwordWipeGeneration, 1);
        expect(subscription.read().canSubmit, isFalse);
        expect(repository.createCalls, hasLength(1));
      },
    );

    test('definite server failure preserves nonsecret form', () async {
      final owner = _owner('owner-a');
      final repository = FakePlatformInstitutionAdminRepository(
        onCreate: (institutionId, request) async =>
            throw _serverFailure(ApiErrorCodes.serverError, statusCode: 500),
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        repository: repository,
      );
      final key = _key(owner);
      final subscription = _listen(container, key);
      final controller = container.read(
        platformInstitutionAdminCreateControllerProvider(key).notifier,
      );

      _fillValid(controller);
      await controller.submit(password: 'valid-password');

      expect(
        subscription.read().status,
        PlatformInstitutionAdminCreateStatus.failure,
      );
      expect(subscription.read().form.fullName, 'Ali Valiyev');
      expect(subscription.read().passwordWipeGeneration, 0);
    });

    test('auth failures request session reconciliation', () async {
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
        final repository = FakePlatformInstitutionAdminRepository(
          onCreate: (institutionId, request) async => throw _serverFailure(
            testCase.code,
            statusCode: testCase.statusCode,
          ),
        );
        final container = _container(
          authController: authController,
          repository: repository,
        );
        final key = _key(owner);
        final controller = container.read(
          platformInstitutionAdminCreateControllerProvider(key).notifier,
        );

        _fillValid(controller);
        await controller.submit(password: 'valid-password');
        await _flush();

        expect(authController.bootstrapCalls, 1);
      }
    });
  });
}

ProviderContainer _container({
  required FakeAuthSessionController authController,
  required FakePlatformInstitutionAdminRepository repository,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      platformInstitutionAdminRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<PlatformInstitutionAdminCreateState> _listen(
  ProviderContainer container,
  PlatformInstitutionAdminCreateKey key,
) {
  final subscription = container.listen(
    platformInstitutionAdminCreateControllerProvider(key),
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

void _fillValid(PlatformInstitutionAdminCreateController controller) {
  controller
    ..updateFullName('Ali Valiyev')
    ..updateLoginName('Admin.MixedCase')
    ..updateEmail('ali@example.uz')
    ..updatePhone('');
}

PlatformInstitutionAdminCreateKey _key(AuthUser user) {
  return PlatformInstitutionAdminCreateKey(
    sessionUserId: user.id,
    sessionInstanceId: identityHashCode(user),
    institutionId: 'institution-a',
  );
}

PlatformInstitutionAdminCreateResult _result() {
  return PlatformInstitutionAdminCreateResult(
    admin: _admin(),
    message: 'Institution administrator created.',
  );
}

PlatformInstitutionAdmin _admin({String loginName = 'Admin.MixedCase'}) {
  return PlatformInstitutionAdmin(
    id: '550e8400-e29b-41d4-a716-446655440001',
    fullName: 'Ali Valiyev',
    loginName: loginName,
    email: 'ali@example.uz',
    phone: null,
    isActive: true,
    mustChangePassword: true,
    lastLoginAt: null,
    deactivatedAt: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
  );
}

PlatformInstitutionAdminList _page() {
  return PlatformInstitutionAdminList(
    admins: [_admin()],
    pagination: const PlatformInstitutionAdminPagination(
      page: 1,
      perPage: 20,
      total: 1,
      lastPage: 1,
    ),
  );
}

AuthUser _owner(String loginName, {bool mustChangePassword = false}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: null,
    role: UserRole.platformOwner,
    fullName: '$loginName User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: mustChangePassword,
    institution: null,
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
          'login_name': ['The login name has already been used.'],
          'email': ['The email must be valid.'],
          'password': ['The password must be at least 8 characters.'],
          'role': ['This field is not allowed.'],
        },
        requestId: 'req-1',
      ),
    ),
  );
}

class FakePlatformInstitutionAdminRepository
    implements PlatformInstitutionAdminRepository {
  FakePlatformInstitutionAdminRepository({this.onFetch, this.onCreate});

  Future<PlatformInstitutionAdminList> Function(
    String institutionId,
    PlatformInstitutionAdminListQuery query,
  )?
  onFetch;
  Future<PlatformInstitutionAdminCreateResult> Function(
    String institutionId,
    PlatformInstitutionAdminCreateRequest request,
  )?
  onCreate;
  final createCalls =
      <
        ({String institutionId, PlatformInstitutionAdminCreateRequest request})
      >[];

  @override
  Future<PlatformInstitutionAdminList> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  }) {
    return onFetch?.call(institutionId, query) ?? Future.value(_page());
  }

  @override
  Future<PlatformInstitutionAdminCreateResult> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  }) {
    createCalls.add((institutionId: institutionId, request: request));

    return onCreate?.call(institutionId, request) ?? Future.value(_result());
  }

  @override
  Future<PlatformInstitutionAdminUpdateResult> updateAdmin({
    required String adminId,
    required PlatformInstitutionAdminUpdateRequest request,
  }) {
    throw UnimplementedError('Create controller tests do not update admins.');
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> activateAdmin({
    required String adminId,
  }) {
    throw UnimplementedError('Create controller tests do not activate admins.');
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> deactivateAdmin({
    required String adminId,
  }) {
    throw UnimplementedError(
      'Create controller tests do not deactivate admins.',
    );
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
}
