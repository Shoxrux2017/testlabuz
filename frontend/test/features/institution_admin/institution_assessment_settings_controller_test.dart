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
import 'package:testlabuz_client/features/institution_admin/application/institution_assessment_settings_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_assessment_settings_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_assessment_settings_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings_repository.dart';

void main() {
  test(
    'eligible exact route loads once and local invalid submit sends no PUT',
    () async {
      final harness = _harness();
      await _flush();

      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.confirmedData,
      );
      expect(harness.repository.fetchCalls, 1);
      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionAssessmentSettingsField.acceptableScoreDifference,
        '1e2',
      );
      await harness.controller.submit();

      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.validationFailure,
      );
      expect(
        harness.read().focusField,
        InstitutionAssessmentSettingsField.acceptableScoreDifference,
      );
      expect(harness.repository.updateCalls, 0);
    },
  );

  test(
    'complete ineligible session route and surface matrix issues zero requests',
    () async {
      final eligibleUser = _admin();
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
          AuthSessionState.authenticated(_admin(id: '')),
          _route,
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
        (const AuthSessionState.initial(), _route, AppDeviceSurface.desktop),
        (
          const AuthSessionState.bootstrapping(),
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
        final auth = _FakeAuthSessionController(fixture.$1);
        final repository = _FakeSettingsRepository();
        final container = ProviderContainer(
          overrides: [
            authSessionControllerProvider.overrideWith(() => auth),
            appDeviceSurfaceProvider.overrideWithValue(fixture.$3),
            institutionAssessmentSettingsRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
        addTearDown(container.dispose);
        final key = InstitutionAssessmentSettingsSessionKey(
          userId: eligibleUser.id,
          userInstance: eligibleUser,
          institutionId: eligibleUser.institutionId!,
          sessionGeneration: identityHashCode(
            container.read(authSessionControllerProvider),
          ),
          routePath: fixture.$2,
        );
        final subscription = container.listen(
          institutionAssessmentSettingsControllerProvider(key),
          (_, _) {},
          fireImmediately: true,
        );
        await _flush();

        expect(
          subscription.read().status,
          InstitutionAssessmentSettingsStatus.initial,
        );
        expect(repository.fetchCalls, 0);
        subscription.close();
      }
    },
  );

  test('strict matching 200 is the only causal direct success', () async {
    final repository = _FakeSettingsRepository(
      onUpdate: (_, request) async =>
          _settings(score: request.acceptableScoreDifference.canonical),
    );
    final harness = _harness(repository: repository);
    await _flush();
    harness.controller.beginEditing();
    harness.controller.updateField(
      InstitutionAssessmentSettingsField.acceptableScoreDifference,
      '7.25000000',
    );

    await harness.controller.submit();

    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 1);
    expect(
      harness.read().status,
      InstitutionAssessmentSettingsStatus.confirmedDirectSuccess,
    );
    expect(
      harness.read().settings?.acceptableScoreDifference?.canonical,
      '7.25',
    );
  });

  test(
    'unknown PUT outcome is never replayed and performs one GET reconciliation',
    () async {
      final repository = _FakeSettingsRepository(
        onFetch: (call) async =>
            call == 1 ? _settings() : _settings(score: '7.25'),
        onUpdate: (_, _) async =>
            throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException(),
      );
      final harness = _harness(repository: repository);
      await _flush();
      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionAssessmentSettingsField.acceptableScoreDifference,
        '7.25',
      );

      await harness.controller.submit();

      expect(repository.updateCalls, 1);
      expect(repository.fetchCalls, 2);
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.unconfirmedCurrentState,
      );
      expect(harness.read().notice, contains('could not be confirmed'));
      expect(harness.read().notice, isNot(contains('saved')));
    },
  );

  test(
    'definite 422 preserves draft, focuses mapped field, and does no GET',
    () async {
      final repository = _FakeSettingsRepository(
        onUpdate: (_, _) async => throw ApiRequestException(
          ApiFailure.fromServerError(
            statusCode: 422,
            error: ApiErrorResponse(
              message: 'Private validation detail.',
              code: ApiErrorCodes.validationFailed,
              fieldErrors: {
                'timezone': ['Private timezone detail.'],
              },
              requestId: null,
            ),
          ),
        ),
      );
      final harness = _harness(repository: repository);
      await _flush();
      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionAssessmentSettingsField.timezone,
        'Europe/London',
      );

      await harness.controller.submit();

      expect(repository.updateCalls, 1);
      expect(repository.fetchCalls, 1);
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.validationFailure,
      );
      expect(harness.read().draft?.timezone, 'Europe/London');
      expect(
        harness.read().focusField,
        InstitutionAssessmentSettingsField.timezone,
      );
      expect(
        harness.read().fieldErrors.values.single,
        isNot(contains('Private')),
      );
    },
  );

  test('session replacement suppresses stale in-flight completion', () async {
    final completion = Completer<InstitutionAssessmentSettings>();
    final auth = _FakeAuthSessionController(
      AuthSessionState.authenticated(_admin()),
    );
    final repository = _FakeSettingsRepository(
      onUpdate: (_, _) => completion.future,
    );
    final harness = _harness(auth: auth, repository: repository);
    await _flush();
    harness.controller.beginEditing();
    harness.controller.updateField(
      InstitutionAssessmentSettingsField.acceptableScoreDifference,
      '7.25',
    );
    final operation = harness.controller.submit();
    await _flush();
    auth.setSession(const AuthSessionState.unauthenticated());
    await _flush();
    completion.complete(_settings(score: '7.25'));
    await operation;

    expect(repository.updateCalls, 1);
    expect(harness.read().settings, isNull);
    expect(harness.read().status, InstitutionAssessmentSettingsStatus.initial);
  });

  test(
    'initial failure exposes Retry and refresh failure preserves data',
    () async {
      final repository = _FakeSettingsRepository(
        onFetch: (call) async {
          if (call == 1 || call == 3) {
            throw StateError('controlled read failure');
          }
          return _settings(score: '6');
        },
      );
      final harness = _harness(repository: repository);
      await _flush();

      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.loadError,
      );
      await harness.controller.retry();
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.confirmedData,
      );
      expect(
        harness.read().settings?.acceptableScoreDifference?.canonical,
        '6',
      );

      await harness.controller.refresh();
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.confirmedData,
      );
      expect(
        harness.read().settings?.acceptableScoreDifference?.canonical,
        '6',
      );
      expect(harness.read().notice, contains('last confirmed values'));
      expect(repository.fetchCalls, 3);
    },
  );

  test(
    'Cancel Reset no-change and dirty Refresh have exact request counts',
    () async {
      final repository = _FakeSettingsRepository(
        onFetch: (_) async => _partiallyConfiguredSettings(),
      );
      final harness = _harness(repository: repository);
      await _flush();

      harness.controller.beginEditing();
      expect(harness.read().draft?.acceptableScoreDifference, '7.5');
      expect(harness.read().draft?.studentResultReleaseMode, isNull);
      harness.controller.updateField(
        InstitutionAssessmentSettingsField.acceptableScoreDifference,
        '8',
      );
      harness.controller.cancelEditing();
      expect(harness.read().isEditing, isFalse);
      expect(repository.fetchCalls, 1);
      expect(repository.updateCalls, 0);

      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionAssessmentSettingsField.acceptableScoreDifference,
        '8',
      );
      harness.controller.resetDraft();
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.editingClean,
      );
      expect(harness.read().draft?.acceptableScoreDifference, '7.5');
      expect(repository.fetchCalls, 1);

      expect(await harness.controller.refresh(), isTrue);
      expect(repository.fetchCalls, 2);
      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionAssessmentSettingsField.acceptableScoreDifference,
        '8',
      );
      expect(await harness.controller.refresh(), isFalse);
      expect(repository.fetchCalls, 2);
      expect(await harness.controller.refresh(discardDirty: true), isTrue);
      expect(repository.fetchCalls, 3);
      expect(repository.updateCalls, 0);
    },
  );

  test(
    'no-change save sends no PUT and duplicate Save is deduplicated',
    () async {
      final update = Completer<InstitutionAssessmentSettings>();
      final repository = _FakeSettingsRepository(
        onUpdate: (_, _) => update.future,
      );
      final harness = _harness(repository: repository);
      await _flush();

      harness.controller.beginEditing();
      await harness.controller.submit();
      expect(harness.read().notice, 'No changes to save.');
      expect(repository.updateCalls, 0);

      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionAssessmentSettingsField.acceptableScoreDifference,
        '6',
      );
      final first = harness.controller.submit();
      final duplicate = harness.controller.submit();
      await _flush();
      expect(repository.updateCalls, 1);
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.submitting,
      );
      update.complete(_settings(score: '6'));
      await Future.wait([first, duplicate]);
      expect(repository.updateCalls, 1);
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.confirmedDirectSuccess,
      );
    },
  );

  test('refresh is deduplicated while a read is in flight', () async {
    final refresh = Completer<InstitutionAssessmentSettings>();
    final repository = _FakeSettingsRepository(
      onFetch: (call) => call == 1 ? Future.value(_settings()) : refresh.future,
    );
    final harness = _harness(repository: repository);
    await _flush();

    final first = harness.controller.refresh();
    await _flush();
    expect(await harness.controller.refresh(), isFalse);
    expect(repository.fetchCalls, 2);
    refresh.complete(_settings(score: '7'));
    expect(await first, isTrue);
    expect(harness.read().settings?.acceptableScoreDifference?.canonical, '7');
  });

  test(
    'mismatched or unconfigured direct 200 reconciles without success',
    () async {
      for (final returned in [_settings(score: '8'), _unconfiguredSettings()]) {
        final repository = _FakeSettingsRepository(
          onFetch: (call) async => call == 1 ? _settings() : returned,
          onUpdate: (_, _) async => returned,
        );
        final harness = _harness(repository: repository);
        await _flush();
        harness.controller.beginEditing();
        harness.controller.updateField(
          InstitutionAssessmentSettingsField.acceptableScoreDifference,
          '6',
        );

        await harness.controller.submit();

        expect(repository.updateCalls, 1);
        expect(repository.fetchCalls, 2);
        expect(
          harness.read().status,
          InstitutionAssessmentSettingsStatus.unconfirmedCurrentState,
        );
        expect(harness.read().notice, isNot(contains('saved')));
      }
    },
  );

  test(
    'exact 401 clears protected state and starts global auth bootstrap',
    () async {
      for (final mutation in [false, true]) {
        final auth = _FakeAuthSessionController(
          AuthSessionState.authenticated(_admin()),
        );
        final repository = _FakeSettingsRepository(
          onFetch: (_) async {
            if (!mutation) {
              throw ApiRequestException(
                _serverFailure(401, ApiErrorCodes.authenticationRequired),
              );
            }
            return _settings();
          },
          onUpdate: (_, _) async => throw ApiRequestException(
            _serverFailure(401, ApiErrorCodes.authenticationRequired),
          ),
        );
        final harness = _harness(auth: auth, repository: repository);
        await _flush();
        if (mutation) {
          harness.controller.beginEditing();
          harness.controller.updateField(
            InstitutionAssessmentSettingsField.acceptableScoreDifference,
            '6',
          );
          await harness.controller.submit();
        }

        expect(
          harness.read().status,
          InstitutionAssessmentSettingsStatus.initial,
        );
        expect(harness.read().settings, isNull);
        expect(harness.read().draft, isNull);
        expect(auth.bootstrapCalls, 1);
        expect(repository.updateCalls, mutation ? 1 : 0);
      }
    },
  );

  test(
    'actor-state errors bootstrap globally while forbidden and 429 do not',
    () async {
      for (final code in [
        ApiErrorCodes.userInactive,
        ApiErrorCodes.institutionInactive,
        ApiErrorCodes.passwordChangeRequired,
      ]) {
        final auth = _FakeAuthSessionController(
          AuthSessionState.authenticated(_admin()),
        );
        final repository = _FakeSettingsRepository(
          onUpdate: (_, _) async =>
              throw ApiRequestException(_serverFailure(403, code)),
        );
        final harness = _harness(auth: auth, repository: repository);
        await _flush();
        _editScore(harness, '6');
        await harness.controller.submit();
        expect(
          harness.read().status,
          InstitutionAssessmentSettingsStatus.initial,
        );
        expect(auth.bootstrapCalls, 1, reason: code);
      }

      for (final fixture in [
        (403, ApiErrorCodes.forbidden),
        (429, ApiErrorCodes.rateLimited),
      ]) {
        final auth = _FakeAuthSessionController(
          AuthSessionState.authenticated(_admin()),
        );
        final repository = _FakeSettingsRepository(
          onUpdate: (_, _) async =>
              throw ApiRequestException(_serverFailure(fixture.$1, fixture.$2)),
        );
        final harness = _harness(auth: auth, repository: repository);
        await _flush();
        _editScore(harness, '6');
        await harness.controller.submit();
        expect(
          harness.read().status,
          InstitutionAssessmentSettingsStatus.definiteFailure,
        );
        expect(harness.read().formError, isNot(contains('Private')));
        expect(auth.bootstrapCalls, 0);
        expect(repository.fetchCalls, 1);
      }
    },
  );

  test(
    'unknown validation keys become safe form-level protocol feedback',
    () async {
      final repository = _FakeSettingsRepository(
        onUpdate: (_, _) async => throw ApiRequestException(
          _serverFailure(
            422,
            ApiErrorCodes.validationFailed,
            fields: {
              'institution_id': ['Private tenant detail'],
              'body': ['Private body detail'],
            },
          ),
        ),
      );
      final harness = _harness(repository: repository);
      await _flush();
      _editScore(harness, '6');
      await harness.controller.submit();

      expect(harness.read().fieldErrors, isEmpty);
      expect(harness.read().formError, contains('could not validate'));
      expect(harness.read().formError, isNot(contains('Private')));
      expect(repository.fetchCalls, 1);
    },
  );

  test('failed reconciliation performs one GET and keeps stale marker', () async {
    final repository = _FakeSettingsRepository(
      onFetch: (call) async {
        if (call == 1) return _settings();
        throw StateError('reconciliation unavailable');
      },
      onUpdate: (_, _) async =>
          throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException(),
    );
    final harness = _harness(repository: repository);
    await _flush();
    _editScore(harness, '6');
    await harness.controller.submit();

    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 2);
    expect(
      harness.read().status,
      InstitutionAssessmentSettingsStatus.unconfirmedWithoutCurrentState,
    );
    expect(
      harness.container
          .read(institutionAssessmentSettingsStaleStoreProvider)
          .isStale(harness.key),
      isTrue,
    );
  });

  test(
    'reconciliation 401 clears state and invokes global bootstrap once',
    () async {
      final auth = _FakeAuthSessionController(
        AuthSessionState.authenticated(_admin()),
      );
      final repository = _FakeSettingsRepository(
        onFetch: (call) async {
          if (call == 1) return _settings();
          throw ApiRequestException(
            _serverFailure(401, ApiErrorCodes.authenticationRequired),
          );
        },
        onUpdate: (_, _) async =>
            throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException(),
      );
      final harness = _harness(auth: auth, repository: repository);
      await _flush();
      _editScore(harness, '6');
      await harness.controller.submit();

      expect(repository.fetchCalls, 2);
      expect(repository.updateCalls, 1);
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.initial,
      );
      expect(harness.read().settings, isNull);
      expect(auth.bootstrapCalls, 1);
    },
  );

  test(
    'logout before a delayed 401 rejects stale feedback and bootstrap',
    () async {
      final completion = Completer<InstitutionAssessmentSettings>();
      final auth = _FakeAuthSessionController(
        AuthSessionState.authenticated(_admin()),
      );
      final repository = _FakeSettingsRepository(
        onUpdate: (_, _) => completion.future,
      );
      final harness = _harness(auth: auth, repository: repository);
      await _flush();
      _editScore(harness, '6');
      final operation = harness.controller.submit();
      await _flush();

      auth.setSession(const AuthSessionState.unauthenticated());
      await _flush();
      completion.completeError(
        ApiRequestException(
          _serverFailure(401, ApiErrorCodes.authenticationRequired),
        ),
      );
      await operation;

      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.initial,
      );
      expect(harness.read().settings, isNull);
      expect(harness.read().notice, isNull);
      expect(auth.bootstrapCalls, 0);
    },
  );

  test(
    'logout during reconciliation rejects the stale current-state response',
    () async {
      final reconciliation = Completer<InstitutionAssessmentSettings>();
      final auth = _FakeAuthSessionController(
        AuthSessionState.authenticated(_admin()),
      );
      final repository = _FakeSettingsRepository(
        onFetch: (call) =>
            call == 1 ? Future.value(_settings()) : reconciliation.future,
        onUpdate: (_, _) async =>
            throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException(),
      );
      final harness = _harness(auth: auth, repository: repository);
      await _flush();
      _editScore(harness, '6');
      final operation = harness.controller.submit();
      await _flush();
      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.reconcilingCurrentState,
      );

      auth.setSession(const AuthSessionState.unauthenticated());
      await _flush();
      reconciliation.complete(_settings(score: '6'));
      await operation;

      expect(
        harness.read().status,
        InstitutionAssessmentSettingsStatus.initial,
      );
      expect(harness.read().settings, isNull);
      expect(harness.read().notice, isNull);
      expect(repository.updateCalls, 1);
      expect(repository.fetchCalls, 2);
    },
  );

  test(
    'account Institution role lifecycle and bootstrap switches reject stale GET',
    () async {
      final replacements = <AuthSessionState>[
        AuthSessionState.authenticated(_admin(id: 'admin-b')),
        AuthSessionState.authenticated(_admin(institutionId: 'institution-b')),
        AuthSessionState.authenticated(_admin(role: UserRole.teacher)),
        AuthSessionState.authenticated(_admin(isActive: false)),
        AuthSessionState.authenticated(_admin(mustChangePassword: true)),
        AuthSessionState.authenticated(_admin(institutionStatus: 'inactive')),
        const AuthSessionState.bootstrapping(),
        const AuthSessionState.unauthenticated(),
      ];
      for (final replacement in replacements) {
        final completion = Completer<InstitutionAssessmentSettings>();
        final auth = _FakeAuthSessionController(
          AuthSessionState.authenticated(_admin()),
        );
        final repository = _FakeSettingsRepository(
          onFetch: (_) => completion.future,
        );
        final harness = _harness(auth: auth, repository: repository);
        await _flush();
        auth.setSession(replacement);
        await _flush();
        completion.complete(_settings(score: '99'));
        await _flush();

        expect(
          harness.read().status,
          InstitutionAssessmentSettingsStatus.initial,
        );
        expect(harness.read().settings, isNull);
      }
    },
  );

  test(
    'provider disposal rejects completion and preserves same-session stale marker',
    () async {
      final completion = Completer<InstitutionAssessmentSettings>();
      final repository = _FakeSettingsRepository(
        onUpdate: (_, _) => completion.future,
      );
      final harness = _harness(repository: repository);
      await _flush();
      _editScore(harness, '6');
      final operation = harness.controller.submit();
      await _flush();
      expect(
        harness.container
            .read(institutionAssessmentSettingsStaleStoreProvider)
            .isStale(harness.key),
        isTrue,
      );

      harness.subscription.close();
      await _flush();
      completion.complete(_settings(score: '6'));
      await operation;
      expect(
        harness.container
            .read(institutionAssessmentSettingsStaleStoreProvider)
            .isStale(harness.key),
        isTrue,
      );
    },
  );
}

