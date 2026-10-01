import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_finished_blitz_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_finished_blitz.dart';

import 'student_blitz_test_support.dart';

StudentFinishedBlitzPage _parse(
  Map<String, Object?> json, {
  int page = 1,
  int perPage = 5,
}) => StudentFinishedBlitzPageDto.fromJson(
  json,
  page: page,
  perPage: perPage,
).toDomain();

Map<String, Object?> _item(Map<String, Object?> page, [int index = 0]) =>
    (page['data']! as List<Object?>)[index]! as Map<String, Object?>;

Map<String, Object?> _result(Map<String, Object?> page) =>
    _item(page)['result']! as Map<String, Object?>;

Map<String, Object?> _feedback(Map<String, Object?> page) =>
    (_result(page)['feedback']! as List<Object?>).first!
        as Map<String, Object?>;

void main() {
  test('parses every result shape', () {
    final page = _parse(
      finishedBlitzPageJson([
        finishedBlitzJson(),
        finishedBlitzJson(
          id: otherStudentBlitzId,
          status: 'archived',
          result: finishedResultJson(visible: false),
        ),
        finishedBlitzJson(
          id: 'b1000000-0000-0000-0000-000000000003',
          attemptException: true,
        ),
        finishedBlitzJson(
          id: 'b1000000-0000-0000-0000-000000000004',
          attemptException: true,
          result: null,
        ),
      ]),
    );

    final [visible, hidden, replacement, none] = page.items;
    expect(visible.id, studentBlitzId);
    expect(visible.topic.title, 'Internet Basics');
    expect(visible.title, 'Classroom Blitz');
    expect(visible.status, StudentFinishedBlitzStatus.closed);
    expect(visible.closedAt, DateTime.utc(2026, 9, 30, 10));
    expect(visible.attemptException, isFalse);
    expect(visible.result?.attemptNumber, 1);
    expect(visible.result?.visible, isTrue);
    expect(visible.result?.normalizedScore, 82);
    expect(visible.result?.feedback.single.questionId, finishedQuestionId);
    expect(visible.result?.feedback.single.position, 3);
    expect(visible.result?.feedback.single.text, 'Good explanation.');
    expect(hidden.status, StudentFinishedBlitzStatus.archived);
    expect(hidden.result?.visible, isFalse);
    expect(hidden.result?.normalizedScore, isNull);
    expect(hidden.result?.feedback, isEmpty);
    expect(replacement.result?.attemptNumber, 2);
    expect(none.result, isNull);
    expect(none.attemptException, isTrue);
    expect(page.page, 1);
    expect(page.perPage, 5);
    expect(page.total, 4);
    expect(page.lastPage, 1);
  });

  test('accepts scores at both ends of the range', () {
    for (final score in [0, 100]) {
      final page = _parse(
        finishedBlitzPageJson([
          finishedBlitzJson(result: finishedResultJson(normalized: score)),
        ]),
      );

      expect(page.items.single.result?.normalizedScore, score);
    }
  });

  test('rejects a missing or an extra key at every level', () {
    final levels =
        <String, Map<String, Object?> Function(Map<String, Object?>)>{
          'envelope': (json) => json,
          'meta': (json) => json['meta']! as Map<String, Object?>,
          'pagination': (json) =>
              (json['meta']! as Map<String, Object?>)['pagination']!
                  as Map<String, Object?>,
          'item': _item,
          'topic': (json) => _item(json)['topic']! as Map<String, Object?>,
          'result': _result,
          'feedback': _feedback,
        };

    for (final MapEntry(key: level, value: locate) in levels.entries) {
      final extra = finishedBlitzPageJson([finishedBlitzJson()]);
      locate(extra)['unexpected'] = true;
      expect(
        () => _parse(extra),
        throwsFormatException,
        reason: 'extra $level',
      );

      final missing = finishedBlitzPageJson([finishedBlitzJson()]);
      final map = locate(missing);
      map.remove(map.keys.last);
      expect(
        () => _parse(missing),
        throwsFormatException,
        reason: 'missing $level',
      );
    }
  });

  test('rejects every contradiction', () {
    Map<String, Object?> page([Map<String, Object?>? item]) =>
        finishedBlitzPageJson([item ?? finishedBlitzJson()]);
    final cases = <String, Map<String, Object?>>{
      'unknown status': page(finishedBlitzJson(status: 'active')),
      'closed without a close time': page(finishedBlitzJson(closedAt: null)),
      // An activated Blitz is closed before it can be archived.
      'archived without a close time': page(
        finishedBlitzJson(status: 'archived', closedAt: null),
      ),
      'local close time': page(
        finishedBlitzJson(closedAt: '2026-09-30T10:00:00+05:00'),
      ),
      'non-canonical id': page(finishedBlitzJson(id: 'blitz-1')),
      'blank title': page(finishedBlitzJson(title: ' ')),
      'Attempt 2 without an exception': page(
        finishedBlitzJson(result: finishedResultJson(attemptNumber: 2)),
      ),
      'Attempt 1 with an exception': page(
        finishedBlitzJson(attemptException: true, result: finishedResultJson()),
      ),
      'visible without a score': _edited(
        page(),
        (json) => _result(json)['normalized_score'] = null,
      ),
      'hidden with a score': _edited(
        page(finishedBlitzJson(result: finishedResultJson(visible: false))),
        (json) => _result(json)['normalized_score'] = 50,
      ),
      'hidden with feedback': _edited(
        page(finishedBlitzJson(result: finishedResultJson(visible: false))),
        (json) => _result(json)['feedback'] = [
          <String, Object?>{
            'question_id': finishedQuestionId,
            'position': 1,
            'text': 'x',
          },
        ],
      ),
      'score above 100': page(
        finishedBlitzJson(result: finishedResultJson(normalized: 100.5)),
      ),
      'negative score': page(
        finishedBlitzJson(result: finishedResultJson(normalized: -1)),
      ),
      'empty feedback text': _edited(
        page(),
        (json) => _feedback(json)['text'] = '',
      ),
      'feedback position 0': _edited(
        page(),
        (json) => _feedback(json)['position'] = 0,
      ),
      'non-canonical feedback id': _edited(
        page(),
        (json) => _feedback(json)['question_id'] = 'q-1',
      ),
      'feedback out of order': page(
        finishedBlitzJson(
          result: finishedResultJson(
            feedback: [
              {'question_id': finishedQuestionId, 'position': 4, 'text': 'a'},
              {
                'question_id': 'b3000000-0000-0000-0000-000000000002',
                'position': 2,
                'text': 'b',
              },
            ],
          ),
        ),
      ),
      // Question positions are unique within an Assessment.
      'feedback positions tie': page(
        finishedBlitzJson(
          result: finishedResultJson(
            feedback: [
              {'question_id': finishedQuestionId, 'position': 2, 'text': 'a'},
              {
                'question_id': 'b3000000-0000-0000-0000-000000000002',
                'position': 2,
                'text': 'b',
              },
            ],
          ),
        ),
      ),
      'repeated feedback Question': page(
        finishedBlitzJson(
          result: finishedResultJson(
            feedback: [
              {'question_id': finishedQuestionId, 'position': 1, 'text': 'a'},
              {'question_id': finishedQuestionId, 'position': 2, 'text': 'b'},
            ],
          ),
        ),
      ),
      'duplicate items': finishedBlitzPageJson([
        finishedBlitzJson(),
        finishedBlitzJson(id: studentBlitzId.toUpperCase()),
      ]),
    };

    for (final MapEntry(key: name, value: json) in cases.entries) {
      expect(() => _parse(json), throwsFormatException, reason: name);
    }
  });

  test('rejects pagination that contradicts the request', () {
    final cases = <String, (Map<String, Object?>, int, int)>{
      'another page': (finishedBlitzPageJson([], page: 2), 1, 5),
      'another page size': (finishedBlitzPageJson([], perPage: 10), 1, 5),
      'wrong last page': (
        _edited(
          finishedBlitzPageJson([finishedBlitzJson()]),
          (json) => _pagination(json)['last_page'] = 3,
        ),
        1,
        5,
      ),
      'more items than the total': (
        _edited(
          finishedBlitzPageJson([finishedBlitzJson()]),
          (json) => _pagination(json)
            ..['total'] = 0
            ..['last_page'] = 1,
        ),
        1,
        5,
      ),
      'negative total': (
        _edited(
          finishedBlitzPageJson([]),
          (json) => _pagination(json)['total'] = -1,
        ),
        1,
        5,
      ),
      'page size 0': (
        _edited(
          finishedBlitzPageJson([finishedBlitzJson()]),
          (json) => _pagination(json)['per_page'] = 0,
        ),
        1,
        5,
      ),
      'more items than the page size': (
        finishedBlitzPageJson([
          for (var index = 1; index <= 6; index++)
            finishedBlitzJson(id: 'b1000000-0000-0000-0000-00000000010$index'),
        ]),
        1,
        5,
      ),
      'items beyond the last page': (
        finishedBlitzPageJson([finishedBlitzJson()], page: 3, total: 1),
        3,
        5,
      ),
    };

    for (final MapEntry(key: name, value: (json, page, perPage))
        in cases.entries) {
      expect(
        () => _parse(json, page: page, perPage: perPage),
        throwsFormatException,
        reason: name,
      );
    }
  });
}

/// Applies [edit] to [json] and returns it, for one-off invalid shapes.
Map<String, Object?> _edited(
  Map<String, Object?> json,
  void Function(Map<String, Object?> json) edit,
) {
  edit(json);
  return json;
}

Map<String, Object?> _pagination(Map<String, Object?> json) =>
    (json['meta']! as Map<String, Object?>)['pagination']!
        as Map<String, Object?>;
