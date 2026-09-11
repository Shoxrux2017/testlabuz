import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/presentation/student_attempt_finalization_summary.dart';
import 'package:testlabuz_client/features/student/presentation/student_file_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_read_view.dart';

import 'stage7_e2e_support.dart';

final _topic = stage7Id(401);
final _homework = stage7Id(501);
final _fileQuestion = stage7Id(1006);
final _detailRoute = AppRoutePaths.studentHomeworkDetailLocation(
  _topic,
  _homework,
);
String _attemptRoute(String id) =>
    AppRoutePaths.studentHomeworkAttemptLocation(_topic, _homework, id);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Stage 7 Student Homework uses the real Windows stack',
    (tester) async {
      final harness = await Stage7Harness.create(tester);
      try {
        await harness.launchAndLogin();
        if (harness.readOnly) {
          await _postRestartRead(harness);
        } else {
          await _mainFlow(harness);
        }
      } finally {
        await harness.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}

Future<void> _mainFlow(Stage7Harness h) async {
  final topicCard = h.byKey('studentTopicCard$_topic');
  await h.waitWidget(topicCard, 'Main Topic card');
  expect(h.textIn(topicCard, 'E2E S07 Main Topic'), findsOneWidget);
  await h.tap(h.within(topicCard, find.byType(InkWell)));
  await h.waitRoute(AppRoutePaths.studentTopicDetailLocation(_topic));
  await h.waitWidget(
    h.byKey('studentHomeworkSection'),
    'independent Homework section',
  );
  await h.tap(h.byKey('studentHomeworkOpen$_homework'));
  await h.waitRoute(_detailRoute);
  await _expectHomework(h, used: 0);
  await _expectNineReadSurfaces(h);

  final attemptIds = <String>[];
  final firstAttempt = await _startAttempt(h, 1);
  attemptIds.add(firstAttempt);
  await h.checkpoint('first_start', firstAttempt);
  await _saveNonFileAnswers(h);
  final fileId = await _uploadAndReplace(h, firstAttempt);
  h.sink.expectedFileId = fileId;
  await _download(h);

  final keysBeforeResume = h.keys.consumed;
  await h.tap(h.byKey('studentHomeworkAttemptBackButton'));
  await h.waitRoute(_detailRoute);
  await _expectHomework(h, used: 1, inProgress: true);
  await h.tap(h.byKey('studentHomeworkResumeAttemptButton'));
  await h.waitRoute(_attemptRoute(firstAttempt));
  await _expectRestoredAnswers(h, fileId);
  expect(
    h.keys.consumed,
    keysBeforeResume,
    reason: 'Resume must not generate a Start request.',
  );

  await _submit(h, attemptNumber: 1, answered: 9);
  for (final attemptNumber in [2, 3]) {
    await h.tap(h.byKey('studentHomeworkAttemptBackButton'));
    await h.waitRoute(_detailRoute);
    await _expectHomework(h, used: attemptNumber - 1);
    final id = await _startAttempt(h, attemptNumber);
    expect(attemptIds, isNot(contains(id)));
    attemptIds.add(id);
    await _submit(h, attemptNumber: attemptNumber, answered: 0);
  }
  await h.tap(h.byKey('studentHomeworkAttemptBackButton'));
  await h.waitRoute(_detailRoute);
  await _expectHomework(h, used: 3);
  expect(h.keys.consumed, stage7UiKeys.length);
  expect(h.picker.consumed, Stage7Picker.queue.length);
  expect(h.sink.openCount, 1);
  expect(h.sink.saveCount, 1);
  await h.writeJson(h.evidence, {
    'version': 1,
    'attempt_ids': attemptIds,
    'first_file_id': fileId,
    'replacement_file_id': fileId,
    'idempotency_keys': stage7UiKeys,
    'picker_consumed': h.picker.consumed,
    'open_count': h.sink.openCount,
    'save_count': h.sink.saveCount,
  });
}

Future<void> _expectHomework(
  Stage7Harness h, {
  required int used,
  bool inProgress = false,
}) async {
  final screen = h.byKey('studentHomeworkDetailScreen');
  await h.waitWidget(screen, 'Homework detail screen');
  await h.until(
    () =>
        h.byKey('studentHomeworkDetailTitle').evaluate().length == 1 &&
        h.byKey('studentHomeworkDetailRefreshing').evaluate().isEmpty &&
        _informationValue(h, screen, 'Used') == '$used' &&
        _informationValue(h, screen, 'Remaining') == '${3 - used}',
    'refreshed Homework attempt allowance',
  );
  expect(
    h.tester.widget<Text>(h.byKey('studentHomeworkDetailTitle')).data,
    'E2E S07 Official Homework',
  );
  expect(_informationValue(h, screen, 'Allowed attempts'), '3');
  expect(h.textIn(screen, 'Active'), findsOneWidget);
  expect(
    h.byKey('studentHomeworkResumeAttemptButton'),
    inProgress ? findsOneWidget : findsNothing,
  );
  expect(
    h.byKey('studentHomeworkStartAttemptButton'),
    used < 3 && !inProgress ? findsOneWidget : findsNothing,
  );
  _expectNoChecking(h, screen);
}

String? _informationValue(Stage7Harness h, Finder screen, String label) {
  final labelFinder = h.textIn(screen, label);
  if (labelFinder.evaluate().length != 1) return null;
  String? value;
  labelFinder.evaluate().single.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Column) {
      final index = widget.children.indexWhere(
        (child) => child is Text && child.data == label,
      );
      if (index >= 0) {
        for (final sibling in widget.children.skip(index + 1)) {
          if (sibling is SelectableText) {
            value = sibling.data;
            break;
          }
          if (sibling is Text) break;
        }
        return false;
      }
    }
    return true;
  });
  return value;
}

