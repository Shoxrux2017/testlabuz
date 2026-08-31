import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/config/app_config.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/files/local_file_actions.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_file_picker.dart';

import 'stage5_e2e_support.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _password = String.fromEnvironment('STAGE5_E2E_PASSWORD');
const _oraclePath = String.fromEnvironment('STAGE5_E2E_ORACLE_PATH');
const _fixtureManifestPath = String.fromEnvironment(
  'STAGE5_E2E_FIXTURE_MANIFEST_PATH',
);
const _fileSinkRoot = String.fromEnvironment('STAGE5_E2E_FILE_SINK_ROOT');
const _authTokenKey = 'auth_access_token';

const _dynamicTitle = 'E2E S05 UI Topic';
const _dynamicSubject = 'E2E S05 Subject';
const _dynamicDescription = 'E2E S05 integration topic';
const _dynamicInstructions = 'E2E S05 Student instructions';
const _renamedPdf = 'E2E S05 PDF Renamed';
const _uuidPattern =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Stage 5 Topics and protected materials use the real Windows stack',
    (tester) async {
      final harness = await _Stage5Harness.create(
        tester,
        dynamicOracle: false,
        requireEmptySink: true,
      );
      try {
        await harness.launch();
        await _runMutationAndSecurityFlow(harness);
      } finally {
        await harness.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );

  testWidgets(
    'Stage 5 Topic and protected material state persists after backend restart',
    (tester) async {
      final harness = await _Stage5Harness.create(
        tester,
        dynamicOracle: true,
        requireEmptySink: false,
      );
      try {
        await harness.launch();
        await _runPersistenceFlow(harness);
      } finally {
        await harness.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

class _Stage5Harness {
  _Stage5Harness._({
    required this.tester,
    required this.oracle,
    required this.fixtures,
    required this.picker,
    required this.sink,
    required this.api,
  });

  final WidgetTester tester;
  final Stage5Oracle oracle;
  final Stage5FixtureManifest fixtures;
  final Stage5TestPicker picker;
  final Stage5LocalFileAdapter sink;
  final Stage5ProbeApi api;
  var _uiLoggedIn = false;

  static Future<_Stage5Harness> create(
    WidgetTester tester, {
    required bool dynamicOracle,
    required bool requireEmptySink,
  }) async {
    _assertEnvironment();
    await _configureDesktopView(tester);
    final oracle = await Stage5Oracle.load(_oraclePath, dynamic: dynamicOracle);
    final fixtures = await Stage5FixtureManifest.load(_fixtureManifestPath);
    final picker = Stage5TestPicker(fixtures);
    final sink = await Stage5LocalFileAdapter.create(
      _fileSinkRoot,
      requireEmpty: requireEmptySink,
    );
    return _Stage5Harness._(
      tester: tester,
      oracle: oracle,
      fixtures: fixtures,
      picker: picker,
      sink: sink,
      api: Stage5ProbeApi(
        baseUrl: _apiBaseUrl,
        password: _password,
        oracle: oracle,
      ),
    );
  }

  Future<void> launch() async {
    await const FlutterSecureStorage().delete(key: _authTokenKey);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromApiBaseUrl(_apiBaseUrl),
          ),
          teacherMaterialFilePickerProvider.overrideWithValue(picker),
          localFileActionsProvider.overrideWithValue(
            LocalFileActions(platform: sink),
          ),
        ],
        child: const TestLabUzApp(),
      ),
    );
    await waitForRoute(AppRoutePaths.login);
    await waitForKey('loginField');
  }

  Future<void> login(String actor, String workspaceRoute, String key) async {
    if (_uiLoggedIn) {
      throw StateError('A Stage 5 UI session is already active.');
    }
    await enter('loginField', oracle.logins[actor]!);
    await enter('passwordField', _password);
    await tapKey('signInButton');
    await waitForRoute(workspaceRoute);
    await waitForKey(key);
    _uiLoggedIn = true;
  }

  Future<void> logout() async {
    if (!_uiLoggedIn) return;
    if (find.byKey(const Key('entryLogoutButton')).evaluate().isEmpty) {
      final route = _currentRoute(tester);
      if (AppRoutePaths.isTeacherSegment(route)) {
        await go(AppRoutePaths.teacher);
      } else if (AppRoutePaths.isStudentSegment(route)) {
        await go(AppRoutePaths.student);
      } else {
        throw StateError('The Stage 5 UI session has no logout surface.');
      }
    }
    await tapKey('entryLogoutButton');
    await waitForRoute(AppRoutePaths.login);
    await waitForKey('loginField');
    _uiLoggedIn = false;
  }

  Future<void> close() async {
    Object? firstFailure;
    try {
      await logout();
    } catch (error) {
      firstFailure = error;
    }
    try {
      await api.logoutAll();
    } catch (error) {
      firstFailure ??= error;
    } finally {
      api.close();
      await const FlutterSecureStorage().delete(key: _authTokenKey);
    }
    if (firstFailure != null) throw firstFailure;
  }

  Future<void> enter(String key, String value) async {
    final finder = find.byKey(Key(key));
    await waitFor(finder);
    await tester.ensureVisible(finder.last);
    await tester.tap(finder.last);
    await tester.enterText(finder.last, value);
    await tester.pump();
  }

  Future<void> tapKey(String key) => tap(find.byKey(Key(key)));

  Future<void> tap(Finder finder) async {
    await waitFor(finder);
    await tester.ensureVisible(finder.last);
    await tester.tap(finder.last);
    await tester.pump();
  }

  Future<void> go(String route) async {
    GoRouter.of(_routerContext(tester)).go(route);
    await tester.pump();
    await waitForRoute(route);
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
    reason: 'Expected a required Stage 5 widget.',
    timeout: timeout,
  );

  Future<void> waitGone(
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) => pumpUntil(
    () => finder.evaluate().isEmpty,
    reason: 'Expected a transient Stage 5 widget to disappear.',
    timeout: timeout,
  );

  Future<void> waitForRoute(String route) => pumpUntil(
    () => _currentRoute(tester) == route,
    reason: 'Expected route $route.',
  );

  Future<void> pumpUntil(
    bool Function() condition, {
    required String reason,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (condition()) return;
    }
    expect(
      condition(),
      isTrue,
      reason: '$reason Visible text: ${_visibleText(tester)}',
    );
  }
}

