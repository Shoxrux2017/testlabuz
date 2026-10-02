import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';

import 'stage9_e2e_support.dart';

const _teacherName = 'E2E S09 Teacher';
const _q3Feedback = 'Clear reasoning.';
const _q4Feedback = 'Good structure, add an example.';
const _grantReason = 'Power outage during the Blitz.';
const _reviewSaved = 'Review saved.';

/// The delivered official-score warning of the grant dialog, verbatim.
const _officialScoreWarning =
    "If this is the Topic's official Blitz:\nthe original attempt "
    'stops counting, and any current official Blitz score is '
    'withdrawn;\nthe replacement attempt becomes official once it '
    'is fully checked, including any Teacher review;\nif the Blitz '
    'is closed before the Student starts the replacement, the '
    'Student has no official Blitz score.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Stage 9 checking, review and results use the real Windows stack',
    (tester) async {
      final harness = await Stage9Harness.create(tester);
      try {
        await harness.launch();
        await _flow(harness);
      } finally {
        await harness.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 35)),
  );
}

Future<void> _flow(Stage9Harness h) async {
  final checkpoints = <String>[];
  final observed = <String, Object?>{};
  Future<void> checkpoint(
    String name, [
    Map<String, Object?> payload = const {},
  ]) async {
    await h.checkpoint(name, payload);
    checkpoints.add(name);
  }

  // Teacher on desktop (steps 1-11).
  await h.signIn('teacher', teacher: true);
  final typedDate = await _setReviewDeadline(h);
  await checkpoint('review_deadline_set', {'typed_date': typedDate});
  await _openSubmissionFromTaskQueue(h);
  await _saveSubmittedFile(h);
  await _partialReview(h);
  await checkpoint('review_partial');
  observed['review_saved_panel'] = await _fullReview(h);
  await checkpoint('review_saved');
  observed['review_corrected_panel'] = await _correctReview(h);
  await checkpoint('review_corrected');
  final grantKey = await _grantException(h);
  await checkpoint('exception_granted');
  observed['replacement_panel'] = await _openReplacementFromGlobalQueue(h);
  await checkpoint('replacement_seen');
  await h.signOut();

  // Student under release mode automatic (steps 12-16).
  await h.signIn('student', teacher: false);
  observed.addAll(await _studentResults(h));
  await h.signOut();

  // Student under release mode manual_teacher (step 17).
  await h.signIn('manual_student', teacher: false);
  await _manualStudentHiddenResults(h);
  await h.signOut();

  h.sink.verify();
  expect(h.keys.issued, [
    grantKey,
  ], reason: 'The UI issues exactly one key, for the grant.');
  expect(h.sink.saveCount, 1, reason: 'The submitted file is saved once.');
  await h.writeJson(h.evidence, {
    'version': 1,
    'checkpoints': checkpoints,
    'typed_date': typedDate,
    'grant_key': grantKey,
    'keys_issued': h.keys.issued.length,
    'file_saves': h.sink.saveCount,
    'saved_sha256': h.sink.savedSha256,
    'observed': observed,
  });
}

// ---------------------------------------------------------------- Teacher review

