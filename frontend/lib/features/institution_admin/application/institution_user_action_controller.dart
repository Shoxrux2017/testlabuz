import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/institution_user_detail_repository_impl.dart';
import '../data/institution_user_mutation_repository_impl.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_mutation.dart';
import 'institution_user_action_state.dart';
import 'institution_user_detail_controller.dart';
import 'institution_user_detail_state.dart';
import 'institution_user_list_controller.dart';

final institutionUserActionControllerProvider = NotifierProvider.autoDispose
    .family<
      InstitutionUserActionController,
      InstitutionUserActionState,
      String
    >(InstitutionUserActionController.new);

class InstitutionUserActionController
    extends Notifier<InstitutionUserActionState> {
  InstitutionUserActionController(this.routeUserId);

  final String routeUserId;

  InstitutionUserDetailSessionKey? _activeSessionKey;
  InstitutionUser? _activeSelected;
  _InstitutionUserOperation? _operation;
  InstitutionUserActionFocusKey? _restorableFocusKey;
  int _operationGeneration = 0;

  @override
  InstitutionUserActionState build() {
    final key = InstitutionUserDetailSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(
      institutionUserDetailControllerProvider(routeUserId),
    );
    final confirmed = detail.status == InstitutionUserDetailStatus.data
        ? detail.user
        : null;
    if (key == null ||
        confirmed == null ||
        confirmed.id.toLowerCase() != routeUserId.toLowerCase()) {
      _clearOwnership();
      return InstitutionUserActionState.idle();
    }

    if (_activeSessionKey != key) {
      _clearOwnership();
      _activeSessionKey = key;
      _activeSelected = confirmed;
      return InstitutionUserActionState.idle();
    }

    if (_activeSelected != null && !identical(_activeSelected, confirmed)) {
      _invalidateOperation();
      _activeSelected = confirmed;
      return InstitutionUserActionState.idle();
    }
    _activeSelected ??= confirmed;
    return state;
  }

  bool beginEdit(InstitutionUser selected) {
    if (!_canBegin(selected)) {
      return false;
    }
    final generation = ++_operationGeneration;
    _activeSelected = selected;
    _operation = _InstitutionUserOperation.edit(
      sessionKey: _activeSessionKey!,
      routeUserId: routeUserId,
      selected: selected,
      generation: generation,
    );
    _restorableFocusKey = InstitutionUserActionFocusKey._fromOperation(
      _operation!,
    );
    state = InstitutionUserActionState.editing(
      selected: selected,
      form: InstitutionUserEditFormValue.fromUser(selected),
    );
    return true;
  }

  bool beginLifecycle(InstitutionUser selected) {
    if (!_canBegin(selected)) {
      return false;
    }
    final action = InstitutionUserLifecycleAction.forUser(selected);
    final generation = ++_operationGeneration;
    _activeSelected = selected;
    _operation = _InstitutionUserOperation.lifecycle(
      sessionKey: _activeSessionKey!,
      routeUserId: routeUserId,
      selected: selected,
      lifecycleAction: action,
      generation: generation,
    );
    _restorableFocusKey = InstitutionUserActionFocusKey._fromOperation(
      _operation!,
    );
    state = InstitutionUserActionState.lifecycle(
      selected: selected,
      action: action,
      status: InstitutionUserActionStatus.lifecycleConfirming,
    );
    return true;
  }

  void updateFullName(String value) => _updateEditForm(
    state.form?.copyWith(fullName: value),
    InstitutionUserEditField.fullName,
  );

  void updateEmail(String value) => _updateEditForm(
    state.form?.copyWith(email: value),
    InstitutionUserEditField.email,
  );

  void updatePhone(String value) => _updateEditForm(
    state.form?.copyWith(phone: value),
    InstitutionUserEditField.phone,
  );

  void dismiss() {
    if (state.isBusy) {
      return;
    }
    _invalidateOperation(clearFocusOwnership: false);
    state = InstitutionUserActionState.idle();
  }

  InstitutionUserActionFocusKey? get focusKey => _restorableFocusKey;

  bool canRestoreFocus(InstitutionUserActionFocusKey key) {
    final currentSession = InstitutionUserDetailSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.read(
      institutionUserDetailControllerProvider(key._routeUserId),
    );
    final hasValidKind = switch (key._kind) {
      _InstitutionUserOperationKind.edit => key._lifecycleAction == null,
      _InstitutionUserOperationKind.lifecycle => key._lifecycleAction != null,
    };
    return ref.mounted &&
        identical(_restorableFocusKey, key) &&
        key._generation > 0 &&
        key._generation <= _operationGeneration &&
        hasValidKind &&
        currentSession == key._sessionKey &&
        routeUserId == key._routeUserId &&
        detail.target?.toLowerCase() == key._routeUserId.toLowerCase() &&
        (detail.user == null ||
            detail.user!.id.toLowerCase() == key._selectedUserId.toLowerCase());
  }

  Future<void> submitEdit() async {
    final operation = _operation;
    final form = state.form;
    if (!state.isEditing ||
        operation == null ||
        operation.kind != _InstitutionUserOperationKind.edit ||
        form == null ||
        !_canPublish(operation)) {
      return;
    }
    final errors = form.validate();
    if (errors.isNotEmpty) {
      state = InstitutionUserActionState.editing(
        selected: operation.selected,
        form: form,
        fieldErrors: errors,
        status: InstitutionUserActionStatus.validationFailure,
      );
      return;
    }
    final request = form.changedFieldsComparedTo(operation.selected);
    if (request.isEmpty) {
      state = InstitutionUserActionState.editing(
        selected: operation.selected,
        form: form,
        formMessage: 'No user changes to save.',
      );
      return;
    }

    final submitted = operation.withEditRequest(request);
    _operation = submitted;
    _markUsersStale(submitted.sessionKey);
    state = InstitutionUserActionState.editing(
      selected: submitted.selected,
      form: form,
      status: InstitutionUserActionStatus.submitting,
    );
    try {
      final returned = await ref
          .read(institutionUserMutationRepositoryProvider)
          .updateUser(submitted.routeUserId, submitted.selected, request);
      if (!_canPublish(submitted)) {
        return;
      }
      _publishDirectSuccess(submitted, returned, 'User updated successfully.');
    } on InstitutionUserMutationOutcomeUnknownException {
      await _reconcile(submitted);
    } on ApiRequestException catch (exception) {
      if (_canPublish(submitted)) {
        _publishDefiniteFailure(submitted, exception.failure, form: form);
      }
    } catch (_) {
      await _reconcile(submitted);
    }
  }

  Future<void> confirmLifecycle() async {
    final operation = _operation;
    if (state.status != InstitutionUserActionStatus.lifecycleConfirming ||
        operation == null ||
        operation.lifecycleAction == null ||
        !_canPublish(operation)) {
      return;
    }
    final submitted = operation;
    _operation = submitted;
    _markUsersStale(submitted.sessionKey);
    state = InstitutionUserActionState.lifecycle(
      selected: submitted.selected,
      action: submitted.lifecycleAction!,
      status: InstitutionUserActionStatus.submitting,
    );
    try {
      final returned = await ref
          .read(institutionUserMutationRepositoryProvider)
          .changeLifecycle(
            submitted.routeUserId,
            submitted.selected,
            submitted.lifecycleAction!,
          );
      if (!_canPublish(submitted)) {
        return;
      }
      final message =
          submitted.lifecycleAction == InstitutionUserLifecycleAction.activate
          ? 'User activated successfully.'
          : 'User deactivated successfully.';
      _publishDirectSuccess(submitted, returned, message);
    } on InstitutionUserMutationOutcomeUnknownException {
      await _reconcile(submitted);
    } on ApiRequestException catch (exception) {
      if (_canPublish(submitted)) {
        _publishDefiniteFailure(submitted, exception.failure);
      }
    } catch (_) {
      await _reconcile(submitted);
    }
  }

  void _updateEditForm(
    InstitutionUserEditFormValue? form,
    InstitutionUserEditField field,
  ) {
    if (!state.isEditing || form == null) {
      return;
    }
    final errors = <InstitutionUserEditField, String>{...state.fieldErrors}
      ..remove(field);
    state = InstitutionUserActionState.editing(
      selected: state.selected!,
      form: form,
      fieldErrors: errors,
      status: errors.isEmpty
          ? InstitutionUserActionStatus.editing
          : InstitutionUserActionStatus.validationFailure,
    );
  }

  Future<void> _reconcile(_InstitutionUserOperation operation) async {
    if (!_canPublish(operation)) {
      return;
    }
    state = operation.kind == _InstitutionUserOperationKind.edit
        ? InstitutionUserActionState.editing(
            selected: operation.selected,
            form:
                state.form ??
                InstitutionUserEditFormValue.fromUser(operation.selected),
            formMessage:
                'The request result could not be confirmed. Checking the current server state…',
            status: InstitutionUserActionStatus.reconcilingCurrentState,
          )
        : InstitutionUserActionState.lifecycle(
            selected: operation.selected,
            action: operation.lifecycleAction!,
            formMessage:
                'The request result could not be confirmed. Checking the current server state…',
            status: InstitutionUserActionStatus.reconcilingCurrentState,
          );
    try {
      final current = await ref
          .read(institutionUserDetailRepositoryProvider)
          .fetchUser(operation.routeUserId);
      if (!_canPublish(operation)) {
        return;
      }
      final matches = operation.kind == _InstitutionUserOperationKind.edit
          ? operation.editRequest!.matches(current)
          : current.isActive == operation.lifecycleAction!.desiredActive;
      _activeSelected = current;
      final replaced = ref
          .read(
            institutionUserDetailControllerProvider(
              operation.routeUserId,
            ).notifier,
          )
          .replaceFromMutation(operation.selected, current);
      if (!replaced) {
        return;
      }
      _markUsersStale(operation.sessionKey);
      state = InstitutionUserActionState.feedback(
        status: InstitutionUserActionStatus.unconfirmedCurrentState,
        selected: current,
        lifecycleAction: operation.lifecycleAction,
        feedback: matches
            ? 'Current server state matches your requested values, but this request result could not be confirmed.'
            : 'Current server state differs from your requested values. The request result remains unconfirmed.',
      );
      _operation = null;
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_isNotFound(exception.failure)) {
        _publishNotFound(operation);
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _handleSessionFailure(exception.failure);
        _clearOwnership();
        state = InstitutionUserActionState.idle();
        return;
      }
      _handleSessionFailure(exception.failure);
      _markUsersStale(operation.sessionKey);
      state = InstitutionUserActionState.feedback(
        status: InstitutionUserActionStatus.unconfirmedCurrentState,
        feedback:
            'The request result could not be confirmed. Current server state is unavailable.',
      );
      _operation = null;
    } catch (_) {
      if (_canPublish(operation)) {
        _markUsersStale(operation.sessionKey);
        state = InstitutionUserActionState.feedback(
          status: InstitutionUserActionStatus.unconfirmedCurrentState,
          feedback:
              'The request result could not be confirmed. Current server state is unavailable.',
        );
        _operation = null;
      }
    }
  }

  void _publishDirectSuccess(
    _InstitutionUserOperation operation,
    InstitutionUser returned,
    String feedback,
  ) {
    _activeSelected = returned;
    final replaced = ref
        .read(
          institutionUserDetailControllerProvider(
            operation.routeUserId,
          ).notifier,
        )
        .replaceFromMutation(operation.selected, returned);
    if (!replaced) {
      return;
    }
    _markUsersStale(operation.sessionKey);
    state = InstitutionUserActionState.feedback(
      status: InstitutionUserActionStatus.confirmedDirectSuccess,
      selected: returned,
      lifecycleAction: operation.lifecycleAction,
      feedback: feedback,
    );
    _operation = null;
  }

  void _publishDefiniteFailure(
    _InstitutionUserOperation operation,
    ApiFailure failure, {
    InstitutionUserEditFormValue? form,
  }) {
    if (_isSessionFailure(failure)) {
      _handleSessionFailure(failure);
      _clearOwnership();
      state = InstitutionUserActionState.idle();
      return;
    }
    if (_isNotFound(failure)) {
      _publishNotFound(operation);
      return;
    }
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed &&
        operation.kind == _InstitutionUserOperationKind.edit) {
      final fieldErrors = <InstitutionUserEditField, String>{};
      var hasProtocolError = failure.fieldErrors.isEmpty;
      for (final key in failure.fieldErrors.keys) {
        final field = InstitutionUserEditField.fromRequestKey(key);
        if (field == null) {
          hasProtocolError = true;
        } else {
          fieldErrors[field] = switch (field) {
            InstitutionUserEditField.fullName => 'Review the full name.',
            InstitutionUserEditField.email => 'Review the email address.',
            InstitutionUserEditField.phone => 'Review the phone number.',
          };
        }
      }
      state = InstitutionUserActionState.editing(
        selected: operation.selected,
        form: form!,
        fieldErrors: fieldErrors,
        formMessage: hasProtocolError
            ? 'The update request did not match the server contract.'
            : null,
        status: InstitutionUserActionStatus.validationFailure,
      );
      return;
    }
    final message = switch (failure.serverCode) {
      ApiErrorCodes.forbidden =>
        'You do not have permission to change this user.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      ApiErrorCodes.validationFailed =>
        'The lifecycle request did not match the server contract.',
      _ => 'The user request was not accepted.',
    };
    if (operation.kind == _InstitutionUserOperationKind.edit) {
      state = InstitutionUserActionState.editing(
        selected: operation.selected,
        form: form!,
        formMessage: message,
        status: InstitutionUserActionStatus.definiteFailure,
      );
    } else {
      _operation = null;
      state = InstitutionUserActionState.feedback(
        status: InstitutionUserActionStatus.definiteFailure,
        selected: operation.selected,
        lifecycleAction: operation.lifecycleAction,
        feedback: message,
      );
    }
  }

  void _publishNotFound(_InstitutionUserOperation operation) {
    _markUsersStale(operation.sessionKey);
    ref
        .read(
          institutionUserDetailControllerProvider(
            operation.routeUserId,
          ).notifier,
        )
        .markNotFoundFromMutation(operation.selected);
    _operation = null;
    _activeSelected = null;
    _restorableFocusKey = InstitutionUserActionFocusKey._fromOperation(
      operation,
    );
    state = InstitutionUserActionState.feedback(
      status: InstitutionUserActionStatus.targetNotFound,
      feedback: 'This user is no longer available.',
    );
  }

  void _markUsersStale(InstitutionUserDetailSessionKey sessionKey) {
    final listKey = InstitutionUserListSessionKey(
      userId: sessionKey.userId,
      userInstance: sessionKey.userInstance,
      institutionId: sessionKey.institutionId,
    );
    ref.read(institutionUserListRetainedQueryProvider).markStale(listKey);
    ref.invalidate(institutionUserListControllerProvider);
  }

  bool _canBegin(InstitutionUser selected) {
    final key = _activeSessionKey;
    final detail = ref.read(
      institutionUserDetailControllerProvider(routeUserId),
    );
    return key != null &&
        _canBeginNewAction &&
        detail.status == InstitutionUserDetailStatus.data &&
        identical(detail.user, selected) &&
        selected.id.toLowerCase() == routeUserId.toLowerCase() &&
        _matchesSession(key);
  }

  bool get _canBeginNewAction => switch (state.status) {
    InstitutionUserActionStatus.idle ||
    InstitutionUserActionStatus.confirmedDirectSuccess ||
    InstitutionUserActionStatus.unconfirmedCurrentState => true,
    InstitutionUserActionStatus.definiteFailure when state.form == null => true,
    _ => false,
  };

  bool _canPublish(_InstitutionUserOperation operation) {
    return ref.mounted &&
        identical(_operation, operation) &&
        operation.generation == _operationGeneration &&
        identical(_activeSelected, operation.selected) &&
        _activeSessionKey == operation.sessionKey &&
        _matchesSession(operation.sessionKey);
  }

  bool _matchesSession(InstitutionUserDetailSessionKey key) {
    return ref.mounted &&
        InstitutionUserDetailSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key;
  }

  bool _isNotFound(ApiFailure failure) =>
      failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound;

  bool _isSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    return (failure.statusCode == 401 &&
            code == ApiErrorCodes.authenticationRequired) ||
        code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive;
  }

  void _handleSessionFailure(ApiFailure failure) {
    if (_isSessionFailure(failure)) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _activeSelected = null;
    _invalidateOperation();
  }

  void _invalidateOperation({bool clearFocusOwnership = true}) {
    _operationGeneration += 1;
    _operation = null;
    if (clearFocusOwnership) {
      _restorableFocusKey = null;
    }
  }
}

