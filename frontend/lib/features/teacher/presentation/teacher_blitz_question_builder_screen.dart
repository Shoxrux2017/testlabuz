import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_blitz_detail_controller.dart';
import '../application/teacher_blitz_detail_state.dart';
import '../application/teacher_blitz_question_builder_controller.dart';
import '../application/teacher_blitz_route_target.dart';
import '../application/teacher_question_builder_state.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import '../domain/teacher_question.dart';
import '../domain/teacher_question_authoring.dart';
import 'teacher_blitz_formatters.dart';
import 'teacher_blitz_question_editor_dialog.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_question_builder_widgets.dart';

class TeacherBlitzQuestionBuilderScreen extends ConsumerStatefulWidget {
  const TeacherBlitzQuestionBuilderScreen({
    required this.topicId,
    required this.blitzId,
    super.key,
  });

  final String topicId;
  final String blitzId;

  @override
  ConsumerState<TeacherBlitzQuestionBuilderScreen> createState() =>
      _TeacherBlitzQuestionBuilderScreenState();
}

class _TeacherBlitzQuestionBuilderScreenState
    extends ConsumerState<TeacherBlitzQuestionBuilderScreen> {
  late final TeacherBlitzRouteTarget _target;
  late final TeacherBlitzQuestionBuilderController _builderController;
  late final int _routeOwnerGeneration;

  @override
  void initState() {
    super.initState();
    _target = TeacherBlitzRouteTarget(
      topicId: widget.topicId,
      blitzId: widget.blitzId,
    );
    _builderController = ref.read(
      teacherBlitzQuestionBuilderControllerProvider(_target).notifier,
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
    final builderProvider = teacherBlitzQuestionBuilderControllerProvider(
      _target,
    );
    final builderState = ref.watch(builderProvider);
    final detailProvider = teacherBlitzDetailControllerProvider(_target);
    final detailState = ref.watch(detailProvider);

    return PopScope(
      canPop: !builderState.blocksNavigation && !builderState.orderDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && !builderState.blocksNavigation) {
          await _backToBlitz(builderState);
        }
      },
      child: Scaffold(
        key: const Key('teacherBlitzQuestionBuilderScreen'),
        appBar: AppBar(
          title: const Text('Question Builder'),
          leading: IconButton(
            key: const Key('teacherBlitzQuestionBuilderBackButton'),
            tooltip: 'Back to Blitz',
            onPressed: builderState.blocksNavigation
                ? null
                : () => _backToBlitz(builderState),
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
    required TeacherBlitzDetailState detailState,
  }) {
    if (builderState.status == TeacherQuestionBuilderStatus.unavailable ||
        detailState.status == TeacherBlitzDetailStatus.notFound) {
      return _BuilderUnavailable(onBack: _backWithoutGuard);
    }

    if ((detailState.status == TeacherBlitzDetailStatus.initial ||
            detailState.status == TeacherBlitzDetailStatus.loading) &&
        detailState.blitz == null) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('teacherBlitzQuestionBuilderLoading'),
          semanticsLabel: 'Loading Question Builder',
        ),
      );
    }

    if (detailState.status == TeacherBlitzDetailStatus.error &&
        detailState.blitz == null) {
      return _BuilderLoadError(
        onRetry: ref
            .read(teacherBlitzDetailControllerProvider(_target).notifier)
            .retry,
        onBack: _backWithoutGuard,
      );
    }

    final blitz = detailState.blitz;
    if (blitz == null) {
      return _BuilderLoadError(
        onRetry: ref
            .read(teacherBlitzDetailControllerProvider(_target).notifier)
            .refresh,
        onBack: _backWithoutGuard,
      );
    }

    final surface = ref.watch(appDeviceSurfaceProvider);
    final hasCurrentDetail =
        detailState.status == TeacherBlitzDetailStatus.data &&
        !detailState.isStale;
    final lifecycleEditable = isTeacherBlitzAuthoringStatus(blitz.status);
    final mutationAvailable =
        surface == AppDeviceSurface.desktop &&
        hasCurrentDetail &&
        lifecycleEditable &&
        !builderState.serverLocked &&
        !builderState.topicNotEditable &&
        !builderState.authoritativeReloadPending &&
        !builderState.isBusy &&
        !builderState.hasBlockingOutcome;
    final orderedQuestions = teacherQuestionsInDraftOrder(
      blitz.questions,
      builderState,
    );
    final canEditQuestion = mutationAvailable && !builderState.orderDirty;
    final canReorder = mutationAvailable;
    final showMutationControls =
        surface == AppDeviceSurface.desktop && lifecycleEditable;
    final atQuestionLimit =
        blitz.questions.length >=
        TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: SingleChildScrollView(
        key: const Key('teacherBlitzQuestionBuilderScroll'),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (detailState.status == TeacherBlitzDetailStatus.refreshing ||
                    builderState.isBusy) ...[
                  LinearProgressIndicator(
                    key: const Key('teacherBlitzQuestionBuilderProgress'),
                    semanticsLabel: switch (builderState.status) {
                      TeacherQuestionBuilderStatus.deleting =>
                        'Deleting Question',
                      TeacherQuestionBuilderStatus.reordering =>
                        'Saving Question order',
                      TeacherQuestionBuilderStatus.reconciling =>
                        'Checking current Blitz',
                      _ => 'Refreshing Question Builder',
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (detailState.isStale ||
                    detailState.status == TeacherBlitzDetailStatus.error) ...[
                  const TeacherQuestionBuilderMessage(
                    key: Key('teacherBlitzQuestionBuilderStaleMessage'),
                    message:
                        'The displayed Blitz may be out of date. Refresh '
                        'before changing Questions.',
                    isError: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (builderState.notice != null) ...[
                  TeacherQuestionBuilderMessage(
                    key: const Key('teacherBlitzQuestionBuilderNotice'),
                    message: builderState.notice!,
                    isError: builderState.hasBlockingOutcome,
                    onDismiss: builderState.hasBlockingOutcome
                        ? null
                        : () => ref
                              .read(
                                teacherBlitzQuestionBuilderControllerProvider(
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
                  const TeacherQuestionBuilderMessage(
                    key: Key('teacherBlitzQuestionBuilderLockedBanner'),
                    message:
                        'Question editing is locked by the current server '
                        'state. Review the current Blitz before continuing.',
                    isError: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (builderState.topicNotEditable &&
                    builderState.notice !=
                        'The Topic is no longer editable.') ...[
                  const TeacherQuestionBuilderMessage(
                    key: Key(
                      'teacherBlitzQuestionBuilderTopicNotEditableBanner',
                    ),
                    message: 'The Topic is no longer editable.',
                    isError: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (!lifecycleEditable) ...[
                  const TeacherQuestionBuilderMessage(
                    key: Key('teacherBlitzQuestionBuilderReviewOnlyMessage'),
                    message: 'Question editing is unavailable for this Blitz.',
                  ),
                  const SizedBox(height: 12),
                ],
                _BlitzContextCard(blitz: blitz),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (showMutationControls)
                      FilledButton.icon(
                        key: const Key('teacherBlitzQuestionBuilderAddButton'),
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
                      key: const Key(
                        'teacherBlitzQuestionBuilderRefreshButton',
                      ),
                      onPressed:
                          builderState.isBusy ||
                              builderState.hasBlockingOutcome ||
                              detailState.status ==
                                  TeacherBlitzDetailStatus.refreshing
                          ? null
                          : () => _refreshWithGuard(builderState),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    if (builderState.orderDirty) ...[
                      FilledButton.icon(
                        key: const Key(
                          'teacherBlitzQuestionBuilderSaveOrderButton',
                        ),
                        onPressed: canReorder
                            ? () => ref
                                  .read(
                                    teacherBlitzQuestionBuilderControllerProvider(
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
                          'teacherBlitzQuestionBuilderResetOrderButton',
                        ),
                        onPressed: builderState.isBusy
                            ? null
                            : () => ref
                                  .read(
                                    teacherBlitzQuestionBuilderControllerProvider(
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
                          'teacherBlitzQuestionBuilderCheckCurrentButton',
                        ),
                        onPressed: builderState.isBusy
                            ? null
                            : () => ref
                                  .read(
                                    teacherBlitzQuestionBuilderControllerProvider(
                                      _target,
                                    ).notifier,
                                  )
                                  .checkCurrentBlitz(
                                    ownerGeneration: _routeOwnerGeneration,
                                  ),
                        icon: const Icon(Icons.sync),
                        label: const Text('Check current Blitz'),
                      ),
                    if (!lifecycleEditable)
                      OutlinedButton.icon(
                        key: const Key(
                          'teacherBlitzQuestionBuilderBackToBlitzButton',
                        ),
                        onPressed: _backWithoutGuard,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Blitz'),
                      ),
                  ],
                ),
                if (atQuestionLimit && lifecycleEditable) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Maximum 100 Questions.',
                    key: Key('teacherBlitzQuestionBuilderMaximumMessage'),
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
                  const TeacherQuestionBuilderMessage(
                    key: Key('teacherBlitzQuestionBuilderEmpty'),
                    message: 'No Questions have been added yet.',
                  )
                else
                  for (
                    var index = 0;
                    index < orderedQuestions.length;
                    index += 1
                  ) ...[
                    TeacherQuestionBuilderCard(
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
                                  teacherBlitzQuestionBuilderControllerProvider(
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
                                  teacherBlitzQuestionBuilderControllerProvider(
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
      builder: (_) => TeacherBlitzQuestionEditorDialog.add(
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
      builder: (_) => TeacherBlitzQuestionEditorDialog.edit(
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
            key: const Key('teacherBlitzQuestionDeleteCancelButton'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('teacherBlitzQuestionDeleteConfirmButton'),
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
        .read(teacherBlitzQuestionBuilderControllerProvider(_target).notifier)
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
          .read(teacherBlitzQuestionBuilderControllerProvider(_target).notifier)
          .refresh(ownerGeneration: _routeOwnerGeneration);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved Question order?'),
        actions: [
          TextButton(
            key: const Key('teacherBlitzQuestionRefreshKeepOrderButton'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            key: const Key('teacherBlitzQuestionRefreshDiscardOrderButton'),
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
      teacherBlitzQuestionBuilderControllerProvider(_target).notifier,
    );
    controller
      ..resetOrder(ownerGeneration: _routeOwnerGeneration)
      ..refresh(ownerGeneration: _routeOwnerGeneration);
  }

  Future<void> _backToBlitz(TeacherQuestionBuilderState builderState) async {
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
              key: const Key('teacherBlitzQuestionBackKeepOrderButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('teacherBlitzQuestionBackDiscardOrderButton'),
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
      teacherBlitzQuestionBuilderControllerProvider(_target).notifier,
    );
    if (!controller.ownsRouteGeneration(_routeOwnerGeneration)) {
      return;
    }
    controller.leaveRoute(_routeOwnerGeneration);
    context.go(
      AppRoutePaths.teacherBlitzDetailLocation(widget.topicId, widget.blitzId),
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

class _BlitzContextCard extends StatelessWidget {
  const _BlitzContextCard({required this.blitz});

  final TeacherBlitz blitz;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('teacherBlitzQuestionBuilderContext'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                blitz.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(teacherBlitzStatusLabel(blitz.status))),
                Chip(
                  key: const Key('teacherBlitzQuestionBuilderTotalPoints'),
                  label: Text(
                    'Total points: '
                    '${formatTeacherHomeworkPoints(blitz.totalPossiblePoints)}',
                  ),
                ),
                Chip(
                  key: const Key('teacherBlitzQuestionBuilderQuestionCount'),
                  label: Text('Questions: ${blitz.questions.length}'),
                ),
              ],
            ),
          ],
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
              'Blitz unavailable',
              key: const Key('teacherBlitzQuestionBuilderUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'The Question Builder is not available for this Blitz.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('Back to Blitz')),
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
              key: const Key('teacherBlitzQuestionBuilderError'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'The current Blitz could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(onPressed: onBack, child: const Text('Back')),
                FilledButton.icon(
                  key: const Key('teacherBlitzQuestionBuilderRetryButton'),
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
