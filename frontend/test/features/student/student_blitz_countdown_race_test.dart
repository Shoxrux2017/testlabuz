import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_readiness.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_state.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_blitz_execution_test_support.dart';
import 'student_test_support.dart';

/// Local zero never decides a race: the in-flight request resolves first,
/// then one replay of the completed Start request shows the server outcome.
void main() {
  test('an answer saved before the deadline is kept after zero', () async {
    final h = await _executing();
    final save = h.saveAnswer();
    h.expire();
    _expectNoLocalFinalization(h);
    h.h.answers.saves.single.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: true),
      ),
    );
    await save;
    await flushStudentControllers();
    expect(h.h.replays, hasLength(1));
    await h.h.completeReplay(_timedOut(answered: true));
    expect(h.h.replays, hasLength(1));
    expect(h.h.execution.attempt!.answers, hasLength(1));
    expect(h.h.execution.status, StudentBlitzExecutionStatus.terminal);
  });

  test('an answer rejected as late is never counted as saved', () async {
    final h = await _executing();
    final save = h.saveAnswer();
    h.expire();
    h.h.answers.saves.single.fail(
      studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
    );
    await save;
    await flushStudentControllers();
    expect(h.h.replays, hasLength(1));
    expect(h.h.execution.attempt!.answers, isEmpty);
    expect(
      h.editor.questions[blitzQuestionId(1)]!.saveStatus,
      isNot(StudentAnswerSaveStatus.saved),
    );
    await h.h.completeReplay(_timedOut());
    expect(h.h.replays, hasLength(1));
    expect(h.h.execution.attempt!.answers, isEmpty);
  });

  test('a file uploaded before the deadline is kept after zero', () async {
    final h = await _executing();
    await h.pickFile();
    final upload = h.uploadFile();
    h.expire();
    _expectNoLocalFinalization(h);
    h.h.answers.uploads.single.complete(
      blitzMutationResult(
        3,
        StudentQuestionType.fileBased,
        StudentFileAnswerValue(file: blitzServerFile()),
      ),
    );
    await upload;
    await flushStudentControllers();
    expect(h.h.replays, hasLength(1));
    expect(h.h.execution.attempt!.answers, hasLength(1));
  });

  test('a file upload rejected as late stays unsaved', () async {
    final h = await _executing();
    await h.pickFile();
    final upload = h.uploadFile();
    h.expire();
    h.h.answers.uploads.single.fail(
      studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
    );
    await upload;
    await flushStudentControllers();
    expect(h.h.replays, hasLength(1));
    expect(h.files.questions[blitzQuestionId(3)]!.serverFile, isNull);
    expect(
      h.files.questions[blitzQuestionId(3)]!.status,
      StudentFileAnswerStatus.failure,
    );
  });

  test('a Submit accepted before the deadline wins without a replay', () async {
    final h = await _executing();
    final pending = Completer<StudentBlitzSubmitResult>();
    h.h.attempts.onSubmit = (_) => pending.future;
    final submit = h.submit();
    h.expire();
    _expectNoLocalFinalization(h);
    pending.complete(
      StudentBlitzSubmitResult(
        attempt: blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.submitted,
          finalizationReason:
              StudentBlitzAttemptFinalizationReason.studentSubmit,
        ),
      ),
    );
    await submit;
    await flushStudentControllers();
    expect(h.h.replays, isEmpty);
    expect(h.submitState.status, StudentBlitzSubmitStatus.completed);
  });

  test('a Submit rejected as late ends in the timeout, not a Submit', () async {
    final h = await _executing();
    final pending = Completer<StudentBlitzSubmitResult>();
    h.h.attempts.onSubmit = (_) => pending.future;
    final submit = h.submit();
    h.expire();
    pending.completeError(
      studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
    );
    await submit;
    await flushStudentControllers();
    expect(h.h.replays, hasLength(1));
    await h.h.completeReplay(_timedOut());
    expect(h.h.replays, hasLength(1));
    expect(h.submitState.status, StudentBlitzSubmitStatus.reconciledTerminal);
    expect(
      h.h.execution.attempt!.finalizationReason,
      StudentBlitzAttemptFinalizationReason.timeout,
    );
    expect(h.h.execution.confirmedBySubmit, isFalse);
  });
}

void _expectNoLocalFinalization(_Race h) {
  final attempt = h.h.execution.attempt!;
  expect(attempt.status, StudentBlitzAttemptStatus.inProgress);
  expect(attempt.finalizedAt, isNull);
  expect(h.h.execution.localTimeExpired, isTrue);
  expect(h.h.replays, isEmpty);
}

StudentBlitzAttempt _timedOut({bool answered = false}) => blitzExecutionAttempt(
  status: StudentBlitzAttemptStatus.timedOutFinalized,
  finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
  answers: [
    if (answered)
      blitzSavedAnswer(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: true),
      ),
  ],
);

Future<_Race> _executing() async {
  final race = _Race(await BlitzExecutionHarness.executing());
  addTearDown(race.h.dispose);
  await flushStudentControllers();
  return race;
}

class _Race {
  _Race(this.h) {
    h.listen(studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget));
    h.listen(studentBlitzFileAnswerControllerProvider(blitzExecutionTarget));
    h.listen(studentBlitzSubmitControllerProvider(blitzExecutionTarget));
    h.listen(studentBlitzSubmitReadinessProvider(blitzExecutionTarget));
  }

  final BlitzExecutionHarness h;

  StudentBlitzAnswerEditorState get editor => h.container.read(
    studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget),
  );
  StudentFileAnswerState get files => h.container.read(
    studentBlitzFileAnswerControllerProvider(blitzExecutionTarget),
  );
  StudentBlitzSubmitState get submitState => h.container.read(
    studentBlitzSubmitControllerProvider(blitzExecutionTarget),
  );

  void expire() =>
      h.executionController.markLocalTimeExpired(h.execution.countdownAnchor!);

  Future<void> saveAnswer() {
    final controller = h.container.read(
      studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget).notifier,
    );
    controller.updateDraft(
      blitzQuestionId(1),
      const StudentTrueFalseDraft(value: true),
    );
    return controller.saveAnswer(blitzQuestionId(1));
  }

  Future<void> pickFile() async {
    final choose = _fileController.chooseFile(blitzQuestionId(3));
    h.picker.pending.single.complete(blitzUploadFile());
    await choose;
  }

  Future<void> uploadFile() => _fileController.uploadAnswer(blitzQuestionId(3));

  StudentBlitzFileAnswerController get _fileController => h.container.read(
    studentBlitzFileAnswerControllerProvider(blitzExecutionTarget).notifier,
  );

  Future<void> submit() {
    final token = h.container
        .read(studentBlitzSubmitReadinessProvider(blitzExecutionTarget))
        .readyToken!;
    return h.container
        .read(
          studentBlitzSubmitControllerProvider(blitzExecutionTarget).notifier,
        )
        .submitConfirmed(token);
  }
}
