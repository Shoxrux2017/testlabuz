import 'package:flutter/material.dart';

import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import 'teacher_blitz_formatters.dart';

/// Focus targets for the editable Blitz fields, owned by the screen state.
class TeacherBlitzFormFocusNodes {
  final title = FocusNode();
  final description = FocusNode();
  final studentInstructions = FocusNode();
  final assignment = FocusNode();
  final studentPicker = FocusNode();
  final duration = FocusNode();

  FocusNode forField(TeacherBlitzFormField field) => switch (field) {
    TeacherBlitzFormField.title => title,
    TeacherBlitzFormField.description => description,
    TeacherBlitzFormField.studentInstructions => studentInstructions,
    TeacherBlitzFormField.assignmentMode => assignment,
    TeacherBlitzFormField.studentIds => studentPicker,
    TeacherBlitzFormField.durationSeconds => duration,
  };

  void dispose() {
    title.dispose();
    description.dispose();
    studentInstructions.dispose();
    assignment.dispose();
    studentPicker.dispose();
    duration.dispose();
  }
}

class TeacherBlitzFormFields extends StatelessWidget {
  const TeacherBlitzFormFields({
    required this.enabled,
    required this.form,
    required this.titleController,
    required this.descriptionController,
    required this.instructionsController,
    required this.durationController,
    required this.focusNodes,
    required this.errorFor,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onInstructionsChanged,
    required this.onDurationChanged,
    required this.onAssignmentModeChanged,
    required this.onChooseStudents,
    this.officialAssignmentLocked = false,
    super.key,
  });

  final bool enabled;
  final TeacherBlitzFormValue form;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController instructionsController;
  final TextEditingController durationController;
  final TeacherBlitzFormFocusNodes focusNodes;
  final String? Function(TeacherBlitzFormField field) errorFor;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String> onInstructionsChanged;
  final ValueChanged<String> onDurationChanged;
  final ValueChanged<TeacherBlitzAssignmentMode> onAssignmentModeChanged;
  final VoidCallback onChooseStudents;
  final bool officialAssignmentLocked;

