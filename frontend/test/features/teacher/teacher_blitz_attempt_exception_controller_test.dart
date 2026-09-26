import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_attempt_exception_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_monitoring_state.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_attempt_exception.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_monitoring.dart';

import 'teacher_blitz_json_fixtures.dart';
import 'teacher_blitz_monitoring_fixtures.dart';
import 'teacher_blitz_monitoring_test_support.dart';
import 'teacher_test_support.dart';

const _granted = 'Additional Blitz attempt granted.';
const _uncertain =
    'We could not confirm whether the additional attempt was granted.';
const _monitoringEnded =
    'Live monitoring is no longer available for this Blitz. Retry the '
    'original grant request to confirm whether it was recorded.';

void main() {
  group('eligibility', () {
    monitoringTest('a desktop candidate grant sends one exact request', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      harness.repository.onFetchMonitoring = (_) async => _grantedSnapshot();

      await _grant(harness);

      final sent = harness.repository.grantRequests.single;
      expect(sent.blitzId, blitzJsonId);
      expect(sent.studentId, monitoringStudentA);
      expect(sent.idempotencyKey, monitoringGrantKeyA);
      expect(sent.request.toJson(), {
        'reason_type': 'other_valid',
        'reason': 'Fire alarm evacuation.',
      });
      expect(harness.keys.generated, 1);
      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.confirmed,
      );
      expect(harness.grantState.message, _granted);
      expect(harness.repository.monitoringIds, hasLength(2));
      expect(
        harness.state.monitoring!
            .studentById(monitoringStudentA)!
            .attemptException,
        isNotNull,
      );
    });

    monitoringTest('mobile never prepares or sends a grant', (harness) async {
      await _startWithCandidate(harness);

      expect(harness.grant.prepare(monitoringStudentA), isNull);
      expect(harness.repository.grantRequests, isEmpty);
      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.idle,
      );
    }, surface: AppDeviceSurface.mobile);

    monitoringTest('a ticket taken on desktop never sends on mobile', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      final ticket = harness.grant.prepare(monitoringStudentA)!;

      harness.container
          .read(teacherTestSurfaceProvider.notifier)
          .change(AppDeviceSurface.mobile);
      await harness.settle();
      await harness.grant.grant(ticket, _request());

      expect(harness.repository.grantRequests, isEmpty);
      expect(harness.keys.generated, 0);
    });

    monitoringTest('only a finalized normal attempt is a candidate', (
      harness,
    ) async {
      harness.repository.onFetchMonitoring = (_) async => teacherMonitoring(
        students: [
          notStartedRowJson(monitoringStudentA),
          inProgressRowJson(monitoringStudentB),
          terminalRowJson(
            monitoringStudentC,
            attemptNumber: 2,
            attemptException: monitoringExceptionJson(
              replacementAttemptId: monitoringAttemptTwo,
            ),
          ),
        ],
      );
      await harness.start();

      for (final id in [
        monitoringStudentA,
        monitoringStudentB,
        monitoringStudentC,
      ]) {
        expect(harness.grant.prepare(id), isNull);
      }
    });

    final pendingDetail = Completer<TeacherBlitz>();
    monitoringTest(
      'a Blitz detail still checking allows no grant',
      (harness) async {
        await harness.start();

        expect(harness.grant.prepare(monitoringStudentA), isNull);
      },
      onFetch: (_) => pendingDetail.future,
    );

    monitoringTest('losing the parent under the dialog sends nothing', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      final ticket = harness.grant.prepare(monitoringStudentA)!;

      harness.markDetailNotFound();
      await harness.settle();
      await harness.grant.grant(ticket, _request());

      expect(harness.grant.prepare(monitoringStudentA), isNull);
      expect(harness.repository.grantRequests, isEmpty);
      expect(harness.keys.generated, 0);
    });

    monitoringTest(
      'a transient detail failure allows no grant',
      (harness) async {
        await harness.start();

        expect(harness.grant.prepare(monitoringStudentA), isNull);
        expect(harness.repository.monitoringIds, isEmpty);
      },
      onFetch: (_) async =>
          throw teacherLocalFailure(ApiFailureKind.connection),
    );

    monitoringTest('a row that changed under the dialog is not sent', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      final ticket = harness.grant.prepare(monitoringStudentA)!;
      harness.repository.onFetchMonitoring = (_) async => _grantedSnapshot();
      harness.monitoring.refresh();
      await harness.settle();

      await harness.grant.grant(ticket, _request());

      expect(harness.repository.grantRequests, isEmpty);
      expect(harness.keys.generated, 0);
      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.failure,
      );
      expect(
        harness.grantState.message,
        "The Student's Blitz status changed. Review current monitoring before "
        'granting an additional attempt.',
      );
    });

    monitoringTest('a ticket from an older route ownership is ignored', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      final ticket = harness.grant.prepare(monitoringStudentA)!;

      harness.monitoring.leaveLiveRoute();
      await harness.grant.grant(ticket, _request());

      expect(harness.repository.grantRequests, isEmpty);
    });
  });

  group('confirmed outcomes', () {
    for (final (name, exception, message) in [
      (
        'a historical grant that can no longer start',
        teacherGrant(replacementAttemptAvailable: false),
        'Additional-attempt grant confirmed, but the Blitz no longer allows '
            'the Student to start that attempt.',
      ),
      (
        'a grant whose replacement already started',
        teacherGrant(replacementAttemptId: monitoringAttemptTwo),
        'Additional-attempt grant confirmed. The additional attempt has '
            'already been started.',
      ),
    ]) {
      monitoringTest('$name is confirmed', (harness) async {
        await _startWithCandidate(harness);
        harness.repository.onGrantAttemptException = (_, _, _, _) async =>
            exception;

        await _grant(harness);

        expect(
          harness.grantState.status,
          TeacherBlitzAttemptExceptionStatus.confirmed,
        );
        expect(harness.grantState.message, message);
      });
    }
  });

  group('unknown outcome', () {
    monitoringTest('Retry resends the same key and request', (harness) async {
      await _startWithCandidate(harness);
      harness.repository.onGrantAttemptException = (_, _, _, _) async =>
          throw const TeacherBlitzAttemptExceptionOutcomeUnknownException();

      await _grant(harness);

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.uncertain,
      );
      expect(harness.grantState.message, _uncertain);
      expect(harness.grantState.canRetry, isTrue);
      expect(harness.grantState.canCheckMonitoring, isTrue);
      expect(harness.grant.prepare(monitoringStudentB), isNull);
      await harness.tick();
      expect(harness.repository.monitoringIds, hasLength(1));

      harness.repository.onGrantAttemptException = null;
      await harness.grant.retryGrant();

      final requests = harness.repository.grantRequests;
      expect(requests, hasLength(2));
      expect(requests.last.idempotencyKey, monitoringGrantKeyA);
      expect(requests.last.request, same(requests.first.request));
      expect(requests.last.studentId, monitoringStudentA);
      expect(harness.keys.generated, 1);
      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.confirmed,
      );
    });

    monitoringTest('an unexpected failure is also uncertain', (harness) async {
      await _startWithCandidate(harness);
      harness.repository.onGrantAttemptException = (_, _, _, _) async =>
          throw StateError('boom');

      await _grant(harness);

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.uncertain,
      );
    });

    monitoringTest('Check monitoring confirms a recorded exception', (
      harness,
    ) async {
      await _startUncertain(harness);
      harness.repository.onFetchMonitoring = (_) async => _grantedSnapshot();

      await harness.grant.checkMonitoring();

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.confirmed,
      );
      expect(
        harness.grantState.message,
        'An additional attempt is now granted to this Student.',
      );
      expect(harness.repository.grantRequests, hasLength(1));
      expect(harness.state.livePollingEnabled, isTrue);
    });

    monitoringTest('Check monitoring without the exception stays unknown', (
      harness,
    ) async {
      await _startUncertain(harness);

      await harness.grant.checkMonitoring();

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.uncertain,
      );
      expect(harness.grantState.canCheckMonitoring, isTrue);
      harness.repository.onGrantAttemptException = null;
      await harness.grant.retryGrant();
      expect(
        harness.repository.grantRequests.last.idempotencyKey,
        monitoringGrantKeyA,
      );
    });

    for (final (name, code) in [
      ('closed', ApiErrorCodes.taskClosed),
      ('archived', ApiErrorCodes.taskArchived),
    ]) {
      monitoringTest(
        'a $name Blitz keeps the key until a same-key Retry resolves it',
        (harness) async {
          await _startUncertain(harness);
          harness.repository.onFetchMonitoring = (_) async =>
              throw teacherServerFailure(code, statusCode: 409);

          await harness.grant.checkMonitoring();

          expect(harness.state.hasEnded, isTrue);
          expect(
            harness.grantState.status,
            TeacherBlitzAttemptExceptionStatus.uncertain,
          );
          expect(harness.grantState.message, _monitoringEnded);
          expect(harness.grantState.canRetry, isTrue);
          expect(harness.grantState.canCheckMonitoring, isFalse);

          harness.repository.onGrantAttemptException = (_, _, _, _) async =>
              teacherGrant(replacementAttemptAvailable: false);
          await harness.grant.retryGrant();

          expect(
            harness.repository.grantRequests.last.idempotencyKey,
            monitoringGrantKeyA,
          );
          expect(
            harness.grantState.status,
            TeacherBlitzAttemptExceptionStatus.confirmed,
          );
          expect(harness.repository.monitoringIds, hasLength(2));
        },
      );
    }

    monitoringTest('a same-key Retry of an uncommitted grant is not allowed', (
      harness,
    ) async {
      await _startUncertain(harness);
      harness.repository.onGrantAttemptException = (_, _, _, _) async =>
          throw teacherServerFailure(
            ApiErrorCodes.blitzAttemptExceptionNotAllowed,
            statusCode: 409,
          );

      await harness.grant.retryGrant();
      await harness.grant.retryGrant();

      expect(harness.repository.grantRequests, hasLength(2));
      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.failure,
      );
    });
  });

  group('definite failures', () {
    monitoringTest('already granted is confirmed from monitoring', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      harness.repository.onGrantAttemptException = (_, _, _, _) async =>
          throw teacherServerFailure(
            ApiErrorCodes.blitzAttemptExceptionAlreadyGranted,
            statusCode: 409,
          );
      harness.repository.onFetchMonitoring = (_) async => _grantedSnapshot();

      await _grant(harness);

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.confirmed,
      );
      expect(
        harness.grantState.message,
        'An additional attempt has already been granted to this Student.',
      );
      expect(harness.repository.monitoringIds, hasLength(2));
    });

    monitoringTest('already granted that monitoring cannot show is a failure', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      harness.repository.onGrantAttemptException = (_, _, _, _) async =>
          throw teacherServerFailure(
            ApiErrorCodes.blitzAttemptExceptionAlreadyGranted,
            statusCode: 409,
          );

      await _grant(harness);
      await harness.grant.retryGrant();

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.failure,
      );
      expect(harness.repository.grantRequests, hasLength(1));
    });

    for (final (code, status, message) in [
      (
        ApiErrorCodes.blitzAttemptExceptionNotAllowed,
        409,
        'An additional attempt cannot be granted in the current Blitz state.\n'
            "Refresh monitoring to review the Student's current attempt.",
      ),
      (
        ApiErrorCodes.blitzNormalAttemptRequired,
        409,
        'The Student must have a normal Blitz attempt before an additional '
            'attempt can be granted.',
      ),
      (
        ApiErrorCodes.idempotencyKeyReused,
        409,
        'The additional-attempt request could not be replayed safely.\n'
            'Refresh monitoring before trying again.',
      ),
      (
        ApiErrorCodes.resourceNotFound,
        404,
        'The Student or Blitz is no longer available for this action.',
      ),
    ]) {
      monitoringTest('$code clears the key and refreshes monitoring', (
        harness,
      ) async {
        await _startWithCandidate(harness);
        harness.repository.onGrantAttemptException = (_, _, _, _) async =>
            throw teacherServerFailure(code, statusCode: status);

        await _grant(harness);
        await harness.grant.retryGrant();

        expect(
          harness.grantState.status,
          TeacherBlitzAttemptExceptionStatus.failure,
        );
        expect(harness.grantState.message, message);
        expect(harness.repository.grantRequests, hasLength(1));
        expect(harness.repository.monitoringIds, hasLength(2));
        expect(harness.state.livePollingEnabled, isTrue);
      });
    }

    monitoringTest('a session failure clears the grant and re-bootstraps', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      harness.repository.onGrantAttemptException = (_, _, _, _) async =>
          throw teacherServerFailure(ApiErrorCodes.passwordChangeRequired);

      await _grant(harness);
      await harness.grant.retryGrant();

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.idle,
      );
      expect(harness.auth.bootstrapCalls, 1);
      expect(harness.repository.grantRequests, hasLength(1));
    });
  });

  group('stale completions', () {
    monitoringTest('a grant finishing after a session switch never publishes', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      final pending = Completer<TeacherBlitzAttemptException>();
      harness.repository.onGrantAttemptException = (_, _, _, _) =>
          pending.future;
      unawaited(
        harness.grant.grant(
          harness.grant.prepare(monitoringStudentA)!,
          _request(),
        ),
      );
      await harness.settle();

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await harness.settle();
      pending.complete(teacherGrant());
      await harness.settle();

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.idle,
      );
      expect(harness.grantState.message, isNull);
    });

    monitoringTest('a grant finishing after parent loss never publishes', (
      harness,
    ) async {
      await _startWithCandidate(harness);
      final pending = Completer<TeacherBlitzAttemptException>();
      harness.repository.onGrantAttemptException = (_, _, _, _) =>
          pending.future;
      unawaited(
        harness.grant.grant(
          harness.grant.prepare(monitoringStudentA)!,
          _request(),
        ),
      );
      await harness.settle();

      harness.markDetailNotFound();
      await harness.settle();
      pending.complete(teacherGrant());
      await harness.settle();

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.idle,
      );
      expect(harness.state.status, TeacherBlitzMonitoringStatus.notFound);
    });

    monitoringTest('the Check monitoring read is dropped after a switch', (
      harness,
    ) async {
      await _startUncertain(harness);
      final pending = Completer<TeacherBlitzMonitoring>();
      harness.repository.onFetchMonitoring = (_) => pending.future;
      unawaited(harness.grant.checkMonitoring());
      await harness.settle();

      harness.auth.logOut();
      await harness.settle();
      pending.complete(_grantedSnapshot());
      await harness.settle();

      expect(
        harness.grantState.status,
        TeacherBlitzAttemptExceptionStatus.idle,
      );
      expect(harness.state.monitoring, isNull);
    });
  });
}

