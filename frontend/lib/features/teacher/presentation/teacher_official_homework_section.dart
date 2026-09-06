import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_homework_route_mutation_activity.dart';
import '../application/teacher_homework_route_target.dart';
import '../application/teacher_official_homework_controller.dart';
import '../application/teacher_official_homework_state.dart';
import '../application/teacher_session_key.dart';
import '../application/teacher_topic_result_pair_controller.dart';
import '../application/teacher_topic_result_pair_state.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_topic_result_pair.dart';

class TeacherOfficialHomeworkSection extends ConsumerWidget {
  const TeacherOfficialHomeworkSection({
    required this.target,
    required this.homework,
    required this.surface,
    required this.mutationsAvailable,
    required this.isCurrentTarget,
    super.key,
  });

  final TeacherHomeworkRouteTarget target;
  final TeacherHomework homework;
  final AppDeviceSurface surface;
  final bool mutationsAvailable;
  final bool Function(TeacherHomeworkRouteTarget target) isCurrentTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairProvider = teacherTopicResultPairControllerProvider(
      target.topicId,
    );
    final pairState = ref.watch(pairProvider);
    final mutationProvider = teacherOfficialHomeworkControllerProvider(target);
    final mutation = surface == AppDeviceSurface.desktop
        ? ref.watch(mutationProvider)
        : const TeacherOfficialHomeworkState();
    final activity = surface == AppDeviceSurface.desktop
        ? ref.watch(teacherHomeworkRouteMutationActivityProvider(target))
        : const TeacherHomeworkRouteMutationActivityState();

    return Card(
      key: const Key('teacherOfficialHomeworkSection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Official Homework',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            _OfficialReadBody(
              homework: homework,
              pairState: pairState,
              isDesktop:
                  surface == AppDeviceSurface.desktop && mutationsAvailable,
              mutationDisabled: activity.isActive,
              serverSelectionLocked:
                  mutation.conflictCode == ApiErrorCodes.resultPairLocked,
              onRetry: ref.read(pairProvider.notifier).retry,
              onSetOfficial: () =>
                  _confirmAndSubmit(context, ref, pairState.pair),
            ),
            if (mutation.isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                key: Key('teacherOfficialHomeworkProgress'),
                semanticsLabel: 'Updating official Homework',
              ),
            ],
            if (mutation.status != TeacherOfficialHomeworkStatus.idle &&
                mutation.status !=
                    TeacherOfficialHomeworkStatus.confirmedSuccess &&
                mutation.feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                mutation.feedback!,
                key: const Key('teacherOfficialHomeworkFeedback'),
              ),
              if (mutation.canCheckCurrent) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('teacherOfficialHomeworkCheckCurrentButton'),
                    onPressed: ref
                        .read(mutationProvider.notifier)
                        .checkCurrentOfficialHomework,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check current official Homework'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndSubmit(
    BuildContext context,
    WidgetRef ref,
    TeacherTopicResultPair? pair,
  ) async {
    final originatingSessionKey = TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (originatingSessionKey == null ||
        originatingSessionKey.surface != AppDeviceSurface.desktop) {
      return;
    }
    final replacing =
        pair != null &&
        pair.homeworkAssessmentId.toLowerCase() != homework.id.toLowerCase();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('teacherOfficialHomeworkConfirmDialog'),
          title: Text(
            replacing
                ? 'Replace official Homework?'
                : 'Set as official Homework?',
          ),
          content: Text(
            '${replacing ? 'This Topic already has an official Homework.\nReplace it with this Homework?' : "This whole-group Homework will be used as the Topic's official Homework for result comparison."}'
            '${homework.status == TeacherHomeworkStatus.active ? '\n\nIts existing assigned-group snapshot will become the official Topic cohort.' : ''}',
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('teacherOfficialHomeworkConfirmButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(replacing ? 'Replace' : 'Set official'),
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
          .read(teacherOfficialHomeworkControllerProvider(target).notifier)
          .setOfficial();
    }
  }
}

class _OfficialReadBody extends StatelessWidget {
  const _OfficialReadBody({
    required this.homework,
    required this.pairState,
    required this.isDesktop,
    required this.mutationDisabled,
    required this.serverSelectionLocked,
    required this.onRetry,
    required this.onSetOfficial,
  });

  final TeacherHomework homework;
  final TeacherTopicResultPairState pairState;
  final bool isDesktop;
  final bool mutationDisabled;
  final bool serverSelectionLocked;
  final VoidCallback onRetry;
  final VoidCallback onSetOfficial;

  @override
  Widget build(BuildContext context) {
    if (pairState.status == TeacherTopicResultPairStatus.initial ||
        pairState.status == TeacherTopicResultPairStatus.loading ||
        pairState.status == TeacherTopicResultPairStatus.refreshing) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            key: Key('teacherOfficialHomeworkLoading'),
            semanticsLabel: 'Loading official Homework status',
          ),
        ),
      );
    }

    if (pairState.status == TeacherTopicResultPairStatus.error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Official Homework status unavailable.',
            key: Key('teacherOfficialHomeworkReadError'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('teacherOfficialHomeworkRetryButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    final pair = pairState.pair;
    final isOfficial =
        pair != null &&
        pair.homeworkAssessmentId.toLowerCase() == homework.id.toLowerCase();
    if (isOfficial) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Chip(
            key: Key('teacherOfficialHomeworkBadge'),
            label: Text('Official Homework'),
          ),
          const SizedBox(height: 6),
          Text(
            pair.cohortSnapshottedAt == null
                ? 'Official cohort will be fixed when this Homework is activated.'
                : 'Official cohort prepared.',
          ),
          if (pair.lockedAt != null) ...[
            const SizedBox(height: 6),
            const Text('Official selection locked.'),
          ],
        ],
      );
    }

    if (homework.assignmentMode ==
        TeacherHomeworkAssignmentMode.selectedStudents) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(label: Text('Practice Homework')),
          SizedBox(height: 6),
          Text(
            'Selected-student Homework is practice-only and cannot be the official Homework.',
          ),
        ],
      );
    }

    final eligible =
        !serverSelectionLocked &&
        canSubmitOfficialHomework(homework: homework, pairState: pairState);
    final selectionLocked =
        serverSelectionLocked ||
        (pair != null &&
            (pair.lockedAt != null || pair.blitzAssessmentId != null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pair == null
              ? 'No official Homework has been selected for this Topic.'
              : 'Another Homework is currently official for this Topic.',
        ),
        if (selectionLocked) ...[
          const SizedBox(height: 6),
          const Text('Official Homework selection is locked.'),
        ],
        if (isDesktop && eligible) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('teacherOfficialHomeworkActionButton'),
              onPressed: mutationDisabled ? null : onSetOfficial,
              icon: const Icon(Icons.verified_outlined),
              label: Text(
                pair == null
                    ? 'Set as official Homework'
                    : 'Replace official Homework',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
