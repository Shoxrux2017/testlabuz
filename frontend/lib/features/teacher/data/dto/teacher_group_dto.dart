import '../../domain/teacher_group.dart';
import 'teacher_dto_parse.dart';

class TeacherGroupDto {
  const TeacherGroupDto({
    required this.id,
    required this.name,
    required this.level,
    required this.subjectDirection,
    required this.status,
  });

  factory TeacherGroupDto.fromAssignedGroupJson(Object? json) {
    final dto = TeacherGroupDto._fromJson(json);
    if (dto.status != TeacherGroupStatus.active) {
      throw const FormatException('An assigned Teacher Group must be active.');
    }

    return dto;
  }

  factory TeacherGroupDto.fromTopicGroupJson(Object? json) {
    return TeacherGroupDto._fromJson(json);
  }

  factory TeacherGroupDto._fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Group resource',
      keys: _groupKeys,
    );

    return TeacherGroupDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      name: readTeacherNonBlankString(map, 'name'),
      level: readTeacherNullableString(map, 'level'),
      subjectDirection: readTeacherNullableString(map, 'subject_direction'),
      status: TeacherGroupStatus.parse(
        readTeacherNonBlankString(map, 'status'),
      ),
    );
  }

  final String id;
  final String name;
  final String? level;
  final String? subjectDirection;
  final TeacherGroupStatus status;

  TeacherGroupSummary toDomain() {
    return TeacherGroupSummary(
      id: id,
      name: name,
      level: level,
      subjectDirection: subjectDirection,
      status: status,
    );
  }
}

const _groupKeys = <String>{
  'id',
  'name',
  'level',
  'subject_direction',
  'status',
};
