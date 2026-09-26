import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_state.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_blitz_execution_test_support.dart';
import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  test('all eight non-file Question types get one editor each', () async {
    final h = await _Harness.create(
      attempt: blitzExecutionAttempt(
        types: [...blitzNonFileTypes, StudentQuestionType.fileBased],
      ),
    );
    expect(h.state.questions, hasLength(8));
    for (var position = 1; position <= 8; position++) {
      final entry = h.state.questions[blitzQuestionId(position)]!;
      expect(entry.question.type, blitzNonFileTypes[position - 1]);
      expect(entry.saveStatus, StudentAnswerSaveStatus.idle);
      expect(entry.isDirty, isFalse);
      expect(h.state.canEdit(blitzQuestionId(position)), isTrue);
    }
    expect(h.state.questions.containsKey(blitzQuestionId(9)), isFalse);
    expect(h.state.sourcePublication, same(h.h.execution.publicationToken));
    expect(h.state.isAuthoritative, isTrue);
  });

  test('a draft is dirty until saved and follows the clear rules', () async {
    final h = await _Harness.create();
    h.controller.updateDraft(
      _trueFalse,
      const StudentTrueFalseDraft(value: true),
    );
    expect(h.entry(_trueFalse).isDirty, isTrue);
    expect(h.state.canSave(_trueFalse), isTrue);
    expect(h.entry(_trueFalse).draft.canClear, isFalse);
    h.controller.clearAnswer(_trueFalse);
    expect(h.entry(_trueFalse).isDirty, isTrue);
    h.controller.discardChanges(_trueFalse);
    expect(h.entry(_trueFalse).isDirty, isFalse);

    h.controller.updateDraft(
      _written,
      const StudentOpenWrittenDraft(text: 'x'),
    );
    expect(h.entry(_written).draft.canClear, isTrue);
    h.controller.clearAnswer(_written);
    expect((h.entry(_written).draft as StudentOpenWrittenDraft).text, '');
  });

  test('a saved answer patches the execution Attempt once', () async {
    final h = await _Harness.create();
    final before = h.h.execution.publicationToken;
    h.controller.updateDraft(
      _trueFalse,
      const StudentTrueFalseDraft(value: false),
    );
    final save = h.controller.saveAnswer(_trueFalse);
    expect(h.entry(_trueFalse).saveStatus, StudentAnswerSaveStatus.saving);
    expect(h.state.canEdit(_trueFalse), isFalse);
    final sent = h.h.answers.saves.single;
    expect(sent.attemptId, studentBlitzAttemptId);
    expect(sent.mutation.toJson(), {'type': 'true_false', 'value': false});
    sent.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: false),
      ),
    );
    await save;
    await flushStudentControllers();

    expect(h.entry(_trueFalse).saveStatus, StudentAnswerSaveStatus.saved);
    expect(h.entry(_trueFalse).isDirty, isFalse);
    expect(h.entry(_trueFalse).updatedAt, DateTime.utc(2026, 9, 17, 12, 2));
    final execution = h.h.execution;
    expect(execution.publicationToken, isNot(same(before)));
    expect(h.state.sourcePublication, same(execution.publicationToken));
    expect(
      (execution.attempt!.answers.single.value as StudentBooleanAnswerValue)
          .value,
      isFalse,
    );
    expect(h.h.replays, isEmpty);
    expect(h.h.answers.saves, hasLength(1));
  });

  test('a cleared answer removes the saved answer', () async {
    final h = await _Harness.create(
      attempt: blitzExecutionAttempt(
        answers: [
          blitzSavedAnswer(
            2,
            StudentQuestionType.openWritten,
            const StudentTextAnswerValue(text: 'old'),
          ),
        ],
      ),
    );
    h.controller.clearAnswer(_written);
    final save = h.controller.saveAnswer(_written);
    expect(h.h.answers.saves.single.mutation.toJson(), {
      'type': 'open_written',
      'text': '',
    });
    h.h.answers.saves.single.complete(
      blitzMutationResult(2, StudentQuestionType.openWritten, null),
    );
    await save;
    await flushStudentControllers();
    expect(h.h.execution.attempt!.answers, isEmpty);
    expect(h.entry(_written).serverAnswer, isNull);
    expect(h.entry(_written).isDirty, isFalse);
  });

  test('selection_limit_exceeded keeps the draft for correction', () async {
    final h = await _Harness.create(
      attempt: blitzExecutionAttempt(
        types: [StudentQuestionType.multipleChoice],
      ),
    );
    final choice = blitzQuestionId(1);
    h.controller.updateDraft(
      choice,
      StudentMultipleChoiceDraft(selectedOptionIds: {blitzUuid(1)}),
    );
    final save = h.controller.saveAnswer(choice);
    h.h.answers.saves.single.fail(
      studentServerFailure(
        ApiErrorCodes.selectionLimitExceeded,
        statusCode: 422,
      ),
    );
    await save;
    expect(h.entry(choice).saveStatus, StudentAnswerSaveStatus.failure);
    expect(h.entry(choice).isDirty, isTrue);
    expect(h.state.canSave(choice), isTrue);
    expect(h.h.replays, isEmpty);
  });

  test('validation_failed is a Question-level failure', () async {
    final h = await _Harness.create();
    h.controller.updateDraft(
      _written,
      const StudentOpenWrittenDraft(text: 'x'),
    );
    final save = h.controller.saveAnswer(_written);
    h.h.answers.saves.single.fail(
      studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
    );
    await save;
    expect(h.entry(_written).saveStatus, StudentAnswerSaveStatus.failure);
    expect(h.h.replays, isEmpty);
  });

  for (final (code, status) in [
    (ApiErrorCodes.blitzTimeExpired, 409),
    (ApiErrorCodes.blitzNotActive, 409),
    (ApiErrorCodes.attemptNotEditable, 409),
    (ApiErrorCodes.resourceNotFound, 404),
    (ApiErrorCodes.businessConflict, 409),
  ]) {
    test('$code reconciles through the completed Start request', () async {
      final h = await _Harness.create();
      h.controller.updateDraft(
        _trueFalse,
        const StudentTrueFalseDraft(value: true),
      );
      final save = h.controller.saveAnswer(_trueFalse);
      h.h.answers.saves.single.fail(
        studentServerFailure(code, statusCode: status),
      );
      await save;
      await flushStudentControllers();
      expect(h.h.replays.single, same(h.h.completedRequest));
      expect(h.state.canSave(_trueFalse), isFalse);
      if (code == ApiErrorCodes.blitzTimeExpired) {
        expect(h.h.execution.localTimeExpired, isTrue);
      }
      await h.h.completeReplay(
        blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.timedOutFinalized,
          finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
        ),
      );
      expect(h.state.isTerminal, isTrue);
      expect(h.state.hasDirtyDrafts, isFalse);
      expect(h.state.canEdit(_trueFalse), isFalse);
      expect(h.h.answers.saves, hasLength(1));
    });
  }

  group('uncertain save', () {
    for (final failure in [
      studentLocalFailure(ApiFailureKind.timeout),
      studentLocalFailure(ApiFailureKind.connection),
      studentLocalFailure(ApiFailureKind.invalidResponse),
      studentServerFailure(ApiErrorCodes.serverError, statusCode: 500),
    ]) {
      test('${failure.failure.kind} is never retried automatically', () async {
        final h = await _Harness.create();
        await h.uncertainSave(failure);
        expect(
          h.entry(_trueFalse).saveStatus,
          StudentAnswerSaveStatus.uncertain,
        );
        expect(h.state.hasUncertainMutation, isTrue);
        expect(h.state.canSave(_trueFalse), isFalse);
        await h.controller.saveAnswer(_trueFalse);
        expect(h.h.answers.saves, hasLength(1));
        expect(h.h.replays, isEmpty);
      });
    }

    test('an unexpected save error is uncertain, never stuck saving', () async {
      final h = await _Harness.create();
      await h.uncertainSave(StateError('unexpected'));
      expect(h.entry(_trueFalse).saveStatus, StudentAnswerSaveStatus.uncertain);
    });

    test('Check confirms a save that the server kept', () async {
      final h = await _Harness.create();
      await h.uncertainSave(studentLocalFailure(ApiFailureKind.timeout));
      final keys = h.h.keys.calls;
      final check = h.controller.checkCurrentAttempt();
      expect(h.state.isReconciling, isTrue);
      expect(h.h.replays.single, same(h.h.completedRequest));
      expect(h.h.replays.single.toJson(), {'intent': 'start_normal'});
      expect(h.h.replays.single.idempotencyKey, blitzKey(1));
      expect(h.h.keys.calls, keys);
      await h.h.completeReplay(
        blitzExecutionAttempt(
          answers: [
            blitzSavedAnswer(
              1,
              StudentQuestionType.trueFalse,
              const StudentBooleanAnswerValue(value: true),
            ),
          ],
        ),
      );
      await check;
      expect(h.entry(_trueFalse).saveStatus, StudentAnswerSaveStatus.saved);
      expect(h.entry(_trueFalse).isDirty, isFalse);
      expect(h.state.hasUncertainMutation, isFalse);
      expect(h.state.sourcePublication, same(h.h.execution.publicationToken));
      expect(h.h.answers.saves, hasLength(1));
    });

    test(
      'Check adopts a different server answer and keeps the draft',
      () async {
        final h = await _Harness.create();
        await h.uncertainSave(studentLocalFailure(ApiFailureKind.timeout));
        final check = h.controller.checkCurrentAttempt();
        await h.h.completeReplay(
          blitzExecutionAttempt(
            answers: [
              blitzSavedAnswer(
                1,
                StudentQuestionType.trueFalse,
                const StudentBooleanAnswerValue(value: false),
              ),
            ],
          ),
        );
        await check;
        final entry = h.entry(_trueFalse);
        expect(entry.saveStatus, StudentAnswerSaveStatus.idle);
        expect(
          (entry.serverAnswer! as StudentBooleanAnswerValue).value,
          isFalse,
        );
        expect((entry.draft as StudentTrueFalseDraft).value, isTrue);
        expect(entry.isDirty, isTrue);
        expect(h.state.canSave(_trueFalse), isTrue);
        expect(h.h.answers.saves, hasLength(1));
      },
    );

    test('Check that finds a terminal Attempt retires the draft', () async {
      final h = await _Harness.create();
      await h.uncertainSave(studentLocalFailure(ApiFailureKind.timeout));
      final check = h.controller.checkCurrentAttempt();
      await h.h.completeReplay(
        blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.submitted,
          finalizationReason: StudentBlitzAttemptFinalizationReason.taskClosed,
        ),
      );
      await check;
      expect(h.state.isTerminal, isTrue);
      expect(h.state.hasUncertainMutation, isFalse);
      expect(h.state.hasDirtyDrafts, isFalse);
      expect(h.state.canEdit(_trueFalse), isFalse);
    });

    test('a failed Check leaves the save unconfirmed', () async {
      final h = await _Harness.create();
      await h.uncertainSave(studentLocalFailure(ApiFailureKind.timeout));
      final check = h.controller.checkCurrentAttempt();
      await h.h.failReplay(studentLocalFailure(ApiFailureKind.connection));
      await check;
      expect(h.entry(_trueFalse).saveStatus, StudentAnswerSaveStatus.uncertain);
      expect(h.state.isReconciling, isFalse);
      final again = h.controller.checkCurrentAttempt();
      expect(h.h.replays, hasLength(2));
      expect(h.h.replays.last, same(h.h.completedRequest));
      await h.h.completeReplay(blitzExecutionAttempt());
      await again;
    });
  });

  test('local countdown zero disables Save without auto-saving', () async {
    final h = await _Harness.create();
    h.controller.updateDraft(
      _trueFalse,
      const StudentTrueFalseDraft(value: true),
    );
    h.h.executionController.markLocalTimeExpired(
      h.h.execution.countdownAnchor!,
    );
    await flushStudentControllers();
    expect(h.state.canSave(_trueFalse), isFalse);
    expect(h.state.canEdit(_trueFalse), isFalse);
    await h.controller.saveAnswer(_trueFalse);
    expect(h.h.answers.saves, isEmpty);
    expect(h.entry(_trueFalse).isDirty, isTrue);
  });

  test('a success after local zero is adopted before reconciliation', () async {
    final h = await _Harness.create();
    h.controller.updateDraft(
      _trueFalse,
      const StudentTrueFalseDraft(value: true),
    );
    final save = h.controller.saveAnswer(_trueFalse);
    h.h.executionController.markLocalTimeExpired(
      h.h.execution.countdownAnchor!,
    );
    expect(h.h.replays, isEmpty);
    h.h.answers.saves.single.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: true),
      ),
    );
    await save;
    await flushStudentControllers();
    expect(h.h.replays.single, same(h.h.completedRequest));
    expect(h.h.execution.attempt!.answers.single.questionId, _trueFalse);
    await h.h.completeReplay(
      blitzExecutionAttempt(
        status: StudentBlitzAttemptStatus.timedOutFinalized,
        finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
        answers: [
          blitzSavedAnswer(
            1,
            StudentQuestionType.trueFalse,
            const StudentBooleanAnswerValue(value: true),
          ),
        ],
      ),
    );
    expect(h.h.replays, hasLength(1));
    expect(h.state.isTerminal, isTrue);
  });

  test(
    'a response for an outdated publication is re-read, not applied',
    () async {
      final h = await _Harness.create();
      h.controller.updateDraft(
        _trueFalse,
        const StudentTrueFalseDraft(value: true),
      );
      final save = h.controller.saveAnswer(_trueFalse);
      // Another write (for example a file upload) published a newer Attempt.
      expect(
        h.h.executionController.acceptAnswerMutation(
          attemptId: studentBlitzAttemptId,
          questionId: _written,
          result: blitzMutationResult(
            2,
            StudentQuestionType.openWritten,
            const StudentTextAnswerValue(text: 'other'),
          ),
          expectedPublication: h.h.execution.publicationToken,
        ),
        isTrue,
      );
      h.h.answers.saves.single.complete(
        blitzMutationResult(
          1,
          StudentQuestionType.trueFalse,
          const StudentBooleanAnswerValue(value: true),
        ),
      );
      await save;
      await flushStudentControllers();
      expect(h.h.execution.attempt!.answers, hasLength(1));
      expect(h.h.replays.single, same(h.h.completedRequest));
      await h.h.completeReplay(
        blitzExecutionAttempt(
          answers: [
            blitzSavedAnswer(
              1,
              StudentQuestionType.trueFalse,
              const StudentBooleanAnswerValue(value: true),
            ),
          ],
        ),
      );
      await flushStudentControllers();
      expect(h.entry(_trueFalse).saveStatus, StudentAnswerSaveStatus.saved);
      expect(h.h.answers.saves, hasLength(1));
    },
  );

  test('a claimed Submit gate blocks every write and check', () async {
    final h = await _Harness.create();
    h.controller.updateDraft(
      _trueFalse,
      const StudentTrueFalseDraft(value: true),
    );
    h.h.listen(
      studentBlitzExecutionOperationGateProvider(blitzExecutionTarget),
    );
    final gate = h.h.container.read(
      studentBlitzExecutionOperationGateProvider(blitzExecutionTarget).notifier,
    );
    expect(gate.claimSubmit(), isTrue);
    await h.controller.saveAnswer(_trueFalse);
    h.controller.updateDraft(
      _written,
      const StudentOpenWrittenDraft(text: 'y'),
    );
    expect(h.h.answers.saves, isEmpty);
    expect(h.entry(_written).isDirty, isFalse);
  });

  test('a session switch drops drafts and ignores late results', () async {
    final h = await _Harness.create();
    h.controller.updateDraft(
      _trueFalse,
      const StudentTrueFalseDraft(value: true),
    );
    final save = h.controller.saveAnswer(_trueFalse);
    h.h.auth.replaceUser(studentUser('student-b'));
    await flushStudentControllers();
    h.h.answers.saves.single.complete(
      blitzMutationResult(
        1,
        StudentQuestionType.trueFalse,
        const StudentBooleanAnswerValue(value: true),
      ),
    );
    await save;
    await flushStudentControllers();
    expect(h.state.questions, isEmpty);
    expect(h.state.isEligible, isFalse);
    expect(h.h.execution.status, StudentBlitzExecutionStatus.none);
  });

  test('leaving clears the local drafts', () async {
    final h = await _Harness.create();
    h.controller.updateDraft(
      _trueFalse,
      const StudentTrueFalseDraft(value: true),
    );
    h.controller.clearLocalState();
    expect(h.state.questions, isEmpty);
    expect(h.state.hasDirtyDrafts, isFalse);
  });
}

final _trueFalse = blitzQuestionId(1);
final _written = blitzQuestionId(2);

class _Harness {
  _Harness(this.h) {
    h.listen(studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget));
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

  StudentBlitzAnswerEditorState get state => h.container.read(
    studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget),
  );
  StudentBlitzAnswerEditorController get controller => h.container.read(
    studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget).notifier,
  );
  StudentQuestionAnswerEditorState entry(String id) => state.questions[id]!;

  Future<void> uncertainSave(Object error) async {
    controller.updateDraft(
      _trueFalse,
      const StudentTrueFalseDraft(value: true),
    );
    final save = controller.saveAnswer(_trueFalse);
    h.answers.saves.last.fail(error);
    await save;
    await flushStudentControllers();
  }
}
