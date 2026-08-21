import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/institution_group_detail_repository_impl.dart';
import '../data/institution_group_mutation_repository_impl.dart';
import '../domain/institution_group.dart';
import '../domain/institution_group_mutation.dart';
import 'institution_group_action_state.dart';
import 'institution_group_detail_controller.dart';
import 'institution_group_detail_state.dart';
import 'institution_group_list_controller.dart';

final institutionGroupActionControllerProvider = NotifierProvider.autoDispose
    .family<
      InstitutionGroupActionController,
      InstitutionGroupActionState,
      String
    >(InstitutionGroupActionController.new);

class InstitutionGroupActionController
    extends Notifier<InstitutionGroupActionState> {
  InstitutionGroupActionController(this.routeGroupId);

  static const noChangesMessage = 'No group changes to save.';

  final String routeGroupId;

  InstitutionGroupDetailSessionKey? _activeSessionKey;
  InstitutionGroup? _activeSelected;
  _InstitutionGroupOperation? _operation;
  InstitutionGroupActionFocusKey? _restorableFocusKey;
  int _operationGeneration = 0;

  @override
  InstitutionGroupActionState build() {
    final key = InstitutionGroupDetailSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(
      institutionGroupDetailControllerProvider(routeGroupId),
    );
    final confirmed = detail.status == InstitutionGroupDetailStatus.data
        ? detail.group
        : null;

    if (key == null) {
      _clearOwnership();
      return InstitutionGroupActionState.idle();
    }
    if (confirmed == null) {
      if (_activeSessionKey == key &&
          detail.target?.toLowerCase() == routeGroupId.toLowerCase() &&
          _retainsTerminalFeedbackWithoutGroup) {
        _activeSelected = null;
        _operation = null;
        return state;
      }
      _clearOwnership();
      return InstitutionGroupActionState.idle();
    }
    if (confirmed.id.toLowerCase() != routeGroupId.toLowerCase()) {
      _clearOwnership();
      return InstitutionGroupActionState.idle();
    }

    if (_activeSessionKey != key) {
      _clearOwnership();
      _activeSessionKey = key;
      _activeSelected = confirmed;
      return InstitutionGroupActionState.idle();
    }

    if (_activeSelected != null && !identical(_activeSelected, confirmed)) {
      _invalidateOperation();
      _activeSelected = confirmed;
      return InstitutionGroupActionState.idle();
    }
    _activeSelected ??= confirmed;
    return state;
  }

  bool beginEdit(InstitutionGroup selected) {
    if (!_canBegin(selected)) {
      return false;
    }
    final operation = _InstitutionGroupOperation(
      kind: InstitutionGroupActionKind.edit,
      sessionKey: _activeSessionKey!,
      routeGroupId: routeGroupId,
      selected: selected,
      editRequest: null,
      generation: ++_operationGeneration,
    );
    _activeSelected = selected;
    _operation = operation;
    _restorableFocusKey = InstitutionGroupActionFocusKey._fromOperation(
      operation,
    );
    state = InstitutionGroupActionState.editing(
      selected: selected,
      form: InstitutionGroupEditFormValue.fromGroup(selected),
    );
    return true;
  }

  bool beginArchive(InstitutionGroup selected) {
    if (!_canBegin(selected)) {
      return false;
    }
    final operation = _InstitutionGroupOperation(
      kind: InstitutionGroupActionKind.archive,
      sessionKey: _activeSessionKey!,
      routeGroupId: routeGroupId,
      selected: selected,
      editRequest: null,
      generation: ++_operationGeneration,
    );
    _activeSelected = selected;
    _operation = operation;
    _restorableFocusKey = InstitutionGroupActionFocusKey._fromOperation(
      operation,
    );
    state = InstitutionGroupActionState.archive(
      selected: selected,
      status: InstitutionGroupActionStatus.archiveConfirming,
    );
    return true;
  }

  void updateName(String value) => _updateEditForm(
    state.form?.copyWith(name: value),
    InstitutionGroupEditField.name,
  );

  void updateLevel(String value) => _updateEditForm(
    state.form?.copyWith(level: value),
    InstitutionGroupEditField.level,
  );

  void updateSubjectDirection(String value) => _updateEditForm(
    state.form?.copyWith(subjectDirection: value),
    InstitutionGroupEditField.subjectDirection,
  );

  void updateDescription(String value) => _updateEditForm(
    state.form?.copyWith(description: value),
    InstitutionGroupEditField.description,
  );

  void dismiss() {
    if (state.isBusy) {
      return;
    }
    _invalidateOperation(clearFocusOwnership: false);
    state = InstitutionGroupActionState.idle();
  }

  InstitutionGroupActionFocusKey? get focusKey => _restorableFocusKey;

  bool canRestoreFocus(InstitutionGroupActionFocusKey key) {
    final currentSession = InstitutionGroupDetailSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.read(
      institutionGroupDetailControllerProvider(key._routeGroupId),
    );
    final current = detail.group;
    if (!ref.mounted ||
        !identical(_restorableFocusKey, key) ||
        currentSession != key._sessionKey ||
        routeGroupId != key._routeGroupId ||
        detail.status != InstitutionGroupDetailStatus.data ||
        current == null ||
        current.status != InstitutionGroupStatus.active ||
        current.id.toLowerCase() != key._selectedGroupId.toLowerCase() ||
        current.createdAt != key._selectedCreatedAt) {
      return false;
    }

    if (identical(current, key._selectedInstance)) {
      return true;
    }
    return key._kind == InstitutionGroupActionKind.edit &&
        state.status == InstitutionGroupActionStatus.confirmedDirectSuccess;
  }

  Future<void> submitEdit() async {
    final operation = _operation;
    final form = state.form;
    if (!state.isEditing ||
        state.isBusy ||
        operation == null ||
        operation.kind != InstitutionGroupActionKind.edit ||
        form == null ||
        !_canPublish(operation)) {
      return;
    }

    final errors = form.validate();
    if (errors.isNotEmpty) {
      state = InstitutionGroupActionState.editing(
        selected: operation.selected,
        form: form,
        fieldErrors: errors,
        status: InstitutionGroupActionStatus.validationFailure,
      );
      return;
    }

    final request = form.changedFieldsComparedTo(operation.selected);
    if (request.isEmpty) {
      state = InstitutionGroupActionState.editing(
        selected: operation.selected,
        form: form,
        formMessage: noChangesMessage,
      );
      return;
    }

    final submitted = operation.withEditRequest(request);
    _operation = submitted;
    state = InstitutionGroupActionState.editing(
      selected: submitted.selected,
      form: form,
      status: InstitutionGroupActionStatus.submitting,
    );
    try {
      final returned = await ref
          .read(institutionGroupMutationRepositoryProvider)
          .updateGroup(submitted.routeGroupId, submitted.selected, request);
      if (_canPublish(submitted)) {
        _publishDirectSuccess(
          submitted,
          returned,
          'Group updated successfully.',
        );
      }
    } on InstitutionGroupMutationOutcomeUnknownException {
      await _reconcile(submitted, _ReconciliationReason.unknownUpdate);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(submitted)) {
        return;
      }
      if (_isBusinessConflict(exception.failure)) {
        await _reconcile(submitted, _ReconciliationReason.updateConflict);
      } else {
        _publishDefiniteFailure(submitted, exception.failure, form: form);
      }
    } catch (_) {
      await _reconcile(submitted, _ReconciliationReason.unknownUpdate);
    }
  }

  Future<void> confirmArchive() async {
    final operation = _operation;
    if (state.status != InstitutionGroupActionStatus.archiveConfirming ||
        operation == null ||
        operation.kind != InstitutionGroupActionKind.archive ||
        !_canPublish(operation)) {
      return;
    }

    state = InstitutionGroupActionState.archive(
      selected: operation.selected,
      status: InstitutionGroupActionStatus.submitting,
    );
    try {
      final returned = await ref
          .read(institutionGroupMutationRepositoryProvider)
          .archiveGroup(operation.routeGroupId, operation.selected);
      if (_canPublish(operation)) {
        _publishDirectSuccess(
          operation,
          returned,
          'Group archived successfully.',
        );
      }
    } on InstitutionGroupMutationOutcomeUnknownException {
      await _reconcile(operation, _ReconciliationReason.unknownArchive);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_isBusinessConflict(exception.failure)) {
        await _reconcile(operation, _ReconciliationReason.archiveConflict);
      } else {
        _publishDefiniteFailure(operation, exception.failure);
      }
    } catch (_) {
      await _reconcile(operation, _ReconciliationReason.unknownArchive);
    }
  }

  void _updateEditForm(
    InstitutionGroupEditFormValue? form,
    InstitutionGroupEditField field,
  ) {
    if (!state.isEditing || state.isBusy || form == null) {
      return;
    }
    final errors = <InstitutionGroupEditField, String>{...state.fieldErrors}
      ..remove(field);
    state = InstitutionGroupActionState.editing(
      selected: state.selected!,
      form: form,
      fieldErrors: errors,
      formMessage: state.formMessage == noChangesMessage
          ? null
          : state.formMessage,
      status: errors.isEmpty
          ? InstitutionGroupActionStatus.editing
          : InstitutionGroupActionStatus.validationFailure,
    );
  }

  Future<void> _reconcile(
    _InstitutionGroupOperation operation,
    _ReconciliationReason reason,
  ) async {
    if (!_canPublish(operation)) {
      return;
    }
    _markGroupListStale(operation.sessionKey);
    final checkingMessage = reason.isConflict
        ? 'Checking current server state'
        : 'The request result could not be confirmed. Checking the current server state…';
    state = operation.kind == InstitutionGroupActionKind.edit
        ? InstitutionGroupActionState.editing(
            selected: operation.selected,
            form:
                state.form ??
                InstitutionGroupEditFormValue.fromGroup(operation.selected),
            formMessage: checkingMessage,
            status: InstitutionGroupActionStatus.reconcilingCurrentState,
          )
        : InstitutionGroupActionState.archive(
            selected: operation.selected,
            formMessage: checkingMessage,
            status: InstitutionGroupActionStatus.reconcilingCurrentState,
          );

    try {
      final current = await ref
          .read(institutionGroupDetailRepositoryProvider)
          .fetchGroup(operation.routeGroupId);
      if (!_canPublish(operation)) {
        return;
      }
      _activeSelected = current;
      final replaced = ref
          .read(
            institutionGroupDetailControllerProvider(
              operation.routeGroupId,
            ).notifier,
          )
          .replaceFromMutation(operation.selected, current);
      if (!replaced) {
        return;
      }
      state = InstitutionGroupActionState.feedback(
        status: InstitutionGroupActionStatus.unconfirmedCurrentState,
        selected: current,
        kind: operation.kind,
        feedback: _reconciliationFeedback(reason, operation, current),
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
        _publishSessionFailure(operation, exception.failure);
        return;
      }
      _publishReconciliationError(operation, reason, exception.failure);
    } catch (_) {
      if (_canPublish(operation)) {
        _publishReconciliationError(
          operation,
          reason,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Institution Group current state is unavailable.',
          ),
        );
      }
    }
  }

  String _reconciliationFeedback(
    _ReconciliationReason reason,
    _InstitutionGroupOperation operation,
    InstitutionGroup current,
  ) {
    return switch (reason) {
      _ReconciliationReason.updateConflict =>
        current.status == InstitutionGroupStatus.archived
            ? 'Group is archived and can no longer be edited.'
            : 'The group update was not accepted in its current state.',
      _ReconciliationReason.unknownUpdate =>
        operation.editRequest!.matches(current)
            ? 'Current server state includes your requested values, but the update result could not be confirmed.'
            : 'Current server state differs from your requested values. The update result remains unconfirmed.',
      _ReconciliationReason.archiveConflict =>
        current.status == InstitutionGroupStatus.archived
            ? 'The group is currently archived.'
            : 'The archive request was not accepted in its current state.',
      _ReconciliationReason.unknownArchive =>
        current.status == InstitutionGroupStatus.archived
            ? 'The group is currently archived, but this archive request result could not be confirmed.'
            : 'The group is still active. The archive request result could not be confirmed.',
    };
  }

  void _publishDirectSuccess(
    _InstitutionGroupOperation operation,
    InstitutionGroup returned,
    String feedback,
  ) {
    _markGroupListStale(operation.sessionKey);
    _activeSelected = returned;
    final replaced = ref
        .read(
          institutionGroupDetailControllerProvider(
            operation.routeGroupId,
          ).notifier,
        )
        .replaceFromMutation(operation.selected, returned);
    if (!replaced) {
      return;
    }
    state = InstitutionGroupActionState.feedback(
      status: InstitutionGroupActionStatus.confirmedDirectSuccess,
      selected: returned,
      kind: operation.kind,
      feedback: feedback,
    );
    _operation = null;
  }

  void _publishDefiniteFailure(
    _InstitutionGroupOperation operation,
    ApiFailure failure, {
    InstitutionGroupEditFormValue? form,
  }) {
    if (_isSessionFailure(failure)) {
      _publishSessionFailure(operation, failure);
      return;
    }
    if (_isNotFound(failure)) {
      _publishNotFound(operation);
      return;
    }
    if (operation.kind == InstitutionGroupActionKind.edit &&
        failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      final fieldErrors = <InstitutionGroupEditField, String>{};
      var hasProtocolError = failure.fieldErrors.isEmpty;
      for (final key in failure.fieldErrors.keys) {
        final field = InstitutionGroupEditField.fromRequestKey(key);
        if (field == null) {
          hasProtocolError = true;
        } else {
          fieldErrors[field] = switch (field) {
            InstitutionGroupEditField.name => 'Review the group name.',
            InstitutionGroupEditField.level => 'Review the level.',
            InstitutionGroupEditField.subjectDirection =>
              'Review the subject direction.',
            InstitutionGroupEditField.description => 'Review the description.',
          };
        }
      }
      state = InstitutionGroupActionState.editing(
        selected: operation.selected,
        form: form!,
        fieldErrors: fieldErrors,
        formMessage: hasProtocolError
            ? 'The update request did not match the server contract.'
            : null,
        status: InstitutionGroupActionStatus.validationFailure,
      );
      return;
    }

    if (operation.kind == InstitutionGroupActionKind.edit) {
      final message = switch (failure.serverCode) {
        ApiErrorCodes.forbidden =>
          'You do not have permission to change this group.',
        ApiErrorCodes.rateLimited =>
          'Too many requests. Wait before trying again.',
        _ => 'The group update was not accepted.',
      };
      state = InstitutionGroupActionState.editing(
        selected: operation.selected,
        form: form!,
        formMessage: message,
        status: InstitutionGroupActionStatus.definiteFailure,
      );
      return;
    }

    final message = switch (failure.serverCode) {
      ApiErrorCodes.forbidden =>
        'You do not have permission to archive this group.',
      ApiErrorCodes.validationFailed =>
        'The archive request did not match the server contract.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The archive request was not accepted.',
    };
    _operation = null;
    state = InstitutionGroupActionState.feedback(
      status: InstitutionGroupActionStatus.definiteFailure,
      selected: operation.selected,
      kind: InstitutionGroupActionKind.archive,
      feedback: message,
    );
  }

  void _publishNotFound(_InstitutionGroupOperation operation) {
    _markGroupListStale(operation.sessionKey);
    final changed = ref
        .read(
          institutionGroupDetailControllerProvider(
            operation.routeGroupId,
          ).notifier,
        )
        .markNotFoundFromMutation(operation.selected);
    if (!changed) {
      return;
    }
    _operation = null;
    _activeSelected = null;
    _restorableFocusKey = null;
    state = InstitutionGroupActionState.idle();
  }

  void _publishSessionFailure(
    _InstitutionGroupOperation operation,
    ApiFailure failure,
  ) {
    ref
        .read(
          institutionGroupDetailControllerProvider(
            operation.routeGroupId,
          ).notifier,
        )
        .clearForMutationSessionFailure(operation.selected);
    if (_isSessionFailure(failure)) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    _clearOwnership();
    state = InstitutionGroupActionState.idle();
  }

  void _publishReconciliationError(
    _InstitutionGroupOperation operation,
    _ReconciliationReason reason,
    ApiFailure failure,
  ) {
    final changed = ref
        .read(
          institutionGroupDetailControllerProvider(
            operation.routeGroupId,
          ).notifier,
        )
        .markErrorFromMutation(operation.selected, failure);
    if (!changed) {
      return;
    }
    _operation = null;
    _activeSelected = null;
    final message = switch (reason) {
      _ReconciliationReason.updateConflict =>
        'The group update was not accepted. Current server state is unavailable.',
      _ReconciliationReason.unknownUpdate =>
        'The update result could not be confirmed. Current server state is unavailable.',
      _ReconciliationReason.archiveConflict =>
        'The archive request was not accepted. Current server state is unavailable.',
      _ReconciliationReason.unknownArchive =>
        'The archive result could not be confirmed. Current server state is unavailable.',
    };
    state = InstitutionGroupActionState.feedback(
      status: InstitutionGroupActionStatus.unconfirmedCurrentState,
      kind: operation.kind,
      feedback: message,
    );
  }

  void _markGroupListStale(InstitutionGroupDetailSessionKey sessionKey) {
    final listKey = InstitutionGroupListSessionKey(
      userId: sessionKey.userId,
      userInstance: sessionKey.userInstance,
      institutionId: sessionKey.institutionId,
    );
    ref
        .read(institutionGroupListRetainedQueryProvider)
        .markAuthoritativeRowsStale(listKey);
    if (ref.exists(institutionGroupListControllerProvider)) {
      ref.invalidate(institutionGroupListControllerProvider);
    }
  }

  bool _canBegin(InstitutionGroup selected) {
    final key = _activeSessionKey;
    final detail = ref.read(
      institutionGroupDetailControllerProvider(routeGroupId),
    );
    return key != null &&
        _canBeginNewAction &&
        detail.status == InstitutionGroupDetailStatus.data &&
        identical(detail.group, selected) &&
        selected.id.toLowerCase() == routeGroupId.toLowerCase() &&
        selected.status == InstitutionGroupStatus.active &&
        _matchesSession(key);
  }

  bool get _canBeginNewAction => switch (state.status) {
    InstitutionGroupActionStatus.idle ||
    InstitutionGroupActionStatus.confirmedDirectSuccess ||
    InstitutionGroupActionStatus.unconfirmedCurrentState => true,
    InstitutionGroupActionStatus.definiteFailure when state.form == null =>
      true,
    _ => false,
  };

  bool get _retainsTerminalFeedbackWithoutGroup =>
      state.selected == null &&
      state.status == InstitutionGroupActionStatus.unconfirmedCurrentState;

  bool _canPublish(_InstitutionGroupOperation operation) {
    if (!ref.mounted) {
      return false;
    }
    final detail = ref.read(
      institutionGroupDetailControllerProvider(operation.routeGroupId),
    );
    return identical(_operation, operation) &&
        operation.generation == _operationGeneration &&
        identical(_activeSelected, operation.selected) &&
        _activeSessionKey == operation.sessionKey &&
        detail.status == InstitutionGroupDetailStatus.data &&
        detail.target?.toLowerCase() == operation.routeGroupId.toLowerCase() &&
        identical(detail.group, operation.selected) &&
        _matchesSession(operation.sessionKey);
  }

  bool _matchesSession(InstitutionGroupDetailSessionKey key) {
    return ref.mounted &&
        InstitutionGroupDetailSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key;
  }

  bool _isNotFound(ApiFailure failure) =>
      failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound;

  bool _isBusinessConflict(ApiFailure failure) =>
      failure.statusCode == 409 &&
      failure.serverCode == ApiErrorCodes.businessConflict;

  bool _isSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    return (failure.statusCode == 401 &&
            code == ApiErrorCodes.authenticationRequired) ||
        (failure.statusCode == 403 &&
            (code == ApiErrorCodes.passwordChangeRequired ||
                code == ApiErrorCodes.userInactive ||
                code == ApiErrorCodes.institutionInactive));
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

