import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_blitz_lifecycle_controller.dart';
import '../application/teacher_blitz_route_mutation_activity.dart';
import '../application/teacher_blitz_route_target.dart';
import '../application/teacher_official_blitz_controller.dart';
import '../application/teacher_question_mutation_activity.dart';
import '../application/teacher_session_key.dart';
import '../application/teacher_topic_result_pair_controller.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import '../domain/teacher_blitz_lifecycle.dart';
import 'teacher_blitz_schedule_dialog.dart';

/// Desktop Schedule/Official/Activate/Close/Archive controls for a confirmed
/// current Blitz. Visibility is a UX hint; the server stays authoritative.
class TeacherBlitzLifecycleControls extends ConsumerWidget {
  const TeacherBlitzLifecycleControls({
    required this.target,
    required this.blitz,
    required this.mutationsAvailable,
    required this.isCurrentTarget,
    required this.onEditBlitz,
    required this.onManageQuestions,
    super.key,
  });

  final TeacherBlitzRouteTarget target;
  final TeacherBlitz blitz;

  /// False while the displayed Blitz is stale or being refreshed.
  final bool mutationsAvailable;
  final bool Function(TeacherBlitzRouteTarget target) isCurrentTarget;
  final VoidCallback onEditBlitz;
  final VoidCallback onManageQuestions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycleProvider = teacherBlitzLifecycleControllerProvider(target);
    final lifecycle = ref.watch(lifecycleProvider);
    final officialProvider = teacherOfficialBlitzControllerProvider(target);
    final official = ref.watch(officialProvider);
    final routeActivity = ref.watch(
      teacherBlitzRouteMutationActivityProvider(target),
    );
    final questionActivity = ref.watch(
      teacherQuestionMutationActivityProvider(target),
    );
    final pairProvider = teacherTopicResultPairControllerProvider(
      target.topicId.toLowerCase(),
    );
    final pairState = ref.watch(pairProvider);

    final officialKnowledge = teacherBlitzOfficialKnowledge(blitz, pairState);
    final officialOption = teacherOfficialBlitzOption(
      blitz: blitz,
      pairState: pairState,
    );
    final actions = teacherBlitzLifecycleActions(
      blitz,
      official: officialKnowledge,
    );
    final enabled =
        mutationsAvailable &&
        !routeActivity.isActive &&
        !questionActivity.isActive &&
        !lifecycle.blocksMutations &&
        !official.hasBlockingOutcome;
    final isPreparation = isTeacherBlitzAuthoringStatus(blitz.status);
    final isGroup = blitz.assignmentMode == TeacherBlitzAssignmentMode.group;
    final officialAction = switch (officialOption) {
      TeacherOfficialBlitzOption.set ||
      TeacherOfficialBlitzOption.fillLocked => 'Set as Official Blitz',
      TeacherOfficialBlitzOption.replace => 'Replace Official Blitz',
      _ => null,
    };

    final lifecycleController = ref.read(lifecycleProvider.notifier);
    final officialController = ref.read(officialProvider.notifier);

