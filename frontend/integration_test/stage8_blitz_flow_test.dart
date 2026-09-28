import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/presentation/student_file_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_answer_editor.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';

import 'stage8_e2e_support.dart';

const _shortAnswer = 'O‘zbekiston — E2E S08 UI';
const _openAnswer = "E2E S08 first line\nStudent's second line";
const _blankAnswer = 'E2E S08 UI blank';
const _grantReason = 'E2E S08 UI technical problem during the Blitz';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Stage 8 Blitz uses the real Windows stack',
    (tester) async {
      final harness = await Stage8Harness.create(tester);
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

Future<void> _flow(Stage8Harness h) async {
  final m = h.manifest;
  final keys = <String, String>{};

  await h.signIn('teacher', teacher: true);
  final builderBlitz = await _teacherBuilderSmoke(h, m.topic('builder'));
  await h.checkpoint('builder_archived', {'blitz_id': builderBlitz});
  await _teacherOfficialActivation(
    h,
    m.topic('official'),
    m.assessment('main'),
  );
  keys['activate'] = h.keys.issued.single;
  await h.checkpoint('official_activated', {'key': keys['activate']});
  await h.signOut();

  await h.signIn('student', teacher: false);
  final fileId = await _studentFirstAttempt(h, keys);
  await h.signOut();

  await h.signIn('teacher', teacher: true);
  await _teacherMonitoringAndGrant(h, keys);
  await h.signOut();

  await h.signIn('student', teacher: false);
  await _studentReplacement(h, keys);
  await h.signOut();

  await h.signIn('d_timeout_ui', teacher: false);
  await _studentTimeout(h, keys);

  expect(h.keys.issued.length, 8, reason: 'Exactly eight keyed UI operations.');
  expect(h.picker.consumed, 1);
  expect(h.sink.openCount, 1);
  expect(h.sink.saveCount, 1);
  await h.writeJson(h.evidence, {
    'version': 1,
    'keys': keys,
    'file_id': fileId,
    'builder_blitz_id': builderBlitz,
    'picker_consumed': h.picker.consumed,
    'open_count': h.sink.openCount,
    'save_count': h.sink.saveCount,
  });
}

// ---------------------------------------------------------------- Teacher preparation

Future<String> _teacherBuilderSmoke(Stage8Harness h, String topic) async {
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topic));
  await h.waitWidget(h.byKey('teacherBlitzSection'), 'Topic Blitz section');
  await h.tap(h.byKey('teacherBlitzCreateButton'));
  await h.waitWidget(
    h.byKey('teacherBlitzCreateScreen'),
    'Blitz create screen',
  );
  await h.enter(h.byKey('teacherBlitzTitleField'), 'E2E S08 UI Blitz');
  await h.enter(
    h.byKey('teacherBlitzInstructionsField'),
    'E2E S08 UI instructions',
  );
  await h.enter(h.byKey('teacherBlitzDurationField'), '300');
  await h.tap(h.byKey('teacherBlitzCreateSubmitButton'));
  await h.until(
    () => AppRoutePaths.isTeacherBlitzDetailPath(h.route.path),
    'created Blitz detail route',
  );
  final blitzId = AppRoutePaths.teacherBlitzIdFromPath(h.route.path)!;
  final detail = h.byKey('teacherBlitzDetailScreen');
  await _waitText(h, detail, 'Draft');

  await h.tap(h.byKey('teacherBlitzEditButton'));
  await h.waitWidget(h.byKey('teacherBlitzEditScreen'), 'Blitz edit screen');
  await h.enter(h.byKey('teacherBlitzTitleField'), 'E2E S08 UI Blitz edited');
  await h.tap(h.byKey('teacherBlitzEditSubmitButton'));
  await h.waitRoute(AppRoutePaths.teacherBlitzDetailLocation(topic, blitzId));
  await h.until(
    () =>
        h.byKey('teacherBlitzDetailTitle').evaluate().length == 1 &&
        h.text(h.byKey('teacherBlitzDetailTitle')) == 'E2E S08 UI Blitz edited',
    'edited Blitz title',
  );

  await h.tap(h.byKey('teacherBlitzManageQuestionsButton'));
  await h.waitWidget(
    h.byKey('teacherBlitzQuestionBuilderScreen'),
    'Blitz Question Builder',
  );
  await h.tap(h.byKey('teacherBlitzQuestionBuilderAddButton'));
  await h.waitWidget(h.byKey('teacherQuestionEditorDialog'), 'Question editor');
  await h.choose(
    find.descendant(
      of: h.byKey('teacherQuestionTypeField'),
      matching: find.byType(DropdownButton<TeacherQuestionType>),
    ),
    'True/False',
  );
  final confirmType = h.byKey('teacherQuestionConfirmTypeButton');
  if (confirmType.evaluate().isNotEmpty) await h.tap(confirmType);
  await h.enter(h.byKey('teacherQuestionPromptField'), 'E2E S08 UI True False');
  await h.tap(h.byKey('teacherQuestionEditorSubmitButton'));
  await h.until(
    () => h.byKey('teacherQuestionEditorDialog').evaluate().isEmpty,
    'saved Question editor closed',
  );
  await h.until(
    () =>
        h.byKey('teacherBlitzQuestionBuilderTotalPoints').evaluate().length ==
            1 &&
        h
            .textIn(
              h.byKey('teacherBlitzQuestionBuilderTotalPoints'),
              'Total points: 1',
            )
            .evaluate()
            .isNotEmpty,
    'server-authoritative Question points',
  );
  await h.tap(h.byKey('teacherBlitzQuestionBuilderBackButton'));
  await h.waitWidget(detail, 'Blitz detail after Questions');

  await h.tap(h.byKey('teacherBlitzScheduleButton'));
  await h.waitWidget(h.byKey('teacherBlitzScheduleDialog'), 'Schedule dialog');
  await h.tap(h.byKey('teacherBlitzScheduleDateButton'));
  await h.until(
    () => find.byTooltip('Switch to input').evaluate().isNotEmpty,
    'date picker',
  );
  await h.tester.tap(find.byTooltip('Switch to input'));
  await h.tester.pump();
  final day = DateTime.now().add(const Duration(days: 2));
  final typed =
      '${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')}/${day.year}';
  final dateField = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byType(TextField),
  );
  await h.enter(dateField, typed);
  await h.tapText('OK');
  await h.until(
    () => find.byType(DatePickerDialog).evaluate().isEmpty,
    'date picker closed',
  );
  await h.tap(h.byKey('teacherBlitzScheduleTimeButton'));
  await h.until(() => find.text('OK').evaluate().isNotEmpty, 'time picker');
  await h.tapText('OK');
  await h.pumpFor(const Duration(milliseconds: 400));
  await h.tap(h.byKey('teacherBlitzScheduleSubmitButton'));
  await h.until(
    () => h.byKey('teacherBlitzScheduleDialog').evaluate().isEmpty,
    'scheduled',
  );
  await _waitText(h, detail, 'Scheduled');
  expect(
    h.text(h.byKey('teacherBlitzScheduleNote')),
    contains('does not start automatically'),
    reason: 'Scheduling is preparation only.',
  );

  await h.tap(h.byKey('teacherBlitzArchiveButton'));
  await h.waitWidget(
    h.byKey('teacherBlitzConfirmDialog'),
    'Archive confirmation',
  );
  await h.tap(h.byKey('teacherBlitzConfirmButton'));
  await _waitText(h, detail, 'Archived');
  expect(
    h.keys.issued,
    isEmpty,
    reason: 'Authoring never needs an idempotency key.',
  );
  return blitzId;
}

