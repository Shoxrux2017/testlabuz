import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_topic_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_topic.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_list_query.dart';

void main() {
  group('Student Topic list query', () {
    test('uses only the exact initial query and fixed page size', () {
      const query = StudentTopicListQuery.initial();

      expect(query.toQueryParameters(), {'page': 1, 'per_page': 20});
      expect(query.status, isNull);
      expect(query.search, isNull);
      expect(
        query.toQueryParameters().keys,
        isNot(containsAll(<String>['sort', 'direction', 'group_id', 'draft'])),
      );
    });

    test(
      'represents only approved statuses and resets filters to page one',
      () {
        expect(StudentTopicStatus.values.map((status) => status.value), [
          'active',
          'closed',
          'archived',
        ]);
        final query = const StudentTopicListQuery.initial()
            .withPage(3)
            .withSearch('  networks  ')
            .withStatus(StudentTopicStatus.archived);

        expect(query.page, 1);
        expect(query.toQueryParameters(), {
          'page': 1,
          'per_page': 20,
          'status': 'archived',
          'search': 'networks',
        });
      },
    );

    test(
      'trims search, maps blank to null, and counts Unicode code points',
      () {
        expect(StudentTopicListQuery.normalizeSearch('  '), isNull);
        expect(
          StudentTopicListQuery.normalizeSearch('  internet  '),
          'internet',
        );
        expect(
          StudentTopicListQuery.isSearchInputValid(
            List.filled(254, '😀').join(),
          ),
          isTrue,
        );
        expect(
          StudentTopicListQuery.isSearchInputValid(
            List.filled(255, '😀').join(),
          ),
          isFalse,
        );
        expect(
          () => const StudentTopicListQuery.initial().withSearch(
            List.filled(255, '😀').join(),
          ),
          throwsArgumentError,
        );
        expect(
          StudentTopicListQuery.searchDebounceDuration,
          const Duration(milliseconds: 300),
        );
      },
    );
  });

  group('Student Topic summary and list envelope DTO', () {
    test('strictly parses the exact Student summary and pagination', () {
      final dto = StudentTopicListDto.fromJson(
        _listJson([_summaryJson()]),
        requestedQuery: const StudentTopicListQuery.initial(),
      );
      final page = dto.toDomain();

      expect(page.topics.single.title, 'Internet Basics');
      expect(page.topics.single.status, StudentTopicStatus.active);
      expect(page.topics.single.group.status, StudentGroupStatus.active);
      expect(page.topics.single.lessonAt, DateTime.utc(2026, 8, 25, 4));
      expect(page.pagination.perPage, 20);
    });

    test('rejects unknown keys, draft, invalid UUIDs, and non-UTC time', () {
      final cases = <Map<String, Object?>>[
        _summaryJson()..['unknown'] = true,
        _summaryJson()..['status'] = 'draft',
        _summaryJson()..['id'] = 'not-a-uuid',
        _summaryJson()..['lesson_at'] = '2026-08-25T09:00:00+05:00',
        _summaryJson()..['group'] = (_groupJson()..['unknown'] = true),
        _summaryJson()..['group'] = (_groupJson()..['status'] = 'inactive'),
      ];

      for (final row in cases) {
        expect(
          () => StudentTopicListDto.fromJson(
            _listJson([row]),
            requestedQuery: const StudentTopicListQuery.initial(),
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects duplicate IDs and contradictory pagination', () {
      final invalidEnvelopes = <Map<String, Object?>>[
        _listJson([_summaryJson(), _summaryJson()], total: 2),
        _listJson([], page: 2),
        _listJson([], total: 21, lastPage: 1),
        _listJson([_summaryJson()], total: 0),
        _listJson(
          List.generate(
            21,
            (index) => _summaryJson(
              id: '10000000-0000-0000-0000-${index.toString().padLeft(12, '0')}',
            ),
          ),
          total: 21,
          lastPage: 2,
        ),
      ];

      for (final envelope in invalidEnvelopes) {
        expect(
          () => StudentTopicListDto.fromJson(
            envelope,
            requestedQuery: const StudentTopicListQuery.initial(),
          ),
          throwsFormatException,
        );
      }
    });
  });

  group('Student Topic detail and Learning Material DTO', () {
    test('parses exact placeholders and preserves Material order', () {
      final json = _detailJson(
        materials: [
          _materialJson(),
          _materialJson(
            id: '20000000-0000-0000-0000-000000000002',
            fileId: '30000000-0000-0000-0000-000000000002',
            title: null,
            originalName: 'notes.pdf',
            extension: 'pdf',
          ),
        ],
      );
      final topic = StudentTopicDetailDto.fromJson(json).toDomain();

      expect(topic.studentInstructions, 'Study the materials.');
      expect(topic.materials.map((material) => material.file.originalName), [
        'lesson.pptx',
        'notes.pdf',
      ]);
      expect(topic.materials.last.title, isNull);
    });

    test('rejects unexpected placeholders and unknown detail keys', () {
      final cases = <Map<String, Object?>>[
        _detailJson()..['unknown'] = true,
        _detailJson()..['homework'] = [<String, Object?>{}],
        _detailJson()..['blitz_status'] = 'available',
        _detailJson()..['result_status'] = 'released',
        _detailJson()..['student_instructions'] = '   ',
        _detailJson()..['status'] = 'draft',
      ];

      for (final json in cases) {
        expect(
          () => StudentTopicDetailDto.fromJson(json),
          throwsFormatException,
        );
      }
    });

    test('strictly validates Material and File resources', () {
      final invalidMaterials = <Map<String, Object?>>[
        _materialJson()..['unknown'] = true,
        _materialJson()..['id'] = 'bad-id',
        _materialJson()..['title'] = '   ',
        _materialJson()..['file'] = (_fileJson()..['original_name'] = '  '),
        _materialJson()..['file'] = (_fileJson()..['extension'] = 'txt'),
        _materialJson()..['file'] = (_fileJson()..['size_bytes'] = 0),
        _materialJson()..['file'] = (_fileJson()..['unknown'] = true),
      ];

      for (final material in invalidMaterials) {
        expect(
          () => StudentLearningMaterialDto.fromJson(material),
          throwsFormatException,
        );
      }
    });

    test('rejects duplicate Material and File IDs', () {
      final duplicateMaterial = _detailJson(
        materials: [
          _materialJson(),
          _materialJson(fileId: '30000000-0000-0000-0000-000000000002'),
        ],
      );
      final duplicateFile = _detailJson(
        materials: [
          _materialJson(),
          _materialJson(id: '20000000-0000-0000-0000-000000000002'),
        ],
      );

      expect(
        () => StudentTopicDetailDto.fromJson(duplicateMaterial),
        throwsFormatException,
      );
      expect(
        () => StudentTopicDetailDto.fromJson(duplicateFile),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _groupJson() {
  return {
    'id': '00000000-0000-0000-0000-000000000001',
    'name': '9-A',
    'level': 'Grade 9',
    'subject_direction': 'Informatics',
    'status': 'active',
  };
}

Map<String, Object?> _summaryJson({
  String id = '10000000-0000-0000-0000-000000000001',
}) {
  return {
    'id': id,
    'group': _groupJson(),
    'title': 'Internet Basics',
    'subject': 'Informatics',
    'lesson_at': '2026-08-25T04:00:00Z',
    'status': 'active',
  };
}

Map<String, Object?> _fileJson({
  String id = '30000000-0000-0000-0000-000000000001',
  String originalName = 'lesson.pptx',
  String extension = 'pptx',
}) {
  return {
    'id': id,
    'original_name': originalName,
    'extension': extension,
    'size_bytes': 1_250_000,
  };
}

Map<String, Object?> _materialJson({
  String id = '20000000-0000-0000-0000-000000000001',
  String fileId = '30000000-0000-0000-0000-000000000001',
  String? title = 'Lesson slides',
  String originalName = 'lesson.pptx',
  String extension = 'pptx',
}) {
  return {
    'id': id,
    'title': title,
    'file': _fileJson(
      id: fileId,
      originalName: originalName,
      extension: extension,
    ),
  };
}

Map<String, Object?> _detailJson({List<Object?>? materials}) {
  return {
    'id': '10000000-0000-0000-0000-000000000001',
    'group': _groupJson(),
    'title': 'Internet Basics',
    'description': 'Optional description',
    'subject': 'Informatics',
    'student_instructions': 'Study the materials.',
    'lesson_at': '2026-08-25T04:00:00Z',
    'status': 'active',
    'materials': materials ?? [_materialJson()],
    'homework': <Object?>[],
    'blitz_status': 'not_available',
    'result_status': 'waiting_for_homework',
  };
}

Map<String, Object?> _listJson(
  List<Object?> rows, {
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) {
  return {
    'data': rows,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': 20,
        'total': total,
        'last_page': lastPage,
      },
    },
  };
}
