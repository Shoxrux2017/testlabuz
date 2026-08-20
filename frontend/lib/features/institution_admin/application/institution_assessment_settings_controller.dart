import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/user_role.dart';
import '../data/institution_assessment_settings_repository_impl.dart';
import '../domain/institution_assessment_settings.dart';
import '../domain/institution_assessment_settings_repository.dart';
import 'institution_assessment_settings_state.dart';

const _matchingReconciliationNotice =
    'Current server settings match your submitted values, but this request result could not be confirmed.';
const _differentReconciliationNotice =
    'Current server settings differ from your submitted values. This request result could not be confirmed.';

final institutionAssessmentSettingsStaleStoreProvider =
    Provider<InstitutionAssessmentSettingsStaleStore>((ref) {
      final store = InstitutionAssessmentSettingsStaleStore();
      ref.listen(authSessionControllerProvider, (previous, next) {
        if (!identical(previous?.user, next.user)) {
          store.clearAll();
        }
      });
      return store;
    });

final institutionAssessmentSettingsControllerProvider = NotifierProvider
    .autoDispose
    .family<
      InstitutionAssessmentSettingsController,
      InstitutionAssessmentSettingsState,
      InstitutionAssessmentSettingsSessionKey
    >(InstitutionAssessmentSettingsController.new);

