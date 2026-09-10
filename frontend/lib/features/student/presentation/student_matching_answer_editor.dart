import 'package:flutter/material.dart';

import '../domain/student_answer_draft.dart';
import '../domain/student_question.dart';

class StudentMatchingAnswerEditor extends StatelessWidget {
  const StudentMatchingAnswerEditor({
    required this.answerUi,
    required this.draft,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final StudentMatchingAnswerUi answerUi;
  final StudentMatchingDraft draft;
  final bool enabled;
  final ValueChanged<StudentMatchingDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final assignments = {
      for (final entry in draft.leftToRight.entries)
        entry.key.toLowerCase(): entry.value.toLowerCase(),
    };
    final rightIds = answerUi.rightItems
        .map((item) => item.id.toLowerCase())
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final left in answerUi.leftItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              label: 'Match: ${left.text}',
              container: true,
              child: InputDecorator(
                decoration: InputDecoration(
                  label: Text('Match: ${left.text}', maxLines: 3),
                  border: const OutlineInputBorder(),
                  enabled: enabled,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey('studentMatching${left.id}'),
                    isExpanded: true,
                    itemHeight: null,
                    value: assignments[left.id.toLowerCase()] ?? '',
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Not matched'),
                      ),
                      if (assignments[left.id.toLowerCase()]
                          case final selected?
                          when !rightIds.contains(selected))
                        DropdownMenuItem(
                          value: selected,
                          enabled: false,
                          child: const Text('Unavailable match'),
                        ),
                      for (final right in answerUi.rightItems)
                        DropdownMenuItem(
                          value: right.id.toLowerCase(),
                          enabled: !assignments.entries.any(
                            (entry) =>
                                entry.key != left.id.toLowerCase() &&
                                entry.value == right.id.toLowerCase(),
                          ),
                          child: Text(right.text),
                        ),
                    ],
                    onChanged: enabled
                        ? (value) {
                            final next = {...assignments};
                            if (value == null || value.isEmpty) {
                              next.remove(left.id.toLowerCase());
                            } else {
                              next[left.id.toLowerCase()] = value;
                            }
                            onChanged(StudentMatchingDraft(leftToRight: next));
                          }
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
