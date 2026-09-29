import 'dart:convert';

import '../../../core/network/api_failure.dart';
import '../domain/student_answer_draft.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_question.dart';
import 'student_homework_attempt_state.dart';

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

  /// The draft still holds the value [mutation] sent, even if it was edited
  /// and changed back meanwhile.
  bool holdsSentValue(StudentAnswerMutation mutation) =>
      validation == null &&
      jsonEncode(draft.toMutation(question).toJson()) ==
          jsonEncode(mutation.toJson());
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
    this.sourceAttemptPublication,
    this.isFlushing = false,
  }) : questions = Map.unmodifiable(questions);

  final Map<String, StudentQuestionAnswerEditorState> questions;
  final bool isEligible;
  final bool isAuthoritative;
  final String? activeQuestionId;
  final StudentAnswerMutation? pendingMutationSnapshot;
  final bool isReconciling;
  final StudentHomeworkAttempt? terminalAttempt;
  final StudentHomeworkAttemptPublicationToken? sourceAttemptPublication;

  /// Pending saves are being sent before Submit or leaving; editing waits.
  final bool isFlushing;

  bool get hasDirtyDrafts =>
      terminalAttempt == null && questions.values.any((entry) => entry.isDirty);

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
      terminalAttempt == null &&
      !isFlushing &&
      questions.containsKey(questionId.toLowerCase());

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
