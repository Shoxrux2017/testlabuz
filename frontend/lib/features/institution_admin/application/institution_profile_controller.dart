import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/institution_profile_repository_impl.dart';
import '../domain/institution_profile.dart';
import '../domain/institution_profile_repository.dart';
import '../domain/institution_profile_update.dart';
import 'institution_profile_state.dart';

const _noChangesNotice = 'No changes to save.';
const _matchingReconciliationNotice =
    'Current server profile matches your submitted changes, but this request result could not be confirmed.';
const _differentReconciliationNotice =
    'Current server profile differs from your submitted changes. This request result could not be confirmed.';

final institutionProfileControllerProvider = NotifierProvider.autoDispose
    .family<
      InstitutionProfileController,
      InstitutionProfileState,
      InstitutionProfileSessionKey
    >(InstitutionProfileController.new);

class InstitutionProfileSessionKey {
  const InstitutionProfileSessionKey({
    required this.userId,
    required this.institutionId,
  });

  final String userId;
  final String institutionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionProfileSessionKey &&
            other.userId == userId &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode => Object.hash(userId, institutionId);
}

class InstitutionProfileController extends Notifier<InstitutionProfileState> {
  InstitutionProfileController(this._providerKey);

  final InstitutionProfileSessionKey _providerKey;
  var _isActive = false;
  var _isDisposed = false;
  int _operationGeneration = 0;
  int? _inFlightGeneration;

