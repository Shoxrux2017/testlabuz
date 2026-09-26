import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_monitoring_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_parent_identity.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_attempt_exception.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_monitoring.dart';

import 'teacher_blitz_json_fixtures.dart';
import 'teacher_blitz_monitoring_fixtures.dart';
import 'teacher_blitz_monitoring_test_support.dart';
import 'teacher_test_support.dart';

void main() {
  test('projects the Blitz detail onto the route identity', () {
    final matching = teacherBlitz(status: TeacherBlitzStatus.active);
    for (final (detail, expected) in [
      (const TeacherBlitzDetailState(), TeacherBlitzParentIdentity.checking),
      (
        const TeacherBlitzDetailState(status: TeacherBlitzDetailStatus.loading),
        TeacherBlitzParentIdentity.checking,
      ),
      (
        TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.data,
          blitz: matching,
        ),
        TeacherBlitzParentIdentity.confirmed,
      ),
      (
        TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.refreshing,
          blitz: matching,
        ),
        TeacherBlitzParentIdentity.confirmed,
      ),
      (
        TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.data,
          blitz: teacherBlitz(topicId: monitoringOtherTopicId),
        ),
        TeacherBlitzParentIdentity.notFound,
      ),
      (
        TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.data,
          blitz: teacherBlitz(id: '80000000-0000-0000-0000-000000000009'),
        ),
        TeacherBlitzParentIdentity.notFound,
      ),
      (
        const TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.notFound,
        ),
        TeacherBlitzParentIdentity.notFound,
      ),
      (
        TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.error,
          blitz: matching,
          isStale: true,
        ),
        TeacherBlitzParentIdentity.error,
      ),
    ]) {
      expect(
        teacherBlitzParentIdentity(detail, monitoringTarget),
        expected,
        reason: '${detail.status}',
      );
    }
  });

  group('parent identity guard', () {
    final pendingDetail = Completer<TeacherBlitz>();
    monitoringTest(
      'a Blitz detail still checking starts no monitoring read',
      (harness) async {
        await harness.start();
        await harness.tick();

        expect(harness.state.status, TeacherBlitzMonitoringStatus.loading);
        expect(harness.state.monitoring, isNull);
        expect(harness.repository.monitoringIds, isEmpty);
      },
      onFetch: (_) => pendingDetail.future,
    );

    monitoringTest('the exact route Blitz loads monitoring once', (
      harness,
    ) async {
      await harness.start();

      expect(harness.repository.monitoringIds, [blitzJsonId]);
      expect(harness.state.status, TeacherBlitzMonitoringStatus.data);
      expect(harness.state.monitoring!.blitz.id, blitzJsonId);
      expect(harness.state.isStale, isFalse);
      expect(harness.state.livePollingEnabled, isTrue);
    });

    monitoringTest(
      'a missing Blitz is not found and never read for monitoring',
      (harness) async {
        await harness.start();
        await harness.tick();

        expect(harness.state.status, TeacherBlitzMonitoringStatus.notFound);
        expect(harness.repository.monitoringIds, isEmpty);
      },
      onFetch: (_) async => throw teacherServerFailure(
        ApiErrorCodes.resourceNotFound,
        statusCode: 404,
      ),
    );

    monitoringTest(
      'a Blitz of another Topic is not found and never read for monitoring',
      (harness) async {
        await harness.start();
        await harness.tick();

        expect(harness.state.status, TeacherBlitzMonitoringStatus.notFound);
        expect(harness.state.monitoring, isNull);
        expect(harness.repository.monitoringIds, isEmpty);
      },
      onFetch: (id) async => teacherBlitz(
        id: id,
        topicId: monitoringOtherTopicId,
        status: TeacherBlitzStatus.active,
      ),
    );

    var detailCalls = 0;
    monitoringTest(
      'a transient detail failure has no monitoring fallback until Retry',
      (harness) async {
        await harness.start();
        await harness.tick();

        expect(harness.state.status, TeacherBlitzMonitoringStatus.initial);
        expect(harness.repository.monitoringIds, isEmpty);

        harness.container
            .read(
              teacherBlitzDetailControllerProvider(monitoringTarget).notifier,
            )
            .retry();
        await harness.settle();

        expect(harness.state.status, TeacherBlitzMonitoringStatus.data);
        expect(harness.repository.monitoringIds, [blitzJsonId]);
      },
      onFetch: (id) async {
        if (detailCalls++ == 0) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherBlitz(id: id, status: TeacherBlitzStatus.active);
      },
    );

    monitoringTest(
      'a manual Refresh without a confirmed Blitz reads nothing',
      (harness) async {
        await harness.start();

        harness.monitoring.refresh();
        await harness.settle();

        expect(harness.repository.monitoringIds, isEmpty);
      },
      onFetch: (_) async =>
          throw teacherLocalFailure(ApiFailureKind.connection),
    );

    monitoringTest(
      'losing the parent identity stops polling and drops the in-flight read',
      (harness) async {
        await harness.start();
        final pending = Completer<TeacherBlitzMonitoring>();
        harness.repository.onFetchMonitoring = (_) => pending.future;
        await harness.tick();
        expect(harness.repository.monitoringIds, hasLength(2));

        harness.markDetailNotFound();
        await harness.settle();
        pending.complete(teacherMonitoring());
        await harness.settle();
        await harness.tick();

        expect(harness.state.status, TeacherBlitzMonitoringStatus.notFound);
        expect(harness.state.monitoring, isNull);
        expect(harness.state.livePollingEnabled, isFalse);
        expect(harness.repository.monitoringIds, hasLength(2));
      },
    );
  });

  group('reads', () {
    monitoringTest('a snapshot of another Blitz is rejected', (harness) async {
      harness.repository.onFetchMonitoring = (_) async =>
          teacherMonitoring(blitzId: '80000000-0000-0000-0000-000000000009');
      await harness.start();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.error);
      expect(harness.state.monitoring, isNull);
      expect(harness.state.failure!.kind, ApiFailureKind.invalidResponse);
    });

    monitoringTest('manual Refresh keeps the snapshot while it reads', (
      harness,
    ) async {
      await harness.start();
      final first = harness.state.monitoring;
      final pending = Completer<TeacherBlitzMonitoring>();
      harness.repository.onFetchMonitoring = (_) => pending.future;

      harness.monitoring.refresh();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.refreshing);
      expect(harness.state.lastRefreshWasAutomatic, isFalse);
      expect(harness.state.monitoring, same(first));

      final next = teacherMonitoring(
        students: [inProgressRowJson(monitoringStudentA)],
      );
      pending.complete(next);
      await harness.settle();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.data);
      expect(harness.state.monitoring, same(next));
    });

    monitoringTest('a failed manual Refresh keeps the snapshot as stale', (
      harness,
    ) async {
      await harness.start();
      final first = harness.state.monitoring;
      harness.repository.onFetchMonitoring = (_) async =>
          throw teacherLocalFailure(ApiFailureKind.connection);

      harness.monitoring.refresh();
      await harness.settle();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.error);
      expect(harness.state.monitoring, same(first));
      expect(harness.state.isStale, isTrue);
    });
  });

  group('polling', () {
    monitoringTest('polls every 5 seconds with a single timer', (
      harness,
    ) async {
      await harness.start();
      await harness.tester.pump(const Duration(seconds: 4));
      expect(harness.repository.monitoringIds, hasLength(1));

      await harness.tester.pump(const Duration(seconds: 1));
      await harness.tick();

      expect(harness.repository.monitoringIds, hasLength(3));
      expect(harness.state.lastRefreshWasAutomatic, isTrue);
    });

    monitoringTest('does not poll before the route owns the screen', (
      harness,
    ) async {
      await harness.start(enterRoute: false);
      await harness.tick();

      expect(harness.repository.monitoringIds, hasLength(1));
      expect(harness.state.livePollingEnabled, isFalse);
    });

    monitoringTest('skips a tick while a read is in flight', (harness) async {
      await harness.start();
      final pending = Completer<TeacherBlitzMonitoring>();
      harness.repository.onFetchMonitoring = (_) => pending.future;

      await harness.tick();
      await harness.tick();
      await harness.tick();
      expect(harness.repository.monitoringIds, hasLength(2));

      pending.complete(teacherMonitoring());
      await harness.settle();
      harness.repository.onFetchMonitoring = null;
      await harness.tick();

      expect(harness.repository.monitoringIds, hasLength(3));
    });

    monitoringTest('a failed poll is stale and the next tick recovers', (
      harness,
    ) async {
      await harness.start();
      final first = harness.state.monitoring;
      harness.repository.onFetchMonitoring = (_) async =>
          throw teacherServerFailure(
            ApiErrorCodes.serverError,
            statusCode: 500,
          );

      await harness.tick();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.error);
      expect(harness.state.monitoring, same(first));
      expect(harness.state.isStale, isTrue);
      expect(harness.state.livePollingEnabled, isTrue);

      harness.repository.onFetchMonitoring = null;
      await harness.tick();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.data);
      expect(harness.state.isStale, isFalse);
    });

    monitoringTest('429 pauses polling until a manual Retry succeeds', (
      harness,
    ) async {
      await harness.start();
      harness.repository.onFetchMonitoring = (_) async =>
          throw teacherServerFailure(
            ApiErrorCodes.rateLimited,
            statusCode: 429,
          );

      await harness.tick();
      await harness.tick();
      await harness.tick();

      expect(harness.repository.monitoringIds, hasLength(2));
      expect(harness.state.pollingPausedByRateLimit, isTrue);
      expect(harness.state.livePollingEnabled, isFalse);
      expect(harness.state.monitoring, isNotNull);
      expect(harness.state.isStale, isTrue);

      harness.repository.onFetchMonitoring = null;
      harness.monitoring.refresh();
      await harness.settle();

      expect(harness.state.pollingPausedByRateLimit, isFalse);
      expect(harness.state.livePollingEnabled, isTrue);
      await harness.tick();
      expect(harness.repository.monitoringIds, hasLength(4));
    });

    for (final (code, status, expected) in [
      (
        ApiErrorCodes.taskNotActive,
        409,
        TeacherBlitzMonitoringStatus.notActive,
      ),
      (ApiErrorCodes.taskClosed, 409, TeacherBlitzMonitoringStatus.closed),
      (ApiErrorCodes.taskArchived, 409, TeacherBlitzMonitoringStatus.archived),
      (
        ApiErrorCodes.resourceNotFound,
        404,
        TeacherBlitzMonitoringStatus.notFound,
      ),
    ]) {
      monitoringTest('$status $code ends live monitoring', (harness) async {
        await harness.start();
        harness.repository.onFetchMonitoring = (_) async =>
            throw teacherServerFailure(code, statusCode: status);

        await harness.tick();
        await harness.tick();
        harness.monitoring.refresh();
        await harness.settle();

        expect(harness.state.status, expected);
        expect(harness.state.monitoring, isNull);
        expect(harness.state.livePollingEnabled, isFalse);
        expect(harness.repository.monitoringIds, hasLength(2));
      });
    }

    monitoringTest('leaving the route stops polling and drops the read', (
      harness,
    ) async {
      await harness.start();
      final first = harness.state.monitoring;
      final pending = Completer<TeacherBlitzMonitoring>();
      harness.repository.onFetchMonitoring = (_) => pending.future;
      await harness.tick();

      harness.monitoring.leaveLiveRoute();
      pending.complete(teacherMonitoring(students: const []));
      await harness.settle();
      await harness.tick();

      expect(harness.repository.monitoringIds, hasLength(2));
      expect(harness.state.monitoring, same(first));
      expect(harness.state.livePollingEnabled, isFalse);
    });

    monitoringTest('an app pause stops polling and a resume reads at once', (
      harness,
    ) async {
      await harness.start();

      harness.monitoring.setAppResumed(false);
      await harness.tick();
      await harness.tick();

      expect(harness.repository.monitoringIds, hasLength(1));
      expect(harness.state.livePollingEnabled, isFalse);
      expect(harness.state.monitoring, isNotNull);

      harness.monitoring.setAppResumed(true);
      await harness.settle();

      expect(harness.repository.monitoringIds, hasLength(2));
      expect(harness.state.livePollingEnabled, isTrue);
      await harness.tick();
      expect(harness.repository.monitoringIds, hasLength(3));
    });

    monitoringTest('a grant dialog pauses polling and closing it reads once', (
      harness,
    ) async {
      await harness.start();

      harness.monitoring.holdForDialog();
      await harness.tick();
      expect(harness.repository.monitoringIds, hasLength(1));
      expect(harness.state.livePollingEnabled, isFalse);

      harness.monitoring.releaseDialogHold();
      await harness.settle();

      expect(harness.repository.monitoringIds, hasLength(2));
      expect(harness.state.livePollingEnabled, isTrue);
    });

    monitoringTest('mobile polls monitoring the same way', (harness) async {
      await harness.start();
      await harness.tick();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.data);
      expect(harness.repository.monitoringIds, hasLength(2));
    }, surface: AppDeviceSurface.mobile);
  });

  group('session ownership', () {
    monitoringTest('a session switch clears the snapshot and reloads', (
      harness,
    ) async {
      harness.repository.onFetchMonitoring = (_) async => teacherMonitoring(
        students: [
          terminalRowJson(
            monitoringStudentA,
            attemptException: monitoringExceptionJson(),
          ),
        ],
      );
      await harness.start();
      final pendingDetail = Completer<TeacherBlitz>();
      harness.repository.onFetch = (_) => pendingDetail.future;

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await harness.settle();

      expect(harness.state.monitoring, isNull);
      expect(harness.state.status, TeacherBlitzMonitoringStatus.loading);

      pendingDetail.complete(teacherBlitz(status: TeacherBlitzStatus.active));
      await harness.settle();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.data);
      expect(harness.repository.monitoringIds, hasLength(2));
    });

    monitoringTest('a read from an older session never publishes', (
      harness,
    ) async {
      await harness.start();
      final pending = Completer<TeacherBlitzMonitoring>();
      harness.repository.onFetchMonitoring = (_) => pending.future;
      await harness.tick();

      harness.auth.logOut();
      await harness.settle();
      pending.complete(teacherMonitoring());
      await harness.settle();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.initial);
      expect(harness.state.monitoring, isNull);
      expect(harness.state.livePollingEnabled, isFalse);
    });

    monitoringTest('a session failure clears monitoring and re-bootstraps', (
      harness,
    ) async {
      await harness.start();
      harness.repository.onFetchMonitoring = (_) async =>
          throw teacherServerFailure(ApiErrorCodes.passwordChangeRequired);

      await harness.tick();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.initial);
      expect(harness.state.monitoring, isNull);
      expect(harness.auth.bootstrapCalls, 1);
      await harness.tick();
      expect(harness.repository.monitoringIds, hasLength(2));
    });
  });

  group('grant coordination', () {
    monitoringTest('a grant drops a poll that was already in flight', (
      harness,
    ) async {
      harness.repository.onFetchMonitoring = (_) async =>
          teacherMonitoring(students: [terminalRowJson(monitoringStudentA)]);
      await harness.start();
      final before = harness.state.monitoring;
      final ticket = harness.grant.prepare(monitoringStudentA)!;
      final stalePoll = Completer<TeacherBlitzMonitoring>();
      harness.repository.onFetchMonitoring = (_) => stalePoll.future;
      await harness.tick();
      expect(harness.state.status, TeacherBlitzMonitoringStatus.refreshing);

      final pendingGrant = Completer<TeacherBlitzAttemptException>();
      harness.repository.onGrantAttemptException = (_, _, _, _) =>
          pendingGrant.future;
      unawaited(harness.grant.grant(ticket, _request()));
      await harness.settle();
      stalePoll.complete(
        teacherMonitoring(
          students: [
            terminalRowJson(monitoringStudentA, fullName: 'Pre-grant poll'),
          ],
        ),
      );
      await harness.settle();

      expect(harness.state.status, TeacherBlitzMonitoringStatus.data);
      expect(harness.state.monitoring, same(before));
    });

    monitoringTest('a grant owns the route until it settles', (harness) async {
      harness.repository.onFetchMonitoring = (_) async =>
          teacherMonitoring(students: [terminalRowJson(monitoringStudentA)]);
      await harness.start();
      final pendingGrant = Completer<TeacherBlitzAttemptException>();
      harness.repository.onGrantAttemptException = (_, _, _, _) =>
          pendingGrant.future;

      final ticket = harness.grant.prepare(monitoringStudentA)!;
      unawaited(harness.grant.grant(ticket, _request()));
      await harness.settle();
      await harness.tick();
      harness.monitoring.refresh();
      await harness.settle();

      expect(harness.repository.monitoringIds, hasLength(1));
      expect(harness.state.livePollingEnabled, isFalse);

      harness.repository.onFetchMonitoring = (_) async => teacherMonitoring(
        students: [
          notStartedRowJson(
            monitoringStudentA,
            remainingSeconds: null,
            attemptException: monitoringExceptionJson(),
          ),
        ],
      );
      pendingGrant.complete(teacherGrant());
      await harness.settle();

      expect(harness.repository.monitoringIds, hasLength(2));
      expect(
        harness.state.monitoring!
            .studentById(monitoringStudentA)!
            .attemptException,
        isNotNull,
      );
      expect(harness.state.livePollingEnabled, isTrue);
      await harness.tick();
      expect(harness.repository.monitoringIds, hasLength(3));
    });
  });
}

TeacherBlitzAttemptExceptionRequest _request() =>
    TeacherBlitzAttemptExceptionRequest(
      reasonType: TeacherBlitzAttemptExceptionReasonType.technical,
      reason: 'The device lost power.',
    );
