import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_homework_lifecycle_controller.dart';
import '../application/teacher_homework_route_mutation_activity.dart';
import '../application/teacher_homework_route_target.dart';
import '../application/teacher_session_key.dart';
import '../application/teacher_topic_result_pair_controller.dart';
import '../application/teacher_topic_result_pair_state.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_lifecycle.dart';

class TeacherHomeworkLifecycleControls extends ConsumerWidget {
  const TeacherHomeworkLifecycleControls({
    required this.target,
    required this.homework,
    required this.surface,
    required this.mutationsAvailable,
    required this.isCurrentTarget,
    required this.onEditHomework,
    required this.onManageQuestions,
    required this.onBackToTopic,
    super.key,
  });

  final TeacherHomeworkRouteTarget target;
  final TeacherHomework homework;
  final AppDeviceSurface surface;
  final bool mutationsAvailable;
  final bool Function(TeacherHomeworkRouteTarget target) isCurrentTarget;
  final VoidCallback onEditHomework;
  final VoidCallback onManageQuestions;
  final VoidCallback onBackToTopic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (surface != AppDeviceSurface.desktop) {
      return const SizedBox.shrink();
    }

    final provider = teacherHomeworkLifecycleControllerProvider(target);
    final lifecycle = ref.watch(provider);
    final activity = ref.watch(
      teacherHomeworkRouteMutationActivityProvider(target),
    );
    final pairState = ref.watch(
      teacherTopicResultPairControllerProvider(target.topicId),
    );
    final officialDraft =
        homework.status == TeacherHomeworkStatus.draft &&
        pairState.status == TeacherTopicResultPairStatus.data &&
        pairState.pair?.homeworkAssessmentId.toLowerCase() ==
            homework.id.toLowerCase();
    final actions = teacherHomeworkLifecycleActions(homework)
        .where(
          (action) =>
              !(officialDraft &&
                  action == TeacherHomeworkLifecycleAction.archive),
        )
        .toList(growable: false);
    final conflictAction = _visibleConflictAction(
      lifecycle.conflictCode,
      homework,
    );

    return Column(
      key: const Key('teacherHomeworkLifecycleControls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (actions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                OutlinedButton.icon(
                  key: ValueKey('teacherHomeworkLifecycle${action.name}Button'),
                  onPressed: activity.isActive || !mutationsAvailable
                      ? null
                      : () => _confirmAndPerform(context, ref, action),
                  icon: Icon(_actionIcon(action)),
                  label: Text(_actionLabel(action)),
                ),
            ],
          ),
        if (officialDraft) ...[
          if (actions.isNotEmpty) const SizedBox(height: 8),
          const Text(
            'Replace the official Homework before archiving this draft.',
            key: Key('teacherHomeworkOfficialDraftArchiveMessage'),
          ),
        ],
        if (lifecycle.isBusy) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            key: const Key('teacherHomeworkLifecycleProgress'),
            semanticsLabel: _busySemantics(lifecycle.action),
          ),
        ],
        if (lifecycle.notice != null) ...[
          const SizedBox(height: 10),
          Text(
            lifecycle.notice!,
            key: const Key('teacherHomeworkLifecycleNotice'),
          ),
          if (lifecycle.canCheckCurrent) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('teacherHomeworkLifecycleCheckCurrentButton'),
                onPressed: ref.read(provider.notifier).checkCurrentHomework,
                icon: const Icon(Icons.refresh),
                label: const Text('Check current Homework'),
              ),
            ),
          ] else if (conflictAction case final action?) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('teacherHomeworkLifecycleConflictAction'),
                onPressed: switch (action) {
                  _LifecycleConflictAction.edit => onEditHomework,
                  _LifecycleConflictAction.questions => onManageQuestions,
                  _LifecycleConflictAction.topic => onBackToTopic,
                },
                icon: Icon(switch (action) {
                  _LifecycleConflictAction.edit => Icons.edit_outlined,
                  _LifecycleConflictAction.questions => Icons.quiz_outlined,
                  _LifecycleConflictAction.topic => Icons.arrow_back,
                }),
                label: Text(switch (action) {
                  _LifecycleConflictAction.edit => 'Edit Homework',
                  _LifecycleConflictAction.questions => 'Manage Questions',
                  _LifecycleConflictAction.topic => 'Back to Topic',
                }),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _confirmAndPerform(
    BuildContext context,
    WidgetRef ref,
    TeacherHomeworkLifecycleAction action,
  ) async {
    final originatingSessionKey = TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (originatingSessionKey == null ||
        originatingSessionKey.surface != AppDeviceSurface.desktop) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('teacherHomeworkLifecycleConfirmDialog'),
          title: Text(_dialogTitle(action)),
          content: Text(_dialogBody(action)),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('teacherHomeworkLifecycleConfirmButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_actionLabel(action)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted || !isCurrentTarget(target)) {
      return;
    }
    final currentSessionKey = TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (currentSessionKey == originatingSessionKey) {
      await ref
          .read(teacherHomeworkLifecycleControllerProvider(target).notifier)
          .perform(action);
    }
  }
}