class InstitutionAssessmentSettingsController
    extends Notifier<InstitutionAssessmentSettingsState> {
  InstitutionAssessmentSettingsController(this._providerKey);

  final InstitutionAssessmentSettingsSessionKey _providerKey;
  var _active = false;
  var _disposed = false;
  var _operationGeneration = 0;
  int? _inFlightGeneration;

  @override
  InstitutionAssessmentSettingsState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _invalidateOperations();
    });

    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final eligible = InstitutionAssessmentSettingsSessionSnapshot.from(
      session: session,
      surface: surface,
    ).eligibleKeyFor(_providerKey.routePath);
    if (eligible != _providerKey) {
      _active = false;
      _invalidateOperations();
      return const InstitutionAssessmentSettingsState.initial();
    }

    if (_active) {
      return state;
    }
    _active = true;
    ref
        .read(institutionAssessmentSettingsStaleStoreProvider)
        .clearUnlessMatches(_providerKey);
    scheduleMicrotask(() => unawaited(_load(_LoadPurpose.initial)));
    return const InstitutionAssessmentSettingsState.loading();
  }

  Future<void> retry() async {
    if (state.status != InstitutionAssessmentSettingsStatus.loadError ||
        _inFlightGeneration != null) {
      return;
    }
    state = const InstitutionAssessmentSettingsState.loading();
    await _load(_LoadPurpose.retry);
  }

  Future<void> reloadUnconfirmedCurrentState() async {
    if (state.status !=
            InstitutionAssessmentSettingsStatus
                .unconfirmedWithoutCurrentState ||
        _inFlightGeneration != null) {
      return;
    }
    state = const InstitutionAssessmentSettingsState.loading();
    await _load(_LoadPurpose.retry);
  }

  Future<bool> refresh({bool discardDirty = false}) async {
    if (_inFlightGeneration != null || state.settings == null) {
      return false;
    }
    if (state.isDirty && !discardDirty) {
      return false;
    }
    if (!_canRefreshStatus(state.status)) {
      return false;
    }

    final current = state.settings!;
    state = InstitutionAssessmentSettingsState.refreshing(current);
    await _load(_LoadPurpose.refresh, previous: current);
    return true;
  }

  void beginEditing() {
    final settings = state.settings;
    if (settings == null ||
        _inFlightGeneration != null ||
        !_isConfirmedDisplayState(state.status)) {
      return;
    }
    state = InstitutionAssessmentSettingsState.editing(
      settings: settings,
      draft: InstitutionAssessmentSettingsDraft.fromSettings(settings),
      dirty: false,
    );
  }

  void cancelEditing() {
    if (!state.isEditing ||
        _inFlightGeneration != null ||
        state.settings == null) {
      return;
    }
    state = InstitutionAssessmentSettingsState.data(state.settings!);
  }

  void resetDraft() {
    if (!state.isEditing ||
        _inFlightGeneration != null ||
        state.settings == null) {
      return;
    }
    final settings = state.settings!;
    state = InstitutionAssessmentSettingsState.editing(
      settings: settings,
      draft: InstitutionAssessmentSettingsDraft.fromSettings(settings),
      dirty: false,
    );
  }

  void updateField(InstitutionAssessmentSettingsField field, Object? value) {
    final settings = state.settings;
    final draft = state.draft;
    if (!state.isEditing ||
        _inFlightGeneration != null ||
        settings == null ||
        draft == null) {
      return;
    }
    final updated = draft.withField(field, value);
    state = InstitutionAssessmentSettingsState.editing(
      settings: settings,
      draft: updated,
      dirty: !_draftMatchesSettings(updated, settings),
    );
  }

  Future<void> submit() async {
    final settings = state.settings;
    final draft = state.draft;
    if (!state.isEditing ||
        _inFlightGeneration != null ||
        settings == null ||
        draft == null) {
      return;
    }
    final validation = draft.validate(
      platformLearningMaterialMaxMb: settings.platformLearningMaterialMaxMb,
      platformStudentSubmissionMaxMb: settings.platformStudentSubmissionMaxMb,
    );
    if (!validation.isValid) {
      state = InstitutionAssessmentSettingsState.validationFailure(
        settings: settings,
        draft: draft,
        fieldErrors: validation.fieldErrors,
        focusField: validation.firstInvalidField,
      );
      return;
    }

    final request = validation.request!;
    if (request.matches(settings)) {
      state = InstitutionAssessmentSettingsState.data(
        settings,
        notice: 'No changes to save.',
      );
      return;
    }

    ref
        .read(institutionAssessmentSettingsStaleStoreProvider)
        .markStale(_providerKey);
    state = InstitutionAssessmentSettingsState.submitting(
      settings: settings,
      draft: draft,
    );
    final generation = _beginOperation();
    final identity = _currentIdentity();
    if (identity == null) {
      _invalidateOperations();
      return;
    }
    try {
      final updated = await ref
          .read(institutionAssessmentSettingsRepositoryProvider)
          .updateSettings(request);
      if (!_canComplete(generation, identity)) {
        return;
      }
      if (!updated.educationalPolicyConfigured || !request.matches(updated)) {
        await _reconcile(
          generation: generation,
          identity: identity,
          request: request,
          previous: settings,
          draft: draft,
        );
        return;
      }

      ref
          .read(institutionAssessmentSettingsStaleStoreProvider)
          .clear(_providerKey);
      state = InstitutionAssessmentSettingsState.confirmedDirectSuccess(
        updated,
      );
    } on InstitutionAssessmentSettingsUpdateOutcomeUnknownException {
      if (_canComplete(generation, identity)) {
        await _reconcile(
          generation: generation,
          identity: identity,
          request: request,
          previous: settings,
          draft: draft,
        );
      }
    } on ApiRequestException catch (exception) {
      if (_canComplete(generation, identity)) {
        _handleDefiniteMutationFailure(
          exception.failure,
          settings: settings,
          draft: draft,
        );
      }
    } catch (_) {
      if (_canComplete(generation, identity)) {
        await _reconcile(
          generation: generation,
          identity: identity,
          request: request,
          previous: settings,
          draft: draft,
        );
      }
    } finally {
      if (_inFlightGeneration == generation) {
        _inFlightGeneration = null;
      }
    }
  }

  Future<void> _load(
    _LoadPurpose purpose, {
    InstitutionAssessmentSettings? previous,
  }) async {
    if (_inFlightGeneration != null) {
      return;
    }
    final generation = _beginOperation();
    final identity = _currentIdentity();
    if (identity == null) {
      _invalidateOperations();
      return;
    }
    try {
      final settings = await ref
          .read(institutionAssessmentSettingsRepositoryProvider)
          .fetchSettings();
      if (!_canComplete(generation, identity)) {
        return;
      }
      ref
          .read(institutionAssessmentSettingsStaleStoreProvider)
          .clear(_providerKey);
      state = InstitutionAssessmentSettingsState.data(settings);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, identity)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state = purpose == _LoadPurpose.refresh && previous != null
          ? InstitutionAssessmentSettingsState.data(
              previous,
              notice:
                  'Assessment settings could not be refreshed. The last confirmed values are still shown.',
            )
          : InstitutionAssessmentSettingsState.loadError(exception.failure);
    } catch (_) {
      if (!_canComplete(generation, identity)) {
        return;
      }
      final failure = ApiFailure.local(
        kind: ApiFailureKind.unknown,
        message: 'Unexpected assessment settings failure.',
      );
      state = purpose == _LoadPurpose.refresh && previous != null
          ? InstitutionAssessmentSettingsState.data(
              previous,
              notice:
                  'Assessment settings could not be refreshed. The last confirmed values are still shown.',
            )
          : InstitutionAssessmentSettingsState.loadError(failure);
    } finally {
      if (_inFlightGeneration == generation) {
        _inFlightGeneration = null;
      }
    }
  }

  Future<void> _reconcile({
    required int generation,
    required InstitutionAssessmentSettingsOperationIdentity identity,
    required InstitutionAssessmentSettingsUpdateRequest request,
    required InstitutionAssessmentSettings previous,
    required InstitutionAssessmentSettingsDraft draft,
  }) async {
    if (!_canComplete(generation, identity)) {
      return;
    }
    state = InstitutionAssessmentSettingsState.reconciling(
      settings: previous,
      draft: draft,
    );
    try {
      final current = await ref
          .read(institutionAssessmentSettingsRepositoryProvider)
          .fetchSettings();
      if (!_canComplete(generation, identity)) {
        return;
      }
      ref
          .read(institutionAssessmentSettingsStaleStoreProvider)
          .clear(_providerKey);
      state = InstitutionAssessmentSettingsState.unconfirmedCurrentState(
        current,
        notice: request.matches(current)
            ? _matchingReconciliationNotice
            : _differentReconciliationNotice,
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, identity)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state =
          const InstitutionAssessmentSettingsState.unconfirmedWithoutCurrentState();
    } catch (_) {
      if (_canComplete(generation, identity)) {
        state =
            const InstitutionAssessmentSettingsState.unconfirmedWithoutCurrentState();
      }
    }
  }

  void _handleDefiniteMutationFailure(
    ApiFailure failure, {
    required InstitutionAssessmentSettings settings,
    required InstitutionAssessmentSettingsDraft draft,
  }) {
    ref
        .read(institutionAssessmentSettingsStaleStoreProvider)
        .clear(_providerKey);
    if (_clearForSessionFailure(failure)) {
      return;
    }

    if (failure.kind == ApiFailureKind.validation ||
        failure.serverCode == ApiErrorCodes.validationFailed) {
      final errors = <InstitutionAssessmentSettingsField, String>{};
      var formProtocolError = false;
      for (final entry in failure.fieldErrors.entries) {
        final field = InstitutionAssessmentSettingsField.fromApiKey(entry.key);
        if (field == null || entry.value.isEmpty) {
          formProtocolError = true;
        } else {
          errors[field] = 'The server rejected this value.';
        }
      }
      state = InstitutionAssessmentSettingsState.validationFailure(
        settings: settings,
        draft: draft,
        fieldErrors: errors,
        formError: formProtocolError || errors.isEmpty
            ? 'The server could not validate this settings request safely.'
            : null,
        focusField: _firstField(errors),
      );
      return;
    }

    final message = failure.serverCode == ApiErrorCodes.rateLimited
        ? 'Too many settings requests were made. Wait before submitting a new explicit request.'
        : failure.serverCode == ApiErrorCodes.forbidden
        ? 'You do not have permission to change assessment settings.'
        : 'The assessment settings request was rejected.';
    state = InstitutionAssessmentSettingsState.definiteFailure(
      settings: settings,
      draft: draft,
      formError: message,
    );
  }

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive ||
        code == ApiErrorCodes.passwordChangeRequired) {
      _invalidateOperations();
      state = const InstitutionAssessmentSettingsState.initial();
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
      return true;
    }
    return false;
  }

  int _beginOperation() {
    final generation = ++_operationGeneration;
    _inFlightGeneration = generation;
    return generation;
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightGeneration = null;
  }

  bool _canComplete(
    int generation,
    InstitutionAssessmentSettingsOperationIdentity identity,
  ) =>
      !_disposed &&
      _active &&
      generation == _operationGeneration &&
      generation == _inFlightGeneration &&
      _currentIdentity() == identity;

  InstitutionAssessmentSettingsOperationIdentity? _currentIdentity() {
    if (_disposed || !_active) {
      return null;
    }
    final key = InstitutionAssessmentSettingsSessionSnapshot.from(
      session: ref.read(authSessionControllerProvider),
      surface: ref.read(appDeviceSurfaceProvider),
    ).eligibleKeyFor(_providerKey.routePath);
    if (key != _providerKey) {
      return null;
    }
    return InstitutionAssessmentSettingsOperationIdentity(
      sessionKey: key!,
      operationGeneration: _operationGeneration,
    );
  }
}

