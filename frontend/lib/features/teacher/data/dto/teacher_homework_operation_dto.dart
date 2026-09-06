import 'teacher_dto_parse.dart';
import 'teacher_homework_dto.dart';
import '../../domain/teacher_homework_lifecycle.dart';

class TeacherHomeworkMutationDto {
  const TeacherHomeworkMutationDto({required this.homework});

  factory TeacherHomeworkMutationDto.fromJson(
    Object? json, {
    required String expectedMessage,
  }) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Homework mutation envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != expectedMessage) {
      throw const FormatException(
        'Teacher Homework mutation message does not match the contract.',
      );
    }

    return TeacherHomeworkMutationDto(
      homework: TeacherHomeworkDto.fromJson(envelope['data']),
    );
  }

  static const createSuccessMessage = 'Homework created successfully.';
  static const updateSuccessMessage = 'Homework updated successfully.';
  static const addQuestionSuccessMessage = 'Question created successfully.';
  static const updateQuestionSuccessMessage = 'Question updated successfully.';
  static const deleteQuestionSuccessMessage = 'Question deleted successfully.';
  static const reorderQuestionsSuccessMessage =
      'Questions reordered successfully.';

  static String lifecycleSuccessMessage(TeacherHomeworkLifecycleAction action) {
    return action.successMessage;
  }

  final TeacherHomeworkDto homework;
}
