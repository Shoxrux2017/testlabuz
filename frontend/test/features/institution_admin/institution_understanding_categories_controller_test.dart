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
import 'package:testlabuz_client/features/institution_admin/application/institution_understanding_categories_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_understanding_categories_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_understanding_categories_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_understanding_categories.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_understanding_categories_repository.dart';

void main() {
  test(
    'eligible route loads once and invalid local submit sends no PUT',
    () async {
      final harness = _harness();
      await _flush();

      expect(
        harness.read().status,
        InstitutionUnderstandingCategoriesStatus.configuredConfirmed,
      );
      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionUnderstandingCategoryField.understoodWellMin,
        '1e2',
      );
      await harness.controller.submit();

      expect(
        harness.read().status,
        InstitutionUnderstandingCategoriesStatus.validationFailure,
      );
      expect(
        harness.read().focusField,
        InstitutionUnderstandingCategoryField.understoodWellMin,
      );
      expect(harness.repository.fetchCalls, 1);
      expect(harness.repository.updateCalls, 0);
    },
  );

  test('ineligible session, route and device issue no requests', () async {
    for (final fixture in <(AuthSessionState, String, AppDeviceSurface)>[
      (
        AuthSessionState.authenticated(_admin(role: UserRole.teacher)),
        _route,
        AppDeviceSurface.desktop,
      ),
      (
        AuthSessionState.authenticated(_admin()),
        '$_route/categories',
        AppDeviceSurface.desktop,
      ),
      (
        AuthSessionState.authenticated(_admin(isActive: false)),
        _route,
        AppDeviceSurface.desktop,
      ),
      (
        AuthSessionState.authenticated(_admin(mustChangePassword: true)),
        _route,
        AppDeviceSurface.desktop,
      ),
      (
        AuthSessionState.authenticated(_admin(institutionId: null)),
        _route,
        AppDeviceSurface.desktop,
      ),
      (
        AuthSessionState.authenticated(_admin(institutionStatus: 'inactive')),
        _route,
        AppDeviceSurface.desktop,
      ),
      (
        const AuthSessionState.unauthenticated(),
        _route,
        AppDeviceSurface.desktop,
      ),
      (
        AuthSessionState.authenticated(_admin()),
        _route,
        AppDeviceSurface.mobile,
      ),
    ]) {
      final repository = _FakeRepository();
      final auth = _FakeAuthController(fixture.$1);
      final container = ProviderContainer(
        overrides: [
          authSessionControllerProvider.overrideWith(() => auth),
          appDeviceSurfaceProvider.overrideWithValue(fixture.$3),
          institutionUnderstandingCategoriesRepositoryProvider
              .overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final eligibleUser = _admin();
      final key = InstitutionUnderstandingCategoriesSessionKey(
        userId: eligibleUser.id,
        userInstance: eligibleUser,
        institutionId: eligibleUser.institutionId!,
        sessionGeneration: identityHashCode(
          container.read(authSessionControllerProvider),
        ),
        routePath: fixture.$2,
      );
      final subscription = container.listen(
        institutionUnderstandingCategoriesControllerProvider(key),
        (_, _) {},
        fireImmediately: true,
      );
      await _flush();

      expect(
        subscription.read().status,
        InstitutionUnderstandingCategoriesStatus.initial,
      );
      expect(repository.fetchCalls, 0);
      subscription.close();
    }
  });

  test('strict matching result is the only direct success', () async {
    final repository = _FakeRepository(
      onUpdate: (_, request) async => _fromRequest(request),
    );
    final harness = _harness(repository: repository);
    await _flush();
    _editValidPartition(harness);

    await harness.controller.submit();

    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 1);
    expect(
      harness.read().status,
      InstitutionUnderstandingCategoriesStatus.confirmedDirectSuccess,
    );
    expect(harness.read().notice, 'Understanding categories saved.');
    expect(
      harness.container
          .read(institutionUnderstandingCategoriesStaleStoreProvider)
          .isStale(harness.key),
      isFalse,
    );
  });

  test('unknown PUT is not replayed and performs exactly one GET', () async {
    final repository = _FakeRepository(
      onFetch: (call) async => call == 1 ? _configuration() : _changed(),
      onUpdate: (_, _) async =>
          throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException(),
    );
    final harness = _harness(repository: repository);
    await _flush();
    _editValidPartition(harness);

    await harness.controller.submit();

    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 2);
    expect(
      harness.read().status,
      InstitutionUnderstandingCategoriesStatus.unconfirmedCurrentState,
    );
    expect(
      harness.read().notice,
      'Current server categories match your submitted ranges, but this request result could not be confirmed.',
    );
    expect(harness.read().notice, isNot(contains('saved')));
    expect(
      harness.container
          .read(institutionUnderstandingCategoriesStaleStoreProvider)
          .isStale(harness.key),
      isFalse,
    );
  });

  test('reconciliation distinguishes different and unconfigured state', () async {
    for (final fixture in <(InstitutionUnderstandingCategoryConfiguration, String)>[
      (
        _configuration(),
        'Current server categories differ from your submitted ranges. This request result could not be confirmed.',
      ),
      (
        InstitutionUnderstandingCategoryConfiguration.unconfigured(),
        'Current server categories are not configured. This request result could not be confirmed.',
      ),
    ]) {
      final repository = _FakeRepository(
        onFetch: (call) async => call == 1 ? _configuration() : fixture.$1,
        onUpdate: (_, _) async =>
            throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException(),
      );
      final harness = _harness(repository: repository);
      await _flush();
      _editValidPartition(harness);

      await harness.controller.submit();

      expect(repository.updateCalls, 1);
      expect(repository.fetchCalls, 2);
      expect(
        harness.read().status,
        InstitutionUnderstandingCategoriesStatus.unconfirmedCurrentState,
      );
      expect(harness.read().notice, fixture.$2);
      expect(harness.read().notice, isNot(contains('saved')));
    }
  });

  test('failed reconciliation stays unconfirmed and stale', () async {
    final repository = _FakeRepository(
      onFetch: (call) async {
        if (call == 1) return _configuration();
        throw StateError('controlled reconciliation failure');
      },
      onUpdate: (_, _) async =>
          throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException(),
    );
    final harness = _harness(repository: repository);
    await _flush();
    _editValidPartition(harness);

    await harness.controller.submit();

    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 2);
    expect(
      harness.read().status,
      InstitutionUnderstandingCategoriesStatus.unconfirmedWithoutCurrentState,
    );
    expect(harness.read().notice, isNot(contains('saved')));
    expect(
      harness.container
          .read(institutionUnderstandingCategoriesStaleStoreProvider)
          .isStale(harness.key),
      isTrue,
    );
  });

  test(
    'definite 422 preserves draft and maps only canonical field paths',
    () async {
      final repository = _FakeRepository(
        onUpdate: (_, _) async => throw ApiRequestException(
          _failure(
            422,
            ApiErrorCodes.validationFailed,
            fields: {
              'categories.0.min_score': ['Private detail'],
              'categories.4.min_score': ['Unexpected final item'],
            },
          ),
        ),
      );
      final harness = _harness(repository: repository);
      await _flush();
      _editValidPartition(harness);

      await harness.controller.submit();

      expect(repository.updateCalls, 1);
      expect(repository.fetchCalls, 1);
      expect(
        harness.read().status,
        InstitutionUnderstandingCategoriesStatus.validationFailure,
      );
      expect(
        harness.read().draft!.valueFor(
          InstitutionUnderstandingCategoryField.understoodWellMin,
        ),
        '87',
      );
      expect(harness.read().fieldErrors.keys, [
        InstitutionUnderstandingCategoryField.understoodWellMin,
      ]);
      expect(harness.read().formError, contains('safely'));
      expect(
        harness.read().fieldErrors.values.single,
        isNot(contains('Private')),
      );
    },
  );

  test(
    'no-change, dirty Refresh and duplicate Save have exact request counts',
    () async {
      final completion =
          Completer<InstitutionUnderstandingCategoryConfiguration>();
      final repository = _FakeRepository(onUpdate: (_, _) => completion.future);
      final harness = _harness(repository: repository);
      await _flush();

      harness.controller.beginEditing();
      await harness.controller.submit();
      expect(harness.read().notice, 'No changes to save.');
      expect(repository.updateCalls, 0);

      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionUnderstandingCategoryField.understoodWellMin,
        '87',
      );
      expect(await harness.controller.refresh(), isFalse);
      expect(repository.fetchCalls, 1);
      expect(await harness.controller.refresh(discardDirty: true), isTrue);
      expect(repository.fetchCalls, 2);

      _editValidPartition(harness);
      final first = harness.controller.submit();
      final duplicate = harness.controller.submit();
      await _flush();
      expect(repository.updateCalls, 1);
      expect(
        harness.container
            .read(institutionUnderstandingCategoriesStaleStoreProvider)
            .isStale(harness.key),
        isTrue,
      );
      completion.complete(_changed());
      await Future.wait([first, duplicate]);
      expect(repository.updateCalls, 1);
    },
  );

  test('session replacement suppresses stale in-flight completion', () async {
    final completion =
        Completer<InstitutionUnderstandingCategoryConfiguration>();
    final auth = _FakeAuthController(AuthSessionState.authenticated(_admin()));
    final repository = _FakeRepository(onUpdate: (_, _) => completion.future);
    final harness = _harness(auth: auth, repository: repository);
    await _flush();
    _editValidPartition(harness);
    final operation = harness.controller.submit();
    await _flush();

    auth.setSession(const AuthSessionState.unauthenticated());
    await _flush();
    completion.complete(_changed());
    await operation;

    expect(
      harness.read().status,
      InstitutionUnderstandingCategoriesStatus.initial,
    );
    expect(harness.read().configuration, isNull);
  });

  test(
    'authentication and actor-state failures bootstrap and clear data',
    () async {
      for (final fixture in <(int, String)>[
        (401, ApiErrorCodes.authenticationRequired),
        (403, ApiErrorCodes.userInactive),
        (403, ApiErrorCodes.institutionInactive),
        (403, ApiErrorCodes.passwordChangeRequired),
      ]) {
        final auth = _FakeAuthController(
          AuthSessionState.authenticated(_admin()),
        );
        final repository = _FakeRepository(
          onUpdate: (_, _) async =>
              throw ApiRequestException(_failure(fixture.$1, fixture.$2)),
        );
        final harness = _harness(auth: auth, repository: repository);
        await _flush();
        _editValidPartition(harness);

        await harness.controller.submit();

        expect(
          harness.read().status,
          InstitutionUnderstandingCategoriesStatus.initial,
          reason: fixture.$2,
        );
        expect(harness.read().configuration, isNull);
        expect(auth.bootstrapCalls, 1);
      }
    },
  );

  test('forbidden and rate limiting are definite without bootstrap', () async {
    for (final fixture in <(int, String, String)>[
      (
        403,
        ApiErrorCodes.forbidden,
        'You do not have permission to change understanding categories.',
      ),
      (
        429,
        ApiErrorCodes.rateLimited,
        'Too many category requests were made. Wait before submitting a new explicit request.',
      ),
    ]) {
      final auth = _FakeAuthController(
        AuthSessionState.authenticated(_admin()),
      );
      final repository = _FakeRepository(
        onUpdate: (_, _) async =>
            throw ApiRequestException(_failure(fixture.$1, fixture.$2)),
      );
      final harness = _harness(auth: auth, repository: repository);
      await _flush();
      _editValidPartition(harness);

      await harness.controller.submit();

      expect(
        harness.read().status,
        InstitutionUnderstandingCategoriesStatus.definiteFailure,
      );
      expect(harness.read().formError, fixture.$3);
      expect(harness.read().draft, isNotNull);
      expect(auth.bootstrapCalls, 0);
      expect(repository.fetchCalls, 1);
      expect(
        harness.container
            .read(institutionUnderstandingCategoriesStaleStoreProvider)
            .isStale(harness.key),
        isFalse,
      );
    }
  });

  test('stale marker survives same-session controller disposal', () async {
    final completion =
        Completer<InstitutionUnderstandingCategoryConfiguration>();
    final harness = _harness(
      repository: _FakeRepository(onUpdate: (_, _) => completion.future),
    );
    await _flush();
    _editValidPartition(harness);
    final operation = harness.controller.submit();
    await _flush();
    expect(
      harness.container
          .read(institutionUnderstandingCategoriesStaleStoreProvider)
          .isStale(harness.key),
      isTrue,
    );

    harness.subscription.close();
    await _flush();

    expect(
      harness.container
          .read(institutionUnderstandingCategoriesStaleStoreProvider)
          .isStale(harness.key),
      isTrue,
    );
    completion.complete(_changed());
    await operation;
  });
}

