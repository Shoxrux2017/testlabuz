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
import '../data/institution_group_create_repository_impl.dart';
import '../domain/institution_group_create.dart';
import 'institution_group_create_state.dart';
import 'institution_group_list_controller.dart';

final institutionGroupCreateControllerProvider =
    NotifierProvider.autoDispose<
      InstitutionGroupCreateController,
      InstitutionGroupCreateState
    >(InstitutionGroupCreateController.new);

class InstitutionGroupCreateController
    extends Notifier<InstitutionGroupCreateState> {
  InstitutionGroupCreateSessionKey? _activeSessionKey;
  InstitutionGroupCreateSnapshot? _activeSnapshot;
  int _operationGeneration = 0;
  int _routeGeneration = 0;
  var _ownsCreateRoute = false;

  @override
  InstitutionGroupCreateState build() {
    final sessionKey = InstitutionGroupCreateSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      _clearSession();
      return const InstitutionGroupCreateState.editing();
    }

    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _invalidateOperation();
    _activeSessionKey = sessionKey;

    return const InstitutionGroupCreateState.editing();
  }

  void enterRoute() {
    if (_ownsCreateRoute) {
      return;
    }
    _ownsCreateRoute = true;
    _routeGeneration += 1;
  }

  void updateName(String value) {
    _updateForm(
      state.form.copyWith(name: value),
      InstitutionGroupCreateField.name,
    );
  }

  void updateLevel(String value) {
    _updateForm(
      state.form.copyWith(level: value),
      InstitutionGroupCreateField.level,
    );
  }

  void updateSubjectDirection(String value) {
    _updateForm(
      state.form.copyWith(subjectDirection: value),
      InstitutionGroupCreateField.subjectDirection,
    );
  }

  void updateDescription(String value) {
    _updateForm(
      state.form.copyWith(description: value),
      InstitutionGroupCreateField.description,
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit || !_ownsCreateRoute) {
      return;
    }

    final localErrors = state.form.validate();
    if (localErrors.isNotEmpty) {
      state = InstitutionGroupCreateState.localValidationFailure(
        form: state.form,
        fieldErrors: localErrors,
      );
      return;
    }

    final sessionKey = _activeSessionKey;
    if (sessionKey == null || !_matchesSession(sessionKey)) {
      return;
    }

    final request = state.form.toRequest();
    final snapshot = request.snapshot;
    final form = InstitutionGroupCreateFormValue.fromSnapshot(snapshot);
    final generation = ++_operationGeneration;
    final routeGeneration = _routeGeneration;
    _activeSnapshot = snapshot;
    state = InstitutionGroupCreateState.submitting(form: form);

    try {
      final group = await ref
          .read(institutionGroupCreateRepositoryProvider)
          .createGroup(request);
      if (!_canPublish(generation, routeGeneration, sessionKey, snapshot)) {
        return;
      }

      _activeSnapshot = null;
      _markGroupListStale(sessionKey);
      state = InstitutionGroupCreateState.confirmedSuccess(groupId: group.id);
    } on InstitutionGroupCreateOutcomeUnknownException {
      await _publishUnknown(
        generation: generation,
        routeGeneration: routeGeneration,
        sessionKey: sessionKey,
        snapshot: snapshot,
        form: form,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, routeGeneration, sessionKey, snapshot)) {
        return;
      }

      _activeSnapshot = null;
      _publishDefiniteFailure(form, exception.failure);
    } catch (_) {
      await _publishUnknown(
        generation: generation,
        routeGeneration: routeGeneration,
        sessionKey: sessionKey,
        snapshot: snapshot,
        form: form,
      );
    }
  }

  bool reviewRecentGroups() {
    final sessionKey = _activeSessionKey;
    if (state.status != InstitutionGroupCreateStatus.unknown ||
        !_ownsCreateRoute ||
        sessionKey == null ||
        !_matchesSession(sessionKey)) {
      return false;
    }

    ref
        .read(institutionGroupListRetainedQueryProvider)
        .prepareUnknownCreateRecovery(sessionKey.toGroupListKey());
    if (ref.exists(institutionGroupListControllerProvider)) {
      ref.invalidate(institutionGroupListControllerProvider);
    }
    leaveRoute();
    return true;
  }

  void leaveRoute() {
    _ownsCreateRoute = false;
    _routeGeneration += 1;
    _invalidateOperation();
    state = const InstitutionGroupCreateState.editing();
  }

  Future<void> _publishUnknown({
    required int generation,
    required int routeGeneration,
    required InstitutionGroupCreateSessionKey sessionKey,
    required InstitutionGroupCreateSnapshot snapshot,
    required InstitutionGroupCreateFormValue form,
  }) async {
    if (!_canPublish(generation, routeGeneration, sessionKey, snapshot)) {
      return;
    }

    state = InstitutionGroupCreateState.reconcilingUnknown(form: form);
    await Future<void>.value();
    if (!_canPublish(generation, routeGeneration, sessionKey, snapshot)) {
      return;
    }

    _activeSnapshot = null;
    state = InstitutionGroupCreateState.unknown(form: form);
  }

  void _publishDefiniteFailure(
    InstitutionGroupCreateFormValue form,
    ApiFailure failure,
  ) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired) {
      _clearSession();
      state = const InstitutionGroupCreateState.editing();
      return;
    }

    if (code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      _clearSession();
      state = const InstitutionGroupCreateState.editing();
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
      return;
    }

    if (failure.statusCode == 422 && code == ApiErrorCodes.validationFailed) {
      _publishValidationFailure(form, failure.fieldErrors);
      return;
    }

    final message = switch (code) {
      ApiErrorCodes.forbidden => 'You do not have permission to create groups.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The group could not be created.',
    };
    state = InstitutionGroupCreateState.definiteFailure(
      form: form,
      formError: message,
    );
  }

  void _publishValidationFailure(
    InstitutionGroupCreateFormValue form,
    Map<String, List<String>> serverErrors,
  ) {
    final errors = <InstitutionGroupCreateField, String>{};
    var hasProtocolField = serverErrors.isEmpty;
    for (final key in serverErrors.keys) {
      final field = InstitutionGroupCreateField.fromRequestKey(key);
      if (field == null) {
        hasProtocolField = true;
        continue;
      }
      errors[field] = switch (field) {
        InstitutionGroupCreateField.name => 'Review the group name.',
        InstitutionGroupCreateField.level => 'Review the level.',
        InstitutionGroupCreateField.subjectDirection =>
          'Review the subject direction.',
        InstitutionGroupCreateField.description => 'Review the description.',
      };
    }

    state = InstitutionGroupCreateState.serverValidationFailure(
      form: form,
      fieldErrors: errors,
      formError: hasProtocolField ? 'The group could not be created.' : null,
    );
  }

  void _updateForm(
    InstitutionGroupCreateFormValue form,
    InstitutionGroupCreateField field,
  ) {
    if (!state.canEdit || !_ownsCreateRoute) {
      return;
    }
    state = state.withForm(form, clearFieldError: field);
  }

  void _markGroupListStale(InstitutionGroupCreateSessionKey sessionKey) {
    ref
        .read(institutionGroupListRetainedQueryProvider)
        .markAuthoritativeRowsStale(sessionKey.toGroupListKey());
    if (ref.exists(institutionGroupListControllerProvider)) {
      ref.invalidate(institutionGroupListControllerProvider);
    }
  }

  bool _canPublish(
    int generation,
    int routeGeneration,
    InstitutionGroupCreateSessionKey sessionKey,
    InstitutionGroupCreateSnapshot snapshot,
  ) {
    return ref.mounted &&
        _ownsCreateRoute &&
        routeGeneration == _routeGeneration &&
        generation == _operationGeneration &&
        _activeSnapshot == snapshot &&
        _activeSessionKey == sessionKey &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(InstitutionGroupCreateSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        InstitutionGroupCreateSessionSnapshot.fromSession(
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
}

class InstitutionGroupCreateSessionSnapshot {
  const InstitutionGroupCreateSessionSnapshot({
    required this.status,
    required this.user,
    required this.surface,
  });

  factory InstitutionGroupCreateSessionSnapshot.fromSession(
    AuthSessionState session,
    AppDeviceSurface surface,
  ) {
    return InstitutionGroupCreateSessionSnapshot(
      status: session.status,
      user: session.user,
      surface: surface,
    );
  }

  final AuthSessionStatus status;
  final AuthUser? user;
  final AppDeviceSurface surface;

  InstitutionGroupCreateSessionKey? get eligibleKey {
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

    return InstitutionGroupCreateSessionKey(
      userId: currentUser.id,
      userInstance: currentUser,
      institutionId: institutionId,
    );
  }
}

class InstitutionGroupCreateSessionKey {
  const InstitutionGroupCreateSessionKey({
    required this.userId,
    required this.userInstance,
    required this.institutionId,
  });

  final String userId;
  final AuthUser userInstance;
  final String institutionId;

  InstitutionGroupListSessionKey toGroupListKey() {
    return InstitutionGroupListSessionKey(
      userId: userId,
      userInstance: userInstance,
      institutionId: institutionId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionGroupCreateSessionKey &&
            other.userId == userId &&
            identical(other.userInstance, userInstance) &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode =>
      Object.hash(userId, identityHashCode(userInstance), institutionId);
}