Future<void> _expectNineReadSurfaces(Stage7Harness h) async {
  const types = [
    StudentQuestionType.singleChoice,
    StudentQuestionType.multipleChoice,
    StudentQuestionType.trueFalse,
    StudentQuestionType.shortWritten,
    StudentQuestionType.openWritten,
    StudentQuestionType.fileBased,
    StudentQuestionType.matching,
    StudentQuestionType.ordering,
    StudentQuestionType.fillInBlank,
  ];
  expect(find.byType(StudentQuestionReadView), findsNWidgets(9));
  for (var position = 1; position <= 9; position++) {
    final id = stage7Id(1000 + position);
    final card = h.byKey('studentQuestion$id');
    await h.waitWidget(card, 'Question $position read surface');
    await h.tester.ensureVisible(card);
    final view = h.tester.widget<StudentQuestionReadView>(
      find.byWidgetPredicate(
        (widget) =>
            widget is StudentQuestionReadView && widget.question.id == id,
      ),
    );
    expect(view.question.position, position);
    expect(view.question.type, types[position - 1]);
    _expectNoChecking(h, card);
    switch (view.question.answerUi) {
      case StudentChoiceAnswerUi(:final options, :final maxSelections):
        expect(options.map((option) => option.text), [
          'E2E S07 Option 1',
          'E2E S07 Option 2',
          'E2E S07 Option 3',
        ]);
        if (position == 2) expect(maxSelections, 2);
        for (final option in options) {
          expect(h.textIn(card, '• ${option.text}'), findsOneWidget);
        }
      case StudentEmptyAnswerUi():
        expect(
          h.textIn(card, switch (position) {
            3 => 'True / False answer',
            4 => 'Short written answer',
            _ => 'Written answer',
          }),
          findsOneWidget,
        );
      case StudentFileAnswerUi(:final allowedExtensions, :final maxSizeBytes):
        expect(allowedExtensions.toSet(), {'pdf', 'docx', 'ppt', 'pptx'});
        expect(maxSizeBytes, 2 * 1024 * 1024);
        expect(h.textIn(card, 'Allowed: PDF, DOCX, PPT, PPTX'), findsOneWidget);
      case StudentMatchingAnswerUi(:final leftItems, :final rightItems):
        expect(leftItems.length, 2);
        expect(rightItems.length, 2);
        expect(h.byKey('studentMatchingLeft$id'), findsOneWidget);
        expect(h.byKey('studentMatchingRight$id'), findsOneWidget);
      case StudentOrderingAnswerUi(:final items):
        expect(items.length, 3);
        for (final item in items) {
          expect(h.textIn(card, '• ${item.text}'), findsOneWidget);
        }
      case StudentFillBlankAnswerUi(:final blanks):
        expect(blanks.length, 2);
        expect(h.textIn(card, 'Blank 1: blank1'), findsOneWidget);
        expect(h.textIn(card, 'Blank 2: blank2'), findsOneWidget);
    }
  }
}

