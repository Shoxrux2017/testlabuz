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
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_list_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_list_state.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('PlatformInstitutionListController', () {
    test(
      'eligible owner entry loads exactly once and ignores rebuild reads',
      () async {
        final listCompleter = Completer<PlatformInstitutionListPage>();
        final repository = FakePlatformInstitutionListRepository(
          onFetch: (_) => listCompleter.future,
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(
            _owner('owner-a'),
          ),
          repository: repository,
        );
        final subscription = _listen(container);

        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionListStatus.loading,
        );
        expect(repository.fetchCalls, 1);
        expect(
          repository.queries.single,
          const PlatformInstitutionListQuery.initial(),
        );

        container.read(platformInstitutionListControllerProvider);
        container.read(platformInstitutionListControllerProvider);
        expect(repository.fetchCalls, 1);

        listCompleter.complete(_page(label: 'Loaded'));
        await _flush();

        final state = subscription.read();
        expect(state.status, PlatformInstitutionListStatus.data);
        expect(state.result?.institutions.single.name, 'Loaded School');
        expect(repository.fetchCalls, 1);
      },
    );

    test(
      'classifies global filtered and empty-page states from backend meta',
      () async {
        final cases = [
          (
            query: const PlatformInstitutionListQuery.initial(),
            page: _page(rows: const [], total: 0),
            status: PlatformInstitutionListStatus.globalEmpty,
          ),
          (
            query: const PlatformInstitutionListQuery.initial().withSearch(
              'None',
            ),
            page: _page(rows: const [], total: 0),
            status: PlatformInstitutionListStatus.filteredEmpty,
          ),
          (
            query: const PlatformInstitutionListQuery.initial().copyWith(
              page: 3,
            ),
            page: _page(rows: const [], page: 3, total: 12, lastPage: 3),
            status: PlatformInstitutionListStatus.emptyPage,
          ),
        ];

        for (final testCase in cases) {
          final state = PlatformInstitutionListState.fromResult(
            query: testCase.query,
            searchText: testCase.query.search ?? '',
            result: testCase.page,
          );

          expect(state.status, testCase.status);
        }
      },
    );

    test(
      'search debounce trims commits and Enter cancels the pending timer',
      () async {
        final repository = FakePlatformInstitutionListRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(
            _owner('owner-a'),
          ),
          repository: repository,
        );
        _listen(container);

        await _flush();
        expect(repository.fetchCalls, 1);

        final controller = container.read(
          platformInstitutionListControllerProvider.notifier,
        );
        controller.updateSearchText('  Samarqand  ');
        controller.updateSearchText("  Samarqand % _ o'quv  ");
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(repository.fetchCalls, 1);

        controller.commitSearchNow();
        await _flush();
        expect(repository.fetchCalls, 2);
        expect(repository.queries.last.search, "Samarqand % _ o'quv");
        expect(repository.queries.last.page, 1);

        await Future<void>.delayed(
          PlatformInstitutionListQuery.searchDebounceDuration +
              const Duration(milliseconds: 40),
        );
        expect(repository.fetchCalls, 2);
      },
    );

    test('overlong search shows safe feedback and issues no request', () async {
      final repository = FakePlatformInstitutionListRepository();
      final container = _container(
        authController: FakeAuthSessionController.authenticated(
          _owner('owner-a'),
        ),
        repository: repository,
      );
      final subscription = _listen(container);

      await _flush();
      final overlong = '${List.filled(200, 'x').join()}!';
      container
          .read(platformInstitutionListControllerProvider.notifier)
          .updateSearchText(overlong);
      await Future<void>.delayed(
        PlatformInstitutionListQuery.searchDebounceDuration +
            const Duration(milliseconds: 40),
      );

      expect(repository.fetchCalls, 1);
      expect(subscription.read().searchErrorText, contains('200'));
      expect(subscription.read().query.search, isNull);
    });

    test(
      'filters sorting page size reset and page transitions serialize exactly',
      () async {
        final repository = FakePlatformInstitutionListRepository();
        final container = _container(
          authController: FakeAuthSessionController.authenticated(
            _owner('owner-a'),
          ),
          repository: repository,
        );
        _listen(container);

        await _flush();
        final controller = container.read(
          platformInstitutionListControllerProvider.notifier,
        );

        controller.setStatus(PlatformInstitutionStatus.inactive);
        await _flush();
        controller.setType(PlatformInstitutionType.university);
        await _flush();
        controller.toggleSort(PlatformInstitutionListSort.createdAt);
        await _flush();
        controller.toggleSort(PlatformInstitutionListSort.createdAt);
        await _flush();
        controller.setPerPage(50);
        await _flush();
        controller.nextPage();
        await _flush();
        controller.previousPage();
        await _flush();
        controller.reset();
        await _flush();

        expect(repository.queries.map((query) => query.toQueryParameters()), [
          {'page': 1, 'per_page': 20, 'sort': 'name', 'direction': 'asc'},
          {
            'page': 1,
            'per_page': 20,
            'sort': 'name',
            'direction': 'asc',
            'status': 'inactive',
          },
          {
            'page': 1,
            'per_page': 20,
            'sort': 'name',
            'direction': 'asc',
            'status': 'inactive',
            'type': 'university',
          },
          {
            'page': 1,
            'per_page': 20,
            'sort': 'created_at',
            'direction': 'asc',
            'status': 'inactive',
            'type': 'university',
          },
          {
            'page': 1,
            'per_page': 20,
            'sort': 'created_at',
            'direction': 'desc',
            'status': 'inactive',
            'type': 'university',
          },
          {
            'page': 1,
            'per_page': 50,
            'sort': 'created_at',
            'direction': 'desc',
            'status': 'inactive',
            'type': 'university',
          },
          {
            'page': 2,
            'per_page': 50,
            'sort': 'created_at',
            'direction': 'desc',
            'status': 'inactive',
            'type': 'university',
          },
          {
            'page': 1,
            'per_page': 50,
            'sort': 'created_at',
            'direction': 'desc',
            'status': 'inactive',
            'type': 'university',
          },
          {'page': 1, 'per_page': 20, 'sort': 'name', 'direction': 'asc'},
        ]);
      },
    );

    test(
      'same committed query is a no-op except explicit retry after error',
      () async {
        final retryCompleter = Completer<PlatformInstitutionListPage>();
        final repository = FakePlatformInstitutionListRepository();
        repository.onFetch = (query) {
          if (repository.fetchCalls == 1) {
            throw _localFailure(ApiFailureKind.connection);
          }

          return retryCompleter.future;
        };
        final container = _container(
          authController: FakeAuthSessionController.authenticated(
            _owner('owner-a'),
          ),
          repository: repository,
        );
        final subscription = _listen(container);

        await _flush();
        expect(subscription.read().status, PlatformInstitutionListStatus.error);
        expect(repository.fetchCalls, 1);

        container
            .read(platformInstitutionListControllerProvider.notifier)
            .setStatus(null);
        await _flush();
        expect(repository.fetchCalls, 1);

        final retryA = container
            .read(platformInstitutionListControllerProvider.notifier)
            .retry();
        final retryB = container
            .read(platformInstitutionListControllerProvider.notifier)
            .retry();
        expect(subscription.read().isRetryInFlight, isTrue);
        expect(repository.fetchCalls, 2);

        retryCompleter.complete(_page(label: 'Retry'));
        await retryA;
        await retryB;
        await _flush();

        expect(subscription.read().status, PlatformInstitutionListStatus.data);
        expect(repository.fetchCalls, 2);
      },
    );

    test(
      'query-change loading clears old rows and stale completion cannot win',
      () async {
        final first = Completer<PlatformInstitutionListPage>();
        final second = Completer<PlatformInstitutionListPage>();
        final repository = FakePlatformInstitutionListRepository();
        repository.onFetch = (_) {
          return repository.fetchCalls == 1 ? first.future : second.future;
        };
        final container = _container(
          authController: FakeAuthSessionController.authenticated(
            _owner('owner-a'),
          ),
          repository: repository,
        );
        final subscription = _listen(container);

        await _flush();
        expect(repository.fetchCalls, 1);

        container
            .read(platformInstitutionListControllerProvider.notifier)
            .updateSearchText('New');
        container
            .read(platformInstitutionListControllerProvider.notifier)
            .commitSearchNow();
        await _flush();

        expect(repository.fetchCalls, 2);
        expect(
          subscription.read().status,
          PlatformInstitutionListStatus.queryLoading,
        );
        expect(subscription.read().result, isNull);

        second.complete(_page(label: 'New'));
        await _flush();
        expect(
          subscription.read().result?.institutions.single.name,
          'New School',
        );

        first.complete(_page(label: 'Old'));
        await _flush();
        expect(
          subscription.read().result?.institutions.single.name,
          'New School',
        );
      },
    );

    test(
      'auth and status failures request accepted session reconciliation',
      () async {
        final cases = [
          (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
          (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
          (statusCode: 403, code: ApiErrorCodes.userInactive),
          (statusCode: 403, code: ApiErrorCodes.institutionInactive),
        ];

        for (final testCase in cases) {
          final authController =
              FakeAuthSessionController.authenticated(_owner('owner-a'))
                ..onBootstrap = () =>
                    testCase.code == ApiErrorCodes.passwordChangeRequired
                    ? AuthSessionState.authenticated(
                        _owner('owner-a', mustChangePassword: true),
                      )
                    : const AuthSessionState.unauthenticated();
          final repository = FakePlatformInstitutionListRepository(
            onFetch: (_) async => throw _serverFailure(
              testCase.code,
              statusCode: testCase.statusCode,
            ),
          );
          final container = _container(
            authController: authController,
            repository: repository,
          );
          _listen(container);

          await _flush();

          expect(authController.bootstrapCalls, 1);
          final session = container.read(authSessionControllerProvider);
          if (testCase.code == ApiErrorCodes.passwordChangeRequired) {
            expect(session.status, AuthSessionStatus.authenticated);
            expect(session.user?.mustChangePassword, isTrue);
          } else {
            expect(session.status, AuthSessionStatus.unauthenticated);
          }
        }
      },
    );

    test(
      'logout and stale debounce or request cannot repopulate list data',
      () async {
        final first = Completer<PlatformInstitutionListPage>();
        final repository = FakePlatformInstitutionListRepository(
          onFetch: (_) => first.future,
        );
        final authController = FakeAuthSessionController.authenticated(
          _owner('owner-a'),
        );
        final container = _container(
          authController: authController,
          repository: repository,
        );
        final subscription = _listen(container);

        await _flush();
        container
            .read(platformInstitutionListControllerProvider.notifier)
            .updateSearchText('Should not commit');
        await container.read(authSessionControllerProvider.notifier).signOut();
        await _flush();
        await Future<void>.delayed(
          PlatformInstitutionListQuery.searchDebounceDuration +
              const Duration(milliseconds: 40),
        );

        first.complete(_page(label: 'Old Owner'));
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionListStatus.initial,
        );
        expect(subscription.read().result, isNull);
        expect(repository.fetchCalls, 1);
      },
    );
  });
}