Future<void> _teacherOfficialActivation(
  Stage8Harness h,
  String topic,
  String blitz,
) async {
  await h.go(AppRoutePaths.teacherBlitzDetailLocation(topic, blitz));
  final detail = h.byKey('teacherBlitzDetailScreen');
  await h.waitWidget(detail, 'official candidate Blitz');
  // The locked pair keeps its Homework and cohort; its empty Blitz side can still be filled.
  await h.waitWidget(
    h.byKey('teacherBlitzSetOfficialButton'),
    'official action',
  );
  expect(
    h.textIn(h.byKey('teacherBlitzSetOfficialButton'), 'Set as Official Blitz'),
    findsOneWidget,
  );
  await h.tap(h.byKey('teacherBlitzSetOfficialButton'));
  await h.waitWidget(
    h.byKey('teacherBlitzConfirmDialog'),
    'official confirmation',
  );
  await h.tap(h.byKey('teacherBlitzConfirmButton'));
  await h.waitWidget(
    h.byKey('teacherBlitzDetailOfficialChip'),
    'Official badge',
  );
  await h.tap(h.byKey('teacherBlitzActivateButton'));
  await h.waitWidget(
    h.byKey('teacherBlitzConfirmDialog'),
    'activation confirmation',
  );
  await h.tap(h.byKey('teacherBlitzConfirmButton'));
  await h.waitWidget(h.byKey('teacherBlitzMonitorButton'), 'Active Blitz');
  await _waitText(h, detail, 'Active');
  await _waitText(h, detail, 'Synchronized');
}

