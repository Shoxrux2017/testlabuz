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
import '../data/institution_understanding_categories_repository_impl.dart';
import '../domain/institution_understanding_categories.dart';
import '../domain/institution_understanding_categories_repository.dart';
import 'institution_understanding_categories_state.dart';

const _matchingReconciliationNotice =
    'Current server categories match your submitted ranges, but this request result could not be confirmed.';
const _differentReconciliationNotice =
    'Current server categories differ from your submitted ranges. This request result could not be confirmed.';
const _unconfiguredReconciliationNotice =
    'Current server categories are not configured. This request result could not be confirmed.';

final institutionUnderstandingCategoriesStaleStoreProvider =
    Provider<InstitutionUnderstandingCategoriesStaleStore>((ref) {
      final store = InstitutionUnderstandingCategoriesStaleStore();
      ref.listen(authSessionControllerProvider, (previous, next) {
        if (!identical(previous?.user, next.user)) store.clearAll();
      });
      return store;
    });

final institutionUnderstandingCategoriesControllerProvider = NotifierProvider
    .autoDispose
    .family<
      InstitutionUnderstandingCategoriesController,
      InstitutionUnderstandingCategoriesState,
      InstitutionUnderstandingCategoriesSessionKey
    >(InstitutionUnderstandingCategoriesController.new);

