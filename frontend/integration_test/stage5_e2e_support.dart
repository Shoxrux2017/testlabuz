import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:testlabuz_client/core/files/local_file_actions.dart';
import 'package:testlabuz_client/core/files/protected_download_metadata.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_file_picker.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material_mutation.dart';

typedef Stage5Json = Map<String, Object?>;

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final _shaPattern = RegExp(r'^[a-f0-9]{64}$');

class Stage5Fixture {
  const Stage5Fixture({
    required this.key,
    required this.path,
    required this.originalName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
  });

  final String key;
  final String path;
  final String originalName;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
}

class Stage5FixtureManifest {
  Stage5FixtureManifest._(this.path, this.root, this.files);

  static const requiredKeys = {
    'pdf',
    'docx',
    'ppt',
    'pptx',
    'replacement_pdf',
    'unsupported',
    'low_limit_over',
    'platform_over',
  };

  final String path;
  final String root;
  final Map<String, Stage5Fixture> files;

  static Future<Stage5FixtureManifest> load(String manifestPath) async {
    final manifestFile = File(manifestPath);
    final resolvedPath = manifestFile.absolute.path;
    final tempRoot = Directory.systemTemp.absolute.path;
    if (!resolvedPath.startsWith('$tempRoot${Platform.pathSeparator}') ||
        !resolvedPath.endsWith(
          '${Platform.pathSeparator}fixture-manifest.json',
        )) {
      throw StateError('The Stage 5 fixture manifest path is unsafe.');
    }
    final root = manifestFile.parent.absolute.path;
    if (!RegExp(r'testlabuz-stage5-fixtures-[a-f0-9]{32}$').hasMatch(root)) {
      throw StateError('The Stage 5 fixture root identity is unsafe.');
    }
    final decoded = _map(jsonDecode(await manifestFile.readAsString()));
    _exactKeys(decoded, {'version', 'files'});
    if (decoded['version'] != 1) {
      throw const FormatException('Unsupported Stage 5 fixture version.');
    }
    final rawFiles = _map(decoded['files']);
    _exactKeys(rawFiles, requiredKeys);
    final files = <String, Stage5Fixture>{};
    for (final key in requiredKeys) {
      final raw = _map(rawFiles[key]);
      _exactKeys(raw, {
        'path',
        'original_name',
        'extension',
        'mime_type',
        'size_bytes',
        'sha256',
      });
      final path = _string(raw, 'path');
      final file = File(path);
      if (!file.isAbsolute ||
          file.parent.absolute.path != root ||
          path != file.absolute.path) {
        throw StateError('A Stage 5 fixture path escaped its exact root.');
      }
      final fixture = Stage5Fixture(
        key: key,
        path: path,
        originalName: _string(raw, 'original_name'),
        extension: _string(raw, 'extension'),
        mimeType: _string(raw, 'mime_type'),
        sizeBytes: _integer(raw, 'size_bytes'),
        sha256: _string(raw, 'sha256'),
      );
      await _validateFixture(fixture);
      files[key] = fixture;
    }
    if (files['low_limit_over']!.sizeBytes != 1_048_577 ||
        files['platform_over']!.sizeBytes != 26_214_401) {
      throw StateError('The Stage 5 oversized fixture lengths are invalid.');
    }
    return Stage5FixtureManifest._(resolvedPath, root, Map.unmodifiable(files));
  }

  Stage5Fixture operator [](String key) {
    final fixture = files[key];
    if (fixture == null) throw StateError('Unknown Stage 5 fixture key.');
    return fixture;
  }

  static Future<void> _validateFixture(Stage5Fixture fixture) async {
    final file = File(fixture.path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size != fixture.sizeBytes ||
        fixture.originalName != file.uri.pathSegments.last ||
        fixture.extension !=
            fixture.originalName.substring(
              fixture.originalName.lastIndexOf('.') + 1,
            ) ||
        !_shaPattern.hasMatch(fixture.sha256)) {
      throw StateError('A Stage 5 fixture manifest record is invalid.');
    }
    final bytes = await file.readAsBytes();
    if (stage5Sha256(bytes) != fixture.sha256) {
      throw StateError('A Stage 5 fixture checksum is invalid.');
    }
  }
}

class Stage5Oracle {
  Stage5Oracle._({
    required this.logins,
    required this.ids,
    required this.seededSha256,
    required this.dynamic,
  });

