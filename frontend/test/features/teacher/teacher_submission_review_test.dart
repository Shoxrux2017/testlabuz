import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_submission_detail_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_detail.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_review.dart';

import 'teacher_submission_test_support.dart';

final _reviewedId = detailId(205);
final _waitingId = detailId(206);

TeacherSubmissionDetail _detail([Map<String, Object?>? json]) =>
    TeacherSubmissionDetailDto.fromJson(
      json ?? submissionDetailJson(),
    ).toDomain();

TeacherSubmissionReviewBuild _build(
  Map<String, TeacherAnswerReviewDraft> drafts, [
  TeacherSubmissionDetail? detail,
]) => buildTeacherSubmissionReview(detail ?? _detail(), drafts);

void main() {
  group('normalizeTeacherReviewFeedback', () {
    test('strips only the server trim set', () {
      expect(
        normalizeTeacherReviewFeedback(
          ' \t\n\r\x00\x0BGood work.\x0B\x00\r\n\t ',
        ),
        'Good work.',
      );
      expect(
        normalizeTeacherReviewFeedback('\u00A0Kept\u00A0'),
        '\u00A0Kept\u00A0',
      );
      expect(normalizeTeacherReviewFeedback('A  B'), 'A  B');
    });

    test('an empty result is null', () {
      expect(normalizeTeacherReviewFeedback(''), isNull);
      expect(normalizeTeacherReviewFeedback(' \n\t '), isNull);
    });
  });

  group('buildTeacherSubmissionReview', () {
    test('without drafts nothing is changed', () {
      final build = _build(const {});

      expect(build.items, isEmpty);
      expect(build.errors, isEmpty);
      expect(build.changedCount, 0);
    });

    test('untouched or equal values are unchanged', () {
      final build = _build({
        _waitingId: const TeacherAnswerReviewDraft(
          pointsText: '  ',
          feedbackText: ' \n',
        ),
        _reviewedId: const TeacherAnswerReviewDraft(
          pointsText: ' 2.50 ',
          feedbackText: 'Good start.\n',
        ),
      });

      expect(build.changedCount, 0);
    });

    test('a correction keeps the untouched field', () {
      final build = _build({
        _reviewedId: const TeacherAnswerReviewDraft(pointsText: '3'),
      });

      expect(build.errors, isEmpty);
      expect(build.items, [
        TeacherAnswerReviewItem(
          answerId: _reviewedId,
          awardedPoints: 3,
          feedback: 'Good start.',
        ),
      ]);
    });

    test('cleared feedback is sent as null', () {
      final build = _build({
        _reviewedId: const TeacherAnswerReviewDraft(feedbackText: '  '),
      });

      expect(build.items, [
        TeacherAnswerReviewItem(
          answerId: _reviewedId,
          awardedPoints: 2.5,
          feedback: null,
        ),
      ]);
    });

    test('feedback alone on a waiting answer needs points', () {
      final build = _build({
        _waitingId: const TeacherAnswerReviewDraft(feedbackText: 'Nice.'),
      });

      expect(build.items, isEmpty);
      expect(build.errors, {
        _waitingId: const TeacherAnswerReviewErrors(
          points: TeacherReviewPointsError.missing,
        ),
      });
      expect(build.changedCount, 1);
    });

    test('rejects points that do not fit the Question', () {
      for (final text in ['2.0000001', '2.5', 'abc', '-1', '1,5', '1e1']) {
        final build = _build({
          _waitingId: TeacherAnswerReviewDraft(pointsText: text),
        });

        expect(build.items, isEmpty, reason: text);
        expect(build.errors, {
          _waitingId: const TeacherAnswerReviewErrors(
            points: TeacherReviewPointsError.invalid,
          ),
        }, reason: text);
      }
    });

    test('accepts the full points with six decimals', () {
      final build = _build({
        _waitingId: const TeacherAnswerReviewDraft(pointsText: '1.999999'),
      });

      expect(build.items.single.awardedPoints, 1.999999);
    });

    test('feedback counts code points up to 2000', () {
      final emoji = String.fromCharCode(0x1F600);
      final allowed = _build({
        _waitingId: TeacherAnswerReviewDraft(
          pointsText: '2',
          feedbackText: emoji * 2000,
        ),
      });
      final tooLong = _build({
        _waitingId: TeacherAnswerReviewDraft(
          pointsText: '2',
          feedbackText: emoji * 2001,
        ),
      });

      expect(allowed.errors, isEmpty);
      expect(allowed.items.single.feedback, emoji * 2000);
      expect(tooLong.items, isEmpty);
      expect(tooLong.errors, {
        _waitingId: const TeacherAnswerReviewErrors(feedbackTooLong: true),
      });
    });

    test('items follow the Question order and ignore other answers', () {
      final build = _build({
        _waitingId: const TeacherAnswerReviewDraft(
          pointsText: '2',
          feedbackText: ' Clear report. ',
        ),
        detailId(201): const TeacherAnswerReviewDraft(pointsText: '0'),
        detailId(299): const TeacherAnswerReviewDraft(pointsText: '0'),
        _reviewedId: const TeacherAnswerReviewDraft(pointsText: '0'),
      });

      expect(build.items, [
        TeacherAnswerReviewItem(
          answerId: _reviewedId,
          awardedPoints: 0,
          feedback: 'Good start.',
        ),
        TeacherAnswerReviewItem(
          answerId: _waitingId,
          awardedPoints: 2,
          feedback: 'Clear report.',
        ),
      ]);
    });

    test('a valid and an invalid answer are both counted', () {
      final build = _build({
        _waitingId: const TeacherAnswerReviewDraft(pointsText: '9'),
        _reviewedId: const TeacherAnswerReviewDraft(pointsText: '1'),
      });

      expect(build.items.single.answerId, _reviewedId);
      expect(build.errors.keys, [_waitingId]);
      expect(build.changedCount, 2);
    });
  });

  group('saved texts', () {
    test('a reviewed answer shows its points and a waiting one is empty', () {
      final answers = {
        for (final answer in _detail().questions.map((q) => q.answer).nonNulls)
          answer.id: answer,
      };

      expect(isTeacherReviewableAnswer(answers[_reviewedId]!), isTrue);
      expect(isTeacherReviewableAnswer(answers[_waitingId]!), isTrue);
      expect(isTeacherReviewableAnswer(answers[detailId(201)]!), isFalse);
      expect(teacherReviewSavedPointsText(answers[_reviewedId]!), '2.5');
      expect(teacherReviewSavedPointsText(answers[_waitingId]!), '');
    });
  });

  group('TeacherSubmissionReviewRequest', () {
    test('serializes exactly', () {
      final request = TeacherSubmissionReviewRequest([
        TeacherAnswerReviewItem(
          answerId: _reviewedId,
          awardedPoints: 2.75,
          feedback: 'Better.',
        ),
        TeacherAnswerReviewItem(
          answerId: _waitingId,
          awardedPoints: 2,
          feedback: null,
        ),
      ]);

      expect(request.toJson(), {
        'answers': [
          {
            'answer_id': _reviewedId,
            'awarded_points': 2.75,
            'feedback': 'Better.',
          },
          {'answer_id': _waitingId, 'awarded_points': 2.0, 'feedback': null},
        ],
      });
    });

    test('rejects no items and repeated answers', () {
      expect(
        () => TeacherSubmissionReviewRequest(const []),
        throwsArgumentError,
      );
      expect(
        () => TeacherSubmissionReviewRequest([
          TeacherAnswerReviewItem(
            answerId: _waitingId,
            awardedPoints: 1,
            feedback: null,
          ),
          TeacherAnswerReviewItem(
            answerId: _waitingId.toUpperCase(),
            awardedPoints: 2,
            feedback: null,
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('matches only a detail that holds every sent value', () {
      final request = TeacherSubmissionReviewRequest([
        TeacherAnswerReviewItem(
          answerId: _waitingId,
          awardedPoints: 2,
          feedback: 'Clear report.',
        ),
      ]);

      expect(request.matches(_detail(reviewedDetailJson())), isTrue);
      expect(request.matches(_detail()), isFalse);
      expect(
        request.matches(_detail(reviewedDetailJson(awarded: 1.5))),
        isFalse,
      );
      expect(
        request.matches(_detail(reviewedDetailJson(feedback: null))),
        isFalse,
      );
      expect(
        TeacherSubmissionReviewRequest([
          TeacherAnswerReviewItem(
            answerId: detailId(299),
            awardedPoints: 2,
            feedback: null,
          ),
        ]).matches(_detail(reviewedDetailJson())),
        isFalse,
      );
      // Q1 holds these values, but it was checked automatically.
      expect(
        TeacherSubmissionReviewRequest([
          TeacherAnswerReviewItem(
            answerId: detailId(201),
            awardedPoints: 1,
            feedback: null,
          ),
        ]).matches(_detail(reviewedDetailJson())),
        isFalse,
      );
    });
  });
}