/// Step 2: counts, then the review deadline through the date and time pickers.
Future<String> _setReviewDeadline(Stage9Harness h) async {
  final m = h.manifest;
  await h.go(
    AppRoutePaths.teacherHomeworkDetailLocation(
      m.topic('review'),
      m.assessment('review_hw'),
    ),
  );
  await h.waitWidget(
    h.byKey('teacherHomeworkDetailScreen'),
    'review Homework detail',
  );
  final overdue = h.byKey('teacherTaskReviewOverdueCount');
  await _waitExact(
    h,
    h.byKey('teacherTaskReviewWaitingCount'),
    'Waiting for review: 1',
  );
  await _waitExact(h, overdue, 'Overdue: 1');

  await h.tap(h.byKey('teacherHomeworkReviewDeadlineSetButton'));
  await h.until(
    () => find.byTooltip('Switch to input').evaluate().isNotEmpty,
    'review deadline date picker',
  );
  await h.tester.tap(find.byTooltip('Switch to input'));
  await h.tester.pump();
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day + 7);
  String two(int value) => value.toString().padLeft(2, '0');
  final datePicker = find.byType(DatePickerDialog);
  await h.enter(
    h.within(datePicker, find.byType(TextField)),
    '${two(day.month)}/${two(day.day)}/${day.year}',
  );
  await h.tap(h.within(datePicker, find.text('OK')));
  final timePicker = find.byType(TimePickerDialog);
  await h.until(
    () => datePicker.evaluate().isEmpty && timePicker.evaluate().length == 1,
    'review deadline time picker',
  );
  // The time picker opens at the current deadline in Institution time: 13:00Z is 22:00 in Asia/Tokyo.
  await h.tap(h.within(timePicker, find.text('OK')));
  await h.until(
    () => timePicker.evaluate().isEmpty,
    'review deadline time picker closed',
  );
  await h.until(
    () => find.text('Review deadline saved.').evaluate().isNotEmpty,
    'review deadline confirmation',
  );
  await _waitExact(h, overdue, 'Overdue: 0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

/// Steps 3-4: the task-scoped queue opens the only waiting submission.
Future<void> _openSubmissionFromTaskQueue(Stage9Harness h) async {
  final m = h.manifest;
  final attempt = m.reviewAttemptId;
  await h.tap(h.byKey('teacherTaskReviewQueueButton'));
  await h.waitRoute(
    AppRoutePaths.teacherHomeworkReviewsLocation(
      m.topic('review'),
      m.assessment('review_hw'),
    ),
  );
  await h.waitWidget(
    h.byKey('teacherReviewQueueScreen'),
    'Homework review queue',
  );
  await _waitExact(
    h,
    h.byKey('teacherReviewQueueScopeLabel'),
    'Submissions of this Homework',
  );
  final row = h.byKey('teacherReviewQueueRow:$attempt');
  await h.waitWidget(row, 'waiting submission row');
  await _queueSettled(h);
  expect(_queueRows(), findsOneWidget, reason: 'Only student #1 waits.');
  expect(
    h.within(row, find.textContaining('Waiting for review')),
    findsWidgets,
  );
  expect(
    h.within(row, find.textContaining('Reviewed 0 of 3 answers')),
    findsOneWidget,
  );

  await h.tap(row);
  await h.waitRoute(AppRoutePaths.teacherSubmissionDetailLocation(attempt));
  await h.waitWidget(
    h.byKey('teacherSubmissionDetailScreen'),
    'submission detail',
  );
  await _waitText(
    h,
    _questionCard(h, 'q1'),
    'Checked automatically · 2 of 2 points',
  );
  await _waitText(
    h,
    _questionCard(h, 'q2'),
    'Checked automatically · 2 of 3 points',
  );
  for (final label in const ['q3', 'q4', 'q5']) {
    final card = _questionCard(h, label);
    final answer = m.reviewAnswerId(label);
    expect(h.textIn(card, 'Waiting for review'), findsOneWidget);
    expect(
      h.within(card, h.byKey('teacherSubmissionReviewPoints:$answer')),
      findsOneWidget,
    );
    expect(
      h.within(card, h.byKey('teacherSubmissionReviewFeedback:$answer')),
      findsOneWidget,
    );
  }
  await _officialPanel(h, const ['Waiting for Teacher review.']);
}

/// Step 5: the protected download reaches the native Save As sink.
Future<void> _saveSubmittedFile(Stage9Harness h) async {
  await h.tap(
    h.byKey('teacherSubmissionFileSaveButton:${h.manifest.reviewFileId}'),
  );
  await h.until(() {
    h.sink.verify();
    return h.sink.saveCount == 1 &&
        find.text('File saved.').evaluate().isNotEmpty;
  }, 'protected Save of the submitted file');
}

/// Step 6: one answer reviewed; the Attempt still waits.
Future<void> _partialReview(Stage9Harness h) async {
  await _enterReview(h, 'q3', points: '4.5', feedback: _q3Feedback);
  await _saveReview(h, '1 answer changed');
  await _waitText(
    h,
    _questionCard(h, 'q3'),
    'Reviewed by $_teacherName · 4.5 of 5 points',
  );
  await _officialPanel(h, const ['Waiting for Teacher review.']);
}

/// Step 7: the last answers reviewed; the Attempt becomes official.
Future<List<String>> _fullReview(Stage9Harness h) async {
  await _enterReview(h, 'q4', points: '3.25', feedback: _q4Feedback);
  await _enterReview(h, 'q5', points: '5');
  await _saveReview(h, '2 answers changed');
  await _waitText(
    h,
    _questionCard(h, 'q4'),
    'Reviewed by $_teacherName · 3.25 of 5 points',
  );
  await _waitText(
    h,
    _questionCard(h, 'q5'),
    'Reviewed by $_teacherName · 5 of 5 points',
  );
  return _officialPanel(h, const [
    'Score 83.8',
    'Attempt 1 · Best checked attempt · This submission',
  ]);
}

/// Step 8: a correction; 73.85 must display half-up as 73.9.
Future<List<String>> _correctReview(Stage9Harness h) async {
  await _enterReview(h, 'q4', points: '1.27');
  await _saveReview(h, '1 answer changed');
  await _waitText(
    h,
    _questionCard(h, 'q4'),
    'Reviewed by $_teacherName · 1.27 of 5 points',
  );
  return _officialPanel(h, const [
    'Score 73.9',
    'Attempt 1 · Best checked attempt · This submission',
  ]);
}

/// Step 9: the exception grant through the monitoring dialog.
Future<String> _grantException(Stage9Harness h) async {
  final m = h.manifest;
  final topic = m.topic('review');
  final blitz = m.assessment('exception_blitz');
  final student = m.user('student');
  await h.go(AppRoutePaths.teacherBlitzDetailLocation(topic, blitz));
  await h.waitWidget(
    h.byKey('teacherBlitzDetailScreen'),
    'exception Blitz detail',
  );
  await _waitExact(
    h,
    h.byKey('teacherTaskReviewWaitingCount'),
    'Waiting for review: 0',
  );
  await h.tap(h.byKey('teacherBlitzMonitorButton'));
  await h.waitRoute(AppRoutePaths.teacherBlitzMonitoringLocation(topic, blitz));
  await h.waitWidget(
    h.byKey('teacherBlitzMonitoringScreen'),
    'monitoring screen',
  );
  await h.tap(h.byKey('teacherBlitzGrantButton:$student'));
  final dialog = h.byKey('teacherBlitzAttemptExceptionDialog');
  await h.waitWidget(dialog, 'grant dialog');
  expect(
    h.text(h.byKey('teacherBlitzAttemptExceptionOfficialScoreWarning')),
    _officialScoreWarning,
  );
  await h.choose(
    h.byKey('teacherBlitzAttemptExceptionReasonType'),
    'Technical problem',
  );
  await h.enter(h.byKey('teacherBlitzAttemptExceptionReason'), _grantReason);
  await h.tap(h.byKey('teacherBlitzAttemptExceptionSubmit'));
  await h.until(() => dialog.evaluate().isEmpty, 'grant dialog closed');
  await _waitExact(
    h,
    h.byKey('teacherBlitzGrantMessage'),
    'Additional Blitz attempt granted.',
  );
  expect(h.keys.issued, hasLength(1), reason: 'Only the grant is keyed.');
  return h.keys.issued.single;
}

/// Step 10: back to the workspace through earlier-stage screens, then the
/// global queue opens the invalidated Attempt #1.
Future<List<String>> _openReplacementFromGlobalQueue(Stage9Harness h) async {
  final m = h.manifest;
  final topic = m.topic('review');
  final attempt = m.exceptionAttempt1Id;
  await h.tap(h.byKey('teacherBlitzMonitoringBackButton'));
  await h.waitRoute(
    AppRoutePaths.teacherBlitzDetailLocation(
      topic,
      m.assessment('exception_blitz'),
    ),
  );
  await h.tap(h.byKey('teacherBlitzBackButton'));
  await h.waitRoute(AppRoutePaths.teacherTopicDetailLocation(topic));
  await h.tap(h.byKey('teacherTopicBackButton'));
  await h.waitRoute(AppRoutePaths.teacher);
  await h.waitWidget(h.byKey('teacherLearningWorkspace'), 'Teacher workspace');

  await h.tap(h.byKey('teacherReviewQueueButton'));
  await h.waitRoute(AppRoutePaths.teacherReviews);
  final queue = h.byKey('teacherReviewQueueScreen');
  await h.waitWidget(queue, 'global review queue');
  await h.choose(h.byKey('teacherReviewQueueStatusFilter'), 'Checked');
  await h.choose(h.byKey('teacherReviewQueueTypeFilter'), 'Blitz');
  await _queueSettled(h);
  final row = h.byKey('teacherReviewQueueRow:$attempt');
  await h.until(
    () =>
        row.evaluate().length == 1 &&
        h.textIn(row, 'Invalidated attempt').evaluate().isNotEmpty,
    'invalidated Blitz Attempt #1 row',
  );
  expect(
    h.within(queue, find.textContaining(RegExp(r'^Homework · '))),
    findsNothing,
    reason: 'The Task filter lists Blitz submissions only.',
  );

  await h.tap(row);
  await h.waitRoute(AppRoutePaths.teacherSubmissionDetailLocation(attempt));
  await h.waitWidget(
    h.byKey('teacherSubmissionDetailScreen'),
    'invalidated Attempt detail',
  );
  final lines = await _officialPanel(h, const [
    'Score 95.0',
    'Attempt 2 · Replacement attempt',
  ]);
  expect(
    h.within(
      h.byKey('teacherOfficialScorePanel'),
      find.textContaining('This submission'),
    ),
    findsNothing,
    reason: 'The replacement, not this submission, is official.',
  );
  return lines;
}

Finder _questionCard(Stage9Harness h, String label) => h.byKey(
  'teacherSubmissionQuestion:${h.manifest.question('review_hw', label)}',
);

Future<void> _enterReview(
  Stage9Harness h,
  String label, {
  required String points,
  String? feedback,
}) async {
  final answer = h.manifest.reviewAnswerId(label);
  await h.enter(h.byKey('teacherSubmissionReviewPoints:$answer'), points);
  if (feedback != null) {
    await h.enter(h.byKey('teacherSubmissionReviewFeedback:$answer'), feedback);
  }
}

Future<void> _saveReview(Stage9Harness h, String changed) async {
  final bar = h.byKey('teacherSubmissionReviewBar');
  await h.until(
    () => h.textIn(bar, changed).evaluate().isNotEmpty,
    'review bar "$changed"',
  );
  // An earlier confirmation must not stand in for this save.
  await h.until(
    () => find.text(_reviewSaved).evaluate().isEmpty,
    'previous review confirmation dismissed',
    timeout: const Duration(seconds: 20),
  );
  await h.tap(h.byKey('teacherSubmissionReviewSaveButton'));
  await h.until(() {
    final failure = h.byKey('teacherSubmissionReviewMessage');
    if (failure.evaluate().isNotEmpty) {
      throw TestFailure(
        'Stage 9 review save failed: ${h.texts(failure).join(' ')}',
      );
    }
    return find.text(_reviewSaved).evaluate().isNotEmpty &&
        h.textIn(bar, 'No unsaved changes').evaluate().isNotEmpty;
  }, 'confirmed review save');
}

/// Waits for the settled official-score panel and returns its lines.
Future<List<String>> _officialPanel(Stage9Harness h, List<String> lines) async {
  final panel = h.byKey('teacherOfficialScorePanel');
  await h.until(
    () =>
        panel.evaluate().length == 1 &&
        h.byKey('teacherOfficialScoreLoading').evaluate().isEmpty &&
        h.byKey('teacherOfficialScoreRefreshing').evaluate().isEmpty &&
        h
            .textIn(panel, 'The official score may be out of date.')
            .evaluate()
            .isEmpty &&
        lines.every((line) => h.textIn(panel, line).evaluate().isNotEmpty),
    'official score panel showing ${lines.join(' / ')}',
  );
  return h.texts(panel);
}

Finder _queueRows() => find.byWidgetPredicate(
  (widget) =>
      widget is Card &&
      switch (widget.key) {
        ValueKey<String>(:final value) => value.startsWith(
          'teacherReviewQueueRow:',
        ),
        _ => false,
      },
);

Future<void> _queueSettled(Stage9Harness h) {
  final queue = h.byKey('teacherReviewQueueScreen');
  return h.until(
    () =>
        queue.evaluate().length == 1 &&
        h.byKey('teacherReviewQueueLoading').evaluate().isEmpty &&
        h.byKey('teacherReviewQueueStaleMessage').evaluate().isEmpty &&
        h
            .within(queue, find.byType(LinearProgressIndicator))
            .evaluate()
            .isEmpty,
    'settled review queue',
  );
}

// ---------------------------------------------------------------- Student results

/// Steps 12-15 for the Student of the automatic-release Institution.
Future<Map<String, Object?>> _studentResults(Stage9Harness h) async {
  final m = h.manifest;
  final blitz = m.assessment('exception_blitz');
  final topic = m.topic('review');
  final homework = m.assessment('review_hw');
  final attempt = m.reviewAttemptId;
  final observed = <String, Object?>{};

  final card = h.byKey('studentFinishedBlitzCard$blitz');
  final blitzResult = h.byKey('studentFinishedBlitzResult$blitz');
  final blitzFeedback = h.byKey('studentFinishedBlitzFeedback$blitz');
  await h.until(
    () =>
        card.evaluate().length == 1 &&
        h.textIn(blitzResult, 'Score 95.0').evaluate().isNotEmpty,
    'finished Blitz replacement score',
  );
  expect(h.textIn(card, 'Attempt 1 was invalidated.'), findsOneWidget);
  expect(
    h.within(
      blitzFeedback,
      find.textContaining('Question 2: Replacement feedback.'),
    ),
    findsOneWidget,
  );
  observed['finished_blitz'] = {
    'result': h.texts(blitzResult),
    'card': h.texts(card),
    'feedback': h.texts(blitzFeedback),
  };

  await h.go(AppRoutePaths.studentTopicDetailLocation(topic));
  await h.waitWidget(
    h.byKey('studentTopicDetailScreen'),
    'review Topic detail',
  );
  final topicScore = h.byKey('studentHomeworkOfficialScore$homework');
  await h.until(
    () => h.textIn(topicScore, 'Official score: 73.9').evaluate().isNotEmpty,
    'Topic Homework official score',
  );
  observed['topic_official_score'] = h.texts(topicScore);

  await h.tap(h.byKey('studentHomeworkOpen$homework'));
  await h.waitRoute(
    AppRoutePaths.studentHomeworkDetailLocation(topic, homework),
  );
  await h.waitWidget(h.byKey('studentHomeworkResultsCard'), 'Results card');
  final official = h.byKey('studentHomeworkOfficialScore');
  final attemptResult = h.byKey('studentHomeworkAttemptResult$attempt');
  await h.until(
    () =>
        h
            .textIn(official, 'Official score: 73.9 (Attempt 1)')
            .evaluate()
            .isNotEmpty &&
        h
            .textIn(attemptResult, 'Attempt 1 · Checked · Score 73.9')
            .evaluate()
            .isNotEmpty,
    'Homework results',
  );
  observed['homework_official_score'] = h.texts(official);
  observed['homework_attempt_result'] = h.texts(attemptResult);

  await h.tap(h.byKey('studentHomeworkOpenAttempt$attempt'));
  await h.waitRoute(
    AppRoutePaths.studentHomeworkAttemptLocation(topic, homework, attempt),
  );
  final screen = h.byKey('studentHomeworkAttemptScreen');
  await h.waitWidget(screen, 'Attempt screen');
  Finder feedback(String label) =>
      h.byKey('studentAttemptFeedback${m.question('review_hw', label)}');
  final score = h.byKey('studentHomeworkAttemptResult');
  await h.until(
    () =>
        h.textIn(score, 'Score 73.9').evaluate().isNotEmpty &&
        feedback('q3').evaluate().length == 1 &&
        feedback('q4').evaluate().length == 1,
    'released Attempt result and feedback',
  );
  expect(
    h.within(feedback('q3'), find.textContaining(_q3Feedback)),
    findsOneWidget,
  );
  expect(
    h.within(feedback('q4'), find.textContaining(_q4Feedback)),
    findsOneWidget,
  );
  for (final label in const ['q1', 'q2', 'q5']) {
    expect(feedback(label), findsNothing, reason: 'No feedback on $label.');
  }
  for (final hidden in const [
    'Correct answer',
    'Accepted answers',
    'Checked automatically',
    'Reviewed by',
  ]) {
    expect(
      h.within(screen, find.textContaining(hidden)),
      findsNothing,
      reason: 'The Student never sees "$hidden".',
    );
  }
  observed['attempt_feedback'] = {
    'q3': h.texts(feedback('q3')),
    'q4': h.texts(feedback('q4')),
  };
  observed['attempt_result'] = h.texts(score);
  return observed;
}

/// Step 17: the manual-release Student sees no score and no feedback.
Future<void> _manualStudentHiddenResults(Stage9Harness h) async {
  final m = h.manifest;
  final topic = m.topic('manual');
  final homework = m.assessment('manual_hw');
  final attempt = m.manualAttemptId;
  await h.go(AppRoutePaths.studentHomeworkDetailLocation(topic, homework));
  await h.waitWidget(h.byKey('studentHomeworkResultsCard'), 'Results card');
  final attemptResult = h.byKey('studentHomeworkAttemptResult$attempt');
  await h.until(
    () => h
        .textIn(attemptResult, 'Attempt 1 · Checked · Result not available yet')
        .evaluate()
        .isNotEmpty,
    'hidden manual Attempt result',
  );
  expect(h.byKey('studentHomeworkOfficialScore'), findsNothing);

  await h.tap(h.byKey('studentHomeworkOpenAttempt$attempt'));
  await h.waitRoute(
    AppRoutePaths.studentHomeworkAttemptLocation(topic, homework, attempt),
  );
  await h.waitWidget(
    h.byKey('studentHomeworkAttemptScreen'),
    'manual Attempt screen',
  );
  await h.until(
    () => h
        .textIn(h.byKey('studentHomeworkAttemptResult'), 'Not available yet')
        .evaluate()
        .isNotEmpty,
    'hidden manual Attempt score',
  );
  expect(
    find.byWidgetPredicate(
      (widget) => switch (widget.key) {
        ValueKey<String>(:final value) => value.startsWith(
          'studentAttemptFeedback',
        ),
        _ => false,
      },
    ),
    findsNothing,
    reason: 'Hidden results carry no feedback.',
  );
}

Future<void> _waitExact(Stage9Harness h, Finder target, String text) => h.until(
  () => target.evaluate().length == 1 && h.text(target) == text,
  '"$text" in ${target.describeMatch(Plurality.one)}',
);

Future<void> _waitText(Stage9Harness h, Finder scope, String text) => h.until(
  () => h.textIn(scope, text).evaluate().isNotEmpty,
  '"$text" in ${scope.describeMatch(Plurality.one)}',
);