class InstitutionUserActionFocusKey {
  InstitutionUserActionFocusKey._fromOperation(
    _InstitutionUserOperation operation,
  ) : _sessionKey = operation.sessionKey,
      _routeUserId = operation.routeUserId,
      _selectedUserId = operation.selected.id,
      _kind = operation.kind,
      _lifecycleAction = operation.lifecycleAction,
      _generation = operation.generation;

  final InstitutionUserDetailSessionKey _sessionKey;
  final String _routeUserId;
  final String _selectedUserId;
  final _InstitutionUserOperationKind _kind;
  final InstitutionUserLifecycleAction? _lifecycleAction;
  final int _generation;
}

enum _InstitutionUserOperationKind { edit, lifecycle }

class _InstitutionUserOperation {
  const _InstitutionUserOperation._({
    required this.kind,
    required this.sessionKey,
    required this.routeUserId,
    required this.selected,
    required this.lifecycleAction,
    required this.editRequest,
    required this.generation,
  });

  factory _InstitutionUserOperation.edit({
    required InstitutionUserDetailSessionKey sessionKey,
    required String routeUserId,
    required InstitutionUser selected,
    required int generation,
  }) => _InstitutionUserOperation._(
    kind: _InstitutionUserOperationKind.edit,
    sessionKey: sessionKey,
    routeUserId: routeUserId,
    selected: selected,
    lifecycleAction: null,
    editRequest: null,
    generation: generation,
  );

  factory _InstitutionUserOperation.lifecycle({
    required InstitutionUserDetailSessionKey sessionKey,
    required String routeUserId,
    required InstitutionUser selected,
    required InstitutionUserLifecycleAction lifecycleAction,
    required int generation,
  }) => _InstitutionUserOperation._(
    kind: _InstitutionUserOperationKind.lifecycle,
    sessionKey: sessionKey,
    routeUserId: routeUserId,
    selected: selected,
    lifecycleAction: lifecycleAction,
    editRequest: null,
    generation: generation,
  );

  final _InstitutionUserOperationKind kind;
  final InstitutionUserDetailSessionKey sessionKey;
  final String routeUserId;
  final InstitutionUser selected;
  final InstitutionUserLifecycleAction? lifecycleAction;
  final InstitutionUserEditRequest? editRequest;
  final int generation;

  _InstitutionUserOperation withEditRequest(
    InstitutionUserEditRequest request,
  ) {
    return _InstitutionUserOperation._(
      kind: kind,
      sessionKey: sessionKey,
      routeUserId: routeUserId,
      selected: selected,
      lifecycleAction: lifecycleAction,
      editRequest: request,
      generation: generation,
    );
  }
}
