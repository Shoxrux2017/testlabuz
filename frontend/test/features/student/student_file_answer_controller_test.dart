import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_route_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'student_test_support.dart';

const _homeworkId = '4abcdef0-0000-0000-0000-000000000001';
const _attemptId = '6abcdef0-0000-0000-0000-000000000001';
const _questionId = '7abcdef0-0000-0000-0000-000000000001';
const _secondId = '7abcdef0-0000-0000-0000-000000000002';
const _textId = '7abcdef0-0000-0000-0000-000000000003';
const _fileId = '8abcdef0-0000-0000-0000-000000000001';
final _target = StudentHomeworkAttemptRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
  attemptId: _attemptId,
);
final _detailTarget = StudentHomeworkRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
);

void main() {
  test(
    'selection and confirmed upload preserve their parent publication',
    () async {
      final h = _Harness();
      await h.flush();
      final publication = h.container
          .read(studentHomeworkAttemptControllerProvider(_target))
          .publicationToken;
      expect(publication, isNotNull);
      expect(h.state.sourceAttemptPublication, same(publication));
      await h.pick();
      expect(h.state.sourceAttemptPublication, same(publication));
      final upload = h.controller.uploadAnswer(_questionId);
      expect(h.state.activeQuestionId, _questionId);
      expect(h.entry.status, StudentFileAnswerStatus.uploading);
      h.repository.uploads.single.complete(_result());
      await upload;
      expect(h.state.sourceAttemptPublication, same(publication));
      final newer = _data(_attempt());
      h.parent.publish(newer);
      await h.flush();
      expect(h.state.sourceAttemptPublication, same(newer.publicationToken));
      expect(h.entry.serverFile, isNull);
    },
  );

  test(
    'older upload overlay cannot claim a newer parent publication',
    () async {
      final h = _Harness();
      await h.pick();
      final upload = h.controller.uploadAnswer(_questionId);
      h.parent.publish(_data(_attempt()));
      await h.flush();
      h.repository.uploads.single.complete(_result());
      await upload;
      expect(h.state.sourceAttemptPublication, isNull);
    },
  );

  test(
    'mixed uncertain file and owned GET wait for complete parent rebase',
    () async {
      final h = _Harness();
      await h.makeUncertain();
      expect(h.state.sourceAttemptPublication, isNotNull);
      h.parent.publish(_data(_attempt(saved: true)));
      await h.flush();
      expect(h.state.hasUncertainUpload, isTrue);
      expect(h.state.sourceAttemptPublication, isNull);
      final reload = h.controller.reloadAttempt();
      h.repository.reads.single.complete(_attempt(saved: true));
      await reload;
      expect(h.state.hasUncertainUpload, isFalse);
      expect(h.state.sourceAttemptPublication, isNull);
      final complete = _data(_attempt(saved: true));
      h.parent.publish(complete);
      await h.flush();
      expect(h.state.sourceAttemptPublication, same(complete.publicationToken));
    },
  );

  for (final uncertainGate in [false, true]) {
    for (final storageFailure in [false, true]) {
      test('Submit gate uncertain=$uncertainGate refuses file entries '
          'after storageFailure=$storageFailure', () async {
        final h = _Harness(attempt: _attempt(saved: true));
        await h.pick();
        if (storageFailure) {
          final upload = h.controller.uploadAnswer(_questionId);
          h.repository.uploads.single.fail(
            studentServerFailure(
              ApiErrorCodes.fileUploadFailed,
              statusCode: 500,
            ),
          );
          await upload;
        }
        h.container.listen(
          studentAttemptRouteOperationGateProvider(_target),
          (_, _) {},
        );
        final gate = h.container.read(
          studentAttemptRouteOperationGateProvider(_target).notifier,
        );
        expect(gate.claimSubmit(), isTrue);
        if (uncertainGate) expect(gate.markSubmitUncertain(), isTrue);
        final before = h.state;
        final pickerCount = h.picker.requests.length;
        final uploadCount = h.repository.uploads.length;
        await h.controller.chooseFile(_questionId);
        await h.controller.uploadAnswer(_questionId);
        h.controller.discardSelectedFile(_questionId);
        await h.controller.reloadAttempt();
        expect(h.state, same(before));
        expect(h.picker.requests, hasLength(pickerCount));
        expect(h.repository.uploads, hasLength(uploadCount));
        expect(h.repository.reads, isEmpty);
        h.controller.clearLocalState();
        expect(h.state.questions, isEmpty);
        expect(h.state.sourceAttemptPublication, isNull);
      });
    }

    test(
      'Submit gate uncertain=$uncertainGate freezes uncertain upload GET',
      () async {
        final h = _Harness();
        await h.makeUncertain();
        h.container.listen(
          studentAttemptRouteOperationGateProvider(_target),
          (_, _) {},
        );
        final gate = h.container.read(
          studentAttemptRouteOperationGateProvider(_target).notifier,
        );
        expect(gate.claimSubmit(), isTrue);
        if (uncertainGate) expect(gate.markSubmitUncertain(), isTrue);
        final before = h.state;
        await h.controller.reloadAttempt();
        expect(h.state, same(before));
        expect(h.repository.reads, isEmpty);
      },
    );
  }

  test(
    'picker cancellation preserves server file refreshed while picker is open',
    () async {
      final h = _Harness();
      await h.pick();
      final selected = h.entry.selectedFile;
      expect(h.entry.serverFile, isNull);
      final pending = h.controller.chooseFile(_questionId);
      h.parent.publish(_data(_attempt(saved: true)));
      await h.flush();
      final currentFile = h.entry.serverFile;
      expect(currentFile, isNotNull);
      h.picker.requests.last.complete(null);
      await pending;
      expect(h.entry.serverFile, same(currentFile));
      expect(h.entry.selectedFile, same(selected));
      expect(h.entry.status, StudentFileAnswerStatus.ready);
      expect(h.state.activeQuestionId, isNull);
      expect(h.repository.uploads, isEmpty);
    },
  );

  for (final status in [
    StudentHomeworkAttemptLoadStatus.refreshing,
    StudentHomeworkAttemptLoadStatus.error,
  ]) {
    test(
      'valid owned GET recovery retains selection without $status mutation authority',
      () async {
        final h = _Harness();
        await h.makeUncertain();
        final selected = h.entry.selectedFile;
        h.parent.publish(
          StudentHomeworkAttemptState(status: status, attempt: _attempt()),
        );
        await h.flush();
        final reload = h.controller.reloadAttempt();
        h.repository.reads.single.complete(_attempt(saved: true));
        await reload;
        await h.flush();
        expect(h.entry.status, StudentFileAnswerStatus.ready);
        expect(h.entry.selectedFile, same(selected));
        expect(h.entry.selectionError, isNull);
        expect(h.state.hasUncertainUpload, isFalse);
        expect(h.state.canChoose(_questionId), isFalse);
        expect(h.state.canUpload(_questionId), isFalse);
        await h.controller.chooseFile(_questionId);
        await h.controller.uploadAnswer(_questionId);
        expect(h.picker.requests, hasLength(1));
        expect(h.repository.uploads, hasLength(1));
      },
    );
  }

  test(
    'late PUT progress cannot replace uncertain upload recovery state',
    () async {
      final h = _Harness();
      await h.makeUncertain();
      final uncertain = h.entry;
      h.repository.uploads.single.progress!(3, 3);
      expect(h.entry, same(uncertain));
      expect(h.entry.status, StudentFileAnswerStatus.uncertain);
      expect(h.state.hasUncertainUpload, isTrue);
      expect(h.state.canUpload(_questionId), isFalse);
      final reload = h.controller.reloadAttempt();
      expect(h.repository.reads, hasLength(1));
      h.repository.reads.single.complete(_attempt(saved: true));
      await reload;
      expect(h.entry.status, StudentFileAnswerStatus.ready);
      expect(h.repository.uploads, hasLength(1));
    },
  );

  for (final saved in [false, true]) {
    test(
      'initializes only file questions with saved=$saved and no local selection',
      () async {
        final h = _Harness(attempt: _attempt(saved: saved));
        await h.flush();
        expect(h.state.questions, hasLength(2));
        expect(h.entry.serverFile == null, !saved);
        expect(h.entry.selectedFile, isNull);
        expect(h.entry.status, StudentFileAnswerStatus.idle);
        expect(h.state.hasPendingSelection, isFalse);
        expect(h.state.questions.containsKey(_textId), isFalse);
      },
    );
  }

  test(
    'picker cancellation restores selection and picker failure is local and safe',
    () async {
      final h = _Harness();
      await h.pick();
      final selected = h.entry.selectedFile;
      final cancel = h.controller.chooseFile(_questionId);
      expect(h.state.activeQuestionId, _questionId);
      expect(h.entry.status, StudentFileAnswerStatus.selecting);
      h.picker.requests.last.complete(null);
      await cancel;
      expect(h.entry.selectedFile, same(selected));
      expect(h.entry.status, StudentFileAnswerStatus.ready);
      expect(h.entry.failure, isNull);
      final failure = h.controller.chooseFile(_questionId);
      h.picker.requests.last.completeError(StateError('private local path'));
      await failure;
      expect(
        h.entry.localFailure,
        StudentFileAnswerLocalFailure.pickerUnavailable,
      );
      expect(h.entry.selectedFile, same(selected));
      expect(h.entry.status, StudentFileAnswerStatus.ready);
      expect(h.state.canUpload(_questionId), isTrue);
      expect(h.state.activeQuestionId, isNull);
      expect(h.repository.uploads, isEmpty);
    },
  );

  for (final invalid in [
    (
      _selected(name: 'answer.exe'),
      StudentSubmissionSelectionError.unsupportedExtension,
    ),
    (_selected(length: 0), StudentSubmissionSelectionError.emptyFile),
    (_selected(length: 1001), StudentSubmissionSelectionError.tooLarge),
    (
      _selected(name: '${'😀' * 497}.pdf'),
      StudentSubmissionSelectionError.filenameTooLong,
    ),
    (_selected(name: '..'), StudentSubmissionSelectionError.invalidFilename),
  ]) {
    test(
      'invalid picker selection ${invalid.$2} preserves previous valid intent',
      () async {
        final h = _Harness();
        await h.pick();
        final previous = h.entry.selectedFile;
        await h.pick(file: invalid.$1);
        expect(h.entry.selectedFile, same(previous));
        expect(h.entry.selectionError, invalid.$2);
        expect(h.entry.status, StudentFileAnswerStatus.ready);
        expect(h.state.canUpload(_questionId), isTrue);
        expect(h.repository.uploads, isEmpty);
      },
    );
  }

  test(
    'selection is explicit dirty work and discard preserves saved answer',
    () async {
      final h = _Harness(attempt: _attempt(saved: true));
      await h.pick();
      final selected = h.entry.selectedFile;
      expect(h.picker.extensions.single, ['pdf', 'docx', 'ppt', 'pptx']);
      expect(h.state.hasPendingSelection, isTrue);
      expect(h.repository.uploads, isEmpty);
      await h.pick(file: _selected(name: 'new.pdf'));
      expect(h.entry.selectedFile, isNot(same(selected)));
      h.controller.discardSelectedFile(_questionId);
      expect(h.entry.selectedFile, isNull);
      expect(h.entry.serverFile!.id, _fileId);
      expect(h.repository.uploads, isEmpty);
    },
  );

  for (final status in StudentHomeworkAttemptLoadStatus.values.where(
    (s) => s != StudentHomeworkAttemptLoadStatus.data,
  )) {
    test(
      '$status retained in-progress data cannot Choose, Upload or Retry',
      () async {
        final h = _Harness();
        await h.pick();
        final upload = h.controller.uploadAnswer(_questionId);
        h.repository.uploads.single.fail(
          studentServerFailure(ApiErrorCodes.fileUploadFailed, statusCode: 500),
        );
        await upload;
        h.parent.publish(
          StudentHomeworkAttemptState(status: status, attempt: _attempt()),
        );
        await h.flush();
        expect(h.state.canChoose(_questionId), isFalse);
        expect(h.state.canUpload(_questionId), isFalse);
        await h.controller.chooseFile(_questionId);
        await h.controller.uploadAnswer(_questionId);
        expect(h.picker.requests, hasLength(1));
        expect(h.repository.uploads, hasLength(1));
        expect(h.entry.selectedFile, isNotNull);
      },
    );
  }

  for (final invalid in [
    null,
    _attempt(id: 'bad'),
    _attempt(id: '6abcdef0-0000-0000-0000-000000000002'),
    _attempt(homeworkId: '4abcdef0-0000-0000-0000-000000000002'),
    _attempt(questions: [_question(id: _secondId)]),
    _attempt(questions: [_textQuestion(id: _questionId)]),
  ]) {
    test(
      'current data requires matching route and current file Question ${invalid?.id}/${invalid?.questions.length}',
      () async {
        final h = _Harness();
        await h.pick();
        h.parent.publish(_data(invalid));
        await h.flush();
        await h.controller.chooseFile(_questionId);
        await h.controller.uploadAnswer(_questionId);
        expect(h.picker.requests, hasLength(1));
        expect(h.repository.uploads, isEmpty);
      },
    );
  }

  test(
    'current lowered policy blocks previously ready file and exposes typed error',
    () async {
      final h = _Harness();
      await h.pick();
      h.parent.publish(_data(_attempt(questions: [_question(maxSize: 2)])));
      await h.flush();
      expect(h.entry.selectedFile, isNotNull);
      expect(h.state.canUpload(_questionId), isFalse);
      await h.controller.uploadAnswer(_questionId);
      expect(h.entry.selectionError, StudentSubmissionSelectionError.tooLarge);
      expect(h.repository.uploads, isEmpty);
    },
  );

  test(
    'one picker/upload owns Attempt while other ready selections and non-file Save survive',
    () async {
      final h = _Harness();
      await h.pick(id: _secondId);
      final second = h.state.questions[_secondId]!.selectedFile;
      final pick = h.controller.chooseFile(_questionId);
      await h.controller.chooseFile(_secondId);
      await h.controller.uploadAnswer(_secondId);
      expect(h.picker.requests, hasLength(2));
      expect(h.repository.uploads, isEmpty);
      h.picker.requests.last.complete(_selected());
      await pick;
      final upload = h.controller.uploadAnswer(_questionId);
      await h.controller.chooseFile(_secondId);
      await h.controller.uploadAnswer(_secondId);
      expect(h.repository.uploads, hasLength(1));
      final nonFile = h.container.read(
        studentAttemptAnswerEditorControllerProvider(_target).notifier,
      );
      nonFile.updateDraft(
        _textId,
        StudentAnswerDraft.fromAnswer(
          _textQuestion(),
          const StudentTextAnswerValue(text: 'Draft'),
        ),
      );
      final save = nonFile.saveAnswer(_textId);
      expect(h.repository.saves, hasLength(1));
      h.repository.saves.single.complete(
        StudentAttemptAnswerMutationResult(
          questionId: _textId,
          type: StudentQuestionType.shortWritten,
          answer: const StudentTextAnswerValue(text: 'Draft'),
          updatedAt: DateTime.utc(2026, 9, 1),
        ),
      );
      await save;
      h.repository.uploads.single.complete(_result());
      await upload;
      expect(h.state.questions[_secondId]!.selectedFile, same(second));
      expect(h.state.activeQuestionId, isNull);
    },
  );

  for (final saved in [false, true]) {
    test(
      'confirmed ${saved ? 'replacement' : 'first upload'} preserves File ID and refreshes parent',
      () async {
        final h = _Harness(attempt: _attempt(saved: saved));
        await h.pick(file: _selected(name: 'new.pdf'));
        final upload = h.controller.uploadAnswer(_questionId);
        final request = h.repository.uploads.single;
        expect(request.attemptId, _attemptId);
        expect(request.question.id, _questionId);
        expect(request.file.name, 'new.pdf');
        request.progress!(3, 3);
        expect(h.entry.sentBytes, 3);
        expect(h.entry.totalBytes, 3);
        expect(h.entry.status, StudentFileAnswerStatus.uploading);
        expect(h.entry.selectedFile, isNotNull);
        request.complete(_result(name: 'new.pdf'));
        await upload;
        expect(h.entry.status, StudentFileAnswerStatus.uploaded);
        expect(h.entry.serverFile!.id, _fileId);
        expect(h.entry.serverFile!.originalName, 'new.pdf');
        expect(h.entry.selectedFile, isNull);
        expect(h.entry.sentBytes, 0);
        expect(h.state.activeQuestionId, isNull);
        expect(h.parent.refreshCalls, 1);
      },
    );
  }

  for (final malformed in [
    _result(fileId: '8abcdef0-0000-0000-0000-000000000002'),
    _result(name: 'wrong.pdf'),
    _result(questionId: _secondId),
    _result(length: 2),
    _result(extension: 'docx'),
    _result(updatedAt: DateTime.utc(2026, 9, 1, 0, 0, 0, 1)),
  ]) {
    test(
      'invalid typed upload result ${malformed.questionId}/${(malformed.answer as StudentFileAnswerValue).file.originalName}/${malformed.updatedAt} remains uncertain',
      () async {
        final h = _Harness(attempt: _attempt(saved: true));
        await h.pick();
        final selected = h.entry.selectedFile;
        final upload = h.controller.uploadAnswer(_questionId);
        h.repository.uploads.single.complete(malformed);
        await upload;
        expect(h.entry.status, StudentFileAnswerStatus.uncertain);
        expect(h.entry.failure!.kind, ApiFailureKind.invalidResponse);
        expect(h.entry.selectedFile, same(selected));
        expect(h.parent.refreshCalls, 0);
      },
    );
  }

  for (final failure in [
    for (final kind in [
      ApiFailureKind.connection,
      ApiFailureKind.timeout,
      ApiFailureKind.cancelled,
      ApiFailureKind.invalidResponse,
      ApiFailureKind.unknown,
    ])
      studentLocalFailure(kind),
    studentServerFailure('unclassified', statusCode: 500),
    studentServerFailure('unclassified', statusCode: 503),
    ApiRequestException(
      ApiFailure(kind: ApiFailureKind.server, message: 'Unknown status'),
    ),
  ]) {
    test(
      '${failure.failure.kind}/${failure.failure.statusCode} has GET recovery only and no blind replay',
      () async {
        final h = _Harness();
        await h.makeUncertain(failure: failure);
        final selected = h.entry.selectedFile;
        expect(h.entry.status, StudentFileAnswerStatus.uncertain);
        await h.controller.uploadAnswer(_questionId);
        await h.controller.chooseFile(_questionId);
        expect(h.repository.uploads, hasLength(1));
        expect(h.picker.requests, hasLength(1));
        final reload = h.controller.reloadAttempt();
        await h.controller.reloadAttempt();
        await h.controller.chooseFile(_secondId);
        await h.controller.uploadAnswer(_questionId);
        expect(h.state.isReconciling, isTrue);
        expect(h.state.activeQuestionId, _questionId);
        expect(h.repository.reads, hasLength(1));
        h.repository.reads.single.complete(_attempt(saved: true));
        await reload;
        expect(h.entry.status, StudentFileAnswerStatus.ready);
        expect(h.entry.selectedFile, same(selected));
        expect(h.entry.serverFile!.originalName, selected!.name);
        expect(h.state.hasUncertainUpload, isFalse);
        expect(h.state.hasPendingSelection, isTrue);
        expect(h.repository.uploads, hasLength(1));
        expect(h.entry.status, isNot(StudentFileAnswerStatus.uploaded));
      },
    );
  }

  test(
    'ordinary parent refresh and omission retain exact uncertainty snapshot and recovery ownership',
    () async {
      final h = _Harness();
      await h.makeUncertain();
      final entry = h.entry;
      h.parent.publish(_data(_attempt(saved: true)));
      await h.flush();
      expect(h.entry, same(entry));
      h.parent.publish(_data(_attempt(questions: [_question(id: _secondId)])));
      await h.flush();
      expect(h.entry, same(entry));
      expect(h.state.activeQuestionId, _questionId);
      expect(h.state.hasUncertainUpload, isTrue);
      final reload = h.controller.reloadAttempt();
      h.repository.reads.single.complete(_attempt(saved: true));
      await reload;
      expect(h.entry.selectedFile, same(entry.selectedFile));
      expect(h.entry.status, StudentFileAnswerStatus.ready);
    },
  );

  for (final invalid in [
    _attempt(id: 'bad'),
    _attempt(homeworkId: 'bad'),
    _attempt(id: '6abcdef0-0000-0000-0000-000000000002'),
    _attempt(homeworkId: '4abcdef0-0000-0000-0000-000000000002'),
    _attempt(questions: []),
    _attempt(questions: [_question(), _question()]),
    _attempt(questions: [_textQuestion(id: _questionId)]),
    _attempt(
      questions: [
        const StudentQuestion(
          id: _questionId,
          type: StudentQuestionType.fileBased,
          prompt: 'File',
          instructions: null,
          points: 1,
          position: 1,
          answerUi: StudentEmptyAnswerUi(),
        ),
      ],
    ),
  ]) {
    test(
      'invalid owned reconciliation ${invalid.id}/${invalid.assessmentId}/${invalid.questions.length} preserves selected snapshot',
      () async {
        final h = _Harness();
        await h.makeUncertain();
        final selected = h.entry.selectedFile;
        final reload = h.controller.reloadAttempt();
        h.repository.reads.single.complete(invalid);
        await reload;
        expect(h.entry.status, StudentFileAnswerStatus.uncertain);
        expect(h.entry.selectedFile, same(selected));
        expect(h.state.activeQuestionId, _questionId);
        expect(h.state.isReconciling, isFalse);
        expect(h.entry.failure!.kind, ApiFailureKind.invalidResponse);
        expect(h.repository.uploads, hasLength(1));
      },
    );
  }

  test(
    'failed owned GET retains uncertainty and can reload again without PUT',
    () async {
      final h = _Harness();
      await h.makeUncertain();
      final selected = h.entry.selectedFile;
      final reload = h.controller.reloadAttempt();
      h.repository.reads.single.completeError(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await reload;
      expect(h.state.isReconciling, isFalse);
      expect(h.entry.selectedFile, same(selected));
      final second = h.controller.reloadAttempt();
      expect(h.repository.reads, hasLength(2));
      h.repository.reads.last.complete(_attempt(saved: true));
      await second;
      expect(h.entry.status, StudentFileAnswerStatus.ready);
      expect(h.repository.uploads, hasLength(1));
    },
  );

  test(
    'owned GET revalidates lowered policy and retained parent error grants no upload authority',
    () async {
      final h = _Harness();
      await h.makeUncertain();
      h.parent.publish(
        StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.error,
          attempt: _attempt(),
        ),
      );
      await h.flush();
      final reload = h.controller.reloadAttempt();
      h.repository.reads.single.complete(
        _attempt(questions: [_question(maxSize: 2)]),
      );
      await reload;
      await h.flush();
      expect(h.entry.selectionError, StudentSubmissionSelectionError.tooLarge);
      expect(h.entry.selectedFile, isNull);
      await h.controller.uploadAnswer(_questionId);
      expect(h.repository.uploads, hasLength(1));
    },
  );

  test(
    'storage failure is confirmed and new explicit Retry uses same selection',
    () async {
      final h = _Harness(attempt: _attempt(saved: true));
      await h.pick();
      final selected = h.entry.selectedFile;
      final upload = h.controller.uploadAnswer(_questionId);
      h.repository.uploads.single.fail(
        studentServerFailure(ApiErrorCodes.fileUploadFailed, statusCode: 500),
      );
      await upload;
      expect(h.entry.status, StudentFileAnswerStatus.failure);
      expect(h.state.hasUncertainUpload, isFalse);
      expect(h.state.canUpload(_questionId), isTrue);
      expect(h.entry.selectedFile, same(selected));
      expect(h.entry.serverFile!.id, _fileId);
      final retry = h.controller.uploadAnswer(_questionId);
      expect(h.repository.uploads, hasLength(2));
      expect(h.repository.uploads.last.file, same(selected));
      h.repository.uploads.last.complete(_result());
      await retry;
      expect(h.entry.status, StudentFileAnswerStatus.uploaded);
    },
  );

  for (final code in [
    ApiErrorCodes.unsupportedFileType,
    ApiErrorCodes.fileTooLarge,
  ]) {
    test('$code clears invalid selection and preserves server file', () async {
      final h = _Harness(attempt: _attempt(saved: true));
      await h.pick();
      final upload = h.controller.uploadAnswer(_questionId);
      h.repository.uploads.single.fail(
        studentServerFailure(code, statusCode: 422),
      );
      await upload;
      expect(h.entry.selectedFile, isNull);
      expect(h.entry.serverFile!.id, _fileId);
      expect(h.entry.status, StudentFileAnswerStatus.failure);
      expect(h.state.activeQuestionId, isNull);
      expect(h.parent.refreshCalls, code == ApiErrorCodes.fileTooLarge ? 1 : 0);
    });
  }

  test(
    'validation failure retains context but cannot resend until new selection',
    () async {
      final h = _Harness();
      await h.pick();
      final selected = h.entry.selectedFile;
      final upload = h.controller.uploadAnswer(_questionId);
      h.repository.uploads.single.fail(
        studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
      );
      await upload;
      expect(h.entry.selectedFile, same(selected));
      expect(h.state.canUpload(_questionId), isFalse);
      await h.controller.uploadAnswer(_questionId);
      expect(h.repository.uploads, hasLength(1));
      await h.pick();
      expect(h.state.canUpload(_questionId), isTrue);
    },
  );

  for (final failure in [
    (code: ApiErrorCodes.validationFailed, statusCode: 422),
    (code: ApiErrorCodes.fileUploadFailed, statusCode: 500),
  ]) {
    for (final outcome in ['cancellation', 'invalid selection', 'exception']) {
      test(
        '${failure.code} retains selected-file provenance after picker $outcome',
        () async {
          final h = _Harness();
          await h.pick();
          final selected = h.entry.selectedFile;
          final upload = h.controller.uploadAnswer(_questionId);
          h.repository.uploads.single.fail(
            studentServerFailure(failure.code, statusCode: failure.statusCode),
          );
          await upload;
          final serverFailure = h.entry.failure;
          final previousQuestion = h.entry.question;

          final repick = h.controller.chooseFile(_questionId);
          expect(h.entry.status, StudentFileAnswerStatus.selecting);
          expect(h.entry.failure, same(serverFailure));
          final currentQuestion = _question(maxSize: 10);
          h.parent.publish(
            _data(_attempt(saved: true, questions: [currentQuestion])),
          );
          await h.flush();
          final currentFile = h.entry.serverFile;
          expect(currentFile, isNotNull);
          switch (outcome) {
            case 'cancellation':
              h.picker.requests.last.complete(null);
            case 'invalid selection':
              h.picker.requests.last.complete(_selected(name: 'answer.exe'));
            case 'exception':
              h.picker.requests.last.completeError(
                StateError('private local path'),
              );
          }
          await repick;

          expect(h.entry.selectedFile, same(selected));
          expect(h.entry.failure, same(serverFailure));
          expect(h.entry.failure!.serverCode, failure.code);
          expect(h.entry.status, StudentFileAnswerStatus.failure);
          expect(h.entry.question, isNot(same(previousQuestion)));
          expect(h.entry.question, same(currentQuestion));
          expect(h.entry.serverFile, same(currentFile));
          expect(
            h.entry.selectionError,
            outcome == 'invalid selection'
                ? StudentSubmissionSelectionError.unsupportedExtension
                : isNull,
          );
          expect(
            h.entry.localFailure,
            outcome == 'exception'
                ? StudentFileAnswerLocalFailure.pickerUnavailable
                : isNull,
          );
          expect(h.state.activeQuestionId, isNull);

          if (failure.code == ApiErrorCodes.validationFailed) {
            expect(h.state.canUpload(_questionId), isFalse);
            await h.controller.uploadAnswer(_questionId);
            expect(h.repository.uploads, hasLength(1));

            final replacement = _selected(name: 'replacement.pdf');
            await h.pick(file: replacement);
            expect(h.entry.selectedFile, same(replacement));
            expect(h.entry.failure, isNull);
            expect(h.entry.selectionError, isNull);
            expect(h.entry.localFailure, isNull);
            expect(h.entry.status, StudentFileAnswerStatus.ready);
            expect(h.state.canUpload(_questionId), isTrue);
          } else {
            expect(h.state.hasUncertainUpload, isFalse);
            expect(h.state.canUpload(_questionId), isTrue);
            final retry = h.controller.uploadAnswer(_questionId);
            expect(h.repository.uploads, hasLength(2));
            expect(h.repository.uploads.last.file, same(selected));
            h.repository.uploads.last.complete(_result());
            await retry;
            expect(h.entry.status, StudentFileAnswerStatus.uploaded);
          }
        },
      );
    }

    for (final status in [
      StudentHomeworkAttemptLoadStatus.refreshing,
      StudentHomeworkAttemptLoadStatus.error,
    ]) {
      test(
        '${failure.code} retains selected-file provenance when picker loses $status authority',
        () async {
          final h = _Harness();
          await h.pick();
          final selected = h.entry.selectedFile;
          final upload = h.controller.uploadAnswer(_questionId);
          h.repository.uploads.single.fail(
            studentServerFailure(failure.code, statusCode: failure.statusCode),
          );
          await upload;
          final serverFailure = h.entry.failure;
          final previousQuestion = h.entry.question;

          final repick = h.controller.chooseFile(_questionId);
          expect(h.entry.status, StudentFileAnswerStatus.selecting);
          expect(h.entry.failure, same(serverFailure));
          final currentQuestion = _question(maxSize: 10);
          final currentAttempt = _attempt(
            saved: true,
            questions: [currentQuestion],
          );
          h.parent.publish(_data(currentAttempt));
          await h.flush();
          final currentFile = h.entry.serverFile;
          expect(currentFile, isNotNull);
          h.parent.publish(
            StudentHomeworkAttemptState(
              status: status,
              attempt: currentAttempt,
            ),
          );
          await h.flush();
          h.picker.requests.last.complete(_selected(name: 'replacement.pdf'));
          await repick;

          expect(h.entry.selectedFile, same(selected));
          expect(h.entry.failure, same(serverFailure));
          expect(h.entry.failure!.serverCode, failure.code);
          expect(h.entry.status, StudentFileAnswerStatus.failure);
          expect(h.entry.question, isNot(same(previousQuestion)));
          expect(h.entry.question, same(currentQuestion));
          expect(h.entry.serverFile, same(currentFile));
          expect(h.state.activeQuestionId, isNull);
          expect(h.state.canUpload(_questionId), isFalse);
          await h.controller.uploadAnswer(_questionId);
          expect(h.repository.uploads, hasLength(1));

          h.parent.publish(_data(currentAttempt));
          await h.flush();
          if (failure.code == ApiErrorCodes.validationFailed) {
            expect(h.state.canUpload(_questionId), isFalse);
            await h.controller.uploadAnswer(_questionId);
            expect(h.repository.uploads, hasLength(1));
          } else {
            expect(h.state.canUpload(_questionId), isTrue);
            final retry = h.controller.uploadAnswer(_questionId);
            expect(h.repository.uploads, hasLength(2));
            expect(h.repository.uploads.last.file, same(selected));
            h.repository.uploads.last.complete(_result());
            await retry;
            expect(h.entry.status, StudentFileAnswerStatus.uploaded);
          }
        },
      );
    }
  }

  test(
    'valid replacement clears confirmed storage-failure provenance',
    () async {
      final h = _Harness();
      await h.pick();
      final upload = h.controller.uploadAnswer(_questionId);
      h.repository.uploads.single.fail(
        studentServerFailure(ApiErrorCodes.fileUploadFailed, statusCode: 500),
      );
      await upload;
      final replacement = _selected(name: 'replacement.pdf');
      await h.pick(file: replacement);
      expect(h.entry.selectedFile, same(replacement));
      expect(h.entry.failure, isNull);
      expect(h.entry.selectionError, isNull);
      expect(h.entry.localFailure, isNull);
      expect(h.entry.status, StudentFileAnswerStatus.ready);
      expect(h.state.canUpload(_questionId), isTrue);
    },
  );

  test(
    'typed unavailable source clears selection and operation, retains server file and refreshes',
    () async {
      final h = _Harness(attempt: _attempt(saved: true));
      await h.pick();
      final upload = h.controller.uploadAnswer(_questionId);
      h.repository.uploads.single.fail(
        const StudentSubmissionSourceUnavailable(),
      );
      await upload;
      expect(h.entry.selectedFile, isNull);
      expect(h.entry.serverFile!.id, _fileId);
      expect(
        h.entry.localFailure,
        StudentFileAnswerLocalFailure.sourceUnavailable,
      );
      expect(h.entry.failure, isNull);
      expect(h.state.hasUncertainUpload, isFalse);
      expect(h.state.activeQuestionId, isNull);
      expect(h.state.canUpload(_questionId), isFalse);
      expect(h.parent.refreshCalls, 1);
    },
  );

  for (final code in [
    ApiErrorCodes.deadlinePassed,
    ApiErrorCodes.attemptNotEditable,
    ApiErrorCodes.taskNotActive,
    ApiErrorCodes.taskClosed,
    ApiErrorCodes.taskArchived,
    ApiErrorCodes.businessConflict,
    ApiErrorCodes.resourceNotFound,
  ]) {
    test('$code reconciles current Attempt and required Homework', () async {
      final h = _Harness();
      await h.pick();
      final before = h.detailBuilds;
      final upload = h.controller.uploadAnswer(_questionId);
      h.repository.uploads.single.fail(
        studentServerFailure(
          code,
          statusCode: code == ApiErrorCodes.resourceNotFound ? 404 : 409,
        ),
      );
      await upload;
      await h.flush();
      expect(h.state.hasPendingSelection, isFalse);
      expect(h.state.hasUncertainUpload, isFalse);
      expect(h.state.activeQuestionId, isNull);
      expect(h.parent.refreshCalls, 1);
      final homework = [
        ApiErrorCodes.deadlinePassed,
        ApiErrorCodes.taskNotActive,
        ApiErrorCodes.taskClosed,
        ApiErrorCodes.taskArchived,
      ].contains(code);
      expect(h.detailBuilds, before + (homework ? 1 : 0));
      if (code == ApiErrorCodes.resourceNotFound) {
        expect(h.state.questions, isEmpty);
      }
    });
  }

  for (final phase in ['picker', 'upload', 'reconciliation']) {
    test(
      'terminal parent invalidates late $phase and preserves accepted terminal through parent error',
      () async {
        final h = _Harness();
        late Future<void> pending;
        if (phase == 'picker') {
          pending = h.controller.chooseFile(_questionId);
        } else if (phase == 'upload') {
          await h.pick();
          pending = h.controller.uploadAnswer(_questionId);
        } else {
          await h.makeUncertain();
          pending = h.controller.reloadAttempt();
        }
        final terminal = _attempt(saved: true, terminal: true);
        h.parent.publish(_data(terminal));
        await h.flush();
        _expectTerminal(h);
        h.parent.publish(
          StudentHomeworkAttemptState(
            status: StudentHomeworkAttemptLoadStatus.error,
            attempt: _attempt(),
          ),
        );
        await h.flush();
        if (phase == 'picker') {
          h.picker.requests.single.complete(_selected());
        }
        if (phase == 'upload') {
          h.repository.uploads.single.progress!(10, 10);
          h.repository.uploads.single.complete(_result());
        }
        if (phase == 'reconciliation') {
          h.repository.reads.single.complete(_attempt());
        }
        await pending;
        await h.flush();
        _expectTerminal(h);
        expect(h.entry.status, StudentFileAnswerStatus.idle);
        expect(h.entry.serverFile!.id, _fileId);
        expect(h.entry.sentBytes, 0);
      },
    );
  }

  for (final phase in ['picker', 'upload', 'reconciliation']) {
    for (final change in ['logout', 'student', 'surface', 'leave', 'dispose']) {
      test(
        '$change suppresses late $phase feedback and local selection',
        () async {
          final h = _Harness();
          late Future<void> pending;
          if (phase == 'picker') {
            pending = h.controller.chooseFile(_questionId);
          } else if (phase == 'upload') {
            await h.pick();
            pending = h.controller.uploadAnswer(_questionId);
          } else {
            await h.makeUncertain();
            pending = h.controller.reloadAttempt();
          }
          switch (change) {
            case 'logout':
              h.auth.logOut();
            case 'student':
              h.auth.replaceUser(studentUser('student-b'));
            case 'surface':
              h.container
                  .read(_surfaceProvider.notifier)
                  .change(AppDeviceSurface.mobile);
            case 'leave':
              h.controller.clearLocalState();
            case 'dispose':
              h.close();
          }
          if (change != 'dispose') {
            await h.flush();
          }
          if (phase == 'picker') {
            h.picker.requests.single.complete(_selected());
          }
          if (phase == 'upload') {
            h.repository.uploads.single.fail(
              studentServerFailure(ApiErrorCodes.userInactive),
            );
          }
          if (phase == 'reconciliation') {
            h.repository.reads.single.complete(_attempt(saved: true));
          }
          await pending;
          if (change != 'dispose') {
            await h.flush();
            expect(h.state.hasPendingSelection, isFalse);
            expect(h.state.hasUncertainUpload, isFalse);
            expect(h.state.activeQuestionId, isNull);
            expect(
              h.state.questions.values.any((e) => e.failure != null),
              isFalse,
            );
          }
          expect(h.auth.bootstrapCalls, 0);
        },
      );
    }
  }

  for (final code in [
    ApiErrorCodes.authenticationRequired,
    ApiErrorCodes.passwordChangeRequired,
    ApiErrorCodes.userInactive,
    ApiErrorCodes.institutionInactive,
  ]) {
    test(
      '$code clears local ownership and uses existing session behavior',
      () async {
        final h = _Harness();
        await h.pick();
        final upload = h.controller.uploadAnswer(_questionId);
        h.repository.uploads.single.fail(studentServerFailure(code));
        await upload;
        expect(h.state.questions, isEmpty);
        expect(h.state.activeQuestionId, isNull);
        expect(
          h.auth.bootstrapCalls,
          code == ApiErrorCodes.authenticationRequired ? 0 : 1,
        );
      },
    );
  }

  test('equivalent session rebuild preserves active upload identity', () async {
    final h = _Harness();
    await h.pick();
    final upload = h.controller.uploadAnswer(_questionId);
    h.auth.replaceUser(h.container.read(authSessionControllerProvider).user!);
    await h.flush();
    h.repository.uploads.single.complete(_result());
    await upload;
    expect(h.entry.status, StudentFileAnswerStatus.uploaded);
  });

  test(
    'file-owned terminal GET publishes through real parent and defeats older GET',
    () async {
      final h = _Harness(realParent: true);
      await h.flush();
      h.repository.reads.single.complete(_attempt());
      await h.flush();
      await h.makeUncertain();
      final parent = h.container.read(
        studentHomeworkAttemptControllerProvider(_target).notifier,
      );
      parent.refresh();
      final older = h.repository.reads.last;
      final reload = h.controller.reloadAttempt();
      h.repository.reads.last.complete(_attempt(saved: true, terminal: true));
      await reload;
      await h.flush();
      _expectTerminal(h);
      expect(
        h.container
            .read(studentHomeworkAttemptControllerProvider(_target))
            .status,
        StudentHomeworkAttemptLoadStatus.data,
      );
      older.complete(_attempt());
      await h.flush();
      expect(
        h.container
            .read(studentHomeworkAttemptControllerProvider(_target))
            .attempt!
            .status,
        StudentHomeworkAttemptStatus.submitted,
      );
      parent.refresh();
      h.repository.reads.last.completeError(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await h.flush();
      _expectTerminal(h);
      expect(
        h.container
            .read(studentAttemptAnswerEditorControllerProvider(_target))
            .terminalAttempt,
        isNotNull,
      );
      expect(h.entry.serverFile!.id, _fileId);
    },
  );
}

void _expectTerminal(_Harness h) {
  expect(h.state.isTerminal, isTrue);
  expect(h.state.activeQuestionId, isNull);
  expect(h.state.hasPendingSelection, isFalse);
  expect(h.state.hasUncertainUpload, isFalse);
  expect(h.state.canChoose(_questionId), isFalse);
  expect(h.state.canUpload(_questionId), isFalse);
}

class _Harness {
  _Harness({StudentHomeworkAttempt? attempt, bool realParent = false}) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWith(
          (ref) => ref.watch(_surfaceProvider),
        ),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(repository),
        studentSubmissionFilePickerProvider.overrideWithValue(picker),
        if (!realParent)
          studentHomeworkAttemptControllerProvider(
            _target,
          ).overrideWith(() => parent = _Parent(_data(attempt ?? _attempt()))),
        studentHomeworkDetailControllerProvider(
          _detailTarget,
        ).overrideWith(() => _Detail(() => detailBuilds += 1)),
      ],
    );
    container.listen(
      studentHomeworkDetailControllerProvider(_detailTarget),
      (_, _) {},
    );
    subscription = container.listen(
      studentFileAnswerControllerProvider(_target),
      (_, _) {},
    );
    addTearDown(close);
  }
  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  final repository = _Repository();
  final picker = _Picker();
  late final ProviderContainer container;
  late final ProviderSubscription<StudentFileAnswerState> subscription;
  late _Parent parent;
  var detailBuilds = 0;
  var closed = false;
  StudentFileAnswerState get state => subscription.read();
  StudentFileQuestionAnswerState get entry => state.questions[_questionId]!;
  StudentFileAnswerController get controller =>
      container.read(studentFileAnswerControllerProvider(_target).notifier);
  Future<void> pick({
    String id = _questionId,
    StudentSubmissionUploadFile? file,
  }) async {
    await flush();
    final future = controller.chooseFile(id);
    picker.requests.last.complete(file ?? _selected());
    await future;
    await flush();
  }

  Future<void> makeUncertain({ApiRequestException? failure}) async {
    await pick();
    final upload = controller.uploadAnswer(_questionId);
    repository.uploads.last.fail(
      failure ?? studentLocalFailure(ApiFailureKind.timeout),
    );
    await upload;
    await flush();
  }

  Future<void> flush() async {
    await Future<void>.value();
    await container.pump();
    await Future<void>.value();
    await container.pump();
  }

  void close() {
    if (!closed) {
      closed = true;
      container.dispose();
    }
  }
}

