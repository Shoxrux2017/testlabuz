import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/scoring/score_display.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_topic_result_action_controller.dart';
import '../application/teacher_topic_result_detail_controller.dart';
import '../application/teacher_topic_result_detail_state.dart';
import '../application/teacher_topic_result_target.dart';
import '../domain/teacher_topic_result.dart';
import 'teacher_topic_result_actions.dart';
import 'teacher_topic_result_formatters.dart';

/// One Student's Topic result on desktop and mobile (`S10-FE-D1`): both
/// sides, the final result, the comment, visibility and closure, with the
/// release actions everywhere and comment and close on desktop.
class TeacherTopicResultDetailScreen extends ConsumerWidget {
  const TeacherTopicResultDetailScreen({
    required this.topicId,
    required this.studentId,
    super.key,
  });

  final String topicId;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = TeacherTopicResultTarget(
      topicId: topicId,
      studentId: studentId,
    );
    final provider = teacherTopicResultDetailControllerProvider(target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final actionProvider = teacherTopicResultActionControllerProvider(target);
    final notice = ref.watch(actionProvider.select((state) => state.notice));
    final surface = ref.watch(appDeviceSurfaceProvider);
    ref.listen<String?>(actionProvider.select((state) => state.feedback), (
      _,
      feedback,
    ) {
      if (feedback == null || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(feedback)));
      ref.read(actionProvider.notifier).consumeFeedback();
    });
    final timezone = ref
        .watch(authSessionControllerProvider)
        .user
        ?.institution
        ?.timezone;
    final detail = state.detail;
    final failure = state.failure;

