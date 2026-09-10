import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/files/local_file_actions.dart';
import '../../../core/files/protected_learning_material_transfer.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_homework_attempt_route_target.dart';
import '../domain/student_question.dart';
import 'student_attempt_answer_editor_controller.dart';
import 'student_file_answer_controller.dart';
import 'student_file_answer_state.dart';
import 'student_homework_attempt_controller.dart';
import 'student_homework_attempt_state.dart';
import 'student_session_key.dart';
import 'student_submission_transfer_state.dart';

final studentSubmissionTransferControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentSubmissionTransferController,
      StudentSubmissionTransferState,
      StudentHomeworkAttemptRouteTarget
    >(StudentSubmissionTransferController.new);

class StudentSubmissionTransferController
    extends Notifier<StudentSubmissionTransferState> {
  StudentSubmissionTransferController(this.target);

  final StudentHomeworkAttemptRouteTarget target;
  StudentSessionKey? _activeSessionKey;
  _TransferOwner? _owner;
  var _generation = 0;

  @override
  StudentSubmissionTransferState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    ref.watch(studentHomeworkAttemptControllerProvider(target));
    ref.watch(studentAttemptAnswerEditorControllerProvider(target));
    ref.watch(studentFileAnswerControllerProvider(target));
    if (key == null || key != _activeSessionKey) {
      _invalidate();
      _activeSessionKey = key;
      return const StudentSubmissionTransferState();
    }
    final owner = _owner;
    if (owner != null && !_canPublish(owner)) {
      _invalidate();
      return const StudentSubmissionTransferState();
    }
    return state;
  }

  bool canTransfer(String questionId, String fileId) {
    final key = _activeSessionKey;
    return !state.isBusy &&
        key != null &&
        _matchesSession(key) &&
        _currentFile(questionId, fileId) != null;
  }

  Future<void> open(String questionId, String fileId) =>
      _transfer(questionId, fileId, StudentSubmissionTransferAction.open);

  Future<void> saveAs(String questionId, String fileId) =>
      _transfer(questionId, fileId, StudentSubmissionTransferAction.saveAs);

  void consumeFeedback() {
    if (state.feedback != null) state = state.copyWith(feedback: null);
  }

  Future<void> _transfer(
    String questionId,
    String fileId,
    StudentSubmissionTransferAction action,
  ) async {
    if (!canTransfer(questionId, fileId)) return;
    final file = _currentFile(questionId, fileId)!;
    final owner = _TransferOwner(
      key: _activeSessionKey!,
      target: target,
      generation: ++_generation,
      questionId: questionId.toLowerCase(),
      file: file,
    );
    _owner = owner;
    state = StudentSubmissionTransferState(
      status: StudentSubmissionTransferStatus.downloading,
      action: action,
      questionId: owner.questionId,
      fileId: file.id,
    );
    try {
      final downloaded = await ref
          .read(protectedLearningMaterialTransferProvider)
          .download(
            file.id,
            onReceiveProgress: (received, total) {
              if (_canPublish(owner)) {
                state = state.copyWith(
                  receivedBytes: received,
                  totalBytes: total,
                );
              }
            },
          );
      if (!_canPublish(owner)) return;
      final current = _currentFile(owner.questionId, file.id)!;
      if (downloaded.extension != current.extension ||
          downloaded.bytes.length != current.sizeBytes ||
          downloaded.bytes.isEmpty ||
          downloaded.bytes.length > _maximumSubmissionBytes) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'The server returned an unexpected file response.',
          ),
        );
      }
      final local = ref.read(localFileActionsProvider);
      switch (action) {
        case StudentSubmissionTransferAction.open:
          state = state.copyWith(
            status: StudentSubmissionTransferStatus.opening,
          );
          final outcome = await local.open(file.id, downloaded);
          if (!_canPublish(owner)) return;
          _finish(
            owner,
            failure: outcome == LocalFileOpenOutcome.noApplication,
            feedback: outcome == LocalFileOpenOutcome.noApplication
                ? 'No application is available to open this file. Save the file instead.'
                : null,
          );
        case StudentSubmissionTransferAction.saveAs:
          state = state.copyWith(
            status: StudentSubmissionTransferStatus.saving,
          );
          final saved = await local.saveAs(
            downloaded,
            dialogTitle: 'Save submitted answer',
          );
          if (!_canPublish(owner)) return;
          _finish(owner, feedback: saved ? 'Submitted file saved.' : null);
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(owner) || _clearForSessionFailure(exception.failure)) {
        return;
      }
      final failure = exception.failure;
      if (failure.statusCode == 404 &&
          failure.serverCode == ApiErrorCodes.resourceNotFound) {
        // Refresh may immediately revoke file authority; preserve only route-safe
        // unavailable feedback, never permit a local action from this response.
        ref
            .read(studentHomeworkAttemptControllerProvider(target).notifier)
            .refresh();
        if (!_ownsRoute(owner)) return;
      }
      _finish(owner, failure: true, feedback: _failureMessage(failure));
    } on PlatformException {
      _publishLocalFailure(owner);
    } on FileSystemException {
      _publishLocalFailure(owner);
    }
  }

  void _publishLocalFailure(_TransferOwner owner) {
    if (_canPublish(owner)) {
      _finish(
        owner,
        failure: true,
        feedback: 'The submitted file could not be opened or saved.',
      );
    }
  }

  StudentHomeworkAttempt? _authoritativeAttempt() {
    final parent = ref.read(studentHomeworkAttemptControllerProvider(target));
    if (parent.status == StudentHomeworkAttemptLoadStatus.notFound) return null;
    final terminal = ref
        .read(studentAttemptAnswerEditorControllerProvider(target))
        .terminalAttempt;
    if (terminal != null &&
        terminal.status != StudentHomeworkAttemptStatus.inProgress &&
        _matchesAttempt(terminal)) {
      return terminal;
    }
    final attempt = parent.attempt;
    return parent.status == StudentHomeworkAttemptLoadStatus.data &&
            attempt != null &&
            _matchesAttempt(attempt)
        ? attempt
        : null;
  }

  StudentSubmissionFile? _currentFile(String questionId, String fileId) {
    if (!isCanonicalStudentAttemptId(questionId) ||
        !isCanonicalStudentAttemptId(fileId)) {
      return null;
    }
    final attempt = _authoritativeAttempt();
    if (attempt == null) return null;
    final id = questionId.toLowerCase();
    final status = ref
        .read(studentFileAnswerControllerProvider(target))
        .questions[id]
        ?.status;
    if (status == StudentFileAnswerStatus.uploading ||
        status == StudentFileAnswerStatus.uncertain) {
      return null;
    }
    final questions = attempt.questions.where(
      (question) => question.id.toLowerCase() == id,
    );
    if (questions.length != 1 ||
        questions.single.type != StudentQuestionType.fileBased) {
      return null;
    }
    final answers = attempt.answers.where(
      (answer) => answer.questionId.toLowerCase() == id,
    );
    if (answers.length != 1 ||
        answers.single.type != StudentQuestionType.fileBased) {
      return null;
    }
    final answer = answers.single.value;
    if (answer is! StudentFileAnswerValue ||
        !isCanonicalStudentAttemptId(answer.file.id) ||
        answer.file.id.toLowerCase() != fileId.toLowerCase()) {
      return null;
    }
    return answer.file;
  }

  bool _matchesAttempt(StudentHomeworkAttempt attempt) =>
      isCanonicalStudentAttemptId(attempt.id) &&
      isCanonicalStudentAttemptId(target.attemptId) &&
      isCanonicalStudentHomeworkId(attempt.assessmentId) &&
      isCanonicalStudentHomeworkId(target.homeworkId) &&
      attempt.id.toLowerCase() == target.attemptId.toLowerCase() &&
      attempt.assessmentId.toLowerCase() == target.homeworkId.toLowerCase();

  bool _canPublish(_TransferOwner owner) {
    if (!_ownsRoute(owner)) return false;
    final current = _currentFile(owner.questionId, owner.file.id);
    return current != null &&
        current.originalName == owner.file.originalName &&
        current.extension == owner.file.extension &&
        current.sizeBytes == owner.file.sizeBytes;
  }

  bool _ownsRoute(_TransferOwner owner) =>
      ref.mounted &&
      identical(_owner, owner) &&
      owner.generation == _generation &&
      owner.target == target &&
      _matchesSession(owner.key);

  bool _matchesSession(StudentSessionKey key) =>
      ref.mounted &&
      _activeSessionKey == key &&
      StudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          key;

  void _finish(_TransferOwner owner, {bool failure = false, String? feedback}) {
    _owner = null;
    state = StudentSubmissionTransferState(
      status: failure
          ? StudentSubmissionTransferStatus.failure
          : StudentSubmissionTransferStatus.idle,
      questionId: owner.questionId,
      fileId: owner.file.id,
      feedback: feedback,
    );
  }

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _invalidate();
    _activeSessionKey = null;
    state = const StudentSubmissionTransferState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _invalidate() {
    _generation += 1;
    _owner = null;
  }
}

String _failureMessage(ApiFailure failure) => switch (failure.serverCode) {
  ApiErrorCodes.resourceNotFound =>
    'This submitted file is no longer available.',
  ApiErrorCodes.fileNotAvailable =>
    'The file is temporarily unavailable. Try again.',
  _ when failure.kind == ApiFailureKind.invalidResponse =>
    'The server returned an unexpected file response.',
  _ when failure.kind == ApiFailureKind.timeout =>
    'The download timed out. Try again.',
  _ when failure.kind == ApiFailureKind.connection =>
    'The download could not connect. Try again.',
  _ => 'The submitted file could not be downloaded.',
};

class _TransferOwner {
  const _TransferOwner({
    required this.key,
    required this.target,
    required this.generation,
    required this.questionId,
    required this.file,
  });

  final StudentSessionKey key;
  final StudentHomeworkAttemptRouteTarget target;
  final int generation;
  final String questionId;
  final StudentSubmissionFile file;
}

const _maximumSubmissionBytes = 15728640;
