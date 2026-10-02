import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/config/app_config.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/files/local_file_actions.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';

import 'stage5_e2e_support.dart' show stage5Sha256;

/// Manifest-owned UI keys; the API scenarios use their own range, so the
/// ranges never meet.
String stage9Key(int number) =>
    '09000000-0000-4000-8000-${(9000000 + number).toString().padLeft(12, '0')}';

final stage9Uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

class Stage9Keys implements IdempotencyKeyGenerator {
  static const budget = 5;
  final List<String> issued = [];

  @override
  String generate() {
    if (issued.length >= budget) {
      throw StateError('Unexpected Stage 9 idempotency key request.');
    }
    final key = stage9Key(issued.length + 1);
    issued.add(key);
    return key;
  }
}

/// The one generated fixture: the PDF the Student submitted through the API.
class Stage9Fixture {
  const Stage9Fixture._({
    required this.file,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.sha256,
  });
  final File file;
  final String name;
  final String mimeType;
  final int size;
  final String sha256;

  static const key = 'answer_pdf';
  static const originalName = 'e2e_s09_answer.pdf';

  Future<Uint8List> verifiedBytes() async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError(
        'integration-harness defect: Stage 9 fixture must be a regular file.',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length != size || stage5Sha256(bytes) != sha256) {
      throw StateError(
        'integration-harness defect: Stage 9 fixture size/checksum changed.',
      );
    }
    return bytes;
  }

  static Future<Stage9Fixture> load(String path) async {
    final manifest = File(path).absolute;
    await stage9TempRoot(manifest.parent, 'fixtures');
    if (manifest.uri.pathSegments.last != 'fixture-manifest.json') {
      throw StateError(
        'integration-harness defect: Unexpected Stage 9 fixture manifest name.',
      );
    }
    final json = stage9Map(jsonDecode(await manifest.readAsString()));
    stage9ExactKeys(json, {'version', 'files'});
    if (json['version'] != 1) {
      throw StateError(
        'integration-harness defect: Invalid Stage 9 fixture version.',
      );
    }
    final rows = stage9Map(json['files']);
    stage9ExactKeys(rows, {key});
    final row = stage9Map(rows[key]);
    stage9ExactKeys(row, {
      'path',
      'original_name',
      'extension',
      'mime_type',
      'size_bytes',
      'sha256',
    });
    final filePath = row['path'];
    final sha256 = row['sha256'];
    final size = row['size_bytes'];
    if (filePath is! String ||
        sha256 is! String ||
        size is! int ||
        size <= 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw StateError(
        'integration-harness defect: Invalid Stage 9 fixture identity.',
      );
    }
    final file = File(filePath);
    if (!file.isAbsolute ||
        file.parent.path != manifest.parent.path ||
        file.uri.pathSegments.last != originalName ||
        row['original_name'] != originalName ||
        row['extension'] != 'pdf' ||
        row['mime_type'] != 'application/pdf') {
      throw StateError(
        'integration-harness defect: Invalid Stage 9 fixture identity.',
      );
    }
    final fixture = Stage9Fixture._(
      file: file,
      name: originalName,
      mimeType: 'application/pdf',
      size: size,
      sha256: sha256,
    );
    await fixture.verifiedBytes();
    return fixture;
  }
}

/// Runtime manifest written by the runner: the seeded ids plus the ids the
/// API setup created before the UI starts.
class Stage9Manifest {
  Stage9Manifest._(this._json);
  final Map<String, Object?> _json;

  static const _requiredIds = {
    'users': {'teacher', 'student', 'manual_student'},
    'topics': {'review', 'manual'},
    'assessments': {'review_hw', 'exception_blitz', 'manual_hw'},
  };
  static const _reviewQuestions = {'q1', 'q2', 'q3', 'q4', 'q5'};
  static const _reviewAnswers = {'q3', 'q4', 'q5'};
  static const _runtimeIds = {
    'review_attempt_id',
    'review_file_id',
    'exception_attempt_1_id',
    'manual_attempt_id',
  };