Future<void> _configureDesktopView(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1800, 1000);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

void _assertEnvironment() {
  final api = Uri.tryParse(_apiBaseUrl);
  if (api == null ||
      api.scheme != 'http' ||
      api.host != '127.0.0.1' ||
      !api.hasPort ||
      api.path != '/api/v1' ||
      api.userInfo.isNotEmpty ||
      api.hasQuery ||
      api.hasFragment ||
      !RegExp(r'^S05-Aa9-[a-f0-9]{32}$').hasMatch(_password) ||
      _oraclePath.isEmpty ||
      _fixtureManifestPath.isEmpty ||
      _fileSinkRoot.isEmpty ||
      !Platform.isWindows) {
    throw StateError('The Stage 5 runner-to-Dart contract is invalid.');
  }
}

String _currentRoute(WidgetTester tester) =>
    GoRouter.of(_routerContext(tester)).routeInformationProvider.value.uri.path;

BuildContext _routerContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

String _visibleText(WidgetTester tester) => find
    .byType(Text)
    .evaluate()
    .map((element) => element.widget)
    .whereType<Text>()
    .map((widget) => widget.data?.trim())
    .whereType<String>()
    .where((text) => text.isNotEmpty)
    .take(30)
    .join(' | ');

Future<void> _runMutationAndSecurityFlow(_Stage5Harness h) async {
  await h.login(
    'target_teacher',
    AppRoutePaths.teacher,
    'teacherLearningWorkspace',
  );
  final topicId = await _createDynamicTopic(h);
  await _expectTeacherTopic(h, topicId, status: 'draft');
  await _verifyTeacherCreateScopeProbes(h);

  await h.logout();
  await h.login(
    'target_student',
    AppRoutePaths.student,
    'studentLearningWorkspace',
  );
  await h.waitGone(find.byKey(const Key('studentTopicInitialLoading')));
  expect(find.text(_dynamicTitle), findsNothing);
  await h.go(AppRoutePaths.studentTopicDetailLocation(topicId));
  await h.waitForKey('studentTopicUnavailable');
  await _expectError(
    await h.api.actorRequest(
      'target_student',
      'GET',
      '/student/topics/$topicId',
    ),
    404,
    'resource_not_found',
  );

  await h.tapKey('studentTopicUnavailableBackButton');
  await h.waitForRoute(AppRoutePaths.student);
  await h.waitForKey('studentLearningWorkspace');
  await h.tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  await h.logout();
  await h.login(
    'target_teacher',
    AppRoutePaths.teacher,
    'teacherLearningWorkspace',
  );
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.waitForKey('teacherTopicDetailScreen');
  await _lifecycleUi(
    h,
    'activate',
    expectedStatus: 'Draft',
    expectFailureFeedback: true,
  );
  await _expectError(
    await h.api.actorRequest(
      'target_teacher',
      'POST',
      '/teacher/topics/$topicId/activate',
    ),
    409,
    'topic_not_editable',
  );

  await _uploadFourMaterials(h, topicId);
  var materials = await _teacherMaterials(h, topicId);
  _expectOriginalNames(materials, const [
    'e2e_s05_material.pdf',
    'e2e_s05_material.docx',
    'e2e_s05_material.ppt',
    'e2e_s05_material.pptx',
  ]);
  _expectMaterialsMatchFixtures(h, materials);
  final pdf = _materialByOriginalName(materials, 'e2e_s05_material.pdf');
  final ppt = _materialByOriginalName(materials, 'e2e_s05_material.ppt');
  final pdfMaterialId = pdf['id']! as String;
  final pdfFileId = stage5Map(pdf['file'])['id']! as String;
  final pptMaterialId = ppt['id']! as String;
  final pptFileId = stage5Map(ppt['file'])['id']! as String;

  await _renameMaterial(h, pdfMaterialId);
  materials = await _teacherMaterials(h, topicId);
  expect(_materialById(materials, pdfMaterialId)['title'], _renamedPdf);
  await _verifyServerUploadValidation(h, topicId, materials);

  await _lifecycleUi(h, 'activate', expectedStatus: 'Active');
  final activated = await _expectTeacherTopic(h, topicId, status: 'active');
  final activateAgain = _data(
    await _expectSuccess(
      await h.api.actorRequest(
        'target_teacher',
        'POST',
        '/teacher/topics/$topicId/activate',
      ),
      200,
    ),
  );
  _expectSameLifecycleWrite(activated, activateAgain);

  await h.logout();
  await h.login(
    'target_student',
    AppRoutePaths.student,
    'studentLearningWorkspace',
  );
  await _openStudentTopic(h, topicId, _dynamicTitle);
  expect(find.text(_renamedPdf), findsOneWidget);
  await _verifyStudentTransfer(
    h,
    materialId: pdfMaterialId,
    fileId: pdfFileId,
    fixture: h.fixtures['pdf'],
    operations: const ['save', 'open'],
  );
  await _verifySecurityMatrix(h, topicId, pdfFileId);

  await h.logout();
  await h.login(
    'target_teacher',
    AppRoutePaths.teacher,
    'teacherLearningWorkspace',
  );
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.waitForKey('teacherLearningMaterialsSection');
  await _replaceMaterial(h, pdfMaterialId);
  materials = await _teacherMaterials(h, topicId);
  final replacedPdf = _materialById(materials, pdfMaterialId);
  expect(stage5Map(replacedPdf['file'])['id'], pdfFileId);
  expect(
    stage5Map(replacedPdf['file'])['original_name'],
    'e2e_s05_replacement.pdf',
  );
  expect(replacedPdf['title'], _renamedPdf);
  await _removeMaterial(h, pptMaterialId);
  materials = await _teacherMaterials(h, topicId);
  expect(materials.any((material) => material['id'] == pptMaterialId), isFalse);
  await _expectError(
    await h.api.actorRequest(
      'target_teacher',
      'GET',
      '/files/$pptFileId/download',
    ),
    404,
    'resource_not_found',
  );

  await _expectError(
    await h.api.actorRequest(
      'target_teacher',
      'POST',
      '/teacher/topics/$topicId/archive',
    ),
    409,
    'topic_not_editable',
  );
  await _lifecycleUi(h, 'close', expectedStatus: 'Closed');
  final closed = await _expectTeacherTopic(h, topicId, status: 'closed');
  final closeAgain = _data(
    await _expectSuccess(
      await h.api.actorRequest(
        'target_teacher',
        'POST',
        '/teacher/topics/$topicId/close',
      ),
      200,
    ),
  );
  _expectSameLifecycleWrite(closed, closeAgain);
  await _expectError(
    await h.api.actorRequest(
      'target_teacher',
      'POST',
      '/teacher/topics/$topicId/activate',
    ),
    409,
    'topic_not_editable',
  );

  await _verifyStudentHistoricalAccess(h, topicId, pdfMaterialId);
  await h.logout();
  await h.login(
    'target_teacher',
    AppRoutePaths.teacher,
    'teacherLearningWorkspace',
  );
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await _lifecycleUi(h, 'archive', expectedStatus: 'Archived');
  final archived = await _expectTeacherTopic(h, topicId, status: 'archived');
  await _verifyArchivedTopicReadOnly(h, topicId, pdfMaterialId, archived);
  await _verifyStudentHistoricalAccess(h, topicId, pdfMaterialId);

  await h.logout();
  await h.login(
    'target_teacher',
    AppRoutePaths.teacher,
    'teacherLearningWorkspace',
  );
  await _archiveSeededDraft(h);
  await _verifyArchivedGroupHistoricalFlow(h);
  h.picker.assertComplete();
  await h.logout();
}