ProviderContainer _container({
  required FakeAuthSessionController authController,
  required FakePlatformInstitutionListRepository repository,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      platformInstitutionListRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<PlatformInstitutionListState> _listen(
  ProviderContainer container,
) {
  final subscription = container.listen(
    platformInstitutionListControllerProvider,
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

PlatformInstitutionListPage _page({
  String label = 'Example',
  List<PlatformInstitutionSummary>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 3,
}) {
  return PlatformInstitutionListPage(
    institutions:
        rows ??
        [
          PlatformInstitutionSummary(
            id: '00000000-0000-0000-0000-000000000001',
            name: '$label School',
            type: PlatformInstitutionType.school,
            status: PlatformInstitutionStatus.active,
            contactEmail: 'info@example.uz',
            contactPhone: '+998901234567',
            createdAt: DateTime.utc(2026, 8, 7, 15),
            updatedAt: DateTime.utc(2026, 8, 7, 16),
            userCounts: const PlatformInstitutionUserCounts(
              total: 42,
              active: 40,
            ),
          ),
        ],
    pagination: PlatformInstitutionPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    ),
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
        message: 'Server message is not used for list state logic.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Local institution list failure.'),
  );
}

class FakePlatformInstitutionListRepository
    implements PlatformInstitutionListRepository {
  FakePlatformInstitutionListRepository({this.onFetch});

  Future<PlatformInstitutionListPage> Function(
    PlatformInstitutionListQuery query,
  )?
  onFetch;
  final queries = <PlatformInstitutionListQuery>[];

  int get fetchCalls => queries.length;

  @override
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) {
    queries.add(query);

    return onFetch?.call(query) ?? Future.value(_page(page: query.page));
  }
}

class FakeAuthSessionController extends AuthSessionController {
  FakeAuthSessionController(this.initialState);

  factory FakeAuthSessionController.authenticated(AuthUser user) {
    return FakeAuthSessionController(AuthSessionState.authenticated(user));
  }

  final AuthSessionState initialState;
  AuthSessionState Function()? onBootstrap;
  AuthSessionState Function(String login, String password)? onSignIn;
  var bootstrapCalls = 0;
  var signInCalls = 0;
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
  Future<void> signIn({required String login, required String password}) async {
    signInCalls += 1;
    state =
        onSignIn?.call(login, password) ??
        AuthSessionState.authenticated(_owner(login));
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    state = const AuthSessionState.unauthenticated();
  }
}
