import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
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
    required this.isReconciling,
    required this.timezone,
    required this.onChanged,
    required this.onCommit,
    required this.onClear,
    required this.onReload,
    this.recoveryLabel = 'Reload attempt',
    this.failureMessage = studentAnswerSaveFailureMessage,
    super.key,
  });

  final StudentQuestionAnswerEditorState state;
  final bool canEdit;
  final bool isReconciling;
  final String timezone;
  final ValueChanged<StudentAnswerDraft> onChanged;

  /// Saves this Question at once, for example when a text field loses focus.
  final VoidCallback onCommit;
  final VoidCallback onClear;
  final VoidCallback onReload;

  /// Text for a rejected save; Blitz adds its own timing codes.
  final String Function(ApiFailure failure) failureMessage;

  /// Action that re-reads the Attempt after an unconfirmed save.
  final String recoveryLabel;

  @override
  Widget build(BuildContext context) {
    final question = state.question;
    final uncertain = state.saveStatus == StudentAnswerSaveStatus.uncertain;
    final busy =
        state.saveStatus == StudentAnswerSaveStatus.saving ||
        (uncertain && isReconciling);
    final failure = state.failure;
    final failed =
        state.saveStatus == StudentAnswerSaveStatus.failure && failure != null;
    final invalid = state.isDirty && state.validation != null;
    // Autosave changes the status at every typing pause, so only messages
    // that need the Student's attention are announced.
    final announced = uncertain || failed || invalid;
    final status = uncertain
        ? 'Save not confirmed. Checking…'
        : failed
        ? failureMessage(failure)
        : invalid
        ? state.validation!
        : state.isDirty || state.saveStatus == StudentAnswerSaveStatus.saving
        ? 'Saving…'
        : state.serverAnswer != null
        ? 'Saved'
        : 'Not answered';
    final showsLastSaved =
        !state.isDirty &&
        state.saveStatus != StudentAnswerSaveStatus.saving &&
        state.serverAnswer != null &&
        state.updatedAt != null;
    return StudentQuestionAnswerCard(
      key: ValueKey('studentAnswerEditor${question.id}'),
      question: question,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _editorBody(),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: announced,
            child: Text(
              status,
              key: ValueKey('studentSaveStatus${question.id}'),
            ),
          ),
          if (showsLastSaved) ...[
            const SizedBox(height: 4),
            Text(
              'Last saved: ${formatStudentInstitutionInstant(state.updatedAt!, timezone) ?? 'Institution timezone unavailable'}',
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
                  child: Text(recoveryLabel),
                )
              else if (state.draft.canClear)
                TextButton(
                  onPressed: canEdit ? onClear : null,
                  child: const Text('Clear answer'),
                ),
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
      onFocusLost: onCommit,
    ),
    StudentOpenWrittenDraft(:final text) => StudentWrittenAnswerEditor(
      text: text,
      label: 'Question ${state.question.position}: Written answer',
      multiline: true,
      enabled: canEdit,
      errorText: state.validation,
      onChanged: (text) => onChanged(StudentOpenWrittenDraft(text: text)),
      onFocusLost: onCommit,
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
      onFocusLost: onCommit,
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
