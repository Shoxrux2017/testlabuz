import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_scope.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_list_query.dart';

import 'teacher_submission_test_support.dart';
import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherReviewQueueController', () {
    test('a task scope loads and clears within its task', () async {
      final scope = TeacherReviewQueueScope.task(
        topicId: _topicId,
        assessmentId: _homeworkId,
        type: TeacherSubmissionTaskType.homework,
      );
      final harness = _Harness();
      final state = harness.listen(scope);
      await flushTeacherControllers();

      expect(harness.repository.queries.single.toQueryParameters(), {
        'topic_id': _topicId,
        'assessment_id': _homeworkId,
        'checking_status': 'waiting_for_teacher_review',
        'sort': 'default',
        'page': 1,
        'per_page': 25,
      });

      harness.controller.setOfficial(true);
      await flushTeacherControllers();
      expect(harness.repository.queries.last.assessmentId, _homeworkId);

      harness.controller.clearFilters();
      await flushTeacherControllers();
      expect(state.read().query, scope.initialQuery);
      expect(harness.repository.queries.last.topicId, _topicId);
    });

    test('loads waiting submissions on desktop', () async {
      final harness = _Harness();
      final state = harness.listen();
      expect(state.read().status, TeacherReviewQueueStatus.loading);
      await flushTeacherControllers();

      expect(harness.repository.queries, [
        const TeacherSubmissionListQuery.initial(),
      ]);
      expect(state.read().status, TeacherReviewQueueStatus.data);
      expect(state.read().result?.items.single.id, submissionId);
    });

    test('is inactive on mobile', () async {
      final harness = _Harness(surface: AppDeviceSurface.mobile);
      final state = harness.listen();
      await flushTeacherControllers();

      expect(harness.repository.queries, isEmpty);
      expect(state.read().status, TeacherReviewQueueStatus.initial);
    });

    test('each filter and sort change reloads from the first page', () async {
      final harness = _Harness(
        onFetch: (query) async => teacherSubmissionList(
          [teacherSubmission()],
          page: query.page,
          total: 60,
        ),
      );
      final state = harness.listen();
      await flushTeacherControllers();
      harness.controller.nextPage();
      await flushTeacherControllers();
      expect(state.read().query.page, 2);

      harness.controller.setCheckingStatus(
        TeacherSubmissionCheckingFilter.checked,
      );
      await flushTeacherControllers();
      harness.controller.setType(TeacherSubmissionTaskType.blitz);
      await flushTeacherControllers();
      harness.controller.setOfficial(false);
      await flushTeacherControllers();
      harness.controller.setOverdueOnly(true);
      await flushTeacherControllers();
      harness.controller.setSort(TeacherSubmissionSort.studentName);
      await flushTeacherControllers();
      harness.controller.setDirection(TeacherSubmissionSortDirection.desc);
      await flushTeacherControllers();

      final last = harness.repository.queries.last;
      expect(last.toQueryParameters(), {
        'checking_status': 'checked',
        'type': 'blitz',
        'official': 'false',
        'overdue': 'true',
        'sort': 'student_name',
        'direction': 'desc',
        'page': 1,
        'per_page': 25,
      });
      expect(
        harness.repository.queries.skip(2).every((query) => query.page == 1),
        isTrue,
      );
      expect(state.read().status, TeacherReviewQueueStatus.data);
    });

    test('an unchanged filter does not reload', () async {
      final harness = _Harness();
      harness.listen();
      await flushTeacherControllers();

      harness.controller.setCheckingStatus(
        TeacherSubmissionCheckingFilter.waitingForTeacherReview,
      );
      harness.controller.setOverdueOnly(false);
      await flushTeacherControllers();

      expect(harness.repository.queries, hasLength(1));
    });

    test('clearFilters returns to the initial query', () async {
      final harness = _Harness();
      final state = harness.listen();
      await flushTeacherControllers();
      harness.controller.setOfficial(true);
      await flushTeacherControllers();

      harness.controller.clearFilters();
      await flushTeacherControllers();

      expect(state.read().query, const TeacherSubmissionListQuery.initial());
      expect(harness.repository.queries, hasLength(3));
    });

    test('paging moves between pages only when they exist', () async {
      final harness = _Harness(
        onFetch: (query) async => teacherSubmissionList(
          [teacherSubmission()],
          page: query.page,
          total: 30,
        ),
      );
      final state = harness.listen();
      await flushTeacherControllers();
      expect(
        [state.read().canGoPrevious, state.read().canGoNext],
        [false, true],
      );

      harness.controller.previousPage();
      harness.controller.nextPage();
      await flushTeacherControllers();
      expect(state.read().query.page, 2);
      expect(
        [state.read().canGoPrevious, state.read().canGoNext],
        [true, false],
      );

      harness.controller.nextPage();
      harness.controller.previousPage();
      await flushTeacherControllers();
      expect(state.read().query.page, 1);
      expect(harness.repository.queries.map((query) => query.page), [1, 2, 1]);
    });

    test('a failed refresh keeps the result and marks it stale', () async {
      var calls = 0;
      final harness = _Harness(
        onFetch: (_) async {
          calls += 1;
          if (calls == 2) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherSubmissionList([teacherSubmission()]);
        },
      );
      final state = harness.listen();
      await flushTeacherControllers();

      harness.controller.refresh();
      expect(state.read().status, TeacherReviewQueueStatus.refreshing);
      expect(state.read().result, isNotNull);
      await flushTeacherControllers();

      expect(state.read().status, TeacherReviewQueueStatus.error);
      expect(state.read().isStale, isTrue);
      expect(state.read().result?.items.single.id, submissionId);

      harness.controller.retry();
      await flushTeacherControllers();
      expect(state.read().status, TeacherReviewQueueStatus.data);
      expect(state.read().isStale, isFalse);
    });

    test('a first-load failure has no result and can be retried', () async {
      var calls = 0;
      final harness = _Harness(
        onFetch: (_) async {
          calls += 1;
          if (calls == 1) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return teacherSubmissionList([]);
        },
      );
      final state = harness.listen();
      await flushTeacherControllers();

      expect(state.read().status, TeacherReviewQueueStatus.error);
      expect(state.read().result, isNull);
      expect(state.read().isStale, isFalse);

      harness.controller.retry();
      await flushTeacherControllers();
      expect(state.read().status, TeacherReviewQueueStatus.data);
      expect(state.read().result?.items, isEmpty);
    });

    test('a session failure clears the controller', () async {
      final harness = _Harness(
        onFetch: (_) async =>
            throw teacherServerFailure(ApiErrorCodes.userInactive),
      );
      final state = harness.listen();
      await flushTeacherControllers();

      expect(state.read().status, TeacherReviewQueueStatus.initial);
      expect(state.read().failure, isNull);
      expect(harness.auth.bootstrapCalls, 1);
    });

    test('an older completion is dropped after the query changes', () async {
      final first = Completer<TeacherSubmissionList>();
      var calls = 0;
      final harness = _Harness(
        onFetch: (_) {
          calls += 1;
          return calls == 1
              ? first.future
              : Future.value(
                  teacherSubmissionList([
                    teacherSubmission(studentName: 'Bekzod Aliev'),
                  ]),
                );
        },
      );
      final state = harness.listen();
      await flushTeacherControllers();

      harness.controller.setType(TeacherSubmissionTaskType.homework);
      await flushTeacherControllers();
      first.complete(
        teacherSubmissionList([teacherSubmission(studentName: 'Old Result')]),
      );
      await flushTeacherControllers();

      expect(state.read().query.type, TeacherSubmissionTaskType.homework);
      expect(state.read().result?.items.single.studentName, 'Bekzod Aliev');
    });
  });
}

class _Harness {
  _Harness({
    Future<TeacherSubmissionList> Function(TeacherSubmissionListQuery query)?
    onFetch,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ),
       repository = FakeTeacherSubmissionRepository(onFetch: onFetch) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherSubmissionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherSubmissionRepository repository;
  late final ProviderContainer container;

  ProviderSubscription<TeacherReviewQueueState> listen([
    TeacherReviewQueueScope scope = TeacherReviewQueueScope.all,
  ]) {
    this.scope = scope;
    return container.listen(
      teacherReviewQueueControllerProvider(scope),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherReviewQueueScope scope = TeacherReviewQueueScope.all;

  TeacherReviewQueueController get controller =>
      container.read(teacherReviewQueueControllerProvider(scope).notifier);
}
