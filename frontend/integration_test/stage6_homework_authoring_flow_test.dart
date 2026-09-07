import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/config/app_config.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _password = String.fromEnvironment('STAGE6_E2E_PASSWORD');
const _oraclePath = String.fromEnvironment('STAGE6_E2E_ORACLE_PATH');
const _authTokenKey = 'auth_access_token';

const _mainTitle = 'E2E S06 Official Homework';
const _practiceTitle = 'E2E S06 Selected Practice Homework';
const _temporaryPrompt = 'E2E S06 Temporary Question';
const _updatedSinglePrompt = 'What is the primary purpose of DNS?';
const _fillPrompt = 'DNS converts {{host}} into an {{address}}.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Stage 6 Homework authoring uses the real Windows stack',
    (tester) async {
      final harness = await _Stage6Harness.create(tester);
      try {
        await harness.launch();
        await harness.login();
        await _runAuthoringFlow(harness);
      } finally {
        await harness.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 35)),
  );

  testWidgets(
    'Stage 6 Homework state persists after backend restart',
    (tester) async {
      final harness = await _Stage6Harness.create(tester);
      try {
        await harness.launch();
        await harness.login();
        await _runPersistenceFlow(harness);
      } finally {
        await harness.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

class _Stage6Oracle {
  _Stage6Oracle(this.raw);

  final Map<String, Object?> raw;

  static Future<_Stage6Oracle> load(String path) async {
    final file = File(path);
    final basename = file.uri.pathSegments.last;
    if (!_isSystemTempDirectory(file.parent) ||
        !RegExp(
          r'^testlabuz-stage6-oracle-[a-f0-9]{32}\.json$',
        ).hasMatch(basename)) {
      throw StateError('The Stage 6 oracle path is unsafe.');
    }
    final raw = _map(jsonDecode(await file.readAsString()));
    _exactKeys(raw, {
      'version',
      'institution',
      'actors',
      'groups',
      'topics',
      'homework',
      'expected',
    });
    if (raw['version'] != 1) {
      throw const FormatException('Unsupported Stage 6 oracle version.');
    }
    return _Stage6Oracle(raw);
  }

  String actorLogin(String key) =>
      _string(_map(_map(raw['actors'])[key]), 'login');
  String actorId(String key) => _string(_map(_map(raw['actors'])[key]), 'id');
  String topicId(String key) => _string(_map(_map(raw['topics'])[key]), 'id');
  String homeworkId(String key) =>
      _string(_map(_map(raw['homework'])[key]), 'id');
}

bool _isSystemTempDirectory(Directory directory) {
  try {
    return FileSystemEntity.identicalSync(
      directory.path,
      Directory.systemTemp.path,
    );
  } on FileSystemException {
    return false;
  }
}

class _Stage6Harness {
  _Stage6Harness._(this.tester, this.oracle);

  final WidgetTester tester;
  final _Stage6Oracle oracle;
  bool _loggedIn = false;

  static Future<_Stage6Harness> create(WidgetTester tester) async {
    if (_apiBaseUrl.isEmpty ||
        !RegExp(r'^S06-Aa9![A-Za-z0-9]{40,}$').hasMatch(_password) ||
        _oraclePath.isEmpty ||
        !Platform.isWindows) {
      throw StateError('Stage 6 real-stack defines are required.');
    }
    final target = Uri.parse(_apiBaseUrl);
    if (target.scheme != 'http' ||
        target.host != '127.0.0.1' ||
        !target.hasPort ||
        target.path != '/api/v1' ||
        target.hasQuery ||
        target.hasFragment ||
        target.userInfo.isNotEmpty) {
      throw StateError('Stage 6 requires the exact loopback API boundary.');
    }
    if (target.port < 1 || target.port > 65535) {
      throw StateError('Stage 6 requires an explicit valid API port.');
    }
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return _Stage6Harness._(tester, await _Stage6Oracle.load(_oraclePath));
  }

  Future<void> launch() async {
    await const FlutterSecureStorage().delete(key: _authTokenKey);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromApiBaseUrl(_apiBaseUrl),
          ),
        ],
        child: const TestLabUzApp(),
      ),
    );
    await waitForRoute(AppRoutePaths.login);
    await waitForKey('loginField');
  }

  Future<void> login() async {
    await enterKey('loginField', oracle.actorLogin('target_teacher'));
    await enterKey('passwordField', _password);
    await tapKey('signInButton');
    await waitForRoute(AppRoutePaths.teacher);
    await waitForKey('teacherLearningWorkspace');
    _loggedIn = true;
  }

  Future<void> close() async {
    Object? logoutFailure;
    if (_loggedIn) {
      try {
        await go(AppRoutePaths.teacher);
        await waitForKey('entryLogoutButton');
        await tapKey('entryLogoutButton');
        await waitForRoute(AppRoutePaths.login);
      } catch (error) {
        logoutFailure = error;
      }
    }
    await const FlutterSecureStorage().delete(key: _authTokenKey);
    if (logoutFailure != null) throw logoutFailure;
  }

  Future<void> go(String route) async {
    GoRouter.of(_routerContext()).go(route);
    await tester.pump();
    await waitForRoute(route);
  }

  Future<void> enterKey(String key, String value) =>
      enter(find.byKey(Key(key)), value);

  Future<void> enterLabel(String label, String value) {
    final finder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    return enter(finder, value);
  }

  Future<void> enter(Finder finder, String value) async {
    await waitFor(finder);
    await tester.ensureVisible(finder.last);
    await tester.tap(finder.last);
    await tester.enterText(finder.last, value);
    await tester.pump();
  }

  Future<void> tapKey(String key) => tap(find.byKey(Key(key)));

  Future<void> tapText(String text) => tap(find.text(text));

  Future<void> tap(Finder finder) async {
    await waitFor(finder);
    await tester.ensureVisible(finder.last);
    await tester.tap(finder.last);
    await tester.pump();
  }

  Future<void> waitForKey(
    String key, {
    Duration timeout = const Duration(seconds: 30),
  }) => waitFor(find.byKey(Key(key)), timeout: timeout);

  Future<void> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) => pumpUntil(
    () => finder.evaluate().isNotEmpty,
    reason: 'Expected a required Stage 6 widget.',
    timeout: timeout,
  );

  Future<void> waitGone(
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) => pumpUntil(
    () => finder.evaluate().isEmpty,
    reason: 'Expected a transient Stage 6 widget to disappear.',
    timeout: timeout,
  );

  Future<void> settleUiTransition() async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  Future<void> waitForRoute(String route) => pumpUntil(
    () => _currentRoute() == route,
    reason: 'Expected route $route.',
  );

  Future<void> pumpUntil(
    bool Function() condition, {
    required String reason,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) throw TestFailure(reason);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 150));
  }

  String _currentRoute() =>
      GoRouter.of(_routerContext()).routeInformationProvider.value.uri.path;

  BuildContext _routerContext() {
    final scaffold = find.byType(Scaffold);
    if (scaffold.evaluate().isEmpty) {
      throw StateError('Stage 6 could not find the application router.');
    }
    return tester.element(scaffold.last);
  }
}

