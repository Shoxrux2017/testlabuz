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
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_admin_action_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_admin_action_state.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_admin_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_lifecycle.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_update.dart';

void main() {
  group('PlatformInstitutionAdminActionController', () {
    test('no-change edit sends no request and keeps dialog editable', () async {
      final owner = _owner('owner-a');
      final repository = FakePlatformInstitutionAdminRepository();
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        repository: repository,
      );
      final key = _key(owner);
      final subscription = _listen(container, key);
      final controller = container.read(
        platformInstitutionAdminActionControllerProvider(key).notifier,
      );

      expect(controller.beginEdit(_admin()), isTrue);
      await controller.submitEdit();
      await _flush();

      expect(repository.updateCalls, isEmpty);
      expect(
        subscription.read().status,
        PlatformInstitutionAdminActionStatus.validationFailure,
      );
      expect(
        subscription.read().formError,
        'No administrator changes to save.',
      );
      expect(subscription.read().canSubmitEdit, isTrue);
    });

    test('changed edit fields submit once without protected fields', () async {
      final owner = _owner('owner-a');
      final completer = Completer<PlatformInstitutionAdminUpdateResult>();
      final repository = FakePlatformInstitutionAdminRepository(
        onUpdate: (_, _) => completer.future,
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        repository: repository,
      );
      final key = _key(owner);
      final subscription = _listen(container, key);
      final controller = container.read(
        platformInstitutionAdminActionControllerProvider(key).notifier,
      );

      expect(controller.beginEdit(_admin()), isTrue);
      controller
        ..updateFullName(' Updated Institution Admin ')
        ..updateEmail('   ')
        ..updatePhone('  +998901234567  ');
      final submitA = controller.submitEdit();
      final submitB = controller.submitEdit();
      await _flush();

      expect(
        subscription.read().status,
        PlatformInstitutionAdminActionStatus.editSubmitting,
      );
      expect(repository.updateCalls, hasLength(1));
      expect(repository.updateCalls.single.adminId, _adminId);
      expect(repository.updateCalls.single.request.toJson(), {
        'full_name': 'Updated Institution Admin',
        'email': null,
        'phone': '+998901234567',
      });
      expect(
        repository.updateCalls.single.request.toJson().keys,
        isNot(
          containsAll([
            'login_name',
            'password',
            'role',
            'institution_id',
            'is_active',
            'must_change_password',
          ]),
        ),
      );

      completer.complete(
        _updateResult(
          fullName: 'Updated Institution Admin',
          email: null,
          phone: '+998901234567',
        ),
      );
      await submitA;
      await submitB;
      await _flush();

      expect(
        subscription.read().status,
        PlatformInstitutionAdminActionStatus.success,
      );
      expect(
        subscription.read().completion?.kind,
        PlatformInstitutionAdminActionCompletionKind.profileUpdated,
      );
      expect(repository.updateCalls, hasLength(1));
    });

    test(
      'edit validation maps only approved fields plus form fallback',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository(
          onUpdate: (_, _) async => throw _serverValidationFailure(),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminActionControllerProvider(key).notifier,
        );

        controller.beginEdit(_admin());
        controller.updateEmail('changed@example.uz');
        await controller.submitEdit();

        expect(
          subscription.read().status,
          PlatformInstitutionAdminActionStatus.validationFailure,
        );
        expect(
          subscription.read().fieldErrors.keys,
          containsAll([
            PlatformInstitutionAdminEditField.fullName,
            PlatformInstitutionAdminEditField.email,
            PlatformInstitutionAdminEditField.phone,
          ]),
        );
        expect(subscription.read().fieldErrors.keys, hasLength(3));
        expect(subscription.read().formError, isNotNull);

        controller.updateEmail('corrected@example.uz');
        expect(
          subscription.read().fieldErrors.keys,
          isNot(contains(PlatformInstitutionAdminEditField.email)),
        );
      },
    );

    test('state-appropriate lifecycle action submits once', () async {
      final owner = _owner('owner-a');
      final completer = Completer<PlatformInstitutionAdminLifecycleResult>();
      final repository = FakePlatformInstitutionAdminRepository(
        onDeactivate: (_) => completer.future,
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        repository: repository,
      );
      final key = _key(owner);
      final subscription = _listen(container, key);
      final controller = container.read(
        platformInstitutionAdminActionControllerProvider(key).notifier,
      );

      expect(controller.beginLifecycle(_admin()), isTrue);
      expect(
        subscription.read().snapshot?.lifecycleAction,
        PlatformInstitutionAdminLifecycleAction.deactivate,
      );
      final confirmA = controller.confirmLifecycle();
      final confirmB = controller.confirmLifecycle();
      await _flush();

      expect(repository.deactivateAdminIds, [_adminId]);
      expect(repository.activateAdminIds, isEmpty);
      expect(
        subscription.read().status,
        PlatformInstitutionAdminActionStatus.lifecycleSubmitting,
      );

      completer.complete(_lifecycleResult(isActive: false));
      await confirmA;
      await confirmB;
      await _flush();

      expect(
        subscription.read().status,
        PlatformInstitutionAdminActionStatus.success,
      );
      expect(
        subscription.read().completion?.lifecycleAction,
        PlatformInstitutionAdminLifecycleAction.deactivate,
      );
      expect(repository.deactivateAdminIds, [_adminId]);
    });

    test('inactive admin opens activate action', () {
      final owner = _owner('owner-a');
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        repository: FakePlatformInstitutionAdminRepository(),
      );
      final key = _key(owner);
      final subscription = _listen(container, key);
      final controller = container.read(
        platformInstitutionAdminActionControllerProvider(key).notifier,
      );

      expect(controller.beginLifecycle(_admin(isActive: false)), isTrue);
      expect(
        subscription.read().snapshot?.lifecycleAction,
        PlatformInstitutionAdminLifecycleAction.activate,
      );
    });

    test(
      'edit target 404 preserves completion identity and refreshes current list once',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository(
          onUpdate: (_, _) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminActionControllerProvider(key).notifier,
        );

        controller.beginEdit(_admin());
        final actionGeneration = subscription.read().snapshot!.actionGeneration;
        controller.updateFullName('Updated');
        await controller.submitEdit();
        await _flush();

        final state = subscription.read();
        expect(
          state.status,
          PlatformInstitutionAdminActionStatus.targetUnavailable,
        );
        expect(state.snapshot, isNotNull);
        expect(state.snapshot!.institutionId, 'institution-a');
        expect(state.snapshot!.adminId, _adminId);
        expect(state.snapshot!.loginName, 'admin.school1');
        expect(state.snapshot!.sessionUserId, owner.id);
        expect(state.snapshot!.sessionInstanceId, identityHashCode(owner));
        expect(state.snapshot!.actionGeneration, actionGeneration);
        expect(state.snapshot!.kind, PlatformInstitutionAdminActionKind.edit);
        expect(state.snapshot!.lifecycleAction, isNull);
        expect(state.form, isNotNull);
        expect(state.isEditDialogState, isTrue);
        expect(state.isLifecycleDialogState, isFalse);
        expect(
          state.completion?.kind,
          PlatformInstitutionAdminActionCompletionKind.targetUnavailable,
        );
        expect(state.message, 'Administrator is no longer available.');
        expect(repository.updateCalls, hasLength(1));
        expect(repository.updateCalls.single.adminId, _adminId);
        expect(repository.fetchCalls, hasLength(1));
        expect(repository.fetchCalls.single.institutionId, 'institution-a');
        expect(repository.activateAdminIds, isEmpty);
        expect(repository.deactivateAdminIds, isEmpty);

        controller.resetAfterCompletion();
        expect(
          subscription.read().status,
          PlatformInstitutionAdminActionStatus.idle,
        );
        expect(subscription.read().snapshot, isNull);
        expect(subscription.read().form, isNull);
        expect(subscription.read().completion, isNull);
      },
    );

    test(
      'lifecycle target 404 preserves action identity and refreshes current list once',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository(
          onDeactivate: (_) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminActionControllerProvider(key).notifier,
        );

        controller.beginLifecycle(_admin());
        final actionGeneration = subscription.read().snapshot!.actionGeneration;
        await controller.confirmLifecycle();
        await _flush();

        final state = subscription.read();
        expect(
          state.status,
          PlatformInstitutionAdminActionStatus.targetUnavailable,
        );
        expect(state.snapshot, isNotNull);
        expect(state.snapshot!.institutionId, 'institution-a');
        expect(state.snapshot!.adminId, _adminId);
        expect(state.snapshot!.loginName, 'admin.school1');
        expect(state.snapshot!.sessionUserId, owner.id);
        expect(state.snapshot!.sessionInstanceId, identityHashCode(owner));
        expect(state.snapshot!.actionGeneration, actionGeneration);
        expect(
          state.snapshot!.kind,
          PlatformInstitutionAdminActionKind.lifecycle,
        );
        expect(
          state.snapshot!.lifecycleAction,
          PlatformInstitutionAdminLifecycleAction.deactivate,
        );
        expect(state.form, isNull);
        expect(state.isEditDialogState, isFalse);
        expect(state.isLifecycleDialogState, isTrue);
        expect(
          state.completion?.kind,
          PlatformInstitutionAdminActionCompletionKind.targetUnavailable,
        );
        expect(state.completion?.lifecycleAction, isNull);
        expect(state.message, 'Administrator is no longer available.');
        expect(repository.deactivateAdminIds, [_adminId]);
        expect(repository.activateAdminIds, isEmpty);
        expect(repository.updateCalls, isEmpty);
        expect(repository.fetchCalls, hasLength(1));
        expect(repository.fetchCalls.single.institutionId, 'institution-a');

        controller.resetAfterCompletion();
        expect(
          subscription.read().status,
          PlatformInstitutionAdminActionStatus.idle,
        );
        expect(subscription.read().snapshot, isNull);
        expect(subscription.read().completion, isNull);
      },
    );

    test(
      'target 404 completion after session invalidation is ignored without retry',
      () async {
        final owner = _owner('owner-a');
        final authController = FakeAuthSessionController.authenticated(owner);
        final refreshCompleter = Completer<PlatformInstitutionAdminList>();
        final repository = FakePlatformInstitutionAdminRepository(
          onUpdate: (_, _) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
          onFetch: (_, _) => refreshCompleter.future,
        );
        final container = _container(
          authController: authController,
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminActionControllerProvider(key).notifier,
        );

        controller.beginEdit(_admin());
        controller.updateFullName('Updated');
        final submit = controller.submitEdit();
        await _flush();

        expect(repository.updateCalls, hasLength(1));
        expect(repository.fetchCalls, hasLength(1));

        authController.markUnauthenticated();
        await _flush();
        refreshCompleter.complete(
          _page(admins: const [], query: repository.fetchCalls.single.query),
        );
        await submit;
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionAdminActionStatus.idle,
        );
        expect(subscription.read().snapshot, isNull);
        expect(subscription.read().completion, isNull);
        expect(repository.updateCalls, hasLength(1));
        expect(repository.fetchCalls, hasLength(1));
        expect(repository.activateAdminIds, isEmpty);
        expect(repository.deactivateAdminIds, isEmpty);
      },
    );

    test(
      'auth and password-state failures request global reconciliation',
      () async {
        final cases = [
          (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
          (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
          (statusCode: 403, code: ApiErrorCodes.userInactive),
          (statusCode: 403, code: ApiErrorCodes.institutionInactive),
        ];

        for (final testCase in cases) {
          final owner = _owner('owner-a');
          final authController = FakeAuthSessionController.authenticated(owner);
          final repository = FakePlatformInstitutionAdminRepository(
            onDeactivate: (_) async => throw _serverFailure(
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
            platformInstitutionAdminActionControllerProvider(key).notifier,
          );

          controller.beginLifecycle(_admin());
          await controller.confirmLifecycle();
          await _flush();

          expect(authController.bootstrapCalls, 1);
        }
      },
    );

    test(
      'unknown update performs one exact reconciliation GET and accepts ID match',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository(
          onUpdate: (_, _) async =>
              throw const PlatformInstitutionAdminMutationOutcomeUnknownException(),
          onFetch: (institutionId, query) async => _page(
            admins: [
              _admin(id: '550e8400-e29b-41d4-a716-446655440009'),
              _admin(fullName: 'Updated', email: null),
            ],
            query: query,
          ),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminActionControllerProvider(key).notifier,
        );

        controller.beginEdit(_admin());
        controller
          ..updateFullName('Updated')
          ..updateEmail('');
        await controller.submitEdit();
        await _flush();

        expect(repository.updateCalls, hasLength(1));
        expect(repository.fetchCalls, hasLength(1));
        expect(repository.fetchCalls.single.institutionId, 'institution-a');
        expect(repository.fetchCalls.single.query.toQueryParameters(), {
          'page': 1,
          'per_page': 100,
          'sort': 'login_name',
          'direction': 'asc',
          'search': 'admin.school1',
        });
        expect(
          subscription.read().status,
          PlatformInstitutionAdminActionStatus.success,
        );
        expect(
          subscription.read().completion?.kind,
          PlatformInstitutionAdminActionCompletionKind.profileUpdated,
        );
      },
    );

    test(
      'unknown update mismatch absent and fetch error remain unresolved',
      () async {
        final cases = [
          (
            onFetch:
                (
                  String institutionId,
                  PlatformInstitutionAdminListQuery query,
                ) async => _page(
                  admins: [_admin(fullName: 'Still old')],
                  query: query,
                ),
            message: contains('Current server profile'),
          ),
          (
            onFetch:
                (
                  String institutionId,
                  PlatformInstitutionAdminListQuery query,
                ) async => _page(admins: const [], query: query),
            message: contains('was not found'),
          ),
          (
            onFetch:
                (
                  String institutionId,
                  PlatformInstitutionAdminListQuery query,
                ) async => throw _serverFailure(
                  ApiErrorCodes.serverError,
                  statusCode: 500,
                ),
            message: contains('Refresh administrators'),
          ),
        ];

        for (final testCase in cases) {
          final owner = _owner('owner-a');
          final repository = FakePlatformInstitutionAdminRepository(
            onUpdate: (_, _) async =>
                throw const PlatformInstitutionAdminMutationOutcomeUnknownException(),
            onFetch: testCase.onFetch,
          );
          final container = _container(
            authController: FakeAuthSessionController.authenticated(owner),
            repository: repository,
          );
          final key = _key(owner);
          final subscription = _listen(container, key);
          final controller = container.read(
            platformInstitutionAdminActionControllerProvider(key).notifier,
          );

          controller.beginEdit(_admin());
          controller.updateFullName('Updated');
          await controller.submitEdit();
          await _flush();

          expect(
            subscription.read().status,
            PlatformInstitutionAdminActionStatus.unknownOutcome,
          );
          expect(subscription.read().message, testCase.message);
          expect(repository.updateCalls, hasLength(1));
          expect(repository.fetchCalls, hasLength(1));
          expect(repository.activateAdminIds, isEmpty);
          expect(repository.deactivateAdminIds, isEmpty);
        }
      },
    );

    test(
      'unknown lifecycle reconciles desired state by exact target ID',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository(
          onDeactivate: (_) async =>
              throw const PlatformInstitutionAdminMutationOutcomeUnknownException(),
          onFetch: (institutionId, query) async => _page(
            admins: [
              _admin(id: '550e8400-e29b-41d4-a716-446655440009'),
              _admin(isActive: false),
            ],
            query: query,
          ),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminActionControllerProvider(key).notifier,
        );

        controller.beginLifecycle(_admin());
        await controller.confirmLifecycle();
        await _flush();

        expect(repository.deactivateAdminIds, [_adminId]);
        expect(repository.fetchCalls, hasLength(1));
        expect(
          subscription.read().status,
          PlatformInstitutionAdminActionStatus.success,
        );
        expect(
          subscription.read().completion?.kind,
          PlatformInstitutionAdminActionCompletionKind.lifecycleChanged,
        );
      },
    );

    test(
      'old completion after account switch cannot affect new session',
      () async {
        final owner = _owner('owner-a');
        final authController = FakeAuthSessionController.authenticated(owner);
        final completer = Completer<PlatformInstitutionAdminUpdateResult>();
        final repository = FakePlatformInstitutionAdminRepository(
          onUpdate: (_, _) => completer.future,
        );
        final container = _container(
          authController: authController,
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        final controller = container.read(
          platformInstitutionAdminActionControllerProvider(key).notifier,
        );

        controller.beginEdit(_admin());
        controller.updateFullName('Updated');
        final submit = controller.submitEdit();
        await _flush();

        authController.markUnauthenticated();
        await _flush();
        completer.complete(_updateResult(fullName: 'Updated'));
        await submit;
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionAdminActionStatus.idle,
        );
        expect(subscription.read().completion, isNull);
        expect(repository.updateCalls, hasLength(1));
      },
    );
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

ProviderSubscription<PlatformInstitutionAdminActionState> _listen(
  ProviderContainer container,
  PlatformInstitutionAdminActionKey key,
) {
  final subscription = container.listen(
    platformInstitutionAdminActionControllerProvider(key),
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

PlatformInstitutionAdminActionKey _key(AuthUser user) {
  return PlatformInstitutionAdminActionKey(
    sessionUserId: user.id,
    sessionInstanceId: identityHashCode(user),
    institutionId: 'institution-a',
  );
}

PlatformInstitutionAdminUpdateResult _updateResult({
  String fullName = 'Ali Valiyev',
  String? email = 'ali@example.uz',
  String? phone,
}) {
  return PlatformInstitutionAdminUpdateResult(
    admin: _admin(fullName: fullName, email: email, phone: phone),
    message: 'Institution admin updated successfully.',
  );
}

PlatformInstitutionAdminLifecycleResult _lifecycleResult({
  required bool isActive,
}) {
  final action = isActive
      ? PlatformInstitutionAdminLifecycleAction.activate
      : PlatformInstitutionAdminLifecycleAction.deactivate;
  return PlatformInstitutionAdminLifecycleResult(
    admin: _admin(isActive: isActive),
    message: action.successMessage,
    action: action,
  );
}

PlatformInstitutionAdminList _page({
  required List<PlatformInstitutionAdmin> admins,
  PlatformInstitutionAdminListQuery query =
      const PlatformInstitutionAdminListQuery.initial(),
}) {
  return PlatformInstitutionAdminList(
    admins: admins,
    pagination: PlatformInstitutionAdminPagination(
      page: query.page,
      perPage: query.perPage,
      total: admins.length,
      lastPage: 1,
    ),
  );
}

PlatformInstitutionAdmin _admin({
  String id = _adminId,
  String fullName = 'Ali Valiyev',
  String loginName = 'admin.school1',
  String? email = 'ali@example.uz',
  String? phone,
  bool isActive = true,
  bool mustChangePassword = true,
}) {
  return PlatformInstitutionAdmin(
    id: id,
    fullName: fullName,
    loginName: loginName,
    email: email,
    phone: phone,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    lastLoginAt: null,
    deactivatedAt: isActive ? null : DateTime.utc(2026, 8, 8, 9),
    createdAt: DateTime.utc(2026, 8, 10, 10),
    updatedAt: DateTime.utc(2026, 8, 10, 10),
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
        message: 'Server message must not control admin action flow.',
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
          'full_name': ['The full name field is required.'],
          'email': ['The email must be valid.'],
          'phone': ['The phone must be 50 characters or fewer.'],
          'role': ['This field is not allowed.'],
        },
        requestId: 'req-1',
      ),
    ),
  );
}