// ---------------------------------------------------------------- Student execution

Future<String> _studentFirstAttempt(
  Stage8Harness h,
  Map<String, String> keys,
) async {
  final m = h.manifest;
  final main = m.assessment('main');
  final topic = m.topic('official');
  await h.waitWidget(
    h.byKey('studentActiveBlitzSection'),
    'active Blitz section',
  );
  await h.tap(h.byKey('studentActiveBlitzOpen$main'));
  await h.waitRoute(AppRoutePaths.studentBlitzDetailLocation(topic, main));
  await h.waitWidget(
    h.byKey('studentBlitzDetailScreen'),
    'Student Blitz detail',
  );
  await _expectDecreasingCountdown(h, 'synchronized pre-Start countdown');
  _expectNoQuestionContent(h);
  final refresh = h.byKey('studentBlitzRefreshButton');
  await h.tap(refresh);
  await h.until(
    () =>
        refresh.evaluate().length == 1 &&
        h.tester.widget<ButtonStyleButton>(refresh).onPressed != null,
    'pre-Start refresh settled',
  );
  _expectNoQuestionContent(h);
  await h.checkpoint('pre_start_viewed', {});

  await h.tap(h.byKey('studentBlitzStartButton'));
  await h.waitWidget(h.byKey('studentBlitzStartDialog'), 'Start confirmation');
  await h.tap(h.byKey('studentBlitzStartConfirmButton'));
  await h.waitWidget(
    find.byKey(const PageStorageKey<String>('studentBlitzAttemptShell')),
    'Attempt #1 shell',
  );
  expect(h.text(h.byKey('studentBlitzAttemptNumber')), 'Attempt 1');
  keys['start1'] = h.keys.issued[1];
  await _expectDecreasingCountdown(h, 'Attempt #1 countdown');

  final expected = await _saveEveryType(h);
  final fileId = await _uploadAndTransfer(h);
  expected.add({
    'question_id': m.question('main', 'file_based'),
    'type': 'file_based',
    'values': [fileId],
  });

  final before = _countdownSeconds(h);
  final topicRoute = AppRoutePaths.studentTopicDetailLocation(topic);
  final confirmLeave = h.byKey('studentBlitzLeaveConfirmButton');
  await h.tap(h.byKey('studentBlitzLeaveButton'));
  // The confirmation dialog key depends on pending writes; its confirm button does not.
  await h.until(
    () =>
        confirmLeave.evaluate().isNotEmpty || h.route.toString() == topicRoute,
    'leave confirmation',
  );
  if (confirmLeave.evaluate().isNotEmpty) await h.tap(confirmLeave);
  await h.waitRoute(topicRoute);
  await h.go(AppRoutePaths.studentBlitzDetailLocation(topic, main));
  await h.tap(h.byKey('studentBlitzResumeButton'));
  await h.waitWidget(
    find.byKey(const PageStorageKey<String>('studentBlitzAttemptShell')),
    'resumed Attempt #1',
  );
  keys['resume1'] = h.keys.issued[2];
  expect(
    _countdownSeconds(h),
    lessThanOrEqualTo(before),
    reason: 'Resume never resets the deadline.',
  );
  await _expectRestored(h);

  await _submit(h, unanswered: true);
  keys['submit1'] = h.keys.issued[3];
  await h.checkpoint('first_submitted', {
    'start_key': keys['start1'],
    'submit_key': keys['submit1'],
    'file_id': fileId,
    'answered_question_ids': [
      for (final label in [
        'single_choice',
        'multiple_choice',
        'true_false',
        'short_written',
        'open_written',
        'file_based',
        'matching',
        'ordering',
        'fill_in_blank',
      ])
        m.question('main', label),
    ],
    'expected_answers': expected,
  });
  return fileId;
}

