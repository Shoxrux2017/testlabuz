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
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'stage5_e2e_support.dart' show stage5Sha256;

/// Manifest-owned UI keys; the API scenarios start at 60, so the ranges never meet.
String stage8Key(int number) =>
    '08000000-0000-4000-8000-${(9000000 + number).toString().padLeft(12, '0')}';

final stage8Uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

class Stage8Keys implements IdempotencyKeyGenerator {
  static const budget = 30;
  final List<String> issued = [];

  @override
  String generate() {
    if (issued.length >= budget) {
      throw StateError('Unexpected Stage 8 idempotency key request.');
    }
    final key = stage8Key(issued.length + 1);
    issued.add(key);
    return key;
  }
}

class Stage8Fixture {
  const Stage8Fixture({
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

  Future<Uint8List> verifiedBytes() async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Stage 8 fixture must be a regular file.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length != size || stage5Sha256(bytes) != sha256) {
      throw StateError('Stage 8 fixture size/checksum changed.');
    }
    return bytes;
  }
}

class Stage8Fixtures {
  Stage8Fixtures._(this.files);
  final Map<String, Stage8Fixture> files;
  Stage8Fixture operator [](String key) => files[key]!;

  static const names = {
    'answer_pdf': 'e2e_s08_answer.pdf',
    'replacement_docx': 'e2e_s08_replacement.docx',
    'replacement_pptx': 'e2e_s08_replacement.pptx',
    'fake_pdf': 'e2e_s08_fake.pdf',
  };

  static Future<Stage8Fixtures> load(String path) async {
    final manifest = File(path).absolute;
    await stage8TempRoot(manifest.parent, 'fixtures');
    if (manifest.uri.pathSegments.last != 'fixture-manifest.json') {
      throw StateError('Unexpected Stage 8 fixture manifest name.');
    }
    final json = stage8Map(jsonDecode(await manifest.readAsString()));
    stage8ExactKeys(json, {'version', 'files'});
    if (json['version'] != 1) throw StateError('Invalid fixture version.');
    final rows = stage8Map(json['files']);
    stage8ExactKeys(rows, names.keys.toSet());
    final result = <String, Stage8Fixture>{};
    for (final entry in names.entries) {
      final row = stage8Map(rows[entry.key]);
      stage8ExactKeys(row, {
        'path',
        'original_name',
        'extension',
        'mime_type',
        'size_bytes',
        'sha256',
      });
      final file = File(row['path'] as String);
      if (!file.isAbsolute ||
          file.parent.path != manifest.parent.path ||
          file.uri.pathSegments.last != entry.value ||
          row['original_name'] != entry.value ||
          row['size_bytes'] is! int ||
          (row['size_bytes'] as int) <= 0 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(row['sha256'] as String)) {
        throw StateError('Invalid Stage 8 fixture identity.');
      }
      final fixture = Stage8Fixture(
        file: file,
        name: entry.value,
        mimeType: row['mime_type'] as String,
        size: row['size_bytes'] as int,
        sha256: row['sha256'] as String,
      );
      await fixture.verifiedBytes();
      result[entry.key] = fixture;
    }
    return Stage8Fixtures._(Map.unmodifiable(result));
  }
}

/// Stage 8 manifest written by the runner from the seeded baseline.
class Stage8Manifest {
  Stage8Manifest._(this.json);
  final Map<String, Object?> json;

  static Future<Stage8Manifest> load(String path) async {
    final file = File(path).absolute;
    await stage8TempRoot(file.parent, 'evidence');
    if (file.uri.pathSegments.last != 'manifest.json') {
      throw StateError('Unexpected Stage 8 manifest name.');
    }
    return Stage8Manifest._(stage8Map(jsonDecode(await file.readAsString())));
  }

  String _id(String group, String name) {
    final value = stage8Map(json[group])[name];
    if (value is! String || !stage8Uuid.hasMatch(value)) {
      throw StateError('Stage 8 manifest lacks $group.$name.');
    }
    return value;
  }

  String user(String name) => _id('users', name);
  String topic(String name) => _id('topics', name);
  String assessment(String name) => _id('assessments', name);

