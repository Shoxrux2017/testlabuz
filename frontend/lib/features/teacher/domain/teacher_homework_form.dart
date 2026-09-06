import '../../../core/time/institution_timezone.dart';
import 'teacher_homework.dart';

enum TeacherHomeworkFormField {
  title('title'),
  description('description'),
  studentInstructions('student_instructions'),
  assignmentMode('assignment_mode'),
  studentIds('student_ids'),
  deadlineAt('deadline_at');

  const TeacherHomeworkFormField(this.requestKey);

  final String requestKey;

  static TeacherHomeworkFormField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }
    return null;
  }
}

class TeacherHomeworkFormValue {
  TeacherHomeworkFormValue({
    this.title = '',
    this.description = '',
    this.studentInstructions = '',
    this.assignmentMode = TeacherHomeworkAssignmentMode.group,
    Set<String> selectedStudentIds = const {},
    this.deadlineWallClock,
  }) : selectedStudentIds = _freezeCanonicalStudentIds(selectedStudentIds);

  factory TeacherHomeworkFormValue.fromHomework(
    TeacherHomework homework,
    String institutionTimezone,
  ) {
    if (InstitutionTimezone.tryResolve(institutionTimezone) == null) {
      throw const InstitutionTimezoneException(
        InstitutionTimezoneFailureReason.unknownTimezone,
      );
    }
    return TeacherHomeworkFormValue(
      title: homework.title,
      description: homework.description ?? '',
      studentInstructions: homework.studentInstructions,
      assignmentMode: homework.assignmentMode,
      selectedStudentIds: homework.studentIds.toSet(),
      deadlineWallClock: InstitutionTimezone.instantToWallClock(
        homework.deadlineAt,
        institutionTimezone,
      ),
    );
  }

  static const titleMaxLength = 255;
  static const descriptionMaxLength = 10000;
  static const studentInstructionsMaxLength = 10000;

  final String title;
  final String description;
  final String studentInstructions;
  final TeacherHomeworkAssignmentMode assignmentMode;
  final Set<String> selectedStudentIds;
  final InstitutionWallClock? deadlineWallClock;

  String get normalizedTitle => title.trim();
  String? get normalizedDescription => description.isEmpty ? null : description;
  String get normalizedStudentInstructions => studentInstructions.trim();

  TeacherHomeworkFormValue copyWith({
    String? title,
    String? description,
    String? studentInstructions,
    TeacherHomeworkAssignmentMode? assignmentMode,
    Set<String>? selectedStudentIds,
    Object? deadlineWallClock = _unchanged,
  }) {
    return TeacherHomeworkFormValue(
      title: title ?? this.title,
      description: description ?? this.description,
      studentInstructions: studentInstructions ?? this.studentInstructions,
      assignmentMode: assignmentMode ?? this.assignmentMode,
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
      deadlineWallClock: identical(deadlineWallClock, _unchanged)
          ? this.deadlineWallClock
          : deadlineWallClock as InstitutionWallClock?,
    );
  }

  Map<TeacherHomeworkFormField, String> validate({
    required String institutionTimezone,
  }) {
    final errors = <TeacherHomeworkFormField, String>{};

    if (normalizedTitle.isEmpty) {
      errors[TeacherHomeworkFormField.title] = 'Homework title is required.';
    } else if (normalizedTitle.runes.length > titleMaxLength) {
      errors[TeacherHomeworkFormField.title] =
          'Homework title must be 255 characters or fewer.';
    }

    if (description.runes.length > descriptionMaxLength) {
      errors[TeacherHomeworkFormField.description] =
          'Description must be 10000 characters or fewer.';
    }

    if (normalizedStudentInstructions.isEmpty) {
      errors[TeacherHomeworkFormField.studentInstructions] =
          'Student instructions are required.';
    } else if (normalizedStudentInstructions.runes.length >
        studentInstructionsMaxLength) {
      errors[TeacherHomeworkFormField.studentInstructions] =
          'Student instructions must be 10000 characters or fewer.';
    }

    switch (assignmentMode) {
      case TeacherHomeworkAssignmentMode.group:
        if (selectedStudentIds.isNotEmpty) {
          errors[TeacherHomeworkFormField.studentIds] =
              'Whole-group Homework cannot include selected Students.';
        }
      case TeacherHomeworkAssignmentMode.selectedStudents:
        if (selectedStudentIds.isEmpty) {
          errors[TeacherHomeworkFormField.studentIds] =
              'Choose at least one Student.';
        }
    }

    if (deadlineWallClock != null) {
      try {
        InstitutionTimezone.serializeWallClock(
          deadlineWallClock,
          institutionTimezone,
        );
      } on InstitutionTimezoneException catch (exception) {
        errors[TeacherHomeworkFormField.deadlineAt] =
            exception.reason ==
                InstitutionTimezoneFailureReason.nonexistentLocalTime
            ? 'This local deadline does not exist in the Institution timezone.'
            : 'The Institution timezone is unavailable.';
      }
    }

    return Map<TeacherHomeworkFormField, String>.unmodifiable(errors);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherHomeworkFormValue &&
            other.title == title &&
            other.description == description &&
            other.studentInstructions == studentInstructions &&
            other.assignmentMode == assignmentMode &&
            _sameStudentIds(other.selectedStudentIds, selectedStudentIds) &&
            other.deadlineWallClock == deadlineWallClock;
  }

  @override
  int get hashCode => Object.hash(
    title,
    description,
    studentInstructions,
    assignmentMode,
    Object.hashAll(selectedStudentIds),
    deadlineWallClock,
  );
}

Set<String> _freezeCanonicalStudentIds(Iterable<String> studentIds) {
  final canonical = <String>{};
  for (final studentId in studentIds) {
    if (!isCanonicalTeacherHomeworkId(studentId)) {
      throw ArgumentError.value(
        studentId,
        'selectedStudentIds',
        'Every Student ID must be a canonical UUID.',
      );
    }
    canonical.add(studentId.toLowerCase());
  }
  final sorted = canonical.toList()..sort();
  return Set<String>.unmodifiable(sorted);
}

bool _sameStudentIds(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}

const _unchanged = Object();