Future<List<Map<String, Object?>>> _saveEveryType(Stage8Harness h) async {
  final m = h.manifest;
  String q(String label) => m.question('main', label);
  final single = (m.nested('main', 'single_choice')! as List).cast<String>();
  final multiple = (m.nested('main', 'multiple_choice')! as List)
      .cast<String>();
  final matching = m.nested('main', 'matching')! as Map<String, dynamic>;
  final left = (matching['left'] as List).cast<String>();
  final right = (matching['right'] as List).cast<String>();
  final ordering = (m.nested('main', 'ordering')! as List).cast<String>();
  final blanks =
      ((m.nested('main', 'fill_in_blank')! as Map<String, dynamic>)['blanks']
              as List)
          .cast<String>();

  await h.tap(h.byKey('studentOption${single[1]}'));
  await _save(h, q('single_choice'));
  await h.tap(h.byKey('studentOption${multiple[0]}'));
  await h.tap(h.byKey('studentOption${multiple[2]}'));
  await _save(h, q('multiple_choice'));
  await h.tap(
    h.within(
      h.byKey('studentAnswerEditor${q('true_false')}'),
      find.byWidgetPredicate(
        (widget) => widget is RadioListTile<bool> && widget.value,
      ),
    ),
  );
  await _save(h, q('true_false'));
  await h.enter(
    h.within(
      h.byKey('studentAnswerEditor${q('short_written')}'),
      find.byType(TextField),
    ),
    _shortAnswer,
  );
  await _save(h, q('short_written'));
  await h.enter(
    h.within(
      h.byKey('studentAnswerEditor${q('open_written')}'),
      find.byType(TextField),
    ),
    _openAnswer,
  );
  await _save(h, q('open_written'));
  await _select<String>(h, h.byKey('studentMatching${left[0]}'), right[1]);
  await _save(h, q('matching'));
  await _select<int>(h, h.byKey('studentOrdering${ordering[1]}'), 1);
  await _select<int>(h, h.byKey('studentOrdering${ordering[0]}'), 2);
  await _save(h, q('ordering'));
  await h.enter(
    h.within(h.byKey('studentBlank${blanks[0]}'), find.byType(TextField)),
    _blankAnswer,
  );
  await _save(h, q('fill_in_blank'));
  return [
    {
      'question_id': q('single_choice'),
      'type': 'single_choice',
      'values': [single[1]],
    },
    {
      'question_id': q('multiple_choice'),
      'type': 'multiple_choice',
      'values': [multiple[0], multiple[2]],
    },
    {
      'question_id': q('true_false'),
      'type': 'true_false',
      'values': [true],
    },
    {
      'question_id': q('short_written'),
      'type': 'short_written',
      'values': [_shortAnswer],
    },
    {
      'question_id': q('open_written'),
      'type': 'open_written',
      'values': [_openAnswer],
    },
    {
      'question_id': q('matching'),
      'type': 'matching',
      'values': ['${left[0]}:${right[1]}'],
    },
    {
      'question_id': q('ordering'),
      'type': 'ordering',
      'values': ['${ordering[1]}:1', '${ordering[0]}:2'],
    },
    {
      'question_id': q('fill_in_blank'),
      'type': 'fill_in_blank',
      'values': ['${blanks[0]}:$_blankAnswer'],
    },
  ];
}

Finder _editorFinder(String questionId) => find.byWidgetPredicate(
  (widget) =>
      widget is StudentQuestionAnswerEditor &&
      widget.state.question.id == questionId,
);

StudentQuestionAnswerEditor _editor(Stage8Harness h, String questionId) =>
    h.tester.widget<StudentQuestionAnswerEditor>(_editorFinder(questionId));

Future<void> _save(Stage8Harness h, String questionId) async {
  await h.tap(h.byKey('studentSaveAnswer$questionId'));
  await h.until(() {
    if (_editorFinder(questionId).evaluate().length != 1) return false;
    final state = _editor(h, questionId).state;
    return state.saveStatus == StudentAnswerSaveStatus.saved &&
        state.serverAnswer != null &&
        !state.isDirty;
  }, 'server-confirmed saved answer $questionId');
  _expectNoChecking(h, h.byKey('studentAnswerEditor$questionId'));
}

Future<void> _select<T>(Stage8Harness h, Finder dropdown, T value) async {
  await h.tap(dropdown);
  final item = find.byWidgetPredicate(
    (widget) => widget is DropdownMenuItem<T> && widget.value == value,
  );
  await h.until(() => item.evaluate().isNotEmpty, 'dropdown item $value');
  final child = h.tester.widget<DropdownMenuItem<T>>(item.last).child;
  await h.tester.tap(find.byWidget(child).last);
  await h.tester.pump();
  await h.until(
    () => h.tester.widget<DropdownButton<T>>(dropdown).value == value,
    'selected dropdown value $value',
  );
}

