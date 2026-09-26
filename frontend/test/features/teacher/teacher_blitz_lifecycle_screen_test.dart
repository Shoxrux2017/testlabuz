import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_detail_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _otherBlitzId = '80000000-0000-0000-0000-000000000002';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _key = '11111111-1111-4111-8111-111111111111';

void main() {
  setUpAll(InstitutionTimezone.initialize);

  group('desktop lifecycle actions', () {
    testWidgets('each status shows only its own lifecycle actions', (
      tester,
    ) async {
      for (final (status, visible) in [
        (TeacherBlitzStatus.draft, ['Schedule', 'Activate', 'Archive']),
        (TeacherBlitzStatus.scheduled, ['Reschedule', 'Activate', 'Archive']),
        (TeacherBlitzStatus.active, ['Close']),
        (TeacherBlitzStatus.closed, ['Archive']),
        (TeacherBlitzStatus.archived, <String>[]),
      ]) {
        await _pump(tester, blitz: _blitz(status));
        await tester.pumpAndSettle();

        for (final label in [
          'Schedule',
          'Reschedule',
          'Activate',
          'Close',
          'Archive',
        ]) {
          expect(
            find.text(label),
            visible.contains(label) ? findsOneWidget : findsNothing,
            reason: '${status.value}: $label',
          );
        }
        expect(
          find.text('Monitor'),
          status == TeacherBlitzStatus.active ? findsOneWidget : findsNothing,
          reason: '${status.value}: Monitor',
        );
        for (final absent in ['Grant exception', 'Remaining']) {
          expect(find.text(absent), findsNothing);
        }
      }
    });

    testWidgets('scheduling states it never activates automatically', (
      tester,
    ) async {
      await _pump(tester, blitz: _blitz(TeacherBlitzStatus.draft));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Scheduling records the planned Blitz time.\nThe Blitz does not '
          'start automatically.\nThe Teacher must still activate it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('confirmation dialogs explain runtime effects first', (
      tester,
    ) async {
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();

      await _tapButton(tester, 'teacherBlitzActivateButton');
      expect(find.text('Activate Blitz?'), findsOneWidget);
      expect(
        find.textContaining(
          "The server will snapshot the Institution's current Blitz "
          'timer-start mode.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'The scheduled time does not activate the Blitz automatically.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.activateRequests, isEmpty);

      await _pump(tester, blitz: _blitz(TeacherBlitzStatus.active));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzCloseButton');
      expect(find.text('Close Blitz?'), findsOneWidget);
      expect(
        find.textContaining(
          'The server will freeze any existing in-progress Student attempts.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a confirmed activation shows progress, then feedback', (
      tester,
    ) async {
      final pending = Completer<TeacherBlitz>();
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
        onActivate: (_, _) => pending.future,
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();

      await _tapButton(tester, 'teacherBlitzActivateButton');
      await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
      await tester.pump();

      expect(
        find.byKey(const Key('teacherBlitzLifecycleProgress')),
        findsOneWidget,
      );
      expect(_button(tester, 'teacherBlitzScheduleButton'), isNull);
      expect(repository.activateRequests.single.idempotencyKey, _key);

      pending.complete(_blitz(TeacherBlitzStatus.active));
      await tester.pumpAndSettle();

      expect(find.text('Blitz activated successfully.'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Activate'), findsNothing);
    });

    testWidgets('Monitor waits while a lifecycle action is in flight', (
      tester,
    ) async {
      final pending = Completer<TeacherBlitz>();
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async => _blitz(TeacherBlitzStatus.active),
        onClose: (_) => pending.future,
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      expect(_button(tester, 'teacherBlitzMonitorButton'), isNotNull);

      await _tapButton(tester, 'teacherBlitzCloseButton');
      await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
      await tester.pump();

      expect(_button(tester, 'teacherBlitzMonitorButton'), isNull);
      pending.complete(_blitz(TeacherBlitzStatus.closed));
      await tester.pumpAndSettle();
      expect(find.text('Monitor'), findsNothing);
    });

    testWidgets('a same-key replay returning Closed adopts Closed', (
      tester,
    ) async {
      var activations = 0;
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
        onActivate: (_, _) async {
          activations += 1;
          if (activations == 1) {
            throw const TeacherBlitzMutationOutcomeUnknownException();
          }
          return _blitz(TeacherBlitzStatus.closed);
        },
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzActivateButton');
      await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The activation result could not be confirmed.\nReview the current '
          'Blitz before trying again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Check current Blitz'), findsOneWidget);
      expect(find.text('Activate'), findsNothing);

      await _tapButton(tester, 'teacherBlitzRetryActivationButton');

      expect(
        find.text('Activation was confirmed. This Blitz is now closed.'),
        findsOneWidget,
      );
      expect(repository.activateRequests.map((r) => r.idempotencyKey), [
        _key,
        _key,
      ]);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Activate'), findsNothing);
      expect(find.text('Retry activation'), findsNothing);
    });

    testWidgets('a same-key replay returning Archived shows no lifecycle', (
      tester,
    ) async {
      var activations = 0;
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
        onActivate: (_, _) async {
          activations += 1;
          if (activations == 1) {
            throw const TeacherBlitzMutationOutcomeUnknownException();
          }
          return _blitz(TeacherBlitzStatus.archived);
        },
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzActivateButton');
      await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
      await tester.pumpAndSettle();

      await _tapButton(tester, 'teacherBlitzRetryActivationButton');

      expect(
        find.text('Activation was confirmed. This Blitz is now archived.'),
        findsOneWidget,
      );
      for (final label in ['Schedule', 'Activate', 'Close', 'Archive']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('an unreadable outcome disables authoring until checked', (
      tester,
    ) async {
      var reads = 0;
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async {
          reads += 1;
          if (reads == 2) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return _blitz(TeacherBlitzStatus.draft);
        },
        onActivate: (_, _) async =>
            throw const TeacherBlitzMutationOutcomeUnknownException(),
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzActivateButton');
      await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
      await tester.pumpAndSettle();

      expect(find.text('Check current Blitz'), findsOneWidget);
      expect(_textButton(tester, 'teacherBlitzEditButton'), isNull);
      expect(_textButton(tester, 'teacherBlitzManageQuestionsButton'), isNull);
      expect(_button(tester, 'teacherBlitzScheduleButton'), isNull);

      await _tapButton(tester, 'teacherBlitzCheckCurrentButton');

      expect(_textButton(tester, 'teacherBlitzEditButton'), isNotNull);
      expect(find.text('Retry activation'), findsOneWidget);
    });

    testWidgets('Refresh clears a settled lifecycle notice', (tester) async {
      await _pump(
        tester,
        blitz: _blitz(
          TeacherBlitzStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 30, 4),
        ),
      );
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzScheduleButton');
      await tester.tap(
        find.byKey(const Key('teacherBlitzScheduleSubmitButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Blitz is already scheduled for this time.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('teacherBlitzDetailRefreshButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Blitz is already scheduled for this time.'),
        findsNothing,
      );
    });

    testWidgets('a scoreable-points conflict offers Manage Questions', (
      tester,
    ) async {
      await _pump(
        tester,
        repository: FakeTeacherBlitzRepository(
          onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
          onActivate: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.assessmentHasNoScoreablePoints,
            statusCode: 409,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzActivateButton');
      await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherBlitzLifecycleConflictAction')),
        findsOneWidget,
      );
      expect(find.text('Check current Blitz'), findsNothing);
      expect(find.text('Retry activation'), findsNothing);
    });
  });

  group('official Blitz', () {
    testWidgets('no pair guides the Teacher to the official Homework', (
      tester,
    ) async {
      await _pump(tester, blitz: _blitz(TeacherBlitzStatus.draft));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Choose the Topic's official Homework first.\nThen this Blitz can be "
          'designated as the official Blitz.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherBlitzSetOfficialButton')),
        findsNothing,
      );
    });

    testWidgets('set, locked fill and replace confirm then publish', (
      tester,
    ) async {
      for (final (pair, label, confirmation) in [
        (
          _pair(),
          'Set as Official Blitz',
          'The current official Homework will be preserved.',
        ),
        (
          _pair(lockedAt: DateTime.utc(2026, 9, 20)),
          'Set as Official Blitz',
          "This Topic's official cohort is already locked.",
        ),
        (
          _pair(blitzId: _otherBlitzId),
          'Replace Official Blitz',
          'The official Homework will remain unchanged.',
        ),
      ]) {
        final pairs = FakeTeacherTopicResultPairRepository(
          onFetch: (_) async => pair,
        );
        await _pump(
          tester,
          blitz: _blitz(TeacherBlitzStatus.draft),
          pairs: pairs,
        );
        await tester.pumpAndSettle();

        expect(find.text(label), findsOneWidget);
        await _tapButton(tester, 'teacherBlitzSetOfficialButton');
        expect(find.textContaining(confirmation), findsOneWidget);
        await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
        await tester.pumpAndSettle();

        expect(pairs.setOfficialBlitzRequests.single.homeworkId, _homeworkId);
        expect(
          find.text('Official Blitz updated successfully.'),
          findsOneWidget,
        );
        expect(find.text('Official'), findsOneWidget);
        expect(
          find.byKey(const Key('teacherBlitzArchiveButton')),
          findsNothing,
        );
        expect(
          find.text(
            'Official Blitz must be activated/closed before it can be '
            'archived.',
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('a populated locked pair is read-only', (tester) async {
      await _pump(
        tester,
        blitz: _blitz(TeacherBlitzStatus.draft),
        pairs: FakeTeacherTopicResultPairRepository(
          onFetch: (_) async => _pair(
            blitzId: _otherBlitzId,
            lockedAt: DateTime.utc(2026, 9, 20),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Official Blitz selection is locked by existing official activity.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherBlitzSetOfficialButton')),
        findsNothing,
      );
    });

    testWidgets('an unconfirmed pair hides preparation Archive', (
      tester,
    ) async {
      await _pump(
        tester,
        blitz: _blitz(TeacherBlitzStatus.draft),
        pairs: FakeTeacherTopicResultPairRepository(
          onFetch: (_) async =>
              throw teacherLocalFailure(ApiFailureKind.connection),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Official Blitz status must be refreshed before archiving.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('teacherBlitzArchiveButton')), findsNothing);
      expect(
        find.byKey(const Key('teacherBlitzOfficialRefreshButton')),
        findsOneWidget,
      );
    });
  });

  group('schedule dialog', () {
    testWidgets('prefills the planned time in the Institution timezone', (
      tester,
    ) async {
      await _pump(
        tester,
        blitz: _blitz(
          TeacherBlitzStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 30, 4),
        ),
      );
      await tester.pumpAndSettle();

      await _tapButton(tester, 'teacherBlitzScheduleButton');

      expect(find.text('Reschedule Blitz'), findsOneWidget);
      expect(find.text('Institution timezone: Asia/Tashkent'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('teacherBlitzScheduleValue')))
            .data,
        '2026-09-30 09:00',
      );
      expect(
        find.text('Scheduling does not activate the Blitz automatically.'),
        findsOneWidget,
      );
    });

    testWidgets('the same planned instant sends nothing', (tester) async {
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async => _blitz(
          TeacherBlitzStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 30, 4),
        ),
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzScheduleButton');

      await tester.tap(
        find.byKey(const Key('teacherBlitzScheduleSubmitButton')),
      );
      await tester.pumpAndSettle();

      expect(repository.scheduleRequests, isEmpty);
      expect(find.byKey(const Key('teacherBlitzScheduleDialog')), findsNothing);
      expect(
        find.text('Blitz is already scheduled for this time.'),
        findsOneWidget,
      );
    });

    testWidgets('a server-rejected time keeps the dialog editable', (
      tester,
    ) async {
      // A Draft always sends Schedule, even for its current planned instant.
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async => _blitz(
          TeacherBlitzStatus.draft,
          scheduledAt: DateTime.utc(2026, 9, 30, 4),
        ),
        onSchedule: (_, _) async => throw ApiRequestException(
          ApiFailure.fromServerError(
            statusCode: 422,
            error: ApiErrorResponse(
              message: 'Invalid.',
              code: ApiErrorCodes.validationFailed,
              fieldErrors: const {
                'scheduled_at': ['The scheduled_at must be in the future.'],
              },
              requestId: null,
            ),
          ),
        ),
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzScheduleButton');
      expect(find.text('Schedule Blitz'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('teacherBlitzScheduleSubmitButton')),
      );
      await tester.pumpAndSettle();

      expect(
        repository.scheduleRequests.single.request.scheduledAt,
        '2026-09-30T09:00:00+05:00',
      );
      expect(
        find.byKey(const Key('teacherBlitzScheduleDialog')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('teacherBlitzScheduleDialog')),
          matching: find.text(
            'The server rejected this scheduled time.\nChoose a future time '
            'in the Institution timezone and try again.',
          ),
        ),
        findsOneWidget,
      );
      expect(_button(tester, 'teacherBlitzScheduleSubmitButton'), isNotNull);
    });
  });

  group('mobile', () {
    testWidgets('shows only Activate or Monitor', (tester) async {
      await _useMobileSize(tester);
      for (final (status, pair, visible) in [
        (TeacherBlitzStatus.draft, _pair(), 'Activate'),
        (
          TeacherBlitzStatus.scheduled,
          _pair(blitzId: _otherBlitzId),
          'Activate',
        ),
        (TeacherBlitzStatus.active, _pair(), 'Monitor'),
        (TeacherBlitzStatus.closed, _pair(), null),
        (TeacherBlitzStatus.archived, _pair(), null),
      ]) {
        await _pump(
          tester,
          blitz: _blitz(status),
          pairs: FakeTeacherTopicResultPairRepository(
            onFetch: (_) async => pair,
          ),
          surface: AppDeviceSurface.mobile,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('teacherBlitzDetailTitle')),
          findsOneWidget,
        );
        for (final label in ['Activate', 'Monitor']) {
          expect(
            find.text(label),
            label == visible ? findsOneWidget : findsNothing,
            reason: '${status.value}: $label',
          );
        }
        for (final label in [
          'Schedule',
          'Reschedule',
          'Close',
          'Archive',
          'Set as Official Blitz',
          'Replace Official Blitz',
          'Edit',
          'Manage Questions',
          'Grant exception',
          'Grant additional attempt',
        ]) {
          expect(
            find.text(label),
            findsNothing,
            reason: '${status.value}: $label',
          );
        }
        expect(find.byKey(const Key('teacherBlitzScheduleNote')), findsNothing);
        expect(
          find.byKey(const Key('teacherBlitzOfficialGuidance')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a confirmed activation shows feedback, then Monitor', (
      tester,
    ) async {
      await _useMobileSize(tester);
      final repository = FakeTeacherBlitzRepository(
        onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
      );
      final pairs = FakeTeacherTopicResultPairRepository(
        onFetch: (_) async => _pair(blitzId: _blitzId),
      );
      await _pump(
        tester,
        repository: repository,
        pairs: pairs,
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();

      await _tapButton(tester, 'teacherBlitzActivateButton');
      expect(find.text('Activate Blitz?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
      await tester.pumpAndSettle();

      expect(repository.activateRequests.single.idempotencyKey, _key);
      expect(find.text('Blitz activated successfully.'), findsOneWidget);
      expect(find.text('Monitor'), findsOneWidget);
      expect(find.text('Activate'), findsNothing);
      expect(find.text('Close'), findsNothing);
      expect(pairs.setOfficialBlitzRequests, isEmpty);
    });

    for (final (status, chip) in [
      (TeacherBlitzStatus.closed, 'Closed'),
      (TeacherBlitzStatus.archived, 'Archived'),
    ]) {
      testWidgets('a same-key replay returning $chip adopts it', (
        tester,
      ) async {
        await _useMobileSize(tester);
        var activations = 0;
        final repository = FakeTeacherBlitzRepository(
          onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
          onActivate: (_, _) async {
            activations += 1;
            if (activations == 1) {
              throw const TeacherBlitzMutationOutcomeUnknownException();
            }
            return _blitz(status);
          },
        );
        await _pump(
          tester,
          repository: repository,
          surface: AppDeviceSurface.mobile,
        );
        await tester.pumpAndSettle();
        await _tapButton(tester, 'teacherBlitzActivateButton');
        await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
        await tester.pumpAndSettle();

        expect(find.text('Check current Blitz'), findsOneWidget);
        await _tapButton(tester, 'teacherBlitzRetryActivationButton');

        expect(repository.activateRequests.map((r) => r.idempotencyKey), [
          _key,
          _key,
        ]);
        expect(find.widgetWithText(Chip, chip), findsOneWidget);
        for (final label in ['Activate', 'Retry activation', 'Monitor']) {
          expect(find.text(label), findsNothing, reason: label);
        }
      });
    }

    for (final (name, pairs, context) in [
      (
        'the confirmed official Blitz',
        FakeTeacherTopicResultPairRepository(
          onFetch: (_) async => _pair(blitzId: _blitzId),
        ),
        'Official Blitz',
      ),
      (
        'a confirmed practice Blitz',
        FakeTeacherTopicResultPairRepository(
          onFetch: (_) async => _pair(blitzId: _otherBlitzId),
        ),
        "This Blitz is not currently designated as the Topic's official "
            'Blitz.\n\nIf you activate it now, it remains '
            'practice/supplementary and cannot later be newly designated as '
            'official while Active.',
      ),
      (
        'an unconfirmed official status',
        FakeTeacherTopicResultPairRepository(
          onFetch: (_) async =>
              throw teacherLocalFailure(ApiFailureKind.connection),
        ),
        'Official Blitz status could not be confirmed.\nIf this Blitz must be '
            'official, refresh on desktop before activation.',
      ),
    ]) {
      testWidgets('activation explains $name and still activates', (
        tester,
      ) async {
        await _useMobileSize(tester);
        final repository = FakeTeacherBlitzRepository(
          onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
        );
        await _pump(
          tester,
          repository: repository,
          pairs: pairs,
          surface: AppDeviceSurface.mobile,
        );
        await tester.pumpAndSettle();

        await _tapButton(tester, 'teacherBlitzActivateButton');

        expect(
          find.descendant(
            of: find.byKey(const Key('teacherBlitzConfirmDialog')),
            matching: find.text(context),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
        await tester.pumpAndSettle();
        expect(repository.activateRequests, hasLength(1));
        expect(pairs.setOfficialBlitzRequests, isEmpty);
      });
    }

    testWidgets('a scoreable-points conflict offers no mobile editor', (
      tester,
    ) async {
      await _useMobileSize(tester);
      await _pump(
        tester,
        repository: FakeTeacherBlitzRepository(
          onFetch: (id) async => _blitz(TeacherBlitzStatus.draft),
          onActivate: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.assessmentHasNoScoreablePoints,
            statusCode: 409,
          ),
        ),
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();
      await _tapButton(tester, 'teacherBlitzActivateButton');
      await tester.tap(find.byKey(const Key('teacherBlitzConfirmButton')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This Blitz needs at least one scoreable Question.\nUse the desktop '
          'Teacher workspace to manage Questions.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherBlitzLifecycleConflictAction')),
        findsNothing,
      );
      expect(find.text('Manage Questions'), findsNothing);
    });
  });
}

Future<void> _useMobileSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

TeacherBlitz _blitz(TeacherBlitzStatus status, {DateTime? scheduledAt}) {
  return teacherBlitz(
    status: status,
    scheduledAt:
        scheduledAt ??
        (status == TeacherBlitzStatus.draft
            ? null
            : DateTime.utc(2026, 9, 18, 4)),
  );
}

TeacherTopicResultPair _pair({String? blitzId, DateTime? lockedAt}) {
  return TeacherTopicResultPair(
    id: '95000000-0000-0000-0000-000000000001',
    topicId: _topicId,
    homeworkAssessmentId: _homeworkId,
    blitzAssessmentId: blitzId,
    cohortSnapshottedAt: lockedAt,
    lockedAt: lockedAt,
    designatedAt: DateTime.utc(2026, 9, 17, 12),
    createdAt: DateTime.utc(2026, 9, 17, 12),
    updatedAt: DateTime.utc(2026, 9, 17, 12),
  );
}

Future<void> _tapButton(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

VoidCallback? _textButton(WidgetTester tester, String key) {
  return tester.widget<TextButton>(find.byKey(Key(key))).onPressed;
}

VoidCallback? _button(WidgetTester tester, String key) {
  return tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed;
}

class _FixedKey implements IdempotencyKeyGenerator {
  @override
  String generate() => _key;
}

Future<void> _pump(
  WidgetTester tester, {
  TeacherBlitz? blitz,
  FakeTeacherBlitzRepository? repository,
  FakeTeacherTopicResultPairRepository? pairs,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
  if (surface == AppDeviceSurface.desktop) {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherBlitzRepositoryProvider.overrideWithValue(
          repository ??
              FakeTeacherBlitzRepository(onFetch: (_) async => blitz!),
        ),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          pairs ?? FakeTeacherTopicResultPairRepository(),
        ),
        idempotencyKeyGeneratorProvider.overrideWithValue(_FixedKey()),
      ],
      child: MaterialApp(
        home: TeacherBlitzDetailScreen(
          target: TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
