import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_blitz_list_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_list_query.dart';

import 'teacher_blitz_json_fixtures.dart';

const _secondBlitzId = '80000000-0000-0000-0000-000000000002';

void main() {
  group('TeacherBlitzListQuery', () {
    test('defaults to all statuses on the first page of twenty', () {
      const query = TeacherBlitzListQuery.initial();

      expect(query.status, isNull);
      expect(query.page, 1);
      expect(query.perPage, 20);
      expect(query.hasStatusFilter, isFalse);
      expect(query.toQueryParameters(), {'page': 1, 'per_page': 20});
    });

    test('serializes only supported keys with exact machine values', () {
      final query = const TeacherBlitzListQuery.initial()
          .withStatus(TeacherBlitzStatus.scheduled)
          .withPage(3);

      expect(query.hasStatusFilter, isTrue);
      expect(query.toQueryParameters(), {
        'page': 3,
        'per_page': 20,
        'status': 'scheduled',
      });
      expect(
        () => query.toQueryParameters()['topic_id'] = 'x',
        throwsUnsupportedError,
      );
    });

    test('status and per-page changes reset the page to one', () {
      final paged = const TeacherBlitzListQuery.initial().withPage(4);

      expect(paged.withStatus(TeacherBlitzStatus.active).page, 1);
      expect(paged.withStatus(null).page, 1);
      expect(paged.withPerPage(50).page, 1);
      expect(paged.withPerPage(50).perPage, 50);
    });

    test('rejects out-of-range page and per-page values', () {
      const query = TeacherBlitzListQuery.initial();

      expect(() => query.withPage(0), throwsArgumentError);
      expect(() => query.withPerPage(0), throwsArgumentError);
      expect(() => query.withPerPage(101), throwsArgumentError);
      expect(query.withPerPage(100).perPage, 100);
    });

    test('uses value equality for in-flight duplicate detection', () {
      final first = const TeacherBlitzListQuery.initial()
          .withStatus(TeacherBlitzStatus.closed)
          .withPage(2);
      final second = const TeacherBlitzListQuery.initial()
          .withStatus(TeacherBlitzStatus.closed)
          .withPage(2);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first == first.withPage(3), isFalse);
      expect(first == first.withStatus(TeacherBlitzStatus.draft), isFalse);
    });
  });

  group('TeacherBlitzListDto', () {
    test('parses the exact Teacher list envelope into domain', () {
      final list = TeacherBlitzListDto.fromJson(
        teacherBlitzListJson([
          teacherBlitzSummaryJson(),
          teacherBlitzSummaryJson(id: _secondBlitzId, status: 'closed'),
        ], total: 2),
        expectedTopicId: blitzJsonTopicId,
        requestedQuery: const TeacherBlitzListQuery.initial(),
      ).toDomain();

      expect(list.items.map((blitz) => blitz.id), [
        blitzJsonId,
        _secondBlitzId,
      ]);
      expect(list.items.last.status, TeacherBlitzStatus.closed);
      expect(list.pagination.page, 1);
      expect(list.pagination.perPage, 20);
      expect(list.pagination.total, 2);
      expect(list.pagination.lastPage, 1);
      expect(() => list.items.clear(), throwsUnsupportedError);
    });

    test('allows an empty page', () {
      final list = TeacherBlitzListDto.fromJson(
        teacherBlitzListJson(const []),
        expectedTopicId: blitzJsonTopicId,
        requestedQuery: const TeacherBlitzListQuery.initial(),
      ).toDomain();

      expect(list.items, isEmpty);
      expect(list.pagination.total, 0);
      expect(list.pagination.lastPage, 1);
    });

    test('requires pagination to match the requested page and size', () {
      final query = const TeacherBlitzListQuery.initial().withPage(2);
      final parsed = TeacherBlitzListDto.fromJson(
        teacherBlitzListJson([teacherBlitzSummaryJson()], page: 2, total: 21),
        expectedTopicId: blitzJsonTopicId,
        requestedQuery: query,
      );
      expect(parsed.pagination.page, 2);
      expect(parsed.pagination.lastPage, 2);

      for (final json in [
        teacherBlitzListJson([teacherBlitzSummaryJson()], page: 1, total: 21),
        teacherBlitzListJson(
          [teacherBlitzSummaryJson()],
          page: 2,
          perPage: 50,
          total: 21,
        ),
        teacherBlitzListJson(
          [teacherBlitzSummaryJson()],
          page: 2,
          total: 21,
          lastPage: 3,
        ),
      ]) {
        expect(
          () => TeacherBlitzListDto.fromJson(
            json,
            expectedTopicId: blitzJsonTopicId,
            requestedQuery: query,
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects malformed envelopes, duplicates, and foreign Topic rows', () {
      final unknownEnvelopeKey = teacherBlitzListJson([
        teacherBlitzSummaryJson(),
      ])..['links'] = <String, Object?>{};
      final unknownMetaKey = teacherBlitzListJson([teacherBlitzSummaryJson()]);
      (unknownMetaKey['meta']! as Map<String, Object?>)['links'] = null;
      final cases = <Object?>[
        unknownEnvelopeKey,
        unknownMetaKey,
        {'data': <Object?>[]},
        teacherBlitzListJson(const [])..['data'] = {},
        teacherBlitzListJson([
          teacherBlitzSummaryJson(),
          teacherBlitzSummaryJson(id: blitzJsonId.toUpperCase()),
        ], total: 2),
        teacherBlitzListJson([
          teacherBlitzSummaryJson(
            topicId: '10000000-0000-0000-0000-000000000002',
          ),
        ]),
        teacherBlitzListJson([teacherBlitzSummaryJson()..['extra'] = true]),
        teacherBlitzListJson([teacherBlitzSummaryJson()], total: 0),
      ];

      for (final json in cases) {
        expect(
          () => TeacherBlitzListDto.fromJson(
            json,
            expectedTopicId: blitzJsonTopicId,
            requestedQuery: const TeacherBlitzListQuery.initial(),
          ),
          throwsFormatException,
        );
      }
    });
  });
}
