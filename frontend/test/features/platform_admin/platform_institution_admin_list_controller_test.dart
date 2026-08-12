import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_admin_list_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_admin_list_state.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_admin_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_repository.dart';

void main() {
  group('PlatformInstitutionAdminListController', () {
    test('loads initial admins for the keyed institution only', () async {
      final owner = _owner('owner-a');
      final repository = FakePlatformInstitutionAdminRepository();
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        repository: repository,
      );
      final key = _key(owner, 'institution-a');
      final subscription = _listen(container, key);

      expect(
        subscription.read().status,
        PlatformInstitutionAdminListStatus.loading,
      );
      await _flush();

      expect(repository.fetchCalls, hasLength(1));
      expect(repository.fetchCalls.single.institutionId, 'institution-a');
      expect(repository.fetchCalls.single.query.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'full_name',
        'direction': 'asc',
      });
      expect(
        subscription.read().status,
        PlatformInstitutionAdminListStatus.data,
      );
      expect(subscription.read().result!.admins.single.loginName, 'admin-a');
    });

    test('query changes clear rows and use server-side filter state', () async {
      final owner = _owner('owner-a');
      final repository = FakePlatformInstitutionAdminRepository(
        onFetch: (institutionId, query) async {
          if (query.search == 'Valiyev') {
            return _page(admins: const []);
          }

          return _page(admins: [_admin(loginName: 'admin-a')]);
        },
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        repository: repository,
      );
      final key = _key(owner, 'institution-a');
      final subscription = _listen(container, key);
      await _flush();

      final controller = container.read(
        platformInstitutionAdminListControllerProvider(key).notifier,
      );
      controller.updateSearchText('Valiyev');
      controller.commitSearchNow();

      expect(
        subscription.read().status,
        PlatformInstitutionAdminListStatus.queryLoading,
      );
      expect(subscription.read().result, isNull);
      await _flush();

      expect(repository.fetchCalls.last.query.search, 'Valiyev');
      expect(
        subscription.read().status,
        PlatformInstitutionAdminListStatus.filteredEmpty,
      );
      expect(repository.fetchCalls, hasLength(2));
    });

    test(
      'route key change starts a fresh query for the new institution',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionAdminRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final keyA = _key(owner, 'institution-a');
        final subscriptionA = _listen(container, keyA);
        await _flush();
        final controllerA = container.read(
          platformInstitutionAdminListControllerProvider(keyA).notifier,
        );
        controllerA.updateSearchText('Ali');
        controllerA.commitSearchNow();
        await _flush();

        final keyB = _key(owner, 'institution-b');
        final subscriptionB = _listen(container, keyB);
        await _flush();

        expect(subscriptionA.read().query.search, 'Ali');
        expect(subscriptionB.read().query.search, isNull);
        expect(repository.fetchCalls.last.institutionId, 'institution-b');
        expect(repository.fetchCalls.last.query.toQueryParameters(), {
          'page': 1,
          'per_page': 20,
          'sort': 'full_name',
          'direction': 'asc',
        });
      },
    );

    test(
      'retry after read failure uses the same safe query only once',
      () async {
        final owner = _owner('owner-a');
        var shouldFail = true;
        final repository = FakePlatformInstitutionAdminRepository(
          onFetch: (institutionId, query) async {
            if (shouldFail) {
              shouldFail = false;
              throw ApiRequestException(
                ApiFailure.local(
                  kind: ApiFailureKind.connection,
                  message: 'offline',
                ),
              );
            }

            return _page(admins: [_admin()]);
          },
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner, 'institution-a');
        final subscription = _listen(container, key);
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionAdminListStatus.error,
        );

        await container
            .read(platformInstitutionAdminListControllerProvider(key).notifier)
            .retry();
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionAdminListStatus.data,
        );
        expect(repository.fetchCalls.map((call) => call.institutionId), [
          'institution-a',
          'institution-a',
        ]);
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

ProviderSubscription<PlatformInstitutionAdminListState> _listen(
  ProviderContainer container,
  PlatformInstitutionAdminListKey key,
) {
  final subscription = container.listen(
    platformInstitutionAdminListControllerProvider(key),
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

PlatformInstitutionAdminListKey _key(AuthUser user, String institutionId) {
  return PlatformInstitutionAdminListKey(
    sessionUserId: user.id,
    sessionInstanceId: identityHashCode(user),
    institutionId: institutionId,
  );
}

PlatformInstitutionAdminList _page({
  List<PlatformInstitutionAdmin> admins = const [],
}) {
  return PlatformInstitutionAdminList(
    admins: List<PlatformInstitutionAdmin>.unmodifiable(admins),
    pagination: PlatformInstitutionAdminPagination(
      page: 1,
      perPage: 20,
      total: admins.length,
      lastPage: 1,
    ),
  );
}

PlatformInstitutionAdmin _admin({String loginName = 'admin-a'}) {
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
  final fetchCalls =
      <({String institutionId, PlatformInstitutionAdminListQuery query})>[];

  @override
  Future<PlatformInstitutionAdminList> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  }) {
    fetchCalls.add((institutionId: institutionId, query: query));

    return onFetch?.call(institutionId, query) ??
        Future.value(_page(admins: [_admin()]));
  }

  @override
  Future<PlatformInstitutionAdminCreateResult> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  }) {
    return onCreate?.call(institutionId, request) ??
        Future.value(
          PlatformInstitutionAdminCreateResult(
            admin: _admin(loginName: request.loginName),
            message: 'Institution administrator created.',
          ),
        );
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
}
