import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_list_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_repository.dart';

void main() {
  group('InstitutionGroupListController', () {
    test(
      'eligible desktop Admin loads once and classifies all result states',
      () async {
        final repository = _FakeGroupListRepository();
        final container = _container(repository: repository);
        final subscription = _listen(container);

        await _flush();

        expect(repository.queries, [const InstitutionGroupListQuery.initial()]);
        expect(subscription.read().status, InstitutionGroupListStatus.data);
        expect(
          InstitutionGroupListState.fromResult(
            query: const InstitutionGroupListQuery.initial(),
            searchDraft: '',
            result: _page(rows: const [], total: 0),
          ).status,
          InstitutionGroupListStatus.globalEmpty,
        );
        expect(
          InstitutionGroupListState.fromResult(
            query: const InstitutionGroupListQuery.initial().withStatus(
              InstitutionGroupStatusFilter.active,
            ),
            searchDraft: '',
            result: _page(rows: const [], total: 0),
          ).status,
          InstitutionGroupListStatus.filteredEmpty,
        );
        expect(
          InstitutionGroupListState.fromResult(
            query: const InstitutionGroupListQuery.initial().copyWith(page: 2),
            searchDraft: '',
            result: _page(rows: const [], page: 2, total: 21, lastPage: 2),
          ).status,
          InstitutionGroupListStatus.emptyPage,
        );
      },
    );

    test('300 ms debounce Enter and pending actions send one query', () async {
      final repository = _FakeGroupListRepository();
      final container = _container(repository: repository);
      _listen(container);
      await _flush();
      final controller = container.read(
        institutionGroupListControllerProvider.notifier,
      );

      controller.updateSearchDraft('  Ali  ');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(repository.fetchCalls, 1);
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(repository.fetchCalls, 2);
      expect(repository.queries.last.search, 'Ali');

      controller.updateSearchDraft('  Vali % _  ');
      controller.commitSearchNow();
      await _flush();
      expect(repository.fetchCalls, 3);
      expect(repository.queries.last.search, 'Vali % _');
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repository.fetchCalls, 3);

      controller.updateSearchDraft('Merged');
      controller.setStatus(InstitutionGroupStatusFilter.archived);
      await _flush();
      expect(repository.fetchCalls, 4);
      expect(repository.queries.last.search, 'Merged');
      expect(
        repository.queries.last.status,
        InstitutionGroupStatusFilter.archived,
      );

      controller.updateSearchDraft('Refresh merge');
      controller.refresh();
      await _flush();
      expect(repository.fetchCalls, 5);
      expect(repository.queries.last.search, 'Refresh merge');
      expect(repository.queries.last.page, 1);
    });

    test('invalid draft blocks every action except Clear filters', () async {
      final repository = _FakeGroupListRepository();
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await _flush();
      final controller = container.read(
        institutionGroupListControllerProvider.notifier,
      );

      controller.updateSearchDraft(List.filled(255, '😀').join());
      controller.commitSearchNow();
      controller.setStatus(InstitutionGroupStatusFilter.archived);
      controller.toggleSort(InstitutionGroupListSort.createdAt);
      controller.setPerPage(50);
      controller.previousPage();
      controller.nextPage();
      controller.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 320));

      expect(repository.fetchCalls, 1);
      expect(
        subscription.read().searchErrorText,
        'Search must be 254 characters or fewer.',
      );

      controller.clearFilters();
      await _flush();
      expect(repository.fetchCalls, 1);
      expect(subscription.read().searchDraft, '');
      expect(subscription.read().searchErrorText, isNull);
    });

    test('every pending-search action commits once on page 1', () async {
      final repository = _FakeGroupListRepository(
        onFetch: (query) async => _page(
          page: query.page,
          perPage: query.perPage,
          total: query.perPage * 3,
          lastPage: 3,
        ),
      );
      final container = _container(repository: repository);
      _listen(container);
      await _flush();
      final controller = container.read(
        institutionGroupListControllerProvider.notifier,
      );

      Future<void> returnToPageTwo() async {
        controller.nextPage();
        await _flush();
        expect(repository.queries.last.page, 2);
      }

      await returnToPageTwo();
      controller.updateSearchDraft('Status pending');
      controller.setStatus(InstitutionGroupStatusFilter.active);
      await _flush();

      await returnToPageTwo();
      controller.updateSearchDraft('Sort pending');
      controller.toggleSort(InstitutionGroupListSort.createdAt);
      await _flush();

      await returnToPageTwo();
      controller.updateSearchDraft('Size pending');
      controller.setPerPage(50);
      await _flush();

      await returnToPageTwo();
      controller.updateSearchDraft('Refresh pending');
      controller.refresh();
      await _flush();

      await returnToPageTwo();
      controller.updateSearchDraft('Previous pending');
      controller.previousPage();
      await _flush();

      await returnToPageTwo();
      controller.updateSearchDraft('Next pending');
      controller.nextPage();
      await _flush();

      final pendingQueries = repository.queries.where(
        (query) =>
            query.page == 1 && (query.search?.endsWith('pending') ?? false),
      );
      expect(pendingQueries.map((query) => query.search), [
        'Status pending',
        'Sort pending',
        'Size pending',
        'Refresh pending',
        'Previous pending',
        'Next pending',
      ]);
      expect(pendingQueries.every((query) => query.page == 1), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(
        repository.queries.where(
          (query) =>
              query.page == 1 && (query.search?.endsWith('pending') ?? false),
        ),
        hasLength(6),
      );
    });

    test(
      'sort size pagination clear refresh and retry preserve exact query',
      () async {
        var failNext = false;
        final repository = _FakeGroupListRepository(
          onFetch: (query) async {
            if (failNext) {
              failNext = false;
              throw _localFailure(ApiFailureKind.connection);
            }
            return _page(
              page: query.page,
              perPage: query.perPage,
              total: query.perPage * 3,
              lastPage: 3,
            );
          },
        );
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await _flush();
        final controller = container.read(
          institutionGroupListControllerProvider.notifier,
        );

        controller.toggleSort(InstitutionGroupListSort.updatedAt);
        await _flush();
        controller.toggleSort(InstitutionGroupListSort.updatedAt);
        await _flush();
        controller.setPerPage(50);
        await _flush();
        controller.nextPage();
        await _flush();
        controller.previousPage();
        await _flush();
        expect(repository.queries.last.toQueryParameters(), {
          'page': 1,
          'per_page': 50,
          'sort': 'updated_at',
          'direction': 'desc',
        });

        controller.updateSearchDraft('Pending next');
        controller.nextPage();
        await _flush();
        expect(repository.queries.last.search, 'Pending next');
        expect(repository.queries.last.page, 1);

        controller.clearFilters();
        await _flush();
        expect(repository.queries.last.search, isNull);
        expect(repository.queries.last.perPage, 50);
        expect(
          repository.queries.last.sort,
          InstitutionGroupListSort.updatedAt,
        );
        expect(
          repository.queries.last.direction,
          InstitutionGroupSortDirection.desc,
        );

        final beforeRefresh = repository.queries.last;
        controller.refresh();
        controller.refresh();
        await _flush();
        expect(repository.queries.last, beforeRefresh);
        expect(subscription.read().status, InstitutionGroupListStatus.data);

        failNext = true;
        controller.refresh();
        await _flush();
        expect(subscription.read().status, InstitutionGroupListStatus.error);
        final failedQuery = subscription.read().query;
        controller.retry();
        controller.retry();
        await _flush();
        expect(repository.queries.last, failedQuery);
        expect(subscription.read().status, InstitutionGroupListStatus.data);
      },
    );

    test('latest logical query wins over stale success and error', () async {
      final first = Completer<InstitutionGroupListPage>();
      final second = Completer<InstitutionGroupListPage>();
      final repository = _FakeGroupListRepository();
      repository.onFetch = (_) =>
          repository.fetchCalls == 1 ? first.future : second.future;
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await _flush();

      final controller = container.read(
        institutionGroupListControllerProvider.notifier,
      );
      controller.updateSearchDraft('New');
      controller.commitSearchNow();
      await _flush();
      expect(subscription.read().result, isNull);

      second.complete(_page(label: 'New'));
      await _flush();
      first.completeError(_localFailure(ApiFailureKind.connection));
      await _flush();

      expect(subscription.read().status, InstitutionGroupListStatus.data);
      expect(subscription.read().result?.groups.single.name, 'New Group');
    });

    test('completion after controller disposal cannot publish', () async {
      final pending = Completer<InstitutionGroupListPage>();
      final repository = _FakeGroupListRepository(
        onFetch: (_) => pending.future,
      );
      final container = _container(repository: repository);
      final published = <InstitutionGroupListState>[];
      final subscription = container.listen(
        institutionGroupListControllerProvider,
        (_, next) => published.add(next),
        fireImmediately: true,
      );
      await _flush();
      expect(repository.fetchCalls, 1);
      final countAtDispose = published.length;

      subscription.close();
      await _flush();
      pending.complete(_page(label: 'Disposed'));
      await _flush();

      expect(published, hasLength(countAtDispose));
      expect(
        published.any(
          (state) =>
              state.result?.groups.any(
                (group) => group.name == 'Disposed Group',
              ) ??
              false,
        ),
        isFalse,
      );
    });

    test('one correction uses bounded target and never loops', () async {
      var correctionPhase = false;
      final repository = _FakeGroupListRepository();
      repository.onFetch = (query) async {
        if (query.page == 4) {
          correctionPhase = true;
          return _page(rows: const [], page: 4, total: 41, lastPage: 3);
        }
        if (correctionPhase && query.page == 3) {
          return _page(rows: const [], page: 3, total: 41, lastPage: 3);
        }
        return _page(
          page: query.page,
          perPage: query.perPage,
          total: 100,
          lastPage: 5,
        );
      };
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await _flush();
      final controller = container.read(
        institutionGroupListControllerProvider.notifier,
      );

      for (var page = 2; page <= 4; page++) {
        controller.nextPage();
        await _flush();
      }

      expect(repository.queries.map((query) => query.page), [1, 2, 3, 4, 3]);
      expect(subscription.read().query.page, 3);
      expect(subscription.read().status, InstitutionGroupListStatus.emptyPage);
    });

    test('zero-total out-of-range correction targets page 1 once', () async {
      var correctionPhase = false;
      final repository = _FakeGroupListRepository(
        onFetch: (query) async {
          if (query.page == 2) {
            correctionPhase = true;
            return _page(rows: const [], page: 2, total: 0, lastPage: 1);
          }
          if (correctionPhase) {
            return _page(rows: const [], page: 1, total: 0, lastPage: 1);
          }
          return _page(page: query.page, total: 40, lastPage: 2);
        },
      );
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await _flush();
      final controller = container.read(
        institutionGroupListControllerProvider.notifier,
      );

      controller.nextPage();
      await _flush();

      expect(repository.queries.map((query) => query.page), [1, 2, 1]);
      expect(subscription.read().query.page, 1);
      expect(
        subscription.read().status,
        InstitutionGroupListStatus.globalEmpty,
      );
    });

    test(
      'retains only same-session query and reloads it authoritatively',
      () async {
        final repository = _FakeGroupListRepository();
        final auth = _FakeAuthSessionController.authenticated(
          _admin('admin-a'),
        );
        final container = _container(repository: repository, auth: auth);
        var subscription = _listen(container);
        await _flush();
        final controller = container.read(
          institutionGroupListControllerProvider.notifier,
        );
        controller.updateSearchDraft('  retained draft  ');
        controller.setStatus(InstitutionGroupStatusFilter.active);
        await _flush();
        final retainedQuery = subscription.read().query;

        subscription.close();
        await _flush();
        subscription = _listen(container);
        await _flush();

        expect(repository.queries.last, retainedQuery);
        expect(subscription.read().searchDraft, '  retained draft  ');
        expect(subscription.read().result?.groups, isNotEmpty);

        auth.replaceUser(_admin('admin-b'));
        await _flush();
        expect(
          repository.queries.last,
          const InstitutionGroupListQuery.initial(),
        );
        expect(subscription.read().searchDraft, '');
      },
    );

    test(
      'session institution device and disposal boundaries reject stale data',
      () async {
        final old = Completer<InstitutionGroupListPage>();
        final replacement = Completer<InstitutionGroupListPage>();
        final repository = _FakeGroupListRepository();
        repository.onFetch = (_) =>
            repository.fetchCalls == 1 ? old.future : replacement.future;
        final auth = _FakeAuthSessionController.authenticated(
          _admin('admin-a'),
        );
        final container = _container(repository: repository, auth: auth);
        final subscription = _listen(container);
        await _flush();

        auth.replaceUser(_admin('admin-b'));
        await _flush();
        old.complete(_page(label: 'Old'));
        replacement.complete(_page(label: 'New'));
        await _flush();
        expect(subscription.read().result?.groups.single.name, 'New Group');

        auth.replaceUser(_admin('admin-b', nestedInstitutionId: 'other'));
        await _flush();
        expect(subscription.read().status, InstitutionGroupListStatus.initial);
        expect(subscription.read().result, isNull);

        final ineligibleRepository = _FakeGroupListRepository();
        final ineligibleContainer = _container(
          repository: ineligibleRepository,
          surface: AppDeviceSurface.mobile,
        );
        _listen(ineligibleContainer);
        await _flush();
        expect(ineligibleRepository.fetchCalls, 0);
      },
    );

    test(
      'session-authority failures clear data and reconcile auth state',
      () async {
        for (final code in [
          ApiErrorCodes.authenticationRequired,
          ApiErrorCodes.passwordChangeRequired,
          ApiErrorCodes.userInactive,
          ApiErrorCodes.institutionInactive,
        ]) {
          final auth = _FakeAuthSessionController.authenticated(
            _admin('admin-a'),
          );
          auth.onBootstrap = () => const AuthSessionState.unauthenticated();
          final repository = _FakeGroupListRepository(
            onFetch: (_) async => throw _serverFailure(code),
          );
          final container = _container(repository: repository, auth: auth);
          final subscription = _listen(container);
          await _flush();

          expect(
            subscription.read().status,
            InstitutionGroupListStatus.initial,
          );
          expect(subscription.read().result, isNull);
          expect(
            auth.bootstrapCalls,
            code == ApiErrorCodes.authenticationRequired ? 0 : 1,
          );
        }
      },
    );
  });
}

