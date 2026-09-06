import 'package:flutter/material.dart';

import '../domain/teacher_question.dart';
import 'teacher_homework_formatters.dart';

class TeacherQuestionReadView extends StatelessWidget {
  const TeacherQuestionReadView({required this.question, super.key});

  final TeacherQuestion question;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('teacherHomeworkQuestion${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Question ${question.position}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(teacherQuestionTypeLabel(question.type))),
                Chip(
                  label: Text(
                    '${formatTeacherHomeworkPoints(question.points)} points',
                  ),
                ),
                Chip(
                  label: Text(
                    teacherQuestionCheckingModeLabel(question.checkingMode),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Prompt', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 3),
            SelectableText(question.prompt),
            if (question.instructions != null) ...[
              const SizedBox(height: 12),
              Text(
                'Instructions',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 3),
              SelectableText(question.instructions!),
            ],
            const SizedBox(height: 14),
            TeacherQuestionConfigurationReadView(
              configuration: question.configuration,
            ),
          ],
        ),
      ),
    );
  }
}

class TeacherQuestionConfigurationReadView extends StatelessWidget {
  const TeacherQuestionConfigurationReadView({
    required this.configuration,
    super.key,
  });

  final TeacherQuestionConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    return switch (configuration) {
      TeacherChoiceQuestionConfiguration(:final options) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Options', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    option.isCorrect
                        ? Icons.check_circle_outline
                        : Icons.circle_outlined,
                    size: 20,
                    semanticLabel: option.isCorrect
                        ? 'Correct option'
                        : 'Option',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.isCorrect
                          ? '${option.position}. ${option.text} — Correct'
                          : '${option.position}. ${option.text}',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      TeacherTrueFalseQuestionConfiguration(:final correctValue) => Text(
        'Correct answer: ${correctValue ? 'True' : 'False'}',
      ),
      TeacherShortWrittenAutomaticConfiguration(:final acceptedAnswers) =>
        _AcceptedAnswers(answers: acceptedAnswers),
      TeacherEmptyQuestionConfiguration() => const Text('Manual review'),
      TeacherFileBasedQuestionConfiguration(:final allowedExtensions) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Allowed files: '
            '${allowedExtensions.map((value) => value.toUpperCase()).join(', ')}',
          ),
          const SizedBox(height: 6),
          const Text('Manual review'),
        ],
      ),
      TeacherMatchingQuestionConfiguration(:final pairs) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Correct pairs', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          for (final pair in pairs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('${pair.left} \u2192 ${pair.right}'),
            ),
        ],
      ),
      TeacherOrderingQuestionConfiguration(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Correct order', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('${item.correctPosition}. ${item.text}'),
            ),
        ],
      ),
      TeacherFillInBlankQuestionConfiguration(:final blanks) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Blanks', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          for (final blank in blanks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${blank.key}: ${blank.acceptedAnswers.join(', ')}'),
            ),
        ],
      ),
    };
  }
}

class _AcceptedAnswers extends StatelessWidget {
  const _AcceptedAnswers({required this.answers});

  final List<String> answers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Accepted answers', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        for (final answer in answers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text('• $answer'),
          ),
      ],
    );
  }
}
