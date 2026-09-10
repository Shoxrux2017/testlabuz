import 'package:flutter/material.dart';

import '../domain/student_question.dart';
import 'student_homework_formatters.dart';
import 'student_topic_formatters.dart';

class StudentQuestionReadView extends StatelessWidget {
  const StudentQuestionReadView({required this.question, super.key});

  final StudentQuestion question;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('studentQuestion${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${question.position} · '
              '${studentQuestionTypeLabel(question.type)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: SelectableText(
                question.prompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (question.instructions case final instructions?) ...[
              const SizedBox(height: 8),
              SelectableText(instructions),
            ],
            const SizedBox(height: 8),
            Text('Points: ${formatStudentHomeworkPoints(question.points)}'),
            const SizedBox(height: 12),
            _answerStructure(),
          ],
        ),
      ),
    );
  }

  Widget _answerStructure() {
    return switch (question.answerUi) {
      StudentChoiceAnswerUi(:final options, :final maxSelections) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (maxSelections != null) ...[
            Text('Select up to $maxSelections when answering.'),
            const SizedBox(height: 8),
          ],
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• ${option.text}'),
            ),
        ],
      ),
      StudentEmptyAnswerUi() => Text(switch (question.type) {
        StudentQuestionType.trueFalse => 'True / False answer',
        StudentQuestionType.shortWritten => 'Short written answer',
        _ => 'Written answer',
      }),
      StudentFileAnswerUi(:final allowedExtensions, :final maxSizeBytes) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Allowed: '
              '${allowedExtensions.map((extension) => extension.toUpperCase()).join(', ')}',
            ),
            const SizedBox(height: 8),
            Text(
              'Maximum file size: ${formatStudentMaterialBytes(maxSizeBytes)}',
            ),
          ],
        ),
      StudentMatchingAnswerUi(:final leftItems, :final rightItems) =>
        LayoutBuilder(
          builder: (context, constraints) {
            final left = _MatchingItems(
              key: ValueKey('studentMatchingLeft${question.id}'),
              heading: 'Left items',
              items: leftItems,
            );
            final right = _MatchingItems(
              key: ValueKey('studentMatchingRight${question.id}'),
              heading: 'Right items',
              items: rightItems,
            );
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 16), right],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 24),
                Expanded(child: right),
              ],
            );
          },
        ),
      StudentOrderingAnswerUi(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• ${item.text}'),
            ),
        ],
      ),
      StudentFillBlankAnswerUi(:final blanks) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final blank in blanks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Blank ${blank.position}: ${blank.key}'),
            ),
        ],
      ),
    };
  }
}

class _MatchingItems extends StatelessWidget {
  const _MatchingItems({required this.heading, required this.items, super.key});

  final String heading;
  final List<StudentMatchingItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(heading, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('• ${item.text}'),
          ),
      ],
    );
  }
}
