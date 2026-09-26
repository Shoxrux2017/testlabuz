import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_lifecycle_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_lifecycle_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_lifecycle.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_schedule.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _keyA = '11111111-1111-4111-8111-111111111111';
const _keyB = '22222222-2222-4222-8222-222222222222';

void main() {
  setUpAll(InstitutionTimezone.initialize);

  group('Schedule', () {
    test('Draft schedules and adopts the returned Blitz', () async {
      final harness = _Harness();
      await harness.start();
      final listReads = harness.blitz.listRequests.length;

      await harness.controller.schedule(_schedule());

      expect(
        harness.blitz.scheduleRequests.single.request.scheduledAt,
        '2026-09-30T09:00:00+05:00',
      );
      expect(
        harness.state.status,
        TeacherBlitzLifecycleStatus.confirmedSuccess,
      );
      expect(harness.state.feedback, 'Blitz scheduled successfully.');
      expect(harness.detail.status, TeacherBlitzStatus.scheduled);
      await flushTeacherControllers();
      expect(harness.blitz.listRequests.length, listReads + 1);
      expect(harness.activity.isActive, isFalse);
    });

    test('the same Scheduled instant sends nothing', () async {
      final harness = _Harness(
        initial: teacherBlitz(
          status: TeacherBlitzStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 30, 4),
        ),
      );
      await harness.start();

      await harness.controller.schedule(_schedule());

      expect(harness.blitz.scheduleRequests, isEmpty);
      expect(harness.state.notice, 'Blitz is already scheduled for this time.');
    });

    test('a Draft already carrying the instant still schedules', () async {
      final harness = _Harness(
        initial: teacherBlitz(scheduledAt: DateTime.utc(2026, 9, 30, 4)),
      );
      await harness.start();

      await harness.controller.schedule(_schedule());

      expect(harness.blitz.scheduleRequests, hasLength(1));
    });

    test('a server-rejected time keeps the conflict definite', () async {
      final harness = _Harness(
        onSchedule: (_, _) async => throw _validationFailure('scheduled_at'),
      );
      await harness.start();

      await harness.controller.schedule(_schedule());

      expect(harness.state.status, TeacherBlitzLifecycleStatus.definiteFailure);
      expect(harness.state.conflictCode, ApiErrorCodes.validationFailed);
      expect(
        harness.state.notice,
        'The server rejected this scheduled time.\nChoose a future time in '
        'the Institution timezone and try again.',
      );
      expect(harness.blitz.scheduleRequests, hasLength(1));
    });

    test(
      'an uncertain schedule is success only for the exact instant',
      () async {
        for (final (current, confirmed) in [
          (
            teacherBlitz(
              status: TeacherBlitzStatus.scheduled,
              scheduledAt: DateTime.utc(2026, 9, 30, 4),
            ),
            true,
          ),
          (
            teacherBlitz(
              status: TeacherBlitzStatus.scheduled,
              scheduledAt: DateTime.utc(2026, 9, 30, 5),
            ),
            false,
          ),
        ]) {
          var reads = 0;
          final harness = _Harness(
            onFetch: (_) async {
              reads += 1;
              return reads == 1 ? teacherBlitz() : current;
            },
            onSchedule: (_, _) async =>
                throw const TeacherBlitzMutationOutcomeUnknownException(),
          );
          await harness.start();

          await harness.controller.schedule(_schedule());

          expect(harness.blitz.scheduleRequests, hasLength(1));
          if (confirmed) {
            expect(
              harness.state.status,
              TeacherBlitzLifecycleStatus.confirmedSuccess,
            );
          } else {
            expect(
              harness.state.status,
              TeacherBlitzLifecycleStatus.outcomeReview,
            );
            expect(
              harness.state.notice,
              'The schedule update could not be confirmed.\nReview the current '
              'Blitz schedule before trying again.',
            );
            expect(harness.state.canCheckCurrent, isTrue);
          }
        }
      },
    );

    test('a schedule conflict refreshes the Blitz without retrying', () async {
      var reads = 0;
      final harness = _Harness(
        onFetch: (_) async {
          reads += 1;
          return teacherBlitz(
            status: reads == 1
                ? TeacherBlitzStatus.draft
                : TeacherBlitzStatus.active,
          );
        },
        onSchedule: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.businessConflict,
          statusCode: 409,
        ),
      );
      await harness.start();

      await harness.controller.schedule(_schedule());

      expect(harness.state.status, TeacherBlitzLifecycleStatus.definiteFailure);
      expect(
        harness.state.notice,
        'Scheduling is not available in the current server state.\nRefresh '
        'the Blitz before trying again.',
      );
      expect(harness.detail.status, TeacherBlitzStatus.active);
      expect(harness.blitz.scheduleRequests, hasLength(1));
    });
  });

  group('Activate', () {
    test(
      'one confirmed activation uses one key and refreshes readers',
      () async {
        final harness = _Harness();
        await harness.start();
        final pairReads = harness.pairs.fetchTopicIds.length;

        await harness.controller.activate();
        await flushTeacherControllers();

        expect(harness.blitz.activateRequests.single.idempotencyKey, _keyA);
        expect(harness.keys.generated, 1);
        expect(harness.state.feedback, 'Blitz activated successfully.');
        expect(harness.detail.status, TeacherBlitzStatus.active);
        expect(harness.pairs.fetchTopicIds.length, pairReads + 1);
        expect(harness.state.canRetryActivation, isFalse);
      },
    );

    test('a fresh 200 in a later lifecycle is not a fresh success', () async {
      var reads = 0;
      final harness = _Harness(
        onFetch: (_) async {
          reads += 1;
          return teacherBlitz(
            status: reads == 1
                ? TeacherBlitzStatus.draft
                : TeacherBlitzStatus.closed,
          );
        },
        onActivate: (id, _) async =>
            teacherBlitz(id: id, status: TeacherBlitzStatus.closed),
      );
      await harness.start();

      await harness.controller.activate();

      expect(
        harness.state.status,
        isNot(TeacherBlitzLifecycleStatus.confirmedSuccess),
      );
      expect(harness.state.canRetryActivation, isFalse);
      expect(harness.blitz.fetchIds, hasLength(2));
      expect(harness.blitz.activateRequests, hasLength(1));
    });

    test(
      'an uncertain activation found Active is reconciled success',
      () async {
        var reads = 0;
        final harness = _Harness(
          onFetch: (_) async {
            reads += 1;
            return teacherBlitz(
              status: reads == 1
                  ? TeacherBlitzStatus.draft
                  : TeacherBlitzStatus.active,
            );
          },
          onActivate: (_, _) async =>
              throw const TeacherBlitzMutationOutcomeUnknownException(),
        );
        await harness.start();

        await harness.controller.activate();

        expect(
          harness.state.status,
          TeacherBlitzLifecycleStatus.confirmedSuccess,
        );
        expect(harness.state.feedback, 'Blitz is active.');
        expect(harness.state.canRetryActivation, isFalse);
        expect(harness.blitz.activateRequests, hasLength(1));
      },
    );

    test(
      'an uncertain activation still Draft keeps the key for Retry',
      () async {
        var activations = 0;
        final harness = _Harness(
          onActivate: (id, _) async {
            activations += 1;
            if (activations == 1) {
              throw const TeacherBlitzMutationOutcomeUnknownException();
            }
            return teacherBlitz(id: id, status: TeacherBlitzStatus.active);
          },
        );
        await harness.start();

        await harness.controller.activate();

        expect(harness.state.status, TeacherBlitzLifecycleStatus.outcomeReview);
        expect(harness.state.canRetryActivation, isTrue);
        expect(harness.blitz.activateRequests, hasLength(1));

        await harness.controller.activate();
        expect(harness.blitz.activateRequests, hasLength(1));

        await harness.controller.retryActivation();

        expect(harness.blitz.activateRequests.map((r) => r.idempotencyKey), [
          _keyA,
          _keyA,
        ]);
        expect(harness.keys.generated, 1);
        expect(harness.state.feedback, 'Blitz activated successfully.');
      },
    );

    test(
      'a same-key replay accepts a later Closed or Archived lifecycle',
      () async {
        for (final (status, feedback) in [
          (
            TeacherBlitzStatus.closed,
            'Activation was confirmed. This Blitz is now closed.',
          ),
          (
            TeacherBlitzStatus.archived,
            'Activation was confirmed. This Blitz is now archived.',
          ),
        ]) {
          var activations = 0;
          final harness = _Harness(
            onActivate: (id, _) async {
              activations += 1;
              if (activations == 1) {
                throw const TeacherBlitzMutationOutcomeUnknownException();
              }
              return teacherBlitz(id: id, status: status);
            },
          );
          await harness.start();
          await harness.controller.activate();

          await harness.controller.retryActivation();

          expect(
            harness.state.status,
            TeacherBlitzLifecycleStatus.confirmedSuccess,
          );
          expect(harness.state.feedback, feedback);
          expect(harness.detail.status, status);
          expect(harness.state.canRetryActivation, isFalse);
        }
      },
    );

    test(
      'a same-key replay projecting back to Scheduled is rejected',
      () async {
        var activations = 0;
        final harness = _Harness(
          onActivate: (id, _) async {
            activations += 1;
            if (activations == 1) {
              throw const TeacherBlitzMutationOutcomeUnknownException();
            }
            return _withStatus(
              teacherBlitz(id: id, status: TeacherBlitzStatus.active),
              TeacherBlitzStatus.scheduled,
            );
          },
        );
        await harness.start();
        await harness.controller.activate();

        await harness.controller.retryActivation();

        expect(
          harness.state.status,
          isNot(TeacherBlitzLifecycleStatus.confirmedSuccess),
        );
        expect(harness.detail.status, TeacherBlitzStatus.draft);
      },
    );

    test('Schedule and Archive keep an unresolved activation key', () async {
      var activations = 0;
      final harness = _Harness(
        onActivate: (id, _) async {
          activations += 1;
          if (activations == 1) {
            throw const TeacherBlitzMutationOutcomeUnknownException();
          }
          return teacherBlitz(id: id, status: TeacherBlitzStatus.active);
        },
      );
      await harness.start();
      await harness.controller.activate();
      expect(harness.state.canRetryActivation, isTrue);

      await harness.controller.schedule(_schedule());

      expect(harness.state.feedback, 'Blitz scheduled successfully.');
      expect(harness.state.canRetryActivation, isTrue);
      await harness.controller.activate();
      expect(harness.blitz.activateRequests, hasLength(1));

      await harness.controller.retryActivation();

      expect(harness.blitz.activateRequests.map((r) => r.idempotencyKey), [
        _keyA,
        _keyA,
      ]);
      expect(harness.keys.generated, 1);
    });

    test('an unreadable activation outcome blocks until checked', () async {
      var reads = 0;
      var activations = 0;
      final harness = _Harness(
        onFetch: (_) async {
          reads += 1;
          if (reads == 2) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherBlitz();
        },
        onActivate: (id, _) async {
          activations += 1;
          if (activations == 1) {
            throw const TeacherBlitzMutationOutcomeUnknownException();
          }
          return teacherBlitz(id: id, status: TeacherBlitzStatus.active);
        },
      );
      await harness.start();

      await harness.controller.activate();

      expect(harness.state.hasBlockingOutcome, isTrue);
      expect(harness.state.canRetryActivation, isFalse);
      expect(harness.activity.isActive, isTrue);
      await harness.controller.schedule(_schedule());
      expect(harness.blitz.scheduleRequests, isEmpty);

      await harness.controller.checkCurrentBlitz();

      expect(harness.state.hasBlockingOutcome, isFalse);
      expect(harness.state.canRetryActivation, isTrue);
      expect(harness.activity.isActive, isFalse);

      await harness.controller.retryActivation();
      expect(harness.blitz.activateRequests.map((r) => r.idempotencyKey), [
        _keyA,
        _keyA,
      ]);
      expect(harness.state.feedback, 'Blitz activated successfully.');
    });

    test('a same-key replay before activation is never accepted', () async {
      var activations = 0;
      final harness = _Harness(
        onActivate: (id, _) async {
          activations += 1;
          if (activations == 1) {
            throw const TeacherBlitzMutationOutcomeUnknownException();
          }
          return teacherBlitz(
            id: id,
            status: TeacherBlitzStatus.archived,
            archivedBeforeActivation: true,
          );
        },
      );
      await harness.start();
      await harness.controller.activate();

      await harness.controller.retryActivation();

      expect(
        harness.state.status,
        isNot(TeacherBlitzLifecycleStatus.confirmedSuccess),
      );
      expect(harness.detail.status, TeacherBlitzStatus.draft);
    });

    test('a definite failure clears the key and maps safe copy', () async {
      for (final (code, notice) in [
        (
          ApiErrorCodes.institutionSettingsIncomplete,
          "The Institution's Blitz timer-start setting is not configured.\n"
              'Ask the Institution Admin to complete the Blitz timer setting '
              'before activation.',
        ),
        (
          ApiErrorCodes.assessmentHasNoScoreablePoints,
          'This Blitz needs at least one scoreable Question before activation.'
              '\nReview the Questions and points.',
        ),
        (
          ApiErrorCodes.assessmentNotAssigned,
          'The server could not establish a valid assigned Student set.\n'
              'Review the Blitz assignment or current Group membership.',
        ),
        (
          ApiErrorCodes.officialCohortMismatch,
          "The official Blitz cohort does not match the Topic's established "
              'official cohort.\nRefresh the official pair and Blitz before '
              'continuing.',
        ),
        (
          ApiErrorCodes.idempotencyKeyReused,
          'The activation request could not be safely replayed.\nRefresh the '
              'Blitz before starting another activation.',
        ),
      ]) {
        var activations = 0;
        final harness = _Harness(
          onActivate: (id, _) async {
            activations += 1;
            if (activations == 1) {
              throw teacherServerFailure(code, statusCode: 409);
            }
            return teacherBlitz(id: id, status: TeacherBlitzStatus.active);
          },
        );
        await harness.start();

        await harness.controller.activate();

        expect(
          harness.state.status,
          TeacherBlitzLifecycleStatus.definiteFailure,
        );
        expect(harness.state.conflictCode, code);
        expect(harness.state.notice, notice, reason: code);
        expect(harness.state.canRetryActivation, isFalse);

        await harness.controller.activate();
        expect(harness.blitz.activateRequests.map((r) => r.idempotencyKey), [
          _keyA,
          _keyB,
        ], reason: code);
      }
    });
  });

  group('Close and Archive', () {
    test('Close confirms an Active Blitz as Closed', () async {
      final harness = _Harness(
        initial: teacherBlitz(status: TeacherBlitzStatus.active),
      );
      await harness.start();

      await harness.controller.close();

      expect(harness.blitz.closeIds, [_blitzId]);
      expect(harness.state.feedback, 'Blitz closed successfully.');
      expect(harness.detail.status, TeacherBlitzStatus.closed);
    });

    test(
      'an uncertain Close or Archive reconciles from the exact GET',
      () async {
        for (final (initial, action, current, confirmed) in [
          (
            TeacherBlitzStatus.active,
            TeacherBlitzLifecycleAction.close,
            TeacherBlitzStatus.closed,
            true,
          ),
          (
            TeacherBlitzStatus.active,
            TeacherBlitzLifecycleAction.close,
            TeacherBlitzStatus.active,
            false,
          ),
          (
            TeacherBlitzStatus.closed,
            TeacherBlitzLifecycleAction.archive,
            TeacherBlitzStatus.archived,
            true,
          ),
          (
            TeacherBlitzStatus.closed,
            TeacherBlitzLifecycleAction.archive,
            TeacherBlitzStatus.closed,
            false,
          ),
        ]) {
          var reads = 0;
          final harness = _Harness(
            onFetch: (_) async {
              reads += 1;
              return teacherBlitz(status: reads == 1 ? initial : current);
            },
            onClose: (_) async =>
                throw const TeacherBlitzMutationOutcomeUnknownException(),
            onArchive: (_) async =>
                throw const TeacherBlitzMutationOutcomeUnknownException(),
          );
          await harness.start();

          if (action == TeacherBlitzLifecycleAction.close) {
            await harness.controller.close();
          } else {
            await harness.controller.archive();
          }

          expect(
            harness.state.status,
            confirmed
                ? TeacherBlitzLifecycleStatus.confirmedSuccess
                : TeacherBlitzLifecycleStatus.outcomeReview,
            reason: '$action -> $current',
          );
          expect(
            harness.blitz.closeIds.length + harness.blitz.archiveIds.length,
            1,
          );
        }
      },
    );

    test('an Archive conflict refreshes the Blitz and the pair', () async {
      final harness = _Harness(
        onArchive: (_) async => throw teacherServerFailure(
          ApiErrorCodes.businessConflict,
          statusCode: 409,
        ),
      );
      await harness.start();
      final pairReads = harness.pairs.fetchTopicIds.length;

      await harness.controller.archive();
      await flushTeacherControllers();

      expect(
        harness.state.notice,
        'This Blitz cannot be archived in the current server state.\nRefresh '
        'the Blitz and official pair before trying again.',
      );
      expect(harness.pairs.fetchTopicIds.length, pairReads + 1);
    });

    test('Close definite conflicts map the delivered codes', () async {
      for (final (code, notice) in [
        (ApiErrorCodes.taskNotActive, 'This Blitz is no longer active.'),
        (ApiErrorCodes.taskArchived, 'This Blitz is archived.'),
        (
          ApiErrorCodes.topicNotEditable,
          'The Topic is no longer available for this action.',
        ),
      ]) {
        final harness = _Harness(
          initial: teacherBlitz(status: TeacherBlitzStatus.active),
          onClose: (_) async =>
              throw teacherServerFailure(code, statusCode: 409),
        );
        await harness.start();

        await harness.controller.close();

        expect(harness.state.notice, notice, reason: code);
        expect(harness.blitz.closeIds, hasLength(1));
      }
    });
  });

  group('safety', () {
    test('404 marks the Blitz unavailable', () async {
      final harness = _Harness(
        onArchive: (_) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
        initial: teacherBlitz(status: TeacherBlitzStatus.closed),
      );
      await harness.start();

      await harness.controller.archive();

      expect(harness.state.status, TeacherBlitzLifecycleStatus.unavailable);
      expect(harness.state.notice, 'This Blitz is no longer available.');
      expect(
        harness.container
            .read(teacherBlitzDetailControllerProvider(_target()))
            .status,
        TeacherBlitzDetailStatus.notFound,
      );
    });

    test('a completion after a session change cannot publish', () async {
      final pending = Completer<TeacherBlitz>();
      final harness = _Harness(onActivate: (_, _) => pending.future);
      await harness.start();
      unawaited(harness.controller.activate());
      await flushTeacherControllers();

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(teacherBlitz(status: TeacherBlitzStatus.active));
      await flushTeacherControllers();

      expect(harness.state.feedback, isNull);
      expect(
        harness.container
            .read(teacherBlitzDetailControllerProvider(_target()))
            .blitz
            ?.status,
        isNot(TeacherBlitzStatus.active),
      );
    });

    test(
      'leaving the route releases the lease and drops completions',
      () async {
        final pending = Completer<TeacherBlitz>();
        final harness = _Harness(onActivate: (_, _) => pending.future);
        await harness.start();
        unawaited(harness.controller.activate());
        await flushTeacherControllers();
        expect(harness.activity.isActive, isTrue);

        harness.controller.leaveRoute();
        pending.complete(teacherBlitz(status: TeacherBlitzStatus.active));
        await flushTeacherControllers();

        expect(harness.activity.isActive, isFalse);
        expect(harness.state.feedback, isNull);
        expect(harness.detail.status, TeacherBlitzStatus.draft);
      },
    );

    test(
      'a pending Question reload does not block lifecycle actions',
      () async {
        final harness = _Harness();
        await harness.start();
        harness.container
            .read(teacherQuestionMutationActivityProvider(_target()).notifier)
            .requireAuthoritativeReload();

        await harness.controller.activate();

        expect(harness.blitz.activateRequests, hasLength(1));
      },
    );

    test('one same-route mutation at a time', () async {
      final pending = Completer<TeacherBlitz>();
      final harness = _Harness(onActivate: (_, _) => pending.future);
      await harness.start();
      unawaited(harness.controller.activate());
      await flushTeacherControllers();

      await harness.controller.schedule(_schedule());
      await harness.controller.archive();
      expect(harness.blitz.scheduleRequests, isEmpty);
      expect(harness.blitz.archiveIds, isEmpty);

      pending.complete(teacherBlitz(status: TeacherBlitzStatus.active));
      await flushTeacherControllers();
      expect(harness.activity.isActive, isFalse);
    });

    test('an active Question mutation blocks lifecycle actions', () async {
      final harness = _Harness();
      await harness.start();
      final lease = harness.container
          .read(teacherQuestionMutationActivityProvider(_target()).notifier)
          .begin(TeacherQuestionMutationOperation.delete);
      expect(lease, isNotNull);

      await harness.controller.activate();

      expect(harness.blitz.activateRequests, isEmpty);
    });

    test('mobile never owns lifecycle mutations', () async {
      final harness = _Harness(surface: AppDeviceSurface.mobile);
      await harness.start();

      await harness.controller.activate();

      expect(harness.blitz.activateRequests, isEmpty);
    });
  });
}