class InstitutionAssessmentSettingsSessionSnapshot {
  const InstitutionAssessmentSettingsSessionSnapshot({
    required this.status,
    required this.sessionInstance,
    required this.user,
    required this.surface,
  });

  factory InstitutionAssessmentSettingsSessionSnapshot.from({
    required AuthSessionState session,
    required AppDeviceSurface surface,
  }) => InstitutionAssessmentSettingsSessionSnapshot(
    status: session.status,
    sessionInstance: session,
    user: session.user,
    surface: surface,
  );

  final AuthSessionStatus status;
  final AuthSessionState sessionInstance;
  final AuthUser? user;
  final AppDeviceSurface surface;

  InstitutionAssessmentSettingsSessionKey? eligibleKeyFor(String routePath) {
    final currentUser = user;
    final institution = currentUser?.institution;
    final institutionId = currentUser?.institutionId;
    if (status != AuthSessionStatus.authenticated ||
        currentUser == null ||
        currentUser.id.isEmpty ||
        currentUser.role != UserRole.institutionAdmin ||
        !currentUser.isActive ||
        currentUser.mustChangePassword ||
        institutionId == null ||
        institutionId.trim().isEmpty ||
        institution == null ||
        institution.id != institutionId ||
        institution.status != 'active' ||
        surface != AppDeviceSurface.desktop ||
        routePath != '/institution-admin/settings') {
      return null;
    }
    return InstitutionAssessmentSettingsSessionKey(
      userId: currentUser.id,
      userInstance: currentUser,
      institutionId: institutionId,
      sessionGeneration: identityHashCode(sessionInstance),
      routePath: routePath,
    );
  }
}

