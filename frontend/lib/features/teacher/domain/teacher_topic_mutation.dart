import '../../../core/time/institution_timezone.dart';
import 'teacher_group.dart';
import 'teacher_topic.dart';

enum TeacherTopicFormField {
  groupId('group_id'),
  title('title'),
  description('description'),
  subject('subject'),
  studentInstructions('student_instructions'),
  lessonAt('lesson_at');

  const TeacherTopicFormField(this.requestKey);

  final String requestKey;

  static TeacherTopicFormField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }

    return null;
  }
}

class TeacherTopicFormValue {
  const TeacherTopicFormValue({
    this.selectedGroup,
    this.title = '',
    this.description = '',
    this.subject = '',
    this.studentInstructions = '',
    this.lessonAt,
  });

  factory TeacherTopicFormValue.fromTopic(
    TeacherTopic topic,
    String institutionTimezone,
  ) {
    return TeacherTopicFormValue(
      selectedGroup: topic.group,
      title: topic.title,
      description: topic.description ?? '',
      subject: topic.subject,
      studentInstructions: topic.studentInstructions,
      lessonAt: InstitutionTimezone.instantToWallClock(
        topic.lessonAt,
        institutionTimezone,
      ),
    );
  }

  static const titleMaxLength = 255;
  static const subjectMaxLength = 160;

  final TeacherGroupSummary? selectedGroup;
  final String title;
  final String description;
  final String subject;
  final String studentInstructions;
  final InstitutionWallClock? lessonAt;

  String get normalizedTitle => title.trim();
  String? get normalizedDescription {
    return description.trim().isEmpty ? null : description;
  }

  String get normalizedSubject => subject.trim();
  String get normalizedStudentInstructions => studentInstructions.trim();

  TeacherTopicFormValue copyWith({
    Object? selectedGroup = _unchanged,
    String? title,
    String? description,
    String? subject,
    String? studentInstructions,
    Object? lessonAt = _unchanged,
  }) {
    return TeacherTopicFormValue(
      selectedGroup: identical(selectedGroup, _unchanged)
          ? this.selectedGroup
          : selectedGroup as TeacherGroupSummary?,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      studentInstructions: studentInstructions ?? this.studentInstructions,
      lessonAt: identical(lessonAt, _unchanged)
          ? this.lessonAt
          : lessonAt as InstitutionWallClock?,
    );
  }

  Map<TeacherTopicFormField, String> validate({
    required bool requireGroup,
    required String institutionTimezone,
  }) {
    final errors = <TeacherTopicFormField, String>{};
    if (requireGroup && selectedGroup == null) {
      errors[TeacherTopicFormField.groupId] = 'Select an assigned Group.';
    }
    if (normalizedTitle.isEmpty) {
      errors[TeacherTopicFormField.title] = 'Topic title is required.';
    } else if (normalizedTitle.runes.length > titleMaxLength) {
      errors[TeacherTopicFormField.title] =
          'Topic title must be 255 characters or fewer.';
    }
    if (normalizedSubject.isEmpty) {
      errors[TeacherTopicFormField.subject] = 'Subject is required.';
    } else if (normalizedSubject.runes.length > subjectMaxLength) {
      errors[TeacherTopicFormField.subject] =
          'Subject must be 160 characters or fewer.';
    }
    if (normalizedStudentInstructions.isEmpty) {
      errors[TeacherTopicFormField.studentInstructions] =
          'Student instructions are required.';
    }
    if (lessonAt != null) {
      try {
        InstitutionTimezone.serializeWallClock(lessonAt, institutionTimezone);
      } on InstitutionTimezoneException catch (exception) {
        errors[TeacherTopicFormField.lessonAt] =
            exception.reason ==
                InstitutionTimezoneFailureReason.nonexistentLocalTime
            ? 'This local lesson time does not exist in the Institution timezone.'
            : 'The Institution timezone is unavailable.';
      }
    } else if (InstitutionTimezone.tryResolve(institutionTimezone) == null) {
      errors[TeacherTopicFormField.lessonAt] =
          'The Institution timezone is unavailable.';
    }

    return Map<TeacherTopicFormField, String>.unmodifiable(errors);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherTopicFormValue &&
            other.selectedGroup?.id == selectedGroup?.id &&
            other.title == title &&
            other.description == description &&
            other.subject == subject &&
            other.studentInstructions == studentInstructions &&
            other.lessonAt == lessonAt;
  }