class InstitutionGroupActionFocusKey {
  InstitutionGroupActionFocusKey._fromOperation(
    _InstitutionGroupOperation operation,
  ) : _sessionKey = operation.sessionKey,
      _routeGroupId = operation.routeGroupId,
      _selectedGroupId = operation.selected.id,
      _selectedCreatedAt = operation.selected.createdAt,
      _selectedInstance = operation.selected,
      _kind = operation.kind;

  final InstitutionGroupDetailSessionKey _sessionKey;
  final String _routeGroupId;
  final String _selectedGroupId;
  final DateTime _selectedCreatedAt;
  final InstitutionGroup _selectedInstance;
  final InstitutionGroupActionKind _kind;
}

class _InstitutionGroupOperation {
  const _InstitutionGroupOperation({
    required this.kind,
    required this.sessionKey,
    required this.routeGroupId,
    required this.selected,
    required this.editRequest,
    required this.generation,
  });

  final InstitutionGroupActionKind kind;
  final InstitutionGroupDetailSessionKey sessionKey;
  final String routeGroupId;
  final InstitutionGroup selected;
  final InstitutionGroupEditRequest? editRequest;
  final int generation;

  _InstitutionGroupOperation withEditRequest(
    InstitutionGroupEditRequest request,
  ) {
    return _InstitutionGroupOperation(
      kind: kind,
      sessionKey: sessionKey,
      routeGroupId: routeGroupId,
      selected: selected,
      editRequest: request,
      generation: generation,
    );
  }
}

enum _ReconciliationReason {
  updateConflict,
  unknownUpdate,
  archiveConflict,
  unknownArchive;

  bool get isConflict => this == updateConflict || this == archiveConflict;
}
