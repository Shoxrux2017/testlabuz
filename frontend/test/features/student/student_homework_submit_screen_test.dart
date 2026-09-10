import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_route_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_submit_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_submit_readiness.dart';
import 'package:testlabuz_client/features/student/application/student_homework_submit_state.dart';
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';
import 'package:testlabuz_client/features/student/presentation/student_attempt_finalization_summary.dart';
import 'package:testlabuz_client/features/student/presentation/student_file_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_attempt_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_detail_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_submit_controls.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_answer_editor.dart';

import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000005';
const _attemptId = '60000000-0000-0000-0000-000000000005';
final _target = StudentHomeworkAttemptRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
  attemptId: _attemptId,
);
final _homeworkTarget = StudentHomeworkRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
);
String _questionId(int number) =>
    '70000000-0000-0000-0000-${number.toString().padLeft(12, '0')}';
final _submitButton = find.byKey(
  const Key('studentHomeworkSubmitAttemptButton'),
);
final _confirmButton = find.byKey(
  const Key('studentHomeworkSubmitConfirmButton'),
);
final _confirmDialog = find.byKey(
  const Key('studentHomeworkSubmitConfirmDialog'),
);

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    for (final saved in [9, 5, 0]) {
      testWidgets(
        '${surface.name} confirmation announces $saved of 9 and Cancel saves nothing',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final harness = await _pump(tester, surface: surface, saved: saved);
            expect(
              tester.widget<FilledButton>(_submitButton).onPressed,
              isNotNull,
            );
            await _tap(tester, _submitButton);
            expect(_confirmDialog, findsOneWidget);
            expect(find.text('Submit Attempt 1?'), findsOneWidget);
            expect(find.text('$saved of 9 answers are saved.'), findsOneWidget);
            expect(
              tester
                  .getSemantics(find.text('$saved of 9 answers are saved.'))
                  .label,
              contains('$saved of 9 answers are saved.'),
            );
            if (saved < 9) {
              expect(
                find.text('${9 - saved} Questions have no saved answer.'),
                findsOneWidget,
              );
            }
            expect(
              find.textContaining('Unanswered Questions are allowed.'),
              findsOneWidget,
            );
            expect(
              find.textContaining('cannot be edited afterward'),
              findsOneWidget,
            );
            expect(
              tester.widget<FilledButton>(_confirmButton).onPressed,
              isNotNull,
            );
            expect(
              tester
                  .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
                  .autofocus,
              isTrue,
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            expect(FocusManager.instance.primaryFocus, isNotNull);
            await _tap(tester, find.text('Cancel'));
            expect(harness.repository.submits, isEmpty);
            expect(harness.repository.saves, isEmpty);
            expect(harness.repository.uploads, isEmpty);
            expect(harness.keys.calls, 0);
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets(
      '${surface.name} dirty and pending file blockers require explicit resolution',
      (tester) async {
        final harness = await _pump(tester, surface: surface);
        harness.editor.updateDraft(
          _questionId(1),
          const StudentShortWrittenDraft(text: 'unsaved'),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);
        expect(
          find.text(
            'Save or discard unsaved answer changes before submitting.',
          ),
          findsOneWidget,
        );
        harness.editor.discardChanges(_questionId(1));
        await harness.files.chooseFile(_questionId(9));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);
        expect(
          find.text('Upload or discard the selected file before submitting.'),
          findsOneWidget,
        );
        harness.files.discardSelectedFile(_questionId(9));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(_submitButton).onPressed, isNotNull);
        expect(harness.repository.submits, isEmpty);
      },
    );

    testWidgets(
      '${surface.name} confirmed zero-answer Submit freezes controls and stays on route',
      (tester) async {
        final harness = await _pump(tester, surface: surface);
        await _submit(tester);
        expect(harness.repository.submits, hasLength(1));
        expect(harness.keys.calls, 1);
        expect(find.text('Submitting Attempt…'), findsOneWidget);
        _expectFrozen(tester);
        expect(_submitButton, findsNothing);
        await _tap(tester, find.byTooltip('Back to Homework'), settle: false);
        expect(find.text('Submission is in progress.'), findsOneWidget);
        expect(find.text('Wait until the result is known.'), findsOneWidget);
        expect(find.text('Leave'), findsNothing);
        await _tap(tester, find.text('Stay'), settle: false);
        expect(find.byType(StudentHomeworkAttemptScreen), findsOneWidget);
        harness.repository.submits.single.complete(_attempt(terminal: true));
        await tester.pumpAndSettle();
        expect(
          harness.submitState.status,
          StudentHomeworkSubmitStatus.completed,
        );
        expect(find.text('Attempt submitted successfully.'), findsOneWidget);
        expect(find.text('Submitted by you'), findsOneWidget);
        expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
        expect(_submitButton, findsNothing);
        expect(find.byType(StudentHomeworkAttemptScreen), findsOneWidget);
        expect(harness.homework.refreshes, 1);
        _expectFinalizationFields(tester, explicit: true);
        expect(find.text('Start another Attempt'), findsNothing);
        expect(find.text('Score'), findsNothing);
        await _tap(tester, find.byTooltip('Back to Homework'));
        expect(find.text('Homework destination'), findsOneWidget);
        expect(find.text('Leave Attempt?'), findsNothing);
      },
    );
  }

  for (final file in [false, true]) {
    testWidgets(
      '${file ? 'file upload' : 'answer save'} uncertainty blocks confirmation',
      (tester) async {
        final harness = await _pump(tester);
        if (file) {
          await harness.files.chooseFile(_questionId(9));
          final operation = harness.files.uploadAnswer(_questionId(9));
          harness.repository.uploads.single.completeError(
            studentLocalFailure(ApiFailureKind.timeout),
          );
          await operation;
        } else {
          harness.editor.updateDraft(
            _questionId(1),
            const StudentShortWrittenDraft(text: 'save this'),
          );
          final operation = harness.editor.saveAnswer(_questionId(1));
          harness.repository.saves.single.completeError(
            studentLocalFailure(ApiFailureKind.timeout),
          );
          await operation;
        }
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);
        expect(
          find.text(
            file
                ? 'Resolve the unconfirmed file upload before submitting.'
                : 'Resolve the unconfirmed answer save before submitting.',
          ),
          findsOneWidget,
        );
        expect(harness.repository.submits, isEmpty);
      },
    );
  }

  for (final status in StudentHomeworkAttemptLoadStatus.values.where(
    (status) => status != StudentHomeworkAttemptLoadStatus.data,
  )) {
    testWidgets(
      'Submit controls refuse retained Attempt under ${status.name}',
      (tester) async {
        final harness = await _pump(tester, controlsOnly: true);
        final current = harness.container.read(
          studentHomeworkAttemptControllerProvider(_target),
        );
        harness.parent.publish(
          StudentHomeworkAttemptState(
            status: status,
            attempt: current.attempt,
            publicationToken: current.publicationToken,
            failure: status == StudentHomeworkAttemptLoadStatus.error
                ? studentLocalFailure(ApiFailureKind.connection).failure
                : null,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);
        expect(_confirmDialog, findsNothing);
        expect(harness.repository.submits, isEmpty);
      },
    );
  }

  testWidgets(
    'missing local publication has readable blocker and no confirmation',
    (tester) async {
      final harness = await _pump(tester);
      harness.parent.publish(
        StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.data,
          attempt: _attempt(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);
      expect(
        find.text(
          'Refresh the Attempt to confirm the current saved answers before submitting.',
        ),
        findsOneWidget,
      );
      expect(_confirmDialog, findsNothing);
      expect(harness.keys.calls, 0);
    },
  );

  for (final change in [
    'draft',
    'file',
    'publication',
    'questions',
    'terminal',
    'session',
    'route',
  ]) {
    testWidgets(
      'confirmation changed $change sends no POST and claims no gate',
      (tester) async {
        final harness = await _pump(tester);
        await _tap(tester, _submitButton);
        switch (change) {
          case 'draft':
            harness.editor.updateDraft(
              _questionId(1),
              const StudentShortWrittenDraft(text: 'changed'),
            );
          case 'file':
            await harness.files.chooseFile(_questionId(9));
          case 'publication':
            harness.parent.publishData(_attempt());
          case 'questions':
            harness.parent.publishData(_attempt(questionCount: 8));
          case 'terminal':
            harness.parent.acceptAuthoritativeTerminalAttempt(
              _attempt(terminal: true),
            );
          case 'session':
            harness.auth.replaceUser(studentUser('student-b'));
          case 'route':
            GoRouter.of(tester.element(_confirmDialog)).go(
              AppRoutePaths.studentHomeworkDetailLocation(
                studentTopicId,
                _homeworkId,
              ),
            );
        }
        await tester.pumpAndSettle();
        if (_confirmButton.evaluate().isNotEmpty) {
          await _tap(tester, _confirmButton);
        }
        expect(_confirmDialog, findsNothing);
        expect(harness.repository.submits, isEmpty);
        expect(harness.keys.calls, 0);
        expect(
          harness.container.read(
            studentAttemptRouteOperationGateProvider(_target),
          ),
          StudentAttemptRouteOperation.idle,
        );
      },
    );
  }

  testWidgets(
    'unrelated terminal publication preserves owned Submit resolution controls',
    (tester) async {
      final harness = await _pump(tester);
      await _makeUncertain(tester, harness);
      harness.parent.publishData(_attempt(terminal: true));
      await tester.pumpAndSettle();
      expect(harness.submitState.status, StudentHomeworkSubmitStatus.uncertain);
      expect(find.byType(StudentAttemptFinalizationSummary), findsOneWidget);
      expect(find.text('Retry submission'), findsOneWidget);
      expect(find.text('Check current Attempt'), findsOneWidget);
      expect(find.text('Attempt submitted successfully.'), findsNothing);
      await _tap(tester, find.byTooltip('Back to Homework'));
      expect(
        find.textContaining('Leaving will discard this retry key.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Stay'));
      expect(harness.repository.submits, hasLength(1));
    },
  );

  testWidgets(
    'uncertain Retry uses same key and active Retry has stay-only Back',
    (tester) async {
      final harness = await _pump(tester, saved: 9);
      await _makeUncertain(tester, harness);
      _expectFrozen(tester);
      expect(
        find.text('We could not confirm whether this Attempt was submitted.'),
        findsOneWidget,
      );
      expect(_submitButton, findsNothing);
      await _tap(tester, find.text('Retry submission'), settle: false);
      expect(harness.repository.submits, hasLength(2));
      expect(
        harness.repository.submits[1].key,
        harness.repository.submits[0].key,
      );
      expect(harness.keys.calls, 1);
      expect(find.text('Check current Attempt'), findsNothing);
      await _tap(tester, find.byTooltip('Back to Homework'), settle: false);
      expect(find.text('Submission is in progress.'), findsOneWidget);
      expect(find.text('Leave'), findsNothing);
      await _tap(tester, find.text('Stay'), settle: false);
      harness.repository.submits.last.complete(
        _attempt(terminal: true, saved: 9),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attempt submitted successfully.'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Open'))
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final reason in StudentHomeworkAttemptFinalizationReason.values) {
    testWidgets(
      'owned Check displays ${reason.name} without current-operation success',
      (tester) async {
        final harness = await _pump(tester, saved: 9);
        await _makeUncertain(tester, harness);
        final check = Completer<StudentHomeworkAttempt>();
        harness.repository.nextFetches.add(check.future);
        await _tap(tester, find.text('Check current Attempt'), settle: false);
        expect(
          harness.submitState.status,
          StudentHomeworkSubmitStatus.checking,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Retry submission'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Check current Attempt'),
              )
              .onPressed,
          isNull,
        );
        _expectFrozen(tester);
        check.complete(_attempt(terminal: true, reason: reason, saved: 9));
        await tester.pumpAndSettle();
        expect(
          harness.submitState.status,
          StudentHomeworkSubmitStatus.reconciledTerminal,
        );
        expect(
          find.text(switch (reason) {
            StudentHomeworkAttemptFinalizationReason.studentSubmit =>
              'Submitted by you',
            StudentHomeworkAttemptFinalizationReason.homeworkDeadline =>
              'Finalized at the Homework deadline',
            StudentHomeworkAttemptFinalizationReason.taskClosed =>
              'Finalized when the Homework was closed',
          }),
          findsOneWidget,
        );
        expect(find.text('Attempt submitted successfully.'), findsNothing);
        if (reason == StudentHomeworkAttemptFinalizationReason.studentSubmit) {
          expect(
            find.text('This Attempt is already submitted.'),
            findsOneWidget,
          );
        }
        _expectFinalizationFields(
          tester,
          explicit:
              reason == StudentHomeworkAttemptFinalizationReason.studentSubmit,
        );
        expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
      },
    );
  }

  for (final checking in [false, true]) {
    testWidgets(
      'Homework notFound action respects ${checking ? 'checking' : 'active POST'} leave guard',
      (tester) async {
        final harness = await _pump(tester);
        final check = Completer<StudentHomeworkAttempt>();
        if (checking) {
          await _makeUncertain(tester, harness);
          harness.repository.nextFetches.add(check.future);
          await _tap(tester, find.text('Check current Attempt'), settle: false);
        } else {
          await _submit(tester);
        }
        harness.homework.publish(StudentHomeworkDetailStatus.notFound);
        await tester.pump();
        expect(find.text('Homework unavailable'), findsOneWidget);
        expect(find.text('Back to Topic'), findsNothing);
        await _tap(tester, find.text('Back to Homework'), settle: false);
        expect(find.byType(AlertDialog), findsOneWidget);
        if (checking) {
          expect(
            find.textContaining('Leaving will discard this retry key.'),
            findsOneWidget,
          );
        } else {
          expect(find.text('Submission is in progress.'), findsOneWidget);
          expect(find.text('Leave'), findsNothing);
        }
        await _tap(tester, find.text('Stay'), settle: false);
        expect(find.byType(StudentHomeworkAttemptScreen), findsOneWidget);
        if (checking) {
          check.complete(_attempt());
        } else {
          harness.repository.submits.single.completer.completeError(
            studentLocalFailure(ApiFailureKind.timeout),
          );
        }
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '${checking ? 'checking' : 'uncertain'} Stay preserves ownership and Leave clears local state without request',
      (tester) async {
        final harness = await _pump(tester, saved: 9);
        final submitSubscription = harness.container.listen(
          studentHomeworkSubmitControllerProvider(_target),
          (_, _) {},
        );
        final answerSubscription = harness.container.listen(
          studentAttemptAnswerEditorControllerProvider(_target),
          (_, _) {},
        );
        final fileSubscription = harness.container.listen(
          studentFileAnswerControllerProvider(_target),
          (_, _) {},
        );
        addTearDown(submitSubscription.close);
        addTearDown(answerSubscription.close);
        addTearDown(fileSubscription.close);
        await _makeUncertain(tester, harness);
        final check = Completer<StudentHomeworkAttempt>();
        if (checking) {
          harness.repository.nextFetches.add(check.future);
          await _tap(tester, find.text('Check current Attempt'), settle: false);
        }
        final fetches = harness.repository.fetches;
        final answerState = answerSubscription.read();
        final fileState = fileSubscription.read();
        await _tap(
          tester,
          find.byTooltip('Back to Homework'),
          settle: !checking,
        );
        expect(
          find.textContaining('Leaving will discard this retry key.'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        await _tap(tester, find.text('Stay'), settle: !checking);
        expect(answerSubscription.read(), same(answerState));
        expect(fileSubscription.read(), same(fileState));
        expect(
          harness.container.read(
            studentAttemptRouteOperationGateProvider(_target),
          ),
          StudentAttemptRouteOperation.submitUncertain,
        );
        await _tap(
          tester,
          find.byTooltip('Back to Homework'),
          settle: !checking,
        );
        await _tap(tester, find.text('Leave'));
        expect(find.text('Homework destination'), findsOneWidget);
        expect(
          submitSubscription.read().status,
          StudentHomeworkSubmitStatus.idle,
        );
        expect(answerSubscription.read().questions, isEmpty);
        expect(fileSubscription.read().questions, isEmpty);
        expect(harness.repository.fetches, fetches);
        expect(harness.repository.submits, hasLength(1));
        if (checking) {
          check.complete(_attempt(terminal: true));
          await tester.pumpAndSettle();
          expect(
            submitSubscription.read().status,
            StudentHomeworkSubmitStatus.idle,
          );
          expect(find.text('Homework destination'), findsOneWidget);
          expect(find.text('Attempt submitted successfully.'), findsNothing);
        }
      },
    );
  }

  testWidgets(
    'terminal summary survives matching retained Homework refresh and error',
    (tester) async {
      final harness = await _pump(tester);
      await _submit(tester);
      harness.repository.submits.single.complete(_attempt(terminal: true));
      await tester.pumpAndSettle();
      expect(
        harness.homework.current.status,
        StudentHomeworkDetailStatus.refreshing,
      );
      _expectFinalizationFields(tester, explicit: true);
      for (final status in [
        StudentHomeworkDetailStatus.error,
        StudentHomeworkDetailStatus.data,
      ]) {
        harness.homework.publish(status);
        await tester.pumpAndSettle();
        expect(find.text('Submit homework'), findsOneWidget);
        _expectFinalizationFields(tester, explicit: true);
        expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
      }
      for (final homework in [
        _homework(id: studentMaterialId),
        _homework(topicId: studentMaterialId),
      ]) {
        harness.homework.publish(
          StudentHomeworkDetailStatus.error,
          homework: homework,
        );
        await tester.pumpAndSettle();
        expect(find.byType(StudentAttemptFinalizationSummary), findsNothing);
        expect(find.text('Unable to load Homework'), findsOneWidget);
      }
      harness.homework.publish(StudentHomeworkDetailStatus.notFound);
      await tester.pumpAndSettle();
      expect(find.text('Homework unavailable'), findsOneWidget);
      expect(find.byType(StudentAttemptFinalizationSummary), findsNothing);
    },
  );

  testWidgets(
    '320px mobile double text scale keeps dialog and terminal controls usable',
    (tester) async {
      final harness = await _pump(
        tester,
        surface: AppDeviceSurface.mobile,
        width: 320,
        textScale: 2,
      );
      await _tap(tester, _submitButton);
      expect(tester.widget<AlertDialog>(_confirmDialog).scrollable, isTrue);
      await _tap(tester, _confirmButton, settle: false);
      harness.repository.submits.single.complete(_attempt(terminal: true));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Finalization reason'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(StudentAttemptFinalizationSummary)).width,
        lessThanOrEqualTo(320),
      );
      await _tap(tester, find.byTooltip('Back to Homework'));
      expect(find.text('Homework destination'), findsOneWidget);
    },
  );
  for (final remaining in [2, 0]) {
    testWidgets(
      'Back after Submit uses refreshed Homework remaining=$remaining for Start availability',
      (tester) async {
        final harness = await _pump(tester, actualHomeworkDestination: true);
        await _submit(tester);
        harness.repository.submits.single.complete(_attempt(terminal: true));
        await tester.pumpAndSettle();
        expect(find.text('Start Attempt'), findsNothing);
        final refreshed = _homework(remaining: remaining, submitted: true);
        harness.homework.publish(
          StudentHomeworkDetailStatus.data,
          homework: refreshed,
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.byTooltip('Back to Homework'));
        expect(find.byType(StudentHomeworkDetailScreen), findsOneWidget);
        expect(harness.homework.current.homework, same(refreshed));
        expect(
          harness.homework.current.homework!.attempts.remaining,
          remaining,
        );
        expect(
          harness.homework.current.homework!.attempts.inProgressAttempt,
          isNull,
        );
        final start = find.byKey(
          const Key('studentHomeworkStartAttemptButton'),
        );
        expect(start, remaining > 0 ? findsOneWidget : findsNothing);
        if (remaining > 0) {
          expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        }
        expect(
          find.byKey(const Key('studentHomeworkResumeAttemptButton')),
          findsNothing,
        );
        expect(harness.repository.submits, hasLength(1));
      },
    );
  }
}

void _expectFrozen(WidgetTester tester) {
  for (final editor in tester.widgetList<StudentQuestionAnswerEditor>(
    find.byType(StudentQuestionAnswerEditor),
  )) {
    expect(editor.canEdit, isFalse);
    expect(editor.canSave, isFalse);
  }
  final file = tester.widget<StudentFileAnswerEditor>(
    find.byType(StudentFileAnswerEditor),
  );
  expect(file.canChoose, isFalse);
  expect(file.canUpload, isFalse);
  expect(file.canDiscard, isFalse);
  expect(file.canTransfer, isFalse);
  expect(
    tester
        .widget<IconButton>(
          find.byKey(const Key('studentHomeworkAttemptRefreshButton')),
        )
        .onPressed,
    isNull,
  );
  for (final action in ['Open', 'Save As…']) {
    final finder = find.widgetWithText(OutlinedButton, action);
    if (finder.evaluate().isNotEmpty) {
      expect(tester.widget<OutlinedButton>(finder).onPressed, isNull);
    }
  }
}

void _expectFinalizationFields(WidgetTester tester, {required bool explicit}) {
  final summary = find.byType(StudentAttemptFinalizationSummary);
  expect(summary, findsOneWidget);
  for (final label in [
    'Status',
    'Finalized at',
    'Finalization reason',
    if (explicit) 'Submitted at',
  ]) {
    expect(find.text(label), findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.text(label)),
      findsOneWidget,
    );
  }
  if (!explicit) expect(find.text('Submitted at'), findsNothing);
  expect(find.text('Started'), findsOneWidget);
  expect(find.text('Deadline'), findsOneWidget);
  expect(find.text('Attempt 1'), findsOneWidget);
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _submit(WidgetTester tester) async {
  await _tap(tester, _submitButton);
  await _tap(tester, _confirmButton, settle: false);
}

Future<void> _makeUncertain(WidgetTester tester, _Harness harness) async {
  await _submit(tester);
  harness.repository.submits.single.completer.completeError(
    studentLocalFailure(ApiFailureKind.timeout),
  );
  await tester.pumpAndSettle();
  expect(harness.submitState.status, StudentHomeworkSubmitStatus.uncertain);
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  int saved = 0,
  bool controlsOnly = false,
  bool actualHomeworkDestination = false,
  double? width,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(
    Size(width ?? (surface == AppDeviceSurface.mobile ? 390 : 1100), 900),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final harness = _Harness(saved);
  final router = GoRouter(
    initialLocation: AppRoutePaths.studentHomeworkAttemptLocation(
      studentTopicId,
      _homeworkId,
      _attemptId,
    ),
    routes: [
      GoRoute(
        path: AppRoutePaths.studentHomeworkAttemptLocation(
          studentTopicId,
          _homeworkId,
          _attemptId,
        ),
        builder: (_, _) => controlsOnly
            ? Scaffold(
                body: StudentHomeworkSubmitControls(
                  target: _target,
                  attemptNumber: 1,
                  isTerminal: false,
                ),
              )
            : StudentHomeworkAttemptScreen(target: _target),
      ),
      GoRoute(
        path: AppRoutePaths.studentHomeworkDetailLocation(
          studentTopicId,
          _homeworkId,
        ),
        builder: (_, _) => actualHomeworkDestination
            ? StudentHomeworkDetailScreen(target: _homeworkTarget)
            : const Scaffold(body: Text('Homework destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(() => harness.auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        idempotencyKeyGeneratorProvider.overrideWithValue(harness.keys),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(
          harness.repository,
        ),
        studentSubmissionFilePickerProvider.overrideWithValue(_Picker()),
        studentHomeworkAttemptControllerProvider(
          _target,
        ).overrideWith(() => harness.parent),
        studentHomeworkDetailControllerProvider(
          _homeworkTarget,
        ).overrideWith(() => harness.homework),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  harness.container = ProviderScope.containerOf(
    tester.element(find.byType(StudentHomeworkSubmitControls)),
  );
  expect(
    harness.container
        .read(studentHomeworkSubmitReadinessProvider(_target))
        .isReady,
    isTrue,
  );
  return harness;
}

class _Harness {
  _Harness(int saved) : repository = _Repository(_attempt(saved: saved));
  final _Repository repository;
  final parent = _AttemptController();
  final homework = _HomeworkController();
  final keys = _Keys();
  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  late ProviderContainer container;
  StudentAttemptAnswerEditorController get editor => container.read(
    studentAttemptAnswerEditorControllerProvider(_target).notifier,
  );
  StudentFileAnswerController get files =>
      container.read(studentFileAnswerControllerProvider(_target).notifier);
  StudentHomeworkSubmitState get submitState =>
      container.read(studentHomeworkSubmitControllerProvider(_target));
}

class _AttemptController extends StudentHomeworkAttemptController {
  _AttemptController() : super(_target);
  void publish(StudentHomeworkAttemptState value) => state = value;
  void publishData(StudentHomeworkAttempt attempt) => publish(
    StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.data,
      attempt: attempt,
      publicationToken: StudentHomeworkAttemptPublicationToken(),
    ),
  );
}

class _HomeworkController extends StudentHomeworkDetailController {
  _HomeworkController() : super(_homeworkTarget);
  int refreshes = 0;
  StudentHomeworkDetailState get current => state;
  @override
  StudentHomeworkDetailState build() => StudentHomeworkDetailState(
    status: StudentHomeworkDetailStatus.data,
    homework: _homework(),
  );
  @override
  void refresh() {
    refreshes++;
    publish(StudentHomeworkDetailStatus.refreshing);
  }

  void publish(
    StudentHomeworkDetailStatus status, {
    StudentHomeworkDetail? homework,
  }) {
    state = StudentHomeworkDetailState(
      status: status,
      homework: homework ?? _homework(),
      failure: status == StudentHomeworkDetailStatus.error
          ? studentLocalFailure(ApiFailureKind.connection).failure
          : null,
    );
  }
}

class _Keys implements IdempotencyKeyGenerator {
  int calls = 0;
  @override
  String generate() {
    calls++;
    return '80000000-0000-4000-8000-${calls.toString().padLeft(12, '0')}';
  }
}

class _Picker implements StudentSubmissionFilePicker {
  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) async => StudentSubmissionUploadFile(
    name: 'selected.pdf',
    length: 5,
    openRead: () => Stream.value([1, 2, 3, 4, 5]),
  );
}

class _Submit {
  _Submit(this.key);
  final String key;
  final completer = Completer<StudentHomeworkSubmitResult>();
  void complete(StudentHomeworkAttempt attempt) =>
      completer.complete(StudentHomeworkSubmitResult(attempt: attempt));
}

class _Repository implements StudentHomeworkAttemptRepository {
  _Repository(this.current);
  StudentHomeworkAttempt current;
  final submits = <_Submit>[];
  final saves = <Completer<StudentAttemptAnswerMutationResult>>[];
  final uploads = <Completer<StudentAttemptAnswerMutationResult>>[];
  final nextFetches = Queue<Future<StudentHomeworkAttempt>>();
  int fetches = 0;
  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) {
    fetches++;
    return nextFetches.isEmpty
        ? Future.value(current)
        : nextFetches.removeFirst();
  }

  @override
  Future<StudentHomeworkSubmitResult> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  ) {
    final submit = _Submit(idempotencyKey);
    submits.add(submit);
    return submit.completer.future;
  }

  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) {
    final operation = Completer<StudentAttemptAnswerMutationResult>();
    saves.add(operation);
    return operation.future;
  }

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) {
    final operation = Completer<StudentAttemptAnswerMutationResult>();
    uploads.add(operation);
    return operation.future;
  }

  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) => throw StateError('Submit screen must never start another Attempt.');
}

