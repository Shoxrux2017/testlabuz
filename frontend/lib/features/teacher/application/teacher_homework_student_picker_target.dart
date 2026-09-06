import '../domain/teacher_group_student.dart';
import '../domain/teacher_homework.dart';
import 'teacher_session_key.dart';

class TeacherHomeworkStudentPickerTarget {
  TeacherHomeworkStudentPickerTarget({
    required this.groupId,
    required Set<String> initialSelectedIds,
  }) : initialSelectedIds = _freezeCanonicalStudentIds(initialSelectedIds) {
    if (!isCanonicalTeacherGroupId(groupId)) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Group ID must be a canonical UUID.',
      );
    }
  }

  final String groupId;
  final Set<String> initialSelectedIds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherHomeworkStudentPickerTarget &&
            other.groupId.toLowerCase() == groupId.toLowerCase() &&
            _setsEqual(
              _lowercaseIds(other.initialSelectedIds),
              _lowercaseIds(initialSelectedIds),
            );
  }

  @override
  int get hashCode {
    final sortedIds = _lowercaseIds(initialSelectedIds).toList()..sort();
    return Object.hash(groupId.toLowerCase(), Object.hashAll(sortedIds));
  }
}

typedef TeacherHomeworkStudentPickerOwner = ({
  TeacherSessionKey sessionKey,
  String groupId,
  int routeGeneration,
  int pickerGeneration,
});

typedef TeacherHomeworkStudentPickerLaunch = ({
  TeacherHomeworkStudentPickerTarget target,
  TeacherHomeworkStudentPickerOwner owner,
});

Set<String> _lowercaseIds(Iterable<String> ids) {
  return ids.map((id) => id.toLowerCase()).toSet();
}

bool _setsEqual(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}

Set<String> _freezeCanonicalStudentIds(Iterable<String> ids) {
  final canonicalIds = <String>{};
  for (final id in ids) {
    if (!isCanonicalTeacherHomeworkId(id)) {
      throw ArgumentError.value(
        ids,
        'initialSelectedIds',
        'Student IDs must be canonical UUIDs.',
      );
    }
    canonicalIds.add(id.toLowerCase());
  }
  final sortedIds = canonicalIds.toList()..sort();
  return Set<String>.unmodifiable(sortedIds);
}