Future<String> _startAttempt(Stage7Harness h, int number) async {
  await h.tap(h.byKey('studentHomeworkStartAttemptButton'));
  await h.until(
    () => AppRoutePaths.isStudentHomeworkAttemptPath(h.route.path),
    'server-confirmed canonical Attempt route',
  );
  final id = AppRoutePaths.studentAttemptIdFromPath(h.route.path)!;
  expect(stage7Uuid.hasMatch(id), isTrue);
  expect(h.route.toString(), _attemptRoute(id));
  final screen = h.byKey('studentHomeworkAttemptScreen');
  await h.waitWidget(h.byKey('studentHomeworkAttemptStatus'), 'Attempt status');
  expect(h.textIn(screen, 'Attempt $number'), findsOneWidget);
  expect(
    h.tester.widget<Text>(h.byKey('studentHomeworkAttemptStatus')).data,
    'In progress',
  );
  await h.waitWidget(
    h.byKey('studentSaveAnswer${stage7Id(1001)}'),
    'first answer editor',
  );
  expect(h.keys.consumed, number * 2 - 1);
  return id;
}

Finder _editorFinder(int question) => find.byWidgetPredicate(
  (widget) =>
      widget is StudentQuestionAnswerEditor &&
      widget.state.question.id == stage7Id(question),
);
StudentQuestionAnswerEditor _editor(Stage7Harness h, int question) =>
    h.tester.widget<StudentQuestionAnswerEditor>(_editorFinder(question));
Finder _card(Stage7Harness h, int question) =>
    h.byKey('studentAnswerEditor${stage7Id(question)}');
Finder _fileEditorFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is StudentFileAnswerEditor &&
      widget.state.question.id == _fileQuestion,
);
StudentFileAnswerEditor _fileEditor(Stage7Harness h) =>
    h.tester.widget<StudentFileAnswerEditor>(_fileEditorFinder());
Finder _fileCard(Stage7Harness h) =>
    h.byKey('studentFileAnswerCard$_fileQuestion');

Future<void> _saveNonFileAnswers(Stage7Harness h) async {
  await h.tap(h.byKey('studentOption${stage7Id(100102)}'));
  await _save(h, 1001);
  for (final option in [100201, 100203]) {
    await h.tap(h.byKey('studentOption${stage7Id(option)}'));
  }
  await _save(h, 1002);
  await h.tap(
    h.within(
      _card(h, 1003),
      find.byWidgetPredicate(
        (widget) => widget is RadioListTile<bool> && widget.value,
      ),
    ),
  );
  await _save(h, 1003);
  await h.enter(
    h.within(_card(h, 1004), find.byType(TextField)),
    stage7ShortAnswer,
  );
  await _save(h, 1004);
  await h.enter(
    h.within(_card(h, 1005), find.byType(TextField)),
    stage7OpenAnswer,
  );
  await _save(h, 1005);
  await h.select<String>(
    h.byKey('studentMatching${stage7Id(100701)}'),
    stage7Id(100712),
  );
  await _save(h, 1007);
  await h.select<int>(h.byKey('studentOrdering${stage7Id(100801)}'), 2);
  await h.select<int>(h.byKey('studentOrdering${stage7Id(100802)}'), 1);
  await _save(h, 1008);
  await h.enter(
    h.within(
      h.byKey('studentBlank${stage7Id(100901)}'),
      find.byType(TextField),
    ),
    stage7BlankAnswer,
  );
  await _save(h, 1009);
  _expectAnswerValues(h);
}

