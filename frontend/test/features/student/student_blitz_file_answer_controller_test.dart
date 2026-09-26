import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/data/dto/student_question_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'student_blitz_execution_test_support.dart';
import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  test(
    'choosing uses the Question file policy and keeps a candidate',
    () async {
      final h = await _Harness.create();
      expect(h.state.questions.keys, [_file]);
      expect(
        h.state.sourceAttemptPublication,
        same(h.h.execution.publicationToken),
      );
      final choose = h.controller.chooseFile(_file);
      expect(h.entry.status, StudentFileAnswerStatus.selecting);
      expect(h.h.picker.requests.single, ['pdf', 'docx', 'ppt', 'pptx']);
      h.h.picker.pending.single.complete(blitzUploadFile());
      await choose;
      expect(h.entry.status, StudentFileAnswerStatus.ready);
      expect(h.entry.selectedFile!.name, 'blitz.pdf');
      expect(h.state.canUpload(_file), isTrue);
      expect(h.h.answers.uploads, isEmpty);
    },
  );

  test(
    'the effective Institution cap and extensions are checked locally',
    () async {
      final h = await _Harness.create(
        attempt: studentBlitzAttempt(
          questions: [
            StudentQuestionDto.fromJson({
              ...blitzQuestionJson(StudentQuestionType.fileBased, 3),
              'answer_ui': {
                'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
                'max_size_bytes': 1000,
              },
            }).toDomain(),
          ],
        ),
      );
      for (final (file, error) in [
        (
          blitzUploadFile(length: 1001),
          StudentSubmissionSelectionError.tooLarge,
        ),
        (
          blitzUploadFile(name: 'notes.txt', length: 10),
          StudentSubmissionSelectionError.unsupportedExtension,
        ),
        (blitzUploadFile(length: 0), StudentSubmissionSelectionError.emptyFile),
      ]) {
        final choose = h.controller.chooseFile(_file);
        h.h.picker.pending.last.complete(file);
        await choose;
        expect(h.entry.selectionError, error);
        expect(h.entry.selectedFile, isNull);
        expect(h.state.canUpload(_file), isFalse);
      }
    },
  );

  test('a confirmed upload patches the execution Attempt', () async {
    final h = await _Harness.create();
    await h.pick();
    final before = h.h.execution.publicationToken;
    final upload = h.controller.uploadAnswer(_file);
    expect(h.entry.status, StudentFileAnswerStatus.uploading);
    final sent = h.h.answers.uploads.single;
    expect(sent.attemptId, studentBlitzAttemptId);
    expect(sent.question.id, _file);
    sent.onProgress!(1024, 2048);
    expect(h.entry.sentBytes, 1024);
    expect(h.entry.totalBytes, 2048);
    sent.complete(_result());
    await upload;
    await flushStudentControllers();

    expect(h.entry.status, StudentFileAnswerStatus.uploaded);
    expect(h.entry.serverFile!.id, blitzUuid(99));
    expect(h.entry.selectedFile, isNull);
    final execution = h.h.execution;
    expect(execution.publicationToken, isNot(same(before)));
    expect(h.state.sourceAttemptPublication, same(execution.publicationToken));
    final saved =
        execution.attempt!.answers.single.value as StudentFileAnswerValue;
    expect(saved.file.id, blitzUuid(99));
    expect(h.h.replays, isEmpty);
  });

  test(
    'a confirmed upload outrun by another save is kept after the re-read',
    () async {
      final h = await _Harness.create();
      await h.pick();
      final upload = h.controller.uploadAnswer(_file);
      // A typed answer saved meanwhile publishes a newer Attempt.
      expect(
        h.h.executionController.acceptAnswerMutation(
          attemptId: studentBlitzAttemptId,
          questionId: blitzQuestionId(1),
          result: blitzMutationResult(
            1,
            StudentQuestionType.trueFalse,
            const StudentBooleanAnswerValue(value: true),
          ),
          expectedPublication: h.h.execution.publicationToken,
        ),
        isTrue,
      );
      h.h.answers.uploads.single.complete(_result());
      await upload;
      await flushStudentControllers();
      expect(h.h.replays.single, same(h.h.completedRequest));
      await h.h.completeReplay(
        blitzExecutionAttempt(
          answers: [
            StudentAttemptAnswerState(
              questionId: _file,
              type: StudentQuestionType.fileBased,
              value: StudentFileAnswerValue(file: blitzServerFile()),
              updatedAt: DateTime.utc(2026, 9, 17, 12, 2),
            ),
          ],
        ),
      );
      await flushStudentControllers();
      expect(h.entry.status, StudentFileAnswerStatus.uploaded);
      expect(h.entry.selectedFile, isNull);
      expect(h.state.hasPendingSelection, isFalse);
      expect(h.state.hasUncertainUpload, isFalse);
      expect(h.h.answers.uploads, hasLength(1));
    },
  );

  test(
    'a confirmed upload replaced elsewhere stays a local candidate',
    () async {
      final h = await _Harness.create();
      await h.pick();
      final upload = h.controller.uploadAnswer(_file);
      h.h.executionController.acceptAnswerMutation(
        attemptId: studentBlitzAttemptId,
        questionId: blitzQuestionId(1),
        result: blitzMutationResult(
          1,
          StudentQuestionType.trueFalse,
          const StudentBooleanAnswerValue(value: true),
        ),
        expectedPublication: h.h.execution.publicationToken,
      );
      h.h.answers.uploads.single.complete(_result());
      await upload;
      await flushStudentControllers();
      await h.h.completeReplay(
        blitzExecutionAttempt(
          answers: [
            StudentAttemptAnswerState(
              questionId: _file,
              type: StudentQuestionType.fileBased,
              value: StudentFileAnswerValue(
                file: blitzServerFile(name: 'other.pdf'),
              ),
              updatedAt: DateTime.utc(2026, 9, 17, 12, 3),
            ),
          ],
        ),
      );
      await flushStudentControllers();
      expect(h.entry.status, StudentFileAnswerStatus.ready);
      expect(h.entry.serverFile!.originalName, 'other.pdf');
      expect(h.entry.selectedFile, isNotNull);
    },
  );

  test(
    'a replacement keeps the file ID and becomes the current file',
    () async {
      final h = await _Harness.create(
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
      expect(h.entry.serverFile!.originalName, 'old.pdf');
      await h.pick(blitzUploadFile(name: 'new.pdf', length: 4096));
      final upload = h.controller.uploadAnswer(_file);
      h.h.answers.uploads.single.complete(
        _result(file: blitzServerFile(name: 'new.pdf', size: 4096)),
      );
      await upload;
      await flushStudentControllers();
      expect(h.entry.serverFile!.originalName, 'new.pdf');
      expect(h.entry.status, StudentFileAnswerStatus.uploaded);
    },
  );

  test('a response for another file is uncertain and re-read', () async {
    final h = await _Harness.create();
    await h.pick();
    final upload = h.controller.uploadAnswer(_file);
    h.h.answers.uploads.single.complete(
      _result(file: blitzServerFile(name: 'other.pdf')),
    );
    await upload;
    expect(h.entry.status, StudentFileAnswerStatus.uncertain);
    expect(h.h.execution.attempt!.answers, isEmpty);
    expect(h.h.answers.uploads, hasLength(1));
  });

  test('an unavailable local source asks for the file again', () async {
    final h = await _Harness.create();
    await h.pick();
    final upload = h.controller.uploadAnswer(_file);
    h.h.answers.uploads.single.fail(const StudentSubmissionSourceUnavailable());
    await upload;
    expect(h.entry.status, StudentFileAnswerStatus.failure);
    expect(
      h.entry.localFailure,
      StudentFileAnswerLocalFailure.sourceUnavailable,
    );
    expect(h.entry.selectedFile, isNull);
    expect(h.h.replays, isEmpty);
    expect(h.h.answers.uploads, hasLength(1));
  });

  test(
    'file_upload_failed keeps the candidate for an explicit retry',
    () async {
      final h = await _Harness.create();
      await h.pick();
      final upload = h.controller.uploadAnswer(_file);
      h.h.answers.uploads.single.fail(
        studentServerFailure(ApiErrorCodes.fileUploadFailed, statusCode: 500),
      );
      await upload;
      expect(h.entry.status, StudentFileAnswerStatus.failure);
      expect(h.entry.selectedFile, isNotNull);
      expect(h.state.canUpload(_file), isTrue);
      expect(h.h.answers.uploads, hasLength(1));
      final retry = h.controller.uploadAnswer(_file);
      expect(h.h.answers.uploads, hasLength(2));
      h.h.answers.uploads.last.complete(_result());
      await retry;
    },
  );

  for (final code in [
    ApiErrorCodes.unsupportedFileType,
    ApiErrorCodes.fileTooLarge,
  ]) {
    test('$code drops the rejected candidate', () async {
      final h = await _Harness.create();
      await h.pick();
      final upload = h.controller.uploadAnswer(_file);
      h.h.answers.uploads.single.fail(
        studentServerFailure(code, statusCode: 422),
      );
      await upload;
      expect(h.entry.status, StudentFileAnswerStatus.failure);
      expect(h.entry.selectedFile, isNull);
      expect(h.entry.failure!.serverCode, code);
    });
  }

  for (final (code, status) in [
    (ApiErrorCodes.blitzTimeExpired, 409),
    (ApiErrorCodes.blitzNotActive, 409),
    (ApiErrorCodes.attemptNotEditable, 409),
    (ApiErrorCodes.resourceNotFound, 404),
  ]) {
    test('$code reconciles and never counts the file as saved', () async {
      final h = await _Harness.create();
      await h.pick();
      final upload = h.controller.uploadAnswer(_file);
      h.h.answers.uploads.single.fail(
        studentServerFailure(code, statusCode: status),
      );
      await upload;
      await flushStudentControllers();
      expect(h.h.replays.single, same(h.h.completedRequest));
      expect(h.entry.serverFile, isNull);
      await h.h.completeReplay(
        blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.timedOutFinalized,
          finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
        ),
      );
      expect(h.state.isTerminal, isTrue);
      expect(h.entry.selectedFile, isNull);
      expect(h.state.canChoose(_file), isFalse);
    });
  }

  group('uncertain upload', () {
    test('is never retried automatically', () async {
      final h = await _Harness.create();
      await h.uncertainUpload();
      expect(h.entry.status, StudentFileAnswerStatus.uncertain);
      expect(h.state.hasUncertainUpload, isTrue);
      expect(h.state.canUpload(_file), isFalse);
      await h.controller.uploadAnswer(_file);
      expect(h.h.answers.uploads, hasLength(1));
      expect(h.h.replays, isEmpty);
    });

    test(
      'Check replays the exact request; matching metadata proves nothing',
      () async {
        final h = await _Harness.create();
        await h.uncertainUpload();
        final keys = h.h.keys.calls;
        final check = h.controller.checkCurrentAttempt();
        expect(h.h.replays.single, same(h.h.completedRequest));
        expect(h.h.replays.single.idempotencyKey, blitzKey(1));
        expect(h.h.keys.calls, keys);
        await h.h.completeReplay(
          blitzExecutionAttempt(
            answers: [
              blitzSavedAnswer(
                3,
                StudentQuestionType.fileBased,
                StudentFileAnswerValue(file: blitzServerFile()),
              ),
            ],
          ),
        );
        await check;
        expect(h.entry.serverFile!.originalName, 'blitz.pdf');
        expect(h.entry.status, StudentFileAnswerStatus.ready);
        expect(h.entry.selectedFile, isNotNull);
        expect(h.state.hasUncertainUpload, isFalse);
        expect(h.state.canUpload(_file), isTrue);
        expect(h.h.answers.uploads, hasLength(1));
      },
    );

    test(
      'Check that finds a terminal Attempt discards the candidate',
      () async {
        final h = await _Harness.create();
        await h.uncertainUpload();
        final check = h.controller.checkCurrentAttempt();
        await h.h.completeReplay(
          blitzExecutionAttempt(
            status: StudentBlitzAttemptStatus.submitted,
            finalizationReason:
                StudentBlitzAttemptFinalizationReason.taskClosed,
            answers: [
              blitzSavedAnswer(
                3,
                StudentQuestionType.fileBased,
                StudentFileAnswerValue(file: blitzServerFile()),
              ),
            ],
          ),
        );
        await check;
        expect(h.state.isTerminal, isTrue);
        expect(h.entry.selectedFile, isNull);
        expect(h.entry.serverFile, isNotNull);
        expect(h.state.hasUncertainUpload, isFalse);
      },
    );

    test('a failed Check keeps the upload unconfirmed', () async {
      final h = await _Harness.create();
      await h.uncertainUpload();
      final check = h.controller.checkCurrentAttempt();
      await h.h.failReplay(studentLocalFailure(ApiFailureKind.timeout));
      await check;
      expect(h.entry.status, StudentFileAnswerStatus.uncertain);
      expect(h.state.isReconciling, isFalse);
    });
  });

  test('local countdown zero disables choose and upload', () async {
    final h = await _Harness.create();
    await h.pick();
    h.h.executionController.markLocalTimeExpired(
      h.h.execution.countdownAnchor!,
    );
    await flushStudentControllers();
    expect(h.state.canChoose(_file), isFalse);
    expect(h.state.canUpload(_file), isFalse);
    await h.controller.uploadAnswer(_file);
    await h.controller.chooseFile(_file);
    expect(h.h.answers.uploads, isEmpty);
    expect(h.h.picker.requests, hasLength(1));
  });

  test(
    'an upload success after local zero is kept before the replay',
    () async {
      final h = await _Harness.create();
      await h.pick();
      final upload = h.controller.uploadAnswer(_file);
      h.h.executionController.markLocalTimeExpired(
        h.h.execution.countdownAnchor!,
      );
      h.h.answers.uploads.single.complete(_result());
      await upload;
      await flushStudentControllers();
      expect(h.h.execution.attempt!.answers, hasLength(1));
      expect(h.h.replays.single, same(h.h.completedRequest));
    },
  );

  test('a claimed Submit gate blocks file writes', () async {
    final h = await _Harness.create();
    await h.pick();
    h.h.listen(
      studentBlitzExecutionOperationGateProvider(blitzExecutionTarget),
    );
    expect(
      h.h.container
          .read(
            studentBlitzExecutionOperationGateProvider(
              blitzExecutionTarget,
            ).notifier,
          )
          .claimSubmit(),
      isTrue,
    );
    await h.controller.uploadAnswer(_file);
    await h.controller.chooseFile(_file);
    h.controller.discardSelectedFile(_file);
    expect(h.h.answers.uploads, isEmpty);
    expect(h.h.picker.requests, hasLength(1));
    expect(h.entry.selectedFile, isNotNull);
  });

  test('a picker completing after a session switch is ignored', () async {
    final h = await _Harness.create();
    final choose = h.controller.chooseFile(_file);
    h.h.auth.replaceUser(studentUser('student-b'));
    await flushStudentControllers();
    h.h.picker.pending.single.complete(blitzUploadFile());
    await choose;
    expect(h.state.questions, isEmpty);
  });

  test('leaving discards the selected file', () async {
    final h = await _Harness.create();
    await h.pick();
    h.controller.clearLocalState();
    expect(h.state.hasPendingSelection, isFalse);
    expect(h.state.questions, isEmpty);
  });
}