  @override
  InstitutionProfileState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _invalidateOperations();
    });

    final session = ref.watch(
      authSessionControllerProvider.select(
        InstitutionProfileSessionSnapshot.fromSession,
      ),
    );
    if (!session.isEligibleFor(_providerKey)) {
      _isActive = false;
      _invalidateOperations();

      return const InstitutionProfileState.initial();
    }

    if (_isActive) {
      return state;
    }

    _isActive = true;
    scheduleMicrotask(() {
      if (_currentIdentity() != null) {
        unawaited(_loadProfile(_LoadPurpose.initial));
      }
    });

    return const InstitutionProfileState.loading();
  }

  Future<void> refresh() async {
    if (!_isVerifiedViewState(state.status) || _inFlightGeneration != null) {
      return;
    }

    state = const InstitutionProfileState.loading();
    await _loadProfile(_LoadPurpose.refresh);
  }

  Future<void> retry() async {
    if (state.status != InstitutionProfileViewStatus.loadError ||
        state.isRetryInFlight ||
        _inFlightGeneration != null ||
        state.failure == null ||
        state.failureOperation == null) {
      return;
    }

    state = InstitutionProfileState.loadError(
      state.failure!,
      operation: state.failureOperation!,
      isRetryInFlight: true,
    );
    await _loadProfile(_LoadPurpose.retry);
  }

  Future<void> reloadAfterUnknownOutcome() async {
    if (state.status != InstitutionProfileViewStatus.outcomeUnknown ||
        state.isReloadInFlight ||
        _inFlightGeneration != null) {
      return;
    }

    state = const InstitutionProfileState.outcomeUnknown(
      isReloadInFlight: true,
    );
    await _loadProfile(_LoadPurpose.recovery);
  }

  void beginEditing() {
    if (!_isVerifiedViewState(state.status) ||
        _inFlightGeneration != null ||
        state.profile == null) {
      return;
    }

    final profile = state.profile!;
    state = InstitutionProfileState.editing(
      profile: profile,
      form: InstitutionProfileEditFormValue.fromProfile(profile),
      baseline: InstitutionProfileEditSnapshot.fromProfile(profile),
    );
  }

  void cancelEditing() {
    if (!_isEditableState(state.status) ||
        _inFlightGeneration != null ||
        state.profile == null) {
      return;
    }

    state = InstitutionProfileState.data(state.profile!);
  }

  void updateField(InstitutionProfileEditField field, String value) {
    if (!_isEditableState(state.status) ||
        _inFlightGeneration != null ||
        state.profile == null ||
        state.form == null ||
        state.baseline == null) {
      return;
    }

    final updatedForm = state.form!.withField(field, value);
    if (state.status == InstitutionProfileViewStatus.validationFailure) {
      final remainingErrors = Map<InstitutionProfileEditField, String>.from(
        state.fieldErrors,
      )..remove(field);
      if (remainingErrors.isNotEmpty || state.formError != null) {
        state = InstitutionProfileState.validationFailure(
          profile: state.profile!,
          form: updatedForm,
          baseline: state.baseline!,
          fieldErrors: remainingErrors,
          formError: state.formError,
        );
        return;
      }
    }

    state = InstitutionProfileState.editing(
      profile: state.profile!,
      form: updatedForm,
      baseline: state.baseline!,
    );
  }

  Future<void> submit() async {
    if (!_isEditableState(state.status) ||
        _inFlightGeneration != null ||
        state.profile == null ||
        state.form == null ||
        state.baseline == null) {
      return;
    }

    final identity = _currentIdentity();
    if (identity == null) {
      return;
    }

    final profile = state.profile!;
    final form = state.form!;
    final baseline = state.baseline!;
    final validation = form.validate();
    if (!validation.isValid) {
      state = InstitutionProfileState.validationFailure(
        profile: profile,
        form: form,
        baseline: baseline,
        fieldErrors: validation.fieldErrors,
        focusField: validation.firstInvalidField,
      );
      return;
    }

    final request = InstitutionProfileUpdateRequest.fromForm(
      form: form,
      baseline: baseline,
    );
    if (request.isEmpty) {
      state = InstitutionProfileState.data(profile, notice: _noChangesNotice);
      return;
    }

    state = InstitutionProfileState.submitting(
      profile: profile,
      form: form,
      baseline: baseline,
    );
    final generation = _beginOperation();

    try {
      final result = await ref
          .read(institutionProfileRepositoryProvider)
          .updateProfile(request);
      if (!_canComplete(generation, identity)) {
        return;
      }

      if (result.profile.id != identity.institutionId ||
          !request.matchesProfile(result.profile)) {
        await _reconcileUnknownUpdate(
          generation: generation,
          identity: identity,
          request: request,
          previousProfile: profile,
          form: form,
          baseline: baseline,
        );
        return;
      }

      if (!_acceptActiveProfile(result.profile, identity)) {
        return;
      }

      state = InstitutionProfileState.confirmedDirectSuccess(result.profile);
    } on InstitutionProfileUpdateOutcomeUnknownException {
      if (!_canComplete(generation, identity)) {
        return;
      }

      await _reconcileUnknownUpdate(
        generation: generation,
        identity: identity,
        request: request,
        previousProfile: profile,
        form: form,
        baseline: baseline,
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, identity)) {
        return;
      }

      if (_isDefiniteMutationFailure(exception.failure)) {
        _handleDefiniteMutationFailure(
          failure: exception.failure,
          profile: profile,
          form: form,
          baseline: baseline,
        );
      } else {
        await _reconcileUnknownUpdate(
          generation: generation,
          identity: identity,
          request: request,
          previousProfile: profile,
          form: form,
          baseline: baseline,
        );
      }
    } catch (_) {
      if (!_canComplete(generation, identity)) {
        return;
      }

      await _reconcileUnknownUpdate(
        generation: generation,
        identity: identity,
        request: request,
        previousProfile: profile,
        form: form,
        baseline: baseline,
      );
    } finally {
      if (_inFlightGeneration == generation) {
        _inFlightGeneration = null;
      }
    }
  }

  Future<void> _loadProfile(_LoadPurpose purpose) async {
    if (_inFlightGeneration != null) {
      return;
    }

    final identity = _currentIdentity();
    if (identity == null) {
      return;
    }

    final generation = _beginOperation();
    try {
      final profile = await ref
          .read(institutionProfileRepositoryProvider)
          .fetchProfile();
      if (!_canComplete(generation, identity)) {
        return;
      }

      if (profile.id != identity.institutionId) {
        _publishLoadFailure(
          purpose,
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'Institution profile identity mismatch.',
          ),
        );
        return;
      }

      if (!_acceptActiveProfile(profile, identity)) {
        return;
      }

      state = InstitutionProfileState.data(profile);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, identity)) {
        return;
      }

      if (_clearProtectedStateForSessionFailure(exception.failure)) {
        return;
      }

      _publishLoadFailure(purpose, exception.failure);
    } catch (_) {
      if (!_canComplete(generation, identity)) {
        return;
      }

      _publishLoadFailure(
        purpose,
        ApiFailure.local(
          kind: ApiFailureKind.unknown,
          message: 'Unexpected institution profile failure.',
        ),
      );
    } finally {
      if (_inFlightGeneration == generation) {
        _inFlightGeneration = null;
      }
    }
  }

  Future<void> _reconcileUnknownUpdate({
    required int generation,
    required _InstitutionProfileIdentity identity,
    required InstitutionProfileUpdateRequest request,
    required InstitutionProfile previousProfile,
    required InstitutionProfileEditFormValue form,
    required InstitutionProfileEditSnapshot baseline,
  }) async {
    if (!_canComplete(generation, identity)) {
      return;
    }

    state = InstitutionProfileState.reconciling(
      profile: previousProfile,
      form: form,
      baseline: baseline,
    );

    try {
      final currentProfile = await ref
          .read(institutionProfileRepositoryProvider)
          .fetchProfile();
      if (!_canComplete(generation, identity)) {
        return;
      }

      if (currentProfile.id != identity.institutionId) {
        state = const InstitutionProfileState.outcomeUnknown();
        return;
      }

      if (!_acceptActiveProfile(currentProfile, identity)) {
        return;
      }

      state = InstitutionProfileState.unconfirmedCurrentState(
        currentProfile,
        notice: request.matchesProfile(currentProfile)
            ? _matchingReconciliationNotice
            : _differentReconciliationNotice,
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, identity)) {
        return;
      }

      if (_clearProtectedStateForSessionFailure(exception.failure)) {
        return;
      }

      state = const InstitutionProfileState.outcomeUnknown();
    } catch (_) {
      if (_canComplete(generation, identity)) {
        state = const InstitutionProfileState.outcomeUnknown();
      }
    }
  }

  void _handleDefiniteMutationFailure({
    required ApiFailure failure,
    required InstitutionProfile profile,
    required InstitutionProfileEditFormValue form,
    required InstitutionProfileEditSnapshot baseline,
  }) {
    if (_clearProtectedStateForSessionFailure(failure)) {
      return;
    }

    if (failure.serverCode == ApiErrorCodes.forbidden ||
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      state = InstitutionProfileState.loadError(
        failure,
        operation: InstitutionProfileFailureOperation.mutation,
      );
      return;
    }

    if (failure.kind == ApiFailureKind.validation ||
        failure.serverCode == ApiErrorCodes.validationFailed) {
      final mapped = <InstitutionProfileEditField, String>{};
      var hasUnmapped = false;
      for (final entry in failure.fieldErrors.entries) {
        final field = InstitutionProfileEditField.fromApiKey(entry.key);
        if (field == null || entry.value.isEmpty) {
          hasUnmapped = true;
        } else {
          mapped[field] = entry.value.first;
        }
      }

      final firstInvalid = _firstFieldInOrder(mapped);
      state = InstitutionProfileState.validationFailure(
        profile: profile,
        form: form,
        baseline: baseline,
        fieldErrors: mapped,
        formError: hasUnmapped || mapped.isEmpty
            ? 'Some submitted profile details need review.'
            : null,
        focusField: firstInvalid,
      );
      return;
    }

    final message = failure.kind == ApiFailureKind.unknown
        ? 'A secure connection to the server could not be established. No changes were confirmed.'
        : 'The institution profile could not be updated. No changes were confirmed.';
    state = InstitutionProfileState.mutationFailure(
      profile: profile,
      form: form,
      baseline: baseline,
      formError: message,
    );
  }

  bool _acceptActiveProfile(
    InstitutionProfile profile,
    _InstitutionProfileIdentity identity,
  ) {
    if (profile.status != InstitutionProfileStatus.active) {
      state = const InstitutionProfileState.initial();
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
      return false;
    }

    final accepted = ref
        .read(authSessionControllerProvider.notifier)
        .reconcileInstitutionNameFromServer(
          expectedUserId: identity.userId,
          expectedInstitutionId: identity.institutionId,
          institutionName: profile.name,
        );

    if (!accepted || _currentIdentity() != identity) {
      state = const InstitutionProfileState.initial();
      return false;
    }

    return true;
  }

  bool _clearProtectedStateForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired) {
      state = const InstitutionProfileState.initial();
      return true;
    }

    if (code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      state = const InstitutionProfileState.initial();
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
      return true;
    }

    return false;
  }

  void _publishLoadFailure(_LoadPurpose purpose, ApiFailure failure) {
    state = purpose == _LoadPurpose.recovery
        ? const InstitutionProfileState.outcomeUnknown()
        : InstitutionProfileState.loadError(
            failure,
            operation: InstitutionProfileFailureOperation.load,
          );
  }

  int _beginOperation() {
    _operationGeneration += 1;
    _inFlightGeneration = _operationGeneration;

    return _operationGeneration;
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightGeneration = null;
  }

  bool _canComplete(int generation, _InstitutionProfileIdentity identity) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        generation == _inFlightGeneration &&
        _currentIdentity() == identity;
  }

  _InstitutionProfileIdentity? _currentIdentity() {
    if (_isDisposed || !_isActive) {
      return null;
    }

    final snapshot = InstitutionProfileSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
    );
    if (!snapshot.isEligibleFor(_providerKey)) {
      return null;
    }

    return _InstitutionProfileIdentity(
      userId: _providerKey.userId,
      institutionId: _providerKey.institutionId,
    );
  }
}

