import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_official_score_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_scope.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_submission_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_submission_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_submission_review_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_submission_review_state.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_submission_detail_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_official_score.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_detail.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_review.dart';

import 'teacher_submission_test_support.dart';
import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _assessmentId = '50000000-0000-0000-0000-000000000001';
final _reviewedId = detailId(205);
final _waitingId = detailId(206);

TeacherSubmissionDetail _detail([Map<String, Object?>? json]) =>
    TeacherSubmissionDetailDto.fromJson(
      json ?? submissionDetailJson(),
    ).toDomain();

ApiRequestException _failure(
  int status,
  String code, [
  Map<String, List<String>> errors = const {},
]) => ApiRequestException(
  ApiFailure(
    kind: status == 422 ? ApiFailureKind.validation : ApiFailureKind.server,
    message: 'Failure.',
    statusCode: status,
    serverCode: code,
    fieldErrors: errors,
  ),
);

void main() {
  group('Teacher submission review controller', () {
    test('edits keep drafts and discard clears them', () async {
      final harness = _Harness();
      final state = await harness.loaded();

      harness.review
        ..editPoints(_waitingId, '2')
        ..editFeedback(_waitingId, 'Clear report.')
        ..editFeedback(_reviewedId, '');

      expect(state.read().drafts, {
        _waitingId: const TeacherAnswerReviewDraft(
          pointsText: '2',
          feedbackText: 'Clear report.',
        ),
        _reviewedId: const TeacherAnswerReviewDraft(feedbackText: ''),
      });

      harness.review.discardChanges();

      expect(state.read().drafts, isEmpty);
    });

    test('a save sends the changed answers and publishes the detail', () async {
      final harness = _Harness();
      final state = await harness.loaded();
      harness.review
        ..editPoints(_waitingId, '2')
        ..editFeedback(_waitingId, ' Clear report. ')
        ..editPoints(_reviewedId, '2.50');

      await harness.review.save();

      expect(harness.submissions.reviewRequests.single.toJson(), {
        'answers': [
          {
            'answer_id': _waitingId,
            'awarded_points': 2.0,
            'feedback': 'Clear report.',
          },
        ],
      });
      expect(state.read().status, TeacherSubmissionReviewStatus.idle);
      expect(state.read().drafts, isEmpty);
      expect(state.read().successFeedback, 'Review saved.');
      expect(harness.detailState.status, TeacherSubmissionDetailStatus.data);
      expect(
        harness.detailState.detail?.submission.status,
        TeacherSubmissionStatus.checked,
      );

      harness.review.consumeFeedback();
      expect(state.read().successFeedback, isNull);
    });

    test('client errors send nothing', () async {
      final harness = _Harness();
      final state = await harness.loaded();
      harness.review
        ..editFeedback(_waitingId, 'Nice.')
        ..editPoints(_reviewedId, '1');

      await harness.review.save();

      expect(harness.submissions.reviewRequests, isEmpty);
      expect(state.read().errors, {
        _waitingId: const TeacherAnswerReviewErrors(
          points: TeacherReviewPointsError.missing,
        ),
      });

      harness.review.editPoints(_waitingId, '1');
      expect(state.read().errors, isEmpty);
    });

    test('without changes nothing is sent', () async {
      final harness = _Harness();
      await harness.loaded();
      harness.review.editPoints(_reviewedId, '2.5');

      await harness.review.save();

      expect(harness.submissions.reviewRequests, isEmpty);
    });

    test('no save unless the detail is loaded and current', () async {
      final load = Completer<TeacherSubmissionDetail>();
      final harness = _Harness(onFetchDetail: (_) => load.future);
      harness.listenDetail();
      harness.listenReview();
      await flushTeacherControllers();
      harness.review.editPoints(_waitingId, '2');

      await harness.review.save();

      expect(harness.submissions.reviewRequests, isEmpty);
    });

    test('no save while the detail refreshes or is stale', () async {
      var fetches = 0;
      final reload = Completer<TeacherSubmissionDetail>();
      final harness = _Harness(
        onFetchDetail: (_) =>
            ++fetches == 1 ? Future.value(_detail()) : reload.future,
      );
      await harness.loaded();
      harness.review.editPoints(_waitingId, '2');

      harness.detail.refresh();
      await flushTeacherControllers();
      expect(
        harness.detailState.status,
        TeacherSubmissionDetailStatus.refreshing,
      );
      await harness.review.save();
      expect(harness.submissions.reviewRequests, isEmpty);

      reload.completeError(
        ApiRequestException(
          ApiFailure.local(kind: ApiFailureKind.timeout, message: 'Timeout.'),
        ),
      );
      await flushTeacherControllers();
      expect(harness.detailState.isStale, isTrue);
      await harness.review.save();
      expect(harness.submissions.reviewRequests, isEmpty);
    });

    test('edits and saves are ignored while saving', () async {
      final release = Completer<TeacherSubmissionDetail>();
      final harness = _Harness(onSaveReview: (_, _) => release.future);
      final state = await harness.loaded();
      harness.review.editPoints(_waitingId, '2');

      final saving = harness.review.save();
      await flushTeacherControllers();
      expect(state.read().status, TeacherSubmissionReviewStatus.saving);
      harness.review
        ..editPoints(_waitingId, '1')
        ..discardChanges();
      expect(state.read().drafts, {
        _waitingId: const TeacherAnswerReviewDraft(pointsText: '2'),
      });
      unawaited(harness.review.save());
      release.complete(_detail(reviewedDetailJson(feedback: null)));
      await saving;

      expect(harness.submissions.reviewRequests, hasLength(1));
      expect(state.read().successFeedback, 'Review saved.');
    });

    test('a confirmed save refreshes every existing related view', () async {
      final harness = _Harness();
      harness.container.listen(
        teacherReviewQueueControllerProvider(TeacherReviewQueueScope.all),
        (_, _) {},
      );
      harness.container.listen(
        teacherReviewQueueControllerProvider(
          TeacherReviewQueueScope.task(
            topicId: _topicId,
            assessmentId: _assessmentId,
            type: TeacherSubmissionTaskType.homework,
          ),
        ),
        (_, _) {},
      );
      final homework = TeacherHomeworkRouteTarget(
        topicId: _topicId,
        homeworkId: _assessmentId,
      );
      harness.container.listen(
        teacherHomeworkDetailControllerProvider(homework),
        (_, _) {},
      );
      harness.container.listen(
        teacherOfficialScoreControllerProvider(
          TeacherOfficialScoreTarget(
            assessmentId: _assessmentId,
            studentId: officialStudentId,
            type: TeacherSubmissionTaskType.homework,
          ),
        ),
        (_, _) {},
      );
      await harness.loaded();
      expect(harness.submissions.queries, hasLength(2));
      expect(harness.homework.fetchIds, [_assessmentId]);
      expect(harness.submissions.officialTargets, hasLength(1));
      harness.review.editPoints(_waitingId, '2');
      harness.review.editFeedback(_waitingId, 'Clear report.');

      await harness.review.save();
      await flushTeacherControllers();

      expect(harness.submissions.queries, hasLength(4));
      expect(harness.homework.fetchIds, [_assessmentId, _assessmentId]);
      expect(harness.submissions.officialTargets, hasLength(2));
    });

    test('a Blitz submission refreshes its Blitz detail', () async {
      Map<String, Object?> blitz(Map<String, Object?> json) => json
        ..['assessment'] = <String, Object?>{
          'id': _assessmentId,
          'type': 'blitz',
          'title': 'Quick check',
        };
      final harness = _Harness(
        onFetchDetail: (_) async =>
            _detail(blitz(submissionDetailJson()..['review_due_at'] = null)),
        onSaveReview: (_, _) async =>
            _detail(blitz(reviewedDetailJson()..['review_due_at'] = null)),
      );
      harness.container.listen(
        teacherBlitzDetailControllerProvider(
          TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _assessmentId),
        ),
        (_, _) {},
      );
      await harness.loaded();
      expect(harness.blitz.fetchIds, [_assessmentId]);
      harness.review
        ..editPoints(_waitingId, '2')
        ..editFeedback(_waitingId, 'Clear report.');

      await harness.review.save();
      await flushTeacherControllers();

      expect(harness.blitz.fetchIds, [_assessmentId, _assessmentId]);
      expect(harness.homework.fetchIds, isEmpty);
    });

    test('views that are not shown are not created', () async {
      Map<String, Object?> blitz(Map<String, Object?> json) => json
        ..['assessment'] = <String, Object?>{
          'id': _assessmentId,
          'type': 'blitz',
          'title': 'Quick check',
        };
      for (final type in TeacherSubmissionTaskType.values) {
        final isBlitz = type == TeacherSubmissionTaskType.blitz;
        final harness = _Harness(
          onFetchDetail: (_) async => _detail(
            isBlitz
                ? blitz(submissionDetailJson()..['review_due_at'] = null)
                : submissionDetailJson(),
          ),
          onSaveReview: (_, _) async => _detail(
            isBlitz
                ? blitz(reviewedDetailJson()..['review_due_at'] = null)
                : reviewedDetailJson(),
          ),
        );
        final state = await harness.loaded();
        harness.review
          ..editPoints(_waitingId, '2')
          ..editFeedback(_waitingId, 'Clear report.');

        await harness.review.save();
        await flushTeacherControllers();

        expect(state.read().successFeedback, 'Review saved.', reason: '$type');
        expect(harness.submissions.queries, isEmpty, reason: '$type');
        expect(harness.homework.fetchIds, isEmpty, reason: '$type');
        expect(harness.blitz.fetchIds, isEmpty, reason: '$type');
        expect(harness.submissions.officialTargets, isEmpty, reason: '$type');
      }
    });

    test('an unconfirmed outcome still refreshes the related views', () async {
      for (final failReconcile in [false, true]) {
        var fetches = 0;
        final harness = _Harness(
          onFetchDetail: (_) async {
            if (++fetches == 1) {
              return _detail();
            }
            if (failReconcile) {
              throw ApiRequestException(
                ApiFailure.local(
                  kind: ApiFailureKind.timeout,
                  message: 'Timeout.',
                ),
              );
            }
            return _detail(reviewedDetailJson(awarded: 1));
          },
          onSaveReview: (_, _) => Future.error(
            const TeacherSubmissionReviewOutcomeUnknownException(),
          ),
        );
        harness.container.listen(
          teacherReviewQueueControllerProvider(TeacherReviewQueueScope.all),
          (_, _) {},
        );
        harness.listenOfficialScore();
        final state = await harness.loaded();
        expect(harness.submissions.queries, hasLength(1));
        expect(harness.submissions.officialTargets, hasLength(1));
        harness.review.editPoints(_reviewedId, '3');

        await harness.review.save();
        await flushTeacherControllers();

        expect(state.read().failureMessage, isNotNull);
        expect(
          harness.submissions.queries,
          hasLength(2),
          reason: 'reconcile failed: $failReconcile',
        );
        expect(
          harness.submissions.officialTargets,
          hasLength(2),
          reason: 'reconcile failed: $failReconcile',
        );
      }
    });

    test('a detail of another submission is reconciled', () async {
      var fetches = 0;
      final harness = _Harness(
        onFetchDetail: (_) async =>
            ++fetches == 1 ? _detail() : _detail(reviewedDetailJson()),
        onSaveReview: (_, _) async => _detail(
          reviewedDetailJson()..['id'] = '70000000-0000-0000-0000-000000000009',
        ),
      );
      final state = await harness.loaded();
      harness.review
        ..editPoints(_waitingId, '2')
        ..editFeedback(_waitingId, 'Clear report.');

      await harness.review.save();

      expect(fetches, 2);
      expect(state.read().successFeedback, 'Review saved.');
      expect(harness.detailState.detail?.submission.id, submissionId);
    });

    test('a session failure while reconciling clears the controller', () async {
      var fetches = 0;
      final harness = _Harness(
        onFetchDetail: (_) async {
          if (++fetches == 1) {
            return _detail();
          }
          throw _failure(403, ApiErrorCodes.passwordChangeRequired);
        },
        onSaveReview: (_, _) => Future.error(
          const TeacherSubmissionReviewOutcomeUnknownException(),
        ),
      );
      final state = await harness.loaded();
      harness.review.editPoints(_reviewedId, '3');

      await harness.review.save();

      expect(state.read().drafts, isEmpty);
      expect(state.read().failureMessage, isNull);
      expect(harness.auth.bootstrapCalls, 1);
    });

    test('an unknown outcome confirmed by the detail is a success', () async {
      var fetches = 0;
      final harness = _Harness(
        onFetchDetail: (_) async =>
            ++fetches == 1 ? _detail() : _detail(reviewedDetailJson()),
        onSaveReview: (_, _) => Future.error(
          const TeacherSubmissionReviewOutcomeUnknownException(),
        ),
      );
      final state = await harness.loaded();
      harness.review
        ..editPoints(_waitingId, '2')
        ..editFeedback(_waitingId, 'Clear report.');

      await harness.review.save();

      expect(fetches, 2);
      expect(state.read().successFeedback, 'Review saved.');
      expect(state.read().drafts, isEmpty);
      expect(
        harness.detailState.detail?.submission.status,
        TeacherSubmissionStatus.checked,
      );
    });

    test('a returned detail that does not match is reconciled', () async {
      var fetches = 0;
      final harness = _Harness(
        onFetchDetail: (_) async =>
            ++fetches == 1 ? _detail() : _detail(reviewedDetailJson()),
        onSaveReview: (_, _) async => _detail(reviewedDetailJson(awarded: 1)),
      );
      final state = await harness.loaded();
      harness.review
        ..editPoints(_waitingId, '2')
        ..editFeedback(_waitingId, 'Clear report.');

      await harness.review.save();

      expect(fetches, 2);
      expect(state.read().successFeedback, 'Review saved.');
    });

    test('a reconciled detail that does not match keeps the drafts', () async {
      var fetches = 0;
      final harness = _Harness(
        onFetchDetail: (_) async => ++fetches == 1
            ? _detail()
            : _detail(reviewedDetailJson(awarded: 1)),
        onSaveReview: (_, _) => Future.error(
          const TeacherSubmissionReviewOutcomeUnknownException(),
        ),
      );
      final state = await harness.loaded();
      harness.review
        ..editPoints(_waitingId, '2')
        ..editFeedback(_waitingId, 'Clear report.');

      await harness.review.save();

      expect(state.read().status, TeacherSubmissionReviewStatus.idle);
      expect(state.read().drafts.keys, [_waitingId]);
      expect(
        state.read().failureMessage,
        'The review could not be confirmed. Check the answers and save again.',
      );
      expect(state.read().successFeedback, isNull);
      expect(
        harness.detailState.detail?.submission.status,
        TeacherSubmissionStatus.checked,
      );
    });

    test('a failed reconcile keeps the drafts and allows saving again', () async {
      var fetches = 0;
      var saves = 0;
      final harness = _Harness(
        onFetchDetail: (_) async {
          if (++fetches == 1) {
            return _detail();
          }
          throw ApiRequestException(
            ApiFailure.local(kind: ApiFailureKind.timeout, message: 'Timeout.'),
          );
        },
        onSaveReview: (_, _) async {
          if (++saves == 1) {
            throw const TeacherSubmissionReviewOutcomeUnknownException();
          }
          return _detail(reviewedDetailJson());
        },
      );
      final state = await harness.loaded();
      harness.review
        ..editPoints(_waitingId, '2')
        ..editFeedback(_waitingId, 'Clear report.');

      await harness.review.save();

      expect(
        state.read().failureMessage,
        'The review could not be confirmed. Save again or refresh the submission.',
      );
      expect(state.read().drafts.keys, [_waitingId]);
      expect(
        harness.detailState.detail?.submission.status,
        TeacherSubmissionStatus.waitingForTeacherReview,
      );

      await harness.review.save();

      expect(saves, 2);
      expect(state.read().successFeedback, 'Review saved.');
      expect(state.read().failureMessage, isNull);
    });

    test('definite failures keep the drafts with their message', () async {
      final cases = <ApiRequestException, String>{
        _failure(
          409,
          ApiErrorCodes.automaticCheckingPending,
        ): 'This submission is still waiting for automatic checking. Try again later.',
        _failure(422, ApiErrorCodes.validationFailed):
            'The review could not be validated. Refresh and try again.',
        _failure(403, ApiErrorCodes.forbidden):
            'You do not have permission to review this submission.',
        _failure(429, ApiErrorCodes.rateLimited):
            'Too many requests. Wait before trying again.',
        _failure(409, ApiErrorCodes.businessConflict):
            'The review could not be saved. Try again.',
      };

      for (final MapEntry(key: failure, value: message) in cases.entries) {
        final harness = _Harness(onSaveReview: (_, _) => Future.error(failure));
        final state = await harness.loaded();
        harness.review.editPoints(_reviewedId, '3');

        await harness.review.save();

        expect(state.read().failureMessage, message);
        expect(state.read().drafts.keys, [_reviewedId]);
        expect(state.read().status, TeacherSubmissionReviewStatus.idle);
        expect(harness.submissions.detailIds, hasLength(1), reason: message);
      }
    });

    test('a 422 marks the answers by item index', () async {
      final harness = _Harness(
        onSaveReview: (_, _) => Future.error(
          _failure(422, ApiErrorCodes.validationFailed, {
            'answers.0.answer_id': ['Not a manual-review answer.'],
            'answers.1.awarded_points': ['Too many points.'],
            'answers.1.feedback': ['Too long.'],
            'answers.7.awarded_points': ['Out of range.'],
          }),
        ),
      );
      final state = await harness.loaded();
      harness.review
        ..editPoints(_waitingId, '2')
        ..editPoints(_reviewedId, '3');

      await harness.review.save();

      expect(state.read().errors, {
        _reviewedId: const TeacherAnswerReviewErrors(notReviewable: true),
        _waitingId: const TeacherAnswerReviewErrors(
          points: TeacherReviewPointsError.invalid,
          feedbackTooLong: true,
        ),
      });
      expect(
        state.read().failureMessage,
        'Some answers were not saved. Check the marked fields.',
      );
      expect(
        state.read().drafts.keys,
        unorderedEquals([_waitingId, _reviewedId]),
      );
    });

    test('a 404 makes the detail not found and refreshes the queue', () async {
      final harness = _Harness(
        onSaveReview: (_, _) =>
            Future.error(_failure(404, ApiErrorCodes.resourceNotFound)),
      );
      harness.container.listen(
        teacherReviewQueueControllerProvider(TeacherReviewQueueScope.all),
        (_, _) {},
      );
      harness.listenOfficialScore();
      final state = await harness.loaded();
      harness.review.editPoints(_reviewedId, '3');

      await harness.review.save();
      await flushTeacherControllers();

      expect(
        harness.detailState.status,
        TeacherSubmissionDetailStatus.notFound,
      );
      expect(state.read().drafts, isEmpty);
      expect(state.read().failureMessage, isNull);
      expect(harness.submissions.queries, hasLength(2));
      expect(harness.submissions.officialTargets, hasLength(2));
    });

    test('a 404 while reconciling makes the detail not found', () async {
      var fetches = 0;
      final harness = _Harness(
        onFetchDetail: (_) async {
          if (++fetches == 1) {
            return _detail();
          }
          throw _failure(404, ApiErrorCodes.resourceNotFound);
        },
        onSaveReview: (_, _) => Future.error(
          const TeacherSubmissionReviewOutcomeUnknownException(),
        ),
      );
      final state = await harness.loaded();
      harness.review.editPoints(_reviewedId, '3');

      await harness.review.save();

      expect(
        harness.detailState.status,
        TeacherSubmissionDetailStatus.notFound,
      );
      expect(state.read().drafts, isEmpty);
    });

    test('a session failure clears the controller', () async {
      for (final code in [
        ApiErrorCodes.authenticationRequired,
        ApiErrorCodes.passwordChangeRequired,
        ApiErrorCodes.userInactive,
        ApiErrorCodes.institutionInactive,
      ]) {
        final status = code == ApiErrorCodes.authenticationRequired ? 401 : 403;
        final harness = _Harness(
          onSaveReview: (_, _) => Future.error(_failure(status, code)),
        );
        final state = await harness.loaded();
        harness.review.editPoints(_reviewedId, '3');

        await harness.review.save();

        expect(state.read().drafts, isEmpty, reason: code);
        expect(state.read().failureMessage, isNull, reason: code);
        expect(
          harness.auth.bootstrapCalls,
          code == ApiErrorCodes.authenticationRequired ? 0 : 1,
          reason: code,
        );
      }
    });

    test('a save from a previous session is dropped', () async {
      final release = Completer<TeacherSubmissionDetail>();
      final harness = _Harness(onSaveReview: (_, _) => release.future);
      final state = await harness.loaded();
      harness.review.editPoints(_reviewedId, '3');

      final saving = harness.review.save();
      await flushTeacherControllers();
      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      release.complete(_detail(reviewedDetailJson()));
      await saving;

      expect(state.read().successFeedback, isNull);
      expect(state.read().drafts, isEmpty);
      expect(state.read().status, TeacherSubmissionReviewStatus.idle);
    });

    test('is inactive on mobile', () async {
      final harness = _Harness(surface: AppDeviceSurface.mobile);
      final state = harness.listenReview();
      await flushTeacherControllers();

      harness.review.editPoints(_reviewedId, '3');
      await harness.review.save();

      expect(state.read().drafts, isEmpty);
      expect(harness.submissions.reviewRequests, isEmpty);
    });
  });

  group('Teacher submission detail controller', () {
    test('accepts an authoritative detail over a load in flight', () async {
      var fetches = 0;
      final reload = Completer<TeacherSubmissionDetail>();
      final harness = _Harness(
        onFetchDetail: (_) =>
            ++fetches == 1 ? Future.value(_detail()) : reload.future,
      );
      await harness.loaded();
      harness.detail.refresh();
      await flushTeacherControllers();

      harness.detail.acceptAuthoritativeDetail(
        _detail(reviewedDetailJson()),
        harness.sessionKey,
      );
      reload.complete(_detail());
      await flushTeacherControllers();

      expect(harness.detailState.status, TeacherSubmissionDetailStatus.data);
      expect(
        harness.detailState.detail?.submission.status,
        TeacherSubmissionStatus.checked,
      );
    });

    test('ignores another session and another submission', () async {
      final harness = _Harness();
      await harness.loaded();
      final previousKey = harness.sessionKey;
      final other = submissionDetailJson()
        ..['id'] = '70000000-0000-0000-0000-000000000009';

      harness.detail.acceptAuthoritativeDetail(_detail(other), previousKey);
      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      harness.detail
        ..acceptAuthoritativeDetail(_detail(reviewedDetailJson()), previousKey)
        ..markNotFound(previousKey);

      expect(harness.detailState.status, TeacherSubmissionDetailStatus.data);
      expect(harness.detailState.detail?.submission.id, submissionId);
      expect(
        harness.detailState.detail?.submission.status,
        TeacherSubmissionStatus.waitingForTeacherReview,
      );
    });
  });
}