final _file = blitzQuestionId(3);

StudentAttemptAnswerMutationResult _result({StudentSubmissionFile? file}) =>
    blitzMutationResult(
      3,
      StudentQuestionType.fileBased,
      StudentFileAnswerValue(file: file ?? blitzServerFile()),
    );

class _Harness {
  _Harness(this.h) {
    h.listen(studentBlitzFileAnswerControllerProvider(blitzExecutionTarget));
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

  StudentFileAnswerState get state => h.container.read(
    studentBlitzFileAnswerControllerProvider(blitzExecutionTarget),
  );
  StudentBlitzFileAnswerController get controller => h.container.read(
    studentBlitzFileAnswerControllerProvider(blitzExecutionTarget).notifier,
  );
  StudentFileQuestionAnswerState get entry => state.questions[_file]!;

  Future<void> pick([StudentSubmissionUploadFile? file]) async {
    final choose = controller.chooseFile(_file);
    h.picker.pending.last.complete(file ?? blitzUploadFile());
    await choose;
  }

  Future<void> uncertainUpload() async {
    await pick();
    final upload = controller.uploadAnswer(_file);
    h.answers.uploads.last.fail(studentLocalFailure(ApiFailureKind.timeout));
    await upload;
    await flushStudentControllers();
  }
}
