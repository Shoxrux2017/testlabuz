import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_institution_create_repository_impl.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_create.dart';
import '../domain/platform_institution_create_repository.dart';
import 'platform_dashboard_controller.dart';
import 'platform_institution_create_state.dart';
import 'platform_institution_list_controller.dart';

final platformInstitutionCreateControllerProvider = NotifierProvider.autoDispose
    .family<
      PlatformInstitutionCreateController,
      PlatformInstitutionCreateState,
      PlatformInstitutionCreateKey
    >((key) => PlatformInstitutionCreateController(key));

class PlatformInstitutionCreateController
    extends Notifier<PlatformInstitutionCreateState> {
  PlatformInstitutionCreateController(this.key);

  final PlatformInstitutionCreateKey key;

  String? _sessionUserId;
  int? _sessionInstanceId;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformInstitutionCreateState build() {
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

      return const PlatformInstitutionCreateState.editing();
    }

    if (_sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId) {
      return state;
    }

    _sessionUserId = key.sessionUserId;
    _sessionInstanceId = key.sessionInstanceId;
    _operationGeneration += 1;

    return const PlatformInstitutionCreateState.editing();
  }

  void updateName(String value) {
    _updateForm(
      state.form.copyWith(name: value),
      PlatformInstitutionCreateField.name,
    );
  }

  void updateType(PlatformInstitutionType? value) {
    _updateForm(
      state.form.copyWith(type: value),
      PlatformInstitutionCreateField.type,
    );
  }

  void updateContactEmail(String value) {
    _updateForm(
      state.form.copyWith(contactEmail: value),
      PlatformInstitutionCreateField.contactEmail,
    );
  }

  void updateContactPhone(String value) {
    _updateForm(
      state.form.copyWith(contactPhone: value),
      PlatformInstitutionCreateField.contactPhone,
    );
  }

  void updateAddress(String value) {
    _updateForm(
      state.form.copyWith(address: value),
      PlatformInstitutionCreateField.address,
    );
  }

  void updateDescription(String value) {
    _updateForm(
      state.form.copyWith(description: value),
      PlatformInstitutionCreateField.description,
    );
  }

  void updateStatus(PlatformInstitutionStatus? value) {
    _updateForm(
      state.form.copyWith(status: value),
      PlatformInstitutionCreateField.status,
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit) {
      return;
    }

    final validation = state.form.validate();
    if (!validation.isValid) {
      state = PlatformInstitutionCreateState.validationFailure(
        form: state.form,
        fieldErrors: validation.fieldErrors,
        firstErrorField: validation.firstInvalidField,
      );
      return;
    }

    final sessionUserId = _sessionUserId;
    final sessionInstanceId = _sessionInstanceId;
    if (sessionUserId == null || sessionInstanceId == null) {
      return;
    }

    final form = state.form;
    final request = form.toRequest();
    final generation = _beginOperation();
    final repository = ref.read(platformInstitutionCreateRepositoryProvider);
    state = PlatformInstitutionCreateState.submitting(form: form);

    try {
      final result = await repository.createInstitution(request);
      if (!_canComplete(generation, sessionUserId, sessionInstanceId)) {
        return;
      }

      ref.invalidate(platformInstitutionListControllerProvider);
      ref.invalidate(platformDashboardControllerProvider);
      state = PlatformInstitutionCreateState.success(
        form: form,
        result: result,
      );
    } on PlatformInstitutionCreateOutcomeUnknownException {
      if (!_canComplete(generation, sessionUserId, sessionInstanceId)) {
        return;
      }

      state = PlatformInstitutionCreateState.outcomeUnknown(form: form);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, sessionUserId, sessionInstanceId)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      if (_isValidationFailure(exception.failure)) {
        state = _validationStateForServerFailure(form, exception.failure);
      } else {
        state = PlatformInstitutionCreateState.failure(
          form: form,
          formError: _safeFailureMessage(exception.failure),
          failure: exception.failure,
        );
      }
    }
  }

  void _updateForm(
    PlatformInstitutionCreateFormValue form,
    PlatformInstitutionCreateField field,
  ) {
    if (state.isSubmitting ||
        state.status == PlatformInstitutionCreateStatus.success ||
        state.status == PlatformInstitutionCreateStatus.outcomeUnknown) {
      return;
    }

    state = state.withForm(form, clearFieldError: field);
  }

  int _beginOperation() {
    _operationGeneration += 1;

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
    _operationGeneration += 1;
  }

  bool _isValidationFailure(ApiFailure failure) {
    return failure.kind == ApiFailureKind.validation ||
        failure.statusCode == 422 ||
        failure.serverCode == ApiErrorCodes.validationFailed;
  }

  PlatformInstitutionCreateState _validationStateForServerFailure(
    PlatformInstitutionCreateFormValue form,
    ApiFailure failure,
  ) {
    final fieldErrors = <PlatformInstitutionCreateField, List<String>>{};
    var hasUnknownValidationEntry = false;

    for (final entry in failure.fieldErrors.entries) {
      final field = PlatformInstitutionCreateField.fromRequestKey(entry.key);
      if (field == null) {
        hasUnknownValidationEntry = true;
        continue;
      }

      fieldErrors[field] = entry.value;
    }

    final formError = hasUnknownValidationEntry || fieldErrors.isEmpty
        ? 'Some submitted institution details need review.'
        : null;

    return PlatformInstitutionCreateState.validationFailure(
      form: form,
      fieldErrors: fieldErrors,
      firstErrorField: _firstFieldIn(fieldErrors),
      formError: formError,
      failure: failure,
    );
  }

  PlatformInstitutionCreateField? _firstFieldIn(
    Map<PlatformInstitutionCreateField, List<String>> fieldErrors,
  ) {
    for (final field in PlatformInstitutionCreateField.values) {
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
        'Password change is required before institution creation.',
      ApiErrorCodes.userInactive => 'This account is inactive.',
      ApiErrorCodes.institutionInactive => 'This institution is inactive.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to create institutions.',
      ApiErrorCodes.validationFailed =>
        'The institution create request did not match the API contract.',
      ApiErrorCodes.serverError =>
        'The institution could not be created. No changes were confirmed.',
      _ => switch (failure.kind) {
        ApiFailureKind.connection =>
          'Could not reach the server. No creation was confirmed.',
        ApiFailureKind.timeout => 'The institution creation request timed out.',
        ApiFailureKind.invalidResponse =>
          'The server returned an unexpected institution creation response.',
        ApiFailureKind.cancelled =>
          'The institution creation request was cancelled.',
        ApiFailureKind.unknown ||
        ApiFailureKind.server ||
        ApiFailureKind.validation =>
          'The institution could not be created. No changes were confirmed.',
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