  static const loginKeys = {
    'target_admin',
    'target_teacher',
    'target_student',
    'ended_student',
    'unrelated_teacher',
    'unrelated_student',
    'low_limit_admin',
    'low_limit_teacher',
    'foreign_admin',
    'foreign_teacher',
    'foreign_student',
  };
  static const idKeys = {
    'target_institution',
    'low_limit_institution',
    'foreign_institution',
    ...loginKeys,
    'group_a',
    'group_b',
    'group_c',
    'low_limit_group',
    'foreign_group',
    'seeded_target_topic',
    'seeded_draft_topic',
    'unrelated_topic',
    'archived_group_topic',
    'low_limit_topic',
    'foreign_topic',
    'seeded_target_material',
    'unrelated_material',
    'archived_group_material',
    'foreign_material',
    'seeded_target_file',
    'unrelated_file',
    'archived_group_file',
    'foreign_file',
  };

  final Map<String, String> logins;
  final Map<String, String> ids;
  final Map<String, String> seededSha256;
  final Stage5Json? dynamic;

  static Future<Stage5Oracle> load(String path, {required bool dynamic}) async {
    final file = File(path);
    final resolved = file.absolute.path;
    if (!resolved.startsWith(
          '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
        ) ||
        !RegExp(
          r'testlabuz-stage5-oracle-[a-f0-9]{32}\.json$',
        ).hasMatch(resolved)) {
      throw StateError('The Stage 5 oracle path is unsafe.');
    }
    final raw = _map(jsonDecode(await file.readAsString()));
    _exactKeys(
      raw,
      dynamic
          ? {'version', 'logins', 'ids', 'seeded_sha256', 'dynamic'}
          : {'version', 'logins', 'ids', 'seeded_sha256'},
    );
    if (raw['version'] != 1) {
      throw const FormatException('Unsupported Stage 5 oracle version.');
    }
    final logins = _stringMap(raw['logins'], loginKeys, 'logins');
    final ids = _stringMap(raw['ids'], idKeys, 'ids');
    for (final id in ids.values) {
      if (!_uuidPattern.hasMatch(id)) {
        throw const FormatException('A Stage 5 oracle UUID is invalid.');
      }
    }
    for (final login in logins.values) {
      if (!login.startsWith('e2e_s05_')) {
        throw const FormatException('A Stage 5 oracle login is invalid.');
      }
    }
    final seeded = _stringMap(raw['seeded_sha256'], {
      'target_file',
    }, 'seeded_sha256');
    if (!_shaPattern.hasMatch(seeded['target_file']!)) {
      throw const FormatException('The seeded Stage 5 checksum is invalid.');
    }
    final dynamicBlock = dynamic ? _map(raw['dynamic']) : null;
    if (dynamicBlock != null) {
      _exactKeys(dynamicBlock, {
        'topic_id',
        'status',
        'replacement_material_id',
        'replacement_file_id',
        'replacement_sha256',
        'removed_material_id',
        'removed_file_id',
        'remaining_material_ids',
      });
      for (final key in [
        'topic_id',
        'replacement_material_id',
        'replacement_file_id',
        'removed_material_id',
        'removed_file_id',
      ]) {
        if (!_uuidPattern.hasMatch(_string(dynamicBlock, key))) {
          throw const FormatException('A dynamic Stage 5 UUID is invalid.');
        }
      }
      if (dynamicBlock['status'] != 'archived' ||
          !_shaPattern.hasMatch(_string(dynamicBlock, 'replacement_sha256'))) {
        throw const FormatException('Dynamic Stage 5 state is invalid.');
      }
      final remaining = _list(dynamicBlock['remaining_material_ids']);
      if (remaining.length != 3 ||
          remaining.any(
            (value) => value is! String || !_uuidPattern.hasMatch(value),
          )) {
        throw const FormatException(
          'Dynamic Stage 5 remaining material IDs are invalid.',
        );
      }
    }
    return Stage5Oracle._(
      logins: logins,
      ids: ids,
      seededSha256: seeded,
      dynamic: dynamicBlock,
    );
  }
}

class Stage5TestPicker implements TeacherMaterialFilePicker {
  Stage5TestPicker(this.manifest)
    : _queue = [
        manifest['pdf'],
        manifest['docx'],
        manifest['ppt'],
        manifest['pptx'],
        manifest['replacement_pdf'],
      ];

