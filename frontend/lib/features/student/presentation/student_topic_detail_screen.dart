import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/student_material_transfer_controller.dart';
import '../application/student_material_transfer_state.dart';
import '../application/student_topic_detail_controller.dart';
import '../application/student_topic_detail_state.dart';
import '../domain/student_topic.dart';
import 'student_topic_formatters.dart';

class StudentTopicDetailScreen extends ConsumerWidget {
  const StudentTopicDetailScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailProvider = studentTopicDetailControllerProvider(topicId);
    final transferProvider = studentMaterialTransferControllerProvider(topicId);
    final detail = ref.watch(detailProvider);
    final transfer = ref.watch(transferProvider);
    final timezone = ref
        .watch(authSessionControllerProvider)
        .user
        ?.institution
        ?.timezone;

    ref.listen<String?>(transferProvider.select((state) => state.feedback), (
      _,
      feedback,
    ) {
      if (feedback == null || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(feedback)));
      ref.read(transferProvider.notifier).consumeFeedback();
    });

    return Scaffold(
      key: const Key('studentTopicDetailScreen'),
      appBar: AppBar(
        title: const Text('Topic Detail'),
        leading: IconButton(
          key: const Key('studentTopicBackButton'),
          tooltip: 'Back to Topics',
          onPressed: () => context.go(AppRoutePaths.student),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: switch (detail.status) {
          StudentTopicDetailStatus.initial ||
          StudentTopicDetailStatus.loading => const Center(
            child: CircularProgressIndicator(
              key: Key('studentTopicDetailLoading'),
              semanticsLabel: 'Loading Topic detail',
            ),
          ),
          StudentTopicDetailStatus.notFound => _UnavailableStudentTopic(
            onBack: () => context.go(AppRoutePaths.student),
          ),
          StudentTopicDetailStatus.error => _StudentTopicDetailError(
            failure: detail.failure!,
            onRetry: ref.read(detailProvider.notifier).refresh,
            onBack: () => context.go(AppRoutePaths.student),
          ),
          StudentTopicDetailStatus.data ||
          StudentTopicDetailStatus.refreshing => _StudentTopicDetailContent(
            topic: detail.topic!,
            institutionTimezone: timezone ?? '',
            refreshing: detail.status == StudentTopicDetailStatus.refreshing,
            transfer: transfer,
            onRefresh: ref.read(detailProvider.notifier).refresh,
            onOpen: ref.read(transferProvider.notifier).open,
            onSaveAs: ref.read(transferProvider.notifier).saveAs,
          ),
        },
      ),
    );
  }
}

class _StudentTopicDetailContent extends StatelessWidget {
  const _StudentTopicDetailContent({
    required this.topic,
    required this.institutionTimezone,
    required this.refreshing,
    required this.transfer,
    required this.onRefresh,
    required this.onOpen,
    required this.onSaveAs,
  });

  final StudentTopicDetail topic;
  final String institutionTimezone;
  final bool refreshing;
  final StudentMaterialTransferState transfer;
  final VoidCallback onRefresh;
  final ValueChanged<StudentLearningMaterial> onOpen;
  final ValueChanged<StudentLearningMaterial> onSaveAs;

