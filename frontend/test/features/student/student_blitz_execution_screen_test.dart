import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/application/student_answer_autosave.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_countdown_clock.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_active_blitz_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_controller.dart';
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/data/student_attempt_answer_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/presentation/student_blitz_countdown.dart';
import 'package:testlabuz_client/features/student/presentation/student_blitz_detail_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_file_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_read_view.dart';

import 'student_autosave_test_support.dart';
import 'student_blitz_execution_test_support.dart';
import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    group(surface.name, () {
      testWidgets('every Question type appears once in its shared editor', (
        tester,
      ) async {
        final h = await _Harness.executing(
          tester,
          surface,
          attempt: blitzExecutionAttempt(
            types: [...blitzNonFileTypes, StudentQuestionType.fileBased],
          ),
        );
        expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(8));
        expect(find.byType(StudentFileAnswerEditor), findsOneWidget);
        expect(find.byType(StudentQuestionReadView), findsNothing);
        expect(find.byType(StudentBlitzCountdown), findsOneWidget);
        expect(find.text('Time remaining'), findsOneWidget);
        await _scrollTo(
          tester,
          find.byKey(const Key('studentBlitzSubmitButton')),
        );
        expect(tester.takeException(), isNull);
        expect(h.attempts.submits, isEmpty);
      });

      testWidgets('an unanswered Attempt submits after confirmation', (
        tester,
      ) async {
        final h = await _Harness.executing(tester, surface);
        await _scrollTo(
          tester,
          find.byKey(const Key('studentBlitzSubmitButton')),
        );
        await _tap(tester, find.byKey(const Key('studentBlitzSubmitButton')));
        await _settle(tester);
        expect(find.text('Submit Blitz?'), findsOneWidget);
        expect(find.text('Answered: 0 of 3'), findsOneWidget);
        expect(find.text('Unanswered: 3'), findsOneWidget);
        expect(
          find.text('You still have 3 unanswered Questions.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('studentBlitzUnansweredWarning')),
          findsOneWidget,
        );
        expect(
          find.text(
            'After submission, this attempt cannot be edited.\n'
            'Unanswered Questions will remain unanswered.',
          ),
          findsOneWidget,
        );
        final confirm = tester.widget<FilledButton>(
          find.byKey(const Key('studentBlitzSubmitConfirmButton')),
        );
        expect(confirm.onPressed, isNotNull);
        await tester.tap(find.text('Cancel'));
        await _settle(tester);
        expect(h.attempts.submits, isEmpty);

        await _tap(tester, find.byKey(const Key('studentBlitzSubmitButton')));
        await _settle(tester);
        await tester.tap(
          find.byKey(const Key('studentBlitzSubmitConfirmButton')),
        );
        await _settle(tester);
        expect(
          h.attempts.submits.single.expectation,
          StudentBlitzSubmitResponseExpectation.fresh,
        );
        expect(
          find.byKey(const Key('studentBlitzFinalizationSummary')),
          findsOneWidget,
        );
        expect(find.text('Blitz submitted successfully.'), findsOneWidget);
        expect(find.text('0 of 3'), findsOneWidget);
        expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
        expect(find.byType(StudentBlitzCountdown), findsNothing);
        _expectNoScore();
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('an answer saves automatically and Submit stays available', (
    tester,
  ) async {
    final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
    await _tap(tester, find.text('True'));
    await tester.pump();
    expect(find.text('Some answers are still being saved.'), findsNothing);
    expect(_submitEnabled(tester), isTrue);
    expect(find.text('Save answer'), findsNothing);
    await _autosave(tester, h);
    expect(find.text('Saving…'), findsOneWidget);
    h.answers.saves.single.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: true),
      ),
    );
    await _settle(tester);
    expect(_saveStatus(tester, 1), 'Saved');
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('Submit saves a pending answer first, then confirms', (
    tester,
  ) async {
    final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
    await _tap(tester, find.text('True'));
    await tester.pump();
    final file = find.byType(StudentFileAnswerEditor);
    expect(tester.widget<StudentFileAnswerEditor>(file).canChoose, isTrue);
    await _tap(tester, find.byKey(const Key('studentBlitzSubmitButton')));
    await tester.pump();
    expect(find.text('Saving answers…'), findsOneWidget);
    expect(
      find.byKey(const Key('studentBlitzSubmitCancelSaving')),
      findsOneWidget,
    );
    // Saving makes every editor read-only, file choices included.
    expect(tester.widget<StudentFileAnswerEditor>(file).canChoose, isFalse);
    expect(h.answers.saves, hasLength(1));
    h.answers.saves.single.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: true),
      ),
    );
    await _settle(tester);
    expect(find.text('Submit Blitz?'), findsOneWidget);
    expect(find.text('Answered: 1 of 3'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(h.attempts.submits, isEmpty);
  });

  testWidgets('a flush cancelled by leaving is not a save failure', (
    tester,
  ) async {
    final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
    await _tap(tester, find.text('True'));
    await tester.pump();
    await _tap(tester, find.byKey(const Key('studentBlitzSubmitButton')));
    await tester.pump();

    // The leave dialog shares this flush and cancels it.
    h.container
        .read(
          studentBlitzAnswerEditorControllerProvider(
            blitzExecutionTarget,
          ).notifier,
        )
        .cancelFlush();
    await tester.pump();

    expect(
      find.text('Some answers are not saved yet. Check the marked questions.'),
      findsNothing,
    );
    h.answers.saves.single.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: true),
      ),
    );
    await _settle(tester);
    expect(find.text('Submit Blitz?'), findsNothing);
  });

  testWidgets('Cancel stops saving before Submit', (tester) async {
    final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
    await _tap(tester, find.text('True'));
    await tester.pump();
    await _tap(tester, find.byKey(const Key('studentBlitzSubmitButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('studentBlitzSubmitCancelSaving')));
    await tester.pump();
    expect(find.text('Saving answers…'), findsNothing);
    expect(
      find.text('Some answers are not saved yet. Check the marked questions.'),
      findsNothing,
    );
    h.answers.saves.single.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: true),
      ),
    );
    await _settle(tester);
    // The cancelled Submit opens no confirmation once the save lands.
    expect(find.text('Submit Blitz?'), findsNothing);
    expect(_saveStatus(tester, 1), 'Saved');
    expect(_submitEnabled(tester), isTrue);
    expect(h.attempts.submits, isEmpty);
  });

  testWidgets('the not-saved message clears once the answer is saved', (
    tester,
  ) async {
    final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
    await _tap(tester, find.text('True'));
    await tester.pump();
    await _tap(tester, find.byKey(const Key('studentBlitzSubmitButton')));
    await tester.pump();
    h.answers.saves.single.fail(
      studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
    );
    await _settle(tester);
    const message =
        'Some answers are not saved yet. Check the marked questions.';
    expect(find.text(message), findsOneWidget);
    await _tap(tester, find.text('False'));
    await tester.pump();
    await _autosave(tester, h);
    h.answers.saves.last.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: false),
      ),
    );
    await _settle(tester);
    expect(find.text(message), findsNothing);
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('a cleared written answer is saved as empty', (tester) async {
    final h = await _Harness.executing(
      tester,
      AppDeviceSurface.desktop,
      attempt: blitzExecutionAttempt(
        answers: [
          blitzSavedAnswer(
            2,
            StudentQuestionType.openWritten,
            const StudentTextAnswerValue(text: 'Old answer'),
          ),
        ],
      ),
    );
    await _tap(tester, find.text('Clear answer'));
    await tester.pump();
    await _autosave(tester, h);
    expect(h.answers.saves.single.mutation.toJson(), {
      'type': 'open_written',
      'text': '',
    });
    h.answers.saves.single.complete(
      blitzMutationResult(2, StudentQuestionType.openWritten, null),
    );
    await _settle(tester);
    expect(_saveStatus(tester, 2), 'Not answered');
  });

  testWidgets('a current file can be replaced', (tester) async {
    final h = await _Harness.executing(
      tester,
      AppDeviceSurface.desktop,
      attempt: blitzExecutionAttempt(
        answers: [
          blitzSavedAnswer(
            3,
            StudentQuestionType.fileBased,
            StudentFileAnswerValue(file: blitzServerFile(name: 'old.pdf')),
          ),
        ],
      ),
    );
    await _scrollTo(tester, find.text('Choose replacement'));
    await _tap(tester, find.text('Choose replacement'));
    await tester.pump();
    h.picker.pending.single.complete(blitzUploadFile(name: 'new.pdf'));
    await _settle(tester);
    // The chosen file uploads at once.
    expect(
      find.text('Wait for the current file operation to finish.'),
      findsOneWidget,
    );
    expect(find.text('Upload replacement'), findsNothing);
    h.answers.uploads.single.complete(
      blitzMutationResult(
        3,
        StudentQuestionType.fileBased,
        StudentFileAnswerValue(file: blitzServerFile(name: 'new.pdf')),
      ),
    );
    await _settle(tester);
    expect(find.text('new.pdf'), findsOneWidget);
    expect(find.text('File answer uploaded.'), findsOneWidget);
  });

  testWidgets('an unconfirmed save offers only Check current attempt', (
    tester,
  ) async {
    final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
    await _tap(tester, find.text('True'));
    await tester.pump();
    await _autosave(tester, h);
    h.answers.saves.single.fail(studentLocalFailure(ApiFailureKind.timeout));
    await _settle(tester);
    expect(_saveStatus(tester, 1), 'Save not confirmed. Checking…');
    expect(find.text('Retry Save'), findsNothing);
    expect(
      find.text('An answer save is not confirmed yet. It is being checked.'),
      findsOneWidget,
    );
    h.start = Completer<StudentBlitzAttemptStartResult>();
    await _tap(tester, find.text('Check current attempt'));
    await tester.pump();
    expect(h.attempts.requests, hasLength(2));
    expect(h.attempts.requests.last, same(h.attempts.requests.first));
    expect(h.answers.saves, hasLength(1));
  });

  testWidgets('an unconfirmed Submit offers same-key Retry and Check', (
    tester,
  ) async {
    final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
    h.submit = studentLocalFailure(ApiFailureKind.timeout);
    await _submitThroughDialog(tester);
    expect(
      find.text('We could not confirm whether the Blitz was submitted.'),
      findsOneWidget,
    );
    expect(find.text('Retry Submit'), findsOneWidget);
    expect(
      find.byKey(const Key('studentBlitzSubmitCheckButton')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('studentBlitzSubmitButton')), findsNothing);
    // Answers stay locked while the Submit outcome is unknown.
    final editor = tester.widget<StudentQuestionAnswerEditor>(
      find.byType(StudentQuestionAnswerEditor).first,
    );
    expect(editor.canEdit, isFalse);
    h.submit = StudentBlitzSubmitResult(attempt: _submitted());
    await _tap(tester, find.text('Retry Submit'));
    await _settle(tester);
    expect(h.attempts.submits, hasLength(2));
    expect(
      h.attempts.submits.last.idempotencyKey,
      h.attempts.submits.first.idempotencyKey,
    );
    expect(
      h.attempts.submits.last.expectation,
      StudentBlitzSubmitResponseExpectation.completedReplay,
    );
    expect(find.text('Blitz submitted successfully.'), findsOneWidget);
  });

  testWidgets('local zero locks every write and warns about local drafts', (
    tester,
  ) async {
    final h = await _Harness.executing(
      tester,
      AppDeviceSurface.desktop,
      attempt: blitzExecutionAttempt(
        remainingSeconds: 2,
        serverNow: DateTime.utc(2026, 9, 17, 12, 4, 58),
      ),
    );
    await _tap(tester, find.text('True'));
    await tester.pump();
    h.start = Completer<StudentBlitzAttemptStartResult>();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Checking current Blitz time…'), findsOneWidget);
    expect(
      find.byKey(const Key('studentBlitzUnconfirmedAtZero')),
      findsOneWidget,
    );
    final editor = tester.widget<StudentQuestionAnswerEditor>(
      find.byType(StudentQuestionAnswerEditor).first,
    );
    expect(editor.canEdit, isFalse);
    final file = tester.widget<StudentFileAnswerEditor>(
      find.byType(StudentFileAnswerEditor),
    );
    expect(file.canChoose, isFalse);
    expect(_submitEnabled(tester), isFalse);
    expect(h.answers.saves, isEmpty);
    expect(h.attempts.submits, isEmpty);
    expect(h.attempts.requests, hasLength(2));

    await tester.tap(find.byTooltip('Back to Topic'));
    await _settle(tester);
    expect(
      find.textContaining('The current attempt is still being checked.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('A save result is still unconfirmed.'),
      findsNothing,
    );
  });

  testWidgets('Teacher close ends in the closed summary', (tester) async {
    final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
    h.start = studentBlitzStartResult(
      attempt: blitzExecutionAttempt(
        status: StudentBlitzAttemptStatus.submitted,
        finalizationReason: StudentBlitzAttemptFinalizationReason.taskClosed,
        answers: [
          blitzSavedAnswer(
            2,
            StudentQuestionType.openWritten,
            const StudentTextAnswerValue(text: 'Kept answer'),
          ),
        ],
      ),
    );
    // A detail read reports the Close; the replay shows the Attempt's end.
    h.detail = studentServerFailure(
      ApiErrorCodes.blitzNotActive,
      statusCode: 409,
    );
    h.container
        .read(studentBlitzDetailControllerProvider(blitzRouteTarget).notifier)
        .refresh();
    await _settle(tester);
    expect(h.attempts.requests, hasLength(2));
    expect(h.attempts.requests.last, same(h.attempts.requests.first));
    expect(find.text('Blitz closed'), findsOneWidget);
    expect(find.text('The Teacher closed the Blitz.'), findsOneWidget);
    expect(find.text('Kept answer'), findsOneWidget);
    expect(find.text('This Blitz attempt is already submitted.'), findsNothing);
    _expectNoScore();
  });

  group('leave guards', () {
    testWidgets(
      'leaving saves a pending answer first and keeps the timer warning',
      (tester) async {
        final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
        await _tap(tester, find.text('True'));
        await tester.pump();
        await tester.tap(find.byTooltip('Back to Topic'));
        await tester.pump();
        expect(
          find.byKey(const Key('studentBlitzSavingDialog')),
          findsOneWidget,
        );
        expect(h.answers.saves, hasLength(1));
        h.answers.saves.single.complete(
          blitzMutationResult(
            1,
            StudentQuestionType.trueFalse,
            const StudentBooleanAnswerValue(value: true),
          ),
        );
        await _settle(tester);
        expect(
          find.byKey(const Key('studentBlitzLeaveDialog')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Your server timer will continue.'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('studentBlitzLeaveConfirmButton')),
        );
        await _settle(tester);
        expect(
          h.path,
          AppRoutePaths.studentTopicDetailLocation(studentTopicId),
        );
        expect(h.answers.saves, hasLength(1));
        expect(h.attempts.requests, hasLength(1));
      },
    );

    testWidgets('an answer that could not be saved warns before leaving', (
      tester,
    ) async {
      final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
      await _tap(tester, find.text('True'));
      await tester.pump();
      await _autosave(tester, h);
      h.answers.saves.single.fail(
        studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
      );
      await _settle(tester);
      await tester.tap(find.byTooltip('Back to Topic'));
      await _settle(tester);
      expect(
        find.text(
          'Some answers are not saved.\n'
          'Leave and lose these changes?\n'
          'Your server timer continues.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('studentBlitzLeaveConfirmButton')));
      await _settle(tester);
      expect(h.path, AppRoutePaths.studentTopicDetailLocation(studentTopicId));
      expect(h.answers.saves, hasLength(1));
    });

    testWidgets('an unconfirmed upload warns before leaving', (tester) async {
      final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
      await _scrollTo(tester, find.text('Choose file'));
      await _tap(tester, find.text('Choose file'));
      await tester.pump();
      h.picker.pending.single.complete(blitzUploadFile());
      await _settle(tester);
      h.answers.uploads.single.fail(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await _settle(tester);
      await tester.tap(find.byTooltip('Back to Topic'));
      await _settle(tester);
      expect(
        find.textContaining('A save result is still unconfirmed.'),
        findsOneWidget,
      );
    });

    for (final (stay, uploads) in [(true, 1), (false, 0)]) {
      testWidgets('a file picked during a replay waits while leaving is asked; '
          '${stay ? 'Stay' : 'Leave'} uploads $uploads', (tester) async {
        final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
        await _scrollTo(tester, find.text('Choose file'));
        await _tap(tester, find.text('Choose file'));
        await tester.pump();
        // The Attempt is replayed while the picker is open.
        final replay = Completer<StudentBlitzAttemptStartResult>();
        h.start = replay;
        unawaited(
          h.container
              .read(
                studentBlitzExecutionControllerProvider(
                  blitzRouteTarget,
                ).notifier,
              )
              .refreshCurrentAttempt(),
        );
        await tester.pump();
        h.picker.pending.single.complete(blitzUploadFile());
        await _settle(tester);
        expect(h.answers.uploads, isEmpty);

        await tester.tap(find.byTooltip('Back to Topic'));
        await _settle(tester);
        replay.complete(
          studentBlitzStartResult(
            attempt: blitzExecutionAttempt(),
            kind: StudentBlitzAttemptStartResultKind.resumed,
          ),
        );
        await _settle(tester);
        expect(h.answers.uploads, isEmpty);

        await tester.tap(
          stay
              ? find.text('Stay')
              : find.byKey(const Key('studentBlitzLeaveConfirmButton')),
        );
        await _settle(tester);
        expect(h.answers.uploads, hasLength(uploads));
      });
    }

    testWidgets('a pending answer saves as soon as the app is paused', (
      tester,
    ) async {
      final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      addTearDown(() {
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      });
      await _tap(tester, find.text('True'));
      await tester.pump();
      expect(h.answers.saves, isEmpty);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(h.answers.saves, hasLength(1));
    });

    testWidgets('a Submit in flight cannot be abandoned', (tester) async {
      final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
      h.submit = Completer<StudentBlitzSubmitResult>();
      await _submitThroughDialog(tester);
      await tester.tap(find.byTooltip('Back to Topic'));
      await _settle(tester);
      expect(find.text('Submission is in progress.'), findsOneWidget);
      expect(find.text('Wait until the result is known.'), findsOneWidget);
      expect(
        find.byKey(const Key('studentBlitzLeaveConfirmButton')),
        findsNothing,
      );
      await tester.tap(find.text('Stay'));
      await _settle(tester);
      expect(
        h.path,
        isNot(AppRoutePaths.studentTopicDetailLocation(studentTopicId)),
      );
    });

    testWidgets('an unconfirmed Submit warns without promising Resume', (
      tester,
    ) async {
      final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
      h.submit = studentLocalFailure(ApiFailureKind.timeout);
      await _submitThroughDialog(tester);
      await tester.tap(find.byTooltip('Back to Topic'));
      await _settle(tester);
      expect(
        find.text(
          'The submission result is unconfirmed.\n'
          'Leaving will discard this local retry key.\n'
          'When you return, the app will reload the current server state.\n'
          'If this attempt is still in progress, Resume will be available.\n'
          'If it was finalized while you were away, it may no longer be '
          'resumable.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('studentBlitzLeaveConfirmButton')));
      await _settle(tester);
      expect(h.attempts.submits, hasLength(1));
      expect(h.path, AppRoutePaths.studentTopicDetailLocation(studentTopicId));
    });

    testWidgets('an unconfirmed save warns without promising Resume', (
      tester,
    ) async {
      final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
      await _tap(tester, find.text('True'));
      await tester.pump();
      await _autosave(tester, h);
      h.answers.saves.single.fail(studentLocalFailure(ApiFailureKind.timeout));
      await _settle(tester);
      await tester.tap(find.byTooltip('Back to Topic'));
      await _settle(tester);
      expect(
        find.textContaining('A save result is still unconfirmed.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('it may no longer be resumable'),
        findsOneWidget,
      );
      expect(find.textContaining('save failed'), findsNothing);
    });
  });

  group('return after leaving', () {
    testWidgets('an Attempt still in progress offers Resume only', (
      tester,
    ) async {
      final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
      await _leave(tester);
      h.detail = inProgressBlitzDetail();
      await _returnToBlitz(tester, h);
      expect(find.byKey(const Key('studentBlitzResumeButton')), findsOneWidget);
      expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
      h.start = studentBlitzStartResult(
        kind: StudentBlitzAttemptStartResultKind.resumed,
        attempt: blitzExecutionAttempt(),
      );
      await _tap(tester, find.byKey(const Key('studentBlitzResumeButton')));
      await _settle(tester);
      final resume = h.attempts.requests.last;
      expect(resume.toJson(), {
        'intent': 'resume',
        'attempt_id': studentBlitzAttemptId,
      });
      expect(
        resume.idempotencyKey,
        isNot(h.attempts.requests.first.idempotencyKey),
      );
      expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(2));

      // The new completed request is the Resume, not the original Start.
      h.start = Completer<StudentBlitzAttemptStartResult>();
      await _scrollTo(
        tester,
        find.byKey(const Key('studentBlitzSubmitButton')),
      );
      await _tap(tester, find.text('True'));
      await tester.pump();
      await _autosave(tester, h);
      h.answers.saves.single.fail(studentLocalFailure(ApiFailureKind.timeout));
      await _settle(tester);
      await _tap(tester, find.text('Check current attempt'));
      await tester.pump();
      expect(h.attempts.requests.last, same(resume));
    });

    testWidgets('a finished Attempt offers no Resume and no invented summary', (
      tester,
    ) async {
      final h = await _Harness.executing(tester, AppDeviceSurface.desktop);
      await _leave(tester);
      h.detail = finishedBlitzDetail();
      await _returnToBlitz(tester, h);
      expect(find.byKey(const Key('studentBlitzResumeButton')), findsNothing);
      expect(find.byKey(const Key('studentBlitzStartButton')), findsNothing);
      expect(
        find.byKey(const Key('studentBlitzStartAdditionalButton')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('studentBlitzFinalizationSummary')),
        findsNothing,
      );
      expect(
        find.text('You have already finished this Blitz.'),
        findsOneWidget,
      );
      expect(h.attempts.requests, hasLength(1));
      expect(h.keys.calls, 1);
    });
  });
}

String _q(int position) => blitzQuestionId(position);

StudentBlitzAttempt _submitted() => blitzExecutionAttempt(
  status: StudentBlitzAttemptStatus.submitted,
  finalizationReason: StudentBlitzAttemptFinalizationReason.studentSubmit,
);

void _expectNoScore() {
  for (final forbidden in ['Score', 'score', 'Points awarded', 'Correct']) {
    expect(find.textContaining(forbidden), findsNothing);
  }
}

bool _submitEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const Key('studentBlitzSubmitButton')))
        .onPressed !=
    null;

String _saveStatus(WidgetTester tester, int position) => tester
    .widget<Text>(find.byKey(ValueKey('studentSaveStatus${_q(position)}')))
    .data!;

/// Lets the one-second autosave of the last change run.
Future<void> _autosave(WidgetTester tester, _Harness h) async {
  h.timers.elapse(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// Taps a control in the long execution page after scrolling it into view.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.tap(finder);
}

Future<void> _submitThroughDialog(WidgetTester tester) async {
  await _scrollTo(tester, find.byKey(const Key('studentBlitzSubmitButton')));
  await _tap(tester, find.byKey(const Key('studentBlitzSubmitButton')));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('studentBlitzSubmitConfirmButton')));
  await _settle(tester);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back to Topic'));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('studentBlitzLeaveConfirmButton')));
  await _settle(tester);
}

Future<void> _returnToBlitz(WidgetTester tester, _Harness h) async {
  h.router.go(
    AppRoutePaths.studentBlitzDetailLocation(studentTopicId, studentBlitzId),
  );
  await _settle(tester);
}

class _Harness {
  _Harness(this.surface) {
    blitz.onFetchBlitz = (_) => _respond(detail);
    attempts.onStart = (_, _) => _respond(start);
    attempts.onSubmit = (_) => _respond(submit);
  }

  static Future<_Harness> executing(
    WidgetTester tester,
    AppDeviceSurface surface, {
    StudentBlitzAttempt? attempt,
  }) async {
    if (surface == AppDeviceSurface.mobile) {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final harness = _Harness(surface);
    harness.start = studentBlitzStartResult(
      attempt: attempt ?? blitzExecutionAttempt(),
    );
    await harness.pump(tester);
    harness.detail = inProgressBlitzDetail();
    await tester.tap(find.byKey(const Key('studentBlitzStartButton')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('studentBlitzStartConfirmButton')));
    await _settle(tester);
    // The Start confirmation snack bar would cover the lowest controls.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pump();
    return harness;
  }

  /// Next detail read: a detail, an exception or a pending completer.
  Object detail = studentBlitzDetail();

  /// Next Start result: a result, an exception or a pending completer.
  Object start = studentBlitzStartResult();

  /// Next Submit result: a result, an exception or a pending completer.
  Object submit = StudentBlitzSubmitResult(attempt: _submitted());
  final AppDeviceSurface surface;
  final blitz = FakeStudentBlitzRepository();
  final attempts = FakeStudentBlitzAttemptRepository();
  final answers = FakeStudentAttemptAnswerRepository();
  final picker = FakeBlitzFilePicker();
  final keys = SequentialBlitzKeys();

  /// Autosave and recovery timers; they fire only when a test elapses them.
  final timers = FakeAutosaveTimers();
  late final GoRouter router;
  late final ProviderContainer container;

  String get path => router.routeInformationProvider.value.uri.path;

  static Future<T> _respond<T>(Object response) {
    if (response is Completer<T>) return response.future;
    if (response is T) return Future.value(response as T);
    return Future.error(response);
  }

  Future<void> pump(WidgetTester tester) async {
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
              builder: (_, _) =>
                  StudentBlitzDetailScreen(target: blitzRouteTarget),
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
        studentAttemptAnswerRepositoryProvider.overrideWithValue(answers),
        studentSubmissionFilePickerProvider.overrideWithValue(picker),
        idempotencyKeyGeneratorProvider.overrideWithValue(keys),
        studentAutosaveTimerFactoryProvider.overrideWithValue(timers.factory),
        studentBlitzStopwatchFactoryProvider.overrideWithValue(
          () => tester.binding.clock.stopwatch(),
        ),
      ],
    );
    addTearDown(container.dispose);
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