  final Stage5FixtureManifest manifest;
  final List<Stage5Fixture> _queue;
  var _index = 0;

  int get consumed => _index;

  @override
  Future<TeacherMaterialUploadFile?> pickFile() async {
    if (_index >= _queue.length) {
      throw StateError('The Stage 5 picker received an unexpected call.');
    }
    final fixture = _queue[_index++];
    await Stage5FixtureManifest._validateFixture(fixture);
    if (File(fixture.path).parent.absolute.path != manifest.root) {
      throw StateError('The Stage 5 picker fixture escaped its root.');
    }
    return TeacherMaterialUploadFile(
      name: fixture.originalName,
      length: fixture.sizeBytes,
      openRead: () => File(fixture.path).openRead(),
    );
  }

  void assertComplete() {
    if (_index != _queue.length) {
      throw StateError('The Stage 5 picker queue was not fully consumed.');
    }
  }
}

class Stage5FileSinkRecord {
  const Stage5FileSinkRecord({
    required this.operation,
    required this.fileId,
    required this.filename,
    required this.mimeType,
    required this.extension,
    required this.sizeBytes,
    required this.sha256,
    required this.path,
  });

  final String operation;
  final String? fileId;
  final String filename;
  final String mimeType;
  final String extension;
  final int sizeBytes;
  final String sha256;
  final String path;
}

class Stage5LocalFileAdapter implements LocalFilePlatformAdapter {
  Stage5LocalFileAdapter._(this.root, this._sequence);

  final Directory root;
  final List<Stage5FileSinkRecord> records = [];
  int _sequence;

  static Future<Stage5LocalFileAdapter> create(
    String path, {
    bool requireEmpty = true,
  }) async {
    final root = Directory(path).absolute;
    if (!root.path.startsWith(
          '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
        ) ||
        !RegExp(r'testlabuz-stage5-sink-[a-f0-9]{32}$').hasMatch(root.path)) {
      throw StateError('The Stage 5 file sink root is unsafe.');
    }
    if (!await root.exists()) {
      throw StateError('The Stage 5 file sink is not in its required state.');
    }
    final entries = await root.list().toList();
    if (requireEmpty && entries.isNotEmpty) {
      throw StateError('The Stage 5 file sink is not in its required state.');
    }
    var nextSequence = 0;
    for (final entry in entries) {
      if (entry is! File || entry.parent.absolute.path != root.path) {
        throw StateError('The Stage 5 file sink contains an unsafe entry.');
      }
      final name = entry.uri.pathSegments.last;
      final match = RegExp(
        r'^(\d+)-(?:save|open)-[A-Za-z0-9._-]+(?:\.json)?$',
      ).firstMatch(name);
      if (match == null) {
        throw StateError('The Stage 5 file sink contains an unsafe filename.');
      }
      final sequence = int.parse(match.group(1)!);
      if (sequence >= nextSequence) {
        nextSequence = sequence + 1;
      }
    }
    return Stage5LocalFileAdapter._(root, nextSequence);
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final extension = _trustedExtension(fileName, mimeType);
    final record = await _write(
      operation: 'save',
      fileId: null,
      filename: fileName,
      extension: extension,
      mimeType: mimeType,
      bytes: bytes,
    );
    return File(record.path).uri;
  }

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (!_uuidPattern.hasMatch(fileId) ||
        protectedMaterialFileTypeForExtension(extension)?.mimeType !=
            mimeType) {
      throw StateError('The Stage 5 Open boundary received unsafe metadata.');
    }
    await _write(
      operation: 'open',
      fileId: fileId,
      filename: '$fileId.$extension',
      extension: extension,
      mimeType: mimeType,
      bytes: bytes,
    );
    return LocalFileOpenOutcome.opened;
  }

  Future<Stage5FileSinkRecord> _write({
    required String operation,
    required String? fileId,
    required String filename,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > maximumProtectedMaterialBytes) {
      throw StateError('The Stage 5 file adapter received invalid bytes.');
    }
    final sequence = _sequence++;
    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${root.path}${Platform.pathSeparator}${sequence.toString().padLeft(3, '0')}-$operation-$safeName',
    );
    await file.writeAsBytes(bytes, flush: true);
    final record = Stage5FileSinkRecord(
      operation: operation,
      fileId: fileId,
      filename: filename,
      mimeType: mimeType,
      extension: extension,
      sizeBytes: bytes.length,
      sha256: stage5Sha256(bytes),
      path: file.absolute.path,
    );
    final recordFile = File('${file.path}.json');
    await recordFile.writeAsString(
      jsonEncode({
        'operation': operation,
        'file_id': fileId,
        'filename': filename,
        'mime_type': mimeType,
        'extension': extension,
        'size_bytes': bytes.length,
        'sha256': record.sha256,
      }),
      flush: true,
    );
    records.add(record);
    return record;
  }

  String _trustedExtension(String filename, String mimeType) {
    final separator = filename.lastIndexOf('.');
    if (separator < 1) {
      throw StateError('A saved Stage 5 filename has no extension.');
    }
    final extension = filename.substring(separator + 1).toLowerCase();
    if (protectedMaterialFileTypeForExtension(extension)?.mimeType !=
        mimeType) {
      throw StateError('A saved Stage 5 filename/MIME pair is invalid.');
    }
    return extension;
  }
}

