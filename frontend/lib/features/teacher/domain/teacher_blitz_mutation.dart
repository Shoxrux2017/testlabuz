import 'teacher_blitz.dart';
import 'teacher_blitz_form.dart';

class TeacherBlitzCreateRequest {
  TeacherBlitzCreateRequest._({
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.assignmentMode,
    required List<String> studentIds,
    required this.durationSeconds,
  }) : studentIds = List<String>.unmodifiable(studentIds);

  factory TeacherBlitzCreateRequest.fromForm(TeacherBlitzFormValue form) {
    _requireValid(form);
    return TeacherBlitzCreateRequest._(
      title: form.normalizedTitle,
      description: form.normalizedDescription,
      studentInstructions: form.normalizedStudentInstructions,
      assignmentMode: form.assignmentMode,
      studentIds: _requestStudentIds(form),
      durationSeconds: form.durationSeconds!,
    );
  }

  final String title;
  final String? description;
  final String studentInstructions;
  final TeacherBlitzAssignmentMode assignmentMode;
  final List<String> studentIds;
  final int durationSeconds;

  // The Builder never schedules and never nests Questions; those belong to
  // the lifecycle endpoint and the Question Builder respectively.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      TeacherBlitzFormField.title.requestKey: title,
      TeacherBlitzFormField.description.requestKey: description,
      TeacherBlitzFormField.studentInstructions.requestKey: studentInstructions,
      TeacherBlitzFormField.assignmentMode.requestKey: assignmentMode.value,
      TeacherBlitzFormField.studentIds.requestKey: studentIds,
      TeacherBlitzFormField.durationSeconds.requestKey: durationSeconds,
      'scheduled_at': null,
      'questions': const <Object?>[],
    };
  }
}

class TeacherBlitzEditSnapshot {
  TeacherBlitzEditSnapshot({
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.assignmentMode,
    required Set<String> selectedStudentIds,
    required this.durationSeconds,
  }) : selectedStudentIds = _canonicalStudentIdSet(selectedStudentIds);

  factory TeacherBlitzEditSnapshot.fromBlitz(TeacherBlitz blitz) {
    return TeacherBlitzEditSnapshot(
      title: blitz.title,
      description: blitz.description == '' ? null : blitz.description,
      studentInstructions: blitz.studentInstructions,
      assignmentMode: blitz.assignmentMode,
      selectedStudentIds: blitz.studentIds.toSet(),
      durationSeconds: blitz.durationSeconds,
    );
  }

  final String title;
  final String? description;
  final String studentInstructions;
  final TeacherBlitzAssignmentMode assignmentMode;
  final Set<String> selectedStudentIds;
  final int durationSeconds;
}

class TeacherBlitzEditRequest {
  TeacherBlitzEditRequest._(Map<String, Object?> changedFields)
    : changedFields = Map<String, Object?>.unmodifiable(changedFields);

  factory TeacherBlitzEditRequest.fromForm({
    required TeacherBlitzFormValue form,
    required TeacherBlitzEditSnapshot initial,
  }) {
    _requireValid(form);
    final changed = <String, Object?>{};

    if (form.normalizedTitle != initial.title) {
      changed[TeacherBlitzFormField.title.requestKey] = form.normalizedTitle;
    }
    if (form.normalizedDescription != initial.description) {
      changed[TeacherBlitzFormField.description.requestKey] =
          form.normalizedDescription;
    }
    if (form.normalizedStudentInstructions != initial.studentInstructions) {
      changed[TeacherBlitzFormField.studentInstructions.requestKey] =
          form.normalizedStudentInstructions;
    }
    if (form.durationSeconds != initial.durationSeconds) {
      changed[TeacherBlitzFormField.durationSeconds.requestKey] =
          form.durationSeconds;
    }

    // Mode and recipients form one relationship; a mode change sends both.
    final resultingStudentIds = _requestStudentIds(form);
    if (form.assignmentMode != initial.assignmentMode) {
      changed[TeacherBlitzFormField.assignmentMode.requestKey] =
          form.assignmentMode.value;
      changed[TeacherBlitzFormField.studentIds.requestKey] =
          resultingStudentIds;
    } else if (form.assignmentMode ==
            TeacherBlitzAssignmentMode.selectedStudents &&
        !_sameStudentIdSets(
          form.selectedStudentIds,
          initial.selectedStudentIds,
        )) {
      changed[TeacherBlitzFormField.studentIds.requestKey] =
          resultingStudentIds;
    }

    return TeacherBlitzEditRequest._(changed);
  }

  final Map<String, Object?> changedFields;

  bool get isEmpty => changedFields.isEmpty;

  Map<String, Object?> toJson() => changedFields;

  /// Whether [current] already carries every requested change.
  bool matches(TeacherBlitz current) {
    for (final entry in changedFields.entries) {
      final matches = switch (entry.key) {
        'title' => current.title == entry.value,
        'description' => current.description == entry.value,
        'student_instructions' => current.studentInstructions == entry.value,
        'assignment_mode' => current.assignmentMode.value == entry.value,
        'student_ids' => _sameStudentIdSets(
          current.studentIds.toSet(),
          (entry.value! as List<Object?>).cast<String>().toSet(),
        ),
        'duration_seconds' => current.durationSeconds == entry.value,
        _ => false,
      };
      if (!matches) {
        return false;
      }
    }
    return true;
  }
}

class TeacherBlitzMutationOutcomeUnknownException implements Exception {
  const TeacherBlitzMutationOutcomeUnknownException();
}

void _requireValid(TeacherBlitzFormValue form) {
  if (form.validate().isNotEmpty) {
    throw ArgumentError('Teacher Blitz request requires a valid form.');
  }
}

List<String> _requestStudentIds(TeacherBlitzFormValue form) {
  if (form.assignmentMode == TeacherBlitzAssignmentMode.group) {
    return const [];
  }
  return List<String>.unmodifiable(form.selectedStudentIds.toList()..sort());
}

Set<String> _canonicalStudentIdSet(Iterable<String> ids) {
  final canonical = <String>{};
  for (final id in ids) {
    if (!isCanonicalTeacherBlitzId(id)) {
      throw ArgumentError.value(
        id,
        'selectedStudentIds',
        'Every Student ID must be a canonical UUID.',
      );
    }
    canonical.add(id.toLowerCase());
  }
  return Set<String>.unmodifiable(canonical);
}

bool _sameStudentIdSets(Set<String> left, Set<String> right) {
  final canonicalLeft = left.map((id) => id.toLowerCase()).toSet();
  final canonicalRight = right.map((id) => id.toLowerCase()).toSet();
  return canonicalLeft.length == canonicalRight.length &&
      canonicalLeft.containsAll(canonicalRight);
}
