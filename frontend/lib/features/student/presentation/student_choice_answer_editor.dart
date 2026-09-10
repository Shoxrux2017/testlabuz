import 'package:flutter/material.dart';

import '../domain/student_answer_draft.dart';
import '../domain/student_question.dart';

class StudentChoiceAnswerEditor extends StatelessWidget {
  const StudentChoiceAnswerEditor({
    required this.question,
    required this.draft,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final StudentQuestion question;
  final StudentAnswerDraft draft;
  final bool enabled;
  final ValueChanged<StudentAnswerDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    if (draft case StudentTrueFalseDraft(:final value)) {
      return RadioGroup<bool>(
        groupValue: value,
        onChanged: (value) {
          if (enabled) onChanged(StudentTrueFalseDraft(value: value));
        },
        child: Column(
          children: [
            for (final choice in [true, false])
              RadioListTile<bool>(
                value: choice,
                enabled: enabled,
                title: Text(choice ? 'True' : 'False'),
              ),
          ],
        ),
      );
    }
    final ui = question.answerUi as StudentChoiceAnswerUi;
    if (draft case StudentMultipleChoiceDraft(:final selectedOptionIds)) {
      final maximum = ui.maxSelections!;
      final selected = selectedOptionIds.map((id) => id.toLowerCase()).toSet();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Select up to $maximum.'),
          Semantics(
            liveRegion: true,
            label: 'Selected ${selected.length} of $maximum',
            excludeSemantics: true,
            child: Text('Selected: ${selected.length} / $maximum'),
          ),
          for (final option in ui.options)
            CheckboxListTile(
              key: ValueKey('studentOption${option.id}'),
              title: Text(option.text),
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains(option.id.toLowerCase()),
              onChanged:
                  enabled &&
                      (selected.contains(option.id.toLowerCase()) ||
                          selected.length < maximum)
                  ? (checked) {
                      final next = {...selected};
                      if (checked == true) {
                        next.add(option.id.toLowerCase());
                      } else {
                        next.remove(option.id.toLowerCase());
                      }
                      onChanged(
                        StudentMultipleChoiceDraft(selectedOptionIds: next),
                      );
                    }
                  : null,
            ),
        ],
      );
    }
    final selection = (draft as StudentSingleChoiceDraft).selectedOptionId;
    return RadioGroup<String>(
      groupValue: selection?.toLowerCase(),
      onChanged: (value) {
        if (enabled) {
          onChanged(StudentSingleChoiceDraft(selectedOptionId: value));
        }
      },
      child: Column(
        children: [
          for (final option in ui.options)
            RadioListTile<String>(
              key: ValueKey('studentOption${option.id}'),
              title: Text(option.text),
              value: option.id.toLowerCase(),
              enabled: enabled,
            ),
        ],
      ),
    );
  }
}
