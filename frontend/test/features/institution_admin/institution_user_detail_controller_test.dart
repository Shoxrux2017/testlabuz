import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_detail_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_detail_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_detail_repository.dart';

void main() {
  test(
    'eligible session loads one target and supports a fresh refresh',
    () async {
      final repository = _FakeDetailRepository();
      final container = _container(repository);
      final subscription = _listen(container, _userId);
      await _flush();

      expect(subscription.read().status, InstitutionUserDetailStatus.data);
      expect(subscription.read().user?.id, _userId);
      expect(repository.fetchCalls, 1);

      container
          .read(institutionUserDetailControllerProvider(_userId).notifier)
          .refresh();
      container
          .read(institutionUserDetailControllerProvider(_userId).notifier)
          .refresh();
      await _flush();

      expect(repository.fetchCalls, 2);
      expect(subscription.read().status, InstitutionUserDetailStatus.data);
    },
  );

  test(
    'retry is limited to retryable failures and is duplicate-protected',
    () async {
      final repository = _FakeDetailRepository(
        onFetch: (call) async {
          if (call == 1) {
            throw ApiRequestException(
              ApiFailure.local(
                kind: ApiFailureKind.connection,
                message: 'private network failure',
              ),
            );
          }
          return _user();
        },
      );
      final container = _container(repository);
      final subscription = _listen(container, _userId);
      await _flush();

      expect(subscription.read().status, InstitutionUserDetailStatus.error);
      expect(subscription.read().isRetryable, isTrue);
      container
          .read(institutionUserDetailControllerProvider(_userId).notifier)
          .retry();
      container
          .read(institutionUserDetailControllerProvider(_userId).notifier)
          .retry();
      await _flush();

      expect(repository.fetchCalls, 2);
      expect(subscription.read().status, InstitutionUserDetailStatus.data);
    },
  );

  test('ineligible and malformed targets issue no request', () async {
    final repository = _FakeDetailRepository();
    final invalidContainer = _container(repository);
    final invalid = _listen(invalidContainer, 'not-a-uuid');
    await _flush();
    expect(
      invalid.read().status,
      InstitutionUserDetailStatus.localUnavailableTarget,
    );
    expect(repository.fetchCalls, 0);

    final ineligibleContainer = _container(
      repository,
      session: AuthSessionState.authenticated(_admin(isActive: false)),
    );
    final ineligible = _listen(ineligibleContainer, _userId);
    await _flush();
    expect(ineligible.read().status, InstitutionUserDetailStatus.initial);
    expect(repository.fetchCalls, 0);
  });

  test('logout invalidates a pending completion', () async {
    final request = Completer<InstitutionUser>();
    final repository = _FakeDetailRepository(onFetch: (_) => request.future);
    final auth = _FakeAuthSessionController.authenticated(_admin());
    final container = _container(repository, auth: auth);
    final subscription = _listen(container, _userId);
    await _flush();

    auth.setSession(const AuthSessionState.unauthenticated());
    await _flush();
    request.complete(_user());
    await _flush();

    expect(subscription.read().hasData, isFalse);
    expect(subscription.read().status, InstitutionUserDetailStatus.initial);
  });
}

ProviderContainer _container(
  _FakeDetailRepository repository, {
  AuthSessionState? session,
  _FakeAuthSessionController? auth,
}) {
  final authController =
      auth ??
      _FakeAuthSessionController(
        session ?? AuthSessionState.authenticated(_admin()),
      );
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionUserDetailRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<InstitutionUserDetailState> _listen(
  ProviderContainer container,
  String userId,
) {
  final subscription = container.listen(
    institutionUserDetailControllerProvider(userId),
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

const _userId = '00000000-0000-0000-0000-000000000001';

InstitutionUser _user({String id = _userId}) => InstitutionUser(
  id: id,
  role: InstitutionUserRole.teacher,
  fullName: 'Teacher Name',
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

AuthUser _admin({bool isActive = true}) => AuthUser(
  id: 'admin-a',
  institutionId: 'institution-a',
  role: UserRole.institutionAdmin,
  fullName: 'Admin User',
  loginName: 'admin',
  email: null,
  phone: null,
  isActive: isActive,
  mustChangePassword: false,
  institution: const AuthInstitution(
    id: 'institution-a',
    name: 'Institution A',
    status: 'active',
    timezone: 'Asia/Tashkent',
  ),
);

class _FakeDetailRepository implements InstitutionUserDetailRepository {
  _FakeDetailRepository({this.onFetch});

  Future<InstitutionUser> Function(int call)? onFetch;
  var fetchCalls = 0;

  @override
  Future<InstitutionUser> fetchUser(String userId) {
    fetchCalls += 1;
    return onFetch?.call(fetchCalls) ?? Future.value(_user(id: userId));
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.initialState);

  factory _FakeAuthSessionController.authenticated(AuthUser user) {
    return _FakeAuthSessionController(AuthSessionState.authenticated(user));
  }

  final AuthSessionState initialState;

  @override
  AuthSessionState build() => initialState;

  void setSession(AuthSessionState nextState) {
    state = nextState;
  }
}