bool _isDefiniteMutationFailure(ApiFailure failure) {
  final code = failure.serverCode;
  final expected = switch (failure.statusCode) {
    401 => code == ApiErrorCodes.authenticationRequired,
    403 =>
      code == ApiErrorCodes.forbidden ||
          code == ApiErrorCodes.passwordChangeRequired ||
          code == ApiErrorCodes.userInactive ||
          code == ApiErrorCodes.institutionInactive,
    404 => code == ApiErrorCodes.resourceNotFound,
    422 => code == ApiErrorCodes.validationFailed,
    429 => code == ApiErrorCodes.rateLimited,
    _ => false,
  };

  return expected && (failure.statusCode == 422 || failure.fieldErrors.isEmpty);
}

class InstitutionProfileSessionSnapshot {
  const InstitutionProfileSessionSnapshot({
    required this.status,
    required this.userId,
    required this.userInstitutionId,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.institutionId,
    required this.institutionStatus,
  });

  factory InstitutionProfileSessionSnapshot.fromSession(
    AuthSessionState session,
  ) {
    final user = session.user;
    final institution = user?.institution;

    return InstitutionProfileSessionSnapshot(
      status: session.status,
      userId: user?.id,
      userInstitutionId: user?.institutionId,
      role: user?.role,
      isActive: user?.isActive,
      mustChangePassword: user?.mustChangePassword,
      institutionId: institution?.id,
      institutionStatus: institution?.status,
    );
  }

