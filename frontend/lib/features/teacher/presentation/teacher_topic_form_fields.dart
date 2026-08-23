import 'package:flutter/material.dart';

import '../../../core/time/institution_timezone.dart';
import '../domain/teacher_topic_mutation.dart';
import 'teacher_topic_formatters.dart';

class TeacherTopicMetadataFields extends StatelessWidget {
  const TeacherTopicMetadataFields({
    required this.enabled,
    required this.titleController,
    required this.descriptionController,
    required this.subjectController,
    required this.instructionsController,
    required this.titleFocusNode,
    required this.descriptionFocusNode,
    required this.subjectFocusNode,
    required this.instructionsFocusNode,
    required this.lessonAtFocusNode,
    required this.groupControl,
    required this.lessonAt,
    required this.errorFor,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onSubjectChanged,
    required this.onInstructionsChanged,
    required this.onChooseLessonAt,
    required this.onClearLessonAt,
    super.key,
  });

  final bool enabled;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController subjectController;
  final TextEditingController instructionsController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final FocusNode subjectFocusNode;
  final FocusNode instructionsFocusNode;
  final FocusNode lessonAtFocusNode;
  final Widget groupControl;
  final InstitutionWallClock? lessonAt;
  final String? Function(TeacherTopicFormField field) errorFor;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onInstructionsChanged;
  final VoidCallback? onChooseLessonAt;
  final VoidCallback? onClearLessonAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        groupControl,
        const SizedBox(height: 16),
        TextField(
          key: const Key('teacherTopicTitleField'),
          controller: titleController,
          focusNode: titleFocusNode,
          enabled: enabled,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: onTitleChanged,
          onSubmitted: (_) => subjectFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Title',
            errorText: errorFor(TeacherTopicFormField.title),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('teacherTopicSubjectField'),
          controller: subjectController,
          focusNode: subjectFocusNode,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          onChanged: onSubjectChanged,
          onSubmitted: (_) => descriptionFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Subject',
            errorText: errorFor(TeacherTopicFormField.subject),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('teacherTopicDescriptionField'),
          controller: descriptionController,
          focusNode: descriptionFocusNode,
          enabled: enabled,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 3,
          maxLines: 7,
          onChanged: onDescriptionChanged,
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            alignLabelWithHint: true,
            errorText: errorFor(TeacherTopicFormField.description),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('teacherTopicInstructionsField'),
          controller: instructionsController,
          focusNode: instructionsFocusNode,
          enabled: enabled,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 4,
          maxLines: 9,
          onChanged: onInstructionsChanged,
          decoration: InputDecoration(
            labelText: 'Student instructions',
            alignLabelWithHint: true,
            errorText: errorFor(TeacherTopicFormField.studentInstructions),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          key: const Key('teacherTopicLessonAtControl'),
          decoration: InputDecoration(
            labelText: 'Lesson date and time (optional)',
            errorText: errorFor(TeacherTopicFormField.lessonAt),
            border: const OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                lessonAt == null
                    ? 'Not scheduled'
                    : formatInstitutionWallClock(lessonAt!),
                key: const Key('teacherTopicLessonAtValue'),
              ),
              OutlinedButton.icon(
                key: const Key('teacherTopicChooseLessonAtButton'),
                focusNode: lessonAtFocusNode,
                onPressed: enabled ? onChooseLessonAt : null,
                icon: const Icon(Icons.event_outlined),
                label: Text(lessonAt == null ? 'Choose' : 'Change'),
              ),
              TextButton(
                key: const Key('teacherTopicClearLessonAtButton'),
                onPressed: enabled && lessonAt != null ? onClearLessonAt : null,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TeacherTopicFormMessage extends StatelessWidget {
  const TeacherTopicFormMessage({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.error : colors.primary;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.hourglass_top,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}
