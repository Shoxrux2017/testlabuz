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
import 'package:testlabuz_client/features/institution_admin/application/institution_user_action_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_action_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_dashboard_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_detail_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_detail_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_mutation_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_mutation_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';

void main() {
  test(
    'edit submits once, updates detail, and marks only Users stale',
    () async {
      final mutation = _FakeMutationRepository(
        onUpdate: (_, _, _) async => _user(fullName: 'Updated Name'),
      );
      final fixture = await _fixture(mutation: mutation);
      final controller = fixture.controller;
      final listKey = InstitutionUserListSessionKey(
        userId: fixture.admin.id,
        userInstance: fixture.admin,
        institutionId: fixture.admin.institutionId!,
      );
      final retainedQuery = const InstitutionUserListQuery.initial().copyWith(
        role: InstitutionUserRole.teacher,
        search: 'Teacher',
        perPage: 50,
        page: 2,
      );
      fixture.container
          .read(institutionUserListRetainedQueryProvider)
          .value = InstitutionUserListRetainedQuery(
        sessionKey: listKey,
        query: retainedQuery,
        searchDraft: 'Teacher',
      );

      expect(controller.beginEdit(fixture.initial), isTrue);
      controller.updateFullName('  Updated Name  ');
      await controller.submitEdit();

      expect(mutation.updateCalls, 1);
      expect(mutation.lastRequest!.toJson(), {'full_name': 'Updated Name'});
      expect(
        fixture.action.read().status,
        InstitutionUserActionStatus.confirmedDirectSuccess,
      );
      expect(fixture.action.read().feedback, 'User updated successfully.');
      expect(fixture.detail.read().user!.fullName, 'Updated Name');
      final retainedStore = fixture.container.read(
        institutionUserListRetainedQueryProvider,
      );
      expect(retainedStore.isStale(listKey), isTrue);
      expect(retainedStore.value!.query, retainedQuery);
      expect(retainedStore.value!.searchDraft, 'Teacher');
      expect(fixture.dashboard.fetchCalls, 1);
    },
  );

  test(
    'activate and deactivate update detail and mark only Users stale',
    () async {
      for (final initialActive in const [true, false]) {
        final initial = _user(
          isActive: initialActive,
          deactivatedAt: initialActive ? null : DateTime.utc(2026, 8, 15, 7),
        );
        final mutation = _FakeMutationRepository(
          onLifecycle: (_, _, action) async => _user(
            isActive: action.desiredActive,
            deactivatedAt: action.desiredActive
                ? null
                : DateTime.utc(2026, 8, 15, 8),
          ),
        );
        final fixture = await _fixture(
          mutation: mutation,
          detail: _FakeDetailRepository([initial]),
        );
        final dashboardFetchesBeforeAction = fixture.dashboard.fetchCalls;
        final listKey = InstitutionUserListSessionKey(
          userId: fixture.admin.id,
          userInstance: fixture.admin,
          institutionId: fixture.admin.institutionId!,
        );

        expect(fixture.controller.beginLifecycle(fixture.initial), isTrue);
        await fixture.controller.confirmLifecycle();

        expect(mutation.lifecycleCalls, 1);
        expect(
          mutation.lastAction,
          initialActive
              ? InstitutionUserLifecycleAction.deactivate
              : InstitutionUserLifecycleAction.activate,
        );
        expect(
          fixture.action.read().status,
          InstitutionUserActionStatus.confirmedDirectSuccess,
        );
        expect(fixture.detail.read().user!.isActive, !initialActive);
        expect(
          fixture.container
              .read(institutionUserListRetainedQueryProvider)
              .isStale(listKey),
          isTrue,
        );
        expect(fixture.dashboard.fetchCalls, dashboardFetchesBeforeAction);
      }
    },
  );

  test(
    'local validation, no change, cancel, and duplicate intent send nothing extra',
    () async {
      final pending = Completer<InstitutionUser>();
      final mutation = _FakeMutationRepository(
        onUpdate: (_, _, _) => pending.future,
      );
      final fixture = await _fixture(mutation: mutation);
      final controller = fixture.controller;

      controller.beginEdit(fixture.initial);
      expect(controller.beginLifecycle(fixture.initial), isFalse);
      await controller.submitEdit();
      expect(mutation.updateCalls, 0);
      expect(fixture.action.read().formMessage, 'No user changes to save.');

      controller.updateFullName('   ');
      await controller.submitEdit();
      expect(mutation.updateCalls, 0);
      expect(
        fixture.action.read().fieldErrors[InstitutionUserEditField.fullName],
        'Full name is required.',
      );

      controller.updateFullName('Updated Name');
      final first = controller.submitEdit();
      final duplicate = controller.submitEdit();
      expect(mutation.updateCalls, 1);
      final listKey = InstitutionUserListSessionKey(
        userId: fixture.admin.id,
        userInstance: fixture.admin,
        institutionId: fixture.admin.institutionId!,
      );
      final retainedStore = fixture.container.read(
        institutionUserListRetainedQueryProvider,
      );
      expect(retainedStore.consumeStale(listKey), isTrue);
      controller.dismiss();
      expect(fixture.action.read().isBusy, isTrue);
      pending.complete(_user(fullName: 'Updated Name'));
      await first;
      await duplicate;
      expect(mutation.updateCalls, 1);
      expect(retainedStore.isStale(listKey), isTrue);
    },
  );

  test(
    'unprovable mutation performs one GET and never converts it to success',
    () async {
      final detail = _FakeDetailRepository([
        _user(),
        _user(fullName: 'Requested Name'),
      ]);
      final mutation = _FakeMutationRepository(
        onUpdate: (_, _, _) async =>
            throw const InstitutionUserMutationOutcomeUnknownException(),
      );
      final fixture = await _fixture(mutation: mutation, detail: detail);

      fixture.controller.beginEdit(fixture.initial);
      fixture.controller.updateFullName('Requested Name');
      await fixture.controller.submitEdit();

      expect(mutation.updateCalls, 1);
      expect(detail.fetchCalls, 2);
      expect(
        fixture.action.read().status,
        InstitutionUserActionStatus.unconfirmedCurrentState,
      );
      expect(
        fixture.action.read().feedback,
        contains('could not be confirmed'),
      );
      expect(fixture.action.read().feedback, isNot(contains('success')));
      expect(fixture.detail.read().user!.fullName, 'Requested Name');
    },
  );

  test(
    'lifecycle is state-derived, duplicate protected, and stale account completion is ignored',
    () async {
      final pending = Completer<InstitutionUser>();
      final mutation = _FakeMutationRepository(
        onLifecycle: (_, _, _) => pending.future,
      );
      final auth = _FakeAuthSessionController(_admin());
      final fixture = await _fixture(mutation: mutation, auth: auth);

      fixture.controller.beginLifecycle(fixture.initial);
      final focusKey = fixture.controller.focusKey!;
      final first = fixture.controller.confirmLifecycle();
      final duplicate = fixture.controller.confirmLifecycle();
      expect(mutation.lifecycleCalls, 1);
      expect(mutation.lastAction, InstitutionUserLifecycleAction.deactivate);

      auth.setUser(_admin(id: 'admin-b'));
      await _flush();
      pending.complete(
        _user(isActive: false, deactivatedAt: DateTime.utc(2026, 8, 15, 8)),
      );
      await first;
      await duplicate;

      expect(mutation.lifecycleCalls, 1);
      expect(fixture.action.read().status, InstitutionUserActionStatus.idle);
      expect(fixture.detail.read().user?.isActive, isTrue);
      expect(fixture.controller.canRestoreFocus(focusKey), isFalse);
    },
  );

  test(
    'approved validation keys map safely and unknown keys stay form-level',
    () async {
      final mutation = _FakeMutationRepository(
        onUpdate: (_, _, _) async =>
            throw ApiRequestException(_validationFailure()),
      );
      final fixture = await _fixture(mutation: mutation);
      fixture.controller.beginEdit(fixture.initial);
      fixture.controller.updateEmail('new@example.uz');
      await fixture.controller.submitEdit();

      expect(
        fixture.action.read().fieldErrors[InstitutionUserEditField.email],
        'Review the email address.',
      );
      expect(
        fixture.action.read().formMessage,
        'The update request did not match the server contract.',
      );
      expect(fixture.action.read().toString(), isNot(contains('Private')));
    },
  );

  test(
    'exact target 404 clears detail through privacy-safe not-found state',
    () async {
      final mutation = _FakeMutationRepository(
        onLifecycle: (_, _, _) async => throw ApiRequestException(
          ApiFailure(
            kind: ApiFailureKind.server,
            statusCode: 404,
            serverCode: ApiErrorCodes.resourceNotFound,
            message: 'Private target and institution detail.',
          ),
        ),
      );
      final fixture = await _fixture(mutation: mutation);
      fixture.controller.beginLifecycle(fixture.initial);
      await fixture.controller.confirmLifecycle();

      expect(
        fixture.detail.read().status,
        InstitutionUserDetailStatus.notFound,
      );
      expect(fixture.detail.read().user, isNull);
      expect(fixture.action.read().toString(), isNot(contains('Private')));
    },
  );

  test(
    'failed reconciliation performs no extra GET and keeps neutral feedback',
    () async {
      final detail = _FakeDetailRepository([
        _user(),
        ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.connection,
            message: 'Private contact and target data.',
          ),
        ),
      ]);
      final mutation = _FakeMutationRepository(
        onLifecycle: (_, _, _) async =>
            throw const InstitutionUserMutationOutcomeUnknownException(),
      );
      final fixture = await _fixture(mutation: mutation, detail: detail);
      fixture.controller.beginLifecycle(fixture.initial);
      await fixture.controller.confirmLifecycle();

      expect(mutation.lifecycleCalls, 1);
      expect(detail.fetchCalls, 2);
      expect(
        fixture.action.read().status,
        InstitutionUserActionStatus.unconfirmedCurrentState,
      );
      expect(
        fixture.action.read().feedback,
        contains('could not be confirmed'),
      );
      expect(fixture.action.read().feedback, isNot(contains('Private')));
    },
  );

  test(
    'detail refresh closes pending ownership before it can retarget',
    () async {
      final refresh = Completer<InstitutionUser>();
      final detail = _FakeDetailRepository([_user(), refresh.future]);
      final fixture = await _fixture(
        mutation: _FakeMutationRepository(),
        detail: detail,
      );
      fixture.controller.beginEdit(fixture.initial);

      fixture.container
          .read(institutionUserDetailControllerProvider(_userId).notifier)
          .refresh();
      await _flush();

      expect(fixture.action.read().status, InstitutionUserActionStatus.idle);
      refresh.complete(_user(fullName: 'Fresh Server User'));
      await _flush();
      expect(fixture.detail.read().user!.fullName, 'Fresh Server User');
    },
  );

  test(
    'early Users stale marker survives route disposal and late completion',
    () async {
      final pending = Completer<InstitutionUser>();
      final fixture = await _fixture(
        mutation: _FakeMutationRepository(
          onUpdate: (_, _, _) => pending.future,
        ),
      );
      fixture.controller.beginEdit(fixture.initial);
      fixture.controller.updateFullName('Late Name');
      final operation = fixture.controller.submitEdit();
      final listKey = InstitutionUserListSessionKey(
        userId: fixture.admin.id,
        userInstance: fixture.admin,
        institutionId: fixture.admin.institutionId!,
      );
      final retainedStore = fixture.container.read(
        institutionUserListRetainedQueryProvider,
      );
      expect(retainedStore.isStale(listKey), isTrue);

      fixture.action.close();
      await _flush();
      pending.complete(_user(fullName: 'Late Name'));
      await operation;

      expect(retainedStore.isStale(listKey), isTrue);
      expect(fixture.detail.read().user!.fullName, 'Teacher Name');
    },
  );

  test('lifecycle 422 closes command ownership with safe feedback', () async {
    final fixture = await _fixture(
      mutation: _FakeMutationRepository(
        onLifecycle: (_, _, _) async => throw ApiRequestException(
          ApiFailure(
            kind: ApiFailureKind.validation,
            statusCode: 422,
            serverCode: ApiErrorCodes.validationFailed,
            message: 'Private backend lifecycle validation.',
          ),
        ),
      ),
    );
    fixture.controller.beginLifecycle(fixture.initial);
    await fixture.controller.confirmLifecycle();

    expect(
      fixture.action.read().status,
      InstitutionUserActionStatus.definiteFailure,
    );
    expect(
      fixture.action.read().feedback,
      'The lifecycle request did not match the server contract.',
    );
    expect(fixture.action.read().isLifecycleDialog, isFalse);
  });

  test(
    'malformed 401 during reconciliation does not invalidate the session',
    () async {
      final auth = _FakeAuthSessionController(_admin());
      final detail = _FakeDetailRepository([
        _user(),
        ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            statusCode: 401,
            message: 'Private malformed response.',
          ),
        ),
      ]);
      final fixture = await _fixture(
        mutation: _FakeMutationRepository(
          onLifecycle: (_, _, _) async =>
              throw const InstitutionUserMutationOutcomeUnknownException(),
        ),
        detail: detail,
        auth: auth,
      );
      fixture.controller.beginLifecycle(fixture.initial);
      await fixture.controller.confirmLifecycle();

      expect(auth.bootstrapCalls, 0);
      expect(
        fixture.action.read().status,
        InstitutionUserActionStatus.unconfirmedCurrentState,
      );
    },
  );

  test('exact actor-state failures reconcile the global session', () async {
    for (final testCase in const [
      (status: 401, code: ApiErrorCodes.authenticationRequired),
      (status: 403, code: ApiErrorCodes.userInactive),
      (status: 403, code: ApiErrorCodes.institutionInactive),
      (status: 403, code: ApiErrorCodes.passwordChangeRequired),
    ]) {
      final auth = _FakeAuthSessionController(_admin());
      final fixture = await _fixture(
        mutation: _FakeMutationRepository(
          onUpdate: (_, _, _) async => throw ApiRequestException(
            ApiFailure(
              kind: ApiFailureKind.server,
              statusCode: testCase.status,
              serverCode: testCase.code,
              message: 'Private actor-state detail.',
            ),
          ),
        ),
        auth: auth,
      );
      fixture.controller.beginEdit(fixture.initial);
      fixture.controller.updateFullName('Updated');
      await fixture.controller.submitEdit();

      expect(auth.bootstrapCalls, 1, reason: testCase.code);
      expect(
        fixture.action.read().status,
        InstitutionUserActionStatus.idle,
        reason: testCase.code,
      );
    }
  });
}

