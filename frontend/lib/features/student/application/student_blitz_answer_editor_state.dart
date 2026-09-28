import '../domain/student_answer_mutation.dart';
import 'student_attempt_answer_editor_state.dart';
import 'student_attempt_publication_token.dart';

/// Non-file answer editors of one Blitz execution Attempt. The per-Question
/// entries reuse the type-neutral Stage 7 editor state.
class StudentBlitzAnswerEditorState {
  StudentBlitzAnswerEditorState({
    Map<String, StudentQuestionAnswerEditorState> questions = const {},
    this.isEligible = false,
    this.isAuthoritative = false,
    this.isRunning = false,
    this.activeQuestionId,
    this.pendingMutationSnapshot,
    this.isReconciling = false,
    this.isTerminal = false,
    this.sourcePublication,
    this.isFlushing = false,
  }) : questions = Map.unmodifiable(questions);

  final Map<String, StudentQuestionAnswerEditorState> questions;
  final bool isEligible;

  /// The current execution publication allows writes.
  final bool isAuthoritative;

  /// The Attempt is running and its time has not run out on this device.
  /// Drafts stay editable while a replay re-checks the Attempt; only saving
  /// waits for write authority.
  final bool isRunning;
  final String? activeQuestionId;
  final StudentAnswerMutation? pendingMutationSnapshot;
  final bool isReconciling;
  final bool isTerminal;

  /// The execution publication these editors synchronized from; `null` while
  /// an uncertain save still waits for its own check.
  final StudentAttemptPublicationToken? sourcePublication;

  /// Pending saves are being sent before Submit or leaving; editing waits.
  final bool isFlushing;

  bool get hasDirtyDrafts =>
      !isTerminal && questions.values.any((entry) => entry.isDirty);

  bool get hasUncertainMutation => questions.values.any(
    (entry) => entry.saveStatus == StudentAnswerSaveStatus.uncertain,
  );

  bool get hasInvalidDraft => questions.values.any(
    (entry) => entry.isDirty && entry.validation != null,
  );

  bool get hasFailedSave => questions.values.any(
    (entry) =>
        entry.isDirty && entry.saveStatus == StudentAnswerSaveStatus.failure,
  );

  // A Question stays editable while its own save runs; the save sends a
  // snapshot and a later change is saved afterwards.
  bool canEdit(String questionId) =>
      isEligible &&
      isRunning &&
      !isTerminal &&
      !isFlushing &&
      questions.containsKey(questionId.toLowerCase());

  bool canSave(String questionId) {
    final entry = questions[questionId.toLowerCase()];
    return isEligible &&
        isAuthoritative &&
        !isTerminal &&
        activeQuestionId == null &&
        !isReconciling &&
        entry != null &&
        entry.validation == null &&
        entry.isDirty;
  }
}