enum _LifecycleConflictAction { edit, questions, topic }

_LifecycleConflictAction? _conflictAction(String? code) {
  return switch (code) {
    ApiErrorCodes.assessmentHasNoScoreablePoints =>
      _LifecycleConflictAction.questions,
    ApiErrorCodes.assessmentNotAssigned ||
    ApiErrorCodes.deadlinePassed => _LifecycleConflictAction.edit,
    ApiErrorCodes.topicNotEditable => _LifecycleConflictAction.topic,
    _ => null,
  };
}

_LifecycleConflictAction? _visibleConflictAction(
  String? code,
  TeacherHomework homework,
) {
  final action = _conflictAction(code);
  if ((action == _LifecycleConflictAction.edit ||
          action == _LifecycleConflictAction.questions) &&
      homework.status != TeacherHomeworkStatus.draft &&
      homework.status != TeacherHomeworkStatus.active) {
    return null;
  }
  return action;
}

String _actionLabel(TeacherHomeworkLifecycleAction action) => switch (action) {
  TeacherHomeworkLifecycleAction.activate => 'Activate',
  TeacherHomeworkLifecycleAction.close => 'Close',
  TeacherHomeworkLifecycleAction.archive => 'Archive',
};

IconData _actionIcon(TeacherHomeworkLifecycleAction action) => switch (action) {
  TeacherHomeworkLifecycleAction.activate => Icons.play_arrow,
  TeacherHomeworkLifecycleAction.close => Icons.stop_circle_outlined,
  TeacherHomeworkLifecycleAction.archive => Icons.archive_outlined,
};

String _dialogTitle(TeacherHomeworkLifecycleAction action) => switch (action) {
  TeacherHomeworkLifecycleAction.activate => 'Activate Homework?',
  TeacherHomeworkLifecycleAction.close => 'Close Homework?',
  TeacherHomeworkLifecycleAction.archive => 'Archive Homework?',
};

String _dialogBody(TeacherHomeworkLifecycleAction action) => switch (action) {
  TeacherHomeworkLifecycleAction.activate =>
    'Students assigned by the server will be able to use this Homework when Stage execution rules allow it.\nThe backend will validate Questions, points, recipients, Topic state, and deadline.',
  TeacherHomeworkLifecycleAction.close =>
    'Closing stops further normal Homework activity.\nThe backend will confirm whether the Homework can be closed now.',
  TeacherHomeworkLifecycleAction.archive =>
    'Archived Homework remains historical and read-only.',
};

String _busySemantics(TeacherHomeworkLifecycleAction? action) =>
    switch (action) {
      TeacherHomeworkLifecycleAction.activate => 'Activating Homework',
      TeacherHomeworkLifecycleAction.close => 'Closing Homework',
      TeacherHomeworkLifecycleAction.archive => 'Archiving Homework',
      null => 'Updating Homework lifecycle',
    };
