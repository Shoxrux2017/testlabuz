import '../../domain/teacher_topic_mutation.dart';
import 'teacher_dto_parse.dart';
import 'teacher_topic_dto.dart';

class TeacherTopicDetailDto {
  const TeacherTopicDetailDto({required this.topic});

  factory TeacherTopicDetailDto.fromJson(Object? json) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Topic detail envelope',
      keys: const {'data'},
    );

    return TeacherTopicDetailDto(
      topic: TeacherTopicDto.fromJson(envelope['data']),
    );
  }

  final TeacherTopicDto topic;
}

class TeacherTopicMutationDto {
  const TeacherTopicMutationDto({required this.topic});

  factory TeacherTopicMutationDto.fromJson(
    Object? json, {
    required String expectedMessage,
  }) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Topic mutation envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != expectedMessage) {
      throw const FormatException(
        'Teacher Topic mutation message does not match the contract.',
      );
    }

    return TeacherTopicMutationDto(
      topic: TeacherTopicDto.fromJson(envelope['data']),
    );
  }

  static const createSuccessMessage = 'Topic created successfully.';
  static const updateSuccessMessage = 'Topic updated successfully.';

  final TeacherTopicDto topic;

  static String lifecycleSuccessMessage(TeacherTopicLifecycleAction action) {
    return action.successMessage;
  }
}