class Stage5ProbeApi {
  Stage5ProbeApi({
    required String baseUrl,
    required this.password,
    required this.oracle,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           headers: const {Headers.acceptHeader: Headers.jsonContentType},
           validateStatus: (_) => true,
           responseType: ResponseType.json,
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(minutes: 5),
           sendTimeout: const Duration(minutes: 5),
         ),
       );

  final Dio _dio;
  final String password;
  final Stage5Oracle oracle;
  final Map<String, String> _tokens = {};

  static const _roles = {
    'target_admin': 'institution_admin',
    'target_teacher': 'teacher',
    'target_student': 'student',
    'ended_student': 'student',
    'unrelated_teacher': 'teacher',
    'unrelated_student': 'student',
    'low_limit_admin': 'institution_admin',
    'low_limit_teacher': 'teacher',
    'foreign_admin': 'institution_admin',
    'foreign_teacher': 'teacher',
    'foreign_student': 'student',
  };

  Future<String> token(String actor) async {
    final existing = _tokens[actor];
    if (existing != null) return existing;
    final response = await request(
      'POST',
      '/auth/login',
      data: {'login': oracle.logins[actor], 'password': password},
    );
    if (response.statusCode != 200) {
      throw StateError('A Stage 5 probe actor could not log in.');
    }
    final data = _map(_map(response.data)['data']);
    final token = _string(data, 'token');
    if (data['token_type'] != 'Bearer' || token.isEmpty) {
      throw StateError('A Stage 5 probe token response is invalid.');
    }
    final user = _map(data['user']);
    final expectedInstitution = actor.startsWith('low_limit_')
        ? oracle.ids['low_limit_institution']
        : actor.startsWith('foreign_')
        ? oracle.ids['foreign_institution']
        : oracle.ids['target_institution'];
    if (user['id'] != oracle.ids[actor] ||
        user['institution_id'] != expectedInstitution ||
        user['role'] != _roles[actor] ||
        user['is_active'] != true ||
        user['must_change_password'] != false) {
      throw StateError('A Stage 5 probe actor identity is invalid.');
    }
    _tokens[actor] = token;
    return token;
  }

  Future<Response<Object?>> request(
    String method,
    String path, {
    String? token,
    Object? data,
  }) {
    return _dio.request<Object?>(
      path,
      data: data,
      options: Options(
        method: method,
        contentType: data is FormData
            ? null
            : data == null
            ? null
            : Headers.jsonContentType,
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
        followRedirects: false,
      ),
    );
  }

  Future<Response<Object?>> actorRequest(
    String actor,
    String method,
    String path, {
    Object? data,
  }) async {
    return request(method, path, token: await token(actor), data: data);
  }

  Future<Response<Object?>> upload(
    String actor,
    String path,
    Stage5Fixture fixture, {
    String? title,
  }) async {
    await Stage5FixtureManifest._validateFixture(fixture);
    final fields = <String, Object?>{
      'file': MultipartFile.fromStream(
        () => File(fixture.path).openRead(),
        fixture.sizeBytes,
        filename: fixture.originalName,
      ),
    };
    if (title != null) fields['title'] = title;
    return actorRequest(actor, 'POST', path, data: FormData.fromMap(fields));
  }

  Future<void> logout(String actor) async {
    final actorToken = _tokens.remove(actor);
    if (actorToken == null) {
      return;
    }
    final response = await request('POST', '/auth/logout', token: actorToken);
    if (response.statusCode != 204) {
      throw StateError('A Stage 5 probe logout failed.');
    }
  }

