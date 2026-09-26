import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_readiness.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_blitz_execution_test_support.dart';
import 'student_test_support.dart';

void main() {
  group('ready with any number of saved answers', () {
    for (final (name, answers, answered) in [
      ('0 of 3', <StudentAttemptAnswerState>[], 0),
      (
        '1 of 3',
        [
          blitzSavedAnswer(
            1,
            StudentQuestionType.trueFalse,
            const StudentBooleanAnswerValue(value: true),
          ),
        ],
        1,
      ),
      (
        '3 of 3',
        [
          blitzSavedAnswer(
            1,
            StudentQuestionType.trueFalse,
            const StudentBooleanAnswerValue(value: true),
          ),
          blitzSavedAnswer(
            2,
            StudentQuestionType.openWritten,
            const StudentTextAnswerValue(text: 'text'),
          ),
          blitzSavedAnswer(
            3,
            StudentQuestionType.fileBased,
            StudentFileAnswerValue(file: blitzServerFile()),
          ),
        ],
        3,
      ),
    ]) {
      test('$name answered', () async {
        final h = await _Harness.create(
          attempt: blitzExecutionAttempt(answers: answers),
        );
        expect(h.readiness.blockers, isEmpty);
        expect(h.readiness.isReady, isTrue);
        final snapshot = h.readiness.readyToken!.snapshot;
        expect(snapshot.questionCount, 3);
        expect(snapshot.confirmedAnsweredCount, answered);
        expect(snapshot.unansweredCount, 3 - answered);
      });
    }
  });

  test('a dirty non-file draft blocks until saved or discarded', () async {
    final h = await _Harness.create();
    h.editor.updateDraft(_trueFalse, const StudentTrueFalseDraft(value: true));
    expect(h.readiness.blockers, {
      StudentBlitzSubmitBlocker.nonFileUnsavedChanges,
    });
    h.editor.discardChanges(_trueFalse);
    expect(h.readiness.isReady, isTrue);
  });

  test('a save in flight and an unconfirmed save block', () async {
    final h = await _Harness.create();
    h.editor.updateDraft(_trueFalse, const StudentTrueFalseDraft(value: true));
    final save = h.editor.saveAnswer(_trueFalse);
    expect(
      h.readiness.blockers,
      contains(StudentBlitzSubmitBlocker.nonFileSaveInProgress),
    );
    h.h.answers.saves.single.fail(studentLocalFailure(ApiFailureKind.timeout));
    await save;
    expect(
      h.readiness.blockers,
      contains(StudentBlitzSubmitBlocker.nonFileSaveUncertain),
    );
    expect(h.readiness.isReady, isFalse);
  });

  test('a selected, uploading or unconfirmed file blocks', () async {
    final h = await _Harness.create();
    final choose = h.files.chooseFile(_file);
    expect(
      h.readiness.blockers,
      contains(StudentBlitzSubmitBlocker.fileUploadInProgress),
    );
    h.h.picker.pending.single.complete(blitzUploadFile());
    await choose;
    expect(h.readiness.blockers, {
      StudentBlitzSubmitBlocker.fileSelectionPending,
    });
    final upload = h.files.uploadAnswer(_file);
    expect(
      h.readiness.blockers,
      contains(StudentBlitzSubmitBlocker.fileUploadInProgress),
    );
    h.h.answers.uploads.single.fail(
      studentLocalFailure(ApiFailureKind.timeout),
    );
    await upload;
    expect(
      h.readiness.blockers,
      contains(StudentBlitzSubmitBlocker.fileUploadUncertain),
    );
  });

  test('local countdown expiry blocks Submit', () async {
    final h = await _Harness.create();
    h.h.executionController.markLocalTimeExpired(
      h.h.execution.countdownAnchor!,
    );
    await flushStudentControllers();
    expect(
      h.readiness.blockers,
      containsAll({
        StudentBlitzSubmitBlocker.localTimeExpired,
        StudentBlitzSubmitBlocker.attemptStateRefreshing,
      }),
    );
    expect(h.readiness.readyToken, isNull);
  });

  test('an Attempt re-read in flight blocks Submit', () async {
    final h = await _Harness.create();
    final replay = h.h.executionController.refreshCurrentAttempt();
    await flushStudentControllers();
    expect(
      h.readiness.blockers,
      contains(StudentBlitzSubmitBlocker.attemptStateRefreshing),
    );
    await h.h.completeReplay(blitzExecutionAttempt());
    await replay;
    expect(h.readiness.isReady, isTrue);
  });

  test('a terminal Attempt is not submittable', () async {
    final h = await _Harness.create();
    h.h.executionController.acceptSubmittedAttempt(
      blitzExecutionAttempt(status: StudentBlitzAttemptStatus.submitted),
    );
    await flushStudentControllers();
    expect(
      h.readiness.blockers,
      contains(StudentBlitzSubmitBlocker.attemptNotEditable),
    );
  });

  test('a busy route operation blocks Submit', () async {
    final h = await _Harness.create();
    expect(h.gate.claimSubmit(), isTrue);
    expect(
      h.readiness.blockers,
      contains(StudentBlitzSubmitBlocker.operationBusy),
    );
  });

  test('editor state that does not match the Attempt blocks Submit', () async {
    final h = await _Harness.create();
    final readiness = StudentBlitzSubmitReadiness.evaluate(
      sessionKey: h.readiness.readyToken!.sessionKey,
      target: blitzExecutionTarget,
      execution: h.h.execution,
      answerState: StudentBlitzAnswerEditorState(
        isEligible: true,
        isAuthoritative: true,
        sourcePublication: h.h.execution.publicationToken,
      ),
      fileState: h.fileState,
      operation: StudentBlitzExecutionOperation.idle,
    );
    expect(readiness.blockers, {
      StudentBlitzSubmitBlocker.localStateUnavailable,
    });
  });

  test('the ready token changes with any relevant state', () async {
    final h = await _Harness.create();
    final first = h.readiness.readyToken!;
    expect(first.matches(h.readiness.readyToken!), isTrue);
    h.editor.updateDraft(_trueFalse, const StudentTrueFalseDraft(value: true));
    h.editor.discardChanges(_trueFalse);
    expect(first.matches(h.readiness.readyToken!), isFalse);
  });
}