class _Parent extends StudentHomeworkAttemptController {
  _Parent(this.initial) : super(_target);
  final StudentHomeworkAttemptState initial;
  var refreshCalls = 0;
  @override
  StudentHomeworkAttemptState build() => initial;
  @override
  void refresh() {
    refreshCalls += 1;
  }

  void publish(StudentHomeworkAttemptState next) {
    state = next;
  }
}

class _Detail extends StudentHomeworkDetailController {
  _Detail(this.onBuild) : super(_detailTarget);
  final void Function() onBuild;
  @override
  StudentHomeworkDetailState build() {
    onBuild();
    return const StudentHomeworkDetailState();
  }
}

final _surfaceProvider = NotifierProvider<_Surface, AppDeviceSurface>(
  _Surface.new,
);

class _Surface extends Notifier<AppDeviceSurface> {
  @override
  AppDeviceSurface build() => AppDeviceSurface.desktop;
  void change(AppDeviceSurface next) {
    state = next;
  }
}

class _Picker implements StudentSubmissionFilePicker {
  final requests = <Completer<StudentSubmissionUploadFile?>>[];
  final extensions = <List<String>>[];
  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) {
    extensions.add(allowedExtensions);
    final request = Completer<StudentSubmissionUploadFile?>();
    requests.add(request);
    return request.future;
  }
}