TeacherBlitzRouteTarget _target() {
  return TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId);
}

TeacherBlitzScheduleRequest _schedule() {
  return TeacherBlitzScheduleRequest.fromWallClock(
    const InstitutionWallClock(
      year: 2026,
      month: 9,
      day: 30,
      hour: 9,
      minute: 0,
    ),
    'Asia/Tashkent',
  );
}

ApiRequestException _validationFailure(String field) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: 422,
      error: ApiErrorResponse(
        message: 'Invalid.',
        code: ApiErrorCodes.validationFailed,
        fieldErrors: {
          field: ['Rejected.'],
        },
        requestId: null,
      ),
    ),
  );
}

class _SequenceKeys implements IdempotencyKeyGenerator {
  final _keys = [_keyA, _keyB];
  var generated = 0;

  @override
  String generate() => _keys[generated++];
}

class _Harness {
  _Harness({
    TeacherBlitz? initial,
    Future<TeacherBlitz> Function(String blitzId)? onFetch,
    Future<TeacherBlitz> Function(
      String blitzId,
      TeacherBlitzScheduleRequest request,
    )?
    onSchedule,
    Future<TeacherBlitz> Function(String blitzId, String key)? onActivate,
    Future<TeacherBlitz> Function(String blitzId)? onClose,
    Future<TeacherBlitz> Function(String blitzId)? onArchive,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ),
       blitz = FakeTeacherBlitzRepository(
         onFetch: onFetch ?? (_) async => initial ?? teacherBlitz(),
       ) {
    blitz
      ..onSchedule = onSchedule
      ..onActivate = onActivate
      ..onClose = onClose
      ..onArchive = onArchive;
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherBlitzRepositoryProvider.overrideWithValue(blitz),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(pairs),
        idempotencyKeyGeneratorProvider.overrideWithValue(keys),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherBlitzRepository blitz;
  final pairs = FakeTeacherTopicResultPairRepository();
  final keys = _SequenceKeys();
  late final ProviderContainer container;
  late ProviderSubscription<TeacherBlitzLifecycleState> _subscription;

  Future<void> start() async {
    container
      ..listen(teacherBlitzDetailControllerProvider(_target()), (_, _) {})
      ..listen(teacherBlitzListControllerProvider(_topicId), (_, _) {})
      ..listen(teacherTopicResultPairControllerProvider(_topicId), (_, _) {})
      ..listen(teacherBlitzRouteMutationActivityProvider(_target()), (_, _) {})
      ..listen(teacherQuestionMutationActivityProvider(_target()), (_, _) {});
    _subscription = container.listen(
      teacherBlitzLifecycleControllerProvider(_target()),
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
  }

  TeacherBlitzLifecycleController get controller => container.read(
    teacherBlitzLifecycleControllerProvider(_target()).notifier,
  );

  TeacherBlitzLifecycleState get state => _subscription.read();

  TeacherBlitz get detail =>
      container.read(teacherBlitzDetailControllerProvider(_target())).blitz!;

  TeacherBlitzRouteMutationActivityState get activity =>
      container.read(teacherBlitzRouteMutationActivityProvider(_target()));
}

/// A Blitz carrying activation evidence under another lifecycle status.
TeacherBlitz _withStatus(TeacherBlitz source, TeacherBlitzStatus status) {
  return TeacherBlitz(
    id: source.id,
    topicId: source.topicId,
    groupId: source.groupId,
    title: source.title,
    description: source.description,
    studentInstructions: source.studentInstructions,
    assignmentMode: source.assignmentMode,
    studentIds: source.studentIds,
    totalPossiblePoints: source.totalPossiblePoints,
    durationSeconds: source.durationSeconds,
    scheduledAt: source.scheduledAt,
    institutionTimezone: source.institutionTimezone,
    status: status,
    timerStartModeSnapshot: source.timerStartModeSnapshot,
    attemptPolicy: source.attemptPolicy,
    activatedAt: source.activatedAt,
    synchronizedEndsAt: source.synchronizedEndsAt,
    closedAt: source.closedAt,
    archivedAt: source.archivedAt,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
    questions: source.questions,
  );
}