Future<String> _createDynamicTopic(_Stage5Harness h) async {
  await h.waitGone(find.byKey(const Key('teacherGroupInitialLoading')));
  await h.waitFor(find.text('E2E S05 Group A'));
  expect(find.text('E2E S05 Group B'), findsNothing);
  expect(find.text('E2E S05 Archived Group C'), findsNothing);
  final createButton = find.byKey(const Key('teacherCreateTopicButton'));
  await h.pumpUntil(() {
    if (createButton.evaluate().isEmpty) {
      return false;
    }
    return h.tester.widget<FilledButton>(createButton).onPressed != null;
  }, reason: 'Expected Create Topic action to become enabled.');
  await h.tapKey('teacherCreateTopicButton');
  await h.waitForRoute(AppRoutePaths.teacherTopicCreate);
  await h.tapKey('teacherTopicChooseGroupButton');
  await h.waitForKey('teacherTopicGroupPickerDialog');
  await h.waitFor(find.text('E2E S05 Group A'));
  expect(find.text('E2E S05 Group B'), findsNothing);
  expect(find.text('E2E S05 Archived Group C'), findsNothing);
  await h.tapKey('teacherTopicPickerGroup${h.oracle.ids['group_a']}');
  await h.tapKey('teacherTopicGroupPickerUseButton');
  await h.waitGone(find.byKey(const Key('teacherTopicGroupPickerDialog')));
  expect(
    _textForKey(h.tester, 'teacherTopicCreateSelectedGroup'),
    'E2E S05 Group A',
  );
  await h.enter('teacherTopicTitleField', _dynamicTitle);
  await h.enter('teacherTopicSubjectField', _dynamicSubject);
  await h.enter('teacherTopicDescriptionField', _dynamicDescription);
  await h.enter('teacherTopicInstructionsField', _dynamicInstructions);
  await h.tapKey('teacherTopicCreateSubmitButton');
  await h.pumpUntil(
    () => AppRoutePaths.isTeacherTopicDetailPath(_currentRoute(h.tester)),
    reason: 'Expected the canonical created Topic detail route.',
  );
  final topicId = AppRoutePaths.teacherTopicIdFromPath(_currentRoute(h.tester));
  expect(topicId, isNotNull);
  expect(RegExp(_uuidPattern).hasMatch(topicId!), isTrue);
  await h.waitForKey('teacherTopicDetailScreen');
  await h.waitFor(find.text('Topic: Draft'));
  return topicId;
}

Future<void> _verifyTeacherCreateScopeProbes(_Stage5Harness h) async {
  final before = await _teacherTopicList(h, search: _dynamicTitle);
  expect(before, hasLength(1));
  for (final group in ['group_b', 'foreign_group']) {
    await _expectError(
      await h.api.actorRequest(
        'target_teacher',
        'POST',
        '/teacher/topics',
        data: {
          'group_id': h.oracle.ids[group],
          'title':
              'E2E S05 rejected ${group == 'group_b' ? 'Group B' : 'Foreign'} Topic',
          'subject': _dynamicSubject,
          'description': _dynamicDescription,
          'student_instructions': _dynamicInstructions,
          'lesson_at': null,
        },
      ),
      404,
      'resource_not_found',
    );
  }
  expect(await _teacherTopicList(h, search: _dynamicTitle), hasLength(1));
}

Future<void> _uploadFourMaterials(_Stage5Harness h, String topicId) async {
  await h.waitForKey('teacherLearningMaterialsSection');
  await h.waitGone(find.byKey(const Key('teacherMaterialsLoading')));
  expect(
    _textForKey(h.tester, 'teacherMaterialUploadCapability'),
    contains('PDF, DOCX, PPT, PPTX'),
  );
  expect(
    _textForKey(h.tester, 'teacherMaterialUploadCapability'),
    contains('25 MiB'),
  );
  for (final originalName in [
    'e2e_s05_material.pdf',
    'e2e_s05_material.docx',
    'e2e_s05_material.ppt',
    'e2e_s05_material.pptx',
  ]) {
    final before = (await _teacherMaterials(h, topicId)).length;
    await h.tapKey('teacherMaterialUploadButton');
    await h.waitForKey('teacherMaterialUploadDialog');
    await h.tapKey('teacherMaterialChooseFileButton');
    await h.waitFor(find.text(originalName));
    await h.tapKey('teacherMaterialUploadSubmitButton');
    await h.waitGone(find.byKey(const Key('teacherMaterialUploadDialog')));
    await h.pumpUntil(
      () => find.text(originalName).evaluate().isNotEmpty,
      reason: 'Expected the uploaded material in authoritative UI order.',
      timeout: const Duration(minutes: 2),
    );
    expect((await _teacherMaterials(h, topicId)).length, before + 1);
  }
}