class InstitutionAssessmentSettingsSessionKey {
  const InstitutionAssessmentSettingsSessionKey({
    required this.userId,
    required this.userInstance,
    required this.institutionId,
    required this.sessionGeneration,
    required this.routePath,
  });

  final String userId;
  final AuthUser userInstance;
  final String institutionId;
  final int sessionGeneration;
  final String routePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionAssessmentSettingsSessionKey &&
          other.userId == userId &&
          identical(other.userInstance, userInstance) &&
          other.institutionId == institutionId &&
          other.sessionGeneration == sessionGeneration &&
          other.routePath == routePath;

  @override
  int get hashCode => Object.hash(
    userId,
    identityHashCode(userInstance),
    institutionId,
    sessionGeneration,
    routePath,
  );
}

class InstitutionAssessmentSettingsOperationIdentity {
  const InstitutionAssessmentSettingsOperationIdentity({
    required this.sessionKey,
    required this.operationGeneration,
  });

  final InstitutionAssessmentSettingsSessionKey sessionKey;
  final int operationGeneration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionAssessmentSettingsOperationIdentity &&
          other.sessionKey == sessionKey &&
          other.operationGeneration == operationGeneration;

  @override
  int get hashCode => Object.hash(sessionKey, operationGeneration);
}

class InstitutionAssessmentSettingsStaleStore {
  InstitutionAssessmentSettingsSessionKey? _staleKey;

  bool isStale(InstitutionAssessmentSettingsSessionKey key) => _staleKey == key;

  void markStale(InstitutionAssessmentSettingsSessionKey key) {
    _staleKey = key;
  }

  void clear(InstitutionAssessmentSettingsSessionKey key) {
    if (_staleKey == key) {
      _staleKey = null;
    }
  }

  void clearUnlessMatches(InstitutionAssessmentSettingsSessionKey key) {
    if (_staleKey != key) {
      _staleKey = null;
    }
  }

  void clearAll() {
    _staleKey = null;
  }
}

enum _LoadPurpose { initial, retry, refresh }

bool _canRefreshStatus(InstitutionAssessmentSettingsStatus status) =>
    _isConfirmedDisplayState(status) ||
    status == InstitutionAssessmentSettingsStatus.editingClean ||
    status == InstitutionAssessmentSettingsStatus.editingDirty ||
    status == InstitutionAssessmentSettingsStatus.validationFailure ||
    status == InstitutionAssessmentSettingsStatus.definiteFailure;

bool _isConfirmedDisplayState(InstitutionAssessmentSettingsStatus status) =>
    status == InstitutionAssessmentSettingsStatus.confirmedData ||
    status == InstitutionAssessmentSettingsStatus.confirmedDirectSuccess ||
    status == InstitutionAssessmentSettingsStatus.unconfirmedCurrentState;

bool _draftMatchesSettings(
  InstitutionAssessmentSettingsDraft draft,
  InstitutionAssessmentSettings settings,
) {
  final validation = draft.validate(
    platformLearningMaterialMaxMb: settings.platformLearningMaterialMaxMb,
    platformStudentSubmissionMaxMb: settings.platformStudentSubmissionMaxMb,
  );
  return validation.request?.matches(settings) == true;
}

InstitutionAssessmentSettingsField? _firstField(
  Map<InstitutionAssessmentSettingsField, String> errors,
) {
  for (final field in InstitutionAssessmentSettingsField.values) {
    if (errors.containsKey(field)) {
      return field;
    }
  }
  return null;
}