Future<void> _runAuthoringFlow(_Stage6Harness h) async {
  final topicId = h.oracle.topicId('authoring');
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.waitForKey('teacherTopicDetailScreen');
  await h.waitFor(find.text('E2E S06 Authoring Topic'));
  await h.waitForKey('teacherHomeworkSection');
  await h.waitForKey('teacherHomeworkEmpty');
  expect(find.byKey(const Key('teacherHomeworkEmpty')), findsOneWidget);

  await h.tapKey('teacherHomeworkCreateButton');
  await h.waitForKey('teacherHomeworkCreateScreen');
  await h.enterKey('teacherHomeworkTitleField', _mainTitle);
  await h.enterKey(
    'teacherHomeworkDescriptionField',
    'E2E S06 official draft description',
  );
  await h.enterKey(
    'teacherHomeworkInstructionsField',
    'Complete every question carefully.',
  );
  expect(find.text('Whole group'), findsWidgets);
  await _chooseDeadline(h);
  expect(find.textContaining('2035-06-15 18:00'), findsOneWidget);
  await h.tapKey('teacherHomeworkCreateSubmitButton');
  await h.waitForKey('teacherHomeworkDetailScreen');
  await h.waitFor(find.text(_mainTitle));
  final mainId = _homeworkIdFromCurrentRoute(h);
  expect(find.text('Draft'), findsWidgets);
  expect(find.text('Normal attempts'), findsOneWidget);
  expect(find.text('3'), findsWidgets);
  expect(find.text('Question count'), findsOneWidget);
  expect(find.text('0'), findsWidgets);
  expect(find.text('2035-06-15 18:00'), findsOneWidget);
  expect(find.text('Asia/Tashkent'), findsWidgets);

  await h.tapKey('teacherHomeworkManageQuestionsButton');
  await h.waitForKey('teacherQuestionBuilderScreen');
  await _verifyNineTypeSelector(h);
  await _addQuestion(
    h,
    type: 'Single choice',
    prompt: 'What does DNS primarily do?',
    points: '1',
    configure: () async {
      await h.enterLabel('Option 1', 'Resolves domain names');
      await h.enterLabel('Option 2', 'Compresses files');
      await h.tapKey('teacherQuestionAddChoiceOptionButton');
      await h.enterLabel('Option 3', 'Encrypts all traffic');
    },
  );
  await _addQuestion(
    h,
    type: 'Multiple choice',
    prompt: 'Select valid network protocols.',
    points: '2',
    configure: () async {
      await h.enterLabel('Option 1', 'HTTP');
      await h.enterLabel('Option 2', 'DNS');
      await h.tap(find.byType(Checkbox).at(1));
      await h.tapKey('teacherQuestionAddChoiceOptionButton');
      await h.tapKey('teacherQuestionAddChoiceOptionButton');
      await h.enterLabel('Option 3', 'PNG');
      await h.enterLabel('Option 4', 'JPEG');
    },
  );
  await _addQuestion(
    h,
    type: 'True/False',
    prompt: 'An IP address can identify a network endpoint.',
    points: '1',
  );
  await _addQuestion(
    h,
    type: 'Short written',
    prompt: 'Write the abbreviation for Domain Name System.',
    points: '1',
    configure: () => h.enterLabel('Answer 1', 'DNS'),
  );
  await _addQuestion(
    h,
    type: 'Short written',
    prompt: 'Describe DNS in one sentence.',
    points: '2',
    manual: true,
  );
  await _addQuestion(
    h,
    type: 'Open written',
    prompt: 'Explain the steps of a DNS lookup.',
    points: '3',
  );
  await _addQuestion(
    h,
    type: 'File based',
    prompt: 'Upload the completed network presentation.',
    points: '4',
    configure: () async {
      final fileConfig = find.byKey(
        const Key('teacherQuestionFileBasedConfiguration'),
      );
      expect(fileConfig, findsOneWidget);
      for (final text in const [
        'PDF',
        'DOCX',
        'PPT',
        'PPTX',
        'Manual review',
      ]) {
        expect(
          find.descendant(of: fileConfig, matching: find.text(text)),
          findsOneWidget,
        );
      }
    },
  );
  await _addQuestion(
    h,
    type: 'Matching',
    prompt: 'Match each term to its meaning.',
    points: '2',
    configure: () async {
      await h.enterLabel('Pair 1 left', 'DNS');
      await h.enterLabel('Pair 1 right', 'Domain name resolution');
      await h.tapKey('teacherQuestionMatchingAddButton');
      await h.enterLabel('Pair 2 left', 'IP');
      await h.enterLabel('Pair 2 right', 'Network address');
    },
  );
  await _addQuestion(
    h,
    type: 'Ordering',
    prompt: 'Put the simplified lookup steps in order.',
    points: '2',
    configure: () async {
      await h.enterLabel('Item 1', 'Enter domain');
      await h.enterLabel('Item 2', 'Resolve address');
      await h.tapKey('teacherQuestionOrderingItemAddButton');
      await h.enterLabel('Item 3', 'Contact server');
    },
  );
  await _addQuestion(
    h,
    type: 'Fill in the blank',
    prompt: _fillPrompt,
    points: '2',
    configure: () async {
      await h.enterLabel('Blank 1 key', 'host');
      await h.enterLabel('Blank 1 answer 1', 'domain name');
      await h.tapKey('teacherQuestionFillBlankAddButton');
      await h.enterLabel('Blank 2 key', 'address');
      await h.enterLabel('Blank 2 answer 1', 'IP address');
    },
  );
  expect(find.text('Questions: 10'), findsOneWidget);
  expect(find.text('Total points: 20'), findsOneWidget);

  final singleId = _questionIdForPrompt(h, 'What does DNS primarily do?');
  await h.tap(find.byKey(ValueKey('teacherQuestionEdit$singleId')));
  await h.waitForKey('teacherQuestionEditorDialog');
  await h.enterKey('teacherQuestionPromptField', _updatedSinglePrompt);
  await h.enterKey('teacherQuestionPointsField', '1.5');
  await h.tapKey('teacherQuestionEditorSubmitButton');
  await h.waitGone(find.byKey(const Key('teacherQuestionEditorDialog')));
  expect(find.text('Total points: 20.5'), findsOneWidget);

  await _addQuestion(
    h,
    type: 'True/False',
    prompt: _temporaryPrompt,
    points: '0.5',
    configure: () => h.tapText('False'),
  );
  expect(find.text('Questions: 11'), findsOneWidget);
  expect(find.text('Total points: 21'), findsOneWidget);
  final temporaryId = _questionIdForPrompt(h, _temporaryPrompt);
  await h.tap(find.byKey(ValueKey('teacherQuestionDelete$temporaryId')));
  await h.waitForKey('teacherQuestionDeleteConfirmButton');
  await h.tapKey('teacherQuestionDeleteConfirmButton');
  await h.waitGone(find.text(_temporaryPrompt));
  expect(find.text('Questions: 10'), findsOneWidget);
  expect(find.text('Total points: 20.5'), findsOneWidget);

  final fillId = _questionIdForPrompt(h, _fillPrompt);
  for (var index = 0; index < 9; index += 1) {
    await h.tap(find.byKey(ValueKey('teacherQuestionMoveUp$fillId')));
  }
  await h.tapKey('teacherQuestionBuilderSaveOrderButton');
  await h.pumpUntil(
    () => _questionCardPosition(h, fillId) == 1,
    reason: 'Fill in Blank did not persist at position 1.',
  );
  expect(find.text('Total points: 20.5'), findsOneWidget);

  await h.go(AppRoutePaths.teacherHomeworkDetailLocation(topicId, mainId));
  await h.waitForKey('teacherHomeworkDetailScreen');
  await h.waitFor(find.text(_mainTitle));
  await h.tapKey('teacherOfficialHomeworkActionButton');
  await h.waitForKey('teacherOfficialHomeworkConfirmButton');
  await h.tapKey('teacherOfficialHomeworkConfirmButton');
  await h.waitForKey('teacherOfficialHomeworkBadge');
  expect(find.textContaining('cohort will be fixed'), findsOneWidget);

  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.tapKey('teacherHomeworkCreateButton');
  await h.waitForKey('teacherHomeworkCreateScreen');
  await h.enterKey('teacherHomeworkTitleField', _practiceTitle);
  await h.enterKey('teacherHomeworkDescriptionField', 'Practice assignment');
  await h.enterKey(
    'teacherHomeworkInstructionsField',
    'Complete this practice Homework.',
  );
  await h.tapText('Selected students');
  await h.tapKey('teacherHomeworkChooseStudentsButton');
  await h.waitForKey('teacherHomeworkStudentPickerDialog');
  await h.enterKey(
    'teacherHomeworkStudentPickerSearchField',
    'E2E S06 Student',
  );
  await h.tapKey('teacherHomeworkStudentPickerSearchButton');
  await h.waitFor(
    find.byKey(
      ValueKey(
        'teacherHomeworkPickerStudent${h.oracle.actorId('student_alpha')}',
      ),
    ),
  );
  for (final excluded in const [
    'E2E S06 Student Ended',
    'E2E S06 Student Inactive',
    'E2E S06 Unrelated Student',
    'E2E S06 Foreign Student',
  ]) {
    expect(find.text(excluded), findsNothing);
  }
  expect(find.text(h.oracle.actorId('student_alpha')), findsNothing);
  expect(find.text(h.oracle.actorId('student_beta')), findsNothing);
  await h.tap(
    find.byKey(
      ValueKey(
        'teacherHomeworkPickerStudent${h.oracle.actorId('student_alpha')}',
      ),
    ),
  );
  await h.tap(
    find.byKey(
      ValueKey(
        'teacherHomeworkPickerStudent${h.oracle.actorId('student_beta')}',
      ),
    ),
  );
  await h.tapKey('teacherHomeworkStudentPickerApplyButton');
  await h.waitGone(find.byKey(const Key('teacherHomeworkStudentPickerDialog')));
  await h.settleUiTransition();
  final createSelectedStudentCount = find.byKey(
    const Key('teacherHomeworkSelectedStudentCount'),
  );
  expect(createSelectedStudentCount, findsOneWidget);
  expect(
    h.tester.widget<Text>(createSelectedStudentCount).data,
    '2 Students selected',
  );
  await h.waitFor(
    find.byKey(const Key('teacherHomeworkCreateSubmitButton')).hitTestable(),
  );
  await h.tapKey('teacherHomeworkCreateSubmitButton');
  await h.waitForKey('teacherHomeworkDetailScreen');
  await h.waitFor(find.text(_practiceTitle));
  final practiceId = _homeworkIdFromCurrentRoute(h);
  expect(find.text('Draft'), findsWidgets);
  expect(find.text('Selected students: 2'), findsOneWidget);
  expect(find.text('Normal attempts'), findsOneWidget);
  expect(find.text('3'), findsWidgets);
  expect(
    find.byKey(const Key('teacherOfficialHomeworkActionButton')),
    findsNothing,
  );

  await h.tapKey('teacherHomeworkEditButton');
  await h.waitForKey('teacherHomeworkEditScreen');
  await h.tapKey('teacherHomeworkChooseStudentsButton');
  await h.waitForKey('teacherHomeworkStudentPickerDialog');
  await h.tap(
    find.byKey(const ValueKey('teacherHomeworkStudentPickerRemoveSelected1')),
  );
  await h.tapKey('teacherHomeworkStudentPickerApplyButton');
  await h.waitGone(find.byKey(const Key('teacherHomeworkStudentPickerDialog')));
  await h.settleUiTransition();
  final editSelectedStudentCount = find.byKey(
    const Key('teacherHomeworkSelectedStudentCount'),
  );
  expect(editSelectedStudentCount, findsOneWidget);
  expect(
    h.tester.widget<Text>(editSelectedStudentCount).data,
    '1 Student selected',
  );
  await h.waitFor(
    find.byKey(const Key('teacherHomeworkEditSubmitButton')).hitTestable(),
  );
  await h.tapKey('teacherHomeworkEditSubmitButton');
  await h.waitForKey('teacherHomeworkDetailScreen');
  await h.waitFor(find.text(_practiceTitle));
  expect(find.text('Selected students: 1'), findsOneWidget);
  await _homeworkLifecycle(h, 'archive', 'Archived');

  await h.go(AppRoutePaths.teacherHomeworkDetailLocation(topicId, mainId));
  await h.waitFor(find.text(_mainTitle));
  await _homeworkLifecycle(h, 'activate', 'Active');
  expect(find.textContaining('Official cohort prepared'), findsOneWidget);

  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.tap(find.byKey(const ValueKey('teacherTopicLifecycleclose')));
  await h.tapKey('teacherTopicLifecycleConfirmButton');
  await h.waitFor(
    find.text(
      "Close or archive the Topic's draft/active Homework before closing or archiving the Topic.",
    ),
  );
  expect(
    find.text(
      "Close or archive the Topic's draft/active Homework before closing or archiving the Topic.",
    ),
    findsOneWidget,
  );
  expect(
    find.byKey(const Key('teacherTopicLifecycleCheckCurrentButton')),
    findsNothing,
  );
  expect(find.text('Topic: Active'), findsOneWidget);

  await h.go(AppRoutePaths.teacherHomeworkDetailLocation(topicId, mainId));
  await _homeworkLifecycle(h, 'close', 'Closed');
  await _homeworkLifecycle(h, 'archive', 'Archived');
  expect(find.byKey(const Key('teacherOfficialHomeworkBadge')), findsOneWidget);

  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.tap(find.byKey(const ValueKey('teacherTopicLifecycleclose')));
  await h.tapKey('teacherTopicLifecycleConfirmButton');
  await h.pumpUntil(
    () => find.text('Topic: Closed').evaluate().isNotEmpty,
    reason: 'Authoring Topic did not close.',
  );

  final lockedTopic = h.oracle.topicId('locked');
  final lockedHomework = h.oracle.homeworkId('locked');
  await h.go(
    AppRoutePaths.teacherHomeworkDetailLocation(lockedTopic, lockedHomework),
  );
  await h.waitForKey('teacherHomeworkDetailScreen');
  await h.waitFor(find.text('E2E S06 Locked Official Homework'));
  expect(find.text('Active'), findsWidgets);
  expect(find.byKey(const Key('teacherOfficialHomeworkBadge')), findsOneWidget);
  expect(find.textContaining('selection locked'), findsWidgets);
  expect(
    find.byKey(const Key('teacherOfficialHomeworkActionButton')),
    findsNothing,
  );
  await h.tapKey('teacherHomeworkManageQuestionsButton');
  await h.waitForKey('teacherQuestionBuilderScreen');
  await h.tapKey('teacherQuestionBuilderAddButton');
  await h.waitForKey('teacherQuestionEditorDialog');
  await h.enterKey(
    'teacherQuestionPromptField',
    'E2E S06 Locked UI Mutation Rejected',
  );
  await h.enterKey('teacherQuestionPointsField', '1');
  await h.enterLabel('Option 1', 'Yes');
  await h.enterLabel('Option 2', 'No');
  await h.tapKey('teacherQuestionEditorSubmitButton');
  await h.waitFor(find.textContaining('Question editing is locked'));
  expect(
    find.byKey(const Key('teacherQuestionEditorSubmitButton')),
    findsNothing,
  );
  await h.tapKey('teacherQuestionEditorCancelButton');
  await h.waitFor(find.text('Discard Question changes?'));
  expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsOneWidget);
  expect(
    find.byKey(const Key('teacherQuestionDiscardChangesButton')),
    findsOneWidget,
  );
  await h.tapKey('teacherQuestionDiscardChangesButton');
  await h.waitGone(find.text('Discard Question changes?'));
  await h.settleUiTransition();
  await h.waitGone(find.byKey(const Key('teacherQuestionEditorDialog')));
  await h.waitForKey('teacherQuestionBuilderLockedBanner');
  expect(find.textContaining('locked'), findsWidgets);
  expect(
    find.byKey(const Key('teacherQuestionBuilderAddButton')),
    findsNothing,
  );
  expect(practiceId, isNot(mainId));
}

