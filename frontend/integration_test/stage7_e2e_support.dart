import 'dart:async';
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
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'stage5_e2e_support.dart' show stage5Sha256;

String stage7Id(int suffix) =>
    '07000000-0000-4000-8000-${suffix.toString().padLeft(12, '0')}';

const stage7UiKeys = [
  '07111111-1111-4111-8111-111111111111',
  '07222222-2222-4222-8222-222222222222',
  '07333333-3333-4333-8333-333333333333',
  '07444444-4444-4444-8444-444444444444',
  '07555555-5555-4555-8555-555555555555',
  '07666666-6666-4666-8666-666666666666',
];
const stage7ShortAnswer = 'O‘zbekiston — E2E S07';
const stage7OpenAnswer = "E2E S07 first line\nStudent's second line";
const stage7BlankAnswer = 'E2E S07 partial blank';

final stage7Uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class Stage7Keys implements IdempotencyKeyGenerator {
  Stage7Keys({required this.readOnly});
  final bool readOnly;
  int consumed = 0;

  @override
  String generate() {
    if (readOnly || consumed >= stage7UiKeys.length) {
      throw StateError('Unexpected Stage 7 Start/Submit key request.');
    }
    return stage7UiKeys[consumed++];
  }
}

class Stage7Fixture {
  const Stage7Fixture({
    required this.file,
    required this.name,
    required this.extension,
    required this.mimeType,
    required this.size,
    required this.sha256,
  });
  final File file;
  final String name;
  final String extension;
  final String mimeType;
  final int size;
  final String sha256;

  Future<Uint8List> verifiedBytes() async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Stage 7 fixture must be a regular file.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length != size || stage5Sha256(bytes) != sha256) {
      throw StateError('Stage 7 fixture size/checksum changed.');
    }
    return bytes;
  }
}

class Stage7Fixtures {
  Stage7Fixtures._(this.files);
  final Map<String, Stage7Fixture> files;
  Stage7Fixture operator [](String key) => files[key]!;

  static const names = {
    'valid_pdf': 'e2e_s07_answer.pdf',
    'replacement_pptx': 'e2e_s07_replacement.pptx',
    'fake_pdf': 'e2e_s07_fake.pdf',
    'over_limit_pdf': 'e2e_s07_over_limit.pdf',
  };

  static Future<Stage7Fixtures> load(String path) async {
    final manifest = File(path).absolute;
    await stage7TempRoot(manifest.parent, 'fixtures');
    if (manifest.uri.pathSegments.last != 'fixture-manifest.json') {
      throw StateError('Unexpected Stage 7 fixture manifest name.');
    }
    final json = stage7Map(jsonDecode(await manifest.readAsString()));
    stage7ExactKeys(json, {'version', 'files'});
    if (json['version'] != 1) throw StateError('Invalid fixture version.');
    final rows = stage7Map(json['files']);
    stage7ExactKeys(rows, names.keys.toSet());
    final result = <String, Stage7Fixture>{};
    for (final entry in names.entries) {
      final row = stage7Map(rows[entry.key]);
      stage7ExactKeys(row, {
        'path',
        'original_name',
        'extension',
        'mime_type',
        'size_bytes',
        'sha256',
      });
      final file = File(row['path'] as String);
      final extension = entry.value.split('.').last;
      final expectedMime = extension == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      if (!file.isAbsolute ||
          file.parent.path != manifest.parent.path ||
          file.uri.pathSegments.last != entry.value ||
          row['original_name'] != entry.value ||
          row['extension'] != extension ||
          row['mime_type'] != expectedMime ||
          row['size_bytes'] is! int ||
          (row['size_bytes'] as int) <= 0 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(row['sha256'] as String)) {
        throw StateError('Invalid Stage 7 fixture identity.');
      }
      final fixture = Stage7Fixture(
        file: file,
        name: entry.value,
        extension: extension,
        mimeType: expectedMime,
        size: row['size_bytes'] as int,
        sha256: row['sha256'] as String,
      );
      await fixture.verifiedBytes();
      if ((entry.key == 'over_limit_pdf') != (fixture.size > 2 * 1024 * 1024)) {
        throw StateError('Invalid Stage 7 fixture size boundary.');
      }
      result[entry.key] = fixture;
    }
    return Stage7Fixtures._(Map.unmodifiable(result));
  }
}

