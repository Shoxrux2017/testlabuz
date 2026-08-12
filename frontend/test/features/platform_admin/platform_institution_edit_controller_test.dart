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
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_detail_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_detail_state.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_edit_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_edit_state.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_list_controller.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_edit_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_edit.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_edit_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('PlatformInstitutionEditController', () {
    test(
      'loads current server detail once and initializes exact form',
      () async {
        final owner = _owner('owner-a');
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) async => _detail(
            id: institutionId,
            name: 'Loaded School',
            type: PlatformInstitutionType.college,
            status: PlatformInstitutionStatus.inactive,
            contactEmail: null,
            contactPhone: '+998901234567',
            address: 'Samarkand',
            description: null,
          ),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          detailRepository: detailRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);

        await _flush();

        expect(subscription.read().status, PlatformInstitutionEditStatus.ready);
        expect(
          subscription.read().detail?.status,
          PlatformInstitutionStatus.inactive,
        );
        expect(subscription.read().form?.name, 'Loaded School');
        expect(subscription.read().form?.type, PlatformInstitutionType.college);
        expect(subscription.read().form?.contactEmail, '');
        expect(subscription.read().form?.contactPhone, '+998901234567');
        expect(subscription.read().form?.address, 'Samarkand');
        expect(subscription.read().form?.description, '');
        expect(subscription.read().initialSnapshot?.contactEmail, isNull);
        expect(detailRepository.institutionIds, [_institutionIdA]);

        container.read(platformInstitutionEditControllerProvider(key));
        container.read(platformInstitutionEditControllerProvider(key));
        await _flush();

        expect(detailRepository.fetchCalls, 1);
      },
    );

    test('load not-found and retryable error behave safely', () async {
      final owner = _owner('owner-a');
      final notFoundRepository = FakePlatformInstitutionDetailRepository(
        onFetch: (_) async => throw _serverFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      );
      final notFoundContainer = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        detailRepository: notFoundRepository,
      );
      final notFoundSubscription = _listen(notFoundContainer, _key(owner));

      await _flush();

      expect(
        notFoundSubscription.read().status,
        PlatformInstitutionEditStatus.notFound,
      );
      expect(notFoundSubscription.read().form, isNull);

      final retryCompleter = Completer<PlatformInstitutionDetail>();
      final retryRepository = FakePlatformInstitutionDetailRepository();
      retryRepository.onFetch = (institutionId) {
        if (retryRepository.fetchCalls == 1) {
          throw _localFailure(ApiFailureKind.connection);
        }

        return retryCompleter.future;
      };
      final retryContainer = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        detailRepository: retryRepository,
      );
      final retryKey = _key(owner);
      final retrySubscription = _listen(retryContainer, retryKey);
      await _flush();

      expect(
        retrySubscription.read().status,
        PlatformInstitutionEditStatus.loadError,
      );
      final retryA = retryContainer
          .read(platformInstitutionEditControllerProvider(retryKey).notifier)
          .retry();
      final retryB = retryContainer
          .read(platformInstitutionEditControllerProvider(retryKey).notifier)
          .retry();
      await _flush();

      expect(retryRepository.fetchCalls, 2);
      expect(retrySubscription.read().isRetryInFlight, isTrue);

      retryCompleter.complete(_detail(name: 'Retry School'));
      await retryA;
      await retryB;
      await _flush();

      expect(
        retrySubscription.read().status,
        PlatformInstitutionEditStatus.ready,
      );
      expect(retrySubscription.read().form?.name, 'Retry School');
      expect(retryRepository.fetchCalls, 2);
    });

    test('no-change and reverted edits do not issue PATCH', () async {
      final owner = _owner('owner-a');
      final editRepository = FakePlatformInstitutionEditRepository();
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        editRepository: editRepository,
      );
      final key = _key(owner);
      final subscription = _listen(container, key);
      await _flush();
      final controller = container.read(
        platformInstitutionEditControllerProvider(key).notifier,
      );

      await controller.submit();
      await _flush();
      expect(editRepository.updateCalls, 0);
      expect(subscription.read().formError, 'No changes to save.');

      controller
        ..updateName('Temporary')
        ..updateName(' Example School ');
      await controller.submit();
      await _flush();

      expect(editRepository.updateCalls, 0);
      expect(subscription.read().formError, 'No changes to save.');
    });

    test(
      'changed fields only and nullable clearing are submitted once',
      () async {
        final owner = _owner('owner-a');
        final completer = Completer<PlatformInstitutionEditResult>();
        final editRepository = FakePlatformInstitutionEditRepository(
          onUpdate: (_, _) => completer.future,
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          editRepository: editRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        await _flush();
        final controller = container.read(
          platformInstitutionEditControllerProvider(key).notifier,
        );

        controller
          ..updateName(' Updated Name ')
          ..updateContactEmail('   ')
          ..updateDescription('  New\nNotes  ');
        final submitA = controller.submit();
        final submitB = controller.submit();
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionEditStatus.submitting,
        );
        expect(editRepository.updateCalls, 1);
        expect(editRepository.institutionIds, [_institutionIdA]);
        expect(editRepository.requests.single.toJson(), {
          'name': 'Updated Name',
          'contact_email': null,
          'description': '  New\nNotes  ',
        });

        completer.complete(_result(name: 'Updated Name'));
        await submitA;
        await submitB;
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionEditStatus.success,
        );
        expect(editRepository.updateCalls, 1);
      },
    );

    test(
      'server validation maps six fields plus fallback and clears one field',
      () async {
        final owner = _owner('owner-a');
        final editRepository = FakePlatformInstitutionEditRepository(
          onUpdate: (_, _) async => throw _serverValidationFailure(),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          editRepository: editRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        await _flush();
        final controller = container.read(
          platformInstitutionEditControllerProvider(key).notifier,
        );

        controller
          ..updateName('Backend rejected')
          ..updateContactEmail('invalid@example.uz');
        await controller.submit();

        expect(
          subscription.read().status,
          PlatformInstitutionEditStatus.validationFailure,
        );
        expect(
          subscription.read().fieldErrors.keys,
          containsAll([
            PlatformInstitutionEditField.name,
            PlatformInstitutionEditField.type,
            PlatformInstitutionEditField.contactEmail,
            PlatformInstitutionEditField.contactPhone,
            PlatformInstitutionEditField.address,
            PlatformInstitutionEditField.description,
          ]),
        );
        expect(subscription.read().formError, isNotNull);

        controller.updateName('Corrected');

        expect(
          subscription.read().fieldErrors.keys,
          isNot(contains(PlatformInstitutionEditField.name)),
        );
        expect(
          subscription.read().fieldErrors.keys,
          contains(PlatformInstitutionEditField.contactEmail),
        );
        expect(subscription.read().form?.name, 'Corrected');
      },
    );

    test(
      'auth not-found definite and ambiguous mutation failures are safe',
      () async {
        final owner = _owner('owner-a');
        final cases = [
          (
            exception: _serverFailure(
              ApiErrorCodes.resourceNotFound,
              statusCode: 404,
            ),
            expected: PlatformInstitutionEditStatus.notFound,
            bootstrap: false,
          ),
          (
            exception: _serverFailure(ApiErrorCodes.forbidden, statusCode: 403),
            expected: PlatformInstitutionEditStatus.accessDenied,
            bootstrap: false,
          ),
          (
            exception: _serverFailure(
              ApiErrorCodes.serverError,
              statusCode: 500,
            ),
            expected: PlatformInstitutionEditStatus.failure,
            bootstrap: false,
          ),
          (
            exception: _serverFailure(
              ApiErrorCodes.authenticationRequired,
              statusCode: 401,
            ),
            expected: PlatformInstitutionEditStatus.failure,
            bootstrap: true,
          ),
        ];

        for (final testCase in cases) {
          final authController = FakeAuthSessionController.authenticated(owner);
          final editRepository = FakePlatformInstitutionEditRepository(
            onUpdate: (_, _) async => throw testCase.exception,
          );
          final container = _container(
            authController: authController,
            editRepository: editRepository,
          );
          final key = _key(owner);
          final subscription = _listen(container, key);
          await _flush();

          final controller = container.read(
            platformInstitutionEditControllerProvider(key).notifier,
          );
          controller.updateName('Changed');
          await controller.submit();
          await _flush();

          expect(subscription.read().status, testCase.expected);
          expect(authController.bootstrapCalls, testCase.bootstrap ? 1 : 0);
        }

        final unknownRepository = FakePlatformInstitutionEditRepository(
          onUpdate: (_, _) async =>
              throw const PlatformInstitutionEditOutcomeUnknownException(
                'unknown',
              ),
        );
        final unknownContainer = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          editRepository: unknownRepository,
        );
        final unknownKey = _key(owner);
        final unknownSubscription = _listen(unknownContainer, unknownKey);
        await _flush();
        final unknownController = unknownContainer.read(
          platformInstitutionEditControllerProvider(unknownKey).notifier,
        );

        unknownController.updateName('Maybe Changed');
        await unknownController.submit();
        await _flush();

        expect(
          unknownSubscription.read().status,
          PlatformInstitutionEditStatus.outcomeUnknown,
        );
        expect(unknownSubscription.read().form?.name, 'Maybe Changed');
        expect(unknownSubscription.read().canSubmit, isFalse);
        await unknownController.submit();
        expect(unknownRepository.updateCalls, 1);
      },
    );

    test(
      'confirmed success avoids hidden detail list dashboard refresh requests',
      () async {
        final owner = _owner('owner-a');
        final detailRepository = FakePlatformInstitutionDetailRepository();
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();
        final editRepository = FakePlatformInstitutionEditRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          detailRepository: detailRepository,
          editRepository: editRepository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        final editKey = _key(owner);
        final detailKey = PlatformInstitutionDetailKey(
          sessionUserId: owner.id,
          sessionInstanceId: identityHashCode(owner),
          institutionId: _institutionIdA,
        );
        final detailSubscription = container.listen(
          platformInstitutionDetailControllerProvider(detailKey),
          (_, _) {},
          fireImmediately: true,
        );
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
        addTearDown(detailSubscription.close);
        addTearDown(listSubscription.close);
        addTearDown(dashboardSubscription.close);
        await _flush();

        expect(detailRepository.fetchCalls, 1);
        expect(listRepository.fetchCalls, 1);
        expect(dashboardRepository.fetchCalls, 1);

        final editSubscription = _listen(container, editKey);
        await _flush();
        expect(detailRepository.fetchCalls, 2);

        final controller = container.read(
          platformInstitutionEditControllerProvider(editKey).notifier,
        );
        controller.updateName('Updated Name');
        await controller.submit();
        await _flush();

        expect(
          editSubscription.read().status,
          PlatformInstitutionEditStatus.success,
        );
        expect(editRepository.updateCalls, 1);
        expect(detailRepository.fetchCalls, 2);
        expect(listRepository.fetchCalls, 1);
        expect(dashboardRepository.fetchCalls, 1);
      },
    );

    test(
      'success without active caches issues no hidden refresh requests',
      () async {
        final owner = _owner('owner-a');
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();
        final editRepository = FakePlatformInstitutionEditRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          editRepository: editRepository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);
        await _flush();

        final controller = container.read(
          platformInstitutionEditControllerProvider(key).notifier,
        );
        controller.updateName('Updated Name');
        await controller.submit();
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionEditStatus.success,
        );
        expect(editRepository.updateCalls, 1);
        expect(listRepository.fetchCalls, 0);
        expect(dashboardRepository.fetchCalls, 0);

        final detailSubscription = container.listen(
          platformInstitutionDetailControllerProvider(
            PlatformInstitutionDetailKey(
              sessionUserId: owner.id,
              sessionInstanceId: identityHashCode(owner),
              institutionId: _institutionIdA,
            ),
          ),
          (_, _) {},
          fireImmediately: true,
        );
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
        addTearDown(detailSubscription.close);
        addTearDown(listSubscription.close);
        addTearDown(dashboardSubscription.close);
        await _flush();

        expect(listRepository.fetchCalls, 1);
        expect(dashboardRepository.fetchCalls, 1);
      },
    );

    test(
      'late load and patch completions after route or session change are ignored',
      () async {
        final ownerA = _owner('owner-a');
        final detailA = Completer<PlatformInstitutionDetail>();
        final detailB = Completer<PlatformInstitutionDetail>();
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) {
            if (institutionId == _institutionIdA) {
              return detailA.future;
            }

            return detailB.future;
          },
        );
        final authController = FakeAuthSessionController.authenticated(ownerA);
        final container = _container(
          authController: authController,
          detailRepository: detailRepository,
        );
        final subscriptionA = _listen(
          container,
          _key(ownerA, institutionId: _institutionIdA),
        );
        await _flush();

        subscriptionA.close();
        await _flush();
        final subscriptionB = _listen(
          container,
          _key(ownerA, institutionId: _institutionIdB),
        );
        await _flush();

        detailA.complete(_detail(id: _institutionIdA, name: 'A School'));
        await _flush();
        expect(subscriptionB.read().form?.name, isNull);

        detailB.complete(_detail(id: _institutionIdB, name: 'B School'));
        await _flush();
        expect(subscriptionB.read().form?.name, 'B School');
        expect(subscriptionB.read().detail?.id, _institutionIdB);

        final patchCompleter = Completer<PlatformInstitutionEditResult>();
        final editRepository = FakePlatformInstitutionEditRepository(
          onUpdate: (_, _) => patchCompleter.future,
        );
        final patchAuthController = FakeAuthSessionController.authenticated(
          ownerA,
        );
        final patchContainer = _container(
          authController: patchAuthController,
          editRepository: editRepository,
        );
        final patchKey = _key(ownerA);
        final patchSubscription = _listen(patchContainer, patchKey);
        await _flush();
        final patchController = patchContainer.read(
          platformInstitutionEditControllerProvider(patchKey).notifier,
        );
        patchController.updateName('Old Owner School');
        final submit = patchController.submit();
        await _flush();

        await patchAuthController.signOut();
        await _flush();
        patchCompleter.complete(_result(name: 'Old Owner School'));
        await submit;
        await _flush();

        expect(
          patchSubscription.read().status,
          PlatformInstitutionEditStatus.initial,
        );
        expect(patchSubscription.read().result, isNull);

        final ownerB = _owner('owner-b');
        patchAuthController.setAuthenticated(ownerB);
        final ownerBState = patchContainer.read(
          platformInstitutionEditControllerProvider(_key(ownerB)),
        );
        expect(ownerBState.result, isNull);
        expect(ownerBState.form?.name, isNull);
      },
    );
  });
}

