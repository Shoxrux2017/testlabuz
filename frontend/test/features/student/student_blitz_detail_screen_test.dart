import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_active_blitz_controller.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/presentation/student_blitz_countdown.dart';
import 'package:testlabuz_client/features/student/presentation/student_blitz_detail_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_read_view.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  group('pre-Start detail', () {
    testWidgets('synchronized normal path counts the class time live', (
      tester,
    ) async {
      final harness = _Harness(detail: studentBlitzDetail());
      await harness.pump(tester);

      expect(find.text('Classroom Blitz'), findsOneWidget);
      expect(find.text('Answer independently.'), findsOneWidget);
      expect(find.text('Timed practice.'), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(find.text('Shared class timer'), findsOneWidget);
      expect(find.text('Class time remaining'), findsOneWidget);
      expect(_countdown(tester), '05:00');
      expect(find.text('Starting does not reset this timer.'), findsOneWidget);
      expect(find.byKey(const Key('studentBlitzStartButton')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(_countdown(tester), '04:59');
      _expectNoQuestions();
      expect(harness.attempts.requests, isEmpty);
    });

    testWidgets('individual path shows its full duration and no countdown', (
      tester,
    ) async {
      final harness = _Harness(detail: individualBlitzDetail());
      await harness.pump(tester);

      expect(find.byType(StudentBlitzCountdown), findsNothing);
      expect(
        find.text(
          'Your full 10 min starts when the server starts your attempt.',
        ),
        findsOneWidget,
      );
      expect(find.text('Individual timer'), findsOneWidget);
      _expectNoQuestions();
    });

    testWidgets('an available replacement has no effective pre-Start timer', (
      tester,
    ) async {
      final harness = _Harness(detail: replacementBlitzDetail());
      await harness.pump(tester);

      expect(find.byType(StudentBlitzCountdown), findsNothing);
      expect(
        find.text(
          'Approved additional attempt available.\n'
          'Your full 10 min starts when the server starts it.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('studentBlitzStartAdditionalButton')),
        findsOneWidget,
      );
      expect(find.text('Approved and available'), findsOneWidget);
      _expectNoQuestions();
    });

    testWidgets('an in-progress summary offers Resume without Questions', (
      tester,
    ) async {
      final harness = _Harness(detail: inProgressBlitzDetail());
      await harness.pump(tester);

      expect(find.byKey(const Key('studentBlitzResumeButton')), findsOneWidget);
      expect(find.byKey(const Key('studentBlitzStartButton')), findsNothing);
      expect(
        find.text('Attempt time remaining at last refresh: 5 min'),
        findsOneWidget,
      );
      expect(find.text('In progress'), findsOneWidget);
      _expectNoQuestions();
    });

    testWidgets('a finished Blitz has no Start control and no countdown', (
      tester,
    ) async {
      final harness = _Harness(detail: finishedBlitzDetail());
      await harness.pump(tester);

      expect(
        find.text('You have already finished this Blitz.'),
        findsOneWidget,
      );
      expect(find.byType(StudentBlitzCountdown), findsNothing);
      for (final key in [
        'studentBlitzStartButton',
        'studentBlitzResumeButton',
        'studentBlitzStartAdditionalButton',
      ]) {
        expect(find.byKey(Key(key)), findsNothing);
      }
      _expectNoQuestions();
    });

    for (final (status, code, text) in [
      (409, ApiErrorCodes.blitzNotActive, 'This Blitz is no longer active.'),
      (409, ApiErrorCodes.blitzTimeExpired, 'The Blitz time has expired.'),
      (
        404,
        ApiErrorCodes.resourceNotFound,
        'This Blitz is no longer available.',
      ),
    ]) {
      testWidgets('$code has a dedicated state without the machine code', (
        tester,
      ) async {
        final harness = _Harness(
          detail: studentServerFailure(code, statusCode: status),
        );
        await harness.pump(tester);
        expect(find.text(text), findsOneWidget);
        expect(find.textContaining(code), findsNothing);
        await tester.tap(
          find.byKey(const Key('studentBlitzUnavailableBackButton')),
        );
        await _settle(tester);
        expect(
          harness.path,
          AppRoutePaths.studentTopicDetailLocation(studentTopicId),
        );
      });
    }
  });

  group('explicit Start / Resume', () {
    testWidgets('Start Blitz confirms before sending start_normal', (
      tester,
    ) async {
      final harness = _Harness(detail: studentBlitzDetail());
      await harness.pump(tester);

      await tester.tap(find.byKey(const Key('studentBlitzStartButton')));
      await _settle(tester);
      expect(find.text('Start Blitz?'), findsOneWidget);
      expect(
        find.text(
          'This Blitz uses a shared class timer.\n'
          'You will receive only the time remaining on the server.\n'
          'Starting does not reset the class timer.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(harness.attempts.requests, isEmpty);

      harness.detail = inProgressBlitzDetail();
      await tester.tap(find.byKey(const Key('studentBlitzStartButton')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('studentBlitzStartConfirmButton')));
      await tester.pump();
      expect(harness.attempts.requests.single.toJson(), {
        'intent': 'start_normal',
      });
      expect(harness.attempts.requests.single.idempotencyKey, blitzKey(1));
    });

    testWidgets('individual Start explains the full duration', (tester) async {
      final harness = _Harness(detail: individualBlitzDetail());
      await harness.pump(tester);
      await tester.tap(find.byKey(const Key('studentBlitzStartButton')));
      await _settle(tester);
      expect(
        find.text(
          'Your full Blitz duration starts when the server starts your attempt.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Resume sends the captured Attempt ID without a dialog', (
      tester,
    ) async {
      final harness = _Harness(detail: inProgressBlitzDetail());
      final pending = Completer<StudentBlitzAttemptStartResult>();
      harness.start = pending;
      await harness.pump(tester);
      await tester.tap(find.byKey(const Key('studentBlitzResumeButton')));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(harness.attempts.requests.single.toJson(), {
        'intent': 'resume',
        'attempt_id': studentBlitzAttemptId,
      });
      expect(find.text('Resuming Blitz…'), findsOneWidget);
      expect(find.byKey(const Key('studentBlitzResumeButton')), findsNothing);
      pending.complete(
        studentBlitzStartResult(
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
      );
      await _settle(tester);
      expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(2));
      expect(find.text('Blitz resumed.'), findsOneWidget);
    });

    testWidgets('an additional attempt starts only after its confirmation', (
      tester,
    ) async {
      final harness = _Harness(detail: replacementBlitzDetail());
      await harness.pump(tester);

      await tester.tap(
        find.byKey(const Key('studentBlitzStartAdditionalButton')),
      );
      await _settle(tester);
      expect(find.text('Start additional Blitz attempt?'), findsOneWidget);
      expect(
        find.text(
          'Your original attempt remains in history.\n'
          'This approved additional attempt receives the full configured '
          'Blitz duration from the moment the server starts it.\n'
          'The original class timer does not restart for other Students.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(harness.attempts.requests, isEmpty);

      await tester.tap(
        find.byKey(const Key('studentBlitzStartAdditionalButton')),
      );
      await _settle(tester);
      await tester.tap(
        find.byKey(const Key('studentBlitzStartAdditionalConfirmButton')),
      );
      await tester.pump();
      expect(harness.attempts.requests.single.toJson(), {
        'intent': 'start_replacement',
      });
    });

    testWidgets('stale Resume refreshes to replacement without starting #2', (
      tester,
    ) async {
      final harness = _Harness(detail: inProgressBlitzDetail());
      harness.start = studentServerFailure(
        ApiErrorCodes.attemptNotEditable,
        statusCode: 409,
      );
      await harness.pump(tester);
      harness.detail = replacementBlitzDetail();
      await tester.tap(find.byKey(const Key('studentBlitzResumeButton')));
      await _settle(tester);

      expect(
        find.text('This Blitz attempt can no longer be resumed.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('studentBlitzStartAdditionalButton')),
        findsOneWidget,
      );
      expect(harness.attempts.requests, hasLength(1));
      _expectNoQuestions();
    });

    testWidgets('an uncertain outcome offers only a same-key Retry', (
      tester,
    ) async {
      final harness = _Harness(detail: individualBlitzDetail());
      harness.start = studentLocalFailure(ApiFailureKind.timeout);
      await harness.pump(tester);
      await tester.tap(find.byKey(const Key('studentBlitzStartButton')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('studentBlitzStartConfirmButton')));
      await _settle(tester);

      expect(
        find.text(
          'We could not confirm the Blitz attempt state.\n'
          'Retry safely using the same request.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('studentBlitzStartButton')), findsNothing);
      _expectNoQuestions();
      harness.start = studentBlitzStartResult(
        attempt: studentBlitzAttempt(mode: StudentBlitzTimerMode.individual),
      );
      harness.detail = inProgressBlitzDetail(
        mode: StudentBlitzTimerMode.individual,
      );
      await tester.tap(find.byKey(const Key('studentBlitzRetryStartButton')));
      await tester.pump();
      expect(harness.attempts.requests, hasLength(2));
      expect(harness.attempts.requests.last.idempotencyKey, blitzKey(1));
      expect(harness.keys.calls, 1);
    });

    testWidgets('a deterministic failure shows its mapped copy', (
      tester,
    ) async {
      final harness = _Harness(detail: individualBlitzDetail());
      harness.start = studentServerFailure(
        ApiErrorCodes.attemptsExhausted,
        statusCode: 409,
      );
      await harness.pump(tester);
      await tester.tap(find.byKey(const Key('studentBlitzStartButton')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('studentBlitzStartConfirmButton')));
      await _settle(tester);
      expect(find.text('No Blitz attempts remain.'), findsOneWidget);
    });
  });

  group('execution shell', () {
    testWidgets('a started Attempt shows Questions on the same route', (
      tester,
    ) async {
      final harness = _Harness(detail: studentBlitzDetail());
      harness.start = studentBlitzStartResult(
        attempt: studentBlitzAttempt(
          answers: [
            StudentAttemptAnswerState(
              questionId: blitzUuid(101),
              type: StudentQuestionType.trueFalse,
              value: const StudentBooleanAnswerValue(value: true),
              updatedAt: DateTime.utc(2026, 9, 17, 12, 1),
            ),
          ],
        ),
      );
      await harness.pump(tester);
      final route = harness.path;
      harness.detail = inProgressBlitzDetail();
      await _confirmStart(tester);

      expect(harness.path, route);
      // Every Question appears once, in its shared editor.
      expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(2));
      expect(find.byType(StudentQuestionReadView), findsNothing);
      expect(find.text('Attempt 1'), findsOneWidget);
      expect(find.text('Time remaining'), findsOneWidget);
      expect(find.text('Blitz started.'), findsOneWidget);
      expect(find.byKey(const Key('studentBlitzRefreshButton')), findsNothing);
      expect(find.byKey(const Key('studentBlitzSubmitButton')), findsOneWidget);
    });

    testWidgets('the approved additional attempt is labelled as such', (
      tester,
    ) async {
      final harness = _Harness(detail: replacementBlitzDetail());
      harness.start = studentBlitzStartResult(
        attempt: studentBlitzAttempt(
          id: studentBlitzReplacementAttemptId,
          attemptNumber: 2,
          deadlineAt: DateTime.utc(2026, 9, 17, 12, 20),
          serverNow: DateTime.utc(2026, 9, 17, 12, 10),
          remainingSeconds: 600,
        ),
      );
      await harness.pump(tester);
      harness.detail = studentBlitzDetail(
        timing: studentBlitzTiming(
          serverNow: DateTime.utc(2026, 9, 17, 12, 10),
          deadlineAt: DateTime.utc(2026, 9, 17, 12, 20),
          remainingSeconds: 600,
        ),
        attempts: studentBlitzAttemptSummary(
          normalUsed: 1,
          inProgressAttemptId: studentBlitzReplacementAttemptId,
          exceptionGranted: true,
        ),
      );
      await tester.tap(
        find.byKey(const Key('studentBlitzStartAdditionalButton')),
      );
      await _settle(tester);
      await tester.tap(
        find.byKey(const Key('studentBlitzStartAdditionalConfirmButton')),
      );
      await _settle(tester);

      expect(find.text('Additional attempt (Attempt 2)'), findsOneWidget);
      expect(
        find.text('This is the approved additional attempt.'),
        findsOneWidget,
      );
      expect(_countdown(tester), '10:00');
      expect(find.text('Additional Blitz attempt started.'), findsOneWidget);
    });

    testWidgets('a terminal replay shows its summary, not execution', (
      tester,
    ) async {
      final harness = _Harness(detail: studentBlitzDetail());
      harness.start = studentBlitzStartResult(
        attempt: studentBlitzAttempt(
          status: StudentBlitzAttemptStatus.timedOutFinalized,
          finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
        ),
      );
      await harness.pump(tester);
      harness.detail = finishedBlitzDetail();
      await _confirmStart(tester);

      expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
      expect(find.byType(StudentBlitzCountdown), findsNothing);
      expect(
        find.byKey(const Key('studentBlitzFinalizationSummary')),
        findsOneWidget,
      );
      expect(find.text('Time expired'), findsWidgets);
    });

    testWidgets('leaving asks first and makes no API call', (tester) async {
      final harness = _Harness(detail: studentBlitzDetail());
      await harness.pump(tester);
      harness.detail = inProgressBlitzDetail();
      await _confirmStart(tester);
      final reads = harness.blitz.detailIds.length;

      await tester.tap(find.byKey(const Key('studentBlitzLeaveButton')));
      await _settle(tester);
      expect(find.text('Leave Blitz?'), findsOneWidget);
      expect(
        find.text(
          'Your server timer will continue.\n'
          'You can resume later while the attempt remains active.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Stay'));
      await _settle(tester);
      expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(2));

      await tester.tap(find.byTooltip('Back to Topic'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('studentBlitzLeaveConfirmButton')));
      await _settle(tester);
      expect(
        harness.path,
        AppRoutePaths.studentTopicDetailLocation(studentTopicId),
      );
      expect(harness.attempts.requests, hasLength(1));
      expect(harness.blitz.detailIds, hasLength(reads));
    });
  });

  group('countdown expiry', () {
    testWidgets('execution zero replays the Start request once', (
      tester,
    ) async {
      final harness = _Harness(detail: studentBlitzDetail());
      harness.start = studentBlitzStartResult(
        attempt: studentBlitzAttempt(
          remainingSeconds: 3,
          serverNow: DateTime.utc(2026, 9, 17, 12, 4, 57),
        ),
      );
      await harness.pump(tester);
      harness.detail = inProgressBlitzDetail(
        remainingSeconds: 3,
        serverNow: DateTime.utc(2026, 9, 17, 12, 4, 57),
      );
      await _confirmStart(tester);
      final reads = harness.blitz.detailIds.length;
      final lists = harness.blitz.activeCalls;
      final pending = Completer<StudentBlitzAttemptStartResult>();
      harness.start = pending;

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(_countdown(tester), '00:00');
      expect(find.text('Checking current Blitz time…'), findsOneWidget);
      expect(harness.attempts.requests, hasLength(2));
      expect(
        harness.attempts.requests.last,
        same(harness.attempts.requests.first),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(harness.attempts.requests, hasLength(2));
      expect(harness.blitz.detailIds, hasLength(reads));

      // The replay finalizes the due Attempt; the device never does.
      pending.complete(
        studentBlitzStartResult(
          attempt: studentBlitzAttempt(
            status: StudentBlitzAttemptStatus.timedOutFinalized,
            finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.byKey(const Key('studentBlitzFinalizationSummary')),
        findsOneWidget,
      );
      expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
      expect(harness.blitz.detailIds, hasLength(reads + 1));
      expect(harness.blitz.activeCalls, lists + 1);
      expect(find.text('Your Blitz attempt has been submitted.'), findsNothing);
    });

    testWidgets('a failed expiry check keeps execution locked at zero', (
      tester,
    ) async {
      final harness = _Harness(detail: studentBlitzDetail());
      harness.start = studentBlitzStartResult(
        attempt: studentBlitzAttempt(
          remainingSeconds: 2,
          serverNow: DateTime.utc(2026, 9, 17, 12, 4, 58),
        ),
      );
      await harness.pump(tester);
      harness.detail = inProgressBlitzDetail(
        remainingSeconds: 2,
        serverNow: DateTime.utc(2026, 9, 17, 12, 4, 58),
      );
      await _confirmStart(tester);
      harness.start = studentLocalFailure(ApiFailureKind.connection);

      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
      expect(
        find.text(
          'Time may have expired. Reconnect and refresh to confirm the '
          'current Blitz state.',
        ),
        findsOneWidget,
      );
      expect(_countdown(tester), '00:00');
      await tester.pump(const Duration(seconds: 10));
      expect(_countdown(tester), '00:00');
      expect(harness.attempts.requests, hasLength(2));

      harness.start = studentBlitzStartResult(
        attempt: studentBlitzAttempt(
          status: StudentBlitzAttemptStatus.timedOutFinalized,
          finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
        ),
      );
      await tester.tap(find.byKey(const Key('studentBlitzCheckAttemptButton')));
      await _settle(tester);
      expect(harness.attempts.requests, hasLength(3));
      expect(
        harness.attempts.requests.last,
        same(harness.attempts.requests.first),
      );
      expect(
        find.byKey(const Key('studentBlitzFinalizationSummary')),
        findsOneWidget,
      );
    });

    testWidgets('pre-Start class time zero disables Start and checks once', (
      tester,
    ) async {
      final harness = _Harness(
        detail: studentBlitzDetail(
          timing: studentBlitzTiming(
            serverNow: DateTime.utc(2026, 9, 17, 12, 4, 58),
            remainingSeconds: 2,
          ),
        ),
      );
      await harness.pump(tester);
      final pending = Completer<StudentBlitzDetail>();
      harness.detail = pending;

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byKey(const Key('studentBlitzStartButton')), findsNothing);
      expect(find.text('Checking current Blitz time…'), findsOneWidget);
      expect(harness.blitz.detailIds, hasLength(2));
      await tester.pump(const Duration(seconds: 5));
      expect(harness.blitz.detailIds, hasLength(2));
      pending.completeError(
        studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
      );
      await _settle(tester);
      expect(find.text('The Blitz time has expired.'), findsOneWidget);
      expect(harness.attempts.requests, isEmpty);
    });
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets('${surface.name} narrow layout wraps without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness(
        surface: surface,
        detail: studentBlitzDetail(
          title:
              'A very long Blitz title that must wrap on a narrow screen '
              'without any horizontal overflow',
          timing: studentBlitzTiming(
            mode: StudentBlitzTimerMode.individual,
            noDeadline: true,
          ),
        ),
      );
      await harness.pump(tester);
      expect(tester.takeException(), isNull);
      harness.detail = inProgressBlitzDetail(
        mode: StudentBlitzTimerMode.individual,
      );
      harness.start = studentBlitzStartResult(
        attempt: studentBlitzAttempt(mode: StudentBlitzTimerMode.individual),
      );
      await _confirmStart(tester);
      expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}

void _expectNoQuestions() {
  expect(find.byType(StudentQuestionReadView), findsNothing);
  expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
  expect(find.text('Questions'), findsNothing);
}

String _countdown(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('studentBlitzCountdownValue')))
    .data!;

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _confirmStart(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('studentBlitzStartButton')));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('studentBlitzStartConfirmButton')));
  await _settle(tester);
}

class _Harness {
  _Harness({required this.detail, this.surface = AppDeviceSurface.desktop}) {
    blitz.onFetchBlitz = (_) => _respond(detail);
    attempts.onStart = (_, _) => _respond(start);
  }

  /// Next detail read: a detail, an exception or a pending completer.
  Object detail;

  /// Next Start result: a result, an exception or a pending completer.
  Object start = studentBlitzStartResult();
  final AppDeviceSurface surface;
  final blitz = FakeStudentBlitzRepository();
  final attempts = FakeStudentBlitzAttemptRepository();
  final keys = SequentialBlitzKeys();
  late final GoRouter router;
  late final ProviderContainer container;

  String get path => router.routeInformationProvider.value.uri.path;

  static Future<T> _respond<T>(Object response) {
    if (response is Completer<T>) return response.future;
    if (response is T) return Future.value(response as T);
    return Future.error(response);
  }

  Future<void> pump(WidgetTester tester) async {
    final target = StudentBlitzRouteTarget(
      topicId: studentTopicId,
      blitzId: studentBlitzId,
    );
    router = GoRouter(
      initialLocation: AppRoutePaths.studentBlitzDetailLocation(
        studentTopicId,
        studentBlitzId,
      ),
      routes: [
        GoRoute(
          path: '/student/topics/:topicId',
          builder: (_, _) => const Scaffold(body: Text('Topic route')),
          routes: [
            GoRoute(
              path: 'blitz/:blitzId',
              builder: (_, _) => StudentBlitzDetailScreen(target: target),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeStudentAuthSessionController.authenticated(
            studentUser('student-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentBlitzRepositoryProvider.overrideWithValue(blitz),
        studentBlitzAttemptRepositoryProvider.overrideWithValue(attempts),
        idempotencyKeyGeneratorProvider.overrideWithValue(keys),
        studentBlitzStopwatchFactoryProvider.overrideWithValue(
          () => tester.binding.clock.stopwatch(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The workspace list is mounted beneath the Blitz route in the real app.
    final list = container.listen(
      studentActiveBlitzControllerProvider,
      (_, _) {},
    );
    addTearDown(list.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
  }
}
