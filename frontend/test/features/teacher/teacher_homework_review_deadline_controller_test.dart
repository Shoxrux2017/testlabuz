import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_review_deadline_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_review_deadline_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
final _requestedInstant = DateTime.utc(2026, 9, 20, 13, 30);

void main() {
  group('TeacherHomeworkReviewDeadlineController', () {
    test(
      'sets the review deadline and publishes the returned Homework',
      () async {
        final harness = _Harness(
          homework: teacherHomework(status: TeacherHomeworkStatus.closed),
        );
        final state = harness.listen();
        await flushTeacherControllers();

        await harness.controller.submit(_request());

        expect(
          harness.repository.reviewDueAtRequests.single.homeworkId,
          _homeworkId,
        );
        expect(
          harness
              .repository
              .reviewDueAtRequests
              .single
              .request
              .reviewDueAtSerialized,
          '2026-09-20T18:30:00+05:00',
        );
        expect(
          state.read().status,
          TeacherHomeworkReviewDeadlineStatus.confirmedSuccess,
        );
        expect(state.read().feedback, 'Review deadline saved.');
        expect(harness.detail.homework?.reviewDueAt, _requestedInstant);
        expect(harness.activity.isActive, isFalse);
      },
    );

    test('clears the review deadline', () async {
      final harness = _Harness(
        homework: teacherHomework(
          status: TeacherHomeworkStatus.active,
          reviewDueAt: _requestedInstant,
        ),
      );
      final state = harness.listen();
      await flushTeacherControllers();

      await harness.controller.submit(_cleared());

      expect(
        harness
            .repository
            .reviewDueAtRequests
            .single
            .request
            .reviewDueAtSerialized,
        isNull,
      );
      expect(state.read().feedback, 'Review deadline cleared.');
      expect(harness.detail.homework?.reviewDueAt, isNull);
    });

    test(
      'sends nothing on mobile, for archived Homework or before the detail loads',
      () async {
        final mobile = _Harness(surface: AppDeviceSurface.mobile);
        mobile.listen();
        await flushTeacherControllers();
        await mobile.controller.submit(_request());
        expect(mobile.repository.reviewDueAtRequests, isEmpty);

        final archived = _Harness(
          homework: teacherHomework(status: TeacherHomeworkStatus.archived),
        );
        archived.listen();
        await flushTeacherControllers();
        await archived.controller.submit(_request());
        expect(archived.repository.reviewDueAtRequests, isEmpty);

        final unloaded = _Harness(listenDetail: false);
        unloaded.listen();
        await flushTeacherControllers();
        await unloaded.controller.submit(_request());
        expect(unloaded.repository.reviewDueAtRequests, isEmpty);
      },
    );

    test(
      'sends nothing while busy or while another Homework mutation holds the lease',
      () async {
        final pending = Completer<TeacherHomework>();
        final harness = _Harness(onSet: (_, _) => pending.future);
        harness.listen();
        await flushTeacherControllers();

        final first = harness.controller.submit(_request());
        await harness.controller.submit(_cleared());
        expect(harness.repository.reviewDueAtRequests, hasLength(1));
        pending.complete(
          teacherHomework(id: _homeworkId, reviewDueAt: _requestedInstant),
        );
        await first;

        final blocked = _Harness();
        blocked.listen();
        await flushTeacherControllers();
        expect(
          blocked.activityController.begin(
            TeacherHomeworkRouteMutationOperation.lifecycle,
          ),
          isNotNull,
        );
        await blocked.controller.submit(_request());
        expect(blocked.repository.reviewDueAtRequests, isEmpty);
      },
    );

    test(
      'an unknown outcome confirmed by the current Homework is a success',
      () async {
        var fetches = 0;
        final harness = _Harness(
          onSet: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
          onFetch: (_) async {
            fetches += 1;
            return teacherHomework(
              reviewDueAt: fetches == 1 ? null : _requestedInstant,
            );
          },
        );
        final state = harness.listen();
        await flushTeacherControllers();

        await harness.controller.submit(_request());

        expect(
          state.read().status,
          TeacherHomeworkReviewDeadlineStatus.confirmedSuccess,
        );
        expect(harness.detail.homework?.reviewDueAt, _requestedInstant);
        expect(harness.activity.isActive, isFalse);
      },
    );

    test(
      'a returned value that differs from the request is reconciled',
      () async {
        final harness = _Harness(
          onSet: (_, _) async =>
              teacherHomework(reviewDueAt: DateTime.utc(2026, 9, 21)),
        );
        final state = harness.listen();
        await flushTeacherControllers();

        await harness.controller.submit(_request());

        expect(harness.repository.fetchIds, [_homeworkId, _homeworkId]);
        expect(
          state.read().status,
          TeacherHomeworkReviewDeadlineStatus.outcomeReview,
        );
        expect(
          state.read().feedback,
          'The review deadline change could not be confirmed.\nReview the current Homework before trying again.',
        );
        expect(state.read().canCheckCurrent, isFalse);
        expect(harness.activity.isActive, isFalse);
      },
    );

    test(
      'a failed reconcile blocks until the current Homework is checked',
      () async {
        var fetches = 0;
        final harness = _Harness(
          onSet: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
          onFetch: (_) async {
            fetches += 1;
            if (fetches == 2) {
              throw teacherLocalFailure(ApiFailureKind.timeout);
            }
            return teacherHomework(
              reviewDueAt: fetches == 1 ? null : _requestedInstant,
            );
          },
        );
        final state = harness.listen();
        await flushTeacherControllers();

        await harness.controller.submit(_request());

        expect(
          state.read().status,
          TeacherHomeworkReviewDeadlineStatus.outcomeReview,
        );
        expect(state.read().canCheckCurrent, isTrue);
        expect(harness.activity.isActive, isTrue);
        expect(harness.activity.outcomeReviewBlocking, isTrue);

        await harness.controller.checkCurrentHomework();

        expect(
          state.read().status,
          TeacherHomeworkReviewDeadlineStatus.confirmedSuccess,
        );
        expect(harness.activity.isActive, isFalse);
      },
    );

    test(
      'each documented conflict refreshes the Homework and explains itself',
      () async {
        final cases = <(String, String)>[
          (
            ApiErrorCodes.taskArchived,
            'This Homework is archived. Its review deadline can no longer be changed.',
          ),
          (
            ApiErrorCodes.topicNotEditable,
            'The Topic is closed or archived. The review deadline can no longer be changed.',
          ),
        ];

        for (final (code, message) in cases) {
          var fetches = 0;
          final harness = _Harness(
            onSet: (_, _) async =>
                throw teacherServerFailure(code, statusCode: 409),
            onFetch: (_) async {
              fetches += 1;
              return teacherHomework(
                status: fetches == 1
                    ? TeacherHomeworkStatus.closed
                    : TeacherHomeworkStatus.archived,
              );
            },
          );
          final state = harness.listen();
          await flushTeacherControllers();

          await harness.controller.submit(_request());

          expect(harness.repository.fetchIds, [
            _homeworkId,
            _homeworkId,
          ], reason: code);
          expect(
            harness.detail.homework?.status,
            TeacherHomeworkStatus.archived,
            reason: code,
          );
          expect(
            state.read().status,
            TeacherHomeworkReviewDeadlineStatus.definiteFailure,
          );
          expect(state.read().feedback, message);
          expect(state.read().conflictCode, code);
          expect(harness.activity.isActive, isFalse);
        }
      },
    );

    test(
      'other definite failures show their message without a refresh',
      () async {
        final cases = <(ApiFailureKindOrCode, String)>[
          (
            (code: ApiErrorCodes.validationFailed, status: 422),
            'The review deadline could not be validated.\nRefresh and try again.',
          ),
          (
            (code: ApiErrorCodes.forbidden, status: 403),
            'You do not have permission to change this review deadline.',
          ),
          (
            (code: ApiErrorCodes.rateLimited, status: 429),
            'Too many requests. Wait before trying again.',
          ),
          (
            (code: 'server_error', status: 500),
            'The review deadline could not be updated.',
          ),
        ];

        for (final (failure, message) in cases) {
          final harness = _Harness(
            onSet: (_, _) async => throw teacherServerFailure(
              failure.code,
              statusCode: failure.status,
            ),
          );
          final state = harness.listen();
          await flushTeacherControllers();

          await harness.controller.submit(_request());

          expect(harness.repository.fetchIds, [
            _homeworkId,
          ], reason: failure.code);
          expect(
            state.read().status,
            TeacherHomeworkReviewDeadlineStatus.definiteFailure,
          );
          expect(state.read().feedback, message);
          expect(harness.activity.isActive, isFalse);
        }
      },
    );

    test('a missing Homework marks the detail not found', () async {
      final harness = _Harness(
        onSet: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      );
      harness.listen();
      harness.container.listen(
        teacherHomeworkListControllerProvider(_topicId),
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();
      expect(harness.repository.listRequests, hasLength(1));

      await harness.controller.submit(_request());
      await flushTeacherControllers();

      expect(harness.detail.status, TeacherHomeworkDetailStatus.notFound);
      expect(harness.repository.listRequests, hasLength(2));
      expect(harness.activity.isActive, isFalse);
    });

    test('a session failure clears the controller', () async {
      final harness = _Harness(
        onSet: (_, _) async =>
            throw teacherServerFailure(ApiErrorCodes.userInactive),
      );
      final state = harness.listen();
      await flushTeacherControllers();

      await harness.controller.submit(_request());

      expect(state.read().status, TeacherHomeworkReviewDeadlineStatus.idle);
      expect(state.read().feedback, isNull);
      expect(harness.auth.bootstrapCalls, 1);
      expect(harness.activity.isActive, isFalse);
    });

    test('a completion after leaving the route publishes nothing', () async {
      final pending = Completer<TeacherHomework>();
      final harness = _Harness(onSet: (_, _) => pending.future);
      final state = harness.listen();
      await flushTeacherControllers();

      final submitted = harness.controller.submit(_request());
      await flushTeacherControllers();
      harness.controller.leaveRoute();
      pending.complete(teacherHomework(reviewDueAt: _requestedInstant));
      await submitted;

      expect(state.read().status, TeacherHomeworkReviewDeadlineStatus.idle);
      expect(harness.detail.homework?.reviewDueAt, isNull);
      expect(harness.activity.isActive, isFalse);
    });

    test('consumeFeedback returns a success to idle', () async {
      final harness = _Harness();
      final state = harness.listen();
      await flushTeacherControllers();
      await harness.controller.submit(_request());

      harness.controller.consumeFeedback();

      expect(state.read().status, TeacherHomeworkReviewDeadlineStatus.idle);
      expect(state.read().feedback, isNull);
    });
  });
}

typedef ApiFailureKindOrCode = ({String code, int status});

TeacherHomeworkReviewDueAtRequest _request() {
  return TeacherHomeworkReviewDueAtRequest.fromWallClock(
    const InstitutionWallClock(
      year: 2026,
      month: 9,
      day: 20,
      hour: 18,
      minute: 30,
    ),
    'Asia/Tashkent',
  );
}

TeacherHomeworkReviewDueAtRequest _cleared() {
  return TeacherHomeworkReviewDueAtRequest.fromWallClock(null, 'Asia/Tashkent');
}

class _Harness {
  _Harness({
    TeacherHomework? homework,
    Future<TeacherHomework> Function(String homeworkId)? onFetch,
    Future<TeacherHomework> Function(
      String homeworkId,
      TeacherHomeworkReviewDueAtRequest request,
    )?
    onSet,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
    this.listenDetail = true,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ) {
    repository = FakeTeacherHomeworkRepository(
      onFetch:
          onFetch ??
          (_) async =>
              homework ?? teacherHomework(status: TeacherHomeworkStatus.closed),
      onSetReviewDueAt: onSet,
    );
    target = TeacherHomeworkRouteTarget(
      topicId: _topicId,
      homeworkId: _homeworkId,
    );
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final bool listenDetail;
  late final FakeTeacherHomeworkRepository repository;
  late final TeacherHomeworkRouteTarget target;
  late final ProviderContainer container;

  ProviderSubscription<TeacherHomeworkReviewDeadlineState> listen() {
    if (listenDetail) {
      container.listen(
        teacherHomeworkDetailControllerProvider(target),
        (_, _) {},
        fireImmediately: true,
      );
    }
    container.listen(
      teacherHomeworkRouteMutationActivityProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
    return container.listen(
      teacherHomeworkReviewDeadlineControllerProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherHomeworkReviewDeadlineController get controller => container.read(
    teacherHomeworkReviewDeadlineControllerProvider(target).notifier,
  );

  TeacherHomeworkDetailState get detail =>
      container.read(teacherHomeworkDetailControllerProvider(target));

  TeacherHomeworkRouteMutationActivityState get activity =>
      container.read(teacherHomeworkRouteMutationActivityProvider(target));

  TeacherHomeworkRouteMutationActivityController get activityController =>
      container.read(
        teacherHomeworkRouteMutationActivityProvider(target).notifier,
      );
}