    return Card(
      key: const Key('teacherBlitzLifecycleControls'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPreparation) ...[
              const Text(
                'Scheduling records the planned Blitz time.\nThe Blitz does '
                'not start automatically.\nThe Teacher must still activate it.',
                key: Key('teacherBlitzScheduleNote'),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actions.contains(TeacherBlitzLifecycleAction.schedule))
                  OutlinedButton.icon(
                    key: const Key('teacherBlitzScheduleButton'),
                    onPressed: enabled
                        ? () => showTeacherBlitzScheduleDialog(
                            context: context,
                            target: target,
                            blitz: blitz,
                            isCurrentTarget: isCurrentTarget,
                          )
                        : null,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      blitz.status == TeacherBlitzStatus.scheduled
                          ? 'Reschedule'
                          : 'Schedule',
                    ),
                  ),
                if (officialAction != null)
                  OutlinedButton.icon(
                    key: const Key('teacherBlitzSetOfficialButton'),
                    onPressed: enabled
                        ? () => _confirm(
                            context,
                            ref,
                            dialog: _officialDialog(officialOption),
                            perform: officialController.setOfficial,
                          )
                        : null,
                    icon: const Icon(Icons.verified_outlined),
                    label: Text(officialAction),
                  ),
                if (actions.contains(TeacherBlitzLifecycleAction.activate))
                  lifecycle.canRetryActivation
                      ? FilledButton.icon(
                          key: const Key('teacherBlitzRetryActivationButton'),
                          onPressed: enabled
                              ? lifecycleController.retryActivation
                              : null,
                          icon: const Icon(Icons.replay),
                          label: const Text('Retry activation'),
                        )
                      : FilledButton.icon(
                          key: const Key('teacherBlitzActivateButton'),
                          onPressed: enabled
                              ? () => _confirm(
                                  context,
                                  ref,
                                  dialog: _activateDialog,
                                  perform: lifecycleController.activate,
                                )
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Activate'),
                        ),
                if (actions.contains(TeacherBlitzLifecycleAction.close))
                  OutlinedButton.icon(
                    key: const Key('teacherBlitzCloseButton'),
                    onPressed: enabled
                        ? () => _confirm(
                            context,
                            ref,
                            dialog: _closeDialog,
                            perform: lifecycleController.close,
                          )
                        : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Close'),
                  ),
                if (actions.contains(TeacherBlitzLifecycleAction.archive))
                  OutlinedButton.icon(
                    key: const Key('teacherBlitzArchiveButton'),
                    onPressed: enabled
                        ? () => _confirm(
                            context,
                            ref,
                            dialog: _archiveDialog,
                            perform: lifecycleController.archive,
                          )
                        : null,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive'),
                  ),
              ],
            ),
            if (_officialGuidance(officialOption) case final guidance?) ...[
              const SizedBox(height: 10),
              Text(guidance, key: const Key('teacherBlitzOfficialGuidance')),
            ],
            if (isPreparation && isGroup) ...[
              if (officialKnowledge == TeacherBlitzOfficialKnowledge.official)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Official Blitz must be activated/closed before it can be '
                    'archived.',
                    key: Key('teacherBlitzOfficialArchiveNote'),
                  ),
                ),
              if (officialKnowledge ==
                  TeacherBlitzOfficialKnowledge.unconfirmed) ...[
                const SizedBox(height: 10),
                const Text(
                  'Official Blitz status must be refreshed before archiving.',
                  key: Key('teacherBlitzOfficialStatusNote'),
                ),
                if (!pairState.isRequestInFlight)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('teacherBlitzOfficialRefreshButton'),
                      onPressed: ref.read(pairProvider.notifier).refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh official status'),
                    ),
                  ),
              ],
            ],
            if (lifecycle.isBusy || official.isBusy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                key: const Key('teacherBlitzLifecycleProgress'),
                semanticsLabel: official.isBusy
                    ? 'Updating official Blitz'
                    : _busySemantics(lifecycle.action),
              ),
            ],
            if (lifecycle.notice != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  lifecycle.notice!,
                  key: const Key('teacherBlitzLifecycleNotice'),
                ),
              ),
              if (lifecycle.canCheckCurrent)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('teacherBlitzCheckCurrentButton'),
                    onPressed: lifecycle.isBusy
                        ? null
                        : lifecycleController.checkCurrentBlitz,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check current Blitz'),
                  ),
                )
              else if (_conflictAction(lifecycle.conflictCode)
                  case final action?
                  when isPreparation &&
                      (action != _ConflictAction.edit || !isGroup))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('teacherBlitzLifecycleConflictAction'),
                    onPressed: switch (action) {
                      _ConflictAction.questions => onManageQuestions,
                      _ConflictAction.edit => onEditBlitz,
                    },
                    icon: Icon(switch (action) {
                      _ConflictAction.questions => Icons.quiz_outlined,
                      _ConflictAction.edit => Icons.edit_outlined,
                    }),
                    label: Text(switch (action) {
                      _ConflictAction.questions => 'Manage Questions',
                      _ConflictAction.edit => 'Edit Blitz',
                    }),
                  ),
                ),
            ],
            if (official.notice != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  official.notice!,
                  key: const Key('teacherBlitzOfficialNotice'),
                ),
              ),
              if (official.canCheckCurrent)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('teacherBlitzCheckOfficialPairButton'),
                    onPressed: official.isBusy
                        ? null
                        : officialController.checkCurrentOfficialPair,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check current official pair'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Confirms first, then acts only if the session and target still own it.
  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required _ConfirmationCopy dialog,
    required Future<void> Function() perform,
  }) async {
    final owner = _sessionOwner(ref);
    if (owner == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('teacherBlitzConfirmDialog'),
        title: Text(dialog.title),
        content: Text(dialog.body),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('teacherBlitzConfirmButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialog.action),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        !isCurrentTarget(target) ||
        _sessionOwner(ref) != owner) {
      return;
    }
    await perform();
  }

  TeacherSessionKey? _sessionOwner(WidgetRef ref) {
    final owner = TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    return owner?.surface == AppDeviceSurface.desktop ? owner : null;
  }
}