    // The nested route normally pops to the results; `go` covers an empty
    // stack.
    void backToResults() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(AppRoutePaths.teacherTopicResultsLocation(topicId));
    }

    return Scaffold(
      key: const Key('teacherTopicResultDetailScreen'),
      appBar: AppBar(
        title: const Text('Topic result'),
        leading: IconButton(
          key: const Key('teacherTopicResultBackButton'),
          tooltip: 'Back to Topic results',
          onPressed: backToResults,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            key: const Key('teacherTopicResultRefreshButton'),
            tooltip: 'Refresh result',
            onPressed: state.isRequestInFlight ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: detail == null
            ? state.status == TeacherTopicResultDetailStatus.error &&
                      failure != null
                  ? _DetailFailure(
                      message: teacherTopicResultFailureMessage(failure),
                      onRetry: controller.refresh,
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        key: Key('teacherTopicResultLoading'),
                        semanticsLabel: 'Loading Topic result',
                      ),
                    )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.status ==
                            TeacherTopicResultDetailStatus.refreshing) ...[
                          const LinearProgressIndicator(
                            semanticsLabel: 'Refreshing Topic result',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (state.isStale) ...[
                          MaterialBanner(
                            key: const Key('teacherTopicResultStaleMessage'),
                            content: const Text(
                              'The displayed result may be out of date.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: controller.refresh,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (notice != null) ...[
                          Semantics(
                            key: const Key('teacherTopicResultActionNotice'),
                            liveRegion: true,
                            child: Text(
                              notice,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ..._sections(
                          detail,
                          timezone,
                          target: target,
                          surface: surface,
                          // The review queue is desktop-only (`S09-D7`).
                          onOpenSubmissions: surface == AppDeviceSurface.desktop
                              ? () => context.push(
                                  AppRoutePaths.teacherTopicResultReviewsLocation(
                                    topicId,
                                    studentId,
                                  ),
                                )
                              : null,
                          confirmed:
                              state.status ==
                              TeacherTopicResultDetailStatus.data,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _sections(
    TeacherTopicResultDetail detail,
    String? timezone, {
    required TeacherTopicResultTarget target,
    required AppDeviceSurface surface,
    required bool confirmed,
    required VoidCallback? onOpenSubmissions,
  }) {
    final result = detail.result;
    final editsComment =
        surface == AppDeviceSurface.desktop &&
        result.status != TeacherTopicResultStatus.closed;
    final closedAt = result.closedAt;
    final closedBy = detail.closedBy;
    final closureReason = detail.closureReason;
    final missing = result.missingComponent;
    final category = result.category;
    final consistency = result.consistency;
    final method = result.method;
    final visibility = result.visibility;
    final commentUpdatedAt = detail.commentUpdatedAt;
    final commentAuthor = detail.commentUpdatedBy;

    String? released(DateTime? at, TeacherTopicResultActor? by) {
      if (at == null) {
        return null;
      }
      final time = formatTeacherResultTime(at, timezone);
      return by == null ? time : '$time by ${by.fullName}';
    }

    final studentReleased = released(
      visibility.studentReleasedAt,
      detail.studentReleasedBy,
    );
    final parentReleased = released(
      visibility.parentReleasedAt,
      detail.parentReleasedBy,
    );

    return [
      _ResultSection(
        key: const Key('teacherTopicResultSummary'),
        title: result.studentName,
        titleStyle: _TitleStyle.headline,
        rows: [
          ('Status', teacherTopicResultLabel(result)),
          if (closedAt != null)
            ('Closed at', formatTeacherResultTime(closedAt, timezone)),
          if (closedBy != null) ('Closed by', closedBy.fullName),
          if (closureReason != null)
            ('Closure', teacherTopicResultClosureReasonLabel(closureReason)),
        ],
        notes: [
          if (missing != null) teacherTopicResultMissingLabel(missing),
          if (result.status == TeacherTopicResultStatus.waitingForSettings)
            teacherTopicResultSettingsMessage,
        ],
      ),
      // Actions need a confirmed current result (not loading, stale or
      // refreshing).
      if (confirmed &&
          TeacherTopicResultActionBar.offersAction(result, surface)) ...[
        const SizedBox(height: 12),
        TeacherTopicResultActionBar(target: target, result: result),
      ],
      if (onOpenSubmissions != null) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('teacherTopicResultSubmissionsButton'),
            onPressed: onOpenSubmissions,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Open submissions'),
          ),
        ),
      ],
      const SizedBox(height: 12),
      _SideSection(title: 'Homework', side: result.homework),
      const SizedBox(height: 12),
      _SideSection(title: 'Blitz', side: result.blitz),
      if (category != null) ...[
        const SizedBox(height: 12),
        _ResultSection(
          key: const Key('teacherTopicResultFinal'),
          title: 'Final result',
          rows: [
            if (result.finalScore case final score?)
              ('Final score', formatScoreOneDecimal(score)),
            ('Category', category.label),
            if (method != null)
              ('Method', teacherTopicResultMethodLabel(method)),
            if (result.scoreDifference case final difference?)
              ('Score difference', formatScoreOneDecimal(difference)),
            if (result.acceptableDifference case final allowed?)
              ('Allowed difference', formatScoreOneDecimal(allowed)),
          ],
          notes: [
            if (consistency != null)
              teacherTopicResultComparisonMessage(consistency),
          ],
        ),
      ],
      const SizedBox(height: 12),
      _ResultSection(
        key: const Key('teacherTopicResultComment'),
        title: "Teacher's comment",
        rows: const [],
        editor: editsComment
            ? TeacherTopicResultCommentEditor(
                // A new saved comment restarts the editor from it.
                key: ValueKey<String?>(result.teacherComment),
                target: target,
                savedComment: result.teacherComment,
                confirmed: confirmed,
              )
            : null,
        notes: [
          if (!editsComment) result.teacherComment ?? 'No comment yet.',
          if (commentUpdatedAt != null)
            'Last changed ${formatTeacherResultTime(commentUpdatedAt, timezone)}'
                '${commentAuthor == null ? '' : ' by ${commentAuthor.fullName}'}',
        ],
      ),
      const SizedBox(height: 12),
      _ResultSection(
        key: const Key('teacherTopicResultVisibility'),
        title: 'Visibility',
        rows: [
          (
            'Student release',
            teacherStudentReleaseModeLabel(visibility.studentReleaseMode),
          ),
          (
            'Student',
            visibility.studentVisible ? 'Visible now' : 'Not visible',
          ),
          if (studentReleased != null)
            ('Released to the Student', studentReleased),
          (
            'Parent release',
            teacherParentReleaseModeLabel(visibility.parentReleaseMode),
          ),
          ('Parents', visibility.parentVisible ? 'Visible now' : 'Not visible'),
          if (parentReleased != null) ('Released to Parents', parentReleased),
        ],
      ),
    ];
  }
}

class _SideSection extends StatelessWidget {
  const _SideSection({required this.title, required this.side});

  final String title;
  final TeacherTopicResultSide side;

  @override
  Widget build(BuildContext context) {
    return _ResultSection(
      title: title,
      rows: [
        ('State', teacherTopicResultSideStateLabel(side.state)),
        if (side.attemptNumber case final number?)
          ('Official Attempt', 'Attempt $number'),
        if (side.score case final score?)
          ('Score', formatScoreOneDecimal(score)),
      ],
    );
  }
}

enum _TitleStyle { section, headline }

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.rows,
    this.notes = const [],
    this.editor,
    this.titleStyle = _TitleStyle.section,
    super.key,
  });

  final String title;
  final List<(String, String)> rows;
  final List<String> notes;
  final Widget? editor;
  final _TitleStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: titleStyle == _TitleStyle.headline
                    ? theme.headlineSmall
                    : theme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows) ...[
              Text(row.$1, style: theme.labelLarge),
              const SizedBox(height: 2),
              Text(row.$2),
              const SizedBox(height: 10),
            ],
            if (editor case final editor?) ...[
              editor,
              const SizedBox(height: 10),
            ],
            for (final note in notes) ...[
              Text(note),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailFailure extends StatelessWidget {
  const _DetailFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('teacherTopicResultRetryButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