ProviderContainer _container({
  required _FakeGroupListRepository repository,
  _FakeAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () =>
            auth ?? _FakeAuthSessionController.authenticated(_admin('admin-a')),
      ),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      institutionGroupListRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<InstitutionGroupListState> _listen(
  ProviderContainer container,
) {
  final subscription = container.listen(
    institutionGroupListControllerProvider,
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

InstitutionGroupListPage _page({
  String label = 'Example',
  List<InstitutionGroup>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) {
  return InstitutionGroupListPage(
    groups: rows ?? [_group(name: '$label Group')],
    pagination: InstitutionGroupListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

InstitutionGroup _group({String name = 'Example Group'}) {
  return InstitutionGroup(
    id: '00000000-0000-0000-0000-000000000001',
    name: name,
    level: null,
    subjectDirection: null,
    description: null,
    status: InstitutionGroupStatus.active,
    teachersCount: 1,
    studentsCount: 10,
    archivedAt: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
  );
}

AuthUser _admin(
  String loginName, {
  String nestedInstitutionId = 'institution-1',
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: 'institution-1',
    role: UserRole.institutionAdmin,
    fullName: '$loginName User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: AuthInstitution(
      id: nestedInstitutionId,
      name: 'Example School',
      status: 'active',
      timezone: 'Asia/Tashkent',
    ),
  );
}

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Raw local failure.'),
  );
}

ApiRequestException _serverFailure(String code) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: code == ApiErrorCodes.authenticationRequired ? 401 : 403,
      error: ApiErrorResponse(
        message: 'Raw server failure.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

class _FakeGroupListRepository implements InstitutionGroupListRepository {
  _FakeGroupListRepository({this.onFetch});

  Future<InstitutionGroupListPage> Function(InstitutionGroupListQuery query)?
  onFetch;
  final queries = <InstitutionGroupListQuery>[];

  int get fetchCalls => queries.length;

  @override
  Future<InstitutionGroupListPage> fetchGroups(
    InstitutionGroupListQuery query,
  ) {
    queries.add(query);

    return onFetch?.call(query) ??
        Future.value(_page(page: query.page, perPage: query.perPage));
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.initialState);

  factory _FakeAuthSessionController.authenticated(AuthUser user) {
    return _FakeAuthSessionController(AuthSessionState.authenticated(user));
  }

  final AuthSessionState initialState;
  AuthSessionState Function()? onBootstrap;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => initialState;

  void replaceUser(AuthUser user) {
    state = AuthSessionState.authenticated(user);
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
    final next = onBootstrap?.call();
    if (next != null) {
      state = next;
    }
  }

  @override
  Future<void> signIn({required String login, required String password}) async {
    state = AuthSessionState.authenticated(_admin(login));
  }

  @override
  Future<void> signOut() async {
    state = const AuthSessionState.unauthenticated();
  }
}