class Stage7Picker implements StudentSubmissionFilePicker {
  Stage7Picker(this.fixtures, {required this.readOnly});
  final Stage7Fixtures fixtures;
  final bool readOnly;
  static const queue = ['fake_pdf', 'valid_pdf', 'replacement_pptx'];
  int consumed = 0;
  Completer<void>? _readGate;

  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) async {
    if (readOnly ||
        consumed >= queue.length ||
        allowedExtensions.toSet().length != 4 ||
        !allowedExtensions.toSet().containsAll({
          'pdf',
          'docx',
          'ppt',
          'pptx',
        })) {
      throw StateError('Unexpected Stage 7 native picker call.');
    }
    releaseRead();
    final fixture = fixtures[queue[consumed++]];
    await fixture.verifiedBytes();
    final gate = Completer<void>();
    _readGate = gate;
    return StudentSubmissionUploadFile(
      name: fixture.name,
      length: fixture.size,
      openRead: () async* {
        // Hold only the native source until the production progress UI renders.
        await gate.future;
        await fixture.verifiedBytes();
        yield* fixture.file.openRead();
      },
    );
  }

  void releaseRead() {
    final gate = _readGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

class Stage7FileSink implements LocalFilePlatformAdapter {
  Stage7FileSink(this.root, this.replacement);
  final Directory root;
  final Stage7Fixture replacement;
  String? expectedFileId;
  int openCount = 0;
  int saveCount = 0;

  Future<void> _verify(Uint8List bytes, String mimeType) async {
    expect(mimeType, replacement.mimeType);
    expect(bytes, orderedEquals(await replacement.verifiedBytes()));
  }

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    expect(fileId, expectedFileId);
    expect(stage7Uuid.hasMatch(fileId), isTrue);
    expect(extension, 'pptx');
    await _verify(bytes, mimeType);
    await File(
      '${root.path}/sink-open-$fileId.pptx',
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
    expect(fileName, replacement.name);
    expect(dialogTitle, 'Save submitted answer');
    await _verify(bytes, mimeType);
    final file = File('${root.path}/sink-save-${replacement.name}');
    await file.writeAsBytes(bytes, flush: true);
    saveCount++;
    return file.uri;
  }
}

Future<void> stage7TempRoot(Directory root, String kind) async {
  if (!RegExp(
        '^testlabuz-stage7-$kind-[a-f0-9]{32}\$',
      ).hasMatch(root.uri.pathSegments.where((s) => s.isNotEmpty).last) ||
      !await root.exists() ||
      await FileSystemEntity.type(root.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      !await FileSystemEntity.identical(
        root.parent.path,
        Directory.systemTemp.path,
      )) {
    throw StateError('Unsafe Stage 7 temporary directory identity.');
  }
}

Map<String, Object?> stage7Map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected Stage 7 JSON object.');
  }
  return Map<String, Object?>.from(value);
}

void stage7ExactKeys(Map<String, Object?> value, Set<String> keys) {
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unexpected Stage 7 JSON keys.');
  }
}

class Stage7Harness {
  Stage7Harness._(this.tester, this.fixtures, this.evidence, this.readOnly)
    : keys = Stage7Keys(readOnly: readOnly),
      picker = Stage7Picker(fixtures, readOnly: readOnly),
      sink = Stage7FileSink(evidence.parent, fixtures['replacement_pptx']);

  final WidgetTester tester;
  final Stage7Fixtures fixtures;
  final File evidence;
  final bool readOnly;
  final Stage7Keys keys;
  final Stage7Picker picker;
  final Stage7FileSink sink;
  bool _loggedIn = false;
  static const _tokenKey = 'auth_access_token';
  static const api = String.fromEnvironment('API_BASE_URL');