class InstitutionUnderstandingCategoriesController
    extends Notifier<InstitutionUnderstandingCategoriesState> {
  InstitutionUnderstandingCategoriesController(this._providerKey);

  final InstitutionUnderstandingCategoriesSessionKey _providerKey;
  var _active = false;
  var _disposed = false;
  var _operationGeneration = 0;
  int? _inFlightGeneration;

  @override
  InstitutionUnderstandingCategoriesState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _invalidateOperations();
    });

    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final eligible = InstitutionUnderstandingCategoriesSessionSnapshot.from(
      session: session,
      surface: surface,
    ).eligibleKeyFor(_providerKey.routePath);
    if (eligible != _providerKey) {
      _active = false;
      _invalidateOperations();
      return const InstitutionUnderstandingCategoriesState.initial();
    }
    if (_active) return state;
    _active = true;
    ref
        .read(institutionUnderstandingCategoriesStaleStoreProvider)
        .clearUnlessMatches(_providerKey);
    scheduleMicrotask(() => unawaited(_load(_CategoryLoadPurpose.initial)));
    return const InstitutionUnderstandingCategoriesState.loading();
  }

  Future<void> retry() async {
    if (state.status != InstitutionUnderstandingCategoriesStatus.loadError ||
        _inFlightGeneration != null) {
      return;
    }
    state = const InstitutionUnderstandingCategoriesState.loading();
    await _load(_CategoryLoadPurpose.retry);
  }

  Future<void> reloadUnconfirmedCurrentState() async {
    if (state.status !=
            InstitutionUnderstandingCategoriesStatus
                .unconfirmedWithoutCurrentState ||
        _inFlightGeneration != null) {
      return;
    }
    state = const InstitutionUnderstandingCategoriesState.loading();
    await _load(_CategoryLoadPurpose.retry);
  }

  Future<bool> refresh({bool discardDirty = false}) async {
    final configuration = state.configuration;
    if (_inFlightGeneration != null || configuration == null) return false;
    if (state.isDirty && !discardDirty) return false;
    if (!_canRefreshStatus(state.status)) return false;
    state = InstitutionUnderstandingCategoriesState.refreshing(configuration);
    await _load(_CategoryLoadPurpose.refresh, previous: configuration);
    return true;
  }

  void beginEditing() {
    final configuration = state.configuration;
    if (configuration == null ||
        _inFlightGeneration != null ||
        !_isConfirmedDisplayState(state.status)) {
      return;
    }
    state = InstitutionUnderstandingCategoriesState.editing(
      configuration: configuration,
      draft: InstitutionUnderstandingCategoryDraft.fromConfiguration(
        configuration,
      ),
      dirty: false,
    );
  }

  void cancelEditing() {
    final configuration = state.configuration;
    if (!state.isEditing ||
        _inFlightGeneration != null ||
        configuration == null) {
      return;
    }
    state = InstitutionUnderstandingCategoriesState.data(configuration);
  }

  void resetDraft() {
    final configuration = state.configuration;
    if (!state.isEditing ||
        _inFlightGeneration != null ||
        configuration == null) {
      return;
    }
    state = InstitutionUnderstandingCategoriesState.editing(
      configuration: configuration,
      draft: InstitutionUnderstandingCategoryDraft.fromConfiguration(
        configuration,
      ),
      dirty: false,
    );
  }

  void updateField(InstitutionUnderstandingCategoryField field, String value) {
    final configuration = state.configuration;
    final draft = state.draft;
    if (!state.isEditing ||
        _inFlightGeneration != null ||
        configuration == null ||
        draft == null) {
      return;
    }
    final updated = draft.withField(field, value);
    state = InstitutionUnderstandingCategoriesState.editing(
      configuration: configuration,
      draft: updated,
      dirty: !_draftMatchesConfiguration(updated, configuration),
    );
  }

  Future<void> submit() async {
    final configuration = state.configuration;
    final draft = state.draft;
    if (!state.isEditing ||
        _inFlightGeneration != null ||
        configuration == null ||
        draft == null) {
      return;
    }
    final validation = draft.validate();
    if (!validation.isValid) {
      state = InstitutionUnderstandingCategoriesState.validationFailure(
        configuration: configuration,
        draft: draft,
        fieldErrors: validation.fieldErrors,
        setError: validation.setError,
        focusField: validation.firstInvalidField,
      );
      return;
    }

    final request = validation.request!;
    if (configuration.matches(request)) {
      state = InstitutionUnderstandingCategoriesState.data(
        configuration,
        notice: 'No changes to save.',
      );
      return;
    }

    ref
        .read(institutionUnderstandingCategoriesStaleStoreProvider)
        .markStale(_providerKey);
    state = InstitutionUnderstandingCategoriesState.submitting(
      configuration: configuration,
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
          .read(institutionUnderstandingCategoriesRepositoryProvider)
          .replaceCategories(request);
      if (!_canComplete(generation, identity)) return;
      if (!request.matches(updated)) {
        await _reconcile(
          generation: generation,
          identity: identity,
          request: request,
          previous: configuration,
          draft: draft,
        );
        return;
      }
      ref
          .read(institutionUnderstandingCategoriesStaleStoreProvider)
          .clear(_providerKey);
      state = InstitutionUnderstandingCategoriesState.confirmedDirectSuccess(
        updated,
      );
    } on InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException {
      if (_canComplete(generation, identity)) {
        await _reconcile(
          generation: generation,
          identity: identity,
          request: request,
          previous: configuration,
          draft: draft,
        );
      }
    } on ApiRequestException catch (exception) {
      if (_canComplete(generation, identity)) {
        _handleDefiniteMutationFailure(
          exception.failure,
          configuration: configuration,
          draft: draft,
        );
      }
    } catch (_) {
      if (_canComplete(generation, identity)) {
        await _reconcile(
          generation: generation,
          identity: identity,
          request: request,
          previous: configuration,
          draft: draft,
        );
      }
    } finally {
      if (_inFlightGeneration == generation) _inFlightGeneration = null;
    }
  }

  Future<void> _load(
    _CategoryLoadPurpose purpose, {
    InstitutionUnderstandingCategoryConfiguration? previous,
  }) async {
    if (_inFlightGeneration != null) return;
    final generation = _beginOperation();
    final identity = _currentIdentity();
    if (identity == null) {
      _invalidateOperations();
      return;
    }
    try {
      final configuration = await ref
          .read(institutionUnderstandingCategoriesRepositoryProvider)
          .fetchCategories();
      if (!_canComplete(generation, identity)) return;
      ref
          .read(institutionUnderstandingCategoriesStaleStoreProvider)
          .clear(_providerKey);
      state = InstitutionUnderstandingCategoriesState.data(configuration);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, identity)) return;
      if (_clearForSessionFailure(exception.failure)) return;
      state = purpose == _CategoryLoadPurpose.refresh && previous != null
          ? InstitutionUnderstandingCategoriesState.data(
              previous,
              notice:
                  'Understanding categories could not be refreshed. The last confirmed values are still shown.',
            )
          : InstitutionUnderstandingCategoriesState.loadError(
              exception.failure,
            );
    } catch (_) {
      if (!_canComplete(generation, identity)) return;
      final failure = ApiFailure.local(
        kind: ApiFailureKind.unknown,
        message: 'Unexpected understanding categories failure.',
      );
      state = purpose == _CategoryLoadPurpose.refresh && previous != null
          ? InstitutionUnderstandingCategoriesState.data(
              previous,
              notice:
                  'Understanding categories could not be refreshed. The last confirmed values are still shown.',
            )
          : InstitutionUnderstandingCategoriesState.loadError(failure);
    } finally {
      if (_inFlightGeneration == generation) _inFlightGeneration = null;
    }
  }

  Future<void> _reconcile({
    required int generation,
    required InstitutionUnderstandingCategoriesOperationIdentity identity,
    required InstitutionUnderstandingCategoryUpdateRequest request,
    required InstitutionUnderstandingCategoryConfiguration previous,
    required InstitutionUnderstandingCategoryDraft draft,
  }) async {
    if (!_canComplete(generation, identity)) return;
    state = InstitutionUnderstandingCategoriesState.reconciling(
      configuration: previous,
      draft: draft,
    );
    try {
      final current = await ref
          .read(institutionUnderstandingCategoriesRepositoryProvider)
          .fetchCategories();
      if (!_canComplete(generation, identity)) return;
      ref
          .read(institutionUnderstandingCategoriesStaleStoreProvider)
          .clear(_providerKey);
      final notice = !current.configured
          ? _unconfiguredReconciliationNotice
          : request.matches(current)
          ? _matchingReconciliationNotice
          : _differentReconciliationNotice;
      state = InstitutionUnderstandingCategoriesState.unconfirmedCurrentState(
        current,
        notice: notice,
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, identity)) return;
      if (_clearForSessionFailure(exception.failure)) return;
      state =
          const InstitutionUnderstandingCategoriesState.unconfirmedWithoutCurrentState();
    } catch (_) {
      if (_canComplete(generation, identity)) {
        state =
            const InstitutionUnderstandingCategoriesState.unconfirmedWithoutCurrentState();
      }
    }
  }

  void _handleDefiniteMutationFailure(
    ApiFailure failure, {
    required InstitutionUnderstandingCategoryConfiguration configuration,
    required InstitutionUnderstandingCategoryDraft draft,
  }) {
    ref
        .read(institutionUnderstandingCategoriesStaleStoreProvider)
        .clear(_providerKey);
    if (_clearForSessionFailure(failure)) return;

    if (failure.kind == ApiFailureKind.validation ||
        failure.serverCode == ApiErrorCodes.validationFailed) {
      final errors = <InstitutionUnderstandingCategoryField, String>{};
      String? setError;
      var formProtocolError = false;
      for (final entry in failure.fieldErrors.entries) {
        if (entry.key == 'categories' && entry.value.isNotEmpty) {
          setError = 'The server rejected the complete category partition.';
          continue;
        }
        final field = InstitutionUnderstandingCategoryField.fromApiPath(
          entry.key,
        );
        if (field == null || entry.value.isEmpty) {
          formProtocolError = true;
        } else {
          errors[field] = 'The server rejected this range value.';
        }
      }
      state = InstitutionUnderstandingCategoriesState.validationFailure(
        configuration: configuration,
        draft: draft,
        fieldErrors: errors,
        setError: setError,
        formError: formProtocolError || (errors.isEmpty && setError == null)
            ? 'The server could not validate this category request safely.'
            : null,
        focusField: _firstField(errors),
      );
      return;
    }

    final message = failure.serverCode == ApiErrorCodes.rateLimited
        ? 'Too many category requests were made. Wait before submitting a new explicit request.'
        : failure.serverCode == ApiErrorCodes.forbidden
        ? 'You do not have permission to change understanding categories.'
        : 'The understanding categories request was rejected.';
    state = InstitutionUnderstandingCategoriesState.definiteFailure(
      configuration: configuration,
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
      state = const InstitutionUnderstandingCategoriesState.initial();
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
    InstitutionUnderstandingCategoriesOperationIdentity identity,
  ) =>
      !_disposed &&
      _active &&
      generation == _operationGeneration &&
      generation == _inFlightGeneration &&
      _currentIdentity() == identity;

  InstitutionUnderstandingCategoriesOperationIdentity? _currentIdentity() {
    if (_disposed || !_active) return null;
    final key = InstitutionUnderstandingCategoriesSessionSnapshot.from(
      session: ref.read(authSessionControllerProvider),
      surface: ref.read(appDeviceSurfaceProvider),
    ).eligibleKeyFor(_providerKey.routePath);
    if (key != _providerKey) return null;
    return InstitutionUnderstandingCategoriesOperationIdentity(
      sessionKey: key!,
      operationGeneration: _operationGeneration,
    );
  }
}

