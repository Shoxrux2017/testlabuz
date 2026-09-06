import '../../../core/time/institution_timezone.dart';
import 'teacher_homework.dart';
import 'teacher_homework_form.dart';

class TeacherHomeworkCreateRequest {
  TeacherHomeworkCreateRequest._({
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.assignmentMode,
    required List<String> studentIds,
    required this.deadlineAtSerialized,
  }) : studentIds = List<String>.unmodifiable(studentIds);

  factory TeacherHomeworkCreateRequest.fromForm(
    TeacherHomeworkFormValue form,
    String institutionTimezone,
  ) {
    _requireCoherentAssignment(form);
    return TeacherHomeworkCreateRequest._(
      title: form.normalizedTitle,
      description: form.normalizedDescription,
      studentInstructions: form.normalizedStudentInstructions,
      assignmentMode: form.assignmentMode,
      studentIds: _requestStudentIds(form),
      deadlineAtSerialized: InstitutionTimezone.serializeWallClock(
        form.deadlineWallClock,
        institutionTimezone,
      ),
    );
  }

  final String title;
  final String? description;
  final String studentInstructions;
  final TeacherHomeworkAssignmentMode assignmentMode;
  final List<String> studentIds;
  final String? deadlineAtSerialized;

  List<Object?> get questions => const [];

  Map<String, Object?> toJson() {
    return <String, Object?>{
      TeacherHomeworkFormField.title.requestKey: title,
      TeacherHomeworkFormField.description.requestKey: description,
      TeacherHomeworkFormField.studentInstructions.requestKey:
          studentInstructions,
      TeacherHomeworkFormField.assignmentMode.requestKey: assignmentMode.value,
      TeacherHomeworkFormField.studentIds.requestKey: studentIds,
      TeacherHomeworkFormField.deadlineAt.requestKey: deadlineAtSerialized,
      'questions': questions,
    };
  }
}

class TeacherHomeworkEditSnapshot {
  TeacherHomeworkEditSnapshot({
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.assignmentMode,
    required Set<String> selectedStudentIds,
    required DateTime? deadlineAtUtc,
  }) : selectedStudentIds = _canonicalStudentIdSet(selectedStudentIds),
       deadlineAtUtc = deadlineAtUtc?.toUtc();

  factory TeacherHomeworkEditSnapshot.fromHomework(TeacherHomework homework) {
    return TeacherHomeworkEditSnapshot(
      title: homework.title,
      description: homework.description == '' ? null : homework.description,
      studentInstructions: homework.studentInstructions,
      assignmentMode: homework.assignmentMode,
      selectedStudentIds: homework.studentIds.toSet(),
      deadlineAtUtc: homework.deadlineAt,
    );
  }

  final String title;
  final String? description;
  final String studentInstructions;
  final TeacherHomeworkAssignmentMode assignmentMode;
  final Set<String> selectedStudentIds;
  final DateTime? deadlineAtUtc;
}

class TeacherHomeworkEditRequest {
  TeacherHomeworkEditRequest._(
    Map<String, Object?> changedFields, {
    required this.deadlineAtUtc,
  }) : changedFields = Map<String, Object?>.unmodifiable(changedFields);

  factory TeacherHomeworkEditRequest.empty() {
    return TeacherHomeworkEditRequest._(const {}, deadlineAtUtc: null);
  }