ApiFailure _validationFailure() => ApiFailure(
  kind: ApiFailureKind.validation,
  statusCode: 422,
  serverCode: ApiErrorCodes.validationFailed,
  message: 'Private backend message.',
  fieldErrors: const {
    'email': ['Private email detail.'],
    'institution_id': ['Private protected detail.'],
  },
);

Future<_Fixture> _fixture({
  required _FakeMutationRepository mutation,
  _FakeDetailRepository? detail,
  _FakeAuthSessionController? auth,
}) async {
  final admin = auth?.currentUser ?? _admin();
  final authController = auth ?? _FakeAuthSessionController(admin);
  final detailRepository = detail ?? _FakeDetailRepository([_user()]);
  final dashboard = _FakeDashboardRepository();
  final container = ProviderContainer(
    overrides: [
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      authSessionControllerProvider.overrideWith(() => authController),
      institutionUserDetailRepositoryProvider.overrideWithValue(
        detailRepository,
      ),
      institutionUserMutationRepositoryProvider.overrideWithValue(mutation),
      institutionDashboardRepositoryProvider.overrideWithValue(dashboard),
    ],
  );
  addTearDown(container.dispose);
  final detailSubscription = container.listen(
    institutionUserDetailControllerProvider(_userId),
    (_, _) {},
    fireImmediately: true,
  );
  await _flush();
  final actionSubscription = container.listen(
    institutionUserActionControllerProvider(_userId),
    (_, _) {},
    fireImmediately: true,
  );
  container.listen(
    institutionDashboardControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  await _flush();
  final initial = detailSubscription.read().user!;
  return _Fixture(
    container: container,
    admin: admin,
    initial: initial,
    controller: container.read(
      institutionUserActionControllerProvider(_userId).notifier,
    ),
    action: actionSubscription,
    detail: detailSubscription,
    dashboard: dashboard,
  );
}

class _Fixture {
  const _Fixture({
    required this.container,
    required this.admin,
    required this.initial,
    required this.controller,
    required this.action,
    required this.detail,
    required this.dashboard,
  });
  final ProviderContainer container;
  final AuthUser admin;
  final InstitutionUser initial;
  final InstitutionUserActionController controller;
  final ProviderSubscription<InstitutionUserActionState> action;
  final ProviderSubscription<InstitutionUserDetailState> detail;
  final _FakeDashboardRepository dashboard;
}

class _FakeDashboardRepository implements InstitutionDashboardRepository {
  var fetchCalls = 0;

  @override
  Future<InstitutionDashboard> fetchDashboard() async {
    fetchCalls += 1;
    return const InstitutionDashboard(teachers: 1, students: 1, parents: 1);
  }
}

class _FakeDetailRepository implements InstitutionUserDetailRepository {
  _FakeDetailRepository(this.responses);
  final List<Object> responses;
  var fetchCalls = 0;

  @override
  Future<InstitutionUser> fetchUser(String userId) async {
    final index = fetchCalls++;
    final response =
        responses[index < responses.length ? index : responses.length - 1];
    if (response is Exception) {
      throw response;
    }
    if (response is Future<InstitutionUser>) {
      return response;
    }
    return response as InstitutionUser;
  }
}

class _FakeMutationRepository implements InstitutionUserMutationRepository {
  _FakeMutationRepository({this.onUpdate, this.onLifecycle});
  final Future<InstitutionUser> Function(
    String,
    InstitutionUser,
    InstitutionUserEditRequest,
  )?
  onUpdate;
  final Future<InstitutionUser> Function(
    String,
    InstitutionUser,
    InstitutionUserLifecycleAction,
  )?
  onLifecycle;
  var updateCalls = 0;
  var lifecycleCalls = 0;
  InstitutionUserEditRequest? lastRequest;
  InstitutionUserLifecycleAction? lastAction;

  @override
  Future<InstitutionUser> updateUser(
    String userId,
    InstitutionUser selected,
    InstitutionUserEditRequest request,
  ) {
    updateCalls += 1;
    lastRequest = request;
    return onUpdate!(userId, selected, request);
  }

  @override
  Future<InstitutionUser> changeLifecycle(
    String userId,
    InstitutionUser selected,
    InstitutionUserLifecycleAction action,
  ) {
    lifecycleCalls += 1;
    lastAction = action;
    return onLifecycle!(userId, selected, action);
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.currentUser);
  AuthUser currentUser;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => AuthSessionState.authenticated(currentUser);

  void setUser(AuthUser user) {
    currentUser = user;
    state = AuthSessionState.authenticated(user);
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
  }
}

const _userId = '00000000-0000-0000-0000-000000000001';

AuthUser _admin({String id = 'admin-a'}) => AuthUser(
  id: id,
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

InstitutionUser _user({
  String fullName = 'Teacher Name',
  bool isActive = true,
  DateTime? deactivatedAt,
}) => InstitutionUser(
  id: _userId,
  role: InstitutionUserRole.teacher,
  fullName: fullName,
  loginName: 'teacher01',
  email: null,
  phone: null,
  isActive: isActive,
  mustChangePassword: false,
  lastLoginAt: null,
  deactivatedAt: deactivatedAt,
  createdAt: DateTime.utc(2026, 8, 7, 15),
  updatedAt: DateTime.utc(2026, 8, 15, 8),
);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