Future<void> _renameMaterial(_Stage5Harness h, String materialId) async {
  await h.tapKey('teacherMaterialEditTitle$materialId');
  await h.waitForKey('teacherMaterialEditTitleDialog');
  await h.tapKey('teacherMaterialUseOriginalNameCheckbox');
  await h.enter('teacherMaterialEditTitleField', _renamedPdf);
  await h.tapKey('teacherMaterialEditTitleSaveButton');
  await h.waitGone(find.byKey(const Key('teacherMaterialEditTitleDialog')));
  await h.waitFor(find.text(_renamedPdf));
}

Future<void> _replaceMaterial(_Stage5Harness h, String materialId) async {
  await h.tapKey('teacherMaterialReplace$materialId');
  await h.waitForKey('teacherMaterialReplaceDialog');
  await h.tapKey('teacherMaterialReplaceChooseFileButton');
  await h.waitFor(find.text('e2e_s05_replacement.pdf'));
  await h.tapKey('teacherMaterialReplaceConfirmButton');
  await h.waitGone(find.byKey(const Key('teacherMaterialReplaceDialog')));
  await h.waitFor(find.text('e2e_s05_replacement.pdf'));
}

Future<void> _removeMaterial(_Stage5Harness h, String materialId) async {
  await h.tapKey('teacherMaterialRemove$materialId');
  await h.waitFor(find.text('Remove this learning material?'));
  await h.tapKey('teacherMaterialRemoveConfirmButton');
  await h.waitGone(find.text('Remove this learning material?'));
  await h.waitGone(find.byKey(ValueKey('teacherMaterial$materialId')));
}

Future<void> _lifecycleUi(
  _Stage5Harness h,
  String action, {
  required String expectedStatus,
  bool expectFailureFeedback = false,
}) async {
  await h.tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  await h.tapKey('teacherTopicLifecycle$action');
  await h.waitForKey('teacherTopicLifecycleConfirmButton');
  await h.tapKey('teacherTopicLifecycleConfirmButton');
  await h.waitGone(find.byKey(const Key('teacherTopicLifecycleConfirmButton')));
  if (expectFailureFeedback) {
    await h.waitFor(find.byType(SnackBar));
  }
  await h.waitFor(find.text('Topic: $expectedStatus'));
  await h.waitGone(find.byKey(const Key('teacherTopicDetailProgress')));
}

Future<void> _verifyServerUploadValidation(
  _Stage5Harness h,
  String topicId,
  List<Stage5Json> baseline,
) async {
  final cases = <(String, String, String, int, String)>[
    ('target_teacher', topicId, 'unsupported', 422, 'unsupported_file_type'),
    ('target_teacher', topicId, 'platform_over', 422, 'file_too_large'),
    (
      'low_limit_teacher',
      h.oracle.ids['low_limit_topic']!,
      'low_limit_over',
      422,
      'file_too_large',
    ),
  ];
  for (final requestCase in cases) {
    final response = await h.api.upload(
      requestCase.$1,
      '/teacher/topics/${requestCase.$2}/materials',
      h.fixtures[requestCase.$3],
    );
    await _expectError(response, requestCase.$4, requestCase.$5);
  }
  final after = await _teacherMaterials(h, topicId);
  expect(
    after.map((material) => jsonEncode(material)).toList(),
    baseline.map((material) => jsonEncode(material)).toList(),
  );
  final lowLimit = await _materialsForActor(
    h,
    'low_limit_teacher',
    h.oracle.ids['low_limit_topic']!,
  );
  expect(lowLimit, isEmpty);
  await h.api.logout('low_limit_teacher');
}

Future<void> _verifySecurityMatrix(
  _Stage5Harness h,
  String topicId,
  String fileId,
) async {
  final baselineTopic = await _expectTeacherTopic(h, topicId, status: 'active');
  final baselineMaterials = await _teacherMaterials(h, topicId);
  final requests = <_DeniedRequest>[
    _DeniedRequest(
      actor: null,
      method: 'GET',
      path: '/files/$fileId/download',
      status: 401,
      code: 'authentication_required',
    ),
    _DeniedRequest(
      actor: 'target_admin',
      method: 'GET',
      path: '/files/$fileId/download',
      status: 403,
      code: 'forbidden',
    ),
    _DeniedRequest(
      actor: 'target_student',
      method: 'GET',
      path: '/student/topics/${h.oracle.ids['unrelated_topic']}',
    ),
    _DeniedRequest(
      actor: 'target_student',
      method: 'GET',
      path: '/files/${h.oracle.ids['unrelated_file']}/download',
    ),
    _DeniedRequest(
      actor: 'target_student',
      method: 'GET',
      path: '/student/topics/${h.oracle.ids['foreign_topic']}',
    ),
    _DeniedRequest(
      actor: 'target_student',
      method: 'GET',
      path: '/files/${h.oracle.ids['foreign_file']}/download',
    ),
    _DeniedRequest(
      actor: 'target_student',
      method: 'GET',
      path: '/teacher/topics/$topicId',
      status: 403,
      code: 'forbidden',
    ),
    for (final actor in [
      'unrelated_student',
      'ended_student',
      'foreign_student',
    ]) ...[
      _DeniedRequest(
        actor: actor,
        method: 'GET',
        path: '/student/topics/$topicId',
      ),
      _DeniedRequest(
        actor: actor,
        method: 'GET',
        path: '/files/$fileId/download',
      ),
    ],
    _DeniedRequest(
      actor: 'ended_student',
      method: 'GET',
      path: '/student/topics/${h.oracle.ids['archived_group_topic']}',
    ),
    _DeniedRequest(
      actor: 'ended_student',
      method: 'GET',
      path: '/files/${h.oracle.ids['archived_group_file']}/download',
    ),
    _DeniedRequest(
      actor: 'target_teacher',
      method: 'GET',
      path: '/teacher/topics/${h.oracle.ids['unrelated_topic']}',
    ),
    _DeniedRequest(
      actor: 'target_teacher',
      method: 'PATCH',
      path: '/teacher/topics/${h.oracle.ids['unrelated_topic']}',
      data: const {'title': 'E2E S05 forbidden mutation'},
    ),
    _DeniedRequest(
      actor: 'target_teacher',
      method: 'GET',
      path: '/files/${h.oracle.ids['unrelated_file']}/download',
    ),
    _DeniedRequest(
      actor: 'target_teacher',
      method: 'GET',
      path: '/teacher/topics/${h.oracle.ids['foreign_topic']}',
    ),
    _DeniedRequest(
      actor: 'target_teacher',
      method: 'GET',
      path: '/files/${h.oracle.ids['foreign_file']}/download',
    ),
  ];
  for (final denied in requests) {
    final response = denied.actor == null
        ? await h.api.request(denied.method, denied.path, data: denied.data)
        : await h.api.actorRequest(
            denied.actor!,
            denied.method,
            denied.path,
            data: denied.data,
          );
    await _expectError(response, denied.status, denied.code);
  }
  expect(
    await _expectTeacherTopic(h, topicId, status: 'active'),
    baselineTopic,
  );
  expect(
    (await _teacherMaterials(
      h,
      topicId,
    )).map((material) => jsonEncode(material)).toList(),
    baselineMaterials.map((material) => jsonEncode(material)).toList(),
  );
  for (final actor in [
    'target_admin',
    'target_student',
    'unrelated_student',
    'ended_student',
    'foreign_student',
  ]) {
    await h.api.logout(actor);
  }
}

