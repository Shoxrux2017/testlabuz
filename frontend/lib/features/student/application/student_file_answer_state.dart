import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_question.dart';
import '../domain/student_submission_upload.dart';

enum StudentFileAnswerStatus {
  idle,
  selecting,
  ready,
  uploading,
  uncertain,
  failure,
  uploaded,
}

enum StudentFileAnswerLocalFailure { pickerUnavailable, sourceUnavailable }

class StudentFileQuestionAnswerState {
  const StudentFileQuestionAnswerState({
    required this.question,
    this.serverFile,
    this.selectedFile,
    this.status = StudentFileAnswerStatus.idle,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.failure,
    this.selectionError,
    this.localFailure,
  });

  final StudentQuestion question;
  final StudentSubmissionFile? serverFile;
  final StudentSubmissionUploadFile? selectedFile;
  final StudentFileAnswerStatus status;
  final int sentBytes;
  final int totalBytes;
  final ApiFailure? failure;
  final StudentSubmissionSelectionError? selectionError;
  final StudentFileAnswerLocalFailure? localFailure;
}

class StudentFileAnswerState {
  StudentFileAnswerState({
    Map<String, StudentFileQuestionAnswerState> questions = const {},
    this.isAuthoritative = false,
    this.isTerminal = false,
    this.activeQuestionId,
    this.isReconciling = false,
  }) : questions = Map.unmodifiable(questions);

  final Map<String, StudentFileQuestionAnswerState> questions;
  final bool isAuthoritative;
  final bool isTerminal;
  final String? activeQuestionId;
  final bool isReconciling;

  bool get hasPendingSelection =>
      questions.values.any((entry) => entry.selectedFile != null);
  bool get hasUncertainUpload => questions.values.any(
    (entry) => entry.status == StudentFileAnswerStatus.uncertain,
  );

  bool canChoose(String questionId) =>
      isAuthoritative &&
      !isTerminal &&
      activeQuestionId == null &&
      !hasUncertainUpload &&
      !isReconciling &&
      questions.containsKey(questionId.toLowerCase());

  bool canUpload(String questionId) {
    final entry = questions[questionId.toLowerCase()];
    final selected = entry?.selectedFile;
    return canChoose(questionId) &&
        entry != null &&
        selected != null &&
        entry.question.answerUi is StudentFileAnswerUi &&
        entry.failure?.serverCode != ApiErrorCodes.validationFailed &&
        validateStudentSubmissionSelection(
              selected,
              entry.question.answerUi as StudentFileAnswerUi,
            ) ==
            null;
  }

  bool canDiscard(String questionId) {
    final entry = questions[questionId.toLowerCase()];
    return entry?.selectedFile != null &&
        activeQuestionId != questionId.toLowerCase() &&
        entry!.status != StudentFileAnswerStatus.uncertain &&
        !isTerminal;
  }
}
