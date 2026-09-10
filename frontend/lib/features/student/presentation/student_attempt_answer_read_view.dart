import 'package:flutter/material.dart';

import '../domain/student_homework_attempt.dart';
import '../domain/student_question.dart';
import 'student_topic_formatters.dart';

class StudentAttemptAnswerReadView extends StatelessWidget {
  const StudentAttemptAnswerReadView({
    required this.question,
    required this.answer,
    super.key,
  });

  final StudentQuestion question;
  final StudentAttemptAnswerState? answer;

  @override
  Widget build(BuildContext context) {
    final savedAnswer = answer;
    return Padding(
      key: ValueKey('studentAttemptAnswer${question.id}'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            savedAnswer == null ? 'Not answered' : 'Saved answer',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (savedAnswer != null) ...[
            const SizedBox(height: 8),
            ..._savedValues(savedAnswer.value).map(
              (value) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _savedValues(StudentAttemptAnswerValue value) {
    // The DTO has verified each saved child against this safe Question.
    return switch (value) {
      StudentChoiceAnswerValue(:final selectedOptionIds) => [
        for (final id in selectedOptionIds)
          (question.answerUi as StudentChoiceAnswerUi).options
              .firstWhere(
                (option) => option.id.toLowerCase() == id.toLowerCase(),
              )
              .text,
      ],
      StudentBooleanAnswerValue(:final value) => [value ? 'True' : 'False'],
      StudentTextAnswerValue(:final text) => [text],
      StudentMatchingAnswerValue(:final pairs) => [
        for (final pair in pairs)
          '${(question.answerUi as StudentMatchingAnswerUi).leftItems.firstWhere((item) => item.id.toLowerCase() == pair.leftItemId.toLowerCase()).text}'
              ' → '
              '${(question.answerUi as StudentMatchingAnswerUi).rightItems.firstWhere((item) => item.id.toLowerCase() == pair.rightItemId.toLowerCase()).text}',
      ],
      StudentOrderingAnswerValue(:final items) => _orderedValues(items),
      StudentFillBlankAnswerValue(:final values) => [
        for (final entry in values)
          '${(question.answerUi as StudentFillBlankAnswerUi).blanks.firstWhere((blank) => blank.id.toLowerCase() == entry.blankId.toLowerCase()).key}'
              ' → ${entry.text}',
      ],
      StudentFileAnswerValue(:final file) => [
        file.originalName,
        'Extension: ${file.extension}',
        'Size: ${formatStudentMaterialBytes(file.sizeBytes)}',
      ],
    };
  }

  List<String> _orderedValues(List<StudentOrderingAnswerItem> items) {
    final ordered = [...items]
      ..sort((left, right) => left.position.compareTo(right.position));
    final questionItems = (question.answerUi as StudentOrderingAnswerUi).items;
    return [
      for (final item in ordered)
        '${item.position}. ${questionItems.firstWhere((questionItem) => questionItem.id.toLowerCase() == item.itemId.toLowerCase()).text}',
    ];
  }
}