Future<void> _runPersistenceFlow(_Stage6Harness h) async {
  final authoringTopic = h.oracle.topicId('authoring');
  await h.go(AppRoutePaths.teacherTopicDetailLocation(authoringTopic));
  await h.waitForKey('teacherTopicDetailScreen');
  await h.waitFor(find.text('E2E S06 Authoring Topic'));
  expect(find.text('Topic: Closed'), findsOneWidget);
  await h.waitForKey('teacherHomeworkSection');
  await h.enterKey('teacherHomeworkSearchField', _mainTitle);
  await h.tapKey('teacherHomeworkSearchButton');
  await h.waitFor(find.text(_mainTitle));
  final mainId = _homeworkIdForTitle(h, _mainTitle);
  await h.tap(find.byKey(ValueKey('teacherHomeworkCard$mainId')));
  await h.waitForKey('teacherHomeworkDetailScreen');
  await h.waitFor(find.text(_mainTitle));
  expect(find.text('Archived'), findsWidgets);
  expect(find.byKey(const Key('teacherOfficialHomeworkBadge')), findsOneWidget);
  expect(find.textContaining('20.5'), findsWidgets);
  expect(find.textContaining('10'), findsWidgets);
  await h.tapKey('teacherHomeworkManageQuestionsButton');
  await h.waitForKey('teacherQuestionBuilderScreen');
  expect(find.text('Questions: 10'), findsOneWidget);
  expect(find.text('Total points: 20.5'), findsOneWidget);
  final fillId = _questionIdForPrompt(h, _fillPrompt);
  expect(_questionCardPosition(h, fillId), 1);

  await h.go(AppRoutePaths.teacherTopicDetailLocation(authoringTopic));
  await h.enterKey('teacherHomeworkSearchField', _practiceTitle);
  await h.tapKey('teacherHomeworkSearchButton');
  await h.waitFor(find.text(_practiceTitle));
  expect(find.text('Archived'), findsWidgets);

  final lockedTopic = h.oracle.topicId('locked');
  final lockedHomework = h.oracle.homeworkId('locked');
  await h.go(
    AppRoutePaths.teacherHomeworkDetailLocation(lockedTopic, lockedHomework),
  );
  await h.waitForKey('teacherHomeworkDetailScreen');
  await h.waitFor(find.text('E2E S06 Locked Official Homework'));
  expect(find.text('Active'), findsWidgets);
  expect(find.byKey(const Key('teacherOfficialHomeworkBadge')), findsOneWidget);
  expect(find.textContaining('selection locked'), findsWidgets);
}

