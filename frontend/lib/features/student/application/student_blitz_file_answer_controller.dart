import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_attempt_answer_repository_impl.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_attempt_answer.dart';
import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_execution_target.dart';
import '../domain/student_question.dart';
import '../domain/student_submission_upload.dart';
import 'student_answer_autosave.dart';
import 'student_attempt_publication_token.dart';
import 'student_blitz_execution_controller.dart';
import 'student_blitz_execution_operation_gate.dart';
import 'student_blitz_execution_state.dart';
import 'student_file_answer_state.dart';
import 'student_session_key.dart';
import 'student_submission_file_picker.dart';

final studentBlitzFileAnswerControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentBlitzFileAnswerController,
      StudentFileAnswerState,
      StudentBlitzExecutionTarget
    >(StudentBlitzFileAnswerController.new);

/// File answer choose/upload/replace for one Blitz execution Attempt, using
/// the shared Stage 7 picker, local checks and answer transport.
class StudentBlitzFileAnswerController
    extends Notifier<StudentFileAnswerState> {
  StudentBlitzFileAnswerController(this.target);

  final StudentBlitzExecutionTarget target;
  StudentSessionKey? _activeSessionKey;
  StudentAttemptPublicationToken? _lastPublication;
  _FileOperation? _operation;

  /// A strict upload `200` that could not be adopted because another write
  /// published first; the re-read decides whether it is still current.
  (_FileOperation, StudentAttemptAnswerMutationResult)? _confirmedUpload;
  StudentAnswerAutosave? _recovery;
  final _uploadWaiters = <Completer<bool>>[];

  /// A chosen file whose upload waited for the write gate (a replay).
  String? _deferredUpload;
  var _generation = 0;
  var _cleared = false;

  @override
  StudentFileAnswerState build() {
    final buildRef = ref;
    // Only a real disposal (not a rebuild) stops the recovery timer.
    buildRef.onDispose(() {
      if (!buildRef.mounted) {
        _recovery?.clear();
        _resolveUploadWaiters(false);
      }
    });
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final parent = ref.watch(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    ref.watch(studentBlitzExecutionOperationGateProvider(target));
    if (key == null) {
      _invalidateOwnership();
      return StudentFileAnswerState();
    }
    final resetScope = key != _activeSessionKey || ref.isRefresh;
    if (resetScope) {
      _invalidateOwnership();
      _activeSessionKey = key;
      _cleared = false;
    }
    final attempt = parent.attempt;
    if (_cleared || attempt == null || !_matchesAttempt(attempt)) {
      _lastPublication = null;
      return StudentFileAnswerState();
    }
    final previous = resetScope ? StudentFileAnswerState() : state;
    if (parent.localTimeExpired) {
      _recovery?.clear();
      _deferredUpload = null;
    }
    final publication = parent.publicationToken;
    final StudentFileAnswerState next;
    if (publication != null && !identical(publication, _lastPublication)) {
      _lastPublication = publication;
      next = _synchronize(previous, parent);
    } else {
      next = _copyState(previous, isAuthoritative: _hasAuthority(parent));
    }
    final deferred = _deferredUpload;
    if (deferred != null && parent.acceptsWrites) {
      _deferredUpload = null;
      scheduleMicrotask(() {
        if (ref.mounted) unawaited(uploadAnswer(deferred));
      });
    }
    return next;
  }

  Future<void> chooseFile(String questionId) async {
    if (!_gateIsIdle) return;
    final id = questionId.toLowerCase();
    final question = _currentQuestion(id);
    if (question == null || !state.canChoose(id)) return;
    final previous = state.questions[id]!;
    final operation = _begin(
      id,
      previous.selectedFile,
      previous.serverFile?.id,
    );
    final generation = _generation;
    _replace(
      id,
      _entry(
        previous,
        status: StudentFileAnswerStatus.selecting,
        failure: previous.failure,
      ),
    );
    try {
      final selected = await ref
          .read(studentSubmissionFilePickerProvider)
          .pickFile(
            allowedExtensions:
                (question.answerUi as StudentFileAnswerUi).allowedExtensions,
          );
      if (!_canPublish(operation, generation)) return;
      final current = state.questions[id]!;
      if (selected == null) {
        _finish(
          id,
          StudentFileQuestionAnswerState(
            question: current.question,
            serverFile: current.serverFile,
            selectedFile: previous.selectedFile,
            status: previous.status,
            failure: previous.failure,
            selectionError: current.selectionError,
            localFailure: previous.localFailure,
            rejectedFileName: previous.rejectedFileName,
          ),
        );
        return;
      }
      final error = validateStudentSubmissionSelection(
        selected,
        current.question.answerUi as StudentFileAnswerUi,
      );
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: current.question,
          serverFile: current.serverFile,
          selectedFile: error == null ? selected : previous.selectedFile,
          status: error == null
              ? StudentFileAnswerStatus.ready
              : previous.status,
          failure: error == null ? null : previous.failure,
          selectionError: error,
          rejectedFileName: error == null ? null : previous.rejectedFileName,
        ),
      );
      // A chosen file is saved at once; there is no separate Upload step.
      if (error == null) _uploadWhenWritable(id);
    } catch (_) {
      // Only the platform picker can fail here; no server state is involved.
      if (!_canPublish(operation, generation)) return;
      final current = state.questions[id]!;
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: current.question,
          serverFile: current.serverFile,
          selectedFile: previous.selectedFile,
          status: previous.selectedFile == null
              ? StudentFileAnswerStatus.failure
              : previous.status,
          failure: previous.failure,
          localFailure: StudentFileAnswerLocalFailure.pickerUnavailable,
          rejectedFileName: previous.rejectedFileName,
        ),
      );
    }
  }

  void discardSelectedFile(String questionId) {
    if (!_gateIsIdle) return;
    final id = questionId.toLowerCase();
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key) || !state.canDiscard(id)) return;
    final previous = state.questions[id]!;
    _replace(
      id,
      StudentFileQuestionAnswerState(
        question: previous.question,
        serverFile: previous.serverFile,
      ),
    );
  }

  /// Uploads the selected file once; an unconfirmed upload is checked, never
  /// resent on its own.
  Future<void> uploadAnswer(String questionId) async {
    if (!_gateIsIdle) return;
    final id = questionId.toLowerCase();
    final question = _currentQuestion(id);
    if (question == null || !state.canChoose(id)) return;
    final previous = state.questions[id]!;
    final selected = previous.selectedFile;
    if (selected == null ||
        previous.failure?.serverCode == ApiErrorCodes.validationFailed) {
      return;
    }
    final error = validateStudentSubmissionSelection(
      selected,
      question.answerUi as StudentFileAnswerUi,
    );
    if (error != null) {
      _replace(
        id,
        StudentFileQuestionAnswerState(
          question: question,
          serverFile: previous.serverFile,
          selectedFile: selected,
          status: StudentFileAnswerStatus.ready,
          selectionError: error,
        ),
      );
      return;
    }
    final execution = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget).notifier,
    );
    final write = execution.beginWrite();
    if (write == null) {
      // A replay is pending; the upload starts once it republishes.
      _deferredUpload = id;
      return;
    }
    final operation = _begin(id, selected, previous.serverFile?.id);
    final generation = _generation;
    _replace(
      id,
      StudentFileQuestionAnswerState(
        question: question,
        serverFile: previous.serverFile,
        selectedFile: selected,
        status: StudentFileAnswerStatus.uploading,
      ),
    );
    try {
      final result = await ref
          .read(studentAttemptAnswerRepositoryProvider)
          .uploadFileAnswer(
            target.attemptId,
            question,
            selected,
            onProgress: (sent, total) {
              if (!_canPublish(operation, generation) ||
                  state.questions[id]!.status !=
                      StudentFileAnswerStatus.uploading) {
                return;
              }
              _replace(
                id,
                _entry(
                  state.questions[id]!,
                  status: StudentFileAnswerStatus.uploading,
                  sentBytes: sent,
                  totalBytes: total,
                ),
              );
            },
          );
      if (!_canPublish(operation, generation)) return;
      if (!_validResult(result, question, operation)) {
        throw _invalidResponse();
      }
      final accepted = execution.acceptAnswerMutation(
        attemptId: target.attemptId,
        questionId: id,
        result: result,
        expectedReadToken: operation.readToken,
      );
      if (!accepted) {
        // A replay adopted the Attempt meanwhile; only a check may show the
        // result.
        _confirmedUpload = (operation, result);
        _replace(
          id,
          _entry(
            state.questions[id]!,
            status: StudentFileAnswerStatus.uncertain,
            failure: _invalidResponse().failure,
          ),
        );
        _resolveUploadWaiters(false);
        unawaited(checkCurrentAttempt());
        return;
      }
      _recovery?.resetRecovery();
      _adoptUploaded(id, (result.answer! as StudentFileAnswerValue).file);
    } on StudentSubmissionSourceUnavailable {
      // A local read failure says nothing about the server; nothing is retried.
      if (!_canPublish(operation, generation)) return;
      final current = state.questions[id]!;
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: current.question,
          serverFile: current.serverFile,
          status: StudentFileAnswerStatus.failure,
          localFailure: StudentFileAnswerLocalFailure.sourceUnavailable,
        ),
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation, generation) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      final failure = exception.failure;
      final current = state.questions[id]!;
      if (_isUncertain(failure)) {
        _replace(
          id,
          _entry(
            current,
            status: StudentFileAnswerStatus.uncertain,
            failure: failure,
          ),
        );
        _recoveryTimer.scheduleRecovery(_recover);
        _resolveUploadWaiters(false);
        return;
      }
      // A rejected file is dropped so it never blocks Submit; the saved server
      // file stays and the Student can choose another one.
      final rejected = _rejectedFileCodes.contains(failure.serverCode);
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: current.question,
          serverFile: current.serverFile,
          status: StudentFileAnswerStatus.failure,
          failure: failure,
          rejectedFileName: rejected ? selected.name : null,
        ),
      );
      if (_reconciledCodes.contains(failure.serverCode)) {
        unawaited(execution.reconcileAfterRejectedWrite(failure));
      }
    } catch (_) {
      // The upload may have committed; only a check can show its outcome.
      if (_canPublish(operation, generation)) {
        _replace(
          id,
          _entry(
            state.questions[id]!,
            status: StudentFileAnswerStatus.uncertain,
            failure: ApiFailure.local(
              kind: ApiFailureKind.unknown,
              message: 'Unexpected file answer failure.',
            ),
          ),
        );
        _recoveryTimer.scheduleRecovery(_recover);
        _resolveUploadWaiters(false);
      }
    } finally {
      execution.endWrite(write);
    }
  }

  /// Re-reads the current Attempt by replaying the completed Start request.
  /// Matching metadata cannot prove the selected bytes committed, so the
  /// selection stays a ready candidate next to the server's current file.
  Future<void> checkCurrentAttempt() async {
    if (!_gateIsIdle) return;
    final operation = _operation;
    if (operation == null ||
        !state.hasUncertainUpload ||
        state.isReconciling ||
        !_canPublish(operation, _generation)) {
      return;
    }
    final generation = ++_generation;
    state = _copyState(state, isReconciling: true);
    final outcome = await ref
        .read(
          studentBlitzExecutionControllerProvider(target.routeTarget).notifier,
        )
        .refreshCurrentAttempt();
    // A terminal or dropped execution already retired this operation.
    if (!_canPublish(operation, generation)) return;
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    final attempt = parent.attempt;
    final question = attempt == null
        ? null
        : _questionFor(attempt, operation.questionId);
    if (outcome != StudentBlitzAttemptReplayOutcome.active ||
        attempt == null ||
        attempt.status != StudentBlitzAttemptStatus.inProgress ||
        question == null) {
      state = _copyState(state, isReconciling: false);
      if (state.hasUncertainUpload && !state.isTerminal) {
        _recoveryTimer.scheduleRecovery(_recover);
      }
      return;
    }
    _recovery?.resetRecovery();
    final selected = operation.selectedFile!;
    final error = validateStudentSubmissionSelection(
      selected,
      question.answerUi as StudentFileAnswerUi,
    );
    final serverFile = _fileFor(attempt, operation.questionId);
    final confirmed = _isConfirmedUploadCurrent(operation, attempt);
    _operation = null;
    _confirmedUpload = null;
    _lastPublication = parent.publicationToken;
    state = _synchronize(
      StudentFileAnswerState(
        questions: {
          ...state.questions,
          operation.questionId: confirmed
              ? StudentFileQuestionAnswerState(
                  question: question,
                  serverFile: serverFile,
                  status: StudentFileAnswerStatus.uploaded,
                )
              : StudentFileQuestionAnswerState(
                  question: question,
                  serverFile: serverFile,
                  selectedFile: error == null ? selected : null,
                  status: error == null
                      ? StudentFileAnswerStatus.ready
                      : StudentFileAnswerStatus.failure,
                  selectionError: error,
                ),
        },
      ),
      parent,
    );
  }

  /// Only a strict `200` for this operation can prove its bytes committed;
  /// it still counts only while the re-read server file is exactly that one.
  bool _isConfirmedUploadCurrent(
    _FileOperation operation,
    StudentBlitzAttempt attempt,
  ) {
    final confirmed = _confirmedUpload;
    final confirmedAnswer = confirmed?.$2.answer;
    if (confirmed == null ||
        !identical(confirmed.$1, operation) ||
        confirmedAnswer is! StudentFileAnswerValue) {
      return false;
    }
    for (final answer in attempt.answers) {
      final value = answer.value;
      if (answer.questionId.toLowerCase() != operation.questionId ||
          value is! StudentFileAnswerValue) {
        continue;
      }
      final file = value.file;
      final expected = confirmedAnswer.file;
      return file.id.toLowerCase() == expected.id.toLowerCase() &&
          file.originalName == expected.originalName &&
          file.extension == expected.extension &&
          file.sizeBytes == expected.sizeBytes &&
          answer.updatedAt.isAtSameMomentAs(confirmed.$2.updatedAt!);
    }
    return false;
  }

  /// Completes once no pick or upload of this Attempt runs: `true` when no
  /// chosen file is left unsaved, `false` otherwise or after
  /// [cancelUploadWait].
  Future<bool> waitForUploads() {
    if (_operation == null || state.hasUncertainUpload) {
      return Future.value(_uploadsSettled);
    }
    final waiter = Completer<bool>();
    _uploadWaiters.add(waiter);
    return waiter.future;
  }

  void cancelUploadWait() => _resolveUploadWaiters(false);

  /// Uploads a just-chosen file now, or once a pending replay republishes a
  /// writable Attempt. Nothing is uploaded after local zero.
  void _uploadWhenWritable(String id) {
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    if (parent.acceptsWrites) {
      unawaited(uploadAnswer(id));
    } else if (!parent.localTimeExpired && parent.isExecuting) {
      _deferredUpload = id;
    }
  }

  bool get _uploadsSettled =>
      !state.hasUncertainUpload && !state.hasPendingSelection;

  void _resolveUploadWaiters([bool? saved]) {
    if (_uploadWaiters.isEmpty) return;
    final result = saved ?? _uploadsSettled;
    final waiters = [..._uploadWaiters];
    _uploadWaiters.clear();
    for (final waiter in waiters) {
      waiter.complete(result);
    }
  }

  static const _rejectedFileCodes = {
    ApiErrorCodes.validationFailed,
    ApiErrorCodes.unsupportedFileType,
    ApiErrorCodes.fileTooLarge,
    ApiErrorCodes.fileUploadFailed,
  };

  StudentAnswerAutosave get _recoveryTimer =>
      _recovery ??= StudentAnswerAutosave(
        ref.read(studentAutosaveTimerFactoryProvider),
        () {},
      );

  void _recover() {
    if (!ref.mounted || !state.hasUncertainUpload || state.isTerminal) return;
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    if (parent.localTimeExpired) return;
    if (!_gateIsIdle || state.isReconciling) {
      _recoveryTimer.scheduleRecovery(_recover);
      return;
    }
    unawaited(checkCurrentAttempt());
  }

  /// Leaving discards the selected local file; nothing is sent.
  void clearLocalState() {
    final session = _activeSessionKey;
    _invalidateOwnership();
    _activeSessionKey = session;
    _cleared = true;
    state = StudentFileAnswerState();
  }

  void _adoptUploaded(String id, StudentSubmissionFile file) {
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    final current = state.questions[id]!;
    _operation = null;
    _lastPublication = parent.publicationToken;
    _adoptUploadedState(id, current, file, parent);
    _resolveUploadWaiters();
  }

  void _adoptUploadedState(
    String id,
    StudentFileQuestionAnswerState current,
    StudentSubmissionFile file,
    StudentBlitzExecutionState parent,
  ) {
    state = _synchronize(
      StudentFileAnswerState(
        questions: {
          ...state.questions,
          id: StudentFileQuestionAnswerState(
            question: current.question,
            serverFile: file,
            status: StudentFileAnswerStatus.uploaded,
          ),
        },
      ),
      parent,
    );
  }

  StudentFileAnswerState _synchronize(
    StudentFileAnswerState previous,
    StudentBlitzExecutionState parent,
  ) {
    final attempt = parent.attempt!;
    final terminal = attempt.status != StudentBlitzAttemptStatus.inProgress;
    if (previous.isTerminal && !terminal) return previous;
    if (terminal) {
      _generation += 1;
      _operation = null;
      _deferredUpload = null;
      _recovery?.clear();
      _resolveUploadWaiters(false);
    }
    final questions = <String, StudentFileQuestionAnswerState>{};
    var preservedUncertainty = false;
    for (final question in attempt.questions.where(_isFileQuestion)) {
      final id = question.id.toLowerCase();
      final old = previous.questions[id];
      if (!terminal && old?.status == StudentFileAnswerStatus.uncertain) {
        questions[id] = old!;
        preservedUncertainty = true;
        continue;
      }
      final selected = terminal ? null : old?.selectedFile;
      final error = selected == null
          ? null
          : validateStudentSubmissionSelection(
              selected,
              question.answerUi as StudentFileAnswerUi,
            );
      questions[id] = StudentFileQuestionAnswerState(
        question: question,
        serverFile: _fileFor(attempt, id),
        selectedFile: selected,
        status: terminal
            ? StudentFileAnswerStatus.idle
            : old?.status ?? StudentFileAnswerStatus.idle,
        sentBytes: terminal ? 0 : old?.sentBytes ?? 0,
        totalBytes: terminal ? 0 : old?.totalBytes ?? 0,
        selectionError: terminal
            ? null
            : selected == null
            ? old?.selectionError
            : error,
        failure: terminal ? null : old?.failure,
        localFailure: terminal ? null : old?.localFailure,
        rejectedFileName: terminal ? null : old?.rejectedFileName,
      );
    }
    return StudentFileAnswerState(
      questions: questions,
      isAuthoritative: _hasAuthority(parent),
      isTerminal: terminal,
      activeQuestionId: _operation?.questionId,
      isReconciling: !terminal && _operation != null && previous.isReconciling,
      sourceAttemptPublication: preservedUncertainty
          ? null
          : parent.publicationToken,
    );
  }

  StudentSubmissionFile? _fileFor(StudentBlitzAttempt attempt, String id) {
    for (final answer in attempt.answers) {
      if (answer.questionId.toLowerCase() == id &&
          answer.type == StudentQuestionType.fileBased &&
          answer.value is StudentFileAnswerValue) {
        return (answer.value as StudentFileAnswerValue).file;
      }
    }
    return null;
  }

  bool _isFileQuestion(StudentQuestion question) =>
      question.type == StudentQuestionType.fileBased &&
      question.answerUi is StudentFileAnswerUi;

  bool _matchesAttempt(StudentBlitzAttempt attempt) =>
      attempt.id.toLowerCase() == target.attemptId &&
      attempt.assessmentId.toLowerCase() == target.routeTarget.blitzId;

  bool _hasAuthority(StudentBlitzExecutionState parent) =>
      !_cleared &&
      parent.acceptsWrites &&
      parent.attempt != null &&
      _matchesAttempt(parent.attempt!);

  bool get _gateIsIdle =>
      ref.read(studentBlitzExecutionOperationGateProvider(target)) ==
      StudentBlitzExecutionOperation.idle;

  StudentQuestion? _currentQuestion(String id) {
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key) || state.isTerminal) return null;
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    return _hasAuthority(parent) ? _questionFor(parent.attempt!, id) : null;
  }

  StudentQuestion? _questionFor(StudentBlitzAttempt attempt, String id) {
    final matches = attempt.questions.where(
      (question) => question.id.toLowerCase() == id,
    );
    return matches.length == 1 && _isFileQuestion(matches.single)
        ? matches.single
        : null;
  }

  _FileOperation _begin(
    String id,
    StudentSubmissionUploadFile? selected,
    String? previousFileId,
  ) {
    final operation = _FileOperation(
      _activeSessionKey!,
      id,
      selected,
      previousFileId,
      state.sourceAttemptPublication,
      ref
          .read(studentBlitzExecutionControllerProvider(target.routeTarget))
          .readToken,
    );
    _operation = operation;
    _generation += 1;
    state = _copyState(state, activeQuestionId: id);
    return operation;
  }

  bool _canPublish(_FileOperation operation, int generation) =>
      ref.mounted &&
      _matchesSession(operation.session) &&
      generation == _generation &&
      identical(_operation, operation) &&
      !state.isTerminal &&
      state.activeQuestionId == operation.questionId &&
      state.questions.containsKey(operation.questionId) &&
      identical(
        state.questions[operation.questionId]!.selectedFile,
        operation.selectedFile,
      );

  bool _matchesSession(StudentSessionKey key) =>
      ref.mounted &&
      !_cleared &&
      _activeSessionKey == key &&
      StudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          key;

  bool _validResult(
    StudentAttemptAnswerMutationResult result,
    StudentQuestion question,
    _FileOperation operation,
  ) {
    final answer = result.answer;
    final selected = operation.selectedFile!;
    if (result.questionId.toLowerCase() != operation.questionId ||
        result.type != StudentQuestionType.fileBased ||
        answer is! StudentFileAnswerValue ||
        result.updatedAt == null) {
      return false;
    }
    final file = answer.file;
    final policy = question.answerUi as StudentFileAnswerUi;
    return file.sizeBytes > 0 &&
        policy.allowedExtensions.contains(file.extension) &&
        file.sizeBytes <= policy.maxSizeBytes &&
        file.originalName == selected.name &&
        file.extension == selected.extension &&
        file.sizeBytes == selected.length &&
        // A replacement keeps the current file identity.
        (operation.previousServerFileId == null ||
            file.id.toLowerCase() ==
                operation.previousServerFileId!.toLowerCase());
  }

  bool _isUncertain(ApiFailure failure) {
    if (failure.serverCode == ApiErrorCodes.fileUploadFailed &&
        failure.statusCode == 500) {
      return false;
    }
    return switch (failure.kind) {
      ApiFailureKind.connection ||
      ApiFailureKind.timeout ||
      ApiFailureKind.cancelled ||
      ApiFailureKind.invalidResponse ||
      ApiFailureKind.unknown => true,
      ApiFailureKind.server || ApiFailureKind.validation =>
        failure.statusCode == null || failure.statusCode! >= 500,
    };
  }

  /// Rejections that may mean the Attempt or its effective file policy changed.
  static const _reconciledCodes = {
    ApiErrorCodes.blitzTimeExpired,
    ApiErrorCodes.blitzNotActive,
    ApiErrorCodes.attemptNotEditable,
    ApiErrorCodes.resourceNotFound,
    ApiErrorCodes.businessConflict,
    ApiErrorCodes.fileTooLarge,
  };

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    clearLocalState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _invalidateOwnership() {
    _generation += 1;
    _activeSessionKey = null;
    _operation = null;
    _confirmedUpload = null;
    _lastPublication = null;
    _deferredUpload = null;
    _recovery?.clear();
    _resolveUploadWaiters(false);
  }

  ApiRequestException _invalidResponse() => ApiRequestException(
    ApiFailure.local(
      kind: ApiFailureKind.invalidResponse,
      message: 'The file answer response could not be confirmed.',
    ),
  );

  StudentFileQuestionAnswerState _entry(
    StudentFileQuestionAnswerState previous, {
    required StudentFileAnswerStatus status,
    int sentBytes = 0,
    int totalBytes = 0,
    ApiFailure? failure,
  }) => StudentFileQuestionAnswerState(
    question: previous.question,
    serverFile: previous.serverFile,
    selectedFile: previous.selectedFile,
    status: status,
    sentBytes: sentBytes,
    totalBytes: totalBytes,
    failure: failure,
    rejectedFileName: previous.rejectedFileName,
  );

  void _replace(String id, StudentFileQuestionAnswerState entry) =>
      state = _copyState(state, questions: {...state.questions, id: entry});

  void _finish(String id, StudentFileQuestionAnswerState entry) {
    _operation = null;
    state = StudentFileAnswerState(
      questions: {...state.questions, id: entry},
      isAuthoritative: state.isAuthoritative,
      isTerminal: state.isTerminal,
      sourceAttemptPublication: state.sourceAttemptPublication,
    );
    _resolveUploadWaiters();
  }

  StudentFileAnswerState _copyState(
    StudentFileAnswerState previous, {
    Map<String, StudentFileQuestionAnswerState>? questions,
    bool? isAuthoritative,
    String? activeQuestionId,
    bool? isReconciling,
  }) => StudentFileAnswerState(
    questions: questions ?? previous.questions,
    isAuthoritative: isAuthoritative ?? previous.isAuthoritative,
    isTerminal: previous.isTerminal,
    activeQuestionId: activeQuestionId ?? previous.activeQuestionId,
    isReconciling: isReconciling ?? previous.isReconciling,
    sourceAttemptPublication: previous.sourceAttemptPublication,
  );
}

class _FileOperation {
  const _FileOperation(
    this.session,
    this.questionId,
    this.selectedFile,
    this.previousServerFileId,
    this.sourcePublication,
    this.readToken,
  );
  final StudentSessionKey session;
  final String questionId;
  final StudentSubmissionUploadFile? selectedFile;
  final String? previousServerFileId;
  final StudentAttemptPublicationToken? sourcePublication;

  /// The execution read this operation started from; a text save patching the
  /// Attempt meanwhile does not reject this upload's own patch.
  final StudentAttemptPublicationToken? readToken;
}
