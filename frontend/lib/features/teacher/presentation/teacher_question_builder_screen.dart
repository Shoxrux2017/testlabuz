import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_homework_detail_controller.dart';
import '../application/teacher_homework_detail_state.dart';
import '../application/teacher_homework_route_target.dart';
import '../application/teacher_question_builder_controller.dart';
import '../application/teacher_question_builder_state.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_question.dart';
import '../domain/teacher_question_authoring.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_question_editor_dialog.dart';
import 'teacher_question_read_view.dart';

class TeacherQuestionBuilderScreen extends ConsumerStatefulWidget {
  const TeacherQuestionBuilderScreen({
    required this.topicId,
    required this.homeworkId,
    super.key,
  });

  final String topicId;
  final String homeworkId;

  @override
  ConsumerState<TeacherQuestionBuilderScreen> createState() =>
      _TeacherQuestionBuilderScreenState();
}

class _TeacherQuestionBuilderScreenState
    extends ConsumerState<TeacherQuestionBuilderScreen> {
  late final TeacherHomeworkRouteTarget _target;
  late final TeacherQuestionBuilderController _builderController;
  late final int _routeOwnerGeneration;

  @override
  void initState() {
    super.initState();
    _target = TeacherHomeworkRouteTarget(
      topicId: widget.topicId,
      homeworkId: widget.homeworkId,
    );
    _builderController = ref.read(
      teacherQuestionBuilderControllerProvider(_target).notifier,
    );
    _routeOwnerGeneration = _builderController.enterRoute();
  }

  @override
  void dispose() {
    final builderController = _builderController;
    final routeOwnerGeneration = _routeOwnerGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      builderController.leaveRoute(routeOwnerGeneration);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builderProvider = teacherQuestionBuilderControllerProvider(_target);
    final builderState = ref.watch(builderProvider);
    final detailProvider = teacherHomeworkDetailControllerProvider(_target);
    final detailState = ref.watch(detailProvider);

    return PopScope(
      canPop: !builderState.blocksNavigation && !builderState.orderDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && !builderState.blocksNavigation) {
          await _backToHomework(builderState);
        }
      },
      child: Scaffold(
        key: const Key('teacherQuestionBuilderScreen'),
        appBar: AppBar(
          title: const Text('Question Builder'),
          leading: IconButton(
            key: const Key('teacherQuestionBuilderBackButton'),
            tooltip: 'Back to Homework',
            onPressed: builderState.blocksNavigation
                ? null
                : () => _backToHomework(builderState),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: _buildBody(
            builderState: builderState,
            detailState: detailState,
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required TeacherQuestionBuilderState builderState,
    required TeacherHomeworkDetailState detailState,
  }) {
    if (builderState.status == TeacherQuestionBuilderStatus.unavailable ||
        detailState.status == TeacherHomeworkDetailStatus.notFound) {
      return _BuilderUnavailable(onBack: _backWithoutGuard);
    }

    if ((detailState.status == TeacherHomeworkDetailStatus.initial ||
            detailState.status == TeacherHomeworkDetailStatus.loading) &&
        detailState.homework == null) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('teacherQuestionBuilderLoading'),
          semanticsLabel: 'Loading Question Builder',
        ),
      );
    }

    if (detailState.status == TeacherHomeworkDetailStatus.error &&
        detailState.homework == null) {
      return _BuilderLoadError(
        onRetry: ref
            .read(teacherHomeworkDetailControllerProvider(_target).notifier)
            .retry,
        onBack: _backWithoutGuard,
      );
    }

    final homework = detailState.homework;
    if (homework == null) {
      return _BuilderLoadError(
        onRetry: ref
            .read(teacherHomeworkDetailControllerProvider(_target).notifier)
            .refresh,
        onBack: _backWithoutGuard,
      );
    }

    final surface = ref.watch(appDeviceSurfaceProvider);
    final hasCurrentDetail =
        detailState.status == TeacherHomeworkDetailStatus.data &&
        !detailState.isStale;
    final lifecycleEditable =
        homework.status == TeacherHomeworkStatus.draft ||
        homework.status == TeacherHomeworkStatus.active;
    final mutationAvailable =
        surface == AppDeviceSurface.desktop &&
        hasCurrentDetail &&
        lifecycleEditable &&
        !builderState.serverLocked &&
        !builderState.topicNotEditable &&
        !builderState.authoritativeReloadPending &&
        !builderState.isBusy &&
        !builderState.hasBlockingOutcome;
    final orderedQuestions = _questionsInDraftOrder(homework, builderState);
    final canEditQuestion = mutationAvailable && !builderState.orderDirty;
    final canReorder = mutationAvailable;
    final showMutationControls =
        surface == AppDeviceSurface.desktop && lifecycleEditable;
    final atQuestionLimit =
        homework.questions.length >=
        TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: SingleChildScrollView(
        key: const Key('teacherQuestionBuilderScroll'),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (detailState.status ==
                        TeacherHomeworkDetailStatus.refreshing ||
                    builderState.isBusy) ...[
                  LinearProgressIndicator(
                    key: const Key('teacherQuestionBuilderProgress'),
                    semanticsLabel: switch (builderState.status) {
                      TeacherQuestionBuilderStatus.deleting =>
                        'Deleting Question',
                      TeacherQuestionBuilderStatus.reordering =>
                        'Saving Question order',
                      TeacherQuestionBuilderStatus.reconciling =>
                        'Checking current Homework',
                      _ => 'Refreshing Question Builder',
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (detailState.isStale ||
                    detailState.status ==
                        TeacherHomeworkDetailStatus.error) ...[
                  const _BuilderMessage(
                    key: Key('teacherQuestionBuilderStaleMessage'),
                    message:
                        'The displayed Homework may be out of date. Refresh '
                        'before changing Questions.',
                    isError: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (builderState.notice != null) ...[
                  _BuilderMessage(
                    key: const Key('teacherQuestionBuilderNotice'),
                    message: builderState.notice!,
                    isError: builderState.hasBlockingOutcome,
                    onDismiss: builderState.hasBlockingOutcome
                        ? null
                        : () => ref
                              .read(
                                teacherQuestionBuilderControllerProvider(
                                  _target,
                                ).notifier,
                              )
                              .clearNotice(
                                ownerGeneration: _routeOwnerGeneration,
                              ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (builderState.serverLocked) ...[
                  const _BuilderMessage(
                    key: Key('teacherQuestionBuilderLockedBanner'),
                    message:
                        'Question editing is locked by the current server '
                        'state. Review the current Homework before continuing.',
                    isError: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (builderState.topicNotEditable &&
                    builderState.notice !=
                        'The Topic is no longer editable.') ...[
                  const _BuilderMessage(
                    key: Key('teacherQuestionBuilderTopicNotEditableBanner'),
                    message: 'The Topic is no longer editable.',
                    isError: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (homework.status == TeacherHomeworkStatus.active) ...[
                  const _BuilderMessage(
                    key: Key('teacherQuestionBuilderActiveNote'),
                    message:
                        'Question editing may be locked after Student activity '
                        'begins. The server will confirm whether changes are '
                        'still allowed.',
                  ),
                  const SizedBox(height: 12),
                ],
                if (!lifecycleEditable) ...[
                  const _BuilderMessage(
                    key: Key('teacherQuestionBuilderReviewOnlyMessage'),
                    message:
                        'Question editing is unavailable for this Homework.',
                  ),
                  const SizedBox(height: 12),
                ],
                _HomeworkContextCard(homework: homework),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (showMutationControls)
                      FilledButton.icon(
                        key: const Key('teacherQuestionBuilderAddButton'),
                        onPressed:
                            mutationAvailable &&
                                !builderState.orderDirty &&
                                !atQuestionLimit
                            ? _openAddEditor
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Question'),
                      ),
                    OutlinedButton.icon(
                      key: const Key('teacherQuestionBuilderRefreshButton'),
                      onPressed:
                          builderState.isBusy ||
                              builderState.hasBlockingOutcome ||
                              detailState.status ==
                                  TeacherHomeworkDetailStatus.refreshing
                          ? null
                          : () => _refreshWithGuard(builderState),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    if (builderState.orderDirty) ...[
                      FilledButton.icon(
                        key: const Key('teacherQuestionBuilderSaveOrderButton'),
                        onPressed: canReorder
                            ? () => ref
                                  .read(
                                    teacherQuestionBuilderControllerProvider(
                                      _target,
                                    ).notifier,
                                  )
                                  .saveOrder(
                                    ownerGeneration: _routeOwnerGeneration,
                                  )
                            : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save order'),
                      ),
                      TextButton(
                        key: const Key(
                          'teacherQuestionBuilderResetOrderButton',
                        ),
                        onPressed: builderState.isBusy
                            ? null
                            : () => ref
                                  .read(
                                    teacherQuestionBuilderControllerProvider(
                                      _target,
                                    ).notifier,
                                  )
                                  .resetOrder(
                                    ownerGeneration: _routeOwnerGeneration,
                                  ),
                        child: const Text('Reset order'),
                      ),
                    ],
                    if (builderState.hasBlockingOutcome)
                      FilledButton.icon(
                        key: const Key(
                          'teacherQuestionBuilderCheckCurrentButton',
                        ),
                        onPressed: builderState.isBusy
                            ? null
                            : () => ref
                                  .read(
                                    teacherQuestionBuilderControllerProvider(
                                      _target,
                                    ).notifier,
                                  )
                                  .checkCurrentHomework(
                                    ownerGeneration: _routeOwnerGeneration,
                                  ),
                        icon: const Icon(Icons.sync),
                        label: const Text('Check current Homework'),
                      ),
                    if (!lifecycleEditable)
                      OutlinedButton.icon(
                        key: const Key(
                          'teacherQuestionBuilderBackToHomeworkButton',
                        ),
                        onPressed: _backWithoutGuard,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Homework'),
                      ),
                  ],
                ),
                if (atQuestionLimit && lifecycleEditable) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Maximum 100 Questions.',
                    key: Key('teacherQuestionBuilderMaximumMessage'),
                  ),
                ],
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    'Questions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 10),
                if (orderedQuestions.isEmpty)
                  const _BuilderMessage(
                    key: Key('teacherQuestionBuilderEmpty'),
                    message: 'No Questions have been added yet.',
                  )
                else
                  for (
                    var index = 0;
                    index < orderedQuestions.length;
                    index += 1
                  ) ...[
                    _BuilderQuestionCard(
                      question: orderedQuestions[index],
                      ordinal: index + 1,
                      canEdit: canEditQuestion,
                      canDelete: canEditQuestion,
                      canMove: canReorder,
                      showActions: showMutationControls,
                      onEdit: () => _openEditEditor(orderedQuestions[index].id),
                      onDelete: () =>
                          _confirmDelete(orderedQuestions[index], index + 1),
                      onMoveUp: index == 0
                          ? null
                          : () => ref
                                .read(
                                  teacherQuestionBuilderControllerProvider(
                                    _target,
                                  ).notifier,
                                )
                                .moveQuestionUp(
                                  orderedQuestions[index].id,
                                  ownerGeneration: _routeOwnerGeneration,
                                ),
                      onMoveDown: index == orderedQuestions.length - 1
                          ? null
                          : () => ref
                                .read(
                                  teacherQuestionBuilderControllerProvider(
                                    _target,
                                  ).notifier,
                                )
                                .moveQuestionDown(
                                  orderedQuestions[index].id,
                                  ownerGeneration: _routeOwnerGeneration,
                                ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddEditor() async {
    final owner = _currentSessionOwner();
    if (owner == null || !_isCurrentSessionOwner(owner)) {
      return;
    }
    final generation = _builderController.nextEditorGeneration();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TeacherQuestionEditorDialog.add(
        routeTarget: _target,
        routeOwnerGeneration: _routeOwnerGeneration,
        editorGeneration: generation,
      ),
    );
  }

  Future<void> _openEditEditor(String questionId) async {
    final owner = _currentSessionOwner();
    if (owner == null || !_isCurrentSessionOwner(owner)) {
      return;
    }
    final generation = _builderController.nextEditorGeneration();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TeacherQuestionEditorDialog.edit(
        routeTarget: _target,
        routeOwnerGeneration: _routeOwnerGeneration,
        questionId: questionId,
        editorGeneration: generation,
      ),
    );
  }

  Future<void> _confirmDelete(TeacherQuestion question, int ordinal) async {
    final owner = _currentSessionOwner();
    if (owner == null || !_isCurrentSessionOwner(owner)) {
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Question $ordinal?'),
        content: const Text(
          'This removes the Question and its answer configuration.',
        ),
        actions: [
          TextButton(
            key: const Key('teacherQuestionDeleteCancelButton'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('teacherQuestionDeleteConfirmButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (accepted != true || !_isCurrentSessionOwner(owner)) {
      return;
    }
    await ref
        .read(teacherQuestionBuilderControllerProvider(_target).notifier)
        .deleteQuestion(question.id, ownerGeneration: _routeOwnerGeneration);
  }

  Future<void> _refreshWithGuard(
    TeacherQuestionBuilderState builderState,
  ) async {
    final owner = _currentSessionOwner();
    if (owner == null || !_isCurrentSessionOwner(owner)) {
      return;
    }
    if (!builderState.orderDirty) {
      ref
          .read(teacherQuestionBuilderControllerProvider(_target).notifier)
          .refresh(ownerGeneration: _routeOwnerGeneration);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved Question order and refresh?'),
        actions: [
          TextButton(
            key: const Key('teacherQuestionRefreshKeepOrderButton'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            key: const Key('teacherQuestionRefreshDiscardOrderButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard and refresh'),
          ),
        ],
      ),
    );
    if (discard != true || !_isCurrentSessionOwner(owner)) {
      return;
    }
    final controller = ref.read(
      teacherQuestionBuilderControllerProvider(_target).notifier,
    );
    controller
      ..resetOrder(ownerGeneration: _routeOwnerGeneration)
      ..refresh(ownerGeneration: _routeOwnerGeneration);
  }

  Future<void> _backToHomework(TeacherQuestionBuilderState builderState) async {
    if (builderState.blocksNavigation) {
      return;
    }
    if (builderState.orderDirty) {
      final owner = _currentSessionOwner();
      if (owner == null || !_isCurrentSessionOwner(owner)) {
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved Question order?'),
          actions: [
            TextButton(
              key: const Key('teacherQuestionBackKeepOrderButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('teacherQuestionBackDiscardOrderButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !_isCurrentSessionOwner(owner)) {
        return;
      }
    }
    _backWithoutGuard();
  }

  void _backWithoutGuard() {
    final controller = ref.read(
      teacherQuestionBuilderControllerProvider(_target).notifier,
    );
    if (!controller.ownsRouteGeneration(_routeOwnerGeneration)) {
      return;
    }
    controller.leaveRoute(_routeOwnerGeneration);
    context.go(
      AppRoutePaths.teacherHomeworkDetailLocation(
        widget.topicId,
        widget.homeworkId,
      ),
    );
  }

  TeacherSessionKey? _currentSessionOwner() {
    return TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
  }

  bool _isCurrentSessionOwner(TeacherSessionKey owner) {
    return mounted &&
        _currentSessionOwner() == owner &&
        _builderController.isCurrentRouteOwner(
          owner,
          ownerGeneration: _routeOwnerGeneration,
        );
  }
}

class _HomeworkContextCard extends StatelessWidget {
  const _HomeworkContextCard({required this.homework});

  final TeacherHomework homework;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('teacherQuestionBuilderContext'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                homework.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(teacherHomeworkStatusLabel(homework.status))),
                Chip(
                  key: const Key('teacherQuestionBuilderTotalPoints'),
                  label: Text(
                    'Total points: '
                    '${formatTeacherHomeworkPoints(homework.totalPossiblePoints)}',
                  ),
                ),
                Chip(
                  key: const Key('teacherQuestionBuilderQuestionCount'),
                  label: Text('Questions: ${homework.questions.length}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BuilderQuestionCard extends StatelessWidget {
  const _BuilderQuestionCard({
    required this.question,
    required this.ordinal,
    required this.canEdit,
    required this.canDelete,
    required this.canMove,
    required this.showActions,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final TeacherQuestion question;
  final int ordinal;
  final bool canEdit;
  final bool canDelete;
  final bool canMove;
  final bool showActions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('teacherQuestionBuilderCard${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Question $ordinal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(teacherQuestionTypeLabel(question.type))),
                Chip(
                  label: Text(
                    '${formatTeacherHomeworkPoints(question.points)} points',
                  ),
                ),
                Chip(
                  label: Text(
                    teacherQuestionCheckingModeLabel(question.checkingMode),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Prompt', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 3),
            SelectableText(question.prompt),
            if (question.instructions != null) ...[
              const SizedBox(height: 10),
              Text(
                'Instructions',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 3),
              SelectableText(question.instructions!),
            ],
            const SizedBox(height: 12),
            TeacherQuestionConfigurationReadView(
              configuration: question.configuration,
            ),
            if (showActions) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    key: ValueKey('teacherQuestionEdit${question.id}'),
                    onPressed: canEdit ? onEdit : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    key: ValueKey('teacherQuestionDelete${question.id}'),
                    onPressed: canDelete ? onDelete : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                  IconButton(
                    key: ValueKey('teacherQuestionMoveUp${question.id}'),
                    tooltip: 'Move Question $ordinal up',
                    onPressed: canMove ? onMoveUp : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    key: ValueKey('teacherQuestionMoveDown${question.id}'),
                    tooltip: 'Move Question $ordinal down',
                    onPressed: canMove ? onMoveDown : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BuilderMessage extends StatelessWidget {
  const _BuilderMessage({
    required this.message,
    this.isError = false,
    this.onDismiss,
    super.key,
  });

  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: isError ? colors.errorContainer : colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(child: Text(message)),
              if (onDismiss != null)
                IconButton(
                  tooltip: 'Dismiss message',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuilderUnavailable extends StatelessWidget {
  const _BuilderUnavailable({required this.onBack});

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
              'Homework unavailable',
              key: const Key('teacherQuestionBuilderUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'The Question Builder is not available for this Homework.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onBack,
              child: const Text('Back to Homework'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuilderLoadError extends StatelessWidget {
  const _BuilderLoadError({required this.onRetry, required this.onBack});

  final VoidCallback onRetry;
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
              'Unable to load Question Builder',
              key: const Key('teacherQuestionBuilderError'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'The current Homework could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(onPressed: onBack, child: const Text('Back')),
                FilledButton.icon(
                  key: const Key('teacherQuestionBuilderRetryButton'),
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

List<TeacherQuestion> _questionsInDraftOrder(
  TeacherHomework homework,
  TeacherQuestionBuilderState state,
) {
  final authoritative = [...homework.questions]
    ..sort((left, right) => left.position.compareTo(right.position));
  if (!state.orderInitialized ||
      state.draftOrderIds.length != authoritative.length) {
    return authoritative;
  }

  final byId = <String, TeacherQuestion>{
    for (final question in authoritative) question.id.toLowerCase(): question,
  };
  final ordered = <TeacherQuestion>[];
  for (final id in state.draftOrderIds) {
    final question = byId.remove(id.toLowerCase());
    if (question == null) {
      return authoritative;
    }
    ordered.add(question);
  }
  return byId.isEmpty ? ordered : authoritative;
}