Future<void> _chooseDeadline(_Stage6Harness h) async {
  await h.tapKey('teacherHomeworkChooseDeadlineButton');
  await h.waitFor(find.byType(DatePickerDialog));
  final switchDate = find.byTooltip('Switch to input');
  if (switchDate.evaluate().isNotEmpty) await h.tap(switchDate);
  final dateField = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byType(TextField),
  );
  await h.enter(dateField, '06/15/2035');
  await h.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('OK'),
    ),
  );
  await h.waitFor(find.byType(TimePickerDialog));
  final switchTime = find.byTooltip('Switch to text input mode');
  if (switchTime.evaluate().isNotEmpty) await h.tap(switchTime);
  final timeFields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  final uses24Hour = MediaQuery.alwaysUse24HourFormatOf(
    h.tester.element(find.byType(TimePickerDialog)),
  );
  await h.enter(timeFields.at(0), uses24Hour ? '18' : '06');
  await h.enter(timeFields.at(1), '00');
  if (!uses24Hour) await h.tapText('PM');
  await h.tap(
    find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.text('OK'),
    ),
  );
}

Future<void> _verifyNineTypeSelector(_Stage6Harness h) async {
  await h.tapKey('teacherQuestionBuilderAddButton');
  await h.waitForKey('teacherQuestionEditorDialog');
  final dropdown = h.tester.widget<DropdownButton<TeacherQuestionType>>(
    _questionTypeDropdown(),
  );
  expect(dropdown.items, hasLength(9));
  expect(
    dropdown.items!.map((item) => item.value).toSet(),
    TeacherQuestionType.values.toSet(),
  );
  await h.tap(_questionTypeDropdown());
  for (final type in const [
    'Single choice',
    'Multiple choice',
    'True/False',
    'Short written',
    'Open written',
    'File based',
    'Matching',
    'Ordering',
    'Fill in the blank',
  ]) {
    expect(find.text(type), findsWidgets);
  }
  await h.tapText('Single choice');
  await h.tapKey('teacherQuestionEditorCancelButton');
  await h.waitGone(find.byKey(const Key('teacherQuestionEditorDialog')));
}

