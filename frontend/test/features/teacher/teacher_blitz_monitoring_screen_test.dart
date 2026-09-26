import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_attempt_exception.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_monitoring.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_monitoring_screen.dart';

import 'teacher_blitz_json_fixtures.dart';
import 'teacher_blitz_monitoring_fixtures.dart';
import 'teacher_blitz_monitoring_test_support.dart';
import 'teacher_test_support.dart';

const _studentD = 'a1000000-0000-0000-0000-000000000004';
const _studentE = 'a1000000-0000-0000-0000-000000000005';
const _studentF = 'a1000000-0000-0000-0000-000000000006';

void main() {
  setUpAll(InstitutionTimezone.initialize);

  group('desktop', () {
    testWidgets('no live data before the route Blitz is confirmed', (
      tester,
    ) async {
      final pendingDetail = Completer<TeacherBlitz>();
      final repository = _repository(onFetch: (_) => pendingDetail.future);
      await _pump(tester, repository);

      expect(
        find.byKey(const Key('teacherBlitzMonitoringVerifying')),
        findsOneWidget,
      );
      expect(find.textContaining('Live'), findsNothing);
      expect(repository.monitoringIds, isEmpty);
    });

    testWidgets('a Blitz of another Topic is a safe not-found state', (
      tester,
    ) async {
      final repository = _repository(
        onFetch: (id) async => teacherBlitz(
          id: id,
          topicId: monitoringOtherTopicId,
          status: TeacherBlitzStatus.active,
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherBlitzMonitoringUnavailable')),
        findsOneWidget,
      );
      expect(find.textContaining(monitoringOtherTopicId), findsNothing);
      expect(find.textContaining('Grant'), findsNothing);
      expect(repository.monitoringIds, isEmpty);
    });

    testWidgets('a parent failure offers Retry instead of monitoring', (
      tester,
    ) async {
      var reads = 0;
      final repository = _repository(
        onFetch: (id) async {
          reads += 1;
          if (reads == 1) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherBlitz(id: id, status: TeacherBlitzStatus.active);
        },
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherBlitzMonitoringParentError')),
        findsOneWidget,
      );
      expect(repository.monitoringIds, isEmpty);

      await tester.tap(
        find.byKey(const Key('teacherBlitzMonitoringParentRetryButton')),
      );
      await tester.pumpAndSettle();

      expect(repository.monitoringIds, [blitzJsonId]);
      expect(find.text('Live · updates every 5 seconds'), findsOneWidget);
    });

    testWidgets('shows the header, timing, summary and Student rows', (
      tester,
    ) async {
      await _pump(
        tester,
        _repository(
          monitoring: teacherMonitoring(
            students: [
              terminalRowJson(monitoringStudentA, fullName: 'Aziza Karimova'),
              inProgressRowJson(monitoringStudentB, fullName: 'Bekzod Aliyev'),
              notStartedRowJson(
                monitoringStudentC,
                fullName: 'Dilnoza Sobirova',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blitz Monitoring'), findsOneWidget);
      expect(find.text('Equation Blitz'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Live · updates every 5 seconds'), findsOneWidget);
      expect(_value(tester, 'Timer mode'), 'Synchronized');
      expect(_value(tester, 'Duration'), '10 min');
      expect(_value(tester, 'Activated at'), '2026-09-18 09:01');
      expect(_value(tester, 'Server snapshot'), '2026-09-18 09:05');
      expect(_value(tester, 'Common end'), '2026-09-18 09:11');
      expect(_summary(tester, 'Assigned'), '3');
      expect(_summary(tester, 'Not started'), '1');
      expect(_summary(tester, 'In progress'), '1');
      expect(_summary(tester, 'Finalized'), '1');
      expect(_summary(tester, 'Waiting for Teacher review'), '0');
      expect(_summary(tester, 'Additional attempts granted'), '0');

      final aziza = _row(monitoringStudentA);
      expect(_inRow(aziza, 'Aziza Karimova'), findsOneWidget);
      expect(_inRow(aziza, 'Finalized'), findsOneWidget);
      expect(_inRow(aziza, 'Attempt 1'), findsOneWidget);
      expect(_inRow(aziza, 'Submitted by Student'), findsOneWidget);
      expect(_inRow(aziza, '00:00'), findsOneWidget);
      final bekzod = _row(monitoringStudentB);
      expect(_inRow(bekzod, 'In progress'), findsOneWidget);
      expect(_inRow(bekzod, '06:00'), findsOneWidget);
      expect(_inRow(bekzod, '2026-09-18 09:11'), findsOneWidget);
    });

    testWidgets('an individual Blitz has no common end', (tester) async {
      await _pump(
        tester,
        _repository(
          monitoring: teacherMonitoring(
            mode: 'individual',
            students: [
              notStartedRowJson(monitoringStudentA, remainingSeconds: null),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_value(tester, 'Timer mode'), 'Individual');
      expect(find.text('Common end'), findsNothing);
    });

    testWidgets('shows exception details without identifiers', (tester) async {
      await _pump(
        tester,
        _repository(
          monitoring: teacherMonitoring(
            students: [
              notStartedRowJson(
                monitoringStudentA,
                remainingSeconds: null,
                attemptException: monitoringExceptionJson(),
              ),
              inProgressRowJson(
                monitoringStudentB,
                attemptNumber: 2,
                attemptException: monitoringExceptionJson(
                  id: 'a3000000-0000-0000-0000-000000000002',
                  replacementAttemptId: monitoringAttemptTwo,
                  reasonType: 'other_valid',
                  reason: 'Fire alarm evacuation.',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final waiting = _row(monitoringStudentA);
      expect(_inRow(waiting, 'Additional attempt granted'), findsOneWidget);
      expect(_inRow(waiting, 'Technical problem'), findsOneWidget);
      expect(_inRow(waiting, 'The device lost power.'), findsOneWidget);
      expect(
        _inRow(waiting, 'Waiting for Student to start additional attempt'),
        findsOneWidget,
      );
      final started = _row(monitoringStudentB);
      expect(_inRow(started, 'Additional attempt'), findsOneWidget);
      expect(_inRow(started, 'Other valid reason'), findsOneWidget);
      expect(
        _inRow(started, 'Additional attempt already started'),
        findsOneWidget,
      );
      expect(find.textContaining(monitoringExceptionId), findsNothing);
      expect(find.textContaining(monitoringAttemptOne), findsNothing);
      expect(find.textContaining(monitoringAttemptTwo), findsNothing);
      expect(find.textContaining('Revoke'), findsNothing);
      expect(find.textContaining('Edit reason'), findsNothing);
    });

    testWidgets('offers Grant only for a finalized normal attempt', (
      tester,
    ) async {
      await _pump(
        tester,
        _repository(
          monitoring: teacherMonitoring(
            students: [
              terminalRowJson(monitoringStudentA),
              terminalRowJson(
                monitoringStudentB,
                status: 'waiting_for_teacher_review',
              ),
              inProgressRowJson(monitoringStudentC),
              notStartedRowJson(_studentD),
              terminalRowJson(
                _studentE,
                attemptNumber: 2,
                attemptException: monitoringExceptionJson(
                  replacementAttemptId: monitoringAttemptTwo,
                ),
              ),
              notStartedRowJson(
                _studentF,
                remainingSeconds: null,
                attemptException: monitoringExceptionJson(
                  id: 'a3000000-0000-0000-0000-000000000009',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final (id, visible) in [
        (monitoringStudentA, true),
        (monitoringStudentB, true),
        (monitoringStudentC, false),
        (_studentD, false),
        (_studentE, false),
        (_studentF, false),
      ]) {
        expect(
          find.byKey(ValueKey('teacherBlitzGrantButton:$id')),
          visible ? findsOneWidget : findsNothing,
          reason: id,
        );
      }
    });

    testWidgets('the grant dialog validates, then grants the trimmed reason', (
      tester,
    ) async {
      final repository = _repository(
        monitoring: teacherMonitoring(
          students: [
            terminalRowJson(monitoringStudentA, fullName: 'Aziza Karimova'),
          ],
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await _tap(
        tester,
        find.byKey(ValueKey('teacherBlitzGrantButton:$monitoringStudentA')),
      );

      final dialog = find.byKey(
        const Key('teacherBlitzAttemptExceptionDialog'),
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Grant additional Blitz attempt'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Aziza Karimova')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(
            'The original attempt remains in history.\nThis grant allows one '
            'replacement attempt only.\nThe replacement attempt is created '
            'only when the Student starts it.',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('teacherBlitzAttemptExceptionSubmit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a reason type.'), findsOneWidget);
      expect(find.text('Enter a reason.'), findsOneWidget);
      expect(repository.grantRequests, isEmpty);

      await tester.tap(
        find.byKey(const Key('teacherBlitzAttemptExceptionReasonType')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technical problem').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('teacherBlitzAttemptExceptionReason')),
        '  The device lost power.  ',
      );
      repository.onFetchMonitoring = (_) async => teacherMonitoring(
        students: [
          notStartedRowJson(
            monitoringStudentA,
            fullName: 'Aziza Karimova',
            remainingSeconds: null,
            attemptException: monitoringExceptionJson(),
          ),
        ],
      );
      await tester.tap(
        find.byKey(const Key('teacherBlitzAttemptExceptionSubmit')),
      );
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(repository.grantRequests.single.request.toJson(), {
        'reason_type': 'technical',
        'reason': 'The device lost power.',
      });
      expect(find.text('Additional Blitz attempt granted.'), findsOneWidget);
      expect(
        find.byKey(ValueKey('teacherBlitzGrantButton:$monitoringStudentA')),
        findsNothing,
      );
      expect(
        _inRow(_row(monitoringStudentA), 'Additional attempt granted'),
        findsOneWidget,
      );
    });

    testWidgets('Cancel closes the dialog and sends nothing', (tester) async {
      final repository = _repository(
        monitoring: teacherMonitoring(
          students: [terminalRowJson(monitoringStudentA)],
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await _tap(
        tester,
        find.byKey(ValueKey('teacherBlitzGrantButton:$monitoringStudentA')),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherBlitzAttemptExceptionDialog')),
        findsNothing,
      );
      expect(repository.grantRequests, isEmpty);
      expect(find.text('Live · updates every 5 seconds'), findsOneWidget);
    });

    testWidgets('an unknown grant offers only same-key recovery', (
      tester,
    ) async {
      final repository =
          _repository(
              monitoring: teacherMonitoring(
                students: [
                  terminalRowJson(monitoringStudentA),
                  terminalRowJson(monitoringStudentB),
                ],
              ),
            )
            ..onGrantAttemptException = (_, _, _, _) async =>
                throw const TeacherBlitzAttemptExceptionOutcomeUnknownException();
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await _grantThroughDialog(tester, monitoringStudentA);

      expect(
        find.text(
          'We could not confirm whether the additional attempt was granted.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherBlitzGrantRetryButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherBlitzGrantCheckMonitoringButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('teacherBlitzGrantButton:$monitoringStudentB')),
        findsNothing,
      );
      expect(find.text('Live updates paused'), findsOneWidget);

      repository.onGrantAttemptException = null;
      await _tap(tester, find.byKey(const Key('teacherBlitzGrantRetryButton')));

      expect(
        repository.grantRequests.map((request) => request.idempotencyKey),
        [monitoringGrantKeyA, monitoringGrantKeyA],
      );
    });

    for (final (name, status, code, notice) in [
      ('closed', 409, ApiErrorCodes.taskClosed, 'This Blitz has been closed.'),
      (
        'unavailable',
        404,
        ApiErrorCodes.resourceNotFound,
        'This Blitz is not available in your current Teacher workspace.',
      ),
    ]) {
      testWidgets('an unknown grant stays recoverable once $name', (
        tester,
      ) async {
        final repository =
            _repository(
                monitoring: teacherMonitoring(
                  students: [terminalRowJson(monitoringStudentA)],
                ),
              )
              ..onGrantAttemptException = (_, _, _, _) async =>
                  throw const TeacherBlitzAttemptExceptionOutcomeUnknownException();
        await _pump(tester, repository);
        await tester.pumpAndSettle();
        await _grantThroughDialog(tester, monitoringStudentA);
        repository.onFetchMonitoring = (_) async =>
            throw teacherServerFailure(code, statusCode: status);

        await _tap(
          tester,
          find.byKey(const Key('teacherBlitzGrantCheckMonitoringButton')),
        );

        expect(find.text(notice), findsOneWidget);
        expect(
          find.text(
            'Live monitoring is no longer available for this Blitz. Retry the '
            'original grant request to confirm whether it was recorded.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('teacherBlitzGrantCheckMonitoringButton')),
          findsNothing,
        );

        repository.onGrantAttemptException = (_, _, _, _) async =>
            teacherGrant(replacementAttemptAvailable: false);
        await _tap(
          tester,
          find.byKey(const Key('teacherBlitzGrantRetryButton')),
        );

        expect(
          repository.grantRequests.map((request) => request.idempotencyKey),
          [monitoringGrantKeyA, monitoringGrantKeyA],
        );
        expect(
          find.text(
            'Additional-attempt grant confirmed, but the Blitz no longer '
            'allows the Student to start that attempt.',
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('a confirmed grant stays visible after the Blitz ends', (
      tester,
    ) async {
      final repository = _repository(
        monitoring: teacherMonitoring(
          students: [terminalRowJson(monitoringStudentA)],
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      repository.onFetchMonitoring = (_) async => throw teacherServerFailure(
        ApiErrorCodes.taskArchived,
        statusCode: 409,
      );

      await _grantThroughDialog(tester, monitoringStudentA);

      expect(find.text('This Blitz is archived.'), findsOneWidget);
      expect(find.text('Additional Blitz attempt granted.'), findsOneWidget);
    });

    testWidgets('a failed poll shows one stale banner and keeps the rows', (
      tester,
    ) async {
      final repository = _repository(
        monitoring: teacherMonitoring(
          students: [terminalRowJson(monitoringStudentA, fullName: 'Aziza')],
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      repository.onFetchMonitoring = (_) async =>
          throw teacherLocalFailure(ApiFailureKind.connection);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherBlitzMonitoringStaleBanner')),
        findsOneWidget,
      );
      expect(find.text('Live monitoring may be out of date.'), findsOneWidget);
      expect(find.text('Aziza'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a rate limit pauses live updates behind Retry', (
      tester,
    ) async {
      final repository = _repository();
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      repository.onFetchMonitoring = (_) async => throw teacherServerFailure(
        ApiErrorCodes.rateLimited,
        statusCode: 429,
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Live updates are paused because too many requests were sent.',
        ),
        findsOneWidget,
      );
      repository.onFetchMonitoring = null;
      await _tap(
        tester,
        find.byKey(const Key('teacherBlitzMonitoringRetryButton')),
      );

      expect(find.text('Live · updates every 5 seconds'), findsOneWidget);
    });

    for (final (code, notice) in [
      (ApiErrorCodes.taskClosed, 'This Blitz has been closed.'),
      (ApiErrorCodes.taskArchived, 'This Blitz is archived.'),
      (ApiErrorCodes.taskNotActive, 'This Blitz is not active.'),
    ]) {
      testWidgets('$code replaces live data with its notice', (tester) async {
        final repository = _repository(
          monitoring: teacherMonitoring(
            students: [terminalRowJson(monitoringStudentA, fullName: 'Aziza')],
          ),
        );
        await _pump(tester, repository);
        await tester.pumpAndSettle();
        repository.onFetchMonitoring = (_) async =>
            throw teacherServerFailure(code, statusCode: 409);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(find.text(notice), findsOneWidget);
        expect(find.text('Aziza'), findsNothing);
        expect(find.textContaining('Live ·'), findsNothing);
        expect(find.text('Active'), findsNothing);
        expect(
          find.byKey(const Key('teacherBlitzMonitoringEndedBackButton')),
          findsOneWidget,
        );
      });
    }

    testWidgets('an app pause stops live updates; a resume reads at once', (
      tester,
    ) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final repository = _repository();
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Live updates paused'), findsOneWidget);
      expect(repository.monitoringIds, hasLength(1));

      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(repository.monitoringIds, hasLength(2));
      expect(find.text('Live · updates every 5 seconds'), findsOneWidget);
    });

    testWidgets('the dialog focuses the first invalid field', (tester) async {
      await _pump(
        tester,
        _repository(
          monitoring: teacherMonitoring(
            students: [terminalRowJson(monitoringStudentA)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byKey(ValueKey('teacherBlitzGrantButton:$monitoringStudentA')),
      );
      await tester.tap(
        find.byKey(const Key('teacherBlitzAttemptExceptionReasonType')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other valid reason').last);
      await tester.pumpAndSettle();
      expect(find.text('Up to 4000 characters.'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('teacherBlitzAttemptExceptionSubmit')),
      );
      await tester.pumpAndSettle();

      final reason = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('teacherBlitzAttemptExceptionReason')),
          matching: find.byType(EditableText),
        ),
      );
      expect(reason.focusNode.hasFocus, isTrue);
      expect(find.text('Enter a reason.'), findsOneWidget);
    });

    testWidgets('never shows score, answers or Questions', (tester) async {
      await _pump(
        tester,
        _repository(
          monitoring: teacherMonitoring(
            students: [
              terminalRowJson(monitoringStudentA),
              inProgressRowJson(monitoringStudentB),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final text in ['core', 'nswer', 'Question', 'oints', 'eedback']) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
    });
  });

  group('mobile', () {
    testWidgets('compact cards omit reasons and Grant', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        _repository(
          monitoring: teacherMonitoring(
            students: [
              terminalRowJson(monitoringStudentA, fullName: 'Aziza Karimova'),
              inProgressRowJson(
                monitoringStudentB,
                fullName: 'Bekzod Aliyev',
                attemptNumber: 2,
                attemptException: monitoringExceptionJson(
                  replacementAttemptId: monitoringAttemptTwo,
                ),
              ),
            ],
          ),
        ),
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();

      expect(find.text('Live · updates every 5 seconds'), findsOneWidget);
      expect(_summary(tester, 'Assigned'), '2');
      final aziza = _row(monitoringStudentA);
      expect(_inRow(aziza, 'Attempt 1'), findsOneWidget);
      expect(_inRow(aziza, 'Submitted by Student'), findsOneWidget);
      final bekzod = _row(monitoringStudentB);
      expect(_inRow(bekzod, 'Additional attempt'), findsOneWidget);
      expect(_inRow(bekzod, 'Additional attempt granted'), findsOneWidget);
      expect(_inRow(bekzod, '06:00'), findsOneWidget);
      for (final hidden in [
        'The device lost power.',
        'Technical problem',
        'Additional attempt already started',
      ]) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
      expect(find.textContaining('Grant'), findsNothing);
      for (final text in ['core', 'nswer', 'Question']) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
    });

    testWidgets('a Blitz of another Topic is a safe not-found state', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _repository(
        onFetch: (id) async => teacherBlitz(
          id: id,
          topicId: monitoringOtherTopicId,
          status: TeacherBlitzStatus.active,
        ),
      );
      await _pump(tester, repository, surface: AppDeviceSurface.mobile);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherBlitzMonitoringUnavailable')),
        findsOneWidget,
      );
      expect(repository.monitoringIds, isEmpty);
    });

    testWidgets('a narrow screen does not overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        _repository(
          monitoring: teacherMonitoring(
            students: [
              terminalRowJson(
                monitoringStudentA,
                fullName: 'Aziza Karimova-Abdurakhmonova Tashkentovna',
                status: 'waiting_for_teacher_review',
                finalizationReason: 'task_closed_auto_finalize',
              ),
              notStartedRowJson(
                monitoringStudentB,
                remainingSeconds: null,
                attemptException: monitoringExceptionJson(),
              ),
            ],
          ),
        ),
        surface: AppDeviceSurface.mobile,
        textScaler: const TextScaler.linear(1.3),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(
          ValueKey('teacherBlitzMonitoringStudent:$monitoringStudentB'),
        ),
        200,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

FakeTeacherBlitzRepository _repository({
  Future<TeacherBlitz> Function(String blitzId)? onFetch,
  TeacherBlitzMonitoring? monitoring,
}) {
  final repository = FakeTeacherBlitzRepository(
    onFetch:
        onFetch ??
        (id) async => teacherBlitz(id: id, status: TeacherBlitzStatus.active),
  );
  if (monitoring != null) {
    repository.onFetchMonitoring = (_) async => monitoring;
  }
  return repository;
}

class _Keys implements IdempotencyKeyGenerator {
  final _keys = [monitoringGrantKeyA, monitoringGrantKeyB];
  var _next = 0;

  @override
  String generate() => _keys[_next++];
}

Future<void> _pump(
  WidgetTester tester,
  FakeTeacherBlitzRepository repository, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  TextScaler textScaler = TextScaler.noScaling,
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
        teacherBlitzRepositoryProvider.overrideWithValue(repository),
        idempotencyKeyGeneratorProvider.overrideWithValue(_Keys()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: TeacherBlitzMonitoringScreen(target: monitoringTarget),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _grantThroughDialog(WidgetTester tester, String studentId) async {
  await _tap(
    tester,
    find.byKey(ValueKey('teacherBlitzGrantButton:$studentId')),
  );
  await tester.tap(
    find.byKey(const Key('teacherBlitzAttemptExceptionReasonType')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Technical problem').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('teacherBlitzAttemptExceptionReason')),
    'The device lost power.',
  );
  await tester.tap(find.byKey(const Key('teacherBlitzAttemptExceptionSubmit')));
  await tester.pumpAndSettle();
}

Finder _row(String studentId) =>
    find.byKey(ValueKey('teacherBlitzMonitoringStudent:$studentId'));

Finder _inRow(Finder row, String text) =>
    find.descendant(of: row, matching: find.text(text));

/// The value shown under a labelled timing field.
String _value(WidgetTester tester, String label) {
  return tester
      .widget<Text>(find.byKey(ValueKey('teacherBlitzMonitoringValue:$label')))
      .data!;
}

String _summary(WidgetTester tester, String label) {
  return tester
      .widget<Text>(
        find.byKey(ValueKey('teacherBlitzMonitoringSummaryCount:$label')),
      )
      .data!;
}