class _DeniedRequest {
  const _DeniedRequest({
    required this.actor,
    required this.method,
    required this.path,
    this.status = 404,
    this.code = 'resource_not_found',
    this.data,
  });

  final String? actor;
  final String method;
  final String path;
  final int status;
  final String code;
  final Object? data;
}

Future<void> _verifyStudentTransfer(
  _Stage5Harness h, {
  required String materialId,
  required String fileId,
  required Stage5Fixture fixture,
  required List<String> operations,
}) async {
  for (final operation in operations) {
    final before = h.sink.records.length;
    final button = find.byKey(
      ValueKey(
        operation == 'save'
            ? 'studentMaterialSave$materialId'
            : 'studentMaterialOpen$materialId',
      ),
    );
    await h.waitFor(button);
    await h.tester.ensureVisible(button.last);
    await h.tester.tap(button.last);
    await h.tester.pump();
    expect(
      find.byKey(ValueKey('studentMaterialProgress$materialId')),
      findsOneWidget,
    );
    expect(h.sink.records, hasLength(before));
    await h.pumpUntil(
      () => h.sink.records.length == before + 1,
      reason: 'Expected a production protected transfer sink record.',
      timeout: const Duration(minutes: 2),
    );
    final record = h.sink.records.last;
    expect(record.operation, operation);
    expect(record.fileId, operation == 'open' ? fileId : isNull);
    expect(
      record.filename,
      operation == 'save'
          ? fixture.originalName
          : '$fileId.${fixture.extension}',
    );
    expect(record.extension, fixture.extension);
    expect(record.mimeType, fixture.mimeType);
    expect(record.sizeBytes, fixture.sizeBytes);
    expect(record.sha256, fixture.sha256);
    expect(
      await File(record.path).readAsBytes(),
      await File(fixture.path).readAsBytes(),
    );
    await h.waitGone(
      find.byKey(ValueKey('studentMaterialProgress$materialId')),
    );
  }
}

Future<void> _verifyStudentHistoricalAccess(
  _Stage5Harness h,
  String topicId,
  String materialId,
) async {
  await h.logout();
  await h.login(
    'target_student',
    AppRoutePaths.student,
    'studentLearningWorkspace',
  );
  await _openStudentTopic(h, topicId, _dynamicTitle);
  final material = _materialById(
    stage5List(
      _data(
        await _expectSuccess(
          await h.api.actorRequest(
            'target_student',
            'GET',
            '/student/topics/$topicId',
          ),
          200,
        ),
      )['materials'],
    ).map(stage5Map).toList(),
    materialId,
  );
  final fileId = stage5Map(material['file'])['id']! as String;
  await _verifyStudentTransfer(
    h,
    materialId: materialId,
    fileId: fileId,
    fixture: h.fixtures['replacement_pdf'],
    operations: const ['save'],
  );
}

Future<void> _openStudentTopic(
  _Stage5Harness h,
  String topicId,
  String title,
) async {
  await h.waitGone(find.byKey(const Key('studentTopicInitialLoading')));
  await h.waitFor(find.byKey(ValueKey('studentTopicCard$topicId')));
  await h.tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  await h.tap(find.byKey(ValueKey('studentTopicCard$topicId')));
  await h.waitForRoute(AppRoutePaths.studentTopicDetailLocation(topicId));
  await h.waitForKey('studentTopicDetailScreen');
  await h.waitFor(find.text(title));
  _expectNoSensitiveRenderedText(h.tester);
}

