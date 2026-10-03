import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scoring/score_display.dart';
import '../application/student_topic_result_controller.dart';
import '../application/student_topic_result_state.dart';
import '../domain/student_topic_result.dart';
import 'student_topic_result_formatters.dart';

/// The Student's own Topic result on the Topic detail page (docs/09 §29.5):
/// the status always, the values only when the server marks them visible.
class StudentTopicResultSection extends ConsumerWidget {
  const StudentTopicResultSection({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentTopicResultControllerProvider(
      topicId.toLowerCase(),
    );
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final result = state.result;
    return Card(
      key: const Key('studentTopicResultSection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(
                'Topic result',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            ...switch (state.status) {
              _
                  when !state.loaded &&
                      state.status != StudentTopicResultLoadStatus.error =>
                [
                  const Center(
                    child: CircularProgressIndicator(
                      key: Key('studentTopicResultLoading'),
                      semanticsLabel: 'Loading Topic result',
                    ),
                  ),
                ],
              StudentTopicResultLoadStatus.error when !state.loaded => [
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'The Topic result could not be loaded.',
                    key: Key('studentTopicResultError'),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('studentTopicResultRetry'),
                    onPressed: controller.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
              _ => [
                if (state.status ==
                    StudentTopicResultLoadStatus.refreshing) ...[
                  const LinearProgressIndicator(
                    semanticsLabel: 'Refreshing Topic result',
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.status == StudentTopicResultLoadStatus.error) ...[
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'The Topic result could not be refreshed.',
                      key: Key('studentTopicResultError'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (result == null)
                  const Text(
                    'No Topic result is available yet.',
                    key: Key('studentTopicResultNone'),
                  )
                else
                  _StudentTopicResultBody(result: result),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('studentTopicResultRefresh'),
                    onPressed: state.isLoading ? null : controller.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh result'),
                  ),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

class _StudentTopicResultBody extends StatelessWidget {
  const _StudentTopicResultBody({required this.result});

  final StudentTopicResult result;

  @override
  Widget build(BuildContext context) {
    final missing = result.missingComponent;
    final method = result.method;
    final category = result.category;
    final comment = result.teacherComment;
    return Column(
      key: const Key('studentTopicResultBody'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Status: ${studentTopicResultStatusLabel(result)}',
          key: const Key('studentTopicResultStatus'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (missing != null) ...[
          const SizedBox(height: 4),
          Text(studentTopicResultMissingLabel(missing)),
        ],
        const SizedBox(height: 10),
        if (!result.visible)
          Text(
            studentTopicResultHiddenMessage(result),
            key: const Key('studentTopicResultHidden'),
          )
        else ...[
          if (result.homeworkScore case final score?)
            _ResultValue(
              label: 'Homework score',
              value: formatScoreOneDecimal(score),
            ),
          if (result.blitzScore case final score?)
            _ResultValue(
              label: 'Blitz score',
              value: formatScoreOneDecimal(score),
            ),
          if (result.finalScore case final score?)
            _ResultValue(
              label: 'Final score',
              value: formatScoreOneDecimal(score),
            ),
          if (method != null) ...[
            Text(studentTopicResultMethodLine(method)),
            const SizedBox(height: 10),
          ],
          if (category != null)
            _ResultValue(label: 'Category', value: category.label),
          if (comment != null)
            _ResultValue(label: "Teacher's comment", value: comment),
        ],
      ],
    );
  }
}

class _ResultValue extends StatelessWidget {
  const _ResultValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(value, softWrap: true),
        ],
      ),
    );
  }
}