Finder _fileEditorFinder(String questionId) => find.byWidgetPredicate(
  (widget) =>
      widget is StudentFileAnswerEditor &&
      widget.state.question.id == questionId,
);

Finder _fileButton(Stage8Harness h, String questionId, String label) {
  final card = h.byKey('studentFileAnswerCard$questionId');
  return h.within(
    card,
    find.ancestor(
      of: h.textIn(card, label),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    ),
  );
}

Future<String> _uploadAndTransfer(Stage8Harness h) async {
  final question = h.manifest.question('main', 'file_based');
  StudentFileAnswerEditor editor() =>
      h.tester.widget<StudentFileAnswerEditor>(_fileEditorFinder(question));
  await h.tap(_fileButton(h, question, 'Choose file'));
  await h.until(
    () =>
        _fileEditorFinder(question).evaluate().length == 1 &&
        editor().state.status == StudentFileAnswerStatus.ready,
    'native picker selection accepted',
  );
  await h.tap(_fileButton(h, question, 'Upload answer'));
  await h.until(
    () =>
        _fileEditorFinder(question).evaluate().length == 1 &&
        editor().state.serverFile?.originalName ==
            h.fixtures['answer_pdf'].name &&
        editor().state.status != StudentFileAnswerStatus.uploading &&
        editor().state.failure == null,
    'server-confirmed file upload',
  );
  final fileId = editor().state.serverFile!.id;
  h.sink.expectedFileId = fileId;
  await h.tap(_fileButton(h, question, 'Open'));
  await h.until(() => h.sink.openCount == 1, 'protected Open exact bytes');
  await h.tap(_fileButton(h, question, 'Save As…'));
  await h.until(() => h.sink.saveCount == 1, 'protected Save As exact bytes');
  return fileId;
}

Future<void> _expectRestored(Stage8Harness h) async {
  final m = h.manifest;
  for (final label in [
    'single_choice',
    'multiple_choice',
    'true_false',
    'short_written',
    'open_written',
    'matching',
    'ordering',
    'fill_in_blank',
  ]) {
    final questionId = m.question('main', label);
    await h.until(
      () =>
          _editorFinder(questionId).evaluate().length == 1 &&
          _editor(h, questionId).state.serverAnswer != null &&
          !_editor(h, questionId).state.isDirty,
      'restored $label answer after Resume',
    );
  }
  expect(
    _editor(h, m.question('main', 'unanswered')).state.serverAnswer,
    isNull,
  );
}

Future<void> _submit(Stage8Harness h, {required bool unanswered}) async {
  await h.tap(h.byKey('studentBlitzSubmitButton'));
  await h.waitWidget(
    h.byKey('studentBlitzSubmitConfirmDialog'),
    'Submit confirmation',
  );
  expect(
    h.byKey('studentBlitzUnansweredWarning'),
    unanswered ? findsOneWidget : findsNothing,
    reason: 'Unanswered Questions are allowed and announced.',
  );
  await h.tap(h.byKey('studentBlitzSubmitConfirmButton'));
  await h.until(
    () =>
        h.byKey('studentBlitzFinalizationHeading').evaluate().length == 1 &&
        h.text(h.byKey('studentBlitzFinalizationHeading')) == 'Submitted',
    'terminal Submitted state',
  );
  _expectNoChecking(h, h.byKey('studentBlitzTerminalView'));
}

// ---------------------------------------------------------------- Teacher monitoring and grant