const _route = '/institution-admin/settings';
const _institutionId = '550e8400-e29b-41d4-a716-446655440000';

_Harness _harness({_FakeAuthController? auth, _FakeRepository? repository}) {
  final resolvedAuth =
      auth ?? _FakeAuthController(AuthSessionState.authenticated(_admin()));
  final resolvedRepository = repository ?? _FakeRepository();
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => resolvedAuth),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionUnderstandingCategoriesRepositoryProvider.overrideWithValue(
        resolvedRepository,
      ),
    ],
  );
  addTearDown(container.dispose);
  final key = InstitutionUnderstandingCategoriesSessionSnapshot.from(
    session: container.read(authSessionControllerProvider),
    surface: AppDeviceSurface.desktop,
  ).eligibleKeyFor(_route)!;
  final provider = institutionUnderstandingCategoriesControllerProvider(key);
  final subscription = container.listen(
    provider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return _Harness(
    container: container,
    provider: provider,
    subscription: subscription,
    key: key,
    auth: resolvedAuth,
    repository: resolvedRepository,
  );
}

class _Harness {
  const _Harness({
    required this.container,
    required this.provider,
    required this.subscription,
    required this.key,
    required this.auth,
    required this.repository,
  });

  final ProviderContainer container;
  final NotifierProvider<
    InstitutionUnderstandingCategoriesController,
    InstitutionUnderstandingCategoriesState
  >
  provider;
  final ProviderSubscription<InstitutionUnderstandingCategoriesState>
  subscription;
  final InstitutionUnderstandingCategoriesSessionKey key;
  final _FakeAuthController auth;
  final _FakeRepository repository;