  static Future<Stage7Harness> create(WidgetTester tester) async {
    final uri = Uri.tryParse(api);
    final password = Platform.environment['STAGE7_E2E_PASSWORD'];
    final mode = Platform.environment['STAGE7_E2E_MODE'] ?? 'main';
    if (!Platform.isWindows ||
        uri == null ||
        !RegExp(
          r'^http://127\.0\.0\.1:[1-9][0-9]{0,4}/api/v1$',
        ).hasMatch(api) ||
        uri.port > 65535 ||
        password == null ||
        password.trim().length < 24 ||
        !{'main', 'post_restart'}.contains(mode)) {
      throw StateError('Stage 7 runner environment is invalid.');
    }
    final evidencePath = Platform.environment['STAGE7_E2E_UI_EVIDENCE_PATH'];
    final manifest = Platform.environment['STAGE7_E2E_FIXTURE_MANIFEST_PATH'];
    if (evidencePath == null || manifest == null) {
      throw StateError('Stage 7 runner paths are missing.');
    }
    final evidence = File(evidencePath);
    if (!evidence.isAbsolute ||
        evidence.uri.pathSegments.last != 'ui-evidence.json') {
      throw StateError('Stage 7 UI evidence path is invalid.');
    }
    await stage7TempRoot(evidence.parent, 'evidence');
    if (mode == 'main' && await evidence.exists()) {
      throw StateError('Stage 7 UI evidence already exists.');
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return Stage7Harness._(
      tester,
      await Stage7Fixtures.load(manifest),
      evidence,
      mode == 'post_restart',
    );
  }

  Future<void> launchAndLogin() async {
    // This is the established integration cleanup, never an injected session.
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
    await enter(byKey('loginField'), 'e2e_s07_student');
    await enter(
      byKey('passwordField'),
      Platform.environment['STAGE7_E2E_PASSWORD']!,
    );
    await tap(byKey('signInButton'));
    await waitRoute(AppRoutePaths.student);
    await waitWidget(byKey('studentLearningWorkspace'), 'Student workspace');
    _loggedIn = true;
  }

  Future<void> close() async {
    picker.releaseRead();
    try {
      if (_loggedIn) {
        await go(AppRoutePaths.student);
        await tap(byKey('entryLogoutButton'));
        await waitRoute(AppRoutePaths.login);
        _loggedIn = false;
      }
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
        throw TestFailure('Timed out waiting for Stage 7 $state.');
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> waitWidget(Finder target, String state) =>
      until(() => target.evaluate().length == 1, state);

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

  Future<void> select<T>(Finder dropdown, T value) async {
    await tap(dropdown);
    final item = find
        .byWidgetPredicate(
          (widget) => widget is DropdownMenuItem<T> && widget.value == value,
        )
        .hitTestable();
    await tap(item);
    await until(
      () => tester.widget<DropdownButton<T>>(dropdown).value == value,
      'selected value for ${dropdown.describeMatch(Plurality.one)}',
    );
  }

  Future<void> checkpoint(
    String name,
    String attemptId, {
    String? fileId,
  }) async {
    if (!{
          'first_start',
          'fake_file_rejected',
          'first_file_uploaded',
          'file_replaced',
        }.contains(name) ||
        !stage7Uuid.hasMatch(attemptId) ||
        (fileId != null && !stage7Uuid.hasMatch(fileId))) {
      throw StateError('Invalid Stage 7 checkpoint identity.');
    }
    final request = File('${evidence.parent.path}/checkpoint-$name.json');
    final ack = File('${evidence.parent.path}/checkpoint-$name.ack.json');
    if (await request.exists() || await ack.exists()) {
      throw StateError('Stage 7 checkpoint is not fresh.');
    }
    await writeJson(request, {
      'version': 1,
      'checkpoint': name,
      'attempt_id': attemptId,
      'file_id': fileId,
    });
    final clock = Stopwatch()..start();
    while (!await ack.exists()) {
      if (clock.elapsed > const Duration(minutes: 2)) {
        throw TestFailure(
          'Timed out waiting for independent Stage 7 $name oracle.',
        );
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    final reply = stage7Map(jsonDecode(await ack.readAsString()));
    stage7ExactKeys(reply, {'version', 'checkpoint', 'passed'});
    if (reply['version'] != 1 ||
        reply['checkpoint'] != name ||
        reply['passed'] != true) {
      throw TestFailure('Independent Stage 7 $name oracle failed.');
    }
  }

  Future<void> writeJson(File destination, Map<String, Object?> value) async {
    if (destination.parent.path != evidence.parent.path) {
      throw StateError('Stage 7 evidence escaped its temporary root.');
    }
    final pending = File('${destination.path}.pending');
    if (await pending.exists() || await destination.exists()) {
      throw StateError('Stage 7 evidence destination already exists.');
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
  CheckboxListTile() => widget.onChanged != null,
  RadioListTile<String>() => widget.enabled != false,
  RadioListTile<bool>() => widget.enabled != false,
  DropdownButton<String>() => widget.onChanged != null,
  DropdownButton<int>() => widget.onChanged != null,
  DropdownMenuItem<String>() => widget.enabled,
  DropdownMenuItem<int>() => widget.enabled,
  InkWell() => widget.onTap != null,
  _ => true,
};