Future<void> _verifyArchivedTopicReadOnly(
  _Stage5Harness h,
  String topicId,
  String materialId,
  Stage5Json archived,
) async {
  final baselineMaterials = await _teacherMaterials(h, topicId);
  expect(find.byKey(const Key('teacherTopicEditButton')), findsNothing);
  expect(find.byKey(const Key('teacherMaterialUploadButton')), findsNothing);
  expect(
    find.byKey(ValueKey('teacherMaterialReplace$materialId')),
    findsNothing,
  );
  for (final lifecycle in ['activate', 'close']) {
    await _expectError(
      await h.api.actorRequest(
        'target_teacher',
        'POST',
        '/teacher/topics/$topicId/$lifecycle',
      ),
      409,
      'topic_not_editable',
    );
  }
  final archiveAgain = _data(
    await _expectSuccess(
      await h.api.actorRequest(
        'target_teacher',
        'POST',
        '/teacher/topics/$topicId/archive',
      ),
      200,
    ),
  );
  _expectSameLifecycleWrite(archived, archiveAgain);
  final fixture = h.fixtures['pdf'];
  final rejected = <Future<Response<Object?>> Function()>[
    () => h.api.upload(
      'target_teacher',
      '/teacher/topics/$topicId/materials',
      fixture,
    ),
    () => h.api.upload(
      'target_teacher',
      '/teacher/materials/$materialId/replace',
      fixture,
    ),
    () => h.api.actorRequest(
      'target_teacher',
      'PATCH',
      '/teacher/materials/$materialId',
      data: const {'title': 'E2E S05 forbidden archived title'},
    ),
    () => h.api.actorRequest(
      'target_teacher',
      'DELETE',
      '/teacher/materials/$materialId',
    ),
  ];
  for (final request in rejected) {
    await _expectError(await request(), 409, 'topic_not_editable');
  }
  expect(await _expectTeacherTopic(h, topicId, status: 'archived'), archived);
  expect(
    (await _teacherMaterials(
      h,
      topicId,
    )).map((material) => jsonEncode(material)).toList(),
    baselineMaterials.map((material) => jsonEncode(material)).toList(),
  );
}

Future<void> _archiveSeededDraft(_Stage5Harness h) async {
  final topicId = h.oracle.ids['seeded_draft_topic']!;
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.waitForKey('teacherTopicDetailScreen');
  await h.waitFor(find.text('E2E S05 Seeded Draft Topic'));
  await _lifecycleUi(h, 'archive', expectedStatus: 'Archived');
  final archived = await _expectTeacherTopic(h, topicId, status: 'archived');
  final repeated = _data(
    await _expectSuccess(
      await h.api.actorRequest(
        'target_teacher',
        'POST',
        '/teacher/topics/$topicId/archive',
      ),
      200,
    ),
  );
  _expectSameLifecycleWrite(archived, repeated);
}

Future<void> _verifyArchivedGroupHistoricalFlow(_Stage5Harness h) async {
  final topicId = h.oracle.ids['archived_group_topic']!;
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.waitFor(find.text('E2E S05 Archived Group Topic'));
  await h.waitFor(find.text('Group: Archived'));
  final baselineTopic = await _expectTeacherTopic(h, topicId, status: 'active');
  final baselineMaterials = await _teacherMaterials(h, topicId);
  expect(baselineMaterials, hasLength(1));
  final materialId = baselineMaterials.single['id']! as String;
  final file = stage5Map(baselineMaterials.single['file']);
  final fileId = file['id']! as String;
  await _verifyTeacherTransfer(
    h,
    materialId: materialId,
    fileId: fileId,
    expectedFile: file,
  );

  await _expectError(
    await h.api.actorRequest(
      'target_teacher',
      'POST',
      '/teacher/topics',
      data: {
        'group_id': h.oracle.ids['group_c'],
        'title': 'E2E S05 forbidden archived Group Topic',
        'subject': _dynamicSubject,
        'description': _dynamicDescription,
        'student_instructions': _dynamicInstructions,
        'lesson_at': null,
      },
    ),
    404,
    'resource_not_found',
  );
  final rejected = <Future<Response<Object?>> Function()>[
    () => h.api.actorRequest(
      'target_teacher',
      'PATCH',
      '/teacher/topics/$topicId',
      data: const {'title': 'E2E S05 forbidden Group C update'},
    ),
    () => h.api.actorRequest(
      'target_teacher',
      'POST',
      '/teacher/topics/$topicId/activate',
    ),
    () => h.api.upload(
      'target_teacher',
      '/teacher/topics/$topicId/materials',
      h.fixtures['pdf'],
    ),
    () => h.api.upload(
      'target_teacher',
      '/teacher/materials/$materialId/replace',
      h.fixtures['pdf'],
    ),
    () => h.api.actorRequest(
      'target_teacher',
      'PATCH',
      '/teacher/materials/$materialId',
      data: const {'title': 'E2E S05 forbidden Group C title'},
    ),
    () => h.api.actorRequest(
      'target_teacher',
      'DELETE',
      '/teacher/materials/$materialId',
    ),
  ];
  for (final request in rejected) {
    await _expectError(await request(), 409, 'topic_not_editable');
  }
  expect(
    await _expectTeacherTopic(h, topicId, status: 'active'),
    baselineTopic,
  );
  expect(
    (await _teacherMaterials(
      h,
      topicId,
    )).map((material) => jsonEncode(material)).toList(),
    baselineMaterials.map((material) => jsonEncode(material)).toList(),
  );

  await _verifyGroupCStudentState(h, topicId, materialId, fileId, 'Active');
  await h.logout();
  await h.login(
    'target_teacher',
    AppRoutePaths.teacher,
    'teacherLearningWorkspace',
  );
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await _lifecycleUi(h, 'close', expectedStatus: 'Closed');
  await _expectTeacherTopic(h, topicId, status: 'closed');
  await _verifyGroupCStudentState(h, topicId, materialId, fileId, 'Closed');
  await h.logout();
  await h.login(
    'target_teacher',
    AppRoutePaths.teacher,
    'teacherLearningWorkspace',
  );
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await _lifecycleUi(h, 'archive', expectedStatus: 'Archived');
  await _expectTeacherTopic(h, topicId, status: 'archived');
  await _verifyGroupCStudentState(h, topicId, materialId, fileId, 'Archived');

  for (final path in ['/student/topics/$topicId', '/files/$fileId/download']) {
    await _expectError(
      await h.api.actorRequest('ended_student', 'GET', path),
      404,
      'resource_not_found',
    );
  }
  await h.api.logout('ended_student');
}

Future<void> _verifyGroupCStudentState(
  _Stage5Harness h,
  String topicId,
  String materialId,
  String fileId,
  String status,
) async {
  await h.logout();
  await h.login(
    'target_student',
    AppRoutePaths.student,
    'studentLearningWorkspace',
  );
  await _openStudentTopic(h, topicId, 'E2E S05 Archived Group Topic');
  await h.waitFor(find.text('Topic: $status'));
  await _verifyUnpinnedStudentTransfer(h, materialId, fileId);
}