  InstitutionUnderstandingCategoriesState read() => subscription.read();
  InstitutionUnderstandingCategoriesController get controller =>
      container.read(provider.notifier);
}

class _FakeRepository implements InstitutionUnderstandingCategoriesRepository {
  _FakeRepository({this.onFetch, this.onUpdate});

  final Future<InstitutionUnderstandingCategoryConfiguration> Function(
    int call,
  )?
  onFetch;
  final Future<InstitutionUnderstandingCategoryConfiguration> Function(
    int call,
    InstitutionUnderstandingCategoryUpdateRequest request,
  )?
  onUpdate;
  var fetchCalls = 0;
  var updateCalls = 0;

  @override
  Future<InstitutionUnderstandingCategoryConfiguration> fetchCategories() {
    fetchCalls += 1;
    return onFetch?.call(fetchCalls) ?? Future.value(_configuration());
  }

  @override
  Future<InstitutionUnderstandingCategoryConfiguration> replaceCategories(
    InstitutionUnderstandingCategoryUpdateRequest request,
  ) {
    updateCalls += 1;
    return onUpdate?.call(updateCalls, request) ??
        Future.value(_configuration());
  }
}

class _FakeAuthController extends AuthSessionController {
  _FakeAuthController(this.initialState);

  final AuthSessionState initialState;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => initialState;