Future<void> _save(Stage7Harness h, int question) async {
  await h.tap(h.byKey('studentSaveAnswer${stage7Id(question)}'));
  await h.until(() {
    if (_editorFinder(question).evaluate().length != 1) return false;
    final state = _editor(h, question).state;
    return state.saveStatus == StudentAnswerSaveStatus.saved &&
        state.serverAnswer != null &&
        state.updatedAt != null &&
        !state.isDirty;
  }, 'Question ${question - 1000} server-confirmed saved answer');
  expect(h.textIn(_card(h, question), 'Saved'), findsOneWidget);
  _expectNoChecking(h, _card(h, question));
}

void _expectAnswerValues(Stage7Harness h) {
  expect(
    (_editor(h, 1001).state.serverAnswer as StudentChoiceAnswerValue)
        .selectedOptionIds,
    [stage7Id(100102)],
  );
  expect(
    (_editor(h, 1002).state.serverAnswer as StudentChoiceAnswerValue)
        .selectedOptionIds
        .toSet(),
    {stage7Id(100201), stage7Id(100203)},
  );
  expect(
    (_editor(h, 1003).state.serverAnswer as StudentBooleanAnswerValue).value,
    true,
  );
  expect(
    (_editor(h, 1004).state.serverAnswer as StudentTextAnswerValue).text,
    stage7ShortAnswer,
  );
  expect(
    (_editor(h, 1005).state.serverAnswer as StudentTextAnswerValue).text,
    stage7OpenAnswer,
  );
  final pairs =
      (_editor(h, 1007).state.serverAnswer as StudentMatchingAnswerValue).pairs;
  expect(pairs.length, 1);
  expect(pairs.single.leftItemId, stage7Id(100701));
  expect(pairs.single.rightItemId, stage7Id(100712));
  final items =
      (_editor(h, 1008).state.serverAnswer as StudentOrderingAnswerValue).items;
  expect(
    {for (final item in items) item.itemId: item.position},
    {stage7Id(100801): 2, stage7Id(100802): 1},
  );
  final blanks =
      (_editor(h, 1009).state.serverAnswer as StudentFillBlankAnswerValue)
          .values;
  expect(blanks.length, 1);
  expect(blanks.single.blankId, stage7Id(100901));
  expect(blanks.single.text, stage7BlankAnswer);
}

Future<String> _uploadAndReplace(Stage7Harness h, String attemptId) async {
  await _chooseAndUpload(h, 'fake_pdf');
  await h.until(
    () =>
        _fileEditorFinder().evaluate().length == 1 &&
        _fileEditor(h).state.status == StudentFileAnswerStatus.failure,
    'backend unsupported-content rejection',
  );
  final failure = _fileEditor(h).state.failure;
  expect(failure?.statusCode, 422);
  expect(failure?.serverCode, 'unsupported_file_type');
  expect(_fileEditor(h).state.serverFile, isNull);
  expect(
    h.textIn(
      _fileCard(h),
      'The selected file content is not a supported PDF, DOCX, PPT, or PPTX file.',
    ),
    findsOneWidget,
  );
  await h.checkpoint('fake_file_rejected', attemptId);

  await _chooseAndUpload(h, 'valid_pdf');
  await _expectUploaded(h, 'valid_pdf');
  final fileId = _fileEditor(h).state.serverFile!.id;
  await h.checkpoint('first_file_uploaded', attemptId, fileId: fileId);

  await _chooseAndUpload(h, 'replacement_pptx', replacement: true);
  await _expectUploaded(h, 'replacement_pptx');
  expect(_fileEditor(h).state.serverFile!.id, fileId);
  await h.checkpoint('file_replaced', attemptId, fileId: fileId);
  return fileId;
}

