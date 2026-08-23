import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_learning_material_dto.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherLearningMaterialListDto', () {
    test('strictly parses exact resources, capability, and backend order', () {
      final json = _listJson();
      final second = _materialJson(
        id: '20000000-0000-0000-0000-000000000002',
        fileId: '30000000-0000-0000-0000-000000000002',
      )..['title'] = null;
      (json['data']! as List<Object?>).add(second);

      final collection = TeacherLearningMaterialListDto.fromJson(
        json,
        expectedTopicId: _topicId,
      ).toDomain();

      expect(collection.materials.map((material) => material.id), [
        '20000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000002',
      ]);
      expect(collection.materials.first.file.extension, 'pptx');
      expect(collection.materials.first.file.sizeBytes, 1_250_000);
      expect(collection.uploadCapability.maxSizeBytes, 20_971_520);
      expect(collection.uploadCapability.platformMaxSizeBytes, 26_214_400);
      expect(collection.uploadCapability.allowedExtensions, [
        'pdf',
        'docx',
        'ppt',
        'pptx',
      ]);
    });

    test('rejects unknown or missing Material and nested File keys', () {
      final unknownMaterial = _listJson();
      (_firstMaterial(unknownMaterial))['institution_id'] = 'hidden';
      final unknownFile = _listJson();
      (_firstMaterial(unknownFile)['file']! as Map<String, Object?>)['path'] =
          'private/path';
      final missing = _listJson();
      _firstMaterial(missing).remove('updated_at');

      for (final json in [unknownMaterial, unknownFile, missing]) {
        expect(() => _parse(json), throwsFormatException);
      }
    });

    test('rejects UUID, Topic ownership, title, size, and UTC violations', () {
      final invalidId = _listJson();
      _firstMaterial(invalidId)['id'] = 'not-a-uuid';
      final wrongTopic = _listJson();
      _firstMaterial(wrongTopic)['topic_id'] =
          '10000000-0000-0000-0000-000000000002';
      final blankTitle = _listJson();
      _firstMaterial(blankTitle)['title'] = '   ';
      final emptyFile = _listJson();
      (_firstMaterial(emptyFile)['file']!
              as Map<String, Object?>)['size_bytes'] =
          0;
      final nonUtc = _listJson();
      _firstMaterial(nonUtc)['created_at'] = '2026-08-07T20:00:00+05:00';

      for (final json in [
        invalidId,
        wrongTopic,
        blankTitle,
        emptyFile,
        nonUtc,
      ]) {
        expect(() => _parse(json), throwsFormatException);
      }
    });

    test('requires canonical extension and MIME pairs', () {
      for (final pair in [
        ('PDF', 'application/pdf'),
        ('pdf', 'application/octet-stream'),
        ('txt', 'text/plain'),
      ]) {
        final json = _listJson();
        final file = _firstMaterial(json)['file']! as Map<String, Object?>;
        file['extension'] = pair.$1;
        file['mime_type'] = pair.$2;
        expect(() => _parse(json), throwsFormatException);
      }
    });

    test('rejects duplicate Material and current File identities', () {
      final duplicateMaterial = _listJson();
      (duplicateMaterial['data']! as List<Object?>).add(
        _clone(_firstMaterial(duplicateMaterial)),
      );
      final duplicateFile = _listJson();
      final second = _materialJson(
        id: '20000000-0000-0000-0000-000000000002',
        fileId: '30000000-0000-0000-0000-000000000001',
      );
      (duplicateFile['data']! as List<Object?>).add(second);

      expect(() => _parse(duplicateMaterial), throwsFormatException);
      expect(() => _parse(duplicateFile), throwsFormatException);
    });

    test('strictly validates exact upload capability', () {
      final unknownMeta = _listJson();
      (_upload(unknownMeta))['extra'] = true;
      final wrongPlatform = _listJson();
      _upload(wrongPlatform)['platform_max_size_bytes'] = 26_214_399;
      final abovePlatform = _listJson();
      _upload(abovePlatform)['max_size_bytes'] = 26_214_401;
      final duplicateExtension = _listJson();
      _upload(duplicateExtension)['allowed_extensions'] = [
        'pdf',
        'docx',
        'ppt',
        'ppt',
      ];
      final futureExtension = _listJson();
      _upload(futureExtension)['allowed_extensions'] = [
        'pdf',
        'docx',
        'ppt',
        'xlsx',
      ];

      for (final json in [
        unknownMeta,
        wrongPlatform,
        abovePlatform,
        duplicateExtension,
        futureExtension,
      ]) {
        expect(() => _parse(json), throwsFormatException);
      }
    });
  });
}

TeacherLearningMaterialListDto _parse(Map<String, Object?> json) {
  return TeacherLearningMaterialListDto.fromJson(
    json,
    expectedTopicId: _topicId,
  );
}

Map<String, Object?> _listJson() {
  return {
    'data': <Object?>[_materialJson()],
    'meta': {
      'upload': {
        'max_size_bytes': 20_971_520,
        'platform_max_size_bytes': 26_214_400,
        'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
      },
    },
  };
}

Map<String, Object?> _materialJson({
  String id = '20000000-0000-0000-0000-000000000001',
  String fileId = '30000000-0000-0000-0000-000000000001',
}) {
  return {
    'id': id,
    'topic_id': _topicId,
    'title': 'Lesson slides',
    'file': {
      'id': fileId,
      'original_name': 'lesson.pptx',
      'mime_type':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'extension': 'pptx',
      'size_bytes': 1_250_000,
    },
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T15:00:00Z',
  };
}

Map<String, Object?> _firstMaterial(Map<String, Object?> json) {
  return (json['data']! as List<Object?>).first as Map<String, Object?>;
}

Map<String, Object?> _upload(Map<String, Object?> json) {
  return ((json['meta']! as Map<String, Object?>)['upload']!
      as Map<String, Object?>);
}

Map<String, Object?> _clone(Map<String, Object?> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, Object?>;
}
