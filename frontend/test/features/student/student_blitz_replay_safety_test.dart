import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_readiness.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';

import 'student_blitz_execution_test_support.dart';
import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

/// Every FE-005 recovery re-reads the Attempt only by resending the exact
/// completed Start request: same intent, same Resume Attempt ID, same key.
void main() {
  for (final shape in BlitzRequestShape.values) {
    group('${shape.name} recovery', () {
      test('answer save uncertain -> Check', () async {
        final h = await _executing(shape);
        h.listen(studentBlitzAnswerEditorControllerProvider(shape.target));
        final editor = h.container.read(
          studentBlitzAnswerEditorControllerProvider(shape.target).notifier,
        );
        editor.updateDraft(
          blitzQuestionId(1),
          const StudentTrueFalseDraft(value: true),
        );
        final save = editor.saveAnswer(blitzQuestionId(1));
        h.answers.saves.single.fail(
          studentLocalFailure(ApiFailureKind.timeout),
        );
        await save;
        final check = editor.checkCurrentAttempt();
        _expectExactReplay(h, shape);
        await h.completeReplay(shape.attempt());
        await check;
      });

      test('file upload uncertain -> Check', () async {
        final h = await _executing(shape);
        h.listen(studentBlitzFileAnswerControllerProvider(shape.target));
        final files = h.container.read(
          studentBlitzFileAnswerControllerProvider(shape.target).notifier,
        );
        final choose = files.chooseFile(blitzQuestionId(3));
        h.picker.pending.single.complete(blitzUploadFile());
        await choose;
        final upload = files.uploadAnswer(blitzQuestionId(3));
        h.answers.uploads.single.fail(
          studentLocalFailure(ApiFailureKind.timeout),
        );
        await upload;
        final check = files.checkCurrentAttempt();
        _expectExactReplay(h, shape);
        await h.completeReplay(shape.attempt());
        await check;
      });

      test('Submit uncertain -> Check', () async {
        final h = await _executing(shape);
        final submit = _submit(h, shape);
        h.attempts.onSubmit = (_) =>
            Future.error(studentLocalFailure(ApiFailureKind.timeout));
        await submit.submitConfirmed(_token(h, shape));
        final check = submit.checkCurrentAttempt();
        _expectExactReplay(h, shape);
        await h.completeReplay(
          shape.attempt(status: StudentBlitzAttemptStatus.submitted),
        );
        await check;
      });

      test('timeout conflict on an answer save', () async {
        final h = await _executing(shape);
        h.listen(studentBlitzAnswerEditorControllerProvider(shape.target));
        final editor = h.container.read(
          studentBlitzAnswerEditorControllerProvider(shape.target).notifier,
        );
        editor.updateDraft(
          blitzQuestionId(1),
          const StudentTrueFalseDraft(value: true),
        );
        final save = editor.saveAnswer(blitzQuestionId(1));
        h.answers.saves.single.fail(
          studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
        );
        await save;
        await flushStudentControllers();
        _expectExactReplay(h, shape);
      });

      test('Teacher-close conflict from detail', () async {
        final h = await _executing(shape);
        h.container
            .read(
              studentBlitzDetailControllerProvider(blitzRouteTarget).notifier,
            )
            .refresh();
        h.pendingDetails.last.completeError(
          studentServerFailure(ApiErrorCodes.blitzNotActive, statusCode: 409),
        );
        await flushStudentControllers();
        _expectExactReplay(h, shape);
        await h.completeReplay(
          shape.attempt(
            status: StudentBlitzAttemptStatus.submitted,
            finalizationReason:
                StudentBlitzAttemptFinalizationReason.taskClosed,
          ),
        );
        expect(h.execution.status, StudentBlitzExecutionStatus.terminal);
        expect(h.execution.attempt!.id, shape.attemptId);
      });

      test('attempt_not_editable on Submit', () async {
        final h = await _executing(shape);
        final submit = _submit(h, shape);
        h.attempts.onSubmit = (_) => Future.error(
          studentServerFailure(
            ApiErrorCodes.attemptNotEditable,
            statusCode: 409,
          ),
        );
        await submit.submitConfirmed(_token(h, shape));
        await flushStudentControllers();
        _expectExactReplay(h, shape);
      });

      test('local countdown zero', () async {
        final h = await _executing(shape);
        h.executionController.markLocalTimeExpired(
          h.execution.countdownAnchor!,
        );
        _expectExactReplay(h, shape);
      });
    });
  }
}

Future<BlitzExecutionHarness> _executing(BlitzRequestShape shape) async {
  final harness = await BlitzExecutionHarness.executing(shape: shape);
  addTearDown(harness.dispose);
  expect(harness.completedRequest.toJson(), shape.body);
  return harness;
}

StudentBlitzSubmitController _submit(
  BlitzExecutionHarness h,
  BlitzRequestShape shape,
) {
  h.listen(studentBlitzSubmitControllerProvider(shape.target));
  h.listen(studentBlitzSubmitReadinessProvider(shape.target));
  return h.container.read(
    studentBlitzSubmitControllerProvider(shape.target).notifier,
  );
}

StudentBlitzSubmitReadyToken _token(
  BlitzExecutionHarness h,
  BlitzRequestShape shape,
) => h.container
    .read(studentBlitzSubmitReadinessProvider(shape.target))
    .readyToken!;

void _expectExactReplay(BlitzExecutionHarness h, BlitzRequestShape shape) {
  final completed = h.completedRequest;
  expect(h.replays, hasLength(1));
  final replay = h.replays.single;
  // The very object that was sent, never a rebuilt or re-derived request.
  expect(replay, same(completed));
  expect(replay.intent, shape.intent);
  expect(replay.toJson(), shape.body);
  expect(replay.attemptId, shape.body['attempt_id']);
  expect(replay.idempotencyKey, blitzKey(1));
  expect(h.attempts.blitzIds.toSet(), {studentBlitzId});
  if (shape.intent != StudentBlitzAttemptIntent.startReplacement) {
    expect(replay.intent, isNot(StudentBlitzAttemptIntent.startReplacement));
  }
}