Future<void> _verifyTeacherTransfer(
  _Stage5Harness h, {
  required String materialId,
  required String fileId,
  required Stage5Json expectedFile,
}) async {
  final before = h.sink.records.length;
  final button = find.byKey(ValueKey('teacherMaterialOpen$materialId'));
  await h.waitFor(button);
  await h.tester.ensureVisible(button.last);
  await h.tester.tap(button.last);
  await h.tester.pump();
  expect(
    find.byKey(ValueKey('teacherMaterialTransferProgress$materialId')),
    findsOneWidget,
  );
  expect(h.sink.records, hasLength(before));
  await h.pumpUntil(
    () => h.sink.records.length == before + 1,
    reason: 'Expected a historical Teacher protected transfer.',
    timeout: const Duration(minutes: 2),
  );
  final record = h.sink.records.last;
  final expectedExtension = expectedFile['extension']! as String;
  expect(record.operation, 'open');
  expect(record.fileId, fileId);
  expect(record.filename, '$fileId.$expectedExtension');
  expect(record.extension, expectedExtension);
  expect(record.mimeType, expectedFile['mime_type']);
  expect(record.sizeBytes, expectedFile['size_bytes']);
  expect(stage5Sha256(await File(record.path).readAsBytes()), record.sha256);
}

Future<void> _verifyUnpinnedStudentTransfer(
  _Stage5Harness h,
  String materialId,
  String fileId,
) async {
  final before = h.sink.records.length;
  final button = find.byKey(ValueKey('studentMaterialOpen$materialId'));
  await h.waitFor(button);
  await h.tester.ensureVisible(button.last);
  await h.tester.tap(button.last);
  await h.tester.pump();
  expect(
    find.byKey(ValueKey('studentMaterialProgress$materialId')),
    findsOneWidget,
  );
  expect(h.sink.records, hasLength(before));
  await h.pumpUntil(
    () => h.sink.records.length == before + 1,
    reason: 'Expected a historical Student protected transfer.',
    timeout: const Duration(minutes: 2),
  );
  final record = h.sink.records.last;
  expect(record.operation, 'open');
  expect(record.fileId, fileId);
  expect(record.sizeBytes, greaterThan(0));
  expect(stage5Sha256(await File(record.path).readAsBytes()), record.sha256);
}

Future<void> _runPersistenceFlow(_Stage5Harness h) async {
  final dynamic = h.oracle.dynamic;
  if (dynamic == null) {
    throw StateError('The persistence oracle is incomplete.');
  }
  final topicId = dynamic['topic_id']! as String;
  final materialId = dynamic['replacement_material_id']! as String;
  final fileId = dynamic['replacement_file_id']! as String;

  await h.login(
    'target_student',
    AppRoutePaths.student,
    'studentLearningWorkspace',
  );
  await _openStudentTopic(h, topicId, _dynamicTitle);
  await h.waitFor(find.text('Topic: Archived'));
  await h.waitFor(find.text(_renamedPdf));
  await _verifyStudentTransfer(
    h,
    materialId: materialId,
    fileId: fileId,
    fixture: h.fixtures['replacement_pdf'],
    operations: const ['open'],
  );
  await _expectError(
    await h.api.actorRequest(
      'target_student',
      'GET',
      '/files/${dynamic['removed_file_id']}/download',
    ),
    404,
    'resource_not_found',
  );
  for (final actor in [
    'ended_student',
    'unrelated_student',
    'foreign_student',
  ]) {
    await _expectError(
      await h.api.actorRequest(actor, 'GET', '/student/topics/$topicId'),
      404,
      'resource_not_found',
    );
    await h.api.logout(actor);
  }

  await h.logout();
  await h.login(
    'target_teacher',
    AppRoutePaths.teacher,
    'teacherLearningWorkspace',
  );
  await h.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
  await h.waitFor(find.text(_dynamicTitle));
  await h.waitFor(find.text('Topic: Archived'));
  await h.waitFor(find.text(_renamedPdf));
  _expectNoSensitiveRenderedText(h.tester);
  final persisted = await _expectTeacherTopic(h, topicId, status: 'archived');
  expect(persisted['title'], _dynamicTitle);
  expect(persisted['subject'], _dynamicSubject);
  expect(persisted['description'], _dynamicDescription);
  expect(persisted['student_instructions'], _dynamicInstructions);
  final materials = await _teacherMaterials(h, topicId);
  expect(
    materials.map((item) => item['id']),
    unorderedEquals(stage5List(dynamic['remaining_material_ids'])),
  );
  _expectOriginalNames(materials, const [
    'e2e_s05_replacement.pdf',
    'e2e_s05_material.docx',
    'e2e_s05_material.pptx',
  ]);
  final replacement = _materialById(materials, materialId);
  expect(stage5Map(replacement['file'])['id'], fileId);
  expect(dynamic['replacement_sha256'], h.fixtures['replacement_pdf'].sha256);

  await h.go(
    AppRoutePaths.teacherTopicDetailLocation(
      h.oracle.ids['seeded_draft_topic']!,
    ),
  );
  await h.waitFor(find.text('E2E S05 Seeded Draft Topic'));
  await h.waitFor(find.text('Topic: Archived'));
  await h.go(
    AppRoutePaths.teacherTopicDetailLocation(
      h.oracle.ids['archived_group_topic']!,
    ),
  );
  await h.waitFor(find.text('E2E S05 Archived Group Topic'));
  await h.waitFor(find.text('Topic: Archived'));
  await h.waitFor(find.text('Group: Archived'));
  await h.logout();
}

Future<Stage5Json> _expectTeacherTopic(
  _Stage5Harness h,
  String topicId, {
  required String status,
}) async {
  final response = await _expectSuccess(
    await h.api.actorRequest(
      'target_teacher',
      'GET',
      '/teacher/topics/$topicId',
    ),
    200,
  );
  final topic = _data(response);
  expect(topic['id'], topicId);
  expect(topic['status'], status);
  _expectPublicProjection(topic);
  return topic;
}

