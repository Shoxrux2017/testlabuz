import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/institution_group_detail_repository_impl.dart';
import '../data/institution_group_membership_repository_impl.dart';
import '../domain/institution_group.dart';
import '../domain/institution_group_membership.dart';
import '../domain/institution_group_membership_mutation.dart';
import '../domain/institution_user.dart';
import 'institution_group_action_controller.dart';
import 'institution_group_detail_controller.dart';
import 'institution_group_detail_state.dart';
import 'institution_group_list_controller.dart';
import 'institution_group_membership_action_state.dart';
import 'institution_group_membership_candidate_controller.dart';
import 'institution_group_membership_list_controller.dart';
import 'institution_group_membership_list_state.dart';

final institutionGroupMembershipActionControllerProvider = NotifierProvider
    .autoDispose
    .family<
      InstitutionGroupMembershipActionController,
      InstitutionGroupMembershipActionState,
      String
    >(InstitutionGroupMembershipActionController.new);

class InstitutionGroupMembershipActionController
    extends Notifier<InstitutionGroupMembershipActionState> {
  InstitutionGroupMembershipActionController(this.routeGroupId);

  final String routeGroupId;

  InstitutionGroupDetailSessionKey? _activeSessionKey;
  InstitutionGroup? _activeSelected;
  _MembershipOperation? _operation;
  InstitutionGroupMembershipActionFocusKey? _focusKey;
  int _operationGeneration = 0;

  @override
  InstitutionGroupMembershipActionState build() {
    final sessionKey = InstitutionGroupDetailSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(
      institutionGroupDetailControllerProvider(routeGroupId),
    );
    final groupAction = ref.watch(
      institutionGroupActionControllerProvider(routeGroupId),
    );
    final teacherList = ref.watch(
      institutionGroupMembershipListControllerProvider(
        _listKey(InstitutionGroupMemberKind.teacher),
      ),
    );
    final studentList = ref.watch(
      institutionGroupMembershipListControllerProvider(
        _listKey(InstitutionGroupMemberKind.student),
      ),
    );
    final confirmed =
        detail.status == InstitutionGroupDetailStatus.data ||
            detail.status == InstitutionGroupDetailStatus.refreshing
        ? detail.group
        : null;

    if (sessionKey == null) {
      _clearOwnership();
      return const InstitutionGroupMembershipActionState.idle();
    }
    if (confirmed == null) {
      if (_activeSessionKey == sessionKey &&
          detail.target?.toLowerCase() == routeGroupId.toLowerCase() &&
          state.status ==
              InstitutionGroupMembershipActionStatus.terminalFeedback) {
        _activeSelected = null;
        _operation = null;
        return state;
      }
      _clearOwnership();
      return const InstitutionGroupMembershipActionState.idle();
    }
    if (confirmed.id.toLowerCase() != routeGroupId.toLowerCase()) {
      _clearOwnership();
      return const InstitutionGroupMembershipActionState.idle();
    }
    if (_activeSessionKey != sessionKey) {
      _clearOwnership();
      _activeSessionKey = sessionKey;
      _activeSelected = confirmed;
      return const InstitutionGroupMembershipActionState.idle();
    }
    if (_activeSelected != null && !identical(_activeSelected, confirmed)) {
      if (state.hasOpenAction) {
        _forceCloseCandidate();
        _invalidateOperation();
        _activeSelected = confirmed;
        return const InstitutionGroupMembershipActionState.idle();
      }
      _activeSelected = confirmed;
      return state;
    }
    _activeSelected ??= confirmed;
    if (groupAction.hasOpenAction && state.hasOpenAction) {
      _forceCloseCandidate();
      _invalidateOperation();
      return const InstitutionGroupMembershipActionState.idle();
    }
    if (confirmed.status == InstitutionGroupStatus.archived &&
        state.hasOpenAction) {
      _forceCloseCandidate();
      _invalidateOperation();
      return const InstitutionGroupMembershipActionState.idle();
    }
    final operation = _operation;
    if (operation?.membershipIdentity case final identity?) {
      final listState = identity.kind == InstitutionGroupMemberKind.teacher
          ? teacherList
          : studentList;
      if (state.hasOpenAction && !_listStateOwns(listState, identity)) {
        _invalidateOperation();
        return const InstitutionGroupMembershipActionState.idle();
      }
    }
    return state;
  }

  bool beginAssign(InstitutionGroup selected, InstitutionGroupMemberKind kind) {
    if (!_canBegin(selected)) {
      return false;
    }
    final operation = _MembershipOperation(
      actionKind: InstitutionGroupMembershipActionKind.assign,
      memberKind: kind,
      sessionKey: _activeSessionKey!,
      routeGroupId: routeGroupId,
      selectedGroup: selected,
      membershipIdentity: null,
      submittedIds: const [],
      submittedCandidates: const [],
      generation: ++_operationGeneration,
    );
    final candidateOpened = ref
        .read(
          institutionGroupMembershipCandidateControllerProvider(
            _listKey(kind),
          ).notifier,
        )
        .open(selected);
    if (!candidateOpened) {
      return false;
    }
    _activeSelected = selected;
    _operation = operation;
    _focusKey = InstitutionGroupMembershipActionFocusKey._(operation);
    state = InstitutionGroupMembershipActionState.assign(
      status: InstitutionGroupMembershipActionStatus.assignOpen,
      memberKind: kind,
      group: selected,
    );
    return true;
  }

  bool beginRemove({
    required InstitutionGroup selected,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembership membership,
  }) {
    if (!_canBegin(selected)) {
      return false;
    }
    final identity = InstitutionGroupMembershipIdentity(
      groupId: routeGroupId,
      kind: kind,
      membership: membership,
    );
    if (!ref
        .read(
          institutionGroupMembershipListControllerProvider(
            _listKey(kind),
          ).notifier,
        )
        .ownsCurrentMembership(identity)) {
      return false;
    }
    final operation = _MembershipOperation(
      actionKind: InstitutionGroupMembershipActionKind.remove,
      memberKind: kind,
      sessionKey: _activeSessionKey!,
      routeGroupId: routeGroupId,
      selectedGroup: selected,
      membershipIdentity: identity,
      submittedIds: const [],
      submittedCandidates: const [],
      generation: ++_operationGeneration,
    );
    _activeSelected = selected;
    _operation = operation;
    _focusKey = InstitutionGroupMembershipActionFocusKey._(operation);
    state = InstitutionGroupMembershipActionState.remove(
      status: InstitutionGroupMembershipActionStatus.removeConfirming,
      memberKind: kind,
      group: selected,
      membership: membership,
    );
    return true;
  }

  void dismiss() {
    if (state.isBusy) {
      return;
    }
    _forceCloseCandidate();
    _invalidateOperation(clearFocusOwnership: false);
    state = const InstitutionGroupMembershipActionState.idle();
  }

  InstitutionGroupMembershipActionFocusKey? get focusKey => _focusKey;

  bool canRestoreFocus(InstitutionGroupMembershipActionFocusKey key) {
    final sessionKey = InstitutionGroupDetailSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.read(
      institutionGroupDetailControllerProvider(key._routeGroupId),
    );
    final current = detail.group;
    if (!ref.mounted ||
        !identical(_focusKey, key) ||
        sessionKey != key._sessionKey ||
        current == null ||
        current.status != InstitutionGroupStatus.active ||
        current.id.toLowerCase() != key._routeGroupId.toLowerCase() ||
        current.createdAt != key._selectedCreatedAt) {
      return false;
    }
    final identity = key._membershipIdentity;
    if (identity == null) {
      return true;
    }
    return ref
        .read(
          institutionGroupMembershipListControllerProvider(
            _listKey(identity.kind),
          ).notifier,
        )
        .ownsCurrentMembership(identity);
  }

  Future<void> submitAssignment() async {
    final operation = _operation;
    if (operation == null ||
        operation.actionKind != InstitutionGroupMembershipActionKind.assign ||
        !state.isAssignDialog ||
        state.isBusy ||
        !_canPublish(operation)) {
      return;
    }
    final candidateState = ref.read(
      institutionGroupMembershipCandidateControllerProvider(
        _listKey(operation.memberKind),
      ),
    );
    if (candidateState.searchErrorText != null ||
        candidateState.selected.isEmpty ||
        candidateState.selected.length > 100) {
      return;
    }
    late final InstitutionGroupMembershipAssignmentRequest request;
    try {
      request = InstitutionGroupMembershipAssignmentRequest(
        candidateState.selected.map((candidate) => candidate.id),
      );
    } on ArgumentError {
      return;
    }
    final submitted = operation.withAssignment(
      ids: request.memberIds,
      candidates: candidateState.selected,
    );
    _operation = submitted;
    state = InstitutionGroupMembershipActionState.assign(
      status: InstitutionGroupMembershipActionStatus.submitting,
      memberKind: submitted.memberKind,
      group: submitted.selectedGroup,
    );
    try {
      await ref
          .read(institutionGroupMembershipRepositoryProvider)
          .assignMemberships(
            groupId: submitted.routeGroupId,
            kind: submitted.memberKind,
            request: request,
          );
      if (_canPublish(submitted)) {
        _publishConfirmed(
          submitted,
          submitted.memberKind == InstitutionGroupMemberKind.teacher
              ? 'Teachers assigned to group successfully.'
              : 'Students assigned to group successfully.',
        );
      }
    } on InstitutionGroupMembershipMutationOutcomeUnknownException {
      _publishUnknown(submitted);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(submitted)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _publishSessionFailure(submitted, exception.failure);
      } else if (_isConflict(exception.failure)) {
        await _reconcileKnown(submitted, _ReconciliationReason.conflict);
      } else if (_isNotFound(exception.failure)) {
        await _reconcileKnown(submitted, _ReconciliationReason.notFound);
      } else {
        _publishRecoverableAssignment(submitted, exception.failure);
      }
    } catch (_) {
      _publishUnknown(submitted);
    }
  }

  Future<void> confirmRemove() async {
    final operation = _operation;
    if (operation == null ||
        operation.actionKind != InstitutionGroupMembershipActionKind.remove ||
        !state.isRemoveDialog ||
        state.isBusy ||
        !_canPublish(operation)) {
      return;
    }
    state = InstitutionGroupMembershipActionState.remove(
      status: InstitutionGroupMembershipActionStatus.submitting,
      memberKind: operation.memberKind,
      group: operation.selectedGroup,
      membership: operation.membershipIdentity!.membership,
    );
    try {
      await ref
          .read(institutionGroupMembershipRepositoryProvider)
          .removeMembership(
            groupId: operation.routeGroupId,
            kind: operation.memberKind,
            memberId: operation.membershipIdentity!.memberId,
          );
      if (_canPublish(operation)) {
        _publishConfirmed(
          operation,
          operation.memberKind == InstitutionGroupMemberKind.teacher
              ? 'Teacher removed from group.'
              : 'Student removed from group.',
        );
      }
    } on InstitutionGroupMembershipMutationOutcomeUnknownException {
      _publishUnknown(operation);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _publishSessionFailure(operation, exception.failure);
      } else if (_isConflict(exception.failure)) {
        await _reconcileKnown(operation, _ReconciliationReason.conflict);
      } else if (_isNotFound(exception.failure)) {
        await _reconcileKnown(operation, _ReconciliationReason.notFound);
      } else {
        _publishDefiniteRemove(operation, exception.failure);
      }
    } catch (_) {
      _publishUnknown(operation);
    }
  }

  void _publishConfirmed(_MembershipOperation operation, String feedback) {
    if (!_canPublish(operation)) {
      return;
    }
    _settleTerminal(operation, feedback);
    _markGroupListStale(operation.sessionKey);
    _reloadAuthoritativeProjections(operation);
  }

  void _publishUnknown(_MembershipOperation operation) {
    if (!_canPublish(operation)) {
      return;
    }
    final feedback = switch ((operation.actionKind, operation.memberKind)) {
      (
        InstitutionGroupMembershipActionKind.assign,
        InstitutionGroupMemberKind.teacher,
      ) =>
        'Teacher assignment result could not be confirmed. Review the current teacher list before assigning again.',
      (
        InstitutionGroupMembershipActionKind.assign,
        InstitutionGroupMemberKind.student,
      ) =>
        'Student assignment result could not be confirmed. Review the current student list before assigning again.',
      (
        InstitutionGroupMembershipActionKind.remove,
        InstitutionGroupMemberKind.teacher,
      ) =>
        'Teacher removal result could not be confirmed. Review the current teacher list.',
      (
        InstitutionGroupMembershipActionKind.remove,
        InstitutionGroupMemberKind.student,
      ) =>
        'Student removal result could not be confirmed. Review the current student list.',
    };
    _settleTerminal(operation, feedback);
    _markGroupListStale(operation.sessionKey);
    _reloadAuthoritativeProjections(operation);
  }

  void _publishRecoverableAssignment(
    _MembershipOperation operation,
    ApiFailure failure,
  ) {
    final message = switch (failure.serverCode) {
      ApiErrorCodes.validationFailed => _assignmentValidationMessage(
        operation,
        failure,
      ),
      ApiErrorCodes.forbidden =>
        'You do not have permission to change group memberships.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The assignment request was not accepted.',
    };
    state = InstitutionGroupMembershipActionState.assign(
      status: InstitutionGroupMembershipActionStatus.recoverableFailure,
      memberKind: operation.memberKind,
      group: operation.selectedGroup,
      formMessage: message,
    );
  }

  String _assignmentValidationMessage(
    _MembershipOperation operation,
    ApiFailure failure,
  ) {
    final knownKey = operation.memberKind.assignmentBodyKey;
    final keys = failure.fieldErrors.keys.toSet();
    if (keys.isEmpty || keys.any((key) => key != knownKey)) {
      return 'The assignment request did not match the server contract.';
    }
    return 'Review the selected users and try again.';
  }

  void _publishDefiniteRemove(
    _MembershipOperation operation,
    ApiFailure failure,
  ) {
    final feedback = switch (failure.serverCode) {
      ApiErrorCodes.forbidden =>
        'You do not have permission to change group memberships.',
      ApiErrorCodes.validationFailed =>
        'The removal request did not match the server contract.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The removal request was not accepted.',
    };
    _settleTerminal(operation, feedback);
  }

  Future<void> _reconcileKnown(
    _MembershipOperation operation,
    _ReconciliationReason reason,
  ) async {
    if (!_canPublish(operation)) {
      return;
    }
    _forceCloseCandidate();
    _markGroupListStale(operation.sessionKey);
    state = InstitutionGroupMembershipActionState.reconciling(
      actionKind: operation.actionKind,
      memberKind: operation.memberKind,
      group: operation.selectedGroup,
    );
    try {
      final current = await ref
          .read(institutionGroupDetailRepositoryProvider)
          .fetchGroup(operation.routeGroupId);
      if (!_canPublish(operation)) {
        return;
      }
      final feedback = _knownReconciliationFeedback(operation, reason);
      _settleTerminal(operation, feedback);
      final replaced = ref
          .read(
            institutionGroupDetailControllerProvider(
              operation.routeGroupId,
            ).notifier,
          )
          .replaceFromMutation(operation.selectedGroup, current);
      if (replaced) {
        _activeSelected = current;
        ref
            .read(
              institutionGroupMembershipListControllerProvider(
                _listKey(operation.memberKind),
              ).notifier,
            )
            .markCheckingAndReload();
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_isNotFound(exception.failure)) {
        _operation = null;
        _activeSelected = null;
        _focusKey = null;
        ref
            .read(
              institutionGroupDetailControllerProvider(
                operation.routeGroupId,
              ).notifier,
            )
            .markNotFoundFromMutation(operation.selectedGroup);
        state = const InstitutionGroupMembershipActionState.idle();
      } else if (_isSessionFailure(exception.failure)) {
        _publishSessionFailure(operation, exception.failure);
      } else {
        _publishReconciliationError(operation, exception.failure);
      }
    } catch (_) {
      if (_canPublish(operation)) {
        _publishReconciliationError(
          operation,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Institution Group current state is unavailable.',
          ),
        );
      }
    }
  }

  String _knownReconciliationFeedback(
    _MembershipOperation operation,
    _ReconciliationReason reason,
  ) {
    if (reason == _ReconciliationReason.conflict) {
      return operation.actionKind == InstitutionGroupMembershipActionKind.assign
          ? 'Assignment was not accepted because current server state changed. Review the group and active users before trying again.'
          : 'Membership removal was not accepted because current server state changed.';
    }
    return operation.actionKind == InstitutionGroupMembershipActionKind.assign
        ? 'One or more selected users are no longer available for this assignment.'
        : 'The selected membership target is no longer available.';
  }

  void _publishReconciliationError(
    _MembershipOperation operation,
    ApiFailure failure,
  ) {
    final changed = ref
        .read(
          institutionGroupDetailControllerProvider(
            operation.routeGroupId,
          ).notifier,
        )
        .markErrorFromMutation(operation.selectedGroup, failure);
    if (!changed) {
      return;
    }
    _operation = null;
    _activeSelected = null;
    _forceCloseCandidate();
    state = InstitutionGroupMembershipActionState.feedback(
      actionKind: operation.actionKind,
      memberKind: operation.memberKind,
      feedback:
          'The membership request result could not be reconciled because current group state is unavailable.',
    );
  }

  void _publishSessionFailure(
    _MembershipOperation operation,
    ApiFailure failure,
  ) {
    ref
        .read(
          institutionGroupDetailControllerProvider(
            operation.routeGroupId,
          ).notifier,
        )
        .clearForMutationSessionFailure(operation.selectedGroup);
    _forceCloseCandidate();
    _clearOwnership();
    state = const InstitutionGroupMembershipActionState.idle();
    if (failure.serverCode != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  void _settleTerminal(_MembershipOperation operation, String feedback) {
    _forceCloseCandidate();
    _operation = null;
    state = InstitutionGroupMembershipActionState.feedback(
      actionKind: operation.actionKind,
      memberKind: operation.memberKind,
      feedback: feedback,
    );
  }

  void _reloadAuthoritativeProjections(_MembershipOperation operation) {
    ref
        .read(
          institutionGroupMembershipListControllerProvider(
            _listKey(operation.memberKind),
          ).notifier,
        )
        .markCheckingAndReload();
    ref
        .read(
          institutionGroupDetailControllerProvider(
            operation.routeGroupId,
          ).notifier,
        )
        .refresh();
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
    final sessionKey = _activeSessionKey;
    final detail = ref.read(
      institutionGroupDetailControllerProvider(routeGroupId),
    );
    final groupAction = ref.read(
      institutionGroupActionControllerProvider(routeGroupId),
    );
    return sessionKey != null &&
        !state.hasOpenAction &&
        !groupAction.hasOpenAction &&
        detail.status == InstitutionGroupDetailStatus.data &&
        identical(detail.group, selected) &&
        selected.status == InstitutionGroupStatus.active &&
        selected.id.toLowerCase() == routeGroupId.toLowerCase() &&
        _matchesSession(sessionKey);
  }

  bool _canPublish(_MembershipOperation operation) {
    if (!ref.mounted ||
        !identical(_operation, operation) ||
        operation.generation != _operationGeneration ||
        _activeSessionKey != operation.sessionKey ||
        !identical(_activeSelected, operation.selectedGroup) ||
        !_matchesSession(operation.sessionKey)) {
      return false;
    }
    final detail = ref.read(
      institutionGroupDetailControllerProvider(operation.routeGroupId),
    );
    if ((detail.status != InstitutionGroupDetailStatus.data &&
            detail.status != InstitutionGroupDetailStatus.refreshing) ||
        !identical(detail.group, operation.selectedGroup) ||
        operation.selectedGroup.status != InstitutionGroupStatus.active) {
      return false;
    }
    if (operation.actionKind == InstitutionGroupMembershipActionKind.remove) {
      return ref
          .read(
            institutionGroupMembershipListControllerProvider(
              _listKey(operation.memberKind),
            ).notifier,
          )
          .ownsCurrentMembership(operation.membershipIdentity!);
    }
    if (operation.submittedIds.isEmpty) {
      return true;
    }
    if (state.isReconciling) {
      return true;
    }
    final candidateState = ref.read(
      institutionGroupMembershipCandidateControllerProvider(
        _listKey(operation.memberKind),
      ),
    );
    if (!identical(candidateState.group, operation.selectedGroup) ||
        candidateState.selected.length !=
            operation.submittedCandidates.length) {
      return false;
    }
    for (var index = 0; index < candidateState.selected.length; index += 1) {
      if (!identical(
            candidateState.selected[index],
            operation.submittedCandidates[index],
          ) ||
          candidateState.selected[index].id.toLowerCase() !=
              operation.submittedIds[index].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  bool _matchesSession(InstitutionGroupDetailSessionKey sessionKey) =>
      ref.mounted &&
      InstitutionGroupDetailSessionSnapshot.fromSession(
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

  bool _isConflict(ApiFailure failure) =>
      failure.statusCode == 409 &&
      failure.serverCode == ApiErrorCodes.businessConflict;

  bool _isNotFound(ApiFailure failure) =>
      failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound;

  bool _listStateOwns(
    InstitutionGroupMembershipListState listState,
    InstitutionGroupMembershipIdentity identity,
  ) {
    if (listState.status != InstitutionGroupMembershipListStatus.data &&
        listState.status != InstitutionGroupMembershipListStatus.refreshing) {
      return false;
    }
    return listState.result?.memberships.any(
          (membership) => identity.matches(
            currentGroupId: routeGroupId,
            currentKind: identity.kind,
            currentMembership: membership,
          ),
        ) ??
        false;
  }

  InstitutionGroupMembershipListKey _listKey(InstitutionGroupMemberKind kind) =>
      InstitutionGroupMembershipListKey(groupId: routeGroupId, kind: kind);

  void _forceCloseCandidate() {
    final kind = _operation?.memberKind ?? state.memberKind;
    if (kind == null) {
      return;
    }
    if (ref.exists(
      institutionGroupMembershipCandidateControllerProvider(_listKey(kind)),
    )) {
      ref
          .read(
            institutionGroupMembershipCandidateControllerProvider(
              _listKey(kind),
            ).notifier,
          )
          .forceClose();
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
      _focusKey = null;
    }
  }
}

class InstitutionGroupMembershipActionFocusKey {
  InstitutionGroupMembershipActionFocusKey._(_MembershipOperation operation)
    : _sessionKey = operation.sessionKey,
      _routeGroupId = operation.routeGroupId,
      _selectedCreatedAt = operation.selectedGroup.createdAt,
      _memberKind = operation.memberKind,
      _membershipIdentity = operation.membershipIdentity;

  final InstitutionGroupDetailSessionKey _sessionKey;
  final String _routeGroupId;
  final DateTime _selectedCreatedAt;
  final InstitutionGroupMemberKind _memberKind;
  final InstitutionGroupMembershipIdentity? _membershipIdentity;

  InstitutionGroupMemberKind get memberKind => _memberKind;
  bool get isRemove => _membershipIdentity != null;
  InstitutionGroupMembership? get membership => _membershipIdentity?.membership;
}

class _MembershipOperation {
  const _MembershipOperation({
    required this.actionKind,
    required this.memberKind,
    required this.sessionKey,
    required this.routeGroupId,
    required this.selectedGroup,
    required this.membershipIdentity,
    required this.submittedIds,
    required this.submittedCandidates,
    required this.generation,
  });

  final InstitutionGroupMembershipActionKind actionKind;
  final InstitutionGroupMemberKind memberKind;
  final InstitutionGroupDetailSessionKey sessionKey;
  final String routeGroupId;
  final InstitutionGroup selectedGroup;
  final InstitutionGroupMembershipIdentity? membershipIdentity;
  final List<String> submittedIds;
  final List<InstitutionUser> submittedCandidates;
  final int generation;

  _MembershipOperation withAssignment({
    required List<String> ids,
    required List<InstitutionUser> candidates,
  }) => _MembershipOperation(
    actionKind: actionKind,
    memberKind: memberKind,
    sessionKey: sessionKey,
    routeGroupId: routeGroupId,
    selectedGroup: selectedGroup,
    membershipIdentity: membershipIdentity,
    submittedIds: List.unmodifiable(ids),
    submittedCandidates: List.unmodifiable(candidates),
    generation: generation,
  );
}

enum _ReconciliationReason { conflict, notFound }
