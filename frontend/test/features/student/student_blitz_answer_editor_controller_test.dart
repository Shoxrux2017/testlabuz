import 'dart:async';

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
    // Editing back to the saved value makes the draft clean again.
    h.controller.updateDraft(_trueFalse, _savedDraft(h.state, _trueFalse));
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
    // The Question stays editable during its own save.
    expect(h.state.canEdit(_trueFalse), isTrue);
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
    'a save overlapping another write is adopted without a re-read',
    () async {
      final h = await _Harness.create();
      h.controller.updateDraft(
        _trueFalse,
        const StudentTrueFalseDraft(value: true),
      );
      final save = h.controller.saveAnswer(_trueFalse);
      // Another write (for example a file upload) patched the same read.
      expect(
        h.h.executionController.acceptAnswerMutation(
          attemptId: studentBlitzAttemptId,
          questionId: _written,
          result: blitzMutationResult(
            2,
            StudentQuestionType.openWritten,
            const StudentTextAnswerValue(text: 'other'),
          ),
          expectedReadToken: h.h.execution.readToken,
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
      expect(h.h.execution.attempt!.answers, hasLength(2));
      expect(h.h.replays, isEmpty);
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
  group('autosave', () {
    const second = Duration(seconds: 1);

    void write(_Harness h, String text) =>
        h.controller.updateDraft(_written, StudentOpenWrittenDraft(text: text));

    test('a typed change is saved one second after the last change', () async {
      final h = await _Harness.create();
      write(h, 'Draft');
      h.h.timers.elapse(const Duration(milliseconds: 999));
      expect(h.h.answers.saves, isEmpty);
      h.h.timers.elapse(const Duration(milliseconds: 1));
      expect(h.h.answers.saves, hasLength(1));
      expect(h.h.answers.saves.single.mutation.toJson(), {
        'type': 'open_written',
        'text': 'Draft',
      });
    });

    test('typing continues during the save and is saved afterwards', () async {
      final h = await _Harness.create();
      write(h, 'Draft');
      h.h.timers.elapse(second);
      write(h, 'Draft plus');
      h.h.answers.saves.single.complete(
        blitzMutationResult(
          2,
          StudentQuestionType.openWritten,
          const StudentTextAnswerValue(text: 'Draft'),
        ),
      );
      await flushStudentControllers();
      expect(
        (h.entry(_written).draft as StudentOpenWrittenDraft).text,
        'Draft plus',
      );
      h.h.timers.elapse(second);
      await flushStudentControllers();
      expect(h.h.answers.saves, hasLength(2));
    });

    test('nothing is sent after local zero', () async {
      final h = await _Harness.create();
      write(h, 'Too late');
      h.h.executionController.markLocalTimeExpired(
        h.h.execution.countdownAnchor!,
      );
      await flushStudentControllers();
      h.h.timers.elapse(const Duration(minutes: 1));
      await flushStudentControllers();
      expect(h.h.answers.saves, isEmpty);
      expect(await h.controller.flushAll(), isFalse);
      // Going to the background after zero queues nothing either.
      h.controller
        ..saveAllNow()
        ..saveNow(_written);
      // Even a replay that re-opens writes sends nothing queued before zero.
      await h.h.completeReplay(blitzExecutionAttempt());
      h.h.timers.elapse(const Duration(minutes: 1));
      await flushStudentControllers();
      expect(h.h.answers.saves, isEmpty);
    });

    test(
      'an unconfirmed save is checked automatically after two seconds',
      () async {
        final h = await _Harness.create();
        await h.uncertainSave(studentLocalFailure(ApiFailureKind.timeout));
        expect(h.state.hasUncertainMutation, isTrue);
        expect(h.state.canEdit(_written), isTrue);
        h.h.timers.elapse(const Duration(milliseconds: 1999));
        await flushStudentControllers();
        expect(h.h.replays, isEmpty);
        h.h.timers.elapse(const Duration(milliseconds: 1));
        await flushStudentControllers();
        expect(h.h.replays, hasLength(1));
      },
    );

    test('flushAll saves pending changes and succeeds', () async {
      final h = await _Harness.create();
      write(h, 'Before Submit');
      final flush = h.controller.flushAll();
      expect(h.state.isFlushing, isTrue);
      expect(h.state.canEdit(_written), isFalse);
      expect(h.h.answers.saves, hasLength(1));
      h.h.answers.saves.single.complete(
        blitzMutationResult(
          2,
          StudentQuestionType.openWritten,
          const StudentTextAnswerValue(text: 'Before Submit'),
        ),
      );
      expect(await flush, isTrue);
      expect(h.state.isFlushing, isFalse);
    });

    test('flushAll stops when the time runs out', () async {
      final h = await _Harness.create();
      write(h, 'Before Submit');
      final flush = h.controller.flushAll();
      h.h.executionController.markLocalTimeExpired(
        h.h.execution.countdownAnchor!,
      );
      await flushStudentControllers();
      expect(await flush, isFalse);
      expect(h.state.isFlushing, isFalse);
    });

    test('a change undone during its save is sent after that save', () async {
      final h = await _Harness.create();
      write(h, 'Typed');
      h.h.timers.elapse(second);
      // Back to the empty server value while the save runs: the draft is clean.
      write(h, '');
      h.h.answers.saves.single.complete(
        blitzMutationResult(
          2,
          StudentQuestionType.openWritten,
          const StudentTextAnswerValue(text: 'Typed'),
        ),
      );
      await flushStudentControllers();
      expect(h.entry(_written).isDirty, isTrue);
      expect(h.h.answers.saves, hasLength(2));
    });

    test('a 422 does not reject typing made during that save', () async {
      final h = await _Harness.create();
      write(h, 'First');
      h.h.timers.elapse(second);
      write(h, 'First more');
      h.h.answers.saves.single.fail(
        studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
      );
      await flushStudentControllers();
      expect(h.state.hasFailedSave, isFalse);
      h.h.timers.elapse(second);
      await flushStudentControllers();
      expect(h.h.answers.saves, hasLength(2));
      expect(h.h.answers.saves.last.mutation.toJson(), {
        'type': 'open_written',
        'text': 'First more',
      });
    });

    test(
      'typing continues during an automatic check and is sent after it',
      () async {
        final h = await _Harness.create();
        await h.uncertainSave(studentLocalFailure(ApiFailureKind.timeout));
        h.h.timers.elapse(const Duration(seconds: 2));
        await flushStudentControllers();
        expect(h.h.replays, hasLength(1));
        expect(h.state.canEdit(_written), isTrue);
        write(h, 'During the check');
        h.h.timers.elapse(second);
        await flushStudentControllers();
        // The check holds the write gate; the change waits in the queue.
        expect(h.h.answers.saves, hasLength(1));
        await h.h.completeReplay(blitzExecutionAttempt());
        expect(
          (h.entry(_written).draft as StudentOpenWrittenDraft).text,
          'During the check',
        );
        // The unconfirmed true/false answer changed first, so it goes first.
        expect(h.h.answers.saves, hasLength(2));
        h.h.answers.saves.last.complete(
          blitzMutationResult(
            1,
            StudentQuestionType.trueFalse,
            const StudentBooleanAnswerValue(value: true),
          ),
        );
        await flushStudentControllers();
        expect(h.h.answers.saves, hasLength(3));
        expect(h.h.answers.saves.last.mutation.toJson(), {
          'type': 'open_written',
          'text': 'During the check',
        });
      },
    );

    test('flushAll stops when the execution drops the Attempt', () async {
      final h = await _Harness.create();
      write(h, 'Pending');
      bool? saved;
      unawaited(h.controller.flushAll().then((value) => saved = value));
      await flushStudentControllers();
      expect(h.h.answers.saves, hasLength(1));
      h.h.executionController.clearLocalState();
      await flushStudentControllers();
      expect(saved, isFalse);
    });

    test('pending timers stop when the editor is disposed', () async {
      final h = await _Harness.create();
      write(h, 'Unsent');
      expect(h.h.timers.pendingCount, 1);
      h.h.dispose();
      expect(h.h.timers.pendingCount, 0);
    });
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

StudentAnswerDraft _savedDraft(StudentBlitzAnswerEditorState state, String id) {
  final entry = state.questions[id.toLowerCase()]!;
  return StudentAnswerDraft.fromAnswer(entry.question, entry.serverAnswer);
}