  factory TeacherHomeworkEditRequest.fromForm({
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required String institutionTimezone,
  }) {
    _requireCoherentAssignment(form);
    final changed = <String, Object?>{};

    if (form.normalizedTitle != initial.title) {
      changed[TeacherHomeworkFormField.title.requestKey] = form.normalizedTitle;
    }
    if (form.normalizedDescription != initial.description) {
      changed[TeacherHomeworkFormField.description.requestKey] =
          form.normalizedDescription;
    }
    if (form.normalizedStudentInstructions != initial.studentInstructions) {
      changed[TeacherHomeworkFormField.studentInstructions.requestKey] =
          form.normalizedStudentInstructions;
    }

    final resultingStudentIds = _requestStudentIds(form);
    if (form.assignmentMode != initial.assignmentMode) {
      changed[TeacherHomeworkFormField.assignmentMode.requestKey] =
          form.assignmentMode.value;
      changed[TeacherHomeworkFormField.studentIds.requestKey] =
          resultingStudentIds;
    } else if (form.assignmentMode ==
            TeacherHomeworkAssignmentMode.selectedStudents &&
        !_sameStudentIdSets(
          form.selectedStudentIds,
          initial.selectedStudentIds,
        )) {
      changed[TeacherHomeworkFormField.studentIds.requestKey] =
          resultingStudentIds;
    }

    final deadlineAtUtc = InstitutionTimezone.wallClockToInstant(
      form.deadlineWallClock,
      institutionTimezone,
    );
    if (!_sameInstant(deadlineAtUtc, initial.deadlineAtUtc)) {
      changed[TeacherHomeworkFormField.deadlineAt.requestKey] =
          InstitutionTimezone.serializeWallClock(
            form.deadlineWallClock,
            institutionTimezone,
          );
    }

    return TeacherHomeworkEditRequest._(changed, deadlineAtUtc: deadlineAtUtc);
  }

  final Map<String, Object?> changedFields;
  final DateTime? deadlineAtUtc;

  bool get isEmpty => changedFields.isEmpty;
  Map<String, Object?> toJson() => changedFields;

  bool matches(TeacherHomework current) {
    for (final entry in changedFields.entries) {
      final matches = switch (entry.key) {
        'title' => current.title == entry.value,
        'description' => current.description == entry.value,
        'student_instructions' => current.studentInstructions == entry.value,
        'assignment_mode' => current.assignmentMode.value == entry.value,
        'student_ids' => _sameStudentIdSets(
          current.studentIds.map((id) => id.toLowerCase()).toSet(),
          (entry.value as List<Object?>)
              .cast<String>()
              .map((id) => id.toLowerCase())
              .toSet(),
        ),
        'deadline_at' => _sameInstant(current.deadlineAt, deadlineAtUtc),
        _ => false,
      };
      if (!matches) {
        return false;
      }
    }
    return true;
  }
}

class TeacherHomeworkMutationOutcomeUnknownException implements Exception {
  const TeacherHomeworkMutationOutcomeUnknownException();
}

List<String> _requestStudentIds(TeacherHomeworkFormValue form) {
  if (form.assignmentMode == TeacherHomeworkAssignmentMode.group) {
    return const [];
  }
  return List<String>.unmodifiable(form.selectedStudentIds.toList()..sort());
}

void _requireCoherentAssignment(TeacherHomeworkFormValue form) {
  final coherent = switch (form.assignmentMode) {
    TeacherHomeworkAssignmentMode.group => form.selectedStudentIds.isEmpty,
    TeacherHomeworkAssignmentMode.selectedStudents =>
      form.selectedStudentIds.isNotEmpty,
  };
  if (!coherent) {
    throw ArgumentError(
      'Teacher Homework request requires a coherent assignment selection.',
    );
  }
}

Set<String> _canonicalStudentIdSet(Iterable<String> ids) {
  final canonical = <String>{};
  for (final id in ids) {
    if (!isCanonicalTeacherHomeworkId(id)) {
      throw ArgumentError.value(
        id,
        'selectedStudentIds',
        'Every Student ID must be a canonical UUID.',
      );
    }
    canonical.add(id.toLowerCase());
  }
  final sorted = canonical.toList()..sort();
  return Set<String>.unmodifiable(sorted);
}

bool _sameStudentIdSets(Set<String> left, Set<String> right) {
  final canonicalLeft = left.map((id) => id.toLowerCase()).toSet();
  final canonicalRight = right.map((id) => id.toLowerCase()).toSet();
  return canonicalLeft.length == canonicalRight.length &&
      canonicalLeft.containsAll(canonicalRight);
}

bool _sameInstant(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == null && right == null;
  }
  return left.toUtc().isAtSameMomentAs(right.toUtc());
}