Future<void> _teacherMonitoringAndGrant(
  Stage8Harness h,
  Map<String, String> keys,
) async {
  final m = h.manifest;
  final student = m.user('student');
  final peer = m.user('peer');
  final topic = m.topic('official');
  final main = m.assessment('main');
  await h.go(AppRoutePaths.teacherBlitzDetailLocation(topic, main));
  await h.waitWidget(h.byKey('teacherBlitzMonitorButton'), 'Monitor action');
  await h.tap(h.byKey('teacherBlitzMonitorButton'));
  await h.waitRoute(AppRoutePaths.teacherBlitzMonitoringLocation(topic, main));
  final screen = h.byKey('teacherBlitzMonitoringScreen');
  await h.waitWidget(screen, 'monitoring screen');
  final studentRow = h.byKey('teacherBlitzMonitoringStudent:$student');
  final peerRow = h.byKey('teacherBlitzMonitoringStudent:$peer');
  await h.until(
    () =>
        h.textIn(studentRow, 'Finalized').evaluate().isNotEmpty &&
        h.textIn(peerRow, 'Not started').evaluate().isNotEmpty,
    'initial monitoring snapshot',
  );
  _expectNoChecking(h, screen);
  // Monitoring polls only while the app is resumed, so the test window must keep focus.
  final lifecycle = WidgetsBinding.instance.lifecycleState;
  expect(
    lifecycle == null || lifecycle == AppLifecycleState.resumed,
    isTrue,
    reason: 'The Windows test window must keep focus (lifecycle: $lifecycle).',
  );
  // The runner starts the peer's Attempt through the API; polling alone must reveal it.
  await h.checkpoint('monitoring_open', {});
  await h.until(
    () => h.textIn(peerRow, 'In progress').evaluate().isNotEmpty,
    'automatic monitoring refresh without user action',
    timeout: const Duration(seconds: 40),
  );

  expect(
    h.textIn(
      h.byKey('teacherBlitzGrantButton:$student'),
      'Grant additional attempt',
    ),
    findsOneWidget,
  );
  await h.tap(h.byKey('teacherBlitzGrantButton:$student'));
  await h.waitWidget(
    h.byKey('teacherBlitzAttemptExceptionDialog'),
    'grant dialog',
  );
  await h.choose(
    h.byKey('teacherBlitzAttemptExceptionReasonType'),
    'Technical problem',
  );
  await h.enter(h.byKey('teacherBlitzAttemptExceptionReason'), _grantReason);
  await h.tap(h.byKey('teacherBlitzAttemptExceptionSubmit'));
  await h.waitWidget(h.byKey('teacherBlitzGrantMessage'), 'grant confirmation');
  await h.until(
    () =>
        h
            .textIn(studentRow, 'Additional attempt granted')
            .evaluate()
            .isNotEmpty &&
        h.textIn(studentRow, 'Not started').evaluate().isNotEmpty,
    'granted Student projected as not started',
  );
  keys['grant'] = h.keys.issued[4];
  await h.checkpoint('granted', {'key': keys['grant'], 'reason': _grantReason});
}

// ---------------------------------------------------------------- replacement and timeout

Future<void> _studentReplacement(
  Stage8Harness h,
  Map<String, String> keys,
) async {
  final m = h.manifest;
  final main = m.assessment('main');
  await h.go(
    AppRoutePaths.studentBlitzDetailLocation(m.topic('official'), main),
  );
  await h.waitWidget(
    h.byKey('studentBlitzStartAdditionalButton'),
    'additional attempt action',
  );
  expect(
    h.textIn(
      h.byKey('studentBlitzStartAdditionalButton'),
      'Start additional attempt',
    ),
    findsOneWidget,
  );
  await h.tap(h.byKey('studentBlitzStartAdditionalButton'));
  await h.waitWidget(
    h.byKey('studentBlitzStartAdditionalDialog'),
    'additional attempt confirmation',
  );
  await h.tap(h.byKey('studentBlitzStartAdditionalConfirmButton'));
  await h.waitWidget(
    find.byKey(const PageStorageKey<String>('studentBlitzAttemptShell')),
    'replacement Attempt #2 shell',
  );
  expect(
    h.text(h.byKey('studentBlitzAttemptNumber')),
    'Additional attempt (Attempt 2)',
  );
  keys['start2'] = h.keys.issued[5];
  expect(
    _countdownSeconds(h),
    greaterThanOrEqualTo(1790),
    reason: 'The replacement gets its own full duration.',
  );
  final short = m.question('main', 'short_written');
  await h.enter(
    h.within(h.byKey('studentAnswerEditor$short'), find.byType(TextField)),
    'E2E S08 UI replacement answer',
  );
  await _save(h, short);
  await _submit(h, unanswered: true);
  keys['submit2'] = h.keys.issued[6];
  await h.checkpoint('replacement_submitted', {
    'start_key': keys['start2'],
    'submit_key': keys['submit2'],
    'answered_question_ids': [short],
  });
}

