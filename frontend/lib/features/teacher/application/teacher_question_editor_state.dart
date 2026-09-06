import '../domain/teacher_question.dart';
import '../domain/teacher_question_authoring.dart';
import '../domain/teacher_question_mutation.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_question_mutation_activity.dart';

enum TeacherQuestionEditorMode { add, edit }

class TeacherQuestionEditorTarget {
  const TeacherQuestionEditorTarget({
    required this.routeTarget,
    required this.routeOwnerGeneration,
    required this.mode,
    required this.editorGeneration,
    this.questionId,
  }) : assert(
         (mode == TeacherQuestionEditorMode.add && questionId == null) ||
             (mode == TeacherQuestionEditorMode.edit && questionId != null),
       );

  final TeacherHomeworkRouteTarget routeTarget;
  final int routeOwnerGeneration;
  final TeacherQuestionEditorMode mode;
  final String? questionId;
  final int editorGeneration;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherQuestionEditorTarget &&
            other.routeTarget == routeTarget &&
            other.routeOwnerGeneration == routeOwnerGeneration &&
            other.mode == mode &&
            other.questionId?.toLowerCase() == questionId?.toLowerCase() &&
            other.editorGeneration == editorGeneration;
  }

  @override
  int get hashCode => Object.hash(
    routeTarget,
    routeOwnerGeneration,
    mode,
    questionId?.toLowerCase(),
    editorGeneration,
  );
}

enum TeacherQuestionEditorStatus {
  loading,
  editing,
  localValidationFailure,
  serverValidationFailure,
  submitting,
  reconciling,
  definiteFailure,
  lockedReview,
  outcomeReview,
  unavailable,
  confirmedSuccess,
  closeForReview,
}

class TeacherQuestionEditorPendingOperation {
  const TeacherQuestionEditorPendingOperation({
    required this.lease,
    required this.authorityStateAtStart,
    this.createRequest,
    this.editRequest,
    this.questionId,
    this.conflictCode,
    this.transportConfirmed = false,
  });

  final TeacherQuestionMutationLease lease;
  final TeacherHomeworkDetailState authorityStateAtStart;
  final TeacherQuestionCreateRequest? createRequest;
  final TeacherQuestionEditRequest? editRequest;
  final String? questionId;
  final String? conflictCode;
  final bool transportConfirmed;

  TeacherQuestionMutationOperation get operation => lease.operation;

  TeacherQuestionEditorPendingOperation withConflictCode(String code) {
    return TeacherQuestionEditorPendingOperation(
      lease: lease,
      authorityStateAtStart: authorityStateAtStart,
      createRequest: createRequest,
      editRequest: editRequest,
      questionId: questionId,
      conflictCode: code,
      transportConfirmed: transportConfirmed,
    );
  }

  TeacherQuestionEditorPendingOperation withConfirmedTransport() {
    return TeacherQuestionEditorPendingOperation(
      lease: lease,
      authorityStateAtStart: authorityStateAtStart,
      createRequest: createRequest,
      editRequest: editRequest,
      questionId: questionId,
      conflictCode: conflictCode,
      transportConfirmed: true,
    );
  }
}

class TeacherQuestionEditorState {
  TeacherQuestionEditorState({
    this.status = TeacherQuestionEditorStatus.loading,
    this.draft,
    this.initialDraft,
    Map<TeacherQuestionDraftField, String> fieldErrors = const {},
    this.formError,
    this.pendingType,
    this.pendingCheckingMode,
    this.pendingOperation,
  }) : fieldErrors = Map<TeacherQuestionDraftField, String>.unmodifiable(
         fieldErrors,
       );

  final TeacherQuestionEditorStatus status;
  final TeacherQuestionDraft? draft;
  final TeacherQuestionDraft? initialDraft;
  final Map<TeacherQuestionDraftField, String> fieldErrors;
  final String? formError;
  final TeacherQuestionType? pendingType;
  final TeacherQuestionCheckingMode? pendingCheckingMode;
  final TeacherQuestionEditorPendingOperation? pendingOperation;

  bool get isBusy =>
      status == TeacherQuestionEditorStatus.submitting ||
      status == TeacherQuestionEditorStatus.reconciling;

  bool get canSubmit =>
      draft != null &&
      !isBusy &&
      status != TeacherQuestionEditorStatus.lockedReview &&
      status != TeacherQuestionEditorStatus.outcomeReview &&
      status != TeacherQuestionEditorStatus.unavailable &&
      status != TeacherQuestionEditorStatus.confirmedSuccess &&
      status != TeacherQuestionEditorStatus.closeForReview;

  bool get isDirty {
    final current = draft;
    final initial = initialDraft;
    return current != null &&
        initial != null &&
        !current.semanticallyEqualsDraft(initial);
  }

  bool get shouldClose =>
      status == TeacherQuestionEditorStatus.confirmedSuccess ||
      status == TeacherQuestionEditorStatus.closeForReview;

  bool get blocksNavigation =>
      isBusy || status == TeacherQuestionEditorStatus.outcomeReview;

  TeacherQuestionEditorState copyWith({
    TeacherQuestionEditorStatus? status,
    Object? draft = _notProvided,
    Object? initialDraft = _notProvided,
    Map<TeacherQuestionDraftField, String>? fieldErrors,
    Object? formError = _notProvided,
    Object? pendingType = _notProvided,
    Object? pendingCheckingMode = _notProvided,
    Object? pendingOperation = _notProvided,
  }) {
    return TeacherQuestionEditorState(
      status: status ?? this.status,
      draft: identical(draft, _notProvided)
          ? this.draft
          : draft as TeacherQuestionDraft?,
      initialDraft: identical(initialDraft, _notProvided)
          ? this.initialDraft
          : initialDraft as TeacherQuestionDraft?,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      formError: identical(formError, _notProvided)
          ? this.formError
          : formError as String?,
      pendingType: identical(pendingType, _notProvided)
          ? this.pendingType
          : pendingType as TeacherQuestionType?,
      pendingCheckingMode: identical(pendingCheckingMode, _notProvided)
          ? this.pendingCheckingMode
          : pendingCheckingMode as TeacherQuestionCheckingMode?,
      pendingOperation: identical(pendingOperation, _notProvided)
          ? this.pendingOperation
          : pendingOperation as TeacherQuestionEditorPendingOperation?,
    );
  }
}

const _notProvided = Object();