Future<void> _addQuestion(
  _Stage6Harness h, {
  required String type,
  required String prompt,
  required String points,
  bool manual = false,
  Future<void> Function()? configure,
}) async {
  await h.tapKey('teacherQuestionBuilderAddButton');
  await h.waitForKey('teacherQuestionEditorDialog');
  if (type != 'Single choice') {
    await h.tap(_questionTypeDropdown());
    await h.tapText(type);
    if (find
        .byKey(const Key('teacherQuestionConfirmTypeButton'))
        .evaluate()
        .isNotEmpty) {
      await h.tapKey('teacherQuestionConfirmTypeButton');
    }
  }
  await h.enterKey('teacherQuestionPromptField', prompt);
  await h.enterKey('teacherQuestionPointsField', points);
  if (manual) {
    await h.tapText('Manual');
    if (find
        .byKey(const Key('teacherQuestionConfirmCheckingModeButton'))
        .evaluate()
        .isNotEmpty) {
      await h.tapKey('teacherQuestionConfirmCheckingModeButton');
    }
  }
  if (configure != null) await configure();
  await h.tapKey('teacherQuestionEditorSubmitButton');
  await h.waitGone(find.byKey(const Key('teacherQuestionEditorDialog')));
  await h.waitFor(find.text(prompt));
}