final _trueFalse = blitzQuestionId(1);
final _file = blitzQuestionId(3);

class _Harness {
  _Harness(this.h) {
    h.listen(studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget));
    h.listen(studentBlitzFileAnswerControllerProvider(blitzExecutionTarget));
    h.listen(studentBlitzExecutionOperationGateProvider(blitzExecutionTarget));
    h.listen(studentBlitzSubmitReadinessProvider(blitzExecutionTarget));
  }

  static Future<_Harness> create({StudentBlitzAttempt? attempt}) async {
    final harness = _Harness(
      await BlitzExecutionHarness.executing(attempt: attempt),
    );
    addTearDown(harness.h.dispose);
    await flushStudentControllers();
    return harness;
  }

  final BlitzExecutionHarness h;

  StudentBlitzSubmitReadiness get readiness => h.container.read(
    studentBlitzSubmitReadinessProvider(blitzExecutionTarget),
  );
  StudentBlitzAnswerEditorController get editor => h.container.read(
    studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget).notifier,
  );
  StudentBlitzFileAnswerController get files => h.container.read(
    studentBlitzFileAnswerControllerProvider(blitzExecutionTarget).notifier,
  );
  StudentFileAnswerState get fileState => h.container.read(
    studentBlitzFileAnswerControllerProvider(blitzExecutionTarget),
  );
  StudentBlitzExecutionOperationGate get gate => h.container.read(
    studentBlitzExecutionOperationGateProvider(blitzExecutionTarget).notifier,
  );
}