  void setSession(AuthSessionState next) => state = next;

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
  }
}

AuthUser _admin({
  String? institutionId = _institutionId,
  UserRole role = UserRole.institutionAdmin,
  bool isActive = true,
  bool mustChangePassword = false,
  String institutionStatus = 'active',
}) => AuthUser(
  id: 'admin-a',
  institutionId: institutionId,
  role: role,
  fullName: 'Admin',
  loginName: 'admin',
  email: null,
  phone: null,
  isActive: isActive,
  mustChangePassword: mustChangePassword,
  institution: institutionId == null
      ? null
      : AuthInstitution(
          id: institutionId,
          name: 'School',
          status: institutionStatus,
          timezone: 'Asia/Tashkent',
        ),
);

void _editValidPartition(_Harness harness) {
  harness.controller.beginEditing();
  harness.controller.updateField(
    InstitutionUnderstandingCategoryField.understoodWellMin,
    '87',
  );
  harness.controller.updateField(
    InstitutionUnderstandingCategoryField.partiallyUnderstoodMax,
    '86',
  );
}

InstitutionUnderstandingCategoryConfiguration _fromRequest(
  InstitutionUnderstandingCategoryUpdateRequest request,
) => InstitutionUnderstandingCategoryConfiguration.configured([
  for (final item in request.categories)
    InstitutionUnderstandingCategory(
      definition: item.definition,
      minScore: item.minScore,
      maxScore: item.maxScore,
    ),
]);

InstitutionUnderstandingCategoryConfiguration _configuration() =>
    InstitutionUnderstandingCategoryConfiguration.configured(const [
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.understoodWell,
        minScore: 86,
        maxScore: 100,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.partiallyUnderstood,
        minScore: 71,
        maxScore: 85,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsRevision,
        minScore: 51,
        maxScore: 70,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsTeacherSupport,
        minScore: 0,
        maxScore: 50,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.notCompleted,
        minScore: null,
        maxScore: null,
      ),
    ]);

InstitutionUnderstandingCategoryConfiguration _changed() =>
    InstitutionUnderstandingCategoryConfiguration.configured(const [
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.understoodWell,
        minScore: 87,
        maxScore: 100,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.partiallyUnderstood,
        minScore: 71,
        maxScore: 86,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsRevision,
        minScore: 51,
        maxScore: 70,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsTeacherSupport,
        minScore: 0,
        maxScore: 50,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.notCompleted,
        minScore: null,
        maxScore: null,
      ),
    ]);

ApiFailure _failure(
  int status,
  String code, {
  Map<String, List<String>> fields = const {},
}) => ApiFailure.fromServerError(
  statusCode: status,
  error: ApiErrorResponse(
    message: 'Private detail',
    code: code,
    fieldErrors: fields,
    requestId: 'private-request-id',
  ),
);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
