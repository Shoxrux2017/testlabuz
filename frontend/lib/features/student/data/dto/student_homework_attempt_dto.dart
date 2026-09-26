import '../../domain/student_homework_attempt.dart';
import 'student_attempt_answer_parser.dart';
import 'student_dto_parse.dart';
import 'student_question_dto.dart';

export 'student_attempt_answer_parser.dart' show parseStudentAttemptAnswerValue;

class StudentHomeworkAttemptDto {
  StudentHomeworkAttemptDto({
    required this.id,
    required this.assessmentId,
    required this.attemptNumber,
    required this.status,
    required this.startedAt,
    required this.submittedAt,
    required this.finalizedAt,
    required this.finalizationReason,
    required this.deadlineAt,
    required List<StudentQuestionDto> questions,
    required List<StudentAttemptAnswerState> answers,
  }) : questions = List<StudentQuestionDto>.unmodifiable(questions),
       answers = List<StudentAttemptAnswerState>.unmodifiable(answers);

  factory StudentHomeworkAttemptDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Homework Attempt',
      keys: const {
        'id',
        'assessment_id',
        'attempt_number',
        'status',
        'started_at',
        'submitted_at',
        'finalized_at',
        'finalization_reason',
        'deadline_at',
        'questions',
        'answers',
      },
    );
    final attemptNumber = readStudentInt(map, 'attempt_number');
    if (attemptNumber < 1 || attemptNumber > 3) {
      throw const FormatException('Homework Attempt number must be in 1..3.');
    }
    final status = StudentHomeworkAttemptStatus.parse(
      readStudentNonBlankString(map, 'status'),
    );
    final startedAt = readStudentWholeSecondUtcTimestamp(map, 'started_at');
    final submittedAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'submitted_at',
    );
    final finalizedAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'finalized_at',
    );
    final deadlineAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'deadline_at',
    );
    final reason = map['finalization_reason'] == null
        ? null
        : StudentHomeworkAttemptFinalizationReason.parse(
            readStudentNonBlankString(map, 'finalization_reason'),
          );
    _validateLifecycle(
      status: status,
      startedAt: startedAt,
      submittedAt: submittedAt,
      finalizedAt: finalizedAt,
      reason: reason,
      deadlineAt: deadlineAt,
    );
    final content = StudentAttemptContentDto.fromAttemptMap(map);
    return StudentHomeworkAttemptDto(
      id: readStudentCanonicalUuid(map, 'id'),
      assessmentId: readStudentCanonicalUuid(map, 'assessment_id'),
      attemptNumber: attemptNumber,
      status: status,
      startedAt: startedAt,
      submittedAt: submittedAt,
      finalizedAt: finalizedAt,
      finalizationReason: reason,
      deadlineAt: deadlineAt,
      questions: content.questions,
      answers: content.answers,
    );
  }

  final String id;
  final String assessmentId;
  final int attemptNumber;
  final StudentHomeworkAttemptStatus status;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime? finalizedAt;
  final StudentHomeworkAttemptFinalizationReason? finalizationReason;
  final DateTime? deadlineAt;
  final List<StudentQuestionDto> questions;
  final List<StudentAttemptAnswerState> answers;

  StudentHomeworkAttempt toDomain() => StudentHomeworkAttempt(
    id: id,
    assessmentId: assessmentId,
    attemptNumber: attemptNumber,
    status: status,
    startedAt: startedAt,
    submittedAt: submittedAt,
    finalizedAt: finalizedAt,
    finalizationReason: finalizationReason,
    deadlineAt: deadlineAt,
    questions: questions.map((question) => question.toDomain()).toList(),
    answers: answers,
  );
}

class StudentHomeworkAttemptStartOperationDto {
  const StudentHomeworkAttemptStartOperationDto({
    required this.attempt,
    required this.resultKind,
  });

  final StudentHomeworkAttemptDto attempt;
  final StudentHomeworkAttemptStartResultKind resultKind;

  StudentHomeworkAttemptStartResult toDomain() =>
      StudentHomeworkAttemptStartResult(
        attempt: attempt.toDomain(),
        resultKind: resultKind,
      );
}

void _validateLifecycle({
  required StudentHomeworkAttemptStatus status,
  required DateTime startedAt,
  required DateTime? submittedAt,
  required DateTime? finalizedAt,
  required StudentHomeworkAttemptFinalizationReason? reason,
  required DateTime? deadlineAt,
}) {
  if ((submittedAt != null && startedAt.isAfter(submittedAt)) ||
      (finalizedAt != null && startedAt.isAfter(finalizedAt))) {
    throw const FormatException('Attempt completion precedes its start.');
  }
  if (status == StudentHomeworkAttemptStatus.inProgress) {
    if (submittedAt != null || finalizedAt != null || reason != null) {
      throw const FormatException('In-progress Attempt cannot be finalized.');
    }
    return;
  }
  if (finalizedAt == null || reason == null) {
    throw const FormatException('Completed Attempt requires finalization.');
  }
  final valid = switch (reason) {
    StudentHomeworkAttemptFinalizationReason.studentSubmit =>
      submittedAt == finalizedAt &&
          (deadlineAt == null || finalizedAt.isBefore(deadlineAt)),
    StudentHomeworkAttemptFinalizationReason.homeworkDeadline =>
      submittedAt == null && deadlineAt != null && finalizedAt == deadlineAt,
    StudentHomeworkAttemptFinalizationReason.taskClosed =>
      submittedAt == null &&
          (deadlineAt == null || finalizedAt.isBefore(deadlineAt)),
  };
  if (!valid) {
    throw const FormatException(
      'Attempt finalization metadata is inconsistent.',
    );
  }
}
