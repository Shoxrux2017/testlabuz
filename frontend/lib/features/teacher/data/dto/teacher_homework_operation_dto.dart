import 'teacher_dto_parse.dart';
import 'teacher_homework_dto.dart';

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

  final TeacherHomeworkDto homework;
}
