import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_institution_admin_repository_impl.dart';
import '../domain/platform_institution_admin.dart';
import '../domain/platform_institution_admin_lifecycle.dart';
import '../domain/platform_institution_admin_list_query.dart';
import '../domain/platform_institution_admin_repository.dart';
import '../domain/platform_institution_admin_update.dart';
import '../domain/platform_institution_list_query.dart';
import 'platform_dashboard_controller.dart';
import 'platform_institution_admin_action_state.dart';
import 'platform_institution_admin_list_controller.dart';
import 'platform_institution_admin_list_state.dart';
import 'platform_institution_detail_controller.dart';
import 'platform_institution_detail_state.dart';
import 'platform_institution_list_controller.dart';

final platformInstitutionAdminActionControllerProvider = NotifierProvider
    .autoDispose
    .family<
      PlatformInstitutionAdminActionController,
      PlatformInstitutionAdminActionState,
      PlatformInstitutionAdminActionKey
    >((key) => PlatformInstitutionAdminActionController(key));

class PlatformInstitutionAdminActionController
    extends Notifier<PlatformInstitutionAdminActionState> {
  PlatformInstitutionAdminActionController(this.key);

  final PlatformInstitutionAdminActionKey key;

  String? _sessionUserId;
  int? _sessionInstanceId;
  String? _institutionId;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformInstitutionAdminActionState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _operationGeneration += 1;
    });

    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;

    if (session.status != AuthSessionStatus.authenticated ||
        user == null ||
        user.id != key.sessionUserId ||
        identityHashCode(user) != key.sessionInstanceId ||
        user.role != UserRole.platformOwner ||
        user.mustChangePassword) {
      _clearSessionState();

      return const PlatformInstitutionAdminActionState.idle();
    }

    if (_sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId &&
        _institutionId == key.institutionId) {
      return state;
    }

    _sessionUserId = key.sessionUserId;
    _sessionInstanceId = key.sessionInstanceId;
    _institutionId = key.institutionId;
    _operationGeneration += 1;

    return const PlatformInstitutionAdminActionState.idle();
  }

  bool beginEdit(PlatformInstitutionAdmin admin) {
    if (!_canStartFor(admin)) {
      return false;
    }

    _operationGeneration += 1;
    final snapshot = PlatformInstitutionAdminActionSnapshot(
      institutionId: key.institutionId,
      admin: admin,
      sessionUserId: key.sessionUserId,
      sessionInstanceId: key.sessionInstanceId,
      requestGeneration: _operationGeneration,
      kind: PlatformInstitutionAdminActionKind.edit,
    );
    state = PlatformInstitutionAdminActionState.editing(
      snapshot: snapshot,
      form: PlatformInstitutionAdminEditFormValue.fromAdmin(admin),
    );

    return true;
  }

  bool beginLifecycle(PlatformInstitutionAdmin admin) {
    if (!_canStartFor(admin)) {
      return false;
    }

    _operationGeneration += 1;
    final action = PlatformInstitutionAdminLifecycleAction.forAdmin(admin);
    final snapshot = PlatformInstitutionAdminActionSnapshot(
      institutionId: key.institutionId,
      admin: admin,
      sessionUserId: key.sessionUserId,
      sessionInstanceId: key.sessionInstanceId,
      requestGeneration: _operationGeneration,
      kind: PlatformInstitutionAdminActionKind.lifecycle,
      lifecycleAction: action,
    );
    state = PlatformInstitutionAdminActionState.lifecycleConfirming(
      snapshot: snapshot,
    );

    return true;
  }

  void updateFullName(String value) {
    _updateEditForm(
      state.form?.copyWith(fullName: value),
      PlatformInstitutionAdminEditField.fullName,
    );
  }

  void updateEmail(String value) {
    _updateEditForm(
      state.form?.copyWith(email: value),
      PlatformInstitutionAdminEditField.email,
    );
  }

  void updatePhone(String value) {
    _updateEditForm(
      state.form?.copyWith(phone: value),
      PlatformInstitutionAdminEditField.phone,
    );
  }

  Future<void> submitEdit() async {
    if (!state.canSubmitEdit) {
      return;
    }

    final currentSnapshot = state.snapshot;
    final form = state.form;
    if (currentSnapshot == null ||
        form == null ||
        currentSnapshot.kind != PlatformInstitutionAdminActionKind.edit ||
        !_operationMatchesCurrentSession(currentSnapshot)) {
      return;
    }

    final validation = form.validate();
    if (validation.isNotEmpty) {
      final fieldErrors = <PlatformInstitutionAdminEditField, List<String>>{
        for (final entry in validation.entries) entry.key: [entry.value],
      };
      state = PlatformInstitutionAdminActionState.validationFailure(
        snapshot: currentSnapshot,
        form: form,
        fieldErrors: fieldErrors,
        firstErrorField: _firstFieldIn(fieldErrors),
      );
      return;
    }

    final request = form.toChangedRequest(initialAdmin: currentSnapshot.admin);
    if (request.isEmpty) {
      state = PlatformInstitutionAdminActionState.validationFailure(
        snapshot: currentSnapshot,
        form: form,
        fieldErrors: const {},
        firstErrorField: null,
        formError: 'No administrator changes to save.',
      );
      return;
    }

    final operation = currentSnapshot.copyWithRequestGeneration(
      _beginOperation(),
    );
    final repository = ref.read(platformInstitutionAdminRepositoryProvider);
    state = PlatformInstitutionAdminActionState.editSubmitting(
      snapshot: operation,
      form: form,
    );

    try {
      final result = await repository.updateAdmin(
        adminId: operation.adminId,
        request: request,
      );
      if (!_canComplete(operation)) {
        return;
      }

      state = PlatformInstitutionAdminActionState.success(
        snapshot: operation,
        form: form,
        resultAdmin: result.admin,
        completion: const PlatformInstitutionAdminActionCompletion(
          kind: PlatformInstitutionAdminActionCompletionKind.profileUpdated,
          message: 'Institution admin updated successfully.',
        ),
      );
    } on PlatformInstitutionAdminMutationOutcomeUnknownException {
      if (!_canComplete(operation)) {
        return;
      }

      await _reconcileUnknownUpdateOutcome(operation, form, request);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(operation)) {
        return;
      }

      await _handleMutationFailure(
        operation: operation,
        form: form,
        failure: exception.failure,
        isEdit: true,
      );
    }
  }

  Future<void> confirmLifecycle() async {
    if (!state.canConfirmLifecycle) {
      return;
    }

    final currentSnapshot = state.snapshot;
    final action = currentSnapshot?.lifecycleAction;
    if (currentSnapshot == null ||
        action == null ||
        currentSnapshot.kind != PlatformInstitutionAdminActionKind.lifecycle ||
        !_operationMatchesCurrentSession(currentSnapshot)) {
      return;
    }

    final operation = currentSnapshot.copyWithRequestGeneration(
      _beginOperation(),
    );
    final repository = ref.read(platformInstitutionAdminRepositoryProvider);
    state = PlatformInstitutionAdminActionState.lifecycleSubmitting(
      snapshot: operation,
    );

    try {
      final result = await _sendLifecycleCommand(
        repository: repository,
        adminId: operation.adminId,
        action: action,
      );
      if (!_canComplete(operation)) {
        return;
      }

      state = PlatformInstitutionAdminActionState.success(
        snapshot: operation,
        form: null,
        resultAdmin: result.admin,
        completion: PlatformInstitutionAdminActionCompletion(
          kind: PlatformInstitutionAdminActionCompletionKind.lifecycleChanged,
          message: action.successMessage,
          lifecycleAction: action,
        ),
      );
    } on PlatformInstitutionAdminMutationOutcomeUnknownException {
      if (!_canComplete(operation)) {
        return;
      }

      await _reconcileUnknownLifecycleOutcome(operation, action);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(operation)) {
        return;
      }

      await _handleMutationFailure(
        operation: operation,
        form: null,
        failure: exception.failure,
        isEdit: false,
      );
    }
  }

  void dismiss() {
    if (!state.canDismiss) {
      return;
    }

    _operationGeneration += 1;
    state = const PlatformInstitutionAdminActionState.idle();
  }

  void resetAfterCompletion() {
    _operationGeneration += 1;
    state = const PlatformInstitutionAdminActionState.idle();
  }

  Future<PlatformInstitutionAdminLifecycleResult> _sendLifecycleCommand({
    required PlatformInstitutionAdminRepository repository,
    required String adminId,
    required PlatformInstitutionAdminLifecycleAction action,
  }) {
    return switch (action) {
      PlatformInstitutionAdminLifecycleAction.activate =>
        repository.activateAdmin(adminId: adminId),
      PlatformInstitutionAdminLifecycleAction.deactivate =>
        repository.deactivateAdmin(adminId: adminId),
    };
  }

  Future<void> _handleMutationFailure({
    required PlatformInstitutionAdminActionSnapshot operation,
    required PlatformInstitutionAdminEditFormValue? form,
    required ApiFailure failure,
    required bool isEdit,
  }) async {
    _reconcileSessionForFailure(failure);

    if (_isResourceNotFound(failure)) {
      await _refreshCurrentAdminList();
      if (!_canComplete(operation)) {
        return;
      }

      state = PlatformInstitutionAdminActionState.targetUnavailable(
        snapshot: operation,
        form: form,
        message: 'Administrator is no longer available.',
      );
      return;
    }

    if (isEdit && _isValidationFailure(failure) && form != null) {
      state = _validationStateForServerFailure(operation, form, failure);
      return;
    }

    state = PlatformInstitutionAdminActionState.definiteFailure(
      snapshot: operation,
      form: form,
      failure: failure,
      message: _safeFailureMessage(failure, isEdit: isEdit),
    );
  }

  Future<void> _reconcileUnknownUpdateOutcome(
    PlatformInstitutionAdminActionSnapshot operation,
    PlatformInstitutionAdminEditFormValue form,
    PlatformInstitutionAdminUpdateRequest request,
  ) async {
    state = PlatformInstitutionAdminActionState.reconciling(
      snapshot: operation,
      form: form,
    );

    try {
      final currentAdmin = await _fetchReconciliationTarget(operation);
      if (!_canComplete(operation)) {
        return;
      }

      if (currentAdmin == null) {
        state = PlatformInstitutionAdminActionState.unknownOutcome(
          snapshot: operation,
          form: form,
          message:
              'Outcome could not be confirmed. The administrator was not found in the current server check.',
        );
        return;
      }

      if (_changedFieldsMatch(currentAdmin, request)) {
        state = PlatformInstitutionAdminActionState.success(
          snapshot: operation,
          form: form,
          resultAdmin: currentAdmin,
          completion: const PlatformInstitutionAdminActionCompletion(
            kind: PlatformInstitutionAdminActionCompletionKind.profileUpdated,
            message: 'Institution admin updated successfully.',
          ),
        );
        return;
      }

      state = PlatformInstitutionAdminActionState.unknownOutcome(
        snapshot: operation,
        form: form,
        currentAdmin: currentAdmin,
        message:
            'Outcome could not be confirmed. Current server profile: full name ${currentAdmin.fullName}, email ${_optionalContact(currentAdmin.email)}, phone ${_optionalContact(currentAdmin.phone)}.',
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(operation)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      state = PlatformInstitutionAdminActionState.unknownOutcome(
        snapshot: operation,
        form: form,
        failure: exception.failure,
        message:
            'Outcome could not be confirmed. Refresh administrators before acting again.',
      );
    }
  }

  Future<void> _reconcileUnknownLifecycleOutcome(
    PlatformInstitutionAdminActionSnapshot operation,
    PlatformInstitutionAdminLifecycleAction action,
  ) async {
    state = PlatformInstitutionAdminActionState.reconciling(
      snapshot: operation,
      form: null,
    );

    try {
      final currentAdmin = await _fetchReconciliationTarget(operation);
      if (!_canComplete(operation)) {
        return;
      }

      if (currentAdmin == null) {
        state = PlatformInstitutionAdminActionState.unknownOutcome(
          snapshot: operation,
          form: null,
          message:
              'Outcome could not be confirmed. The administrator was not found in the current server check.',
        );
        return;
      }

      if (currentAdmin.isActive == action.targetIsActive) {
        state = PlatformInstitutionAdminActionState.success(
          snapshot: operation,
          form: null,
          resultAdmin: currentAdmin,
          completion: PlatformInstitutionAdminActionCompletion(
            kind: PlatformInstitutionAdminActionCompletionKind.lifecycleChanged,
            message: action.successMessage,
            lifecycleAction: action,
          ),
        );
        return;
      }

      final status = currentAdmin.isActive ? 'active' : 'inactive';
      state = PlatformInstitutionAdminActionState.unknownOutcome(
        snapshot: operation,
        form: null,
        currentAdmin: currentAdmin,
        message:
            'Outcome could not be confirmed. Current server account status is $status.',
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(operation)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      state = PlatformInstitutionAdminActionState.unknownOutcome(
        snapshot: operation,
        form: null,
        failure: exception.failure,
        message:
            'Outcome could not be confirmed. Refresh administrators before acting again.',
      );
    }
  }

  Future<PlatformInstitutionAdmin?> _fetchReconciliationTarget(
    PlatformInstitutionAdminActionSnapshot operation,
  ) async {
    final repository = ref.read(platformInstitutionAdminRepositoryProvider);
    final result = await repository.fetchAdmins(
      institutionId: operation.institutionId,
      query: PlatformInstitutionAdminListQuery(
        search: operation.loginName,
        page: 1,
        perPage: 100,
        sort: PlatformInstitutionAdminListSort.loginName,
        direction: PlatformSortDirection.asc,
      ),
    );

    for (final admin in result.admins) {
      if (admin.id == operation.adminId) {
        return admin;
      }
    }

    return null;
  }

  Future<void> _refreshCurrentAdminList() {
    return ref
        .read(
          platformInstitutionAdminListControllerProvider(
            PlatformInstitutionAdminListKey(
              sessionUserId: key.sessionUserId,
              sessionInstanceId: key.sessionInstanceId,
              institutionId: key.institutionId,
            ),
          ).notifier,
        )
        .refreshAfterMutation();
  }

  void invalidateProfileSuccess() {
    unawaited(_refreshCurrentAdminList());
  }

  void invalidateLifecycleSuccess() {
    unawaited(_refreshCurrentAdminList());
    unawaited(
      ref
          .read(
            platformInstitutionDetailControllerProvider(
              PlatformInstitutionDetailKey(
                sessionUserId: key.sessionUserId,
                sessionInstanceId: key.sessionInstanceId,
                institutionId: key.institutionId,
              ),
            ).notifier,
          )
          .refreshVisibleAfterRelatedMutation(),
    );
    ref.invalidate(platformInstitutionListControllerProvider);
    ref.invalidate(platformDashboardControllerProvider);
  }

  bool _changedFieldsMatch(
    PlatformInstitutionAdmin currentAdmin,
    PlatformInstitutionAdminUpdateRequest request,
  ) {
    for (final entry in request.changedValues.entries) {
      final matches = switch (entry.key) {
        PlatformInstitutionAdminEditField.fullName =>
          currentAdmin.fullName.trim() == entry.value,
        PlatformInstitutionAdminEditField.email =>
          _normalizedContact(currentAdmin.email) == entry.value,
        PlatformInstitutionAdminEditField.phone =>
          _normalizedContact(currentAdmin.phone) == entry.value,
      };

      if (!matches) {
        return false;
      }
    }

    return true;
  }

  void _updateEditForm(
    PlatformInstitutionAdminEditFormValue? form,
    PlatformInstitutionAdminEditField field,
  ) {
    if (form == null || state.isBusy) {
      return;
    }

    if (state.snapshot?.kind != PlatformInstitutionAdminActionKind.edit) {
      return;
    }

    state = state.withForm(form, clearFieldError: field);
  }

  bool _canStartFor(PlatformInstitutionAdmin admin) {
    return _sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId &&
        _institutionId == key.institutionId &&
        state.canStartAction &&
        admin.id.trim().isNotEmpty &&
        admin.loginName.trim().isNotEmpty;
  }

  int _beginOperation() {
    _operationGeneration += 1;

    return _operationGeneration;
  }

  bool _canComplete(PlatformInstitutionAdminActionSnapshot operation) {
    return !_isDisposed &&
        operation.requestGeneration == _operationGeneration &&
        _operationMatchesCurrentSession(operation);
  }

  bool _operationMatchesCurrentSession(
    PlatformInstitutionAdminActionSnapshot operation,
  ) {
    return operation.sessionUserId == _sessionUserId &&
        operation.sessionInstanceId == _sessionInstanceId &&
        operation.institutionId == _institutionId &&
        operation.institutionId == key.institutionId;
  }

  void _clearSessionState() {
    _sessionUserId = null;
    _sessionInstanceId = null;
    _institutionId = null;
    _operationGeneration += 1;
  }

  PlatformInstitutionAdminActionState _validationStateForServerFailure(
    PlatformInstitutionAdminActionSnapshot operation,
    PlatformInstitutionAdminEditFormValue form,
    ApiFailure failure,
  ) {
    final fieldErrors = <PlatformInstitutionAdminEditField, List<String>>{};
    var hasUnknownValidationEntry = false;

    for (final entry in failure.fieldErrors.entries) {
      final field = PlatformInstitutionAdminEditField.fromRequestKey(entry.key);
      if (field == null) {
        hasUnknownValidationEntry = true;
        continue;
      }

      fieldErrors[field] = entry.value;
    }

    return PlatformInstitutionAdminActionState.validationFailure(
      snapshot: operation,
      form: form,
      fieldErrors: fieldErrors,
      firstErrorField: _firstFieldIn(fieldErrors),
      formError: hasUnknownValidationEntry || fieldErrors.isEmpty
          ? 'Some submitted administrator details need review.'
          : null,
      failure: failure,
    );
  }

  PlatformInstitutionAdminEditField? _firstFieldIn(
    Map<PlatformInstitutionAdminEditField, List<String>> fieldErrors,
  ) {
    for (final field in PlatformInstitutionAdminEditField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }

  bool _isValidationFailure(ApiFailure failure) {
    return failure.kind == ApiFailureKind.validation ||
        failure.statusCode == 422 ||
        failure.serverCode == ApiErrorCodes.validationFailed;
  }

  bool _isResourceNotFound(ApiFailure failure) {
    return failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound;
  }

  String _safeFailureMessage(ApiFailure failure, {required bool isEdit}) {
    final action = isEdit ? 'update' : 'lifecycle';
    return switch (failure.serverCode) {
      ApiErrorCodes.authenticationRequired => 'Please sign in again.',
      ApiErrorCodes.passwordChangeRequired =>
        'Password change is required before administrator actions.',
      ApiErrorCodes.userInactive => 'This account is inactive.',
      ApiErrorCodes.institutionInactive => 'This institution is inactive.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to manage institution administrators.',
      ApiErrorCodes.resourceNotFound => 'Administrator is no longer available.',
      ApiErrorCodes.validationFailed =>
        'The administrator $action request did not match the API contract.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying this administrator action again.',
      ApiErrorCodes.serverError =>
        'The administrator $action could not be confirmed.',
      _ => switch (failure.kind) {
        ApiFailureKind.connection =>
          'Could not reach the server. No administrator $action was confirmed.',
        ApiFailureKind.timeout =>
          'The administrator $action request timed out.',
        ApiFailureKind.invalidResponse =>
          'The server returned an unexpected administrator $action response.',
        ApiFailureKind.cancelled =>
          'The administrator $action request was cancelled.',
        ApiFailureKind.unknown ||
        ApiFailureKind.server ||
        ApiFailureKind.validation =>
          'The administrator $action could not be confirmed.',
      },
    };
  }

  void _reconcileSessionForFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }
}

String? _normalizedContact(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

String _optionalContact(String? value) {
  return _normalizedContact(value) ?? 'Not provided';
}
