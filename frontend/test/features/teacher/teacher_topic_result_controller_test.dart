import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_list_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_list.dart';

import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

const _secondStudentId = '60000000-0000-0000-0000-000000000002';

void main() {
  group('Teacher Topic result list controller', () {
    for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
      test('loads the first page and the counts on ${surface.name}', () async {
        final harness = _Harness(
          surface: surface,
          onFetchResults: (_, query) async => teacherTopicResultList(
            query: query,
            counts: teacherResultCountsJson(calculated: 1),
          ),
        );
        final state = harness.listenList();
        expect(state.read().status, TeacherTopicResultListStatus.loading);
        await flushTeacherControllers();

        expect(
          harness.repository.listRequests.single.topicId,
          teacherResultTopicId,
        );
        expect(
          harness.repository.listRequests.single.query,
          const TeacherTopicResultListQuery(),
        );
        expect(state.read().status, TeacherTopicResultListStatus.data);
        expect(state.read().result?.items, hasLength(1));
        expect(state.read().counts?.of(TeacherTopicResultStatus.calculated), 1);
      });
    }

    test('an invalid Topic id never loads', () async {
      final harness = _Harness();
      final state = harness.listenList('topic-1');
      await flushTeacherControllers();

      expect(state.read().status, TeacherTopicResultListStatus.initial);
      expect(harness.repository.listRequests, isEmpty);
    });

    test('each filter change reloads from the first page', () async {
      final harness = _Harness(
        onFetchResults: (_, query) async =>
            emptyTeacherTopicResultList(query: query),
      );
      final state = harness.listenList();
      await flushTeacherControllers();
      final controller = harness.listController();

      controller.setStatus(TeacherTopicResultStatus.closed);
      await flushTeacherControllers();
      controller.setCategory(TeacherTopicResultCategoryCode.notCompleted);
      await flushTeacherControllers();
      controller.setCategory(TeacherTopicResultCategoryCode.notCompleted);
      await flushTeacherControllers();

      expect(harness.repository.listRequests.map((request) => request.query), [
        const TeacherTopicResultListQuery(),
        const TeacherTopicResultListQuery(
          status: TeacherTopicResultStatus.closed,
        ),
        const TeacherTopicResultListQuery(
          status: TeacherTopicResultStatus.closed,
          category: TeacherTopicResultCategoryCode.notCompleted,
        ),
      ]);

      controller.clearFilters();
      await flushTeacherControllers();
      expect(state.read().query, const TeacherTopicResultListQuery());
      expect(harness.repository.listRequests, hasLength(4));
    });

    test('pages move only within the confirmed last page', () async {
      final harness = _Harness(
        onFetchResults: (_, query) async => teacherTopicResultList(
          query: query,
          items: [teacherTopicResultJson()],
          total: 30,
          counts: teacherResultCountsJson(calculated: 30),
        ),
      );
      final state = harness.listenList();
      await flushTeacherControllers();
      final controller = harness.listController();
      expect(state.read().canGoPrevious, isFalse);
      expect(state.read().canGoNext, isTrue);

      controller.nextPage();
      expect(state.read().canGoNext, isFalse, reason: 'in flight');
      await flushTeacherControllers();
      expect(state.read().query.page, 2);
      expect(state.read().canGoNext, isFalse);

      controller.nextPage();
      controller.previousPage();
      await flushTeacherControllers();

      expect(harness.repository.listRequests.map((r) => r.query.page), [
        1,
        2,
        1,
      ]);
    });

    test('a filter change on a later page starts at the first page', () async {
      final harness = _Harness(
        onFetchResults: (_, query) async => query.status == null
            ? teacherTopicResultList(
                query: query,
                total: 30,
                counts: teacherResultCountsJson(calculated: 30),
              )
            : emptyTeacherTopicResultList(query: query),
      );
      final state = harness.listenList();
      await flushTeacherControllers();
      final controller = harness.listController();
      controller.nextPage();
      await flushTeacherControllers();
      expect(state.read().query.page, 2);

      controller.setStatus(TeacherTopicResultStatus.closed);
      await flushTeacherControllers();

      expect(
        harness.repository.listRequests.last.query,
        const TeacherTopicResultListQuery(
          status: TeacherTopicResultStatus.closed,
        ),
      );
    });

    test('a page change after a filter keeps the filter', () async {
      final harness = _Harness(
        onFetchResults: (_, query) async => teacherTopicResultList(
          query: query,
          items: [notCompletedTeacherTopicResultJson()],
          total: 26,
          counts: teacherResultCountsJson(notCompleted: 26),
        ),
      );
      harness.listenList();
      await flushTeacherControllers();
      final controller = harness.listController();

      controller.setStatus(TeacherTopicResultStatus.notCompleted);
      await flushTeacherControllers();
      controller.nextPage();
      await flushTeacherControllers();

      expect(
        harness.repository.listRequests.last.query,
        const TeacherTopicResultListQuery(
          status: TeacherTopicResultStatus.notCompleted,
          page: 2,
        ),
      );
    });

    test('the confirmed counts survive later loads and failures', () async {
      final pendingFilter = Completer<TeacherTopicResultList>();
      var fetches = 0;
      final harness = _Harness(
        onFetchResults: (_, query) {
          fetches += 1;
          return switch (fetches) {
            1 => Future.value(
              teacherTopicResultList(
                query: query,
                counts: teacherResultCountsJson(calculated: 1),
              ),
            ),
            2 => pendingFilter.future,
            _ => Future.error(
              teacherServerFailure(ApiErrorCodes.serverError, statusCode: 500),
            ),
          };
        },
      );
      final state = harness.listenList();
      await flushTeacherControllers();
      final controller = harness.listController();

      controller.setStatus(TeacherTopicResultStatus.closed);
      expect(state.read().status, TeacherTopicResultListStatus.loading);
      expect(state.read().result, isNull);
      expect(state.read().counts?.total, 1);

      pendingFilter.complete(
        emptyTeacherTopicResultList(
          query: const TeacherTopicResultListQuery(
            status: TeacherTopicResultStatus.closed,
          ),
        ).withCounts(teacherResultCountsJson(calculated: 2)),
      );
      await flushTeacherControllers();
      expect(state.read().counts?.total, 2);

      controller.setStatus(null);
      await flushTeacherControllers();
      expect(state.read().status, TeacherTopicResultListStatus.error);
      expect(state.read().counts?.total, 2);
    });

    test('a failed refresh keeps the stale page and Retry reloads', () async {
      var fetches = 0;
      final harness = _Harness(
        onFetchResults: (_, query) async {
          fetches += 1;
          if (fetches == 2) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return teacherTopicResultList(query: query);
        },
      );
      final state = harness.listenList();
      await flushTeacherControllers();
      final controller = harness.listController();

      controller.refresh();
      expect(state.read().status, TeacherTopicResultListStatus.refreshing);
      expect(state.read().result, isNotNull);
      await flushTeacherControllers();
      expect(state.read().status, TeacherTopicResultListStatus.error);
      expect(state.read().isStale, isTrue);
      expect(state.read().result?.items, hasLength(1));
      expect(state.read().failure?.kind, ApiFailureKind.timeout);

      controller.retry();
      await flushTeacherControllers();
      expect(state.read().status, TeacherTopicResultListStatus.data);
      expect(state.read().isStale, isFalse);
      expect(fetches, 3);
    });

    test('an older filter response never replaces a newer one', () async {
      final slow = Completer<TeacherTopicResultList>();
      final harness = _Harness(
        onFetchResults: (_, query) => query.status == null
            ? Future.value(teacherTopicResultList(query: query))
            : query.status == TeacherTopicResultStatus.closed
            ? slow.future
            : Future.value(emptyTeacherTopicResultList(query: query)),
      );
      final state = harness.listenList();
      await flushTeacherControllers();
      final controller = harness.listController();

      controller.setStatus(TeacherTopicResultStatus.closed);
      controller.setStatus(TeacherTopicResultStatus.waitingForBlitz);
      await flushTeacherControllers();
      slow.complete(
        emptyTeacherTopicResultList(
          query: const TeacherTopicResultListQuery(
            status: TeacherTopicResultStatus.closed,
          ),
        ),
      );
      await flushTeacherControllers();

      expect(
        state.read().query.status,
        TeacherTopicResultStatus.waitingForBlitz,
      );
      expect(state.read().status, TeacherTopicResultListStatus.data);
    });

    test('a load of an earlier session is never published', () async {
      final pending = Completer<TeacherTopicResultList>();
      var fetches = 0;
      final harness = _Harness(
        onFetchResults: (_, query) {
          fetches += 1;
          return fetches == 1
              ? pending.future
              : Future.value(emptyTeacherTopicResultList(query: query));
        },
      );
      final state = harness.listenList();
      await flushTeacherControllers();

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(teacherTopicResultList());
      await flushTeacherControllers();

      expect(state.read().status, TeacherTopicResultListStatus.data);
      expect(state.read().result?.items, isEmpty);
      expect(state.read().counts?.total, 0);
    });

    test('a new session never shows the counts of the previous one', () async {
      final secondSession = Completer<TeacherTopicResultList>();
      var fetches = 0;
      final harness = _Harness(
        onFetchResults: (_, query) {
          fetches += 1;
          return fetches == 1
              ? Future.value(teacherTopicResultList(query: query))
              : secondSession.future;
        },
      );
      final state = harness.listenList();
      await flushTeacherControllers();
      expect(state.read().counts?.total, 1);

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();

      expect(state.read().status, TeacherTopicResultListStatus.loading);
      expect(state.read().counts, isNull);
      expect(state.read().result, isNull);
    });

    test('a load that finishes after dispose is dropped', () async {
      final pending = Completer<TeacherTopicResultList>();
      final harness = _Harness(onFetchResults: (_, _) => pending.future);
      final subscription = harness.listenList();
      await flushTeacherControllers();
      expect(harness.repository.listRequests, hasLength(1));

      subscription.close();
      await flushTeacherControllers();
      pending.complete(teacherTopicResultList());
      await flushTeacherControllers();

      expect(
        harness.container.exists(
          teacherTopicResultListControllerProvider(teacherResultTopicId),
        ),
        isFalse,
      );
    });

    test('session failures clear the state and re-run bootstrap', () async {
      for (final (code, bootstraps) in [
        (ApiErrorCodes.authenticationRequired, 0),
        (ApiErrorCodes.passwordChangeRequired, 1),
        (ApiErrorCodes.userInactive, 1),
        (ApiErrorCodes.institutionInactive, 1),
      ]) {
        final harness = _Harness(
          onFetchResults: (_, _) async =>
              throw teacherServerFailure(code, statusCode: 403),
        );
        final state = harness.listenList();
        await flushTeacherControllers();

        expect(
          state.read().status,
          TeacherTopicResultListStatus.initial,
          reason: code,
        );
        expect(state.read().counts, isNull, reason: code);
        expect(harness.auth.bootstrapCalls, bootstraps, reason: code);
      }
    });

    test('an unexpected error becomes a local unknown failure', () async {
      final harness = _Harness(
        onFetchResults: (_, _) async => throw StateError('unexpected'),
      );
      final state = harness.listenList();
      await flushTeacherControllers();

      expect(state.read().status, TeacherTopicResultListStatus.error);
      expect(state.read().failure?.kind, ApiFailureKind.unknown);
    });
  });

  group('Teacher Topic result detail controller', () {
    test('the target compares ids without case', () {
      expect(
        TeacherTopicResultTarget(
          topicId: teacherResultTopicId.toUpperCase(),
          studentId: teacherResultStudentId.toUpperCase(),
        ),
        TeacherTopicResultTarget(
          topicId: teacherResultTopicId,
          studentId: teacherResultStudentId,
        ),
      );
    });

    test('loads one result and refreshes with it retained', () async {
      final pendingRefresh = Completer<TeacherTopicResultDetail>();
      var fetches = 0;
      final harness = _Harness(
        onFetchResult: (_, studentId) {
          fetches += 1;
          return fetches == 1
              ? Future.value(teacherTopicResultDetail())
              : pendingRefresh.future;
        },
      );
      final state = harness.listenDetail();
      expect(state.read().status, TeacherTopicResultDetailStatus.loading);
      await flushTeacherControllers();
      expect(state.read().status, TeacherTopicResultDetailStatus.data);
      expect(state.read().detail?.result.finalScore, 86.0);

      harness.detailController().refresh();
      expect(state.read().status, TeacherTopicResultDetailStatus.refreshing);
      expect(state.read().detail, isNotNull);
      pendingRefresh.complete(
        teacherTopicResultDetail(
          teacherTopicResultDetailJson(
            item: inconsistentTeacherTopicResultJson(),
          ),
        ),
      );
      await flushTeacherControllers();

      expect(state.read().detail?.result.finalScore, 60.0);
      expect(harness.repository.detailRequests, [
        (topicId: teacherResultTopicId, studentId: teacherResultStudentId),
        (topicId: teacherResultTopicId, studentId: teacherResultStudentId),
      ]);
    });

    test('a failed refresh keeps the stale result', () async {
      var fetches = 0;
      final harness = _Harness(
        onFetchResult: (_, _) async {
          fetches += 1;
          if (fetches == 2) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherTopicResultDetail();
        },
      );
      final state = harness.listenDetail();
      await flushTeacherControllers();

      harness.detailController().refresh();
      await flushTeacherControllers();

      expect(state.read().status, TeacherTopicResultDetailStatus.error);
      expect(state.read().isStale, isTrue);
      expect(state.read().detail, isNotNull);
      expect(state.read().failure?.kind, ApiFailureKind.connection);
    });

    test('a result outside the cohort is an error without a result', () async {
      final harness = _Harness(
        onFetchResult: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      );
      final state = harness.listenDetail();
      await flushTeacherControllers();

      expect(state.read().status, TeacherTopicResultDetailStatus.error);
      expect(state.read().detail, isNull);
      expect(state.read().failure?.statusCode, 404);
    });

    test('invalid ids never load', () async {
      final harness = _Harness();
      final invalidStudent = harness.listenDetail(studentId: 'student-1');
      final invalidTopic = harness.listenDetail(topicId: 'topic-1');
      await flushTeacherControllers();

      expect(
        invalidStudent.read().status,
        TeacherTopicResultDetailStatus.initial,
      );
      expect(
        invalidTopic.read().status,
        TeacherTopicResultDetailStatus.initial,
      );
      expect(harness.repository.detailRequests, isEmpty);
    });

    test('a load of an earlier session is never published', () async {
      final pending = Completer<TeacherTopicResultDetail>();
      var fetches = 0;
      final harness = _Harness(
        onFetchResult: (_, _) {
          fetches += 1;
          return fetches == 1
              ? pending.future
              : Future.value(
                  teacherTopicResultDetail(
                    teacherTopicResultDetailJson(
                      item: waitingTeacherTopicResultJson(),
                    ),
                  ),
                );
        },
      );
      final state = harness.listenDetail();
      await flushTeacherControllers();

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(teacherTopicResultDetail());
      await flushTeacherControllers();

      expect(
        state.read().detail?.result.status,
        TeacherTopicResultStatus.waitingForBlitz,
      );
    });

    test('a load that finishes after dispose is dropped', () async {
      final pending = Completer<TeacherTopicResultDetail>();
      final harness = _Harness(onFetchResult: (_, _) => pending.future);
      final subscription = harness.listenDetail();
      await flushTeacherControllers();
      expect(harness.repository.detailRequests, hasLength(1));

      subscription.close();
      await flushTeacherControllers();
      pending.complete(teacherTopicResultDetail());
      await flushTeacherControllers();

      expect(
        harness.container.exists(
          teacherTopicResultDetailControllerProvider(
            TeacherTopicResultTarget(
              topicId: teacherResultTopicId,
              studentId: teacherResultStudentId,
            ),
          ),
        ),
        isFalse,
      );
    });

    test('session failures clear the state and re-run bootstrap', () async {
      for (final (code, bootstraps) in [
        (ApiErrorCodes.authenticationRequired, 0),
        (ApiErrorCodes.institutionInactive, 1),
      ]) {
        final harness = _Harness(
          onFetchResult: (_, _) async =>
              throw teacherServerFailure(code, statusCode: 401),
        );
        final state = harness.listenDetail();
        await flushTeacherControllers();

        expect(
          state.read().status,
          TeacherTopicResultDetailStatus.initial,
          reason: code,
        );
        expect(harness.auth.bootstrapCalls, bootstraps, reason: code);
      }
    });

    test('an unexpected error becomes a local unknown failure', () async {
      final harness = _Harness(
        onFetchResult: (_, _) async => throw StateError('unexpected'),
      );
      final state = harness.listenDetail(studentId: _secondStudentId);
      await flushTeacherControllers();

      expect(state.read().status, TeacherTopicResultDetailStatus.error);
      expect(state.read().failure?.kind, ApiFailureKind.unknown);
    });
  });
}