Future<List<Stage5Json>> _teacherTopicList(
  _Stage5Harness h, {
  required String search,
}) async {
  final response = await _expectSuccess(
    await h.api.actorRequest(
      'target_teacher',
      'GET',
      '/teacher/topics?search=${Uri.encodeQueryComponent(search)}&page=1&per_page=20',
    ),
    200,
  );
  final envelope = stage5Map(response.data);
  _expectPublicProjection(envelope);
  return stage5List(envelope['data']).map(stage5Map).toList();
}

Future<List<Stage5Json>> _teacherMaterials(_Stage5Harness h, String topicId) =>
    _materialsForActor(h, 'target_teacher', topicId);

Future<List<Stage5Json>> _materialsForActor(
  _Stage5Harness h,
  String actor,
  String topicId,
) async {
  final response = await _expectSuccess(
    await h.api.actorRequest(
      actor,
      'GET',
      '/teacher/topics/$topicId/materials',
    ),
    200,
  );
  final envelope = stage5Map(response.data);
  _expectPublicProjection(envelope);
  final materials = stage5List(envelope['data']).map(stage5Map).toList();
  for (final material in materials) {
    expect(material.keys.toSet(), {
      'id',
      'topic_id',
      'title',
      'file',
      'created_at',
      'updated_at',
    });
    expect(material['topic_id'], topicId);
    expect(stage5Map(material['file']).keys.toSet(), {
      'id',
      'original_name',
      'mime_type',
      'extension',
      'size_bytes',
    });
  }
  return materials;
}

Future<Response<Object?>> _expectSuccess(
  Response<Object?> response,
  int status,
) async {
  expect(response.statusCode, status);
  expect(response.data, isA<Map<Object?, Object?>>());
  _expectPublicProjection(response.data);
  return response;
}

Future<void> _expectError(
  Response<Object?> response,
  int status,
  String code,
) async {
  expect(response.statusCode, status);
  final error = stage5Map(response.data);
  expect(error.keys.toSet(), {'message', 'code', 'errors'});
  expect(error['message'], isA<String>());
  expect((error['message']! as String).isNotEmpty, isTrue);
  expect(error['code'], code);
  expect(error['errors'], isA<Map<Object?, Object?>>());
  final serialized = jsonEncode(error).toLowerCase();
  for (final forbidden in [
    'storage_disk',
    'storage_key',
    'checksum_sha256',
    'private-files',
    'bearer ',
    'authorization',
    'stack trace',
    'exception',
    'sqlstate',
    'app\\',
    'e2e s05',
  ]) {
    expect(serialized, isNot(contains(forbidden)));
  }
  expect(
    RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    ).hasMatch(serialized),
    isFalse,
    reason: 'A privacy-safe error must not disclose a resource identity.',
  );
}

Stage5Json _data(Response<Object?> response) {
  final envelope = stage5Map(response.data);
  final data = stage5Map(envelope['data']);
  _expectPublicProjection(data);
  return data;
}

void _expectPublicProjection(Object? value) {
  const forbiddenKeys = {
    'storage_disk',
    'storage_key',
    'checksum_sha256',
    'path',
    'url',
    'signed_url',
    'password',
    'token',
  };
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();
      expect(forbiddenKeys, isNot(contains(key)));
      _expectPublicProjection(entry.value);
    }
  } else if (value is List) {
    for (final item in value) {
      _expectPublicProjection(item);
    }
  } else if (value is String) {
    final normalized = value.toLowerCase();
    expect(normalized, isNot(contains('learning-materials/')));
    expect(normalized, isNot(contains('private-files')));
  }
}

void _expectNoSensitiveRenderedText(WidgetTester tester) {
  final rendered = <String>[
    ...find
        .byType(Text)
        .evaluate()
        .map((element) => element.widget)
        .whereType<Text>()
        .map((widget) => widget.data ?? ''),
    ...find
        .byType(SelectableText)
        .evaluate()
        .map((element) => element.widget)
        .whereType<SelectableText>()
        .map((widget) => widget.data ?? ''),
  ].join(' | ').toLowerCase();
  for (final forbidden in [
    'storage_disk',
    'storage_key',
    'checksum_sha256',
    'learning-materials/',
    'private-files',
    'signed url',
  ]) {
    expect(rendered, isNot(contains(forbidden)));
  }
}

void _expectSameLifecycleWrite(Stage5Json before, Stage5Json after) {
  for (final field in [
    'id',
    'status',
    'updated_at',
    'activated_at',
    'closed_at',
    'archived_at',
  ]) {
    expect(after[field], before[field], reason: 'Idempotent field: $field');
  }
}

void _expectOriginalNames(List<Stage5Json> materials, List<String> expected) {
  expect(
    materials
        .map((material) => stage5Map(material['file'])['original_name'])
        .toList(),
    expected,
  );
}

void _expectMaterialsMatchFixtures(
  _Stage5Harness h,
  List<Stage5Json> materials,
) {
  const fixtureKeys = ['pdf', 'docx', 'ppt', 'pptx'];
  expect(materials, hasLength(fixtureKeys.length));
  for (var index = 0; index < fixtureKeys.length; index++) {
    final fixture = h.fixtures[fixtureKeys[index]];
    final file = stage5Map(materials[index]['file']);
    expect(file['original_name'], fixture.originalName);
    expect(file['extension'], fixture.extension);
    expect(file['mime_type'], fixture.mimeType);
    expect(file['size_bytes'], fixture.sizeBytes);
  }
}

Stage5Json _materialByOriginalName(
  List<Stage5Json> materials,
  String originalName,
) => materials.singleWhere(
  (material) => stage5Map(material['file'])['original_name'] == originalName,
);

Stage5Json _materialById(List<Stage5Json> materials, String materialId) =>
    materials.singleWhere((material) => material['id'] == materialId);

String _textForKey(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(Key(key)).last);
  if (widget is Text) return widget.data ?? '';
  if (widget is SelectableText) return widget.data ?? '';
  throw StateError('Expected a text-bearing Stage 5 widget for $key.');
}