class _Repository implements StudentHomeworkAttemptRepository {
  @override
  Future<StudentHomeworkSubmitResult> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  ) => throw StateError(
    'This regression must not submit a Student Homework Attempt.',
  );

  final reads = <Completer<StudentHomeworkAttempt>>[];
  final uploads = <_Upload>[];
  final saves = <Completer<StudentAttemptAnswerMutationResult>>[];
  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) {
    expect(attemptId, _attemptId);
    final request = Completer<StudentHomeworkAttempt>();
    reads.add(request);
    return request.future;
  }

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) {
    final request = _Upload(attemptId, question, file, onProgress);
    uploads.add(request);
    return request.completer.future;
  }

  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) {
    final request = Completer<StudentAttemptAnswerMutationResult>();
    saves.add(request);
    return request.future;
  }

  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) => throw StateError('File answer controller must not start Attempt.');
}

class _Upload {
  _Upload(this.attemptId, this.question, this.file, this.progress);
  final String attemptId;
  final StudentQuestion question;
  final StudentSubmissionUploadFile file;
  final StudentSubmissionUploadProgress? progress;
  final completer = Completer<StudentAttemptAnswerMutationResult>();
  void complete(StudentAttemptAnswerMutationResult result) =>
      completer.complete(result);
  void fail(Object error) => completer.completeError(error);
}

