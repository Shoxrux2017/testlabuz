import '../../../core/network/api_failure.dart';
import '../domain/student_answer_draft.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_question.dart';

enum StudentAnswerSaveStatus { idle, saving, uncertain, failure, saved }

class StudentQuestionAnswerEditorState {
  StudentQuestionAnswerEditorState({
    required this.question,
    required this.serverAnswer,
    required this.updatedAt,
    required this.draft,
    this.saveStatus = StudentAnswerSaveStatus.idle,
    this.failure,
  }) : validation = draft.validate(question),
       isDirty = draft.isDirty(question, serverAnswer);

  final StudentQuestion question;
  final StudentAttemptAnswerValue? serverAnswer;
  final DateTime? updatedAt;
  final StudentAnswerDraft draft;
  final String? validation;
  final bool isDirty;
  final StudentAnswerSaveStatus saveStatus;
  final ApiFailure? failure;
}

class StudentAttemptAnswerEditorState {
  StudentAttemptAnswerEditorState({
    Map<String, StudentQuestionAnswerEditorState> questions = const {},
    this.isEligible = false,
    this.isAuthoritative = false,
    this.activeQuestionId,
    this.pendingMutationSnapshot,
    this.isReconciling = false,
    this.terminalAttempt,
  }) : questions = Map.unmodifiable(questions);

  final Map<String, StudentQuestionAnswerEditorState> questions;
  final bool isEligible;
  final bool isAuthoritative;
  final String? activeQuestionId;
  final StudentAnswerMutation? pendingMutationSnapshot;
  final bool isReconciling;
  final StudentHomeworkAttempt? terminalAttempt;

  bool get hasDirtyDrafts =>
      terminalAttempt == null && questions.values.any((entry) => entry.isDirty);

  bool get hasUncertainMutation => questions.values.any(
    (entry) => entry.saveStatus == StudentAnswerSaveStatus.uncertain,
  );

  bool canEdit(String questionId) =>
      isEligible &&
      terminalAttempt == null &&
      questions.containsKey(questionId.toLowerCase()) &&
      activeQuestionId != questionId.toLowerCase();

  bool canSave(String questionId) {
    final entry = questions[questionId.toLowerCase()];
    return isEligible &&
        isAuthoritative &&
        terminalAttempt == null &&
        activeQuestionId == null &&
        !isReconciling &&
        entry != null &&
        entry.validation == null &&
        entry.isDirty;
  }
}
