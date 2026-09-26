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
    this.activeQuestionId,
    this.pendingMutationSnapshot,
    this.isReconciling = false,
    this.isTerminal = false,
    this.sourcePublication,
  }) : questions = Map.unmodifiable(questions);

  final Map<String, StudentQuestionAnswerEditorState> questions;
  final bool isEligible;

  /// The current execution publication allows writes.
  final bool isAuthoritative;
  final String? activeQuestionId;
  final StudentAnswerMutation? pendingMutationSnapshot;
  final bool isReconciling;
  final bool isTerminal;

  /// The execution publication these editors synchronized from; `null` while
  /// an uncertain save still waits for its own check.
  final StudentAttemptPublicationToken? sourcePublication;

  bool get hasDirtyDrafts =>
      !isTerminal && questions.values.any((entry) => entry.isDirty);

  bool get hasUncertainMutation => questions.values.any(
    (entry) => entry.saveStatus == StudentAnswerSaveStatus.uncertain,
  );

  bool canEdit(String questionId) =>
      isEligible &&
      isAuthoritative &&
      !isTerminal &&
      questions.containsKey(questionId.toLowerCase()) &&
      activeQuestionId != questionId.toLowerCase();

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
