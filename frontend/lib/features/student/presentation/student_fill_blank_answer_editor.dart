import 'package:flutter/material.dart';

import '../domain/student_answer_draft.dart';
import '../domain/student_question.dart';
import 'student_written_answer_editor.dart';

class StudentFillBlankAnswerEditor extends StatelessWidget {
  const StudentFillBlankAnswerEditor({
    required this.answerUi,
    required this.draft,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final StudentFillBlankAnswerUi answerUi;
  final StudentFillBlankDraft draft;
  final bool enabled;
  final ValueChanged<StudentFillBlankDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = {
      for (final entry in draft.blankTextById.entries)
        entry.key.toLowerCase(): entry.value,
    };
    final blanks = [...answerUi.blanks]
      ..sort((first, second) => first.position.compareTo(second.position));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final blank in blanks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StudentWrittenAnswerEditor(
              key: ValueKey('studentBlank${blank.id}'),
              label: 'Blank: ${blank.key}',
              text: values[blank.id.toLowerCase()] ?? '',
              enabled: enabled,
              errorText: _error(values[blank.id.toLowerCase()] ?? ''),
              onChanged: (text) => onChanged(
                StudentFillBlankDraft(
                  blankTextById: {...values, blank.id.toLowerCase(): text},
                ),
              ),
            ),
          ),
      ],
    );
  }

  String? _error(String text) =>
      text.trim().isNotEmpty && text.runes.length > 1000
      ? 'Use at most 1000 characters for this blank.'
      : null;
}