class _ConfirmationCopy {
  const _ConfirmationCopy({
    required this.title,
    required this.body,
    required this.action,
  });

  final String title;
  final String body;
  final String action;
}

const _activateDialog = _ConfirmationCopy(
  title: 'Activate Blitz?',
  body:
      "The server will snapshot the Institution's current Blitz timer-start "
      'mode.\n\nIf the mode is synchronized, activation starts the common '
      'class timer immediately.\n\nIf the mode is individual, activation makes '
      "the Blitz available and each Student's timer starts when that Student "
      'starts the attempt.\n\nThe scheduled time does not activate the Blitz '
      'automatically.',
  action: 'Activate',
);

const _closeDialog = _ConfirmationCopy(
  title: 'Close Blitz?',
  body:
      'Closing stops further Blitz execution.\n\nThe server will freeze any '
      'existing in-progress Student attempts.\nAttempts whose authoritative '
      'deadline has already arrived are finalized by the timeout rule.',
  action: 'Close',
);

const _archiveDialog = _ConfirmationCopy(
  title: 'Archive Blitz?',
  body: 'Archived Blitz remains historical and read-only.',
  action: 'Archive',
);

_ConfirmationCopy _officialDialog(TeacherOfficialBlitzOption option) {
  return switch (option) {
    TeacherOfficialBlitzOption.fillLocked => const _ConfirmationCopy(
      title: "Set this Blitz as the Topic's official Blitz?",
      body:
          "This Topic's official cohort is already locked.\nThis Blitz will use "
          'the existing official cohort.\nThe Homework and cohort cannot be '
          'changed by this action.',
      action: 'Set as Official Blitz',
    ),
    TeacherOfficialBlitzOption.replace => const _ConfirmationCopy(
      title: 'Replace the currently designated official Blitz with this Blitz?',
      body:
          'The official Homework will remain unchanged.\nThe server will '
          'reject the change if official activity or another lock now '
          'prevents replacement.',
      action: 'Replace Official Blitz',
    ),
    _ => const _ConfirmationCopy(
      title: "Set this Blitz as the Topic's official Blitz?",
      body:
          'The current official Homework will be preserved.\nThe server will '
          'validate whether this Blitz is still eligible.',
      action: 'Set as Official Blitz',
    ),
  };
}

String? _officialGuidance(TeacherOfficialBlitzOption option) {
  return switch (option) {
    TeacherOfficialBlitzOption.requiresOfficialHomework =>
      "Choose the Topic's official Homework first.\nThen this Blitz can be "
          'designated as the official Blitz.',
    TeacherOfficialBlitzOption.lockedByOther =>
      'Official Blitz selection is locked by existing official activity.',
    TeacherOfficialBlitzOption.selectedStudents =>
      'Selected-student Blitz cannot be the official Topic Blitz.',
    _ => null,
  };
}

enum _ConflictAction { questions, edit }

_ConflictAction? _conflictAction(String? code) {
  return switch (code) {
    ApiErrorCodes.assessmentHasNoScoreablePoints => _ConflictAction.questions,
    ApiErrorCodes.assessmentNotAssigned => _ConflictAction.edit,
    _ => null,
  };
}

String _busySemantics(TeacherBlitzLifecycleAction? action) {
  return switch (action) {
    TeacherBlitzLifecycleAction.schedule => 'Scheduling Blitz',
    TeacherBlitzLifecycleAction.activate => 'Activating Blitz',
    TeacherBlitzLifecycleAction.close => 'Closing Blitz',
    TeacherBlitzLifecycleAction.archive => 'Archiving Blitz',
    null => 'Updating Blitz lifecycle',
  };
}