ProviderContainer _container({
  required FakeAuthSessionController authController,
  FakePlatformInstitutionDetailRepository? detailRepository,
  FakePlatformInstitutionEditRepository? editRepository,
  FakePlatformInstitutionListRepository? listRepository,
  FakePlatformDashboardRepository? dashboardRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      platformInstitutionDetailRepositoryProvider.overrideWithValue(
        detailRepository ?? FakePlatformInstitutionDetailRepository(),
      ),
      platformInstitutionEditRepositoryProvider.overrideWithValue(
        editRepository ?? FakePlatformInstitutionEditRepository(),
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

ProviderSubscription<PlatformInstitutionEditState> _listen(
  ProviderContainer container,
  PlatformInstitutionEditKey key,
) {
  final subscription = container.listen(
    platformInstitutionEditControllerProvider(key),
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

PlatformInstitutionEditKey _key(
  AuthUser user, {
  String institutionId = _institutionIdA,
}) {
  return PlatformInstitutionEditKey(
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
  String? contactEmail = 'info@example.uz',
  String? contactPhone = '+998901234567',
  String? address = 'Samarkand',
  String? description = 'Optional notes',
}) {
  return PlatformInstitutionDetail(
    id: id,
    name: name,
    type: type,
    status: status,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    address: address,
    description: description,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    userCounts: const PlatformInstitutionUserCounts(total: 42, active: 40),
  );
}

PlatformInstitutionEditResult _result({
  String id = _institutionIdA,
  String name = 'Updated Name',
  PlatformInstitutionType type = PlatformInstitutionType.school,
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
}) {
  return PlatformInstitutionEditResult(
    id: id,
    name: name,
    type: type,
    status: status,
    contactEmail: 'updated@example.uz',
    contactPhone: '+998901234567',
    address: 'Updated address',
    description: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 10, 12),
    message: 'Institution updated successfully.',
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
        message: 'Server message must not control edit flow.',
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
        fieldErrors: const {
          'name': ['The name field failed backend validation.'],
          'type': ['The type field failed backend validation.'],
          'contact_email': ['The contact email must be valid.'],
          'contact_phone': ['The contact phone is too long.'],
          'address': ['The address field failed backend validation.'],
          'description': ['The description field failed backend validation.'],
          'settings': ['This field is not allowed.'],
        },
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Local institution edit failure.'),
  );
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

class FakePlatformInstitutionEditRepository
    implements PlatformInstitutionEditRepository {
  FakePlatformInstitutionEditRepository({this.onUpdate});

  Future<PlatformInstitutionEditResult> Function(
    String institutionId,
    PlatformInstitutionEditRequest request,
  )?
  onUpdate;
  final institutionIds = <String>[];
  final requests = <PlatformInstitutionEditRequest>[];

  int get updateCalls => requests.length;

  @override
  Future<PlatformInstitutionEditResult> updateInstitution(
    String institutionId,
    PlatformInstitutionEditRequest request,
  ) {
    institutionIds.add(institutionId);
    requests.add(request);

    return onUpdate?.call(institutionId, request) ?? Future.value(_result());
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
