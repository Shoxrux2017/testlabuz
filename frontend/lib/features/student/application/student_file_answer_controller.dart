import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_homework_attempt_repository_impl.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_homework_attempt_route_target.dart';
import '../domain/student_homework_route_target.dart';
import '../domain/student_question.dart';
import '../domain/student_submission_upload.dart';
import 'student_attempt_answer_editor_controller.dart';
import 'student_file_answer_state.dart';
import 'student_homework_attempt_controller.dart';
import 'student_homework_attempt_state.dart';
import 'student_homework_detail_controller.dart';
import 'student_session_key.dart';
import 'student_submission_file_picker.dart';

final studentFileAnswerControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentFileAnswerController,
      StudentFileAnswerState,
      StudentHomeworkAttemptRouteTarget
    >(StudentFileAnswerController.new);

class StudentFileAnswerController extends Notifier<StudentFileAnswerState> {
  StudentFileAnswerController(this.target);

  final StudentHomeworkAttemptRouteTarget target;
  StudentSessionKey? _activeSessionKey;
  StudentHomeworkAttemptState? _lastParent;
  StudentHomeworkAttempt? _lastTerminal;
  _FileOperation? _operation;
  var _generation = 0;
  var _cleared = false;

  @override
  StudentFileAnswerState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final parent = ref.watch(studentHomeworkAttemptControllerProvider(target));
    final terminal = ref.watch(
      studentAttemptAnswerEditorControllerProvider(
        target,
      ).select((editor) => editor.terminalAttempt),
    );
    if (key == null) {
      _invalidateOwnership();
      return StudentFileAnswerState();
    }
    final changedSession = key != _activeSessionKey;
    if (changedSession) {
      _invalidateOwnership();
      _activeSessionKey = key;
      _cleared = false;
    }
    if (_cleared) return StudentFileAnswerState();
    final previous = changedSession ? StudentFileAnswerState() : state;
    if (terminal != null &&
        _matchesAttempt(terminal) &&
        terminal.status != StudentHomeworkAttemptStatus.inProgress) {
      final changed = !identical(terminal, _lastTerminal);
      _lastTerminal = terminal;
      return changed ? _synchronize(previous, terminal) : previous;
    }
    final changedParent = !identical(parent, _lastParent);
    _lastParent = parent;
    if (changedParent &&
        parent.status == StudentHomeworkAttemptLoadStatus.data &&
        parent.attempt != null &&
        _matchesAttempt(parent.attempt!)) {
      return _synchronize(previous, parent.attempt!);
    }
    return _copyState(previous, isAuthoritative: _hasAuthority(parent));
  }

  Future<void> chooseFile(String questionId) async {
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
    _replace(id, _entry(previous, status: StudentFileAnswerStatus.selecting));
    try {
      final selected = await ref
          .read(studentSubmissionFilePickerProvider)
          .pickFile(
            allowedExtensions:
                (question.answerUi as StudentFileAnswerUi).allowedExtensions,
          );
      if (!_canPublish(operation, generation)) return;
      if (selected == null) {
        final current = state.questions[id]!;
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
          ),
        );
        return;
      }
      final current = _currentQuestion(id);
      if (current == null) {
        _finish(id, _entry(state.questions[id]!, status: previous.status));
        return;
      }
      final error = validateStudentSubmissionSelection(
        selected,
        current.answerUi as StudentFileAnswerUi,
      );
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: current,
          serverFile: state.questions[id]!.serverFile,
          selectedFile: error == null ? selected : previous.selectedFile,
          status: error == null
              ? StudentFileAnswerStatus.ready
              : previous.status,
          selectionError: error,
        ),
      );
    } catch (_) {
      if (!_canPublish(operation, generation)) return;
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: state.questions[id]!.question,
          serverFile: state.questions[id]!.serverFile,
          selectedFile: previous.selectedFile,
          status: previous.selectedFile == null
              ? StudentFileAnswerStatus.failure
              : StudentFileAnswerStatus.ready,
          localFailure: StudentFileAnswerLocalFailure.pickerUnavailable,
        ),
      );
    }
  }

  void discardSelectedFile(String questionId) {
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

  Future<void> uploadAnswer(String questionId) async {
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
          .read(studentHomeworkAttemptRepositoryProvider)
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
      final current = _responseQuestion(id);
      if (current == null || !_validResult(result, current, operation)) {
        throw _invalidResponse();
      }
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: current,
          serverFile: (result.answer as StudentFileAnswerValue).file,
          status: StudentFileAnswerStatus.uploaded,
        ),
      );
      _refreshAttempt();
    } on StudentSubmissionSourceUnavailable {
      if (!_canPublish(operation, generation)) return;
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: state.questions[id]!.question,
          serverFile: state.questions[id]!.serverFile,
          status: StudentFileAnswerStatus.failure,
          localFailure: StudentFileAnswerLocalFailure.sourceUnavailable,
        ),
      );
      _refreshAttempt();
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation, generation) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      final failure = exception.failure;
      final entry = state.questions[id]!;
      if (_isUncertain(failure)) {
        _replace(
          id,
          _entry(
            entry,
            status: StudentFileAnswerStatus.uncertain,
            failure: failure,
          ),
        );
        return;
      }
      if (failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _generation += 1;
        _operation = null;
        state = StudentFileAnswerState();
        _refreshAttempt();
        return;
      }
      final retainSelection =
          failure.serverCode == ApiErrorCodes.fileUploadFailed ||
          failure.serverCode == ApiErrorCodes.validationFailed;
      _finish(
        id,
        StudentFileQuestionAnswerState(
          question: entry.question,
          serverFile: entry.serverFile,
          selectedFile: retainSelection ? selected : null,
          status: StudentFileAnswerStatus.failure,
          failure: failure,
        ),
      );
      _reconcileFailure(failure);
    }
  }

  Future<void> reloadAttempt() async {
    final operation = _operation;
    if (operation == null ||
        !state.hasUncertainUpload ||
        state.isReconciling ||
        !_canPublish(operation, _generation)) {
      return;
    }
    final generation = ++_generation;
    state = _copyState(state, isReconciling: true);
    try {
      // Only this GET owns recovery; metadata cannot prove the selected bytes committed.
      final attempt = await ref
          .read(studentHomeworkAttemptRepositoryProvider)
          .fetchAttempt(operation.target.attemptId);
      if (!_canPublish(operation, generation)) return;
      if (!_matchesAttempt(attempt)) throw _invalidResponse();
      if (attempt.status != StudentHomeworkAttemptStatus.inProgress) {
        final accepted = ref
            .read(studentHomeworkAttemptControllerProvider(target).notifier)
            .acceptAuthoritativeTerminalAttempt(attempt);
        if (accepted && ref.mounted) state = _synchronize(state, attempt);
        return;
      }
      final matches = attempt.questions.where(
        (question) => question.id.toLowerCase() == operation.questionId,
      );
      if (matches.length != 1 || !_isFileQuestion(matches.single)) {
        throw _invalidResponse();
      }
      final question = matches.single;
      final selected = operation.selectedFile!;
      final error = validateStudentSubmissionSelection(
        selected,
        question.answerUi as StudentFileAnswerUi,
      );
      final refreshed = _synchronize(state, attempt);
      state = _copyState(
        refreshed,
        isAuthoritative: _hasAuthority(
          ref.read(studentHomeworkAttemptControllerProvider(target)),
        ),
      );
      _finish(
        operation.questionId,
        StudentFileQuestionAnswerState(
          question: question,
          serverFile: _fileFor(attempt, operation.questionId),
          selectedFile: error == null ? selected : null,
          status: error == null
              ? StudentFileAnswerStatus.ready
              : StudentFileAnswerStatus.failure,
          selectionError: error,
        ),
      );
      _refreshAttempt();
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation, generation) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      state = _copyState(
        state,
        isReconciling: false,
        questions: {
          ...state.questions,
          operation.questionId: _entry(
            state.questions[operation.questionId]!,
            status: StudentFileAnswerStatus.uncertain,
            failure: exception.failure,
          ),
        },
      );
    }
  }

  void clearLocalState() {
    final session = _activeSessionKey;
    _invalidateOwnership();
    _activeSessionKey = session;
    _cleared = true;
    state = StudentFileAnswerState();
  }

  StudentFileAnswerState _synchronize(
    StudentFileAnswerState previous,
    StudentHomeworkAttempt attempt,
  ) {
    final terminal = attempt.status != StudentHomeworkAttemptStatus.inProgress;
    if (previous.isTerminal && !terminal) return previous;
    if (terminal) {
      _generation += 1;
      _operation = null;
    }
    final questions = <String, StudentFileQuestionAnswerState>{};
    for (final question in attempt.questions.where(_isFileQuestion)) {
      final id = question.id.toLowerCase();
      final old = previous.questions[id];
      if (!terminal && old?.status == StudentFileAnswerStatus.uncertain) {
        questions[id] = old!;
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
      );
    }
    final activeId = previous.activeQuestionId;
    if (!terminal && activeId != null && !questions.containsKey(activeId)) {
      final old = previous.questions[activeId];
      if (old?.status == StudentFileAnswerStatus.uncertain) {
        questions[activeId] = old!;
      } else {
        _generation += 1;
        _operation = null;
      }
    }
    return StudentFileAnswerState(
      questions: questions,
      isAuthoritative: !terminal,
      isTerminal: terminal,
      activeQuestionId: _operation?.questionId,
      isReconciling: !terminal && _operation != null && previous.isReconciling,
    );
  }

  StudentSubmissionFile? _fileFor(StudentHomeworkAttempt attempt, String id) {
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
      isCanonicalStudentAttemptId(question.id) &&
      question.type == StudentQuestionType.fileBased &&
      question.answerUi is StudentFileAnswerUi;

  bool _matchesAttempt(StudentHomeworkAttempt attempt) =>
      isCanonicalStudentAttemptId(attempt.id) &&
      isCanonicalStudentAttemptId(target.attemptId) &&
      isCanonicalStudentHomeworkId(attempt.assessmentId) &&
      isCanonicalStudentHomeworkId(target.homeworkId) &&
      attempt.id.toLowerCase() == target.attemptId.toLowerCase() &&
      attempt.assessmentId.toLowerCase() == target.homeworkId.toLowerCase();

  bool _hasAuthority(StudentHomeworkAttemptState parent) =>
      !_cleared &&
      parent.status == StudentHomeworkAttemptLoadStatus.data &&
      parent.attempt != null &&
      _matchesAttempt(parent.attempt!) &&
      parent.attempt!.status == StudentHomeworkAttemptStatus.inProgress;

  StudentQuestion? _currentQuestion(String id) {
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key) || state.isTerminal) return null;
    final parent = ref.read(studentHomeworkAttemptControllerProvider(target));
    if (!_hasAuthority(parent) || _terminalAuthority()) return null;
    return _questionFor(parent.attempt!, id);
  }

  StudentQuestion? _responseQuestion(String id) {
    final attempt = ref
        .read(studentHomeworkAttemptControllerProvider(target))
        .attempt;
    return attempt != null && _matchesAttempt(attempt)
        ? _questionFor(attempt, id)
        : null;
  }

  StudentQuestion? _questionFor(StudentHomeworkAttempt attempt, String id) {
    final matches = attempt.questions.where(
      (question) => question.id.toLowerCase() == id,
    );
    return matches.length == 1 && _isFileQuestion(matches.single)
        ? matches.single
        : null;
  }

  bool _terminalAuthority() {
    final terminal = ref
        .read(studentAttemptAnswerEditorControllerProvider(target))
        .terminalAttempt;
    if (terminal != null &&
        _matchesAttempt(terminal) &&
        terminal.status != StudentHomeworkAttemptStatus.inProgress) {
      return true;
    }
    final parent = ref.read(studentHomeworkAttemptControllerProvider(target));
    return parent.status == StudentHomeworkAttemptLoadStatus.data &&
        parent.attempt != null &&
        _matchesAttempt(parent.attempt!) &&
        parent.attempt!.status != StudentHomeworkAttemptStatus.inProgress;
  }

  _FileOperation _begin(
    String id,
    StudentSubmissionUploadFile? selected,
    String? previousFileId,
  ) {
    final operation = _FileOperation(
      _activeSessionKey!,
      target,
      id,
      selected,
      previousFileId,
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
      operation.target == target &&
      identical(_operation, operation) &&
      !state.isTerminal &&
      !_terminalAuthority() &&
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
    if (!isCanonicalStudentAttemptId(result.questionId) ||
        result.questionId.toLowerCase() != operation.questionId ||
        result.type != StudentQuestionType.fileBased ||
        !_isFileQuestion(question) ||
        answer is! StudentFileAnswerValue ||
        result.updatedAt == null ||
        !result.updatedAt!.isUtc ||
        result.updatedAt!.millisecond != 0 ||
        result.updatedAt!.microsecond != 0) {
      return false;
    }
    final file = answer.file;
    final policy = question.answerUi as StudentFileAnswerUi;
    return isCanonicalStudentAttemptId(file.id) &&
        file.sizeBytes > 0 &&
        file.sizeBytes <= 15728640 &&
        policy.allowedExtensions.contains(file.extension) &&
        file.sizeBytes <= policy.maxSizeBytes &&
        file.originalName == selected.name &&
        file.extension == selected.extension &&
        file.sizeBytes == selected.length &&
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

  void _reconcileFailure(ApiFailure failure) {
    switch (failure.serverCode) {
      case ApiErrorCodes.fileTooLarge:
      case ApiErrorCodes.attemptNotEditable:
      case ApiErrorCodes.businessConflict:
        _refreshAttempt();
      case ApiErrorCodes.deadlinePassed:
      case ApiErrorCodes.taskClosed:
      case ApiErrorCodes.taskArchived:
      case ApiErrorCodes.taskNotActive:
        _refreshAttempt();
        ref.invalidate(
          studentHomeworkDetailControllerProvider(
            StudentHomeworkRouteTarget(
              topicId: target.topicId,
              homeworkId: target.homeworkId,
            ),
          ),
        );
    }
  }

  void _refreshAttempt() => ref
      .read(studentHomeworkAttemptControllerProvider(target).notifier)
      .refresh();

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
    _lastParent = null;
    _lastTerminal = null;
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
  );

  void _replace(String id, StudentFileQuestionAnswerState entry) =>
      state = _copyState(state, questions: {...state.questions, id: entry});

  void _finish(String id, StudentFileQuestionAnswerState entry) {
    _operation = null;
    state = StudentFileAnswerState(
      questions: {...state.questions, id: entry},
      isAuthoritative: state.isAuthoritative,
      isTerminal: state.isTerminal,
    );
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
  );
}

class _FileOperation {
  const _FileOperation(
    this.session,
    this.target,
    this.questionId,
    this.selectedFile,
    this.previousServerFileId,
  );
  final StudentSessionKey session;
  final StudentHomeworkAttemptRouteTarget target;
  final String questionId;
  final StudentSubmissionUploadFile? selectedFile;
  final String? previousServerFileId;
}
