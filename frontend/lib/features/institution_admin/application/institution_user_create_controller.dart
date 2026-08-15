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
import '../data/institution_user_create_repository_impl.dart';
import '../data/institution_user_list_repository_impl.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_create.dart';
import '../domain/institution_user_list.dart';
import '../domain/institution_user_list_query.dart';
import 'institution_dashboard_controller.dart';
import 'institution_user_create_state.dart';
import 'institution_user_list_controller.dart';

final institutionUserCreateControllerProvider =
    NotifierProvider.autoDispose<
      InstitutionUserCreateController,
      InstitutionUserCreateState
    >(InstitutionUserCreateController.new);

class InstitutionUserCreateController
    extends Notifier<InstitutionUserCreateState> {
  InstitutionUserCreateSessionKey? _activeSessionKey;
  InstitutionUserCreateSnapshot? _activeSnapshot;
  int _operationGeneration = 0;
  int _passwordWipeGeneration = 0;

  @override
  InstitutionUserCreateState build() {
    final sessionKey = InstitutionUserCreateSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      final hadSession = _activeSessionKey != null;
      _clearSession();
      if (hadSession) {
        _wipePassword();
      }

      return InstitutionUserCreateState.editing(
        passwordWipeGeneration: _passwordWipeGeneration,
      );
    }

    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearSession();
    _activeSessionKey = sessionKey;
    _wipePassword();

    return InstitutionUserCreateState.editing(
      passwordWipeGeneration: _passwordWipeGeneration,
    );
  }

  void updateRole(InstitutionUserRole? value) {
    _updateForm(
      state.form.copyWith(role: value),
      InstitutionUserCreateField.role,
    );
  }

  void updateFullName(String value) {
    _updateForm(
      state.form.copyWith(fullName: value),
      InstitutionUserCreateField.fullName,
    );
  }

  void updateLoginName(String value) {
    _updateForm(
      state.form.copyWith(loginName: value),
      InstitutionUserCreateField.loginName,
    );
  }

  void updateEmail(String value) {
    _updateForm(
      state.form.copyWith(email: value),
      InstitutionUserCreateField.email,
    );
  }

  void updatePhone(String value) {
    _updateForm(
      state.form.copyWith(phone: value),
      InstitutionUserCreateField.phone,
    );
  }

  void clearPasswordError() {
    _updateForm(state.form, InstitutionUserCreateField.password);
  }

  Future<void> submit({required String password}) async {
    if (!state.canSubmit) {
      return;
    }

    final localErrors = state.form.validate(password: password);
    if (localErrors.isNotEmpty) {
      state = InstitutionUserCreateState.localValidationFailure(
        form: state.form,
        fieldErrors: localErrors,
        passwordWipeGeneration: _passwordWipeGeneration,
      );
      return;
    }

    final sessionKey = _activeSessionKey;
    if (sessionKey == null || !_matchesSession(sessionKey)) {
      return;
    }

    final request = state.form.toRequest(password: password);
    final snapshot = request.snapshot;
    final form = InstitutionUserCreateFormValue.fromSnapshot(snapshot);
    final generation = ++_operationGeneration;
    _activeSnapshot = snapshot;

    _markUserSummariesStale();
    state = InstitutionUserCreateState.submitting(
      form: form,
      passwordWipeGeneration: _passwordWipeGeneration,
    );

    try {
      final user = await ref
          .read(institutionUserCreateRepositoryProvider)
          .createUser(request);
      if (!_canPublish(generation, sessionKey, snapshot)) {
        return;
      }

      _activeSnapshot = null;
      _wipePassword();
      state = InstitutionUserCreateState.confirmedSuccess(
        userId: user.id,
        passwordWipeGeneration: _passwordWipeGeneration,
      );
    } on InstitutionUserCreateOutcomeUnknownException {
      if (!_canPublish(generation, sessionKey, snapshot)) {
        return;
      }

      _wipePassword();
      state = InstitutionUserCreateState.reconcilingUnknown(
        form: form,
        passwordWipeGeneration: _passwordWipeGeneration,
      );
      await _diagnoseUnknownOutcome(
        generation: generation,
        sessionKey: sessionKey,
        snapshot: snapshot,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, snapshot)) {
        return;
      }

      _activeSnapshot = null;
      _wipePassword();
      _publishDefiniteFailure(form, exception.failure);
    } catch (_) {
      if (!_canPublish(generation, sessionKey, snapshot)) {
        return;
      }

      _wipePassword();
      state = InstitutionUserCreateState.reconcilingUnknown(
        form: form,
        passwordWipeGeneration: _passwordWipeGeneration,
      );
      await _diagnoseUnknownOutcome(
        generation: generation,
        sessionKey: sessionKey,
        snapshot: snapshot,
      );
    }
  }

  void leaveRoute() {
    _clearSession();
    _wipePassword();
    state = InstitutionUserCreateState.editing(
      passwordWipeGeneration: _passwordWipeGeneration,
    );
  }

  Future<void> _diagnoseUnknownOutcome({
    required int generation,
    required InstitutionUserCreateSessionKey sessionKey,
    required InstitutionUserCreateSnapshot snapshot,
  }) async {
    var possibleMatch = false;
    try {
      final query = const InstitutionUserListQuery.initial().copyWith(
        role: snapshot.role,
        search: snapshot.loginName,
        page: 1,
        perPage: 100,
        sort: InstitutionUserListSort.loginName,
        direction: InstitutionUserSortDirection.asc,
      );
      final page = await ref
          .read(institutionUserListRepositoryProvider)
          .fetchUsers(query);
      if (!_canPublish(generation, sessionKey, snapshot)) {
        return;
      }
      possibleMatch = _isSingleExactMatch(page, snapshot);
    } catch (_) {
      if (!_canPublish(generation, sessionKey, snapshot)) {
        return;
      }
    }

    _activeSnapshot = null;
    state = InstitutionUserCreateState.unknown(
      form: InstitutionUserCreateFormValue.fromSnapshot(snapshot),
      possibleMatch: possibleMatch,
      passwordWipeGeneration: _passwordWipeGeneration,
    );
  }

  bool _isSingleExactMatch(
    InstitutionUserListPage page,
    InstitutionUserCreateSnapshot snapshot,
  ) {
    return page.pagination.page == 1 &&
        page.pagination.perPage == 100 &&
        page.pagination.total == 1 &&
        page.pagination.lastPage == 1 &&
        page.users.length == 1 &&
        snapshot.matches(page.users.single);
  }

  void _publishDefiniteFailure(
    InstitutionUserCreateFormValue form,
    ApiFailure failure,
  ) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired) {
      _clearSession();
      state = InstitutionUserCreateState.editing(
        passwordWipeGeneration: _passwordWipeGeneration,
      );
      return;
    }

    if (code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      _clearSession();
      state = InstitutionUserCreateState.editing(
        passwordWipeGeneration: _passwordWipeGeneration,
      );
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
      return;
    }

    if (failure.statusCode == 422 && code == ApiErrorCodes.validationFailed) {
      _publishValidationFailure(form, failure.fieldErrors);
      return;
    }

    final message = switch (code) {
      ApiErrorCodes.forbidden => 'You do not have permission to create users.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The user could not be created.',
    };
    state = InstitutionUserCreateState.definiteFailure(
      form: form,
      formError: message,
      passwordWipeGeneration: _passwordWipeGeneration,
    );
  }

  void _publishValidationFailure(
    InstitutionUserCreateFormValue form,
    Map<String, List<String>> serverErrors,
  ) {
    final errors = <InstitutionUserCreateField, String>{};
    var hasProtocolField = serverErrors.isEmpty;
    for (final key in serverErrors.keys) {
      final field = InstitutionUserCreateField.fromRequestKey(key);
      if (field == null) {
        hasProtocolField = true;
        continue;
      }
      errors[field] = _safeServerFieldMessage(field);
    }

    state = InstitutionUserCreateState.serverValidationFailure(
      form: form,
      fieldErrors: errors,
      formError: hasProtocolField ? 'The user could not be created.' : null,
      passwordWipeGeneration: _passwordWipeGeneration,
    );
  }

  String _safeServerFieldMessage(InstitutionUserCreateField field) {
    return switch (field) {
      InstitutionUserCreateField.role => 'Select a role.',
      InstitutionUserCreateField.fullName => 'Review the full name.',
      InstitutionUserCreateField.loginName =>
        'Review the login name; it may already be in use.',
      InstitutionUserCreateField.email => 'Review the email address.',
      InstitutionUserCreateField.phone => 'Review the phone number.',
      InstitutionUserCreateField.password =>
        'Re-enter a valid initial password.',
    };
  }

  void _updateForm(
    InstitutionUserCreateFormValue form,
    InstitutionUserCreateField field,
  ) {
    if (!state.canEdit) {
      return;
    }
    state = state.withForm(form, clearFieldError: field);
  }

  void _markUserSummariesStale() {
    if (ref.exists(institutionUserListControllerProvider)) {
      ref.read(institutionUserListControllerProvider.notifier).refresh();
    } else {
      ref.invalidate(institutionUserListControllerProvider);
    }

    if (ref.exists(institutionDashboardControllerProvider)) {
      unawaited(
        ref.read(institutionDashboardControllerProvider.notifier).refresh(),
      );
    } else {
      ref.invalidate(institutionDashboardControllerProvider);
    }
  }

  bool _canPublish(
    int generation,
    InstitutionUserCreateSessionKey sessionKey,
    InstitutionUserCreateSnapshot snapshot,
  ) {
    return ref.mounted &&
        generation == _operationGeneration &&
        _activeSnapshot == snapshot &&
        _activeSessionKey == sessionKey &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(InstitutionUserCreateSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        InstitutionUserCreateSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _invalidateOperation();
  }

  void _invalidateOperation() {
    _operationGeneration += 1;
    _activeSnapshot = null;
  }

  void _wipePassword() {
    _passwordWipeGeneration += 1;
  }
}

class InstitutionUserCreateSessionSnapshot {
  const InstitutionUserCreateSessionSnapshot({
    required this.status,
    required this.user,
    required this.surface,
  });

  factory InstitutionUserCreateSessionSnapshot.fromSession(
    AuthSessionState session,
    AppDeviceSurface surface,
  ) {
    return InstitutionUserCreateSessionSnapshot(
      status: session.status,
      user: session.user,
      surface: surface,
    );
  }

  final AuthSessionStatus status;
  final AuthUser? user;
  final AppDeviceSurface surface;

  InstitutionUserCreateSessionKey? get eligibleKey {
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
        surface != AppDeviceSurface.desktop) {
      return null;
    }

    return InstitutionUserCreateSessionKey(
      userId: currentUser.id,
      userInstance: currentUser,
      institutionId: institutionId,
    );
  }
}

class InstitutionUserCreateSessionKey {
  const InstitutionUserCreateSessionKey({
    required this.userId,
    required this.userInstance,
    required this.institutionId,
  });

  final String userId;
  final AuthUser userInstance;
  final String institutionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionUserCreateSessionKey &&
            other.userId == userId &&
            identical(other.userInstance, userInstance) &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode =>
      Object.hash(userId, identityHashCode(userInstance), institutionId);
}
