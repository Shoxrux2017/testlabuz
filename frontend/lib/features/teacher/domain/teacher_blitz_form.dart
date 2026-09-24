import 'teacher_blitz.dart';

enum TeacherBlitzFormField {
  title('title'),
  description('description'),
  studentInstructions('student_instructions'),
  assignmentMode('assignment_mode'),
  studentIds('student_ids'),
  durationSeconds('duration_seconds');

  const TeacherBlitzFormField(this.requestKey);

  final String requestKey;

  static TeacherBlitzFormField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }
    return null;
  }
}

/// Whether Blitz metadata and Questions may be authored in this status.
bool isTeacherBlitzAuthoringStatus(TeacherBlitzStatus status) {
  return status == TeacherBlitzStatus.draft ||
      status == TeacherBlitzStatus.scheduled;
}

class TeacherBlitzFormValue {
  TeacherBlitzFormValue({
    this.title = '',
    this.description = '',
    this.studentInstructions = '',
    this.assignmentMode = TeacherBlitzAssignmentMode.group,
    Set<String> selectedStudentIds = const {},
    this.durationSecondsText = '',
  }) : selectedStudentIds = _freezeCanonicalStudentIds(selectedStudentIds);

  factory TeacherBlitzFormValue.fromBlitz(TeacherBlitz blitz) {
    return TeacherBlitzFormValue(
      title: blitz.title,
      description: blitz.description ?? '',
      studentInstructions: blitz.studentInstructions,
      assignmentMode: blitz.assignmentMode,
      selectedStudentIds: blitz.studentIds.toSet(),
      durationSecondsText: blitz.durationSeconds.toString(),
    );
  }

  static const titleMaxLength = 255;
  static const descriptionMaxLength = 10000;
  static const studentInstructionsMaxLength = 10000;

  /// PostgreSQL signed integer maximum accepted by the backend.
  static const maxDurationSeconds = 2147483647;

  final String title;
  final String description;
  final String studentInstructions;
  final TeacherBlitzAssignmentMode assignmentMode;
  final Set<String> selectedStudentIds;
  final String durationSecondsText;

  String get normalizedTitle => title.trim();
  String? get normalizedDescription => description.isEmpty ? null : description;
  String get normalizedStudentInstructions => studentInstructions.trim();

  /// Whole seconds when [durationSecondsText] is valid, otherwise `null`.
  int? get durationSeconds {
    final text = durationSecondsText.trim();
    if (!_durationPattern.hasMatch(text)) {
      return null;
    }
    final seconds = int.tryParse(text);
    if (seconds == null || seconds < 1 || seconds > maxDurationSeconds) {
      return null;
    }
    return seconds;
  }

  TeacherBlitzFormValue copyWith({
    String? title,
    String? description,
    String? studentInstructions,
    TeacherBlitzAssignmentMode? assignmentMode,
    Set<String>? selectedStudentIds,
    String? durationSecondsText,
  }) {
    return TeacherBlitzFormValue(
      title: title ?? this.title,
      description: description ?? this.description,
      studentInstructions: studentInstructions ?? this.studentInstructions,
      assignmentMode: assignmentMode ?? this.assignmentMode,
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
      durationSecondsText: durationSecondsText ?? this.durationSecondsText,
    );
  }

  Map<TeacherBlitzFormField, String> validate() {
    final errors = <TeacherBlitzFormField, String>{};

    if (normalizedTitle.isEmpty) {
      errors[TeacherBlitzFormField.title] = 'Blitz title is required.';
    } else if (normalizedTitle.runes.length > titleMaxLength) {
      errors[TeacherBlitzFormField.title] =
          'Blitz title must be 255 characters or fewer.';
    }

    if (description.runes.length > descriptionMaxLength) {
      errors[TeacherBlitzFormField.description] =
          'Description must be 10000 characters or fewer.';
    }

    if (normalizedStudentInstructions.isEmpty) {
      errors[TeacherBlitzFormField.studentInstructions] =
          'Student instructions are required.';
    } else if (normalizedStudentInstructions.runes.length >
        studentInstructionsMaxLength) {
      errors[TeacherBlitzFormField.studentInstructions] =
          'Student instructions must be 10000 characters or fewer.';
    }

    switch (assignmentMode) {
      case TeacherBlitzAssignmentMode.group:
        if (selectedStudentIds.isNotEmpty) {
          errors[TeacherBlitzFormField.studentIds] =
              'Whole-group Blitz cannot include selected Students.';
        }
      case TeacherBlitzAssignmentMode.selectedStudents:
        if (selectedStudentIds.isEmpty) {
          errors[TeacherBlitzFormField.studentIds] =
              'Choose at least one Student.';
        }
    }

    final durationText = durationSecondsText.trim();
    if (durationText.isEmpty) {
      errors[TeacherBlitzFormField.durationSeconds] = 'Duration is required.';
    } else if (!_durationPattern.hasMatch(durationText)) {
      errors[TeacherBlitzFormField.durationSeconds] =
          'Enter whole seconds using digits only.';
    } else if (durationSeconds == null) {
      errors[TeacherBlitzFormField.durationSeconds] =
          'Duration must be between 1 and $maxDurationSeconds seconds.';
    }

    return Map<TeacherBlitzFormField, String>.unmodifiable(errors);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherBlitzFormValue &&
            other.title == title &&
            other.description == description &&
            other.studentInstructions == studentInstructions &&
            other.assignmentMode == assignmentMode &&
            other.selectedStudentIds.length == selectedStudentIds.length &&
            other.selectedStudentIds.containsAll(selectedStudentIds) &&
            other.durationSecondsText == durationSecondsText;
  }

  @override
  int get hashCode => Object.hash(
    title,
    description,
    studentInstructions,
    assignmentMode,
    Object.hashAll(selectedStudentIds),
    durationSecondsText,
  );
}

final _durationPattern = RegExp(r'^[0-9]+$');

Set<String> _freezeCanonicalStudentIds(Iterable<String> studentIds) {
  final canonical = <String>{};
  for (final studentId in studentIds) {
    if (!isCanonicalTeacherBlitzId(studentId)) {
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