Finder _questionTypeDropdown() => find.descendant(
  of: find.byKey(const Key('teacherQuestionTypeField')),
  matching: find.byType(DropdownButton<TeacherQuestionType>),
);

Future<void> _homeworkLifecycle(
  _Stage6Harness h,
  String action,
  String expectedStatus,
) async {
  await h.tap(find.byKey(ValueKey('teacherHomeworkLifecycle${action}Button')));
  await h.waitForKey('teacherHomeworkLifecycleConfirmButton');
  await h.tapKey('teacherHomeworkLifecycleConfirmButton');
  await h.waitGone(
    find.byKey(const Key('teacherHomeworkLifecycleConfirmDialog')),
  );
  await h.pumpUntil(
    () => find.text(expectedStatus).evaluate().isNotEmpty,
    reason: 'Homework lifecycle $action did not reach $expectedStatus.',
  );
}

String _homeworkIdFromCurrentRoute(_Stage6Harness h) {
  final location = h._currentRoute();
  final id = AppRoutePaths.teacherHomeworkIdFromPath(location);
  if (id == null) throw StateError('The Stage 6 route omitted a Homework ID.');
  return id;
}

String _homeworkIdForTitle(_Stage6Harness h, String title) {
  final card = find
      .ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Card &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'teacherHomeworkCard',
              ),
        ),
      )
      .first;
  final key = h.tester.widget<Card>(card).key;
  if (key is! ValueKey<String> ||
      !key.value.startsWith('teacherHomeworkCard')) {
    throw StateError('The Stage 6 Homework card identity is invalid.');
  }
  return key.value.substring('teacherHomeworkCard'.length);
}