class InstitutionUnderstandingCategoriesSessionSnapshot {
  const InstitutionUnderstandingCategoriesSessionSnapshot({
    required this.status,
    required this.sessionInstance,
    required this.user,
    required this.surface,
  });

  factory InstitutionUnderstandingCategoriesSessionSnapshot.from({
    required AuthSessionState session,
    required AppDeviceSurface surface,
  }) => InstitutionUnderstandingCategoriesSessionSnapshot(
    status: session.status,
    sessionInstance: session,
    user: session.user,
    surface: surface,
  );

  final AuthSessionStatus status;
  final AuthSessionState sessionInstance;
  final AuthUser? user;
  final AppDeviceSurface surface;

  InstitutionUnderstandingCategoriesSessionKey? eligibleKeyFor(
    String routePath,
  ) {
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
    return InstitutionUnderstandingCategoriesSessionKey(
      userId: currentUser.id,
      userInstance: currentUser,
      institutionId: institutionId,
      sessionGeneration: identityHashCode(sessionInstance),
      routePath: routePath,
    );
  }
}

class InstitutionUnderstandingCategoriesSessionKey {
  const InstitutionUnderstandingCategoriesSessionKey({
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
      other is InstitutionUnderstandingCategoriesSessionKey &&
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

class InstitutionUnderstandingCategoriesOperationIdentity {
  const InstitutionUnderstandingCategoriesOperationIdentity({
    required this.sessionKey,
    required this.operationGeneration,
  });

  final InstitutionUnderstandingCategoriesSessionKey sessionKey;
  final int operationGeneration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionUnderstandingCategoriesOperationIdentity &&
          other.sessionKey == sessionKey &&
          other.operationGeneration == operationGeneration;

  @override
  int get hashCode => Object.hash(sessionKey, operationGeneration);
}

class InstitutionUnderstandingCategoriesStaleStore {
  InstitutionUnderstandingCategoriesSessionKey? _staleKey;

  bool isStale(InstitutionUnderstandingCategoriesSessionKey key) =>
      _staleKey == key;

  void markStale(InstitutionUnderstandingCategoriesSessionKey key) {
    _staleKey = key;
  }

  void clear(InstitutionUnderstandingCategoriesSessionKey key) {
    if (_staleKey == key) _staleKey = null;
  }

  void clearUnlessMatches(InstitutionUnderstandingCategoriesSessionKey key) {
    if (_staleKey != key) _staleKey = null;
  }

  void clearAll() {
    _staleKey = null;
  }
}

enum _CategoryLoadPurpose { initial, retry, refresh }

bool _canRefreshStatus(InstitutionUnderstandingCategoriesStatus status) =>
    _isConfirmedDisplayState(status) ||
    status == InstitutionUnderstandingCategoriesStatus.editingClean ||
    status == InstitutionUnderstandingCategoriesStatus.editingDirty ||
    status == InstitutionUnderstandingCategoriesStatus.validationFailure ||
    status == InstitutionUnderstandingCategoriesStatus.definiteFailure;

bool _isConfirmedDisplayState(
  InstitutionUnderstandingCategoriesStatus status,
) =>
    status == InstitutionUnderstandingCategoriesStatus.configuredConfirmed ||
    status == InstitutionUnderstandingCategoriesStatus.unconfiguredConfirmed ||
    status == InstitutionUnderstandingCategoriesStatus.confirmedDirectSuccess ||
    status == InstitutionUnderstandingCategoriesStatus.unconfirmedCurrentState;

bool _draftMatchesConfiguration(
  InstitutionUnderstandingCategoryDraft draft,
  InstitutionUnderstandingCategoryConfiguration configuration,
) => draft.validate().request?.matches(configuration) == true;

InstitutionUnderstandingCategoryField? _firstField(
  Map<InstitutionUnderstandingCategoryField, String> errors,
) {
  for (final field in InstitutionUnderstandingCategoryField.values) {
    if (errors.containsKey(field)) return field;
  }
  return null;
}
