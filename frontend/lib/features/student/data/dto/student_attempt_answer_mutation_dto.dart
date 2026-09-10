import '../../domain/student_answer_mutation.dart';
import '../../domain/student_homework_attempt.dart';
import '../../domain/student_question.dart';
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
        type != question.type ||
        type == StudentQuestionType.fileBased) {
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
                type == StudentQuestionType.trueFalse))) {
      throw const FormatException('Answer response has invalid nullability.');
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