  final AuthSessionStatus status;
  final String? userId;
  final String? userInstitutionId;
  final UserRole? role;
  final bool? isActive;
  final bool? mustChangePassword;
  final String? institutionId;
  final String? institutionStatus;

  bool isEligibleFor(InstitutionProfileSessionKey providerKey) {
    final currentInstitutionId = userInstitutionId;

    return status == AuthSessionStatus.authenticated &&
        userId != null &&
        userId == providerKey.userId &&
        role == UserRole.institutionAdmin &&
        isActive == true &&
        mustChangePassword == false &&
        currentInstitutionId != null &&
        currentInstitutionId.trim().isNotEmpty &&
        currentInstitutionId == providerKey.institutionId &&
        institutionId == currentInstitutionId &&
        institutionStatus == 'active';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionProfileSessionSnapshot &&
            other.status == status &&
            other.userId == userId &&
            other.userInstitutionId == userInstitutionId &&
            other.role == role &&
            other.isActive == isActive &&
            other.mustChangePassword == mustChangePassword &&
            other.institutionId == institutionId &&
            other.institutionStatus == institutionStatus;
  }

  @override
  int get hashCode => Object.hash(
    status,
    userId,
    userInstitutionId,
    role,
    isActive,
    mustChangePassword,
    institutionId,
    institutionStatus,
  );
}

class _InstitutionProfileIdentity {
  const _InstitutionProfileIdentity({
    required this.userId,
    required this.institutionId,
  });

  final String userId;
  final String institutionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _InstitutionProfileIdentity &&
            other.userId == userId &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode => Object.hash(userId, institutionId);
}

enum _LoadPurpose { initial, refresh, retry, recovery }

bool _isVerifiedViewState(InstitutionProfileViewStatus status) {
  return status == InstitutionProfileViewStatus.data ||
      status == InstitutionProfileViewStatus.confirmedDirectSuccess ||
      status == InstitutionProfileViewStatus.unconfirmedCurrentState;
}

bool _isEditableState(InstitutionProfileViewStatus status) {
  return status == InstitutionProfileViewStatus.editing ||
      status == InstitutionProfileViewStatus.validationFailure ||
      status == InstitutionProfileViewStatus.mutationFailure;
}

InstitutionProfileEditField? _firstFieldInOrder(
  Map<InstitutionProfileEditField, String> errors,
) {
  for (final field in InstitutionProfileEditField.values) {
    if (errors.containsKey(field)) {
      return field;
    }
  }

  return null;
}