  @override
  int get hashCode => Object.hash(
    selectedGroup?.id,
    title,
    description,
    subject,
    studentInstructions,
    lessonAt,
  );
}

class TeacherTopicCreateRequest {
  TeacherTopicCreateRequest._({
    required this.groupId,
    required this.title,
    required this.description,
    required this.subject,
    required this.studentInstructions,
    required this.lessonAt,
    required this.lessonAtInstant,
  });

  factory TeacherTopicCreateRequest.fromForm(
    TeacherTopicFormValue form,
    String institutionTimezone,
  ) {
    final group = form.selectedGroup;
    if (group == null) {
      throw ArgumentError('Teacher Topic create requires a selected Group.');
    }
    final serializedLessonAt = InstitutionTimezone.serializeWallClock(
      form.lessonAt,
      institutionTimezone,
    );

    return TeacherTopicCreateRequest._(
      groupId: group.id,
      title: form.normalizedTitle,
      description: form.normalizedDescription,
      subject: form.normalizedSubject,
      studentInstructions: form.normalizedStudentInstructions,
      lessonAt: serializedLessonAt,
      lessonAtInstant: InstitutionTimezone.wallClockToInstant(
        form.lessonAt,
        institutionTimezone,
      ),
    );
  }

  final String groupId;
  final String title;
  final String? description;
  final String subject;
  final String studentInstructions;
  final String? lessonAt;
  final DateTime? lessonAtInstant;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      TeacherTopicFormField.groupId.requestKey: groupId,
      TeacherTopicFormField.title.requestKey: title,
      TeacherTopicFormField.description.requestKey: description,
      TeacherTopicFormField.subject.requestKey: subject,
      TeacherTopicFormField.studentInstructions.requestKey: studentInstructions,
      TeacherTopicFormField.lessonAt.requestKey: lessonAt,
    };
  }

  bool matches(TeacherTopic topic) {
    return topic.group.id.toLowerCase() == groupId.toLowerCase() &&
        topic.title == title &&
        topic.description == description &&
        topic.subject == subject &&
        topic.studentInstructions == studentInstructions &&
        topic.lessonAt == lessonAtInstant &&
        topic.status == TeacherTopicStatus.draft;
  }
}

class TeacherTopicEditSnapshot {
  const TeacherTopicEditSnapshot({
    required this.title,
    required this.description,
    required this.subject,
    required this.studentInstructions,
    required this.lessonAt,
    required this.lessonAtInstant,
  });

  factory TeacherTopicEditSnapshot.fromTopic(
    TeacherTopic topic,
    String institutionTimezone,
  ) {
    final form = TeacherTopicFormValue.fromTopic(topic, institutionTimezone);

    return TeacherTopicEditSnapshot(
      title: form.normalizedTitle,
      description: form.normalizedDescription,
      subject: form.normalizedSubject,
      studentInstructions: form.normalizedStudentInstructions,
      lessonAt: form.lessonAt,
      lessonAtInstant: topic.lessonAt,
    );
  }

  final String title;
  final String? description;
  final String subject;
  final String studentInstructions;
  final InstitutionWallClock? lessonAt;
  final DateTime? lessonAtInstant;
}

class TeacherTopicEditRequest {
  TeacherTopicEditRequest._(
    Map<String, Object?> changedFields, {
    required this.lessonAtInstant,
  }) : changedFields = Map<String, Object?>.unmodifiable(changedFields);

  factory TeacherTopicEditRequest.empty() {
    return TeacherTopicEditRequest._(const {}, lessonAtInstant: null);
  }