Finder _fileButton(Stage7Harness h, String label) => h.within(
  _fileCard(h),
  find.ancestor(
    of: h.textIn(_fileCard(h), label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  ),
);

Future<void> _chooseAndUpload(
  Stage7Harness h,
  String fixtureKey, {
  bool replacement = false,
}) async {
  await h.tap(
    _fileButton(h, replacement ? 'Choose replacement' : 'Choose file'),
  );
  await h.until(
    () =>
        _fileEditorFinder().evaluate().length == 1 &&
        _fileEditor(h).state.status == StudentFileAnswerStatus.ready,
    'native picker selection accepted',
  );
  expect(_fileEditor(h).state.selectedFile?.name, h.fixtures[fixtureKey].name);
  expect(_fileEditor(h).state.selectionError, isNull);
  await h.tap(
    _fileButton(h, replacement ? 'Upload replacement' : 'Upload answer'),
  );
  try {
    await h.until(
      () => _fileEditor(h).state.status == StudentFileAnswerStatus.uploading,
      'production upload progress',
    );
    expect(h.textIn(_fileCard(h), 'Uploading file…'), findsOneWidget);
    expect(
      h.within(_fileCard(h), find.byType(LinearProgressIndicator)),
      findsOneWidget,
    );
  } finally {
    h.picker.releaseRead();
  }
}

Future<void> _expectUploaded(Stage7Harness h, String fixtureKey) async {
  final expected = h.fixtures[fixtureKey];
  await h.until(() {
    if (_fileEditorFinder().evaluate().length != 1) return false;
    final state = _fileEditor(h).state;
    return state.serverFile?.originalName == expected.name &&
        state.selectedFile == null &&
        state.failure == null &&
        state.status != StudentFileAnswerStatus.uploading &&
        !_fileEditor(h).isReconciling;
  }, 'server-confirmed $fixtureKey upload');
  final saved = _fileEditor(h).state.serverFile!;
  expect(saved.extension, expected.extension);
  expect(saved.sizeBytes, expected.size);
  expect(h.textIn(_fileCard(h), expected.name), findsOneWidget);
  expect(h.textIn(_fileCard(h), expected.sha256), findsNothing);
  _expectNoChecking(h, _fileCard(h));
}

Future<void> _download(Stage7Harness h) async {
  final previousOpens = h.sink.openCount;
  await h.tap(_fileButton(h, 'Open'));
  await h.until(
    () => h.sink.openCount == previousOpens + 1,
    'protected Open exact-byte sink',
  );
  final previousSaves = h.sink.saveCount;
  await h.tap(_fileButton(h, 'Save As…'));
  await h.until(
    () => h.sink.saveCount == previousSaves + 1,
    'protected Save As exact-byte sink',
  );
}

Future<void> _expectRestoredAnswers(Stage7Harness h, String fileId) async {
  await h.until(
    () =>
        _editorFinder(1001).evaluate().length == 1 &&
        _editor(h, 1001).state.serverAnswer != null &&
        _fileEditorFinder().evaluate().length == 1 &&
        _fileEditor(h).state.serverFile != null,
    'persisted Attempt answers after Resume',
  );
  _expectAnswerValues(h);
  for (final question in [1001, 1002, 1003, 1004, 1005, 1007, 1008, 1009]) {
    expect(_editor(h, question).state.isDirty, false);
    expect(_editor(h, question).state.updatedAt, isNotNull);
    expect(_editor(h, question).canSave, false);
  }
  expect(_fileEditor(h).state.serverFile!.id, fileId);
  expect(_fileEditor(h).state.selectedFile, isNull);
  await _expectUploaded(h, 'replacement_pptx');
}

Future<void> _submit(
  Stage7Harness h, {
  required int attemptNumber,
  required int answered,
}) async {
  await h.tap(h.byKey('studentHomeworkSubmitAttemptButton'));
  final dialog = h.byKey('studentHomeworkSubmitConfirmDialog');
  await h.waitWidget(dialog, 'Submit confirmation dialog');
  expect(h.textIn(dialog, 'Submit Attempt $attemptNumber?'), findsOneWidget);
  expect(h.textIn(dialog, '$answered of 9 answers are saved.'), findsOneWidget);
  expect(
    h.textIn(dialog, '9 Questions have no saved answer.'),
    answered == 0 ? findsOneWidget : findsNothing,
  );
  expect(
    h.textIn(
      dialog,
      'Submitting will lock this Attempt and it cannot be edited afterward.\nUnanswered Questions are allowed.',
    ),
    findsOneWidget,
  );
  await h.tap(h.within(dialog, h.byKey('studentHomeworkSubmitConfirmButton')));
  await h.until(
    () =>
        dialog.evaluate().isEmpty &&
        h.byKey('studentAttemptFinalizationSummary').evaluate().length == 1,
    'terminal explicit Submit',
  );
  await _expectTerminal(h, attemptNumber);
}

Future<void> _expectTerminal(Stage7Harness h, int number) async {
  final summary = h.byKey('studentAttemptFinalizationSummary');
  await h.waitWidget(summary, 'terminal finalization summary');
  await h.until(
    () =>
        _fileEditorFinder().evaluate().length == 1 && _fileEditor(h).isTerminal,
    'terminal file answer state',
  );
  final model = h.tester
      .widget<StudentAttemptFinalizationSummary>(
        find.byType(StudentAttemptFinalizationSummary),
      )
      .attempt;
  expect(model.attemptNumber, number);
  expect(model.status, StudentHomeworkAttemptStatus.submitted);
  expect(
    model.finalizationReason,
    StudentHomeworkAttemptFinalizationReason.studentSubmit,
  );
  expect(model.submittedAt, isNotNull);
  expect(model.finalizedAt, model.submittedAt);
  expect(h.textIn(summary, 'Submitted by you'), findsOneWidget);
  expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
  expect(h.byKey('studentHomeworkSubmitAttemptButton'), findsNothing);
  expect(_fileEditor(h).isTerminal, true);
  expect(_fileEditor(h).canChoose, false);
  expect(_fileEditor(h).canUpload, false);
  expect(_fileButton(h, 'Upload answer'), findsNothing);
  expect(_fileButton(h, 'Upload replacement'), findsNothing);
  expect(_fileButton(h, 'Choose file'), findsNothing);
  expect(_fileButton(h, 'Choose replacement'), findsNothing);
  _expectNoChecking(h, h.byKey('studentHomeworkAttemptScreen'));
}

void _expectNoChecking(Stage7Harness h, Finder scope) {
  // Static possible-points and official-policy copy is permitted; earned results are not.
  const forbidden = [
    'Correct answer',
    'Incorrect answer',
    'Checked',
    'Checking status',
    'Awarded points',
    'Earned points',
    'Normalized score',
    'Your score',
    'Teacher feedback',
  ];
  for (final label in forbidden) {
    expect(
      h.textIn(scope, label),
      findsNothing,
      reason: 'Stage 7 must not expose checking or released scores.',
    );
  }
  for (final key in [
    'is_correct',
    'correct_value',
    'accepted_answers',
    'correct_position',
    'match_key',
    'checking_mode',
    'configuration',
    'client_key',
    'storage_key',
    'storage_path',
    'checksum',
  ]) {
    expect(h.textIn(scope, key), findsNothing);
  }
}

Future<void> _postRestartRead(Stage7Harness h) async {
  final saved = stage7Map(jsonDecode(await h.evidence.readAsString()));
  final ids = (saved['attempt_ids'] as List).cast<String>();
  final fileId = saved['replacement_file_id'] as String;
  if (saved['version'] != 1 ||
      ids.length != 3 ||
      !ids.every(stage7Uuid.hasMatch) ||
      !stage7Uuid.hasMatch(fileId)) {
    throw StateError('Invalid Stage 7 persisted UI evidence.');
  }
  await h.go(_detailRoute);
  await _expectHomework(h, used: 3);
  await h.go(_attemptRoute(ids.first));
  await _expectTerminal(h, 1);
  await _expectUploaded(h, 'replacement_pptx');
  expect(_fileEditor(h).state.serverFile!.id, fileId);
  h.sink.expectedFileId = fileId;
  await _download(h);
  expect(h.keys.consumed, 0);
  expect(h.picker.consumed, 0);
}