class FakePlatformInstitutionAdminRepository
    implements PlatformInstitutionAdminRepository {
  FakePlatformInstitutionAdminRepository({
    this.onFetch,
    this.onCreate,
    this.onUpdate,
    this.onActivate,
    this.onDeactivate,
  });

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
  Future<PlatformInstitutionAdminUpdateResult> Function(
    String adminId,
    PlatformInstitutionAdminUpdateRequest request,
  )?
  onUpdate;
  Future<PlatformInstitutionAdminLifecycleResult> Function(String adminId)?
  onActivate;
  Future<PlatformInstitutionAdminLifecycleResult> Function(String adminId)?
  onDeactivate;

  final fetchCalls =
      <({String institutionId, PlatformInstitutionAdminListQuery query})>[];
  final createCalls =
      <
        ({String institutionId, PlatformInstitutionAdminCreateRequest request})
      >[];
  final updateCalls =
      <({String adminId, PlatformInstitutionAdminUpdateRequest request})>[];
  final activateAdminIds = <String>[];
  final deactivateAdminIds = <String>[];

  @override
  Future<PlatformInstitutionAdminList> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  }) {
    fetchCalls.add((institutionId: institutionId, query: query));

    return onFetch?.call(institutionId, query) ??
        Future.value(_page(admins: [_admin()], query: query));
  }

  @override
  Future<PlatformInstitutionAdminCreateResult> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  }) {
    createCalls.add((institutionId: institutionId, request: request));

    return onCreate?.call(institutionId, request) ??
        Future.value(
          PlatformInstitutionAdminCreateResult(
            admin: _admin(),
            message: 'Institution administrator created.',
          ),
        );
  }

  @override
  Future<PlatformInstitutionAdminUpdateResult> updateAdmin({
    required String adminId,
    required PlatformInstitutionAdminUpdateRequest request,
  }) {
    updateCalls.add((adminId: adminId, request: request));

    return onUpdate?.call(adminId, request) ?? Future.value(_updateResult());
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> activateAdmin({
    required String adminId,
  }) {
    activateAdminIds.add(adminId);

    return onActivate?.call(adminId) ??
        Future.value(_lifecycleResult(isActive: true));
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> deactivateAdmin({
    required String adminId,
  }) {
    deactivateAdminIds.add(adminId);

    return onDeactivate?.call(adminId) ??
        Future.value(_lifecycleResult(isActive: false));
  }
}

class FakeAuthSessionController extends AuthSessionController {
  FakeAuthSessionController(this.initialState);

  factory FakeAuthSessionController.authenticated(AuthUser user) {
    return FakeAuthSessionController(AuthSessionState.authenticated(user));
  }

  final AuthSessionState initialState;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() {
    return initialState;
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
  }

  void markUnauthenticated() {
    state = const AuthSessionState.unauthenticated();
  }
}

const _adminId = '550e8400-e29b-41d4-a716-446655440001';