  factory TeacherTopicEditRequest.fromForm({
    required TeacherTopicFormValue form,
    required TeacherTopicEditSnapshot initial,
    required String institutionTimezone,
  }) {
    final changed = <String, Object?>{};
    if (form.normalizedTitle != initial.title) {
      changed[TeacherTopicFormField.title.requestKey] = form.normalizedTitle;
    }
    if (form.normalizedDescription != initial.description) {
      changed[TeacherTopicFormField.description.requestKey] =
          form.normalizedDescription;
    }
    if (form.normalizedSubject != initial.subject) {
      changed[TeacherTopicFormField.subject.requestKey] =
          form.normalizedSubject;
    }
    if (form.normalizedStudentInstructions != initial.studentInstructions) {
      changed[TeacherTopicFormField.studentInstructions.requestKey] =
          form.normalizedStudentInstructions;
    }
    DateTime? submittedLessonInstant;
    if (form.lessonAt != initial.lessonAt) {
      changed[TeacherTopicFormField.lessonAt.requestKey] =
          InstitutionTimezone.serializeWallClock(
            form.lessonAt,
            institutionTimezone,
          );
      submittedLessonInstant = InstitutionTimezone.wallClockToInstant(
        form.lessonAt,
        institutionTimezone,
      );
    }

    return TeacherTopicEditRequest._(
      changed,
      lessonAtInstant: submittedLessonInstant,
    );
  }

  final Map<String, Object?> changedFields;
  final DateTime? lessonAtInstant;

  bool get isEmpty => changedFields.isEmpty;
  Map<String, Object?> toJson() => changedFields;

  bool matches(TeacherTopic topic) {
    for (final entry in changedFields.entries) {
      final matches = switch (entry.key) {
        'title' => topic.title == entry.value,
        'description' => topic.description == entry.value,
        'subject' => topic.subject == entry.value,
        'student_instructions' => topic.studentInstructions == entry.value,
        'lesson_at' => topic.lessonAt == lessonAtInstant,
        _ => false,
      };
      if (!matches) {
        return false;
      }
    }

    return true;
  }
}

enum TeacherTopicLifecycleAction {
  activate(
    segment: 'activate',
    expectedStatus: TeacherTopicStatus.active,
    successMessage: 'Topic activated successfully.',
  ),
  close(
    segment: 'close',
    expectedStatus: TeacherTopicStatus.closed,
    successMessage: 'Topic closed successfully.',
  ),
  archive(
    segment: 'archive',
    expectedStatus: TeacherTopicStatus.archived,
    successMessage: 'Topic archived successfully.',
  );

  const TeacherTopicLifecycleAction({
    required this.segment,
    required this.expectedStatus,
    required this.successMessage,
  });

  final String segment;
  final TeacherTopicStatus expectedStatus;
  final String successMessage;
}

bool teacherTopicCanEdit(TeacherTopic topic) {
  return topic.group.status == TeacherGroupStatus.active &&
      (topic.status == TeacherTopicStatus.draft ||
          topic.status == TeacherTopicStatus.active);
}

List<TeacherTopicLifecycleAction> teacherTopicLifecycleActions(
  TeacherTopic topic,
) {
  return switch ((topic.group.status, topic.status)) {
    (TeacherGroupStatus.active, TeacherTopicStatus.draft) => const [
      TeacherTopicLifecycleAction.activate,
      TeacherTopicLifecycleAction.archive,
    ],
    (TeacherGroupStatus.active, TeacherTopicStatus.active) => const [
      TeacherTopicLifecycleAction.close,
    ],
    (TeacherGroupStatus.active, TeacherTopicStatus.closed) ||
    (TeacherGroupStatus.archived, TeacherTopicStatus.draft) ||
    (
      TeacherGroupStatus.archived,
      TeacherTopicStatus.closed,
    ) => const [TeacherTopicLifecycleAction.archive],
    (TeacherGroupStatus.archived, TeacherTopicStatus.active) => const [
      TeacherTopicLifecycleAction.close,
    ],
    (TeacherGroupStatus.active, TeacherTopicStatus.archived) ||
    (TeacherGroupStatus.archived, TeacherTopicStatus.archived) => const [],
  };
}

class TeacherTopicMutationOutcomeUnknownException implements Exception {
  const TeacherTopicMutationOutcomeUnknownException();
}

const _unchanged = Object();