  String question(String assessment, String label) {
    final value = stage8Map(stage8Map(json['questions'])[assessment])[label];
    if (value is! String) {
      throw StateError('Stage 8 manifest lacks a Question.');
    }
    return value;
  }

  Object? nested(String assessment, String label) =>
      stage8Map(stage8Map(json['nested'])[assessment])[label];
}

class Stage8Picker implements StudentSubmissionFilePicker {
  Stage8Picker(this.fixtures);
  final Stage8Fixtures fixtures;
  final List<String> queue = ['answer_pdf'];
  int consumed = 0;

  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) async {
    if (consumed >= queue.length ||
        allowedExtensions.toSet().length != 4 ||
        !allowedExtensions.toSet().containsAll({
          'pdf',
          'docx',
          'ppt',
          'pptx',
        })) {
      throw StateError('Unexpected Stage 8 native picker call.');
    }
    final fixture = fixtures[queue[consumed++]];
    await fixture.verifiedBytes();
    return StudentSubmissionUploadFile(
      name: fixture.name,
      length: fixture.size,
      openRead: () async* {
        await fixture.verifiedBytes();
        yield* fixture.file.openRead();
      },
    );
  }
}

/// Native Open/Save As sink: proves the protected transfer delivered the exact bytes.
class Stage8FileSink implements LocalFilePlatformAdapter {
  Stage8FileSink(this.root, this.expected);
  final Directory root;
  final Stage8Fixture expected;
  String? expectedFileId;
  int openCount = 0;
  int saveCount = 0;

  Future<void> _verify(Uint8List bytes, String mimeType) async {
    expect(mimeType, expected.mimeType);
    expect(bytes, orderedEquals(await expected.verifiedBytes()));
  }

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    expect(fileId, expectedFileId);
    expect(extension, 'pdf');
    await _verify(bytes, mimeType);
    await File(
      '${root.path}/sink-open-$fileId.pdf',
    ).writeAsBytes(bytes, flush: true);
    openCount++;
    return LocalFileOpenOutcome.opened;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String dialogTitle,
  }) async {
    expect(fileName, expected.name);
    expect(dialogTitle, 'Save submitted answer');
    await _verify(bytes, mimeType);
    final file = File('${root.path}/sink-save-${expected.name}');
    await file.writeAsBytes(bytes, flush: true);
    saveCount++;
    return file.uri;
  }
}

Future<void> stage8TempRoot(Directory root, String kind) async {
  if (!RegExp(
        '^testlabuz-stage8-$kind-[a-f0-9]{32}\$',
      ).hasMatch(root.uri.pathSegments.where((s) => s.isNotEmpty).last) ||
      !await root.exists() ||
      await FileSystemEntity.type(root.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      !await FileSystemEntity.identical(
        root.parent.path,
        Directory.systemTemp.path,
      )) {
    throw StateError('Unsafe Stage 8 temporary directory identity.');
  }
}

Map<String, Object?> stage8Map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected Stage 8 JSON object.');
  }
  return Map<String, Object?>.from(value);
}

void stage8ExactKeys(Map<String, Object?> value, Set<String> keys) {
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unexpected Stage 8 JSON keys.');
  }
}

class Stage8Harness {
  Stage8Harness._(this.tester, this.fixtures, this.manifest, this.evidence)
    : keys = Stage8Keys(),
      picker = Stage8Picker(fixtures),
      sink = Stage8FileSink(evidence.parent, fixtures['answer_pdf']);

  final WidgetTester tester;
  final Stage8Fixtures fixtures;
  final Stage8Manifest manifest;
  final File evidence;
  final Stage8Keys keys;
  final Stage8Picker picker;
  final Stage8FileSink sink;
  bool _signedIn = false;
  static const _tokenKey = 'auth_access_token';
  static const api = String.fromEnvironment('API_BASE_URL');