String _questionIdForPrompt(_Stage6Harness h, String prompt) {
  final card = find
      .ancestor(
        of: find.text(prompt),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Card &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'teacherQuestionBuilderCard',
              ),
        ),
      )
      .first;
  final key = h.tester.widget<Card>(card).key;
  if (key is! ValueKey<String> ||
      !key.value.startsWith('teacherQuestionBuilderCard')) {
    throw StateError('The Stage 6 Question card identity is invalid.');
  }
  return key.value.substring('teacherQuestionBuilderCard'.length);
}

int _questionCardPosition(_Stage6Harness h, String questionId) {
  final card = find.byKey(ValueKey('teacherQuestionBuilderCard$questionId'));
  final positionText = find.descendant(
    of: card,
    matching: find.textContaining('Question '),
  );
  final value = h.tester.widget<Text>(positionText.first).data;
  final match = RegExp(r'Question (\d+)').firstMatch(value ?? '');
  if (match == null) throw StateError('Question position was not rendered.');
  return int.parse(match.group(1)!);
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}

String _string(Map<String, Object?> value, String key) {
  final item = value[key];
  if (item is! String || item.isEmpty) {
    throw FormatException('Expected non-empty $key.');
  }
  return item;
}

void _exactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(value.keys.toSet()).isNotEmpty) {
    throw const FormatException('Stage 6 oracle keys are invalid.');
  }
}