StudentHomeworkAttempt _attempt({
  int saved = 0,
  int questionCount = 9,
  bool terminal = false,
  StudentHomeworkAttemptFinalizationReason reason =
      StudentHomeworkAttemptFinalizationReason.studentSubmit,
}) => StudentHomeworkAttempt(
  id: _attemptId,
  assessmentId: _homeworkId,
  attemptNumber: 1,
  status: terminal
      ? StudentHomeworkAttemptStatus.submitted
      : StudentHomeworkAttemptStatus.inProgress,
  startedAt: DateTime.utc(2026, 9, 8, 12),
  submittedAt:
      terminal &&
          reason == StudentHomeworkAttemptFinalizationReason.studentSubmit
      ? DateTime.utc(2026, 9, 8, 13)
      : null,
  finalizedAt: terminal
      ? reason == StudentHomeworkAttemptFinalizationReason.homeworkDeadline
            ? DateTime.utc(2026, 9, 10, 13)
            : DateTime.utc(2026, 9, 8, 13)
      : null,
  finalizationReason: terminal ? reason : null,
  deadlineAt: DateTime.utc(2026, 9, 10, 13),
  questions: [
    for (var number = 1; number <= questionCount; number++)
      StudentQuestion(
        id: _questionId(number),
        type: number == 9
            ? StudentQuestionType.fileBased
            : StudentQuestionType.shortWritten,
        prompt: 'Question $number',
        instructions: null,
        points: 1,
        position: number,
        answerUi: number == 9
            ? StudentFileAnswerUi(
                allowedExtensions: ['pdf', 'docx', 'ppt', 'pptx'],
                maxSizeBytes: 10000,
              )
            : const StudentEmptyAnswerUi(),
      ),
  ],
  answers: [
    for (var number = 1; number <= saved; number++)
      StudentAttemptAnswerState(
        questionId: _questionId(number),
        type: number == 9
            ? StudentQuestionType.fileBased
            : StudentQuestionType.shortWritten,
        value: number == 9
            ? const StudentFileAnswerValue(
                file: StudentSubmissionFile(
                  id: studentFileId,
                  originalName: 'saved-answer.pdf',
                  extension: 'pdf',
                  sizeBytes: 100,
                ),
              )
            : StudentTextAnswerValue(text: 'Saved answer $number'),
        updatedAt: DateTime.utc(2026, 9, 8, 12, 30),
      ),
  ],
);

StudentHomeworkDetail _homework({
  String id = _homeworkId,
  String topicId = studentTopicId,
  int remaining = 2,
  bool submitted = false,
}) => StudentHomeworkDetail(
  id: id,
  topic: StudentHomeworkTopicSummary(id: topicId, title: 'Topic'),
  title: 'Submit homework',
  description: null,
  studentInstructions: 'Answer the questions.',
  status: StudentHomeworkStatus.active,
  deadlineAt: DateTime.utc(2026, 9, 10, 13),
  totalPossiblePoints: 9,
  attempts: StudentHomeworkAttemptSummary(
    allowed: 3,
    used: 1,
    remaining: remaining,
    officialScorePolicy: 'highest_valid_completed',
  ),
  myStatus: submitted
      ? StudentHomeworkMyStatus.submitted
      : StudentHomeworkMyStatus.inProgress,
  scoreVisible: false,
  questions: _attempt().questions,
);