  @override
  Widget build(BuildContext context) {
    final selectedCount = form.selectedStudentIds.length;
    final durationSeconds = form.durationSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormSectionHeading('Blitz information'),
        const SizedBox(height: 10),
        TextField(
          key: const Key('teacherBlitzTitleField'),
          controller: titleController,
          focusNode: focusNodes.title,
          enabled: enabled,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: onTitleChanged,
          onSubmitted: (_) => focusNodes.description.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Title',
            errorText: errorFor(TeacherBlitzFormField.title),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('teacherBlitzDescriptionField'),
          controller: descriptionController,
          focusNode: focusNodes.description,
          enabled: enabled,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 3,
          maxLines: 7,
          onChanged: onDescriptionChanged,
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            alignLabelWithHint: true,
            errorText: errorFor(TeacherBlitzFormField.description),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('teacherBlitzInstructionsField'),
          controller: instructionsController,
          focusNode: focusNodes.studentInstructions,
          enabled: enabled,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 4,
          maxLines: 9,
          onChanged: onInstructionsChanged,
          decoration: InputDecoration(
            labelText: 'Student instructions',
            alignLabelWithHint: true,
            errorText: errorFor(TeacherBlitzFormField.studentInstructions),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        const _FormSectionHeading('Assignment'),
        const SizedBox(height: 10),
        InputDecorator(
          key: const Key('teacherBlitzAssignmentControl'),
          decoration: InputDecoration(
            labelText: 'Assignment mode',
            errorText: errorFor(TeacherBlitzFormField.assignmentMode),
            border: const OutlineInputBorder(),
          ),
          child: Focus(
            focusNode: focusNodes.assignment,
            child: Semantics(
              label: 'Blitz assignment mode',
              child: SegmentedButton<TeacherBlitzAssignmentMode>(
                segments: [
                  const ButtonSegment(
                    value: TeacherBlitzAssignmentMode.group,
                    label: Text('Whole group'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                  ButtonSegment(
                    value: TeacherBlitzAssignmentMode.selectedStudents,
                    label: const Text('Selected students'),
                    icon: const Icon(Icons.person_search_outlined),
                    enabled: !officialAssignmentLocked,
                  ),
                ],
                selected: {form.assignmentMode},
                onSelectionChanged: enabled
                    ? (selection) => onAssignmentModeChanged(selection.single)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (officialAssignmentLocked)
          const Text(
            'Official Blitz uses whole-group assignment.',
            key: Key('teacherBlitzOfficialAssignmentNote'),
          )
        else if (form.assignmentMode == TeacherBlitzAssignmentMode.group)
          const Text(
            'All eligible Students in the Topic Group will be snapshotted by '
            'the backend when the Blitz is activated.',
            key: Key('teacherBlitzGroupAssignmentNote'),
          )
        else ...[
          InputDecorator(
            key: const Key('teacherBlitzStudentSelectionControl'),
            decoration: InputDecoration(
              labelText: 'Selected Students',
              errorText: errorFor(TeacherBlitzFormField.studentIds),
              border: const OutlineInputBorder(),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Selected: $selectedCount',
                  key: const Key('teacherBlitzSelectedStudentCount'),
                ),
                OutlinedButton.icon(
                  key: const Key('teacherBlitzChooseStudentsButton'),
                  focusNode: focusNodes.studentPicker,
                  onPressed: enabled ? onChooseStudents : null,
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Choose Students'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A selected-student Blitz cannot be designated as the official '
            'Topic Blitz. Only whole-group Blitz can be official.',
            key: Key('teacherBlitzSelectedAssignmentNote'),
          ),
        ],
        const SizedBox(height: 24),
        const _FormSectionHeading('Duration'),
        const SizedBox(height: 10),
        TextField(
          key: const Key('teacherBlitzDurationField'),
          controller: durationController,
          focusNode: focusNodes.duration,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: onDurationChanged,
          decoration: InputDecoration(
            labelText: 'Duration (seconds)',
            helperText:
                'Whole-Blitz duration. Example: 600 seconds = 10 minutes.',
            errorText: errorFor(TeacherBlitzFormField.durationSeconds),
            border: const OutlineInputBorder(),
          ),
        ),
        if (durationSeconds != null) ...[
          const SizedBox(height: 8),
          Text(
            'Duration: ${formatTeacherBlitzDuration(durationSeconds)}',
            key: const Key('teacherBlitzDurationPreview'),
          ),
        ],
      ],
    );
  }
}

class TeacherBlitzAttemptPolicyCard extends StatelessWidget {
  const TeacherBlitzAttemptPolicyCard({
    required this.normalAttempts,
    required this.maxAdditionalExceptionAttempts,
    super.key,
  });

  final int normalAttempts;
  final int maxAdditionalExceptionAttempts;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('teacherBlitzAttemptPolicyCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FormSectionHeading('Blitz attempts'),
            const SizedBox(height: 8),
            Text('Normal attempts: $normalAttempts'),
            Text(
              'Maximum additional exception attempts: '
              '$maxAdditionalExceptionAttempts',
            ),
            const SizedBox(height: 8),
            const Text(
              'An additional attempt is not a normal retry. It can only be '
              'granted later by an authorized Teacher for one Student when a '
              'valid exception applies.',
            ),
          ],
        ),
      ),
    );
  }
}

class TeacherBlitzTimerModeNote extends StatelessWidget {
  const TeacherBlitzTimerModeNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      key: Key('teacherBlitzTimerModeNote'),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'The institution timer-start mode is snapshotted by the server when '
          'the Blitz is activated. It is not configured in this Builder.',
        ),
      ),
    );
  }
}

/// Asks before a Selected -> Group switch clears the chosen Students.
Future<bool> showTeacherBlitzClearSelectionDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear selected Students?'),
      content: const Text(
        'Switching to whole group removes the current Student selection.',
      ),
      actions: [
        TextButton(
          key: const Key('teacherBlitzKeepSelectionButton'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep selection'),
        ),
        FilledButton(
          key: const Key('teacherBlitzClearSelectionButton'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Use whole group'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Future<bool> showTeacherBlitzDiscardDialog(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard Blitz changes?'),
      actions: [
        TextButton(
          key: const Key('teacherBlitzKeepEditingButton'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          key: const Key('teacherBlitzDiscardButton'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard == true;
}

/// Keeps text controllers aligned with the controller-owned form value.
void syncTeacherBlitzFormText({
  required TeacherBlitzFormValue form,
  required TextEditingController title,
  required TextEditingController description,
  required TextEditingController instructions,
  required TextEditingController duration,
}) {
  _setText(title, form.title);
  _setText(description, form.description);
  _setText(instructions, form.studentInstructions);
  _setText(duration, form.durationSecondsText);
}

void _setText(TextEditingController controller, String value) {
  if (controller.text != value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
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