  static Future<Stage9Manifest> load(String path) async {
    final file = File(path).absolute;
    await stage9TempRoot(file.parent, 'evidence');
    if (file.uri.pathSegments.last != 'manifest.json') {
      throw StateError(
        'integration-harness defect: Unexpected Stage 9 manifest name.',
      );
    }
    final json = stage9Map(jsonDecode(await file.readAsString()));
    stage9ExactKeys(json, {
      'version',
      'users',
      'topics',
      'assessments',
      'questions',
      'runtime',
    });
    if (json['version'] != 1) {
      throw StateError(
        'integration-harness defect: Invalid Stage 9 manifest version.',
      );
    }
    for (final group in _requiredIds.entries) {
      _requireIds(stage9Map(json[group.key]), group.value);
    }
    final questions = stage9Map(json['questions']);
    for (final assessment in questions.values) {
      _requireIds(stage9Map(assessment), const {});
    }
    _requireIds(stage9Map(questions['review_hw']), _reviewQuestions);
    final runtime = stage9Map(json['runtime']);
    stage9ExactKeys(runtime, {..._runtimeIds, 'review_answer_ids'});
    final answers = stage9Map(runtime['review_answer_ids']);
    stage9ExactKeys(answers, _reviewAnswers);
    _requireIds(answers, _reviewAnswers);
    _requireIds({
      for (final name in _runtimeIds) name: runtime[name],
    }, _runtimeIds);
    return Stage9Manifest._(json);
  }

  /// [names] are present and every value is a lowercase canonical UUID.
  static void _requireIds(Map<String, Object?> group, Set<String> names) {
    if (!group.keys.toSet().containsAll(names) ||
        group.values.any(
          (value) => value is! String || !stage9Uuid.hasMatch(value),
        )) {
      throw StateError(
        'integration-harness defect: Invalid Stage 9 manifest ids.',
      );
    }
  }

  String _id(Object? group, String name) {
    final value = stage9Map(group)[name];
    if (value is! String || !stage9Uuid.hasMatch(value)) {
      throw StateError(
        'integration-harness defect: Stage 9 manifest lacks $name.',
      );
    }
    return value;
  }

  Map<String, Object?> get _runtime => stage9Map(_json['runtime']);

  String user(String name) => _id(_json['users'], name);
  String topic(String name) => _id(_json['topics'], name);
  String assessment(String name) => _id(_json['assessments'], name);
  String question(String assessment, String label) =>
      _id(stage9Map(_json['questions'])[assessment], label);

  String get reviewAttemptId => _id(_runtime, 'review_attempt_id');
  String reviewAnswerId(String label) =>
      _id(_runtime['review_answer_ids'], label);
  String get reviewFileId => _id(_runtime, 'review_file_id');
  String get exceptionAttempt1Id => _id(_runtime, 'exception_attempt_1_id');
  String get manualAttemptId => _id(_runtime, 'manual_attempt_id');
}

/// Native Save As sink: proves the Teacher's protected download delivered the
/// exact submitted bytes under the submitted name.
class Stage9FileSink implements LocalFilePlatformAdapter {
  Stage9FileSink(this.expected);
  final Stage9Fixture expected;
  int saveCount = 0;
  String? savedSha256;

  /// The first violation; the production controller swallows adapter errors,
  /// so the flow re-raises it through [verify].
  String? violation;

  void verify() {
    if (violation case final message?) {
      throw TestFailure(message);
    }
  }

  Never _reject(String message) {
    violation ??= message;
    throw TestFailure(message);
  }

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    _reject('Unexpected Stage 9 Open of file $fileId; only Save is expected.');
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String dialogTitle,
  }) async {
    if (dialogTitle != 'Save submitted file') {
      _reject('Stage 9 Save dialog title was "$dialogTitle".');
    }
    if (fileName != expected.name) {
      _reject('Stage 9 Save file name was "$fileName".');
    }
    if (mimeType != expected.mimeType) {
      _reject('Stage 9 Save MIME type was "$mimeType".');
    }
    final sha256 = stage5Sha256(bytes);
    if (bytes.length != expected.size || sha256 != expected.sha256) {
      _reject('Stage 9 saved bytes differ from the submitted fixture.');
    }
    saveCount++;
    savedSha256 = sha256;
    return Uri.file(r'C:\stage9-e2e\saved.pdf', windows: true);
  }
}

Future<void> stage9TempRoot(Directory root, String kind) async {
  if (!RegExp(
        '^testlabuz-stage9-$kind-[a-f0-9]{32}\$',
      ).hasMatch(root.uri.pathSegments.where((s) => s.isNotEmpty).last) ||
      !await root.exists() ||
      await FileSystemEntity.type(root.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      !await FileSystemEntity.identical(
        root.parent.path,
        Directory.systemTemp.path,
      )) {
    throw StateError(
      'integration-harness defect: Unsafe Stage 9 temporary directory identity.',
    );
  }
}

Map<String, Object?> stage9Map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected Stage 9 JSON object.');
  }
  return Map<String, Object?>.from(value);
}

void stage9ExactKeys(Map<String, Object?> value, Set<String> keys) {
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unexpected Stage 9 JSON keys.');
  }
}