StudentHomeworkAttemptState _data(StudentHomeworkAttempt? attempt) =>
    StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.data,
      attempt: attempt,
      publicationToken: StudentHomeworkAttemptPublicationToken(),
    );
StudentSubmissionUploadFile _selected({
  String name = 'answer.pdf',
  int length = 3,
}) => StudentSubmissionUploadFile(
  name: name,
  length: length,
  openRead: () => Stream.value([1, 2, 3]),
);
StudentQuestion _question({String id = _questionId, int maxSize = 1000}) =>
    StudentQuestion(
      id: id,
      type: StudentQuestionType.fileBased,
      prompt: 'Upload your work',
      instructions: 'Use a document',
      points: 1,
      position: id == _questionId ? 1 : 2,
      answerUi: StudentFileAnswerUi(
        allowedExtensions: ['pdf', 'docx', 'ppt', 'pptx'],
        maxSizeBytes: maxSize,
      ),
    );
StudentQuestion _textQuestion({String id = _textId}) => StudentQuestion(
  id: id,
  type: StudentQuestionType.shortWritten,
  prompt: 'Explain',
  instructions: null,
  points: 1,
  position: 3,
  answerUi: const StudentEmptyAnswerUi(),
);
StudentAttemptAnswerMutationResult _result({
  String fileId = _fileId,
  String name = 'answer.pdf',
  String extension = 'pdf',
  int length = 3,
  String questionId = _questionId,
  DateTime? updatedAt,
}) => StudentAttemptAnswerMutationResult(
  questionId: questionId,
  type: StudentQuestionType.fileBased,
  answer: StudentFileAnswerValue(
    file: StudentSubmissionFile(
      id: fileId,
      originalName: name,
      extension: extension,
      sizeBytes: length,
    ),
  ),
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 1),
);
StudentHomeworkAttempt _attempt({
  String id = _attemptId,
  String homeworkId = _homeworkId,
  bool saved = false,
  bool terminal = false,
  List<StudentQuestion>? questions,
}) => StudentHomeworkAttempt(
  id: id,
  assessmentId: homeworkId,
  attemptNumber: 1,
  status: terminal
      ? StudentHomeworkAttemptStatus.submitted
      : StudentHomeworkAttemptStatus.inProgress,
  startedAt: DateTime.utc(2026, 9, 1),
  submittedAt: terminal ? DateTime.utc(2026, 9, 1, 1) : null,
  finalizedAt: terminal ? DateTime.utc(2026, 9, 1, 1) : null,
  finalizationReason: terminal
      ? StudentHomeworkAttemptFinalizationReason.studentSubmit
      : null,
  deadlineAt: null,
  questions:
      questions ?? [_question(), _question(id: _secondId), _textQuestion()],
  answers: saved
      ? [
          StudentAttemptAnswerState(
            questionId: _questionId,
            type: StudentQuestionType.fileBased,
            value: _result().answer!,
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ]
      : [],
);
