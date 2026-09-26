import 'teacher_blitz_dto.dart';
import 'teacher_dto_parse.dart';

class TeacherBlitzMutationDto {
  const TeacherBlitzMutationDto({required this.blitz});

  factory TeacherBlitzMutationDto.fromJson(
    Object? json, {
    required String expectedMessage,
  }) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Blitz mutation envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != expectedMessage) {
      throw const FormatException(
        'Teacher Blitz mutation message does not match the contract.',
      );
    }

    return TeacherBlitzMutationDto(
      blitz: TeacherBlitzDto.fromJson(envelope['data']),
    );
  }

  static const createSuccessMessage = 'Blitz task created successfully.';
  static const updateSuccessMessage = 'Blitz task updated successfully.';
  static const scheduleSuccessMessage = 'Blitz task scheduled successfully.';
  static const activateSuccessMessage = 'Blitz task activated successfully.';
  static const closeSuccessMessage = 'Blitz task closed successfully.';
  static const archiveSuccessMessage = 'Blitz task archived successfully.';

  final TeacherBlitzDto blitz;
}