Future<void> _studentTimeout(Stage8Harness h, Map<String, String> keys) async {
  final m = h.manifest;
  final blitz = m.assessment('timeout_ui');
  await h.waitWidget(
    h.byKey('studentActiveBlitzSection'),
    'active Blitz section',
  );
  await h.tap(h.byKey('studentActiveBlitzOpen$blitz'));
  await h.waitWidget(
    h.byKey('studentBlitzDetailScreen'),
    'timeout Blitz detail',
  );
  await h.waitWidget(
    h.byKey('studentBlitzIndividualTiming'),
    'individual pre-Start timing',
  );
  expect(h.byKey('studentBlitzStartButton'), findsOneWidget);
  expect(
    h.byKey('studentBlitzCountdownValue'),
    findsNothing,
    reason: 'Individual pre-Start has no effective countdown.',
  );
  await h.tap(h.byKey('studentBlitzStartButton'));
  await h.waitWidget(h.byKey('studentBlitzStartDialog'), 'Start confirmation');
  await h.tap(h.byKey('studentBlitzStartConfirmButton'));
  await h.waitWidget(
    find.byKey(const PageStorageKey<String>('studentBlitzAttemptShell')),
    'timeout Attempt shell',
  );
  keys['timeout_start'] = h.keys.issued[7];
  await _expectDecreasingCountdown(h, 'individual Attempt countdown');
  final short = m.question('timeout_ui', 'short_written');
  await h.enter(
    h.within(h.byKey('studentAnswerEditor$short'), find.byType(TextField)),
    'E2E S08 saved before the deadline',
  );
  await _save(h, short);
  final open = m.question('timeout_ui', 'open_written');
  await h.enter(
    h.within(h.byKey('studentAnswerEditor$open'), find.byType(TextField)),
    'E2E S08 unsaved local draft',
  );
  // No user action from here: local zero replays the completed Start and the server finalizes.
  await h.until(
    () =>
        h.byKey('studentBlitzFinalizationHeading').evaluate().length == 1 &&
        h.text(h.byKey('studentBlitzFinalizationHeading')) == 'Time expired',
    'server-authoritative timeout',
    timeout: const Duration(seconds: 120),
  );
  expect(
    h.textIn(h.byKey('studentBlitzFinalizationSummary'), '1 of 2'),
    findsOneWidget,
    reason: 'Only the saved answer counts; the unsaved local draft does not.',
  );
  expect(
    h.keys.issued.length,
    8,
    reason: 'Timeout never submits or starts again.',
  );
  await h.checkpoint('timed_out', {'start_key': keys['timeout_start']});
}

// ---------------------------------------------------------------- shared checks

void _expectNoQuestionContent(Stage8Harness h) {
  expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
  expect(
    find.byKey(const PageStorageKey<String>('studentBlitzAttemptShell')),
    findsNothing,
  );
  expect(
    find.textContaining(
      RegExp(
        r'E2E S08 (Single Choice|Multiple Choice|True False|Short Written|'
        r'Open Written|File Based|Matching|Ordering|Fill In Blank|Unanswered)',
      ),
    ),
    findsNothing,
    reason: 'Question prompts stay hidden before Start.',
  );
}

Future<void> _waitText(Stage8Harness h, Finder scope, String text) => h.until(
  () => h.textIn(scope, text).evaluate().isNotEmpty,
  '"$text" in ${scope.describeMatch(Plurality.one)}',
);

int _countdownSeconds(Stage8Harness h) {
  final value = h.text(h.byKey('studentBlitzCountdownValue'));
  final parts = value.split(':').map(int.parse).toList();
  return parts.fold(0, (total, part) => total * 60 + part);
}

Future<void> _expectDecreasingCountdown(Stage8Harness h, String label) async {
  await h.waitWidget(h.byKey('studentBlitzCountdownValue'), label);
  final first = _countdownSeconds(h);
  await h.pumpFor(const Duration(milliseconds: 2600));
  final second = _countdownSeconds(h);
  expect(second, lessThan(first), reason: '$label decreases.');
  expect(
    first - second,
    lessThanOrEqualTo(4),
    reason: '$label follows real time.',
  );
}

void _expectNoChecking(Stage8Harness h, Finder scope) {
  // Stage 8 never checks or scores; static possible points are permitted.
  const forbidden = [
    'Correct answer',
    'Incorrect answer',
    'Checked',
    'Awarded points',
    'Earned points',
    'Normalized score',
    'Your score',
    'Score',
    'Teacher feedback',
  ];
  for (final label in forbidden) {
    expect(
      h.textIn(scope, label),
      findsNothing,
      reason: 'No Stage 9 result: $label',
    );
  }
}
