import '../domain/teacher_question_mutation.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_question_mutation_activity.dart';

enum TeacherQuestionBuilderStatus {
  ready,
  deleting,
  reordering,
  reconciling,
  outcomeReview,
  unavailable,
}

class TeacherQuestionBuilderPendingOperation {
  TeacherQuestionBuilderPendingOperation({
    required this.lease,
    required this.authorityStateAtStart,
    this.questionId,
    List<String>? requestedOrderIds,
    this.conflictCode,
    this.transportConfirmed = false,
  }) : requestedOrderIds = requestedOrderIds == null
           ? null
           : List<String>.unmodifiable(requestedOrderIds);

  final TeacherQuestionMutationLease lease;
  final TeacherHomeworkDetailState authorityStateAtStart;
  final String? questionId;
  final List<String>? requestedOrderIds;
  final String? conflictCode;
  final bool transportConfirmed;

  TeacherQuestionMutationOperation get operation => lease.operation;

  TeacherQuestionBuilderPendingOperation withConflictCode(String code) {
    return TeacherQuestionBuilderPendingOperation(
      lease: lease,
      authorityStateAtStart: authorityStateAtStart,
      questionId: questionId,
      requestedOrderIds: requestedOrderIds,
      conflictCode: code,
      transportConfirmed: transportConfirmed,
    );
  }

  TeacherQuestionBuilderPendingOperation withConfirmedTransport() {
    return TeacherQuestionBuilderPendingOperation(
      lease: lease,
      authorityStateAtStart: authorityStateAtStart,
      questionId: questionId,
      requestedOrderIds: requestedOrderIds,
      conflictCode: conflictCode,
      transportConfirmed: true,
    );
  }
}

class TeacherQuestionBuilderState {
  TeacherQuestionBuilderState({
    this.status = TeacherQuestionBuilderStatus.ready,
    List<String> authoritativeOrderIds = const [],
    List<String> draftOrderIds = const [],
    this.orderInitialized = false,
    this.serverLocked = false,
    this.topicNotEditable = false,
    this.authoritativeReloadPending = false,
    this.sharedMutationActive = false,
    this.notice,
    this.pendingOperation,
  }) : authoritativeOrderIds = List<String>.unmodifiable(authoritativeOrderIds),
       draftOrderIds = List<String>.unmodifiable(draftOrderIds);

  final TeacherQuestionBuilderStatus status;
  final List<String> authoritativeOrderIds;
  final List<String> draftOrderIds;
  final bool orderInitialized;
  final bool serverLocked;
  final bool topicNotEditable;
  final bool authoritativeReloadPending;
  final bool sharedMutationActive;
  final String? notice;
  final TeacherQuestionBuilderPendingOperation? pendingOperation;

  bool get orderDirty =>
      orderInitialized && !_sameOrder(authoritativeOrderIds, draftOrderIds);

  bool get isLocalBusy =>
      status == TeacherQuestionBuilderStatus.deleting ||
      status == TeacherQuestionBuilderStatus.reordering ||
      status == TeacherQuestionBuilderStatus.reconciling;

  bool get isBusy => isLocalBusy || sharedMutationActive;

  bool get hasBlockingOutcome =>
      status == TeacherQuestionBuilderStatus.outcomeReview;

  bool get blocksNavigation => isBusy || hasBlockingOutcome;

  TeacherQuestionBuilderState copyWith({
    TeacherQuestionBuilderStatus? status,
    List<String>? authoritativeOrderIds,
    List<String>? draftOrderIds,
    bool? orderInitialized,
    bool? serverLocked,
    bool? topicNotEditable,
    bool? authoritativeReloadPending,
    bool? sharedMutationActive,
    Object? notice = _notProvided,
    Object? pendingOperation = _notProvided,
  }) {
    return TeacherQuestionBuilderState(
      status: status ?? this.status,
      authoritativeOrderIds:
          authoritativeOrderIds ?? this.authoritativeOrderIds,
      draftOrderIds: draftOrderIds ?? this.draftOrderIds,
      orderInitialized: orderInitialized ?? this.orderInitialized,
      serverLocked: serverLocked ?? this.serverLocked,
      topicNotEditable: topicNotEditable ?? this.topicNotEditable,
      authoritativeReloadPending:
          authoritativeReloadPending ?? this.authoritativeReloadPending,
      sharedMutationActive: sharedMutationActive ?? this.sharedMutationActive,
      notice: identical(notice, _notProvided) ? this.notice : notice as String?,
      pendingOperation: identical(pendingOperation, _notProvided)
          ? this.pendingOperation
          : pendingOperation as TeacherQuestionBuilderPendingOperation?,
    );
  }
}

const _notProvided = Object();

bool _sameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].toLowerCase() != right[index].toLowerCase()) {
      return false;
    }
  }
  return true;
}
