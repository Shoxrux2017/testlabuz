import 'package:flutter/material.dart';

import '../../../core/time/institution_timezone.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_form.dart';
import '../domain/teacher_topic.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_topic_formatters.dart';

class TeacherHomeworkMetadataFields extends StatelessWidget {
  const TeacherHomeworkMetadataFields({
    required this.enabled,
    required this.titleController,
    required this.descriptionController,
    required this.instructionsController,
    required this.titleFocusNode,
    required this.descriptionFocusNode,
    required this.instructionsFocusNode,
    required this.assignmentFocusNode,
    required this.studentPickerFocusNode,
    required this.deadlineFocusNode,
    required this.assignmentMode,
    required this.selectedStudentCount,
    required this.deadlineWallClock,
    required this.institutionTimezone,
    required this.errorFor,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onInstructionsChanged,
    required this.onAssignmentModeChanged,
    required this.onChooseStudents,
    required this.onChooseDeadline,
    required this.onClearDeadline,
    super.key,
  });

  final bool enabled;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController instructionsController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final FocusNode instructionsFocusNode;
  final FocusNode assignmentFocusNode;
  final FocusNode studentPickerFocusNode;
  final FocusNode deadlineFocusNode;
  final TeacherHomeworkAssignmentMode assignmentMode;
  final int selectedStudentCount;
  final InstitutionWallClock? deadlineWallClock;
  final String institutionTimezone;
  final String? Function(TeacherHomeworkFormField field) errorFor;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String> onInstructionsChanged;
  final ValueChanged<TeacherHomeworkAssignmentMode> onAssignmentModeChanged;
  final VoidCallback onChooseStudents;
  final VoidCallback onChooseDeadline;
  final VoidCallback onClearDeadline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormSectionHeading('Homework information'),
        const SizedBox(height: 10),
        TextField(
          key: const Key('teacherHomeworkTitleField'),
          controller: titleController,
          focusNode: titleFocusNode,
          enabled: enabled,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: onTitleChanged,
          onSubmitted: (_) => descriptionFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Title',
            errorText: errorFor(TeacherHomeworkFormField.title),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('teacherHomeworkDescriptionField'),
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
            errorText: errorFor(TeacherHomeworkFormField.description),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('teacherHomeworkInstructionsField'),
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
            errorText: errorFor(TeacherHomeworkFormField.studentInstructions),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        const _FormSectionHeading('Assignment'),
        const SizedBox(height: 10),
        InputDecorator(
          key: const Key('teacherHomeworkAssignmentControl'),
          decoration: InputDecoration(
            labelText: 'Assignment mode',
            errorText: errorFor(TeacherHomeworkFormField.assignmentMode),
            border: const OutlineInputBorder(),
          ),
          child: Focus(
            focusNode: assignmentFocusNode,
            child: Semantics(
              label: 'Homework assignment mode',
              child: SegmentedButton<TeacherHomeworkAssignmentMode>(
                segments: const [
                  ButtonSegment(
                    value: TeacherHomeworkAssignmentMode.group,
                    label: Text('Whole group'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                  ButtonSegment(
                    value: TeacherHomeworkAssignmentMode.selectedStudents,
                    label: Text('Selected students'),
                    icon: Icon(Icons.person_search_outlined),
                  ),
                ],
                selected: {assignmentMode},
                onSelectionChanged: enabled
                    ? (selection) => onAssignmentModeChanged(selection.single)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (assignmentMode == TeacherHomeworkAssignmentMode.group)
          const Text(
            'All eligible Students in the Topic Group will be snapshotted by '
            'the backend when the Homework is activated.',
            key: Key('teacherHomeworkGroupAssignmentNote'),
          )
        else
          InputDecorator(
            key: const Key('teacherHomeworkStudentSelectionControl'),
            decoration: InputDecoration(
              labelText: 'Selected Students',
              errorText: errorFor(TeacherHomeworkFormField.studentIds),
              border: const OutlineInputBorder(),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$selectedStudentCount '
                  '${selectedStudentCount == 1 ? 'Student' : 'Students'} '
                  'selected',
                  key: const Key('teacherHomeworkSelectedStudentCount'),
                ),
                OutlinedButton.icon(
                  key: const Key('teacherHomeworkChooseStudentsButton'),
                  focusNode: studentPickerFocusNode,
                  onPressed: enabled ? onChooseStudents : null,
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Choose Students'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const _FormSectionHeading('Deadline'),
        const SizedBox(height: 10),
        Text('Institution timezone: $institutionTimezone'),
        const SizedBox(height: 8),
        InputDecorator(
          key: const Key('teacherHomeworkDeadlineControl'),
          decoration: InputDecoration(
            labelText: 'Homework deadline (optional)',
            errorText: errorFor(TeacherHomeworkFormField.deadlineAt),
            border: const OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                deadlineWallClock == null
                    ? 'No deadline'
                    : formatInstitutionWallClock(deadlineWallClock!),
                key: const Key('teacherHomeworkDeadlineValue'),
              ),
              OutlinedButton.icon(
                key: const Key('teacherHomeworkChooseDeadlineButton'),
                focusNode: deadlineFocusNode,
                onPressed: enabled ? onChooseDeadline : null,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  deadlineWallClock == null ? 'Choose Deadline' : 'Change',
                ),
              ),
              Tooltip(
                message: 'Clear Deadline',
                child: TextButton.icon(
                  key: const Key('teacherHomeworkClearDeadlineButton'),
                  onPressed: enabled && deadlineWallClock != null
                      ? onClearDeadline
                      : null,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Deadline'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TeacherHomeworkTopicContextCard extends StatelessWidget {
  const TeacherHomeworkTopicContextCard({required this.topic, super.key});

  final TeacherTopic topic;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('teacherHomeworkTopicContext'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FormSectionHeading('Topic context'),
            const SizedBox(height: 10),
            Text('Topic title: ${topic.title}'),
            Text('Group: ${topic.group.name}'),
            Text('Topic status: ${teacherTopicStatusLabel(topic.status)}'),
          ],
        ),
      ),
    );
  }
}

class TeacherHomeworkAttemptPolicyCard extends StatelessWidget {
  const TeacherHomeworkAttemptPolicyCard({
    required this.normalAttempts,
    super.key,
  });

  final int normalAttempts;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('teacherHomeworkAttemptPolicyCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FormSectionHeading('Homework attempts'),
            const SizedBox(height: 8),
            Text('Normal attempts: $normalAttempts'),
            const SizedBox(height: 4),
            const Text('The attempt limit cannot be changed.'),
          ],
        ),
      ),
    );
  }
}

class TeacherHomeworkFormMessage extends StatelessWidget {
  const TeacherHomeworkFormMessage({
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
      container: true,
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

class TeacherHomeworkCurrentStateCard extends StatelessWidget {
  const TeacherHomeworkCurrentStateCard({
    required this.homework,
    required this.institutionTimezone,
    super.key,
  });

  final TeacherHomework homework;
  final String institutionTimezone;

  @override
  Widget build(BuildContext context) {
    final deadline = formatTeacherHomeworkDeadline(
      homework.deadlineAt,
      institutionTimezone,
    );
    final recipientSummary =
        homework.assignmentMode == TeacherHomeworkAssignmentMode.group
        ? 'Whole group'
        : '${homework.studentIds.length} selected Students';

    return Card(
      key: const Key('teacherHomeworkCurrentServerState'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FormSectionHeading('Current server state'),
            const SizedBox(height: 10),
            Text('Title: ${homework.title}'),
            Text('Description: ${homework.description ?? 'No description'}'),
            Text('Student instructions: ${homework.studentInstructions}'),
            Text('Status: ${teacherHomeworkStatusLabel(homework.status)}'),
            Text('Assignment: $recipientSummary'),
            Text('Deadline: $deadline'),
          ],
        ),
      ),
    );
  }
}

class _FormSectionHeading extends StatelessWidget {
  const _FormSectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