  static Future<Stage8Harness> create(WidgetTester tester) async {
    final uri = Uri.tryParse(api);
    final password = Platform.environment['STAGE8_E2E_PASSWORD'];
    final mode = Platform.environment['STAGE8_E2E_MODE'];
    if (!Platform.isWindows ||
        uri == null ||
        !RegExp(
          r'^http://127\.0\.0\.1:[1-9][0-9]{0,4}/api/v1$',
        ).hasMatch(api) ||
        uri.port > 65535 ||
        password == null ||
        password.trim().length < 16 ||
        mode != 'main') {
      throw StateError('Stage 8 runner environment is invalid.');
    }
    final evidencePath = Platform.environment['STAGE8_E2E_EVIDENCE_PATH'];
    final fixturePath = Platform.environment['STAGE8_E2E_FIXTURE_ROOT'];
    final manifestPath = Platform.environment['STAGE8_E2E_MANIFEST_PATH'];
    if (evidencePath == null || fixturePath == null || manifestPath == null) {
      throw StateError('Stage 8 runner paths are missing.');
    }
    final evidence = File(evidencePath);
    if (!evidence.isAbsolute ||
        evidence.uri.pathSegments.last != 'ui-evidence.json') {
      throw StateError('Stage 8 UI evidence path is invalid.');
    }
    await stage8TempRoot(evidence.parent, 'evidence');
    if (await evidence.exists()) {
      throw StateError('Stage 8 UI evidence already exists.');
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return Stage8Harness._(
      tester,
      await Stage8Fixtures.load(fixturePath),
      await Stage8Manifest.load(manifestPath),
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
          studentSubmissionFilePickerProvider.overrideWithValue(picker),
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
    await enter(byKey('loginField'), 'e2e_s08_$actor');
    await enter(
      byKey('passwordField'),
      Platform.environment['STAGE8_E2E_PASSWORD']!,
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
        throw TestFailure('Timed out waiting for Stage 8 $state.');
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

  Future<void> tapText(String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target, warnIfMissed: true);
    await tester.pump();
  }

  Future<void> enter(Finder target, String value) async {
    await ready(target);
    await tester.tap(target);
    await tester.enterText(target, value);
    await tester.pump();
  }

  /// Opens a production dropdown and picks the visible item label.
  Future<void> choose(Finder dropdown, String label) async {
    await tap(dropdown);
    await until(
      () => find.text(label).evaluate().isNotEmpty,
      'dropdown item $label',
    );
    await tapText(label);
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
      _ => throw StateError('Stage 8 finder is not a Text widget.'),
    };
  }

  /// Independent DB oracle round-trip: the runner judges the persisted state before the UI continues.
  Future<void> checkpoint(String name, Map<String, Object?> payload) async {
    final request = File('${evidence.parent.path}/checkpoint-$name.json');
    final ack = File('${evidence.parent.path}/checkpoint-$name.ack.json');
    if (await request.exists() || await ack.exists()) {
      throw StateError('Stage 8 checkpoint is not fresh.');
    }
    await writeJson(request, {'version': 1, 'checkpoint': name, ...payload});
    final clock = Stopwatch()..start();
    while (!await ack.exists()) {
      if (clock.elapsed > const Duration(minutes: 3)) {
        throw TestFailure(
          'Timed out waiting for independent Stage 8 $name oracle.',
        );
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    final reply = stage8Map(jsonDecode(await ack.readAsString()));
    stage8ExactKeys(reply, {'version', 'checkpoint', 'passed'});
    if (reply['version'] != 1 ||
        reply['checkpoint'] != name ||
        reply['passed'] != true) {
      throw TestFailure('Independent Stage 8 $name oracle failed.');
    }
  }

  Future<void> writeJson(File destination, Map<String, Object?> value) async {
    if (destination.parent.path != evidence.parent.path) {
      throw StateError('Stage 8 evidence escaped its temporary root.');
    }
    final pending = File('${destination.path}.pending');
    if (await pending.exists() || await destination.exists()) {
      throw StateError('Stage 8 evidence destination already exists.');
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
  RadioListTile<bool>() => widget.enabled != false,
  DropdownButton<String>() => widget.onChanged != null,
  DropdownButton<int>() => widget.onChanged != null,
  InkWell() => widget.onTap != null,
  _ => true,
};