class _Harness {
  _Harness({
    Future<TeacherSubmissionDetail> Function(String submissionId)?
    onFetchDetail,
    Future<TeacherSubmissionDetail> Function(
      String submissionId,
      TeacherSubmissionReviewRequest request,
    )?
    onSaveReview,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ),
       submissions = FakeTeacherSubmissionRepository()
         ..onFetchDetail = onFetchDetail
         ..onSaveReview = onSaveReview,
       homework = FakeTeacherHomeworkRepository(),
       blitz = FakeTeacherBlitzRepository() {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherSubmissionRepositoryProvider.overrideWithValue(submissions),
        teacherHomeworkRepositoryProvider.overrideWithValue(homework),
        teacherBlitzRepositoryProvider.overrideWithValue(blitz),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherSubmissionRepository submissions;
  final FakeTeacherHomeworkRepository homework;
  final FakeTeacherBlitzRepository blitz;
  late final ProviderContainer container;

  ProviderSubscription<TeacherSubmissionDetailState> listenDetail() =>
      container.listen(
        teacherSubmissionDetailControllerProvider(submissionId),
        (_, _) {},
        fireImmediately: true,
      );

  ProviderSubscription<TeacherSubmissionReviewState> listenReview() =>
      container.listen(
        teacherSubmissionReviewControllerProvider(submissionId),
        (_, _) {},
        fireImmediately: true,
      );

  void listenOfficialScore() => container.listen(
    teacherOfficialScoreControllerProvider(
      TeacherOfficialScoreTarget(
        assessmentId: _assessmentId,
        studentId: officialStudentId,
        type: TeacherSubmissionTaskType.homework,
      ),
    ),
    (_, _) {},
  );

  /// Listens to both controllers and waits for the first detail load.
  Future<ProviderSubscription<TeacherSubmissionReviewState>> loaded() async {
    listenDetail();
    final state = listenReview();
    await flushTeacherControllers();
    return state;
  }

  TeacherSubmissionDetailState get detailState =>
      container.read(teacherSubmissionDetailControllerProvider(submissionId));

  TeacherSubmissionDetailController get detail => container.read(
    teacherSubmissionDetailControllerProvider(submissionId).notifier,
  );

  TeacherSubmissionReviewController get review => container.read(
    teacherSubmissionReviewControllerProvider(submissionId).notifier,
  );

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    container.read(appDeviceSurfaceProvider),
  ).eligibleKey!;
}