TeacherBlitzAttemptExceptionRequest _request() =>
    TeacherBlitzAttemptExceptionRequest(
      reasonType: TeacherBlitzAttemptExceptionReasonType.otherValid,
      reason: '  Fire alarm evacuation. ',
    );

TeacherBlitzMonitoring _grantedSnapshot() => teacherMonitoring(
  students: [
    notStartedRowJson(
      monitoringStudentA,
      remainingSeconds: null,
      attemptException: monitoringExceptionJson(),
    ),
  ],
);

Future<void> _startWithCandidate(MonitoringHarness harness) async {
  harness.repository.onFetchMonitoring = (_) async => teacherMonitoring(
    students: [
      terminalRowJson(monitoringStudentA, fullName: 'Aziza Karimova'),
      terminalRowJson(
        monitoringStudentB,
        fullName: 'Bekzod Aliyev',
        status: 'waiting_for_teacher_review',
        finalizationReason: 'timeout_auto_submit',
      ),
    ],
  );
  await harness.start();
}

Future<void> _grant(MonitoringHarness harness) async {
  final ticket = harness.grant.prepare(monitoringStudentA)!;
  await harness.grant.grant(ticket, _request());
  await harness.settle();
}

Future<void> _startUncertain(MonitoringHarness harness) async {
  await _startWithCandidate(harness);
  harness.repository.onGrantAttemptException = (_, _, _, _) async =>
      throw const TeacherBlitzAttemptExceptionOutcomeUnknownException();
  await _grant(harness);
  expect(
    harness.grantState.status,
    TeacherBlitzAttemptExceptionStatus.uncertain,
  );
}
