import '../../domain/teacher_group_student.dart';
import 'teacher_dto_parse.dart';

class TeacherGroupStudentDto {
  const TeacherGroupStudentDto({
    required this.id,
    required this.fullName,
    required this.loginName,
  });

  factory TeacherGroupStudentDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Group Student resource',
      keys: const {'id', 'full_name', 'login_name'},
    );
    return TeacherGroupStudentDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      fullName: readTeacherNonBlankString(map, 'full_name'),
      loginName: readTeacherNonBlankString(map, 'login_name'),
    );
  }

  final String id;
  final String fullName;
  final String loginName;

  TeacherGroupStudent toDomain() {
    return TeacherGroupStudent(
      id: id,
      fullName: fullName,
      loginName: loginName,
    );
  }
}
