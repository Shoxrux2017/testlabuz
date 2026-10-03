import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_session_key.dart';
import '../application/teacher_topic_result_action_controller.dart';
import '../application/teacher_topic_result_bulk_action_controller.dart';
import '../application/teacher_topic_result_target.dart';
import '../domain/teacher_topic_result.dart';
import '../domain/teacher_topic_result_mutation.dart';

/// Release and close for one result, from the server's flags: release on
/// desktop and mobile, close on desktop only (`S10-FE-D1`).
class TeacherTopicResultActionBar extends ConsumerWidget {
  const TeacherTopicResultActionBar({
    required this.target,
    required this.result,
    super.key,
  });

  final TeacherTopicResultTarget target;
  final TeacherTopicResult result;

  /// Whether [result] offers any action on [surface].
  static bool offersAction(
    TeacherTopicResult result,
    AppDeviceSurface surface,
  ) {
    return result.visibility.canReleaseToStudent ||
        result.visibility.canReleaseToParent ||
        (surface == AppDeviceSurface.desktop && result.canClose);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherTopicResultActionControllerProvider(target);
    final busy = ref.watch(provider.select((state) => state.isBusy));
    final controller = ref.read(provider.notifier);
    final isDesktop =
        ref.watch(appDeviceSurfaceProvider) == AppDeviceSurface.desktop;
    final name = result.studentName;

    return Card(
      key: const Key('teacherTopicResultActions'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (busy) ...[
              const LinearProgressIndicator(
                semanticsLabel: 'Updating Topic result',
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (result.visibility.canReleaseToStudent)
                  FilledButton.tonalIcon(
                    key: const Key('teacherTopicResultReleaseStudentButton'),
                    onPressed: busy
                        ? null
                        : () => _confirmAction(
                            context,
                            ref,
                            title: 'Release to the Student?',
                            message:
                                '$name will see the scores, the category and '
                                'your comment. A release cannot be undone.',
                            confirmLabel: 'Release',
                            onConfirmed: () => controller.release(
                              TeacherTopicResultAudience.student,
                            ),
                          ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Release to Student'),
                  ),
                if (result.visibility.canReleaseToParent)
                  FilledButton.tonalIcon(
                    key: const Key('teacherTopicResultReleaseParentButton'),
                    onPressed: busy
                        ? null
                        : () => _confirmAction(
                            context,
                            ref,
                            title: 'Release to Parents?',
                            message:
                                'The Parents of $name will see the scores, the '
                                'category and your comment. A release cannot '
                                'be undone.',
                            confirmLabel: 'Release',
                            onConfirmed: () => controller.release(
                              TeacherTopicResultAudience.parent,
                            ),
                          ),
                    icon: const Icon(Icons.family_restroom_outlined),
                    label: const Text('Release to Parents'),
                  ),
                if (isDesktop && result.canClose)
                  OutlinedButton.icon(
                    key: const Key('teacherTopicResultCloseButton'),
                    onPressed: busy
                        ? null
                        : () => _confirmAction(
                            context,
                            ref,
                            title: 'Close this result?',
                            message:
                                'The result of $name becomes final: '
                                'corrections of the official answers and '
                                'comment changes are no longer possible. '
                                'Closing cannot be undone.',
                            confirmLabel: 'Close',
                            onConfirmed: controller.close,
                          ),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Close result'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The desktop comment editor of an open result (`S10-D1`): counted in
/// Unicode code points after trimming, as the server counts it.
class TeacherTopicResultCommentEditor extends ConsumerStatefulWidget {
  const TeacherTopicResultCommentEditor({
    required this.target,
    required this.savedComment,
    required this.confirmed,
    super.key,
  });

  final TeacherTopicResultTarget target;
  final String? savedComment;

  /// False while the shown result is loading, refreshing or stale.
  final bool confirmed;

  @override
  ConsumerState<TeacherTopicResultCommentEditor> createState() =>
      _TeacherTopicResultCommentEditorState();
}

class _TeacherTopicResultCommentEditorState
    extends ConsumerState<TeacherTopicResultCommentEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.savedComment ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = teacherTopicResultActionControllerProvider(widget.target);
    final busy = ref.watch(provider.select((state) => state.isBusy));
    final trimmed = _text.text.trim();
    final length = trimmed.runes.length;
    final tooLong = length > teacherTopicResultCommentMaxLength;
    final changed = trimmed != (widget.savedComment ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('teacherTopicResultCommentField'),
          controller: _text,
          enabled: !busy,
          minLines: 2,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'Comment for the Student and Parents',
            border: const OutlineInputBorder(),
            errorText: tooLong ? 'Use at most 2000 characters.' : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text(
          '$length / $teacherTopicResultCommentMaxLength',
          key: const Key('teacherTopicResultCommentCounter'),
          textAlign: TextAlign.end,
        ),
        // Saving needs a confirmed current result; the draft stays meanwhile.
        if (widget.confirmed) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('teacherTopicResultCommentSave'),
              onPressed: !busy && changed && !tooLong
                  ? () => ref.read(provider.notifier).saveComment(_text.text)
                  : null,
              child: const Text('Save comment'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Release all ready results (desktop and mobile) and close all ready results
/// (desktop) of the Topic's whole cohort, offered by the Institution modes
/// carried by [rows].
class TeacherTopicResultBulkActionBar extends ConsumerWidget {
  const TeacherTopicResultBulkActionBar({
    required this.topicId,
    required this.rows,
    super.key,
  });

  final String topicId;
  final List<TeacherTopicResult> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherTopicResultBulkActionControllerProvider(
      topicId.toLowerCase(),
    );
    final busy = ref.watch(provider.select((state) => state.isBusy));
    final controller = ref.read(provider.notifier);
    final isDesktop =
        ref.watch(appDeviceSurfaceProvider) == AppDeviceSurface.desktop;
    final visibility = rows.first.visibility;
    final releasesToStudents =
        visibility.studentReleaseMode ==
        TeacherStudentResultReleaseMode.manualTeacher;
    final releasesToParents =
        visibility.parentReleaseMode ==
        TeacherParentResultReleaseMode.manualTeacher;
    const scope =
        'This covers every Student of the Topic, not only this page or '
        'filter.';

    final buttons = [
      if (releasesToStudents)
        FilledButton.tonalIcon(
          key: const Key('teacherTopicResultsReleaseStudentsButton'),
          onPressed: busy
              ? null
              : () => _confirmAction(
                  context,
                  ref,
                  title: 'Release ready results to Students?',
                  message:
                      'Each Student whose result is ready will see the '
                      'scores, the category and your comment. $scope Results '
                      'that are not ready are skipped. A release cannot be '
                      'undone.',
                  confirmLabel: 'Release',
                  onConfirmed: () =>
                      controller.releaseAll(TeacherTopicResultAudience.student),
                ),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Release ready results to Students'),
        ),
      if (releasesToParents)
        FilledButton.tonalIcon(
          key: const Key('teacherTopicResultsReleaseParentsButton'),
          onPressed: busy
              ? null
              : () => _confirmAction(
                  context,
                  ref,
                  title: 'Release ready results to Parents?',
                  message:
                      'Parents will see each result their Student can '
                      'already see. $scope Other results are skipped. A '
                      'release cannot be undone.',
                  confirmLabel: 'Release',
                  onConfirmed: () =>
                      controller.releaseAll(TeacherTopicResultAudience.parent),
                ),
          icon: const Icon(Icons.family_restroom_outlined),
          label: const Text('Release ready results to Parents'),
        ),
      if (isDesktop)
        OutlinedButton.icon(
          key: const Key('teacherTopicResultsCloseAllButton'),
          onPressed: busy
              ? null
              : () => _confirmAction(
                  context,
                  ref,
                  title: 'Close ready results?',
                  message:
                      'Every result that is ready to close becomes final: '
                      'corrections of the official answers and comment '
                      'changes are blocked. $scope Results that are not ready '
                      'are skipped. Closing cannot be undone.',
                  confirmLabel: 'Close',
                  onConfirmed: controller.closeAll,
                ),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Close ready results'),
        ),
    ];
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('teacherTopicResultsBulkActions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) ...[
          const LinearProgressIndicator(
            semanticsLabel: 'Updating Topic results',
          ),
          const SizedBox(height: 12),
        ],
        Wrap(spacing: 10, runSpacing: 10, children: buttons),
      ],
    );
  }
}

/// Asks before an action that cannot be undone; the action runs only if the
/// same Teacher session still owns the screen.
Future<void> _confirmAction(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirmed,
}) async {
  TeacherSessionKey? owner() => TeacherSessionSnapshot.fromSession(
    ref.read(authSessionControllerProvider),
    ref.read(appDeviceSurfaceProvider),
  ).eligibleKey;
  final startedBy = owner();
  if (startedBy == null) {
    return;
  }
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherTopicResultConfirmButton'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (accepted == true && context.mounted && owner() == startedBy) {
    onConfirmed();
  }
}