class Stage9Harness {
  Stage9Harness._(this.tester, this.fixture, this.manifest, this.evidence)
    : keys = Stage9Keys(),
      sink = Stage9FileSink(fixture);

  final WidgetTester tester;
  final Stage9Fixture fixture;
  final Stage9Manifest manifest;
  final File evidence;
  final Stage9Keys keys;
  final Stage9FileSink sink;
  bool _signedIn = false;
  static const _tokenKey = 'auth_access_token';
  static const api = String.fromEnvironment('API_BASE_URL');

  static Future<Stage9Harness> create(WidgetTester tester) async {
    final uri = Uri.tryParse(api);
    final password = Platform.environment['STAGE9_E2E_PASSWORD'];
    final mode = Platform.environment['STAGE9_E2E_MODE'];
    if (!Platform.isWindows ||
        uri == null ||
        !RegExp(
          r'^http://127\.0\.0\.1:[1-9][0-9]{0,4}/api/v1$',
        ).hasMatch(api) ||
        uri.port > 65535 ||
        Platform.environment['STAGE9_E2E_API_BASE_URL'] != api ||
        password == null ||
        password.trim().length < 16 ||
        mode != 'main') {
      throw StateError(
        'environment/runtime defect: Stage 9 runner environment is invalid.',
      );
    }
    final evidencePath = Platform.environment['STAGE9_E2E_EVIDENCE_PATH'];
    final fixturePath = Platform.environment['STAGE9_E2E_FIXTURE_ROOT'];
    final manifestPath = Platform.environment['STAGE9_E2E_MANIFEST_PATH'];
    if (evidencePath == null || fixturePath == null || manifestPath == null) {
      throw StateError(
        'environment/runtime defect: Stage 9 runner paths are missing.',
      );
    }
    final evidence = File(evidencePath);
    if (!evidence.isAbsolute ||
        evidence.uri.pathSegments.last != 'ui-evidence.json') {
      throw StateError(
        'integration-harness defect: Stage 9 UI evidence path is invalid.',
      );
    }
    await stage9TempRoot(evidence.parent, 'evidence');
    if (await evidence.exists()) {
      throw StateError(
        'integration-harness defect: Stage 9 UI evidence already exists.',
      );
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return Stage9Harness._(
      tester,
      await Stage9Fixture.load(fixturePath),
      await Stage9Manifest.load(manifestPath),
      evidence,
    );
  }

  Future<void> launch() async {
    // Established integration cleanup of a stored token, never an injected session.
    await const FlutterSecureStorage().delete(key: _tokenKey);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.fromApiBaseUrl(api)),
          idempotencyKeyGeneratorProvider.overrideWithValue(keys),
          localFileActionsProvider.overrideWithValue(
            LocalFileActions(platform: sink),
          ),
        ],
        child: const TestLabUzApp(),
      ),
    );
    await waitRoute(AppRoutePaths.login);
  }

  /// Real production login UI; the password only travels from the runner environment.
  Future<void> signIn(String actor, {required bool teacher}) async {
    await waitRoute(AppRoutePaths.login);
    await enter(byKey('loginField'), 'e2e_s09_$actor');
    await enter(
      byKey('passwordField'),
      Platform.environment['STAGE9_E2E_PASSWORD']!,
    );
    await tap(byKey('signInButton'));
    await waitRoute(teacher ? AppRoutePaths.teacher : AppRoutePaths.student);
    await waitWidget(
      byKey(teacher ? 'teacherLearningWorkspace' : 'studentLearningWorkspace'),
      teacher ? 'Teacher workspace' : 'Student workspace',
    );
    _signedIn = true;
  }

  Future<void> signOut() async {
    if (!_signedIn) return;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TestLabUzApp)),
      listen: false,
    );
    await container.read(authSessionControllerProvider.notifier).signOut();
    await waitRoute(AppRoutePaths.login);
    _signedIn = false;
  }

  Future<void> close() async {
    try {
      await signOut();
    } finally {
      await const FlutterSecureStorage().delete(key: _tokenKey);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }

  Finder byKey(String key) => find.byKey(ValueKey(key));
  Finder within(Finder scope, Finder target) =>
      find.descendant(of: scope, matching: target);
  Finder textIn(Finder scope, String text) => within(scope, find.text(text));

  Uri get route => GoRouter.of(
    tester.element(find.byType(Scaffold).last),
  ).routeInformationProvider.value.uri;

  Future<void> go(String path) async {
    GoRouter.of(tester.element(find.byType(Scaffold).last)).go(path);
    await tester.pump();
    await waitRoute(path);
  }

  Future<void> waitRoute(String path) => until(
    () =>
        find.byType(Scaffold).evaluate().isNotEmpty && route.toString() == path,
    'canonical route $path',
  );

  Future<void> until(
    bool Function() condition,
    String state, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final clock = Stopwatch()..start();
    while (!condition()) {
      if (clock.elapsed >= timeout) {
        throw TestFailure('Timed out waiting for Stage 9 $state.');
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> waitWidget(Finder target, String state, {Duration? timeout}) =>
      until(
        () => target.evaluate().length == 1,
        state,
        timeout: timeout ?? const Duration(seconds: 45),
      );

  Future<void> ready(Finder target) async {
    await waitWidget(
      target,
      'unique control ${target.describeMatch(Plurality.one)}',
    );
    await tester.ensureVisible(target);
    await until(
      () =>
          target.evaluate().length == 1 &&
          _enabled(target.evaluate().single.widget) &&
          target.hitTestable().evaluate().length == 1,
      'enabled hit-testable control ${target.describeMatch(Plurality.one)}',
    );
  }

  Future<void> tap(Finder target) async {
    await ready(target);
    await tester.tap(target, warnIfMissed: true);
    await tester.pump();
  }

  Future<void> enter(Finder target, String value) async {
    await ready(target);
    await tester.tap(target);
    await tester.enterText(target, value);
    await tester.pump();
  }

  /// Opens a production dropdown and picks the visible item label from its
  /// open menu (the closed button already holds every label).
  Future<void> choose(Finder dropdown, String label) async {
    final item = find.text(label);
    final closed = item.evaluate().length;
    await tap(dropdown);
    await until(
      () => item.evaluate().length > closed,
      'open dropdown item $label',
    );
    await tester.ensureVisible(item.last);
    await tester.tap(item.last, warnIfMissed: true);
    await tester.pump();
    await pumpFor(const Duration(milliseconds: 400));
  }

  Future<void> pumpFor(Duration duration) async {
    final clock = Stopwatch()..start();
    while (clock.elapsed < duration) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String text(Finder target) {
    final widget = tester.widget(target);
    return switch (widget) {
      Text(:final data) => data ?? '',
      SelectableText(:final data) => data ?? '',
      _ => throw StateError('Stage 9 finder is not a Text widget.'),
    };
  }

  /// Every Text and SelectableText string under [scope], in tree order.
  List<String> texts(Finder scope) => [
    for (final element in within(
      scope,
      find.byWidgetPredicate(
        (widget) => widget is Text || widget is SelectableText,
      ),
    ).evaluate())
      switch (element.widget) {
        Text(:final data) => data ?? '',
        SelectableText(:final data) => data ?? '',
        _ => '',
      },
  ];

  /// Independent DB oracle round-trip: the runner judges the persisted state before the UI continues.
  Future<void> checkpoint(String name, Map<String, Object?> payload) async {
    final request = File('${evidence.parent.path}/checkpoint-$name.json');
    final ack = File('${evidence.parent.path}/checkpoint-$name.ack.json');
    if (await request.exists() || await ack.exists()) {
      throw StateError('Stage 9 checkpoint is not fresh.');
    }
    await writeJson(request, {'version': 1, 'checkpoint': name, ...payload});
    final clock = Stopwatch()..start();
    while (!await ack.exists()) {
      if (clock.elapsed > const Duration(minutes: 3)) {
        throw TestFailure(
          'Timed out waiting for independent Stage 9 $name oracle.',
        );
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    final reply = stage9Map(jsonDecode(await ack.readAsString()));
    stage9ExactKeys(reply, {'version', 'checkpoint', 'passed'});
    if (reply['version'] != 1 ||
        reply['checkpoint'] != name ||
        reply['passed'] != true) {
      throw TestFailure('Independent Stage 9 $name oracle failed.');
    }
  }

  Future<void> writeJson(File destination, Map<String, Object?> value) async {
    if (destination.parent.path != evidence.parent.path) {
      throw StateError('Stage 9 evidence escaped its temporary root.');
    }
    final pending = File('${destination.path}.pending');
    if (await pending.exists() || await destination.exists()) {
      throw StateError('Stage 9 evidence destination already exists.');
    }
    await pending.writeAsString(jsonEncode(value), flush: true);
    await pending.rename(destination.path);
  }
}

bool _enabled(Widget widget) => switch (widget) {
  ButtonStyleButton() => widget.onPressed != null,
  IconButton() => widget.onPressed != null,
  TextField() => widget.enabled != false && !widget.readOnly,
  TextFormField() => widget.enabled,
  InkWell() => widget.onTap != null,
  _ => true,
};
