import 'teacher_dto_parse.dart';
import 'teacher_topic_result_pair_dto.dart';

class TeacherTopicResultPairReadDto {
  const TeacherTopicResultPairReadDto({required this.pair});

  factory TeacherTopicResultPairReadDto.fromJson(Object? json) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Topic result pair read envelope',
      keys: const {'data'},
    );
    final data = envelope['data'];
    return TeacherTopicResultPairReadDto(
      pair: data == null ? null : TeacherTopicResultPairDto.fromJson(data),
    );
  }

  final TeacherTopicResultPairDto? pair;
}

class TeacherTopicResultPairMutationDto {
  const TeacherTopicResultPairMutationDto({required this.pair});

  factory TeacherTopicResultPairMutationDto.fromJson(Object? json) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Topic result pair mutation envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != successMessage) {
      throw const FormatException(
        'Teacher Topic result pair mutation message does not match the contract.',
      );
    }

    return TeacherTopicResultPairMutationDto(
      pair: TeacherTopicResultPairDto.fromJson(envelope['data']),
    );
  }

  static const successMessage = 'Topic result pair updated successfully.';

  final TeacherTopicResultPairDto pair;
}
