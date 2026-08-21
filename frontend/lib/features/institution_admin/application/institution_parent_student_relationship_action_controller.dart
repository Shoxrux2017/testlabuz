import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/institution_parent_student_relationship_repository_impl.dart';
import '../domain/institution_parent_student_relationship.dart';
import '../domain/institution_parent_student_relationship_mutation.dart';
import '../domain/institution_parent_student_relationship_query.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_selection.dart';
import 'institution_parent_student_relationship_action_state.dart';
import 'institution_parent_student_relationship_list_controller.dart';
import 'institution_parent_student_relationship_list_state.dart';
import 'institution_user_selection_controller.dart';

final institutionParentStudentRelationshipActionControllerProvider =
    NotifierProvider.autoDispose<
      InstitutionParentStudentRelationshipActionController,
      InstitutionParentStudentRelationshipActionState
    >(InstitutionParentStudentRelationshipActionController.new);

class InstitutionParentStudentRelationshipActionController
    extends Notifier<InstitutionParentStudentRelationshipActionState> {
  InstitutionParentStudentSessionKey? _activeSessionKey;
  _ParentStudentOperation? _operation;
  InstitutionParentStudentRelationshipActionFocusKey? _focusKey;
  int _operationGeneration = 0;

  @override
  InstitutionParentStudentRelationshipActionState build() {
    final byParent = ref.watch(
      institutionParentStudentRelationshipListControllerProvider(
        InstitutionParentStudentPerspective.byParent,
      ),
    );
    final byStudent = ref.watch(
      institutionParentStudentRelationshipListControllerProvider(
        InstitutionParentStudentPerspective.byStudent,
      ),
    );
    ref.watch(
      institutionUserSelectionControllerProvider(
        InstitutionUserSelectionPurpose.activeParent,
      ),
    );
    ref.watch(
      institutionUserSelectionControllerProvider(
        InstitutionUserSelectionPurpose.activeStudent,
      ),
    );
    final sessionKey = InstitutionParentStudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      _activeSessionKey = null;
      _invalidateOperation();
      return const InstitutionParentStudentRelationshipActionState.idle();
    }
    if (_activeSessionKey == sessionKey) {
      final operation = _operation;
      if (operation?.kind == _ParentStudentOperationKind.disconnect &&
          state.isDisconnectDialog) {
        final identity = operation!.identity!;
        final listState =
            identity.perspective == InstitutionParentStudentPerspective.byParent
            ? byParent
            : byStudent;
        if (!_listStateOwnsIdentity(listState, identity)) {
          _operation = null;
          return const InstitutionParentStudentRelationshipActionState.idle();
        }
      }
      return state;
    }
    _invalidateOperation();
    _activeSessionKey = sessionKey;
    return const InstitutionParentStudentRelationshipActionState.idle();
  }

  bool beginConnect() {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        state.hasOpenAction ||
        !_matchesSession(sessionKey)) {
      return false;
    }
    final parentController = ref.read(
      institutionUserSelectionControllerProvider(
        InstitutionUserSelectionPurpose.activeParent,
      ).notifier,
    );
    final studentController = ref.read(
      institutionUserSelectionControllerProvider(
        InstitutionUserSelectionPurpose.activeStudent,
      ).notifier,
    );
    if (!parentController.open() || !studentController.open()) {
      parentController.close();
      studentController.close();
      return false;
    }
    _invalidateOperation();
    state = const InstitutionParentStudentRelationshipActionState.connect();
    return true;
  }

  void cancelConnect() {
    if (!state.isConnectDialog || state.isBusy) {
      return;
    }
    _closeConnectSelectors();
    _invalidateOperation();
    state = const InstitutionParentStudentRelationshipActionState.idle();
  }

  Future<void> submitConnect() async {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || !state.isConnectDialog || state.isBusy) {
      return;
    }
    final parentState = ref.read(
      institutionUserSelectionControllerProvider(
        InstitutionUserSelectionPurpose.activeParent,
      ),
    );
    final studentState = ref.read(
      institutionUserSelectionControllerProvider(
        InstitutionUserSelectionPurpose.activeStudent,
      ),
    );
    final parent = parentState.selected;
    final student = studentState.selected;
    if (parent == null ||
        student == null ||
        !ref
            .read(
              institutionUserSelectionControllerProvider(
                InstitutionUserSelectionPurpose.activeParent,
              ).notifier,
            )
            .ownsSelected(parent) ||
        !ref
            .read(
              institutionUserSelectionControllerProvider(
                InstitutionUserSelectionPurpose.activeStudent,
              ).notifier,
            )
            .ownsSelected(student) ||
        !_matchesSession(sessionKey)) {
      return;
    }
    final request = InstitutionParentStudentConnectRequest(
      parentId: parent.id,
      studentId: student.id,
    );
    final operation = _ParentStudentOperation.connect(
      sessionKey: sessionKey,
      parent: parent,
      student: student,
      generation: ++_operationGeneration,
    );
    _operation = operation;
    state = InstitutionParentStudentRelationshipActionState.connect(
      status:
          InstitutionParentStudentRelationshipActionStatus.submittingConnect,
      parent: parent,
      student: student,
    );
    try {
      await ref
          .read(institutionParentStudentRelationshipRepositoryProvider)
          .connect(request);
      if (_canPublishConnect(operation)) {
        await _settleConnect(
          operation,
          feedback: 'Parent and student connected successfully.',
          unknown: false,
        );
      }
    } on InstitutionParentStudentMutationOutcomeUnknownException {
      if (_canPublishConnect(operation)) {
        await _settleConnect(
          operation,
          feedback:
              'Connection result remains unconfirmed. Review recent current connections before connecting this pair again.',
          unknown: true,
        );
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublishConnect(operation)) {
        return;
      }
      final failure = exception.failure;
      if (_isSessionFailure(failure)) {
        _publishSessionFailure(failure);
      } else if (_isConnectRecoverable(failure)) {
        _publishConnectRecoverable(operation, failure);
      } else if (_isNotFound(failure)) {
        _settleConnectRejected(
          'One or both selected users are no longer available for this connection.',
        );
      } else if (_isConflict(failure)) {
        _settleConnectRejected(
          'The connection was not accepted because current user state changed. Review active Parents and Students before trying again.',
        );
      }
    } catch (_) {
      if (_canPublishConnect(operation)) {
        await _settleConnect(
          operation,
          feedback:
              'Connection result remains unconfirmed. Review recent current connections before connecting this pair again.',
          unknown: true,
        );
      }
    }
  }

  bool beginDisconnect({
    required InstitutionParentStudentPerspective perspective,
    required InstitutionUser anchor,
    required InstitutionParentStudentRelationship relationship,
  }) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        state.hasOpenAction ||
        !_matchesSession(sessionKey)) {
      return false;
    }
    final identity = InstitutionParentStudentRelationshipIdentity(
      perspective: perspective,
      anchor: anchor,
      relationship: relationship,
    );
    final listController = ref.read(
      institutionParentStudentRelationshipListControllerProvider(
        perspective,
      ).notifier,
    );
    if (!listController.ownsCurrentRelationship(identity)) {
      return false;
    }
    final operation = _ParentStudentOperation.disconnect(
      sessionKey: sessionKey,
      identity: identity,
      generation: ++_operationGeneration,
    );
    _operation = operation;
    _focusKey = InstitutionParentStudentRelationshipActionFocusKey(identity);
    state = InstitutionParentStudentRelationshipActionState.disconnect(
      status: InstitutionParentStudentRelationshipActionStatus.disconnectDialog,
      perspective: perspective,
      anchor: anchor,
      relationship: relationship,
    );
    return true;
  }

  void cancelDisconnect() {
    final operation = _operation;
    if (!state.isDisconnectDialog || state.isBusy || operation == null) {
      return;
    }
    _operation = null;
    state = const InstitutionParentStudentRelationshipActionState.idle();
  }

  Future<void> confirmDisconnect() async {
    final operation = _operation;
    if (operation == null ||
        operation.kind != _ParentStudentOperationKind.disconnect ||
        !state.isDisconnectDialog ||
        state.isBusy ||
        !_canPublishDisconnect(operation)) {
      return;
    }
    final identity = operation.identity!;
    state = InstitutionParentStudentRelationshipActionState.disconnect(
      status:
          InstitutionParentStudentRelationshipActionStatus.submittingDisconnect,
      perspective: identity.perspective,
      anchor: identity.anchor,
      relationship: identity.relationship,
    );
    try {
      await ref
          .read(institutionParentStudentRelationshipRepositoryProvider)
          .disconnect(identity.relationshipId);
      if (_canPublishDisconnect(operation)) {
        await _settleDisconnect(operation, 'Parent and student disconnected.');
      }
    } on InstitutionParentStudentMutationOutcomeUnknownException {
      if (_canPublishDisconnect(operation)) {
        await _settleDisconnect(
          operation,
          'Disconnect result could not be confirmed. Review the current connections.',
        );
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublishDisconnect(operation)) {
        return;
      }
      final failure = exception.failure;
      if (_isSessionFailure(failure)) {
        _publishSessionFailure(failure);
      } else if (_isDisconnectRecoverable(failure)) {
        _settleDisconnectDefinite(_disconnectDefiniteMessage(failure));
      } else if (_isNotFound(failure)) {
        await _settleDisconnect(
          operation,
          'The selected connection is no longer available.',
        );
      } else if (_isConflict(failure)) {
        await _settleDisconnect(
          operation,
          'The disconnect request was not accepted because current server state changed.',
        );
      }
    } catch (_) {
      if (_canPublishDisconnect(operation)) {
        await _settleDisconnect(
          operation,
          'Disconnect result could not be confirmed. Review the current connections.',
        );
      }
    }
  }

  InstitutionParentStudentRelationshipActionFocusKey? takeFocusKey() {
    final key = _focusKey;
    _focusKey = null;
    return key;
  }

  void clearFeedback() {
    if (state.status ==
        InstitutionParentStudentRelationshipActionStatus.feedback) {
      state = const InstitutionParentStudentRelationshipActionState.idle();
    }
  }

  Future<void> _settleConnect(
    _ParentStudentOperation operation, {
    required String feedback,
    required bool unknown,
  }) async {
    if (!_ownsOperation(operation)) {
      return;
    }
    _closeConnectSelectors();
    state = InstitutionParentStudentRelationshipActionState.reconciling(
      feedback: feedback,
      perspective: InstitutionParentStudentPerspective.byParent,
    );
    final parent = operation.parent!;
    final student = operation.student!;
    final byStudent = ref.read(
      institutionParentStudentRelationshipListControllerProvider(
        InstitutionParentStudentPerspective.byStudent,
      ).notifier,
    );
    if (byStudent.hasAnchorId(student.id)) {
      byStudent.markStale();
    }
    final byParent = ref.read(
      institutionParentStudentRelationshipListControllerProvider(
        InstitutionParentStudentPerspective.byParent,
      ).notifier,
    );
    if (unknown) {
      final currentPerPage = ref
          .read(
            institutionParentStudentRelationshipListControllerProvider(
              InstitutionParentStudentPerspective.byParent,
            ),
          )
          .query
          .perPage;
      final recoveryQuery =
          const InstitutionParentStudentRelationshipQuery.initial().copyWith(
            perPage: currentPerPage,
            sort: InstitutionParentStudentRelationshipSort.startedAt,
            direction: InstitutionParentStudentRelationshipSortDirection.desc,
          );
      await byParent.selectAnchorForMutation(parent, query: recoveryQuery);
    } else {
      await byParent.selectAnchorForMutation(
        parent,
        preserveQueryForSameAnchor: true,
      );
    }
    if (_ownsOperation(operation)) {
      _operation = null;
      state = InstitutionParentStudentRelationshipActionState.feedback(
        feedback,
      );
    }
  }

  void _settleConnectRejected(String feedback) {
    _closeConnectSelectors();
    _operation = null;
    state = InstitutionParentStudentRelationshipActionState.feedback(feedback);
  }

  void _publishConnectRecoverable(
    _ParentStudentOperation operation,
    ApiFailure failure,
  ) {
    final (
      formMessage,
      parentError,
      studentError,
    ) = switch (failure.serverCode) {
      ApiErrorCodes.forbidden => (
        'You do not have permission to manage Parent–Student connections.',
        null,
        null,
      ),
      ApiErrorCodes.rateLimited => (
        'Too many requests. Wait before trying again.',
        null,
        null,
      ),
      ApiErrorCodes.validationFailed => _connectValidationFeedback(failure),
      _ => ('The connection request was not accepted.', null, null),
    };
    _operation = null;
    state = InstitutionParentStudentRelationshipActionState.connect(
      status: InstitutionParentStudentRelationshipActionStatus
          .connectRecoverableFailure,
      parent: operation.parent,
      student: operation.student,
      formMessage: formMessage,
      parentError: parentError,
      studentError: studentError,
    );
  }

  (String?, String?, String?) _connectValidationFeedback(ApiFailure failure) {
    final keys = failure.fieldErrors.keys.toSet();
    final parentError = keys.contains('parent_id')
        ? 'Review the selected Parent.'
        : null;
    final studentError = keys.contains('student_id')
        ? 'Review the selected Student.'
        : null;
    final unexpected =
        keys.isEmpty ||
        keys.any((key) => key != 'parent_id' && key != 'student_id');
    return (
      unexpected
          ? 'The connection request did not match the server contract.'
          : null,
      parentError,
      studentError,
    );
  }

  Future<void> _settleDisconnect(
    _ParentStudentOperation operation,
    String feedback,
  ) async {
    if (!_ownsOperation(operation)) {
      return;
    }
    final identity = operation.identity!;
    state = InstitutionParentStudentRelationshipActionState.reconciling(
      feedback: feedback,
    );
    final opposite =
        identity.perspective == InstitutionParentStudentPerspective.byParent
        ? InstitutionParentStudentPerspective.byStudent
        : InstitutionParentStudentPerspective.byParent;
    final oppositeAnchorId =
        identity.perspective == InstitutionParentStudentPerspective.byParent
        ? identity.studentId
        : identity.parentId;
    final oppositeController = ref.read(
      institutionParentStudentRelationshipListControllerProvider(
        opposite,
      ).notifier,
    );
    if (oppositeController.hasAnchorId(oppositeAnchorId)) {
      oppositeController.markStale();
    }
    await ref
        .read(
          institutionParentStudentRelationshipListControllerProvider(
            identity.perspective,
          ).notifier,
        )
        .markCheckingAndReload();
    if (_ownsOperation(operation)) {
      _operation = null;
      state = InstitutionParentStudentRelationshipActionState.feedback(
        feedback,
      );
    }
  }

  void _settleDisconnectDefinite(String feedback) {
    _operation = null;
    state = InstitutionParentStudentRelationshipActionState.feedback(feedback);
  }

  String _disconnectDefiniteMessage(ApiFailure failure) =>
      switch (failure.serverCode) {
        ApiErrorCodes.forbidden =>
          'You do not have permission to manage Parent–Student connections.',
        ApiErrorCodes.validationFailed =>
          'The disconnect request did not match the server contract.',
        ApiErrorCodes.rateLimited =>
          'Too many requests. Wait before trying again.',
        _ => 'The disconnect request was not accepted.',
      };

  bool _canPublishConnect(_ParentStudentOperation operation) {
    if (!_ownsOperation(operation) ||
        operation.kind != _ParentStudentOperationKind.connect) {
      return false;
    }
    final parent = operation.parent!;
    final student = operation.student!;
    return ref
            .read(
              institutionUserSelectionControllerProvider(
                InstitutionUserSelectionPurpose.activeParent,
              ).notifier,
            )
            .ownsSelected(parent) &&
        ref
            .read(
              institutionUserSelectionControllerProvider(
                InstitutionUserSelectionPurpose.activeStudent,
              ).notifier,
            )
            .ownsSelected(student);
  }

  bool _canPublishDisconnect(_ParentStudentOperation operation) {
    if (!_ownsOperation(operation) ||
        operation.kind != _ParentStudentOperationKind.disconnect) {
      return false;
    }
    final identity = operation.identity!;
    return ref
        .read(
          institutionParentStudentRelationshipListControllerProvider(
            identity.perspective,
          ).notifier,
        )
        .ownsCurrentRelationship(identity);
  }

  bool _listStateOwnsIdentity(
    InstitutionParentStudentRelationshipListState listState,
    InstitutionParentStudentRelationshipIdentity identity,
  ) {
    final anchor = listState.anchor;
    if (anchor == null ||
        listState.status !=
            InstitutionParentStudentRelationshipListStatus.data) {
      return false;
    }
    return listState.result?.relationships.any(
          (relationship) => identity.matches(
            currentPerspective: identity.perspective,
            currentAnchor: anchor,
            currentRelationship: relationship,
          ),
        ) ??
        false;
  }

  bool _ownsOperation(_ParentStudentOperation operation) =>
      ref.mounted &&
      identical(_operation, operation) &&
      operation.generation == _operationGeneration &&
      _activeSessionKey == operation.sessionKey &&
      _matchesSession(operation.sessionKey);

  bool _matchesSession(InstitutionParentStudentSessionKey sessionKey) =>
      ref.mounted &&
      InstitutionParentStudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          sessionKey;

  bool _isSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    return (failure.statusCode == 401 &&
            code == ApiErrorCodes.authenticationRequired) ||
        (failure.statusCode == 403 &&
            (code == ApiErrorCodes.passwordChangeRequired ||
                code == ApiErrorCodes.userInactive ||
                code == ApiErrorCodes.institutionInactive));
  }

  bool _isConnectRecoverable(ApiFailure failure) =>
      (failure.statusCode == 403 &&
          failure.serverCode == ApiErrorCodes.forbidden) ||
      (failure.statusCode == 422 &&
          failure.serverCode == ApiErrorCodes.validationFailed) ||
      (failure.statusCode == 429 &&
          failure.serverCode == ApiErrorCodes.rateLimited);

  bool _isDisconnectRecoverable(ApiFailure failure) =>
      _isConnectRecoverable(failure);

  bool _isNotFound(ApiFailure failure) =>
      failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound;

  bool _isConflict(ApiFailure failure) =>
      failure.statusCode == 409 &&
      failure.serverCode == ApiErrorCodes.businessConflict;

  void _publishSessionFailure(ApiFailure failure) {
    _closeConnectSelectors();
    _clearOwnership();
    state = const InstitutionParentStudentRelationshipActionState.idle();
    if (failure.serverCode != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  void _closeConnectSelectors() {
    for (final purpose in const [
      InstitutionUserSelectionPurpose.activeParent,
      InstitutionUserSelectionPurpose.activeStudent,
    ]) {
      if (ref.exists(institutionUserSelectionControllerProvider(purpose))) {
        ref
            .read(institutionUserSelectionControllerProvider(purpose).notifier)
            .close();
      }
    }
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _closeConnectSelectors();
    _invalidateOperation();
  }

  void _invalidateOperation() {
    _operationGeneration += 1;
    _operation = null;
    _focusKey = null;
  }
}

class InstitutionParentStudentRelationshipActionFocusKey {
  InstitutionParentStudentRelationshipActionFocusKey(this.identity);

  final InstitutionParentStudentRelationshipIdentity identity;
}

enum _ParentStudentOperationKind { connect, disconnect }

class _ParentStudentOperation {
  const _ParentStudentOperation._({
    required this.kind,
    required this.sessionKey,
    required this.parent,
    required this.student,
    required this.identity,
    required this.generation,
  });

  const _ParentStudentOperation.connect({
    required InstitutionParentStudentSessionKey sessionKey,
    required InstitutionUser parent,
    required InstitutionUser student,
    required int generation,
  }) : this._(
         kind: _ParentStudentOperationKind.connect,
         sessionKey: sessionKey,
         parent: parent,
         student: student,
         identity: null,
         generation: generation,
       );

  const _ParentStudentOperation.disconnect({
    required InstitutionParentStudentSessionKey sessionKey,
    required InstitutionParentStudentRelationshipIdentity identity,
    required int generation,
  }) : this._(
         kind: _ParentStudentOperationKind.disconnect,
         sessionKey: sessionKey,
         parent: null,
         student: null,
         identity: identity,
         generation: generation,
       );

  final _ParentStudentOperationKind kind;
  final InstitutionParentStudentSessionKey sessionKey;
  final InstitutionUser? parent;
  final InstitutionUser? student;
  final InstitutionParentStudentRelationshipIdentity? identity;
  final int generation;
}