const _institutionId = '550e8400-e29b-41d4-a716-446655440000';
const _route = '/institution-admin/settings';

_Harness _harness({
  _FakeAuthSessionController? auth,
  _FakeSettingsRepository? repository,
}) {
  final resolvedAuth =
      auth ??
      _FakeAuthSessionController(AuthSessionState.authenticated(_admin()));
  final resolvedRepository = repository ?? _FakeSettingsRepository();
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => resolvedAuth),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionAssessmentSettingsRepositoryProvider.overrideWithValue(
        resolvedRepository,
      ),
    ],
  );
  addTearDown(container.dispose);
  final session = container.read(authSessionControllerProvider);
  final key = InstitutionAssessmentSettingsSessionSnapshot.from(
    session: session,
    surface: AppDeviceSurface.desktop,
  ).eligibleKeyFor(_route)!;
  final provider = institutionAssessmentSettingsControllerProvider(key);
  final subscription = container.listen(
    provider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return _Harness(
    container,
    provider,
    subscription,
    key,
    resolvedAuth,
    resolvedRepository,
  );
}

class _Harness {
  const _Harness(
    this.container,
    this.provider,
    this.subscription,
    this.key,
    this.auth,
    this.repository,
  );
  final ProviderContainer container;
  final NotifierProvider<
    InstitutionAssessmentSettingsController,
    InstitutionAssessmentSettingsState
  >
  provider;
  final ProviderSubscription<InstitutionAssessmentSettingsState> subscription;
  final InstitutionAssessmentSettingsSessionKey key;
  final _FakeAuthSessionController auth;
  final _FakeSettingsRepository repository;
  InstitutionAssessmentSettingsState read() => subscription.read();
  InstitutionAssessmentSettingsController get controller =>
      container.read(provider.notifier);
}

