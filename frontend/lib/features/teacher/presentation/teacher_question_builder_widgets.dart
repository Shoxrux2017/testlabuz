import 'package:flutter/material.dart';

import '../application/teacher_question_builder_state.dart';
import '../domain/teacher_question.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_question_read_view.dart';

/// One authored Question with its builder actions.
class TeacherQuestionBuilderCard extends StatelessWidget {
  const TeacherQuestionBuilderCard({
    super.key,
    required this.question,
    required this.ordinal,
    required this.canEdit,
    required this.canDelete,
    required this.canMove,
    required this.showActions,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final TeacherQuestion question;
  final int ordinal;
  final bool canEdit;
  final bool canDelete;
  final bool canMove;
  final bool showActions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('teacherQuestionBuilderCard${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Question $ordinal',
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
            const SizedBox(height: 10),
            Text('Prompt', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 3),
            SelectableText(question.prompt),
            if (question.instructions != null) ...[
              const SizedBox(height: 10),
              Text(
                'Instructions',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 3),
              SelectableText(question.instructions!),
            ],
            const SizedBox(height: 12),
            TeacherQuestionConfigurationReadView(
              configuration: question.configuration,
            ),
            if (showActions) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    key: ValueKey('teacherQuestionEdit${question.id}'),
                    onPressed: canEdit ? onEdit : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    key: ValueKey('teacherQuestionDelete${question.id}'),
                    onPressed: canDelete ? onDelete : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                  IconButton(
                    key: ValueKey('teacherQuestionMoveUp${question.id}'),
                    tooltip: 'Move Question $ordinal up',
                    onPressed: canMove ? onMoveUp : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    key: ValueKey('teacherQuestionMoveDown${question.id}'),
                    tooltip: 'Move Question $ordinal down',
                    onPressed: canMove ? onMoveDown : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TeacherQuestionBuilderMessage extends StatelessWidget {
  const TeacherQuestionBuilderMessage({
    required this.message,
    this.isError = false,
    this.onDismiss,
    super.key,
  });

  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: isError ? colors.errorContainer : colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(child: Text(message)),
              if (onDismiss != null)
                IconButton(
                  tooltip: 'Dismiss message',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Questions in the staged local order, or the authoritative order when the
/// staged IDs no longer describe the same Question set.
List<TeacherQuestion> teacherQuestionsInDraftOrder(
  List<TeacherQuestion> questions,
  TeacherQuestionBuilderState state,
) {
  final authoritative = [...questions]
    ..sort((left, right) => left.position.compareTo(right.position));
  if (!state.orderInitialized ||
      state.draftOrderIds.length != authoritative.length) {
    return authoritative;
  }

  final byId = <String, TeacherQuestion>{
    for (final question in authoritative) question.id.toLowerCase(): question,
  };
  final ordered = <TeacherQuestion>[];
  for (final id in state.draftOrderIds) {
    final question = byId.remove(id.toLowerCase());
    if (question == null) {
      return authoritative;
    }
    ordered.add(question);
  }
  return byId.isEmpty ? ordered : authoritative;
}
