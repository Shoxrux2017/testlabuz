import 'package:flutter/material.dart';

import '../domain/student_answer_draft.dart';
import '../domain/student_question.dart';

class StudentOrderingAnswerEditor extends StatelessWidget {
  const StudentOrderingAnswerEditor({
    required this.answerUi,
    required this.draft,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final StudentOrderingAnswerUi answerUi;
  final StudentOrderingDraft draft;
  final bool enabled;
  final ValueChanged<StudentOrderingDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final assignments = {
      for (final entry in draft.itemToPosition.entries)
        entry.key.toLowerCase(): entry.value,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in answerUi.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              label: 'Position: ${item.text}',
              container: true,
              child: InputDecorator(
                decoration: InputDecoration(
                  label: Text('Position: ${item.text}', maxLines: 3),
                  border: const OutlineInputBorder(),
                  enabled: enabled,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: ValueKey('studentOrdering${item.id}'),
                    isExpanded: true,
                    itemHeight: null,
                    value: assignments[item.id.toLowerCase()] ?? 0,
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('Unassigned'),
                      ),
                      if (assignments[item.id.toLowerCase()]
                          case final selected?
                          when selected != 0 &&
                              (selected < 1 ||
                                  selected > answerUi.items.length))
                        DropdownMenuItem(
                          value: selected,
                          enabled: false,
                          child: Text('Unavailable position: $selected'),
                        ),
                      for (
                        var position = 1;
                        position <= answerUi.items.length;
                        position++
                      )
                        DropdownMenuItem(
                          value: position,
                          enabled: !assignments.entries.any(
                            (entry) =>
                                entry.key != item.id.toLowerCase() &&
                                entry.value == position,
                          ),
                          child: Text('$position'),
                        ),
                    ],
                    onChanged: enabled
                        ? (value) {
                            final next = {...assignments};
                            if (value == null || value == 0) {
                              next.remove(item.id.toLowerCase());
                            } else {
                              next[item.id.toLowerCase()] = value;
                            }
                            onChanged(
                              StudentOrderingDraft(itemToPosition: next),
                            );
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
