import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_institution_admin_repository_impl.dart';
import '../domain/platform_institution_admin_create.dart';
import 'platform_dashboard_controller.dart';
import 'platform_institution_admin_create_state.dart';
import 'platform_institution_detail_controller.dart';
import 'platform_institution_detail_state.dart';
import 'platform_institution_list_controller.dart';

final platformInstitutionAdminCreateControllerProvider = NotifierProvider
    .autoDispose
    .family<
      PlatformInstitutionAdminCreateController,
      PlatformInstitutionAdminCreateState,
      PlatformInstitutionAdminCreateKey
    >((key) => PlatformInstitutionAdminCreateController(key));

class PlatformInstitutionAdminCreateController
    extends Notifier<PlatformInstitutionAdminCreateState> {
  PlatformInstitutionAdminCreateController(this.key);

  final PlatformInstitutionAdminCreateKey key;

  String? _sessionUserId;
  int? _sessionInstanceId;
  String? _institutionId;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformInstitutionAdminCreateState build() {
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

      return const PlatformInstitutionAdminCreateState.editing();
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

    return const PlatformInstitutionAdminCreateState.editing();
  }

  void reset() {
    state = PlatformInstitutionAdminCreateState.editing(
      passwordWipeGeneration: state.passwordWipeGeneration + 1,
    );
  }

  void updateFullName(String value) {
    _updateForm(
      state.form.copyWith(fullName: value),
      PlatformInstitutionAdminCreateField.fullName,
    );
  }

  void updateLoginName(String value) {
    _updateForm(
      state.form.copyWith(loginName: value),
      PlatformInstitutionAdminCreateField.loginName,
    );
  }

  void updateEmail(String value) {
    _updateForm(
      state.form.copyWith(email: value),
      PlatformInstitutionAdminCreateField.email,
    );
  }

  void updatePhone(String value) {
    _updateForm(
      state.form.copyWith(phone: value),
      PlatformInstitutionAdminCreateField.phone,
    );
  }

  void clearPasswordError() {
    _updateForm(state.form, PlatformInstitutionAdminCreateField.password);
  }

  Future<void> submit({required String password}) async {
    if (!state.canSubmit) {
      return;
    }

    final validation = state.form.validate(password: password);
    if (validation.isNotEmpty) {
      final fieldErrors = <PlatformInstitutionAdminCreateField, List<String>>{
        for (final entry in validation.entries) entry.key: [entry.value],
      };
      state = PlatformInstitutionAdminCreateState.validationFailure(
        form: state.form,
        fieldErrors: fieldErrors,
        firstErrorField: _firstFieldIn(fieldErrors),
        passwordWipeGeneration: state.passwordWipeGeneration,
      );
      return;
    }

    final sessionUserId = _sessionUserId;
    final sessionInstanceId = _sessionInstanceId;
    final institutionId = _institutionId;
    if (sessionUserId == null ||
        sessionInstanceId == null ||
        institutionId == null) {
      return;
    }

    final form = state.form;
    final request = form.toRequest(password: password);
    final generation = _beginOperation();
    final repository = ref.read(platformInstitutionAdminRepositoryProvider);
    state = PlatformInstitutionAdminCreateState.submitting(
      form: form,
      passwordWipeGeneration: state.passwordWipeGeneration,
    );

    try {
      final result = await repository.createAdmin(
        institutionId: institutionId,
        request: request,
      );
      if (!_canComplete(
        generation,
        sessionUserId,
        sessionInstanceId,
        institutionId,
      )) {
        return;
      }

      ref.invalidate(platformInstitutionListControllerProvider);
      ref.invalidate(platformDashboardControllerProvider);
      state = PlatformInstitutionAdminCreateState.success(
        form: form,
        result: result,
        passwordWipeGeneration: state.passwordWipeGeneration + 1,
      );
    } on PlatformInstitutionAdminCreateOutcomeUnknownException {
      if (!_canComplete(
        generation,
        sessionUserId,
        sessionInstanceId,
        institutionId,
      )) {
        return;
      }

      state = PlatformInstitutionAdminCreateState.outcomeUnknown(
        form: form,
        passwordWipeGeneration: state.passwordWipeGeneration + 1,
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(
        generation,
        sessionUserId,
        sessionInstanceId,
        institutionId,
      )) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      if (_isValidationFailure(exception.failure)) {
        state = _validationStateForServerFailure(form, exception.failure);
      } else if (_isInstitutionNotFound(exception.failure)) {
        _refreshDetailAfterNotFound();
        state = PlatformInstitutionAdminCreateState.failure(
          form: const PlatformInstitutionAdminCreateFormValue(),
          formError: _safeFailureMessage(exception.failure),
          failure: exception.failure,
          passwordWipeGeneration: state.passwordWipeGeneration + 1,
        );
      } else {
        state = PlatformInstitutionAdminCreateState.failure(
          form: form,
          formError: _safeFailureMessage(exception.failure),
          failure: exception.failure,
          passwordWipeGeneration: state.passwordWipeGeneration,
        );
      }
    }
  }

  void _updateForm(
    PlatformInstitutionAdminCreateFormValue form,
    PlatformInstitutionAdminCreateField field,
  ) {
    if (state.isSubmitting ||
        state.status == PlatformInstitutionAdminCreateStatus.success ||
        state.status == PlatformInstitutionAdminCreateStatus.outcomeUnknown) {
      return;
    }

    state = state.withForm(form, clearFieldError: field);
  }

  void _refreshDetailAfterNotFound() {
    final detailKey = _detailKey();
    if (detailKey == null) {
      return;
    }

    ref.invalidate(platformInstitutionDetailControllerProvider(detailKey));
  }

  PlatformInstitutionDetailKey? _detailKey() {
    final sessionUserId = _sessionUserId;
    final sessionInstanceId = _sessionInstanceId;
    final institutionId = _institutionId;
    if (sessionUserId == null ||
        sessionInstanceId == null ||
        institutionId == null) {
      return null;
    }

    return PlatformInstitutionDetailKey(
      sessionUserId: sessionUserId,
      sessionInstanceId: sessionInstanceId,
      institutionId: institutionId,
    );
  }

  int _beginOperation() {
    _operationGeneration += 1;

    return _operationGeneration;
  }

  bool _canComplete(
    int generation,
    String sessionUserId,
    int sessionInstanceId,
    String institutionId,
  ) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        _sessionUserId == sessionUserId &&
        _sessionInstanceId == sessionInstanceId &&
        _institutionId == institutionId;
  }

  void _clearSessionState() {
    _sessionUserId = null;
    _sessionInstanceId = null;
    _institutionId = null;
    _operationGeneration += 1;
  }

  bool _isValidationFailure(ApiFailure failure) {
    return failure.kind == ApiFailureKind.validation ||
        failure.statusCode == 422 ||
        failure.serverCode == ApiErrorCodes.validationFailed;
  }

  bool _isInstitutionNotFound(ApiFailure failure) {
    return failure.statusCode == 404 ||
        failure.serverCode == ApiErrorCodes.resourceNotFound;
  }

  PlatformInstitutionAdminCreateState _validationStateForServerFailure(
    PlatformInstitutionAdminCreateFormValue form,
    ApiFailure failure,
  ) {
    final fieldErrors = <PlatformInstitutionAdminCreateField, List<String>>{};
    var hasUnknownValidationEntry = false;

    for (final entry in failure.fieldErrors.entries) {
      final field = PlatformInstitutionAdminCreateField.fromRequestKey(
        entry.key,
      );
      if (field == null) {
        hasUnknownValidationEntry = true;
        continue;
      }

      fieldErrors[field] = entry.value;
    }

    final formError = hasUnknownValidationEntry || fieldErrors.isEmpty
        ? 'Some submitted administrator details need review.'
        : null;

    return PlatformInstitutionAdminCreateState.validationFailure(
      form: form,
      fieldErrors: fieldErrors,
      firstErrorField: _firstFieldIn(fieldErrors),
      formError: formError,
      failure: failure,
      passwordWipeGeneration: state.passwordWipeGeneration,
    );
  }

  PlatformInstitutionAdminCreateField? _firstFieldIn(
    Map<PlatformInstitutionAdminCreateField, List<String>> fieldErrors,
  ) {
    for (final field in PlatformInstitutionAdminCreateField.values) {
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
        'Password change is required before administrator creation.',
      ApiErrorCodes.userInactive => 'This account is inactive.',
      ApiErrorCodes.institutionInactive => 'This institution is inactive.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to create institution administrators.',
      ApiErrorCodes.resourceNotFound => 'The institution could not be found.',
      ApiErrorCodes.validationFailed =>
        'The administrator create request did not match the API contract.',
      ApiErrorCodes.serverError =>
        'The administrator could not be created. No changes were confirmed.',
      _ => switch (failure.kind) {
        ApiFailureKind.connection =>
          'Could not reach the server. No creation was confirmed.',
        ApiFailureKind.timeout =>
          'The administrator creation request timed out.',
        ApiFailureKind.invalidResponse =>
          'The server returned an unexpected administrator creation response.',
        ApiFailureKind.cancelled =>
          'The administrator creation request was cancelled.',
        ApiFailureKind.unknown ||
        ApiFailureKind.server ||
        ApiFailureKind.validation =>
          'The administrator could not be created. No changes were confirmed.',
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
