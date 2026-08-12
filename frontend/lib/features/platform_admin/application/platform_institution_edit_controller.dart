import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_institution_detail_repository_impl.dart';
import '../data/platform_institution_edit_repository_impl.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_detail.dart';
import '../domain/platform_institution_edit.dart';
import '../domain/platform_institution_edit_repository.dart';
import 'platform_dashboard_controller.dart';
import 'platform_institution_detail_controller.dart';
import 'platform_institution_detail_state.dart';
import 'platform_institution_edit_state.dart';
import 'platform_institution_list_controller.dart';

final platformInstitutionEditControllerProvider = NotifierProvider.autoDispose
    .family<
      PlatformInstitutionEditController,
      PlatformInstitutionEditState,
      PlatformInstitutionEditKey
    >((key) => PlatformInstitutionEditController(key));

class PlatformInstitutionEditController
    extends Notifier<PlatformInstitutionEditState> {
  PlatformInstitutionEditController(this.key);

  final PlatformInstitutionEditKey key;

  String? _sessionUserId;
  int? _sessionInstanceId;
  String? _inFlightInstitutionId;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformInstitutionEditState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _operationGeneration += 1;
      _inFlightInstitutionId = null;
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

      return const PlatformInstitutionEditState.initial();
    }

    if (_sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId) {
      return state;
    }

    _sessionUserId = key.sessionUserId;
    _sessionInstanceId = key.sessionInstanceId;
    _operationGeneration += 1;
    _inFlightInstitutionId = null;

    scheduleMicrotask(() {
      if (!_isDisposed &&
          _sessionUserId == key.sessionUserId &&
          _sessionInstanceId == key.sessionInstanceId) {
        unawaited(_loadForKey());
      }
    });

    return const PlatformInstitutionEditState.loading();
  }

  Future<void> retry() async {
    if (state.status != PlatformInstitutionEditStatus.loadError ||
        state.isRetryInFlight) {
      return;
    }

    if (_sessionUserId == null || _sessionInstanceId == null) {
      return;
    }

    state = state.retrying();
    await _loadForKey(isRetry: true);
  }

  void updateName(String value) {
    _updateForm(
      state.form?.copyWith(name: value),
      PlatformInstitutionEditField.name,
    );
  }

  void updateType(PlatformInstitutionType? value) {
    if (value == null) {
      return;
    }

    _updateForm(
      state.form?.copyWith(type: value),
      PlatformInstitutionEditField.type,
    );
  }

  void updateContactEmail(String value) {
    _updateForm(
      state.form?.copyWith(contactEmail: value),
      PlatformInstitutionEditField.contactEmail,
    );
  }

  void updateContactPhone(String value) {
    _updateForm(
      state.form?.copyWith(contactPhone: value),
      PlatformInstitutionEditField.contactPhone,
    );
  }

  void updateAddress(String value) {
    _updateForm(
      state.form?.copyWith(address: value),
      PlatformInstitutionEditField.address,
    );
  }

  void updateDescription(String value) {
    _updateForm(
      state.form?.copyWith(description: value),
      PlatformInstitutionEditField.description,
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit) {
      return;
    }

    final detail = state.detail;
    final form = state.form;
    final initialSnapshot = state.initialSnapshot;
    if (detail == null || form == null || initialSnapshot == null) {
      return;
    }

    final validation = form.validate();
    if (!validation.isValid) {
      state = PlatformInstitutionEditState.validationFailure(
        detail: detail,
        form: form,
        initialSnapshot: initialSnapshot,
        fieldErrors: validation.fieldErrors,
        firstErrorField: validation.firstInvalidField,
      );
      return;
    }

    final request = form.toChangedFieldsRequest(initialSnapshot);
    if (request.isEmpty) {
      state = state.noChangesToSave();
      return;
    }

    final sessionUserId = _sessionUserId;
    final sessionInstanceId = _sessionInstanceId;
    if (sessionUserId == null || sessionInstanceId == null) {
      return;
    }

    final generation = _beginOperation();
    final repository = ref.read(platformInstitutionEditRepositoryProvider);
    state = PlatformInstitutionEditState.submitting(
      detail: detail,
      form: form,
      initialSnapshot: initialSnapshot,
    );

    try {
      final result = await repository.updateInstitution(
        key.institutionId,
        request,
      );
      if (!_canComplete(generation, sessionUserId, sessionInstanceId)) {
        return;
      }

      final detailProvider = platformInstitutionDetailControllerProvider(
        PlatformInstitutionDetailKey(
          sessionUserId: sessionUserId,
          sessionInstanceId: sessionInstanceId,
          institutionId: result.id,
        ),
      );
      ref.invalidate(detailProvider);
      ref.invalidate(platformInstitutionListControllerProvider);
      ref.invalidate(platformDashboardControllerProvider);
      state = PlatformInstitutionEditState.success(
        detail: detail,
        form: form,
        initialSnapshot: initialSnapshot,
        result: result,
      );
    } on PlatformInstitutionEditOutcomeUnknownException {
      if (!_canComplete(generation, sessionUserId, sessionInstanceId)) {
        return;
      }

      state = PlatformInstitutionEditState.outcomeUnknown(
        detail: detail,
        form: form,
        initialSnapshot: initialSnapshot,
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, sessionUserId, sessionInstanceId)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      if (_isValidationFailure(exception.failure)) {
        state = _validationStateForServerFailure(
          detail: detail,
          form: form,
          initialSnapshot: initialSnapshot,
          failure: exception.failure,
        );
      } else if (_isResourceNotFound(exception.failure)) {
        state = const PlatformInstitutionEditState.notFound();
      } else if (_isForbidden(exception.failure)) {
        state = const PlatformInstitutionEditState.accessDenied();
      } else {
        state = PlatformInstitutionEditState.failure(
          detail: detail,
          form: form,
          initialSnapshot: initialSnapshot,
          formError: _safeFailureMessage(exception.failure),
          failure: exception.failure,
        );
      }
    }
  }

  Future<void> _loadForKey({bool isRetry = false}) async {
    if (!isRetry &&
        state.isRequestInFlight &&
        _inFlightInstitutionId == key.institutionId) {
      return;
    }

    final generation = _beginOperation();
    final repository = ref.read(platformInstitutionDetailRepositoryProvider);

    try {
      final detail = await repository.fetchInstitutionDetail(key.institutionId);
      if (!_canComplete(generation, key.sessionUserId, key.sessionInstanceId)) {
        return;
      }

      if (detail.id != key.institutionId) {
        state = PlatformInstitutionEditState.loadError(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'Institution detail response did not match request.',
          ),
        );
        return;
      }

      final form = PlatformInstitutionEditFormValue.fromDetail(detail);
      state = PlatformInstitutionEditState.ready(
        detail: detail,
        form: form,
        initialSnapshot: form.normalized(),
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, key.sessionUserId, key.sessionInstanceId)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      if (_isResourceNotFound(exception.failure)) {
        state = const PlatformInstitutionEditState.notFound();
      } else if (_isForbidden(exception.failure)) {
        state = const PlatformInstitutionEditState.accessDenied();
      } else {
        state = PlatformInstitutionEditState.loadError(exception.failure);
      }
    } finally {
      if (_inFlightInstitutionId == key.institutionId) {
        _inFlightInstitutionId = null;
      }
    }
  }

  void _updateForm(
    PlatformInstitutionEditFormValue? form,
    PlatformInstitutionEditField field,
  ) {
    if (form == null ||
        state.isSubmitting ||
        state.status == PlatformInstitutionEditStatus.success ||
        state.status == PlatformInstitutionEditStatus.outcomeUnknown) {
      return;
    }

    state = state.withForm(form, clearFieldError: field);
  }

  int _beginOperation() {
    _operationGeneration += 1;
    _inFlightInstitutionId = key.institutionId;

    return _operationGeneration;
  }

  bool _canComplete(
    int generation,
    String sessionUserId,
    int sessionInstanceId,
  ) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        _sessionUserId == sessionUserId &&
        _sessionInstanceId == sessionInstanceId;
  }

  void _clearSessionState() {
    _sessionUserId = null;
    _sessionInstanceId = null;
    _inFlightInstitutionId = null;
    _operationGeneration += 1;
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

  bool _isForbidden(ApiFailure failure) {
    return failure.statusCode == 403 &&
        failure.serverCode == ApiErrorCodes.forbidden;
  }

  PlatformInstitutionEditState _validationStateForServerFailure({
    required PlatformInstitutionDetail detail,
    required PlatformInstitutionEditFormValue form,
    required PlatformInstitutionEditSnapshot initialSnapshot,
    required ApiFailure failure,
  }) {
    final fieldErrors = <PlatformInstitutionEditField, List<String>>{};
    var hasUnknownValidationEntry = false;

    for (final entry in failure.fieldErrors.entries) {
      final field = PlatformInstitutionEditField.fromRequestKey(entry.key);
      if (field == null) {
        hasUnknownValidationEntry = true;
        continue;
      }

      fieldErrors[field] = entry.value;
    }

    final formError = hasUnknownValidationEntry || fieldErrors.isEmpty
        ? 'Some submitted institution details need review.'
        : null;

    return PlatformInstitutionEditState.validationFailure(
      detail: detail,
      form: form,
      initialSnapshot: initialSnapshot,
      fieldErrors: fieldErrors,
      firstErrorField: _firstFieldIn(fieldErrors),
      formError: formError,
      failure: failure,
    );
  }

  PlatformInstitutionEditField? _firstFieldIn(
    Map<PlatformInstitutionEditField, List<String>> fieldErrors,
  ) {
    for (final field in PlatformInstitutionEditField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }

  String _safeFailureMessage(ApiFailure failure) {
    return switch (failure.serverCode) {
      ApiErrorCodes.authenticationRequired => 'Please sign in again.',
      ApiErrorCodes.passwordChangeRequired =>
        'Password change is required before institution editing.',
      ApiErrorCodes.userInactive => 'This account is inactive.',
      ApiErrorCodes.institutionInactive => 'This institution is inactive.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to edit this institution.',
      ApiErrorCodes.validationFailed =>
        'The institution update request did not match the API contract.',
      ApiErrorCodes.serverError =>
        'The institution could not be updated. No changes were confirmed.',
      _ => switch (failure.kind) {
        ApiFailureKind.connection =>
          'Could not reach the server. No update was confirmed.',
        ApiFailureKind.timeout => 'The institution update request timed out.',
        ApiFailureKind.invalidResponse =>
          'The server returned an unexpected institution update response.',
        ApiFailureKind.cancelled =>
          'The institution update request was cancelled.',
        ApiFailureKind.unknown ||
        ApiFailureKind.server ||
        ApiFailureKind.validation =>
          'The institution could not be updated. No changes were confirmed.',
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
