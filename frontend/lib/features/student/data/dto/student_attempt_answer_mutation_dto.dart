import '../../domain/student_answer_mutation.dart';
import '../../domain/student_homework_attempt.dart';
import '../../domain/student_question.dart';
import '../../domain/student_submission_upload.dart';
import 'student_dto_parse.dart';
import 'student_homework_attempt_dto.dart';

class StudentAttemptAnswerMutationDto {
  const StudentAttemptAnswerMutationDto({
    required this.questionId,
    required this.type,
    required this.answer,
    required this.updatedAt,
  });

  factory StudentAttemptAnswerMutationDto.fromJson(
    Object? json, {
    required StudentQuestion question,
    required StudentQuestionType requestedType,
    StudentSubmissionUploadFile? selectedFile,
  }) {
    final envelope = readExactStudentMap(
      json,
      context: 'Student answer mutation envelope',
      keys: const {'data'},
    );
    final map = readExactStudentMap(
      envelope['data'],
      context: 'Student answer mutation',
      keys: const {'question_id', 'type', 'answer', 'updated_at'},
    );
    final questionId = readStudentCanonicalUuid(map, 'question_id');
    final requestedId = readStudentCanonicalUuid({'id': question.id}, 'id');
    final type = StudentQuestionType.parse(
      readStudentNonBlankString(map, 'type'),
    );
    if (questionId.toLowerCase() != requestedId.toLowerCase() ||
        type != requestedType ||
        type != question.type) {
      throw const FormatException(
        'Answer response does not match its Question.',
      );
    }
    final updatedAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'updated_at',
    );
    final answer = map['answer'] == null
        ? null
        : parseStudentAttemptAnswerValue(map['answer'], question);
    if ((answer == null) != (updatedAt == null) ||
        (answer == null &&
            (type == StudentQuestionType.singleChoice ||
                type == StudentQuestionType.trueFalse ||
                type == StudentQuestionType.fileBased))) {
      throw const FormatException('Answer response has invalid nullability.');
    }
    if (type == StudentQuestionType.fileBased) {
      final answerUi = question.answerUi;
      if (answerUi is! StudentFileAnswerUi ||
          answer is! StudentFileAnswerValue ||
          selectedFile == null ||
          !answerUi.allowedExtensions.contains(answer.file.extension) ||
          answer.file.sizeBytes > answerUi.maxSizeBytes ||
          answer.file.originalName != selectedFile.name ||
          answer.file.extension != selectedFile.extension ||
          answer.file.sizeBytes != selectedFile.length) {
        throw const FormatException(
          'File answer response does not match the selected file and Question.',
        );
      }
    }
    return StudentAttemptAnswerMutationDto(
      questionId: questionId,
      type: type,
      answer: answer,
      updatedAt: updatedAt,
    );
  }

  final String questionId;
  final StudentQuestionType type;
  final StudentAttemptAnswerValue? answer;
  final DateTime? updatedAt;

  StudentAttemptAnswerMutationResult toDomain() =>
      StudentAttemptAnswerMutationResult(
        questionId: questionId,
        type: type,
        answer: answer,
        updatedAt: updatedAt,
      );
}