class _FakeSettingsRepository
    implements InstitutionAssessmentSettingsRepository {
  _FakeSettingsRepository({this.onFetch, this.onUpdate});
  final Future<InstitutionAssessmentSettings> Function(int call)? onFetch;
  final Future<InstitutionAssessmentSettings> Function(
    int call,
    InstitutionAssessmentSettingsUpdateRequest request,
  )?
  onUpdate;
  var fetchCalls = 0;
  var updateCalls = 0;

  @override
  Future<InstitutionAssessmentSettings> fetchSettings() {
    fetchCalls += 1;
    return onFetch?.call(fetchCalls) ?? Future.value(_settings());
  }

  @override
  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) {
    updateCalls += 1;
    return onUpdate?.call(updateCalls, request) ?? Future.value(_settings());
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.initialState);
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
  String id = 'admin-a',
  String? institutionId = _institutionId,
  UserRole role = UserRole.institutionAdmin,
  bool isActive = true,
  bool mustChangePassword = false,
  String institutionStatus = 'active',
}) => AuthUser(
  id: id,
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

InstitutionAssessmentSettings _settings({String score = '5'}) =>
    InstitutionAssessmentSettings(
      educationalPolicyConfigured: true,
      acceptableScoreDifference: ExactAssessmentDecimal.parseUserInput(score),
      blitzTimerStartMode: BlitzTimerStartMode.synchronized,
      studentResultReleaseMode: StudentResultReleaseMode.automatic,
      parentResultReleaseMode: ParentResultReleaseMode.withStudent,
      timezone: 'Asia/Tashkent',
      learningMaterialMaxMb: 25,
      studentSubmissionMaxMb: 15,
      platformLearningMaterialMaxMb: 25,
      platformStudentSubmissionMaxMb: 15,
      homeworkNormalAttempts: 3,
      blitzNormalAttempts: 1,
      blitzMaxAdditionalExceptionAttempts: 1,
    );

InstitutionAssessmentSettings _partiallyConfiguredSettings() =>
    InstitutionAssessmentSettings(
      educationalPolicyConfigured: false,
      acceptableScoreDifference: ExactAssessmentDecimal.parseUserInput('7.5'),
      blitzTimerStartMode: BlitzTimerStartMode.individual,
      studentResultReleaseMode: null,
      parentResultReleaseMode: ParentResultReleaseMode.hidden,
      timezone: 'Europe/London',
      learningMaterialMaxMb: 20,
      studentSubmissionMaxMb: 10,
      platformLearningMaterialMaxMb: 25,
      platformStudentSubmissionMaxMb: 15,
      homeworkNormalAttempts: 3,
      blitzNormalAttempts: 1,
      blitzMaxAdditionalExceptionAttempts: 1,
    );

InstitutionAssessmentSettings _unconfiguredSettings() =>
    const InstitutionAssessmentSettings(
      educationalPolicyConfigured: false,
      acceptableScoreDifference: null,
      blitzTimerStartMode: null,
      studentResultReleaseMode: null,
      parentResultReleaseMode: null,
      timezone: 'Asia/Tashkent',
      learningMaterialMaxMb: 25,
      studentSubmissionMaxMb: 15,
      platformLearningMaterialMaxMb: 25,
      platformStudentSubmissionMaxMb: 15,
      homeworkNormalAttempts: 3,
      blitzNormalAttempts: 1,
      blitzMaxAdditionalExceptionAttempts: 1,
    );

ApiFailure _serverFailure(
  int status,
  String code, {
  Map<String, List<String>> fields = const {},
}) => ApiFailure.fromServerError(
  statusCode: status,
  error: ApiErrorResponse(
    message: 'Private server detail',
    code: code,
    fieldErrors: fields,
    requestId: 'private-request-id',
  ),
);

void _editScore(_Harness harness, String value) {
  harness.controller.beginEditing();
  harness.controller.updateField(
    InstitutionAssessmentSettingsField.acceptableScoreDifference,
    value,
  );
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
