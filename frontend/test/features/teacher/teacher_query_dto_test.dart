import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_group_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_group_list_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_list_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list_query.dart';

void main() {
  group('Teacher list queries', () {
    test('Group query serializes only fixed keys and normalized search', () {
      const initial = TeacherGroupListQuery.initial();
      expect(initial.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'name',
        'direction': 'asc',
      });

      final searched = initial.withSearch('  Group % _  ').withPage(3);
      expect(searched.toQueryParameters(), {
        'page': 3,
        'per_page': 20,
        'sort': 'name',
        'direction': 'asc',
        'search': 'Group % _',
      });
      expect(searched.withSearch('   ').search, isNull);
    });

    test('Topic query serializes only approved filters and fixed sorting', () {
      final query = const TeacherTopicListQuery.initial()
          .withSearch('  Algebra  ')
          .withStatus(TeacherTopicStatus.closed)
          .withGroupId('00000000-0000-0000-0000-000000000001')
          .withPage(2);

      expect(query.toQueryParameters(), {
        'page': 2,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
        'group_id': '00000000-0000-0000-0000-000000000001',
        'status': 'closed',
        'search': 'Algebra',
      });
      expect(query.clearFilters(), const TeacherTopicListQuery.initial());
    });

    test('search validation counts Unicode code points', () {
      final valid = List.filled(254, '😀').join();
      final invalid = '$valid😀';

      expect(TeacherGroupListQuery.isSearchInputValid(valid), isTrue);
      expect(TeacherTopicListQuery.isSearchInputValid(valid), isTrue);
      expect(TeacherGroupListQuery.isSearchInputValid(invalid), isFalse);
      expect(TeacherTopicListQuery.isSearchInputValid(invalid), isFalse);
      expect(
        () => const TeacherGroupListQuery.initial().withSearch(invalid),
        throwsArgumentError,
      );
      expect(
        () => const TeacherTopicListQuery.initial().withSearch(invalid),
        throwsArgumentError,
      );
    });
  });

  group('Teacher Group DTO', () {
    test('strictly parses assigned active Group', () {
      final group = TeacherGroupDto.fromAssignedGroupJson(_groupJson());

      expect(group.id, '00000000-0000-0000-0000-000000000001');
      expect(group.name, 'Group A');
      expect(group.status, TeacherGroupStatus.active);
      expect(group.toDomain().subjectDirection, 'Mathematics');
    });

    test('rejects archived assignment and malformed or unknown fields', () {
      expect(
        () => TeacherGroupDto.fromAssignedGroupJson(
          _groupJson()..['status'] = 'archived',
        ),
        throwsFormatException,
      );
      expect(
        () => TeacherGroupDto.fromAssignedGroupJson(
          _groupJson()..['id'] = 'not-a-uuid',
        ),
        throwsFormatException,
      );
      expect(
        () => TeacherGroupDto.fromAssignedGroupJson(
          _groupJson()..['unknown'] = true,
        ),
        throwsFormatException,
      );
      expect(
        () => TeacherGroupDto.fromAssignedGroupJson(
          _groupJson()..['name'] = '   ',
        ),
        throwsFormatException,
      );
    });
  });

  group('Teacher Topic DTO', () {
    test('parses all lifecycle states and retains lesson_at as UTC', () {
      for (final status in TeacherTopicStatus.values) {
        final dto = TeacherTopicDto.fromJson(_topicJson(status));

        expect(dto.status, status);
        expect(dto.lessonAt, DateTime.utc(2026, 8, 25, 8));
        expect(dto.lessonAt!.isUtc, isTrue);
        expect(dto.group.status, TeacherGroupStatus.archived);
      }
    });

    test('rejects lifecycle contradictions and non-Z timestamps', () {
      expect(
        () => TeacherTopicDto.fromJson(
          _topicJson(TeacherTopicStatus.active)..['activated_at'] = null,
        ),
        throwsFormatException,
      );
      expect(
        () => TeacherTopicDto.fromJson(
          _topicJson(TeacherTopicStatus.archived)..['closed_at'] = null,
        ),
        throwsFormatException,
      );
      expect(
        () => TeacherTopicDto.fromJson(
          _topicJson(TeacherTopicStatus.draft)
            ..['created_at'] = '2026-08-19T10:00:00+05:00',
        ),
        throwsFormatException,
      );
      expect(
        () => TeacherTopicDto.fromJson(
          _topicJson(TeacherTopicStatus.draft)
            ..['updated_at'] = '2026-02-31T10:00:00Z',
        ),
        throwsFormatException,
      );
      expect(
        () => TeacherTopicDto.fromJson(
          _topicJson(TeacherTopicStatus.draft)..['extra'] = null,
        ),
        throwsFormatException,
      );
    });
  });

  group('Teacher list envelopes', () {
    test('requires exact pagination and rejects duplicate IDs', () {
      final query = const TeacherGroupListQuery.initial();
      final parsed = TeacherGroupListDto.fromJson(
        _listJson([_groupJson()]),
        requestedQuery: query,
      );
      expect(parsed.toDomain().pagination.total, 1);

      expect(
        () => TeacherGroupListDto.fromJson(
          _listJson([_groupJson(), _groupJson()], total: 2),
          requestedQuery: query,
        ),
        throwsFormatException,
      );
      final uppercaseDuplicate = _groupJson()
        ..['id'] = '00000000-0000-0000-0000-00000000000A';
      final lowercaseDuplicate = _groupJson()
        ..['id'] = '00000000-0000-0000-0000-00000000000a';
      expect(
        () => TeacherGroupListDto.fromJson(
          _listJson([uppercaseDuplicate, lowercaseDuplicate], total: 2),
          requestedQuery: query,
        ),
        throwsFormatException,
      );
      expect(
        () => TeacherGroupListDto.fromJson(
          _listJson([_groupJson()], page: 2),
          requestedQuery: query,
        ),
        throwsFormatException,
      );
      final unknown = _listJson([_groupJson()])..['unknown'] = true;
      expect(
        () => TeacherGroupListDto.fromJson(unknown, requestedQuery: query),
        throwsFormatException,
      );
    });

    test('accepts only empty data beyond last page', () {
      final query = const TeacherTopicListQuery.initial().withPage(3);
      final parsed = TeacherTopicListDto.fromJson(
        _listJson(const [], page: 3, total: 20, lastPage: 1),
        requestedQuery: query,
      );
      expect(parsed.topics, isEmpty);

      expect(
        () => TeacherTopicListDto.fromJson(
          _listJson(
            [_topicJson(TeacherTopicStatus.draft)],
            page: 3,
            total: 20,
            lastPage: 1,
          ),
          requestedQuery: query,
        ),
        throwsFormatException,
      );
    });

    test('Topic list rejects duplicates and malformed nested resources', () {
      const query = TeacherTopicListQuery.initial();
      expect(
        () => TeacherTopicListDto.fromJson(
          _listJson([
            _topicJson(TeacherTopicStatus.draft),
            _topicJson(TeacherTopicStatus.draft),
          ], total: 2),
          requestedQuery: query,
        ),
        throwsFormatException,
      );
      final malformed = _topicJson(TeacherTopicStatus.draft);
      final nestedGroup = Map<String, Object?>.from(
        malformed['group']! as Map<String, Object?>,
      )..['unknown'] = true;
      malformed['group'] = nestedGroup;
      expect(
        () => TeacherTopicListDto.fromJson(
          _listJson([malformed]),
          requestedQuery: query,
        ),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _groupJson() {
  return {
    'id': '00000000-0000-0000-0000-000000000001',
    'name': 'Group A',
    'level': '7',
    'subject_direction': 'Mathematics',
    'status': 'active',
  };
}

Map<String, Object?> _topicJson(TeacherTopicStatus status) {
  final activatedAt = switch (status) {
    TeacherTopicStatus.draft => null,
    TeacherTopicStatus.active ||
    TeacherTopicStatus.closed ||
    TeacherTopicStatus.archived => '2026-08-20T10:00:00Z',
  };
  final closedAt = switch (status) {
    TeacherTopicStatus.draft || TeacherTopicStatus.active => null,
    TeacherTopicStatus.closed ||
    TeacherTopicStatus.archived => '2026-08-21T10:00:00Z',
  };

  return {
    'id': '10000000-0000-0000-0000-000000000001',
    'group': _groupJson()..['status'] = 'archived',
    'title': 'Linear equations',
    'description': null,
    'subject': 'Algebra',
    'student_instructions': 'Read the examples.',
    'lesson_at': '2026-08-25T08:00:00Z',
    'status': status.value,
    'activated_at': activatedAt,
    'closed_at': closedAt,
    'archived_at': status == TeacherTopicStatus.archived
        ? '2026-08-22T10:00:00Z'
        : null,
    'created_at': '2026-08-19T10:00:00Z',
    'updated_at': '2026-08-22T10:00:00Z',
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