  Future<void> logoutAll() async {
    Object? firstFailure;
    for (final entry in _tokens.entries.toList()) {
      final token = entry.value;
      try {
        final response = await request('POST', '/auth/logout', token: token);
        if (response.statusCode != 204) {
          firstFailure ??= StateError('A Stage 5 probe logout failed.');
        }
      } catch (error) {
        firstFailure ??= error;
      } finally {
        _tokens.remove(entry.key);
      }
    }
    if (firstFailure != null) throw firstFailure;
  }

  void close() {
    _tokens.clear();
    _dio.close(force: true);
  }
}

Stage5Json stage5Map(Object? value) => _map(value);
List<Object?> stage5List(Object? value) => _list(value);

String stage5Sha256(List<int> input) {
  const initial = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  const constants = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  final bytes = BytesBuilder(copy: false)..add(input);
  bytes.addByte(0x80);
  while ((bytes.length + 8) % 64 != 0) {
    bytes.addByte(0);
  }
  final bitLength = input.length * 8;
  final lengthBytes = ByteData(8)..setUint64(0, bitLength, Endian.big);
  bytes.add(lengthBytes.buffer.asUint8List());
  final padded = bytes.takeBytes();
  final hash = [...initial];
  for (var offset = 0; offset < padded.length; offset += 64) {
    final words = List<int>.filled(64, 0);
    final block = ByteData.sublistView(padded, offset, offset + 64);
    for (var index = 0; index < 16; index++) {
      words[index] = block.getUint32(index * 4, Endian.big);
    }
    for (var index = 16; index < 64; index++) {
      final s0 =
          _rotate(words[index - 15], 7) ^
          _rotate(words[index - 15], 18) ^
          (words[index - 15] >>> 3);
      final s1 =
          _rotate(words[index - 2], 17) ^
          _rotate(words[index - 2], 19) ^
          (words[index - 2] >>> 10);
      words[index] =
          (words[index - 16] + s0 + words[index - 7] + s1) & 0xffffffff;
    }
    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];
    for (var index = 0; index < 64; index++) {
      final upper = _rotate(e, 6) ^ _rotate(e, 11) ^ _rotate(e, 25);
      final choose = (e & f) ^ ((~e) & g);
      final t1 =
          (h + upper + choose + constants[index] + words[index]) & 0xffffffff;
      final lower = _rotate(a, 2) ^ _rotate(a, 13) ^ _rotate(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (lower + majority) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    hash[0] = (hash[0] + a) & 0xffffffff;
    hash[1] = (hash[1] + b) & 0xffffffff;
    hash[2] = (hash[2] + c) & 0xffffffff;
    hash[3] = (hash[3] + d) & 0xffffffff;
    hash[4] = (hash[4] + e) & 0xffffffff;
    hash[5] = (hash[5] + f) & 0xffffffff;
    hash[6] = (hash[6] + g) & 0xffffffff;
    hash[7] = (hash[7] + h) & 0xffffffff;
  }
  return hash.map((value) => value.toRadixString(16).padLeft(8, '0')).join();
}

int _rotate(int value, int amount) =>
    ((value >>> amount) | (value << (32 - amount))) & 0xffffffff;

Stage5Json _map(Object? value) {
  if (value is! Map) throw const FormatException('Expected a JSON object.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const FormatException('Expected string JSON keys.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value) {
  if (value is! List) throw const FormatException('Expected a JSON list.');
  return List<Object?>.from(value);
}

void _exactKeys(Stage5Json value, Set<String> keys) {
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty) {
    throw const FormatException('Unexpected Stage 5 JSON keys.');
  }
}

String _string(Stage5Json value, String key) {
  final item = value[key];
  if (item is! String || item.isEmpty) {
    throw FormatException('Expected a non-empty $key string.');
  }
  return item;
}

int _integer(Stage5Json value, String key) {
  final item = value[key];
  if (item is! int || item < 1) {
    throw FormatException('Expected a positive $key integer.');
  }
  return item;
}

Map<String, String> _stringMap(
  Object? value,
  Set<String> keys,
  String context,
) {
  final map = _map(value);
  _exactKeys(map, keys);
  final result = <String, String>{};
  for (final key in keys) {
    result[key] = _string(map, key);
  }
  if (result.length != keys.length) {
    throw FormatException('The $context map is incomplete.');
  }
  return Map.unmodifiable(result);
}