  @override
  Widget build(BuildContext context) {
    final lesson = formatStudentInstitutionInstant(
      topic.lessonAt,
      institutionTimezone,
    );
    return SingleChildScrollView(
      key: const Key('studentTopicDetailScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refreshing) ...[
                const LinearProgressIndicator(
                  key: Key('studentTopicDetailRefreshing'),
                  semanticsLabel: 'Refreshing Topic detail',
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          topic.title,
                          key: const Key('studentTopicDetailTitle'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Topic: '
                              '${studentTopicStatusLabel(topic.status)}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Group: '
                              '${studentGroupStatusLabel(topic.group.status)}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('studentTopicDetailRefreshButton'),
                          onPressed: refreshing || transfer.isBusy
                              ? null
                              : onRefresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _StudentDetailCard(
                title: 'Topic information',
                rows: [
                  ('Subject', topic.subject),
                  if (topic.description != null)
                    ('Description', topic.description!),
                  ('Student instructions', topic.studentInstructions),
                  if (topic.lessonAt != null)
                    (
                      'Lesson time',
                      lesson ?? 'Institution timezone unavailable',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StudentDetailCard(
                title: 'Group',
                rows: [
                  ('Name', topic.group.name),
                  if (topic.group.level != null) ('Level', topic.group.level!),
                  if (topic.group.subjectDirection != null)
                    ('Subject direction', topic.group.subjectDirection!),
                  ('Status', studentGroupStatusLabel(topic.group.status)),
                ],
              ),
              const SizedBox(height: 12),
              _StudentLearningMaterials(
                materials: topic.materials,
                transfer: transfer,
                onOpen: onOpen,
                onSaveAs: onSaveAs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentDetailCard extends StatelessWidget {
  const _StudentDetailCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
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
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows) ...[
              Text(row.$1, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              SelectableText(row.$2),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentLearningMaterials extends StatelessWidget {
  const _StudentLearningMaterials({
    required this.materials,
    required this.transfer,
    required this.onOpen,
    required this.onSaveAs,
  });

  final List<StudentLearningMaterial> materials;
  final StudentMaterialTransferState transfer;
  final ValueChanged<StudentLearningMaterial> onOpen;
  final ValueChanged<StudentLearningMaterial> onSaveAs;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('studentLearningMaterialsSection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Learning Materials',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            if (materials.isEmpty)
              const Text(
                'No learning materials are available for this Topic.',
                key: Key('studentMaterialsEmpty'),
              )
            else
              for (var index = 0; index < materials.length; index++) ...[
                if (index > 0) const Divider(height: 24),
                _StudentMaterialRow(
                  material: materials[index],
                  transfer: transfer,
                  onOpen: onOpen,
                  onSaveAs: onSaveAs,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _StudentMaterialRow extends StatelessWidget {
  const _StudentMaterialRow({
    required this.material,
    required this.transfer,
    required this.onOpen,
    required this.onSaveAs,
  });

  final StudentLearningMaterial material;
  final StudentMaterialTransferState transfer;
  final ValueChanged<StudentLearningMaterial> onOpen;
  final ValueChanged<StudentLearningMaterial> onSaveAs;

  @override
  Widget build(BuildContext context) {
    final busyForMaterial = transfer.isBusyForMaterial(material.id);
    return Column(
      key: ValueKey('studentMaterial${material.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          material.displayName,
          key: ValueKey('studentMaterialName${material.id}'),
          softWrap: true,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (material.title != null) ...[
          const SizedBox(height: 3),
          Text(material.file.originalName, softWrap: true),
        ],
        const SizedBox(height: 5),
        Text(
          '${material.file.extension.toUpperCase()} · '
          '${formatStudentMaterialBytes(material.file.sizeBytes)}',
        ),
        if (busyForMaterial) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            label: 'Downloading ${material.displayName}',
            child: LinearProgressIndicator(
              key: ValueKey('studentMaterialProgress${material.id}'),
              value: transfer.progress,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Semantics(
              button: true,
              label: 'Open ${material.displayName}',
              child: OutlinedButton.icon(
                key: ValueKey('studentMaterialOpen${material.id}'),
                onPressed: transfer.isBusy ? null : () => onOpen(material),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
            ),
            Semantics(
              button: true,
              label: 'Save ${material.displayName} as',
              child: OutlinedButton.icon(
                key: ValueKey('studentMaterialSave${material.id}'),
                onPressed: transfer.isBusy ? null : () => onSaveAs(material),
                icon: const Icon(Icons.save_alt),
                label: const Text('Save as…'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UnavailableStudentTopic extends StatelessWidget {
  const _UnavailableStudentTopic({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Topic unavailable',
              key: const Key('studentTopicUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This Topic is no longer available.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('studentTopicUnavailableBackButton'),
              onPressed: onBack,
              child: const Text('Back to Topics'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTopicDetailError extends StatelessWidget {
  const _StudentTopicDetailError({
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final ApiFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The Topic request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected Topic response.',
      _ => 'The Topic could not be loaded.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load Topic',
              key: const Key('studentTopicDetailError'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(onPressed: onBack, child: const Text('Back')),
                FilledButton.icon(
                  key: const Key('studentTopicDetailRetryButton'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
