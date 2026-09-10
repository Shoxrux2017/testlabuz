import 'package:flutter/material.dart';

import '../application/student_attempt_answer_editor_state.dart';
import '../domain/student_answer_draft.dart';
import '../domain/student_question.dart';
import 'student_choice_answer_editor.dart';
import 'student_fill_blank_answer_editor.dart';
import 'student_homework_formatters.dart';
import 'student_matching_answer_editor.dart';
import 'student_ordering_answer_editor.dart';
import 'student_topic_formatters.dart';
import 'student_written_answer_editor.dart';

class StudentQuestionAnswerEditor extends StatelessWidget {
  const StudentQuestionAnswerEditor({
    required this.state,
    required this.canEdit,
    required this.canSave,
    required this.isReconciling,
    required this.timezone,
    required this.onChanged,
    required this.onSave,
    required this.onDiscard,
    required this.onClear,
    required this.onReload,
    super.key,
  });

  final StudentQuestionAnswerEditorState state;
  final bool canEdit;
  final bool canSave;
  final bool isReconciling;
  final String timezone;
  final ValueChanged<StudentAnswerDraft> onChanged;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onClear;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final question = state.question;
    final uncertain = state.saveStatus == StudentAnswerSaveStatus.uncertain;
    final busy =
        state.saveStatus == StudentAnswerSaveStatus.saving ||
        (uncertain && isReconciling);
    final status = switch (state.saveStatus) {
      StudentAnswerSaveStatus.saving => 'Saving…',
      StudentAnswerSaveStatus.uncertain => 'Save result unconfirmed',
      StudentAnswerSaveStatus.failure => 'Could not save answer',
      StudentAnswerSaveStatus.saved => 'Saved',
      StudentAnswerSaveStatus.idle =>
        state.isDirty ? 'Unsaved changes' : 'No unsaved changes',
    };
    return StudentQuestionAnswerCard(
      key: ValueKey('studentAnswerEditor${question.id}'),
      question: question,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _editorBody(),
          if (state.validation case final validation?
              when state.draft is! StudentShortWrittenDraft &&
                  state.draft is! StudentOpenWrittenDraft) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: Text(validation)),
          ],
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              key: ValueKey('studentSaveStatus${question.id}'),
            ),
          ),
          if (state.saveStatus == StudentAnswerSaveStatus.saved &&
              state.updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last saved: ${formatStudentInstitutionInstant(state.updatedAt!, timezone) ?? 'Institution timezone unavailable'}',
            ),
          ],
          if (state.saveStatus == StudentAnswerSaveStatus.failure &&
              state.failure != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(studentAnswerSaveFailureMessage(state.failure!)),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              semanticsLabel: isReconciling
                  ? 'Reloading Attempt'
                  : 'Saving answer',
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (uncertain)
                FilledButton(
                  onPressed: isReconciling ? null : onReload,
                  child: const Text('Reload attempt'),
                )
              else ...[
                FilledButton(
                  key: ValueKey('studentSaveAnswer${question.id}'),
                  onPressed: canSave ? onSave : null,
                  child: const Text('Save answer'),
                ),
                if (state.isDirty)
                  TextButton(
                    onPressed: canEdit ? onDiscard : null,
                    child: const Text('Discard changes'),
                  ),
                if (state.draft.canClear)
                  TextButton(
                    onPressed: canEdit ? onClear : null,
                    child: const Text('Clear answer'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _editorBody() => switch (state.draft) {
    StudentSingleChoiceDraft() ||
    StudentMultipleChoiceDraft() ||
    StudentTrueFalseDraft() => StudentChoiceAnswerEditor(
      question: state.question,
      draft: state.draft,
      enabled: canEdit,
      onChanged: onChanged,
    ),
    StudentShortWrittenDraft(:final text) => StudentWrittenAnswerEditor(
      text: text,
      label: 'Question ${state.question.position}: Short answer',
      enabled: canEdit,
      errorText: state.validation,
      onChanged: (text) => onChanged(StudentShortWrittenDraft(text: text)),
    ),
    StudentOpenWrittenDraft(:final text) => StudentWrittenAnswerEditor(
      text: text,
      label: 'Question ${state.question.position}: Written answer',
      multiline: true,
      enabled: canEdit,
      errorText: state.validation,
      onChanged: (text) => onChanged(StudentOpenWrittenDraft(text: text)),
    ),
    StudentMatchingDraft() => StudentMatchingAnswerEditor(
      answerUi: state.question.answerUi as StudentMatchingAnswerUi,
      draft: state.draft as StudentMatchingDraft,
      enabled: canEdit,
      onChanged: onChanged,
    ),
    StudentOrderingDraft() => StudentOrderingAnswerEditor(
      answerUi: state.question.answerUi as StudentOrderingAnswerUi,
      draft: state.draft as StudentOrderingDraft,
      enabled: canEdit,
      onChanged: onChanged,
    ),
    StudentFillBlankDraft() => StudentFillBlankAnswerEditor(
      answerUi: state.question.answerUi as StudentFillBlankAnswerUi,
      draft: state.draft as StudentFillBlankDraft,
      enabled: canEdit,
      onChanged: onChanged,
    ),
  };
}

class StudentQuestionAnswerCard extends StatelessWidget {
  const StudentQuestionAnswerCard({
    required this.question,
    required this.body,
    super.key,
  });

  final StudentQuestion question;
  final Widget body;

  @override
  Widget build(BuildContext context) => Card(
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
          const SizedBox(height: 16),
          body,
        ],
      ),
    ),
  );
}
