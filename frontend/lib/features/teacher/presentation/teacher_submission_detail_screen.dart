import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/scoring/score_display.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_official_score_controller.dart';
import '../application/teacher_official_score_state.dart';
import '../application/teacher_session_key.dart';
import '../application/teacher_submission_detail_controller.dart';
import '../application/teacher_submission_detail_state.dart';
import '../application/teacher_submission_file_controller.dart';
import '../application/teacher_submission_file_state.dart';
import '../application/teacher_submission_review_controller.dart';
import '../application/teacher_submission_review_state.dart';
import '../domain/teacher_official_score.dart';
import '../domain/teacher_submission.dart';
import '../domain/teacher_submission_detail.dart';
import '../domain/teacher_submission_review.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_learning_material_section.dart';
import 'teacher_review_formatters.dart';

/// One submission with every Question and the Student's answers
/// (`S09-FE-003A`), where the Teacher reviews the manual answers
/// (`S09-FE-003B`) next to the Student's official score (`S09-FE-003C`);
/// desktop only.
class TeacherSubmissionDetailScreen extends ConsumerWidget {
  const TeacherSubmissionDetailScreen({required this.submissionId, super.key});

  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherSubmissionDetailControllerProvider(submissionId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final fileProvider = teacherSubmissionFileControllerProvider(submissionId);
    final reviewProvider = teacherSubmissionReviewControllerProvider(
      submissionId,
    );
    final review = ref.watch(reviewProvider);
    final reviewController = ref.read(reviewProvider.notifier);
    final timezone = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey?.institutionTimezone;

    ref.listen<TeacherSubmissionFileState>(fileProvider, (previous, next) {
      final feedback = next.feedback;
      if (next.status != TeacherSubmissionFileStatus.idle ||
          feedback == null ||
          !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(feedback)));
      ref.read(fileProvider.notifier).consumeFeedback();
    });
    ref.listen<TeacherSubmissionReviewState>(reviewProvider, (previous, next) {
      final feedback = next.successFeedback;
      if (feedback == null || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(feedback)));
      ref.read(reviewProvider.notifier).consumeFeedback();
    });

    final detail = state.detail;
    final showsDetail =
        detail != null &&
        state.status != TeacherSubmissionDetailStatus.initial &&
        state.status != TeacherSubmissionDetailStatus.loading &&
        state.status != TeacherSubmissionDetailStatus.notFound;
    final changedCount = detail == null
        ? 0
        : buildTeacherSubmissionReview(detail, review.drafts).changedCount;
    final reviewable =
        showsDetail &&
        detail.questions.any(
          (question) =>
              question.answer != null &&
              isTeacherReviewableAnswer(question.answer!),
        );
    return Scaffold(
      key: const Key('teacherSubmissionDetailScreen'),
      appBar: AppBar(
        title: const Text('Submission'),
        leading: IconButton(
          key: const Key('teacherSubmissionBackButton'),
          tooltip: 'Back to review queue',
          onPressed: review.isBusy
              ? null
              : () async {
                  if (changedCount > 0 && !await _confirmDiscard(context)) {
                    return;
                  }
                  if (!context.mounted) {
                    return;
                  }
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutePaths.teacherReviews);
                  }
                },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            key: const Key('teacherSubmissionRefreshButton'),
            tooltip: 'Refresh submission',
            onPressed: state.isLoading || review.isBusy
                ? null
                : () {
                    if (state.status == TeacherSubmissionDetailStatus.error) {
                      controller.retry();
                    } else {
                      controller.refresh();
                    }
                    if (detail != null) {
                      ref
                          .read(
                            teacherOfficialScoreControllerProvider(
                              TeacherOfficialScoreTarget.ofSubmission(
                                detail.submission,
                              ),
                            ).notifier,
                          )
                          .refresh();
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          TeacherSubmissionDetailStatus.initial ||
          TeacherSubmissionDetailStatus.loading => const Center(
            child: CircularProgressIndicator(
              key: Key('teacherSubmissionDetailLoading'),
              semanticsLabel: 'Loading submission',
            ),
          ),
          TeacherSubmissionDetailStatus.notFound => const Center(
            child: Text('This submission is not available.'),
          ),
          _ when detail == null => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('The submission could not be loaded.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('teacherSubmissionDetailRetryButton'),
                  onPressed: controller.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          _ => _DetailBody(
            detail: detail,
            state: state,
            timezone: timezone,
            submissionId: submissionId,
            onRetry: controller.retry,
          ),
        },
      ),
      bottomNavigationBar: reviewable
          ? _ReviewBar(
              review: review,
              changedCount: changedCount,
              canSave:
                  changedCount > 0 &&
                  !review.isBusy &&
                  state.status == TeacherSubmissionDetailStatus.data,
              onSave: () => reviewController.save(),
              onDiscard: reviewController.discardChanges,
            )
          : null,
    );
  }
}