extension on TeacherTopicResultList {
  TeacherTopicResultList withCounts(Map<String, Object?> counts) {
    return TeacherTopicResultList(
      items: items,
      pagination: pagination,
      counts: TeacherTopicResultCounts({
        for (final status in TeacherTopicResultStatus.values)
          status: counts[status.value]! as int,
      }),
    );
  }
}

class _Harness {
  _Harness({
    Future<TeacherTopicResultList> Function(
      String topicId,
      TeacherTopicResultListQuery query,
    )?
    onFetchResults,
    Future<TeacherTopicResultDetail> Function(String topicId, String studentId)?
    onFetchResult,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ),
       repository = FakeTeacherTopicResultRepository(
         onFetchResults: onFetchResults,
         onFetchResult: onFetchResult,
       ) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherTopicResultRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherTopicResultRepository repository;
  late final ProviderContainer container;

  ProviderSubscription<TeacherTopicResultListState> listenList([
    String topicId = teacherResultTopicId,
  ]) {
    return container.listen(
      teacherTopicResultListControllerProvider(topicId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherTopicResultListController listController() {
    return container.read(
      teacherTopicResultListControllerProvider(teacherResultTopicId).notifier,
    );
  }

  ProviderSubscription<TeacherTopicResultDetailState> listenDetail({
    String topicId = teacherResultTopicId,
    String studentId = teacherResultStudentId,
  }) {
    return container.listen(
      teacherTopicResultDetailControllerProvider(
        TeacherTopicResultTarget(topicId: topicId, studentId: studentId),
      ),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherTopicResultDetailController detailController() {
    return container.read(
      teacherTopicResultDetailControllerProvider(
        TeacherTopicResultTarget(
          topicId: teacherResultTopicId,
          studentId: teacherResultStudentId,
        ),
      ).notifier,
    );
  }
}
