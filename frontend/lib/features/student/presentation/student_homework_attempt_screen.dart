import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/student_attempt_answer_editor_controller.dart';
import '../application/student_attempt_answer_editor_state.dart';
import '../application/student_file_answer_controller.dart';
import '../application/student_homework_attempt_controller.dart';
import '../application/student_homework_attempt_state.dart';
import '../application/student_homework_detail_controller.dart';
import '../application/student_homework_detail_state.dart';
import '../application/student_session_key.dart';
import '../application/student_submission_transfer_controller.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_homework_attempt_route_target.dart';
import '../domain/student_homework_route_target.dart';
import 'student_attempt_answer_read_view.dart';
import 'student_file_answer_editor.dart';
import 'student_homework_formatters.dart';
import 'student_question_read_view.dart';
import 'student_question_answer_editor.dart';
import 'student_topic_formatters.dart';

class StudentHomeworkAttemptScreen extends ConsumerStatefulWidget {
  const StudentHomeworkAttemptScreen({required this.target, super.key});

  final StudentHomeworkAttemptRouteTarget target;

  @override
  ConsumerState<StudentHomeworkAttemptScreen> createState() =>
      _StudentHomeworkAttemptScreenState();
}

class _StudentHomeworkAttemptScreenState
    extends ConsumerState<StudentHomeworkAttemptScreen> {
  bool _leaving = false;
  DialogRoute<bool>? _leaveDialog;

  StudentHomeworkAttemptRouteTarget get target => widget.target;

  StudentSessionKey? get _sessionKey => StudentSessionSnapshot.fromSession(
    ref.read(authSessionControllerProvider),
    ref.read(appDeviceSurfaceProvider),
  ).eligibleKey;

  Future<void> _backToHomework() async {
    if (_leaving) return;
    _leaving = true;
    final capturedTarget = target;
    final capturedSession = _sessionKey;
    final router = GoRouter.of(context);
    final capturedLocation = router.routeInformationProvider.value.uri;
    final provider = studentAttemptAnswerEditorControllerProvider(target);
    final editor = ref.read(provider);
    final fileProvider = studentFileAnswerControllerProvider(target);
    final files = ref.read(fileProvider);
    var leave = true;
    if (files.hasUncertainUpload ||
        editor.hasUncertainMutation ||
        files.hasPendingSelection ||
        editor.hasDirtyDrafts) {
      final route = DialogRoute<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave Attempt?'),
          content: Text(
            files.hasUncertainUpload
                ? 'A file upload result is still unconfirmed. '
                      'Leaving will discard the local uncertainty/reconciliation state. '
                      'Re-opening the attempt will reload server data.'
                : editor.hasUncertainMutation
                ? 'A save result is still unconfirmed. '
                      'Leaving will discard the local uncertainty/reconciliation state. '
                      'Re-opening the attempt will reload server data.'
                : 'You have unsaved answer changes.\n'
                      'Leave and discard these changes?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      _leaveDialog = route;
      leave = await Navigator.of(context).push(route) ?? false;
      if (identical(_leaveDialog, route)) _leaveDialog = null;
    }
    if (!mounted) return;
    _leaving = false;
    if (!leave ||
        target != capturedTarget ||
        _sessionKey != capturedSession ||
        router.routeInformationProvider.value.uri != capturedLocation) {
      return;
    }
    ref.read(provider.notifier).clearLocalState();
    ref.read(fileProvider.notifier).clearLocalState();
    router.go(
      AppRoutePaths.studentHomeworkDetailLocation(
        capturedTarget.topicId,
        capturedTarget.homeworkId,
      ),
    );
  }

  void _dismissObsoleteDialog() {
    final route = _leaveDialog;
    if (route == null) return;
    _leaveDialog = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  @override
  void didUpdateWidget(covariant StudentHomeworkAttemptScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != target) _dismissObsoleteDialog();
  }

  @override
  Widget build(BuildContext context) {
    final homeworkTarget = StudentHomeworkRouteTarget(
      topicId: target.topicId,
      homeworkId: target.homeworkId,
    );
    final homeworkProvider = studentHomeworkDetailControllerProvider(
      homeworkTarget,
    );
    final attemptProvider = studentHomeworkAttemptControllerProvider(target);
    final homeworkState = ref.watch(homeworkProvider);
    final attemptState = ref.watch(attemptProvider);
    final editorProvider = studentAttemptAnswerEditorControllerProvider(target);
    final editorState = ref.watch(editorProvider);
    ref.watch(studentFileAnswerControllerProvider(target));
    final editorController = ref.read(editorProvider.notifier);
    final homeworkController = ref.read(homeworkProvider.notifier);
    final attemptController = ref.read(attemptProvider.notifier);
    final timezone =
        ref.watch(authSessionControllerProvider).user?.institution?.timezone ??
        '';
    final sessionKey = _sessionKey;
    ref.listen(authSessionControllerProvider, (_, _) {
      if (_sessionKey != sessionKey) _dismissObsoleteDialog();
    });
    ref.listen(appDeviceSurfaceProvider, (_, _) {
      if (_sessionKey != sessionKey) _dismissObsoleteDialog();
    });
    void backToHomework() => _backToHomework();
    void backToTopic() =>
        context.go(AppRoutePaths.studentTopicDetailLocation(target.topicId));
    void refresh() {
      homeworkController.refresh();
      attemptController.refresh();
    }

    final terminalAttempt = editorState.terminalAttempt;
    Widget body;
    if (homeworkState.status == StudentHomeworkDetailStatus.notFound) {
      body = _AttemptNotice(
        title: 'Homework unavailable',
        actionLabel: 'Back to Topic',
        onAction: backToTopic,
      );
    } else if (attemptState.status ==
        StudentHomeworkAttemptLoadStatus.notFound) {
      body = _AttemptNotice(
        title: 'Attempt unavailable',
        actionLabel: 'Back to Homework',
        onAction: backToHomework,
      );
    } else if (sessionKey != null &&
        homeworkState.status == StudentHomeworkDetailStatus.data &&
        homeworkState.homework != null &&
        homeworkState.homework!.id.toLowerCase() == target.homeworkId &&
        homeworkState.homework!.topic.id.toLowerCase() == target.topicId &&
        terminalAttempt != null &&
        terminalAttempt.id.toLowerCase() == target.attemptId &&
        terminalAttempt.assessmentId.toLowerCase() == target.homeworkId &&
        (attemptState.status == StudentHomeworkAttemptLoadStatus.data ||
            attemptState.status ==
                StudentHomeworkAttemptLoadStatus.refreshing ||
            attemptState.status == StudentHomeworkAttemptLoadStatus.error)) {
      body = _AttemptContent(
        target: target,
        homework: homeworkState.homework!,
        attempt: terminalAttempt,
        timezone: timezone,
        editorState: editorState,
        editorController: editorController,
      );
    } else if (homeworkState.status == StudentHomeworkDetailStatus.error ||
        attemptState.status == StudentHomeworkAttemptLoadStatus.error) {
      final parentFailure =
          homeworkState.status == StudentHomeworkDetailStatus.error;
      body = _AttemptNotice(
        title: parentFailure
            ? 'Unable to load Homework'
            : 'Unable to load Attempt',
        message: parentFailure
            ? studentHomeworkFailureMessage(homeworkState.failure!)
            : studentHomeworkAttemptFailureMessage(attemptState.failure!),
        actionLabel: 'Retry',
        onAction: refresh,
      );
    } else if (homeworkState.status == StudentHomeworkDetailStatus.data &&
        homeworkState.homework != null &&
        attemptState.status == StudentHomeworkAttemptLoadStatus.data &&
        attemptState.attempt != null &&
        homeworkState.homework!.id.toLowerCase() == target.homeworkId &&
        homeworkState.homework!.topic.id.toLowerCase() == target.topicId &&
        attemptState.attempt!.id.toLowerCase() == target.attemptId &&
        attemptState.attempt!.assessmentId.toLowerCase() == target.homeworkId) {
      body = _AttemptContent(
        target: target,
        homework: homeworkState.homework!,
        attempt: attemptState.attempt!,
        timezone: timezone,
        editorState: editorState,
        editorController: editorController,
      );
    } else {
      final refreshing =
          homeworkState.status == StudentHomeworkDetailStatus.refreshing ||
          attemptState.status == StudentHomeworkAttemptLoadStatus.refreshing;
      body = Center(
        child: CircularProgressIndicator(
          key: Key(
            refreshing
                ? 'studentHomeworkAttemptRefreshing'
                : 'studentHomeworkAttemptLoading',
          ),
          semanticsLabel: refreshing ? 'Refreshing Attempt' : 'Loading Attempt',
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToHomework();
      },
      child: Scaffold(
        key: const Key('studentHomeworkAttemptScreen'),
        appBar: AppBar(
          title: const Text('Homework Attempt'),
          leading: IconButton(
            key: const Key('studentHomeworkAttemptBackButton'),
            tooltip: 'Back to Homework',
            onPressed: backToHomework,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              key: const Key('studentHomeworkAttemptRefreshButton'),
              tooltip: 'Refresh Attempt',
              onPressed:
                  homeworkState.isRequestInFlight ||
                      attemptState.isRequestInFlight
                  ? null
                  : refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

class _AttemptContent extends ConsumerWidget {
  const _AttemptContent({
    required this.target,
    required this.homework,
    required this.attempt,
    required this.timezone,
    required this.editorState,
    required this.editorController,
  });

  final StudentHomeworkAttemptRouteTarget target;
  final StudentHomeworkDetail homework;
  final StudentHomeworkAttempt attempt;
  final String timezone;
  final StudentAttemptAnswerEditorState editorState;
  final StudentAttemptAnswerEditorController editorController;

  String instant(DateTime value) =>
      formatStudentInstitutionInstant(value, timezone) ??
      'Institution timezone unavailable';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionKey = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final fileProvider = studentFileAnswerControllerProvider(target);
    final fileState = ref.watch(fileProvider);
    final fileController = ref.read(fileProvider.notifier);
    final transferProvider = studentSubmissionTransferControllerProvider(
      target,
    );
    final transferState = ref.watch(transferProvider);
    final transferController = ref.read(transferProvider.notifier);
    final answers = {
      for (final answer in attempt.answers)
        answer.questionId.toLowerCase(): answer,
    };
    final activeEditor = editorState.questions[editorState.activeQuestionId];
    final activeFile = fileState.questions[fileState.activeQuestionId];
    final displayedQuestions = [
      ...attempt.questions,
      if (attempt.status == StudentHomeworkAttemptStatus.inProgress &&
          activeEditor != null &&
          !attempt.questions.any(
            (question) =>
                question.id.toLowerCase() ==
                activeEditor.question.id.toLowerCase(),
          ))
        activeEditor.question,
      if (attempt.status == StudentHomeworkAttemptStatus.inProgress &&
          activeFile != null &&
          !attempt.questions.any(
            (question) =>
                question.id.toLowerCase() ==
                activeFile.question.id.toLowerCase(),
          ))
        activeFile.question,
    ];
    final timing = <(String, String)>[
      ('Started', instant(attempt.startedAt)),
      if (attempt.deadlineAt case final value?) ('Deadline', instant(value)),
      if (attempt.submittedAt case final value?) ('Submitted', instant(value)),
      if (attempt.finalizedAt case final value?) ('Finalized', instant(value)),
      if (attempt.finalizationReason case final reason?)
        (
          'Finalization reason',
          studentHomeworkAttemptFinalizationLabel(reason),
        ),
    ];
    return SingleChildScrollView(
      key: const Key('studentHomeworkAttemptScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
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
                        const SizedBox(height: 8),
                        Text(
                          'Attempt ${attempt.attemptNumber}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          container: true,
                          liveRegion: true,
                          child: Text(
                            studentHomeworkAttemptStatusLabel(attempt.status),
                            key: const Key('studentHomeworkAttemptStatus'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final row in timing) ...[
                          Text(
                            row.$1,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          SelectableText(row.$2),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    'Questions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 12),
                for (final question in displayedQuestions) ...[
                  if (fileState.questions[question.id.toLowerCase()]
                      case final file?)
                    StudentFileAnswerEditor(
                      key: ValueKey((target, sessionKey, question.id)),
                      state: file,
                      isTerminal: fileState.isTerminal,
                      canChoose: fileState.canChoose(question.id),
                      canUpload: fileState.canUpload(question.id),
                      canDiscard: fileState.canDiscard(question.id),
                      isReconciling: fileState.isReconciling,
                      canTransfer:
                          file.serverFile != null &&
                          transferController.canTransfer(
                            question.id,
                            file.serverFile!.id,
                          ),
                      transferState: transferState,
                      onChoose: () => fileController.chooseFile(question.id),
                      onUpload: () => fileController.uploadAnswer(question.id),
                      onDiscard: () =>
                          fileController.discardSelectedFile(question.id),
                      onReload: fileController.reloadAttempt,
                      onOpen: () => transferController.open(
                        question.id,
                        file.serverFile!.id,
                      ),
                      onSaveAs: () => transferController.saveAs(
                        question.id,
                        file.serverFile!.id,
                      ),
                    )
                  else if (attempt.status ==
                          StudentHomeworkAttemptStatus.inProgress &&
                      editorState.questions[question.id.toLowerCase()] != null)
                    StudentQuestionAnswerEditor(
                      state: editorState.questions[question.id.toLowerCase()]!,
                      canEdit: editorState.canEdit(question.id),
                      canSave: editorState.canSave(question.id),
                      isReconciling: editorState.isReconciling,
                      timezone: timezone,
                      onChanged: (draft) =>
                          editorController.updateDraft(question.id, draft),
                      onSave: () => editorController.saveAnswer(question.id),
                      onDiscard: () =>
                          editorController.discardChanges(question.id),
                      onClear: () => editorController.clearAnswer(question.id),
                      onReload: editorController.reloadAttempt,
                    )
                  else ...[
                    StudentQuestionReadView(question: question),
                    StudentAttemptAnswerReadView(
                      question: question,
                      answer: answers[question.id.toLowerCase()],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttemptNotice extends StatelessWidget {
  const _AttemptNotice({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.message,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