Future<bool> _confirmDiscard(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard unsaved review?'),
      content: const Text(
        'The points and feedback you entered have not been saved.',
      ),
      actions: [
        TextButton(
          key: const Key('teacherSubmissionDiscardCancelButton'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          key: const Key('teacherSubmissionDiscardConfirmButton'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard ?? false;
}

class _ReviewBar extends StatelessWidget {
  const _ReviewBar({
    required this.review,
    required this.changedCount,
    required this.canSave,
    required this.onSave,
    required this.onDiscard,
  });

  final TeacherSubmissionReviewState review;
  final int changedCount;
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final failureMessage = review.failureMessage;
    return Material(
      key: const Key('teacherSubmissionReviewBar'),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (review.isBusy)
              const LinearProgressIndicator(
                key: Key('teacherSubmissionReviewProgress'),
                semanticsLabel: 'Saving review',
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(switch (changedCount) {
                          0 => 'No unsaved changes',
                          1 => '1 answer changed',
                          _ => '$changedCount answers changed',
                        }),
                        if (failureMessage != null)
                          Semantics(
                            key: const Key('teacherSubmissionReviewMessage'),
                            liveRegion: true,
                            child: Text(
                              failureMessage,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('teacherSubmissionReviewDiscardButton'),
                    onPressed: changedCount > 0 && !review.isBusy
                        ? onDiscard
                        : null,
                    child: const Text('Discard changes'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('teacherSubmissionReviewSaveButton'),
                    onPressed: canSave ? onSave : null,
                    child: const Text('Save review'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.state,
    required this.timezone,
    required this.submissionId,
    required this.onRetry,
  });

  final TeacherSubmissionDetail detail;
  final TeacherSubmissionDetailState state;
  final String? timezone;
  final String submissionId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.status == TeacherSubmissionDetailStatus.refreshing) ...[
                const LinearProgressIndicator(
                  semanticsLabel: 'Refreshing submission',
                ),
                const SizedBox(height: 12),
              ],
              if (state.isStale) ...[
                MaterialBanner(
                  key: const Key('teacherSubmissionDetailStaleMessage'),
                  content: const Text(
                    'The displayed submission may be out of date.',
                  ),
                  actions: [
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Card(
                key: const Key('teacherSubmissionHeader'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TeacherSubmissionSummary(
                    submission: detail.submission,
                    timezone: timezone,
                    submittedAt: detail.submittedAt,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _OfficialScorePanel(
                submission: detail.submission,
                timezone: timezone,
              ),
              for (final question in detail.questions) ...[
                const SizedBox(height: 12),
                _QuestionCard(question: question, submissionId: submissionId),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The Student's official score for this task, evaluated live by the
/// server.
class _OfficialScorePanel extends ConsumerWidget {
  const _OfficialScorePanel({required this.submission, required this.timezone});

  final TeacherSubmission submission;
  final String? timezone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherOfficialScoreControllerProvider(
      TeacherOfficialScoreTarget.ofSubmission(submission),
    );
    final state = ref.watch(provider);
    final score = state.score;
    final retry = OutlinedButton.icon(
      key: const Key('teacherOfficialScoreRetryButton'),
      onPressed: state.isLoading ? null : ref.read(provider.notifier).retry,
      icon: const Icon(Icons.refresh),
      label: const Text('Retry'),
    );

    return Card(
      key: const Key('teacherOfficialScorePanel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Official score',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 6),
            ...switch (state.status) {
              TeacherOfficialScoreLoadStatus.initial ||
              TeacherOfficialScoreLoadStatus.loading => [
                const LinearProgressIndicator(
                  key: Key('teacherOfficialScoreLoading'),
                  semanticsLabel: 'Loading official score',
                ),
              ],
              TeacherOfficialScoreLoadStatus.notFound => [
                const Text('The official score is not available.'),
              ],
              _ when score == null => [
                const Text('The official score could not be loaded.'),
                const SizedBox(height: 8),
                retry,
              ],
              _ => [
                if (state.status == TeacherOfficialScoreLoadStatus.refreshing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: LinearProgressIndicator(
                      key: Key('teacherOfficialScoreRefreshing'),
                      semanticsLabel: 'Refreshing official score',
                    ),
                  ),
                ..._officialScoreLines(
                  score,
                  submission.id,
                  timezone,
                ).map(Text.new),
                if (state.isStale) ...[
                  const SizedBox(height: 8),
                  const Text('The official score may be out of date.'),
                  const SizedBox(height: 8),
                  retry,
                ],
              ],
            },
          ],
        ),
      ),
    );
  }
}

List<String> _officialScoreLines(
  TeacherOfficialScore score,
  String submissionId,
  String? timezone,
) {
  return switch (score.status) {
    TeacherOfficialScoreStatus.ready => [
      'Score ${formatScoreOneDecimal(score.normalizedScore!)}',
      [
        'Attempt ${score.attemptNumber}',
        switch (score.selectionPolicy!) {
          TeacherOfficialScoreSelectionPolicy.highestValidCompleted =>
            'Best checked attempt',
          TeacherOfficialScoreSelectionPolicy.validNormalBlitz =>
            'Blitz attempt',
          TeacherOfficialScoreSelectionPolicy
              .approvedBlitzExceptionReplacement =>
            'Replacement attempt',
        },
        if (score.officialAttemptId!.toLowerCase() ==
            submissionId.toLowerCase())
          'This submission',
      ].join(' · '),
      'Selected ${formatTeacherReviewTime(score.selectedAt!, timezone)}',
    ],
    TeacherOfficialScoreStatus.notApplicable => [
      'Practice task: no official score.',
    ],
    TeacherOfficialScoreStatus.waitingForReplacement => [
      "Waiting for the Student's replacement attempt.",
    ],
    TeacherOfficialScoreStatus.automaticCheckingPending => [
      'Waiting for automatic checking.',
    ],
    TeacherOfficialScoreStatus.waitingForTeacherReview => [
      'Waiting for Teacher review.',
    ],
    TeacherOfficialScoreStatus.noCompletedAttempt => [
      'No completed attempt counts yet.',
    ],
  };
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.submissionId});

  final TeacherReviewQuestion question;
  final String submissionId;

  @override
  Widget build(BuildContext context) {
    final answer = question.answer;
    return Card(
      key: Key('teacherSubmissionQuestion:${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Question ${question.position} · '
                '${teacherQuestionTypeLabel(question.type)} · '
                '${formatTeacherReviewPoints(question.points)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 6),
            Text(question.prompt),
            const SizedBox(height: 10),
            if (answer == null)
              const Text('No answer.')
            else ...[
              ..._answerLines(
                question.configuration,
                answer.value,
              ).map(Text.new),
              if (answer.value case TeacherReviewFileValue(:final file))
                _SubmittedFile(file: file, submissionId: submissionId),
              const SizedBox(height: 8),
              Text(_statusLine(answer, question.points)),
              if (answer.feedback case final feedback?)
                Text('Feedback: $feedback'),
              if (isTeacherReviewableAnswer(answer))
                _ReviewFields(
                  key: ValueKey<String>(answer.id),
                  question: question,
                  answer: answer,
                  submissionId: submissionId,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The Teacher's points and feedback for one reviewable answer.
class _ReviewFields extends ConsumerStatefulWidget {
  const _ReviewFields({
    required this.question,
    required this.answer,
    required this.submissionId,
    super.key,
  });

  final TeacherReviewQuestion question;
  final TeacherReviewAnswer answer;
  final String submissionId;

  @override
  ConsumerState<_ReviewFields> createState() => _ReviewFieldsState();
}

class _ReviewFieldsState extends ConsumerState<_ReviewFields> {
  final _pointsController = TextEditingController();
  final _feedbackController = TextEditingController();

  @override
  void dispose() {
    _pointsController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = teacherSubmissionReviewControllerProvider(
      widget.submissionId,
    );
    final review = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final answer = widget.answer;
    final draft = review.drafts[answer.id];
    // Untouched fields follow the saved answer; typed text is kept.
    _setText(
      _pointsController,
      draft?.pointsText ?? teacherReviewSavedPointsText(answer),
    );
    _setText(_feedbackController, draft?.feedbackText ?? answer.feedback ?? '');
    final errors = review.errors[answer.id];
    final points = formatTeacherReviewPoints(widget.question.points);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  key: Key('teacherSubmissionReviewPoints:${answer.id}'),
                  controller: _pointsController,
                  enabled: !review.isBusy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Points',
                    helperText: '0 to $points',
                    errorMaxLines: 3,
                    errorText: switch (errors?.points) {
                      TeacherReviewPointsError.missing => 'Enter points.',
                      TeacherReviewPointsError.invalid =>
                        'Enter 0 to $points with up to 6 decimal places.',
                      null => null,
                    },
                  ),
                  onChanged: (text) => controller.editPoints(answer.id, text),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  key: Key('teacherSubmissionReviewFeedback:${answer.id}'),
                  controller: _feedbackController,
                  enabled: !review.isBusy,
                  minLines: 2,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Feedback (optional)',
                    errorText: errors?.feedbackTooLong ?? false
                        ? 'Use at most 2000 characters.'
                        : null,
                  ),
                  onChanged: (text) => controller.editFeedback(answer.id, text),
                ),
              ),
            ],
          ),
          if (errors?.notReviewable ?? false) ...[
            const SizedBox(height: 6),
            Text(
              'This answer can no longer be reviewed. Refresh the submission.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

void _setText(TextEditingController controller, String value) {
  if (controller.text != value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

String _statusLine(TeacherReviewAnswer answer, double points) {
  String awarded() =>
      '${formatTeacherHomeworkPoints(answer.awardedPoints!)} of '
      '${formatTeacherReviewPoints(points)}';
  return switch (answer.checkingStatus) {
    TeacherReviewAnswerStatus.pending => 'Waiting for automatic checking',
    TeacherReviewAnswerStatus.autoChecked =>
      'Checked automatically · ${awarded()}',
    TeacherReviewAnswerStatus.waitingForTeacherReview => 'Waiting for review',
    TeacherReviewAnswerStatus.teacherChecked =>
      'Reviewed by ${answer.checkedBy!.fullName} · ${awarded()}',
  };
}

/// The Student's answer next to the correct answer, one line each.
List<String> _answerLines(
  TeacherReviewConfiguration configuration,
  TeacherReviewAnswerValue value,
) {
  String yesNo(bool value) => value ? 'True' : 'False';
  return switch ((configuration, value)) {
    (
      TeacherReviewChoiceConfiguration(:final options),
      TeacherReviewChoiceValue(:final selectedOptionIds),
    ) =>
      [
        for (final option in options)
          [
            option.text,
            if (selectedOptionIds.contains(option.id)) 'Student answer',
            if (option.isCorrect) 'Correct',
          ].join(' · '),
      ],
    (
      TeacherReviewTrueFalseConfiguration(:final correctValue),
      TeacherReviewTrueFalseValue(:final value),
    ) =>
      [
        'Student answer: ${yesNo(value)}',
        'Correct answer: ${yesNo(correctValue)}',
      ],
    (
      TeacherReviewShortWrittenConfiguration(:final acceptedAnswers),
      TeacherReviewTextValue(:final text),
    ) =>
      [
        'Student answer: $text',
        if (acceptedAnswers.isNotEmpty)
          'Accepted answers: ${acceptedAnswers.join(', ')}',
      ],
    (
      TeacherReviewOpenWrittenConfiguration(),
      TeacherReviewTextValue(:final text),
    ) =>
      ['Student answer: $text'],
    (
      TeacherReviewMatchingConfiguration(:final pairs),
      TeacherReviewMatchingValue(pairs: final selections),
    ) =>
      () {
        final lefts = {for (final pair in pairs) pair.leftItemId: pair.left};
        final rights = {for (final pair in pairs) pair.rightItemId: pair.right};
        final order = [for (final pair in pairs) pair.leftItemId];
        // In the configured left order, so both lists read side by side.
        final sorted = [...selections]
          ..sort(
            (left, right) => order
                .indexOf(left.leftItemId)
                .compareTo(order.indexOf(right.leftItemId)),
          );
        return [
          'Student matches:',
          for (final selection in sorted)
            '${lefts[selection.leftItemId]} → ${rights[selection.rightItemId]}',
          'Correct matches:',
          for (final pair in pairs) '${pair.left} → ${pair.right}',
        ];
      }(),
    (
      TeacherReviewOrderingConfiguration(:final items),
      TeacherReviewOrderingValue(items: final selections),
    ) =>
      () {
        final texts = {for (final item in items) item.id: item.text};
        final ordered = [...selections]
          ..sort((left, right) => left.position.compareTo(right.position));
        return [
          'Student order:',
          for (final selection in ordered)
            '${selection.position}. ${texts[selection.itemId]}',
          'Correct order:',
          for (final item in items) '${item.correctPosition}. ${item.text}',
        ];
      }(),
    (
      TeacherReviewFillInBlankConfiguration(:final blanks),
      TeacherReviewFillInBlankValue(:final values),
    ) =>
      () {
        final texts = {for (final value in values) value.blankId: value.text};
        return [
          'Student answers:',
          for (final blank in blanks)
            if (texts[blank.id] case final text?) '${blank.key}: $text',
          'Accepted answers:',
          for (final blank in blanks)
            '${blank.key}: ${blank.acceptedAnswers.join(', ')}',
        ];
      }(),
    (TeacherReviewFileConfiguration(), TeacherReviewFileValue()) => const [],
    _ => throw StateError('An answer value does not match its Question.'),
  };
}

class _SubmittedFile extends ConsumerWidget {
  const _SubmittedFile({required this.file, required this.submissionId});

  final TeacherReviewFile file;
  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherSubmissionFileControllerProvider(submissionId);
    final transfer = ref.watch(provider);
    final failed =
        transfer.status == TeacherSubmissionFileStatus.failure &&
        transfer.fileId == file.id;
    final transferring = transfer.isBusy && transfer.fileId == file.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${file.originalName} · ${file.extension.toUpperCase()} · '
          '${formatTeacherMaterialBytes(file.sizeBytes)}',
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          key: Key('teacherSubmissionFileSaveButton:${file.id}'),
          onPressed: transfer.isBusy
              ? null
              : () => ref.read(provider.notifier).saveFile(file),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Save file'),
        ),
        if (transferring) ...[
          const SizedBox(height: 6),
          const LinearProgressIndicator(
            key: Key('teacherSubmissionFileProgress'),
            semanticsLabel: 'Downloading file',
          ),
        ],
        if (failed && transfer.feedback != null) ...[
          const SizedBox(height: 6),
          Text(transfer.feedback!),
        ],
      ],
    );
  }
}
