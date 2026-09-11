import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_route_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_list_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_submit_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_submit_readiness.dart';
import 'package:testlabuz_client/features/student/application/student_homework_submit_state.dart';
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _attemptId = '60000000-0000-0000-0000-000000000001';
const _answerId = '70000000-0000-0000-0000-000000000001';
const _fileId = '70000000-0000-0000-0000-000000000002';
const _keyA = '80000000-0000-4000-8000-000000000001';
const _keyB = '80000000-0000-4000-8000-000000000002';
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
    'failed terminal adoption retains the key and cannot report completion',
    () async {
      final h = _Harness(rejectAdoption: true);
      await h.ready();
      final post = h.controller.submitConfirmed(h.token);
      h.repository.posts.single.complete(_attempt(terminal: true));
      await post;
      expect(h.state.status, StudentHomeworkSubmitStatus.uncertain);
      expect(h.gate, StudentAttemptRouteOperation.submitUncertain);
      expect(
        h.attempt.attempt!.status,
        StudentHomeworkAttemptStatus.inProgress,
      );
      expect(h.homework.details, hasLength(1));
      final retry = h.controller.retrySubmission();
      expect(h.repository.posts.last.key, _keyA);
      expect(h.keys.calls, 1);
      h.repository.posts.last.fail(studentLocalFailure(ApiFailureKind.timeout));
      await retry;
      expect(h.gate, StudentAttemptRouteOperation.submitUncertain);
    },
  );

  test(
    'validation failure revokes old readiness before synchronous failure listeners run',
    () async {
      final h = _Harness();
      await h.ready();
      final token = h.token;
      h.container.listen(studentHomeworkSubmitControllerProvider(_target), (
        _,
        next,
      ) {
        if (next.status == StudentHomeworkSubmitStatus.failure) {
          unawaited(h.controller.submitConfirmed(token));
        }
      });
      final post = h.controller.submitConfirmed(token);
      h.repository.posts.single.fail(
        studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
      );
      await post;
      expect(h.repository.posts, hasLength(1));
      expect(h.keys.calls, 1);
      expect(h.attempt.status, StudentHomeworkAttemptLoadStatus.refreshing);
    },
  );

  test(
    'zero-answer Submit claims synchronously and adopts before releasing; old GET loses',
    () async {
      final h = _Harness();
      await h.ready();
      final list = h.container.listen(
        studentHomeworkListControllerProvider(studentTopicId),
        (_, _) {},
      );
      await h.flush();
      h.homework.lists.single.complete(
        StudentHomeworkList(
          items: [],
          page: 1,
          perPage: 20,
          total: 0,
          lastPage: 1,
        ),
      );
      await h.flush();
      final retainedHomework = h.detail.homework;
      final token = h.token;
      expect(token.snapshot.confirmedAnsweredCount, 0);
      final pending = h.controller.submitConfirmed(token);
      expect(h.gate, StudentAttemptRouteOperation.submitting);
      expect(h.state.status, StudentHomeworkSubmitStatus.submitting);
      expect(h.repository.posts.single.attemptId, _attemptId);
      expect(h.repository.posts.single.homeworkId, _homeworkId);
      expect(h.repository.posts.single.key, _keyA);
      await h.controller.submitConfirmed(token);
      expect(h.repository.posts, hasLength(1));
      h.parent.refresh();
      final olderGet = h.repository.gets.last;
      final publication = h.attempt.publicationToken;
      StudentAttemptRouteOperation? gateAtAdoption;
      StudentHomeworkSubmitStatus? statusAtAdoption;
      h.container.listen(studentHomeworkAttemptControllerProvider(_target), (
        _,
        next,
      ) {
        if (next.attempt?.status == StudentHomeworkAttemptStatus.submitted) {
          gateAtAdoption = h.gate;
          statusAtAdoption = h.state.status;
        }
      });
      h.repository.posts.single.complete(_attempt(terminal: true));
      await pending;
      expect(gateAtAdoption, StudentAttemptRouteOperation.submitting);
      expect(statusAtAdoption, StudentHomeworkSubmitStatus.submitting);
      expect(h.attempt.publicationToken, isNot(same(publication)));
      expect(h.state.status, StudentHomeworkSubmitStatus.completed);
      expect(h.state.notice, 'Attempt submitted successfully.');
      expect(h.gate, StudentAttemptRouteOperation.idle);
      expect(h.detail.status, StudentHomeworkDetailStatus.refreshing);
      expect(h.detail.homework, same(retainedHomework));
      expect(list.read().isStale, isTrue);
      olderGet.complete(_attempt());
      await h.flush();
      expect(h.attempt.attempt!.status, StudentHomeworkAttemptStatus.submitted);
      expect(h.keys.calls, 1);
      expect(h.repository.saves, isEmpty);
      expect(h.repository.uploads, isEmpty);
    },
  );

  for (final failure in [
    studentLocalFailure(ApiFailureKind.timeout),
    studentLocalFailure(ApiFailureKind.connection),
    studentLocalFailure(ApiFailureKind.cancelled),
    studentLocalFailure(ApiFailureKind.invalidResponse),
    studentLocalFailure(ApiFailureKind.unknown),
    studentServerFailure('server_failure', statusCode: 500),
  ]) {
    test(
      '${failure.failure.kind}/${failure.failure.statusCode} retains exact key across explicit Retry',
      () async {
        final h = _Harness();
        await h.ready();
        final first = h.controller.submitConfirmed(h.token);
        h.repository.posts.single.fail(failure);
        await first;
        expect(h.state.status, StudentHomeworkSubmitStatus.uncertain);
        expect(h.gate, StudentAttemptRouteOperation.submitUncertain);
        final retry = h.controller.retrySubmission();
        expect(h.gate, StudentAttemptRouteOperation.submitting);
        await h.controller.retrySubmission();
        await h.controller.checkCurrentAttempt();
        expect(h.repository.gets, hasLength(1));
        expect(h.repository.posts.map((p) => p.key), [_keyA, _keyA]);
        h.repository.posts.last.complete(_attempt(terminal: true));
        await retry;
        expect(h.state.status, StudentHomeworkSubmitStatus.completed);
        expect(h.keys.calls, 1);
      },
    );
  }

  final invalidResults = <String, StudentHomeworkAttempt>{
    'deadline reason': _attempt(
      terminal: true,
      reason: StudentHomeworkAttemptFinalizationReason.homeworkDeadline,
    ),
    'close reason': _attempt(
      terminal: true,
      reason: StudentHomeworkAttemptFinalizationReason.taskClosed,
    ),
    'missing reason': _attempt(terminal: true, reason: null),
    'missing submitted timestamp': _attempt(terminal: true, submitted: false),
    'different finalized timestamp': _attempt(
      terminal: true,
      unequalFinalized: true,
    ),
    'wrong Attempt': _attempt(
      terminal: true,
      id: '60000000-0000-0000-0000-000000000002',
    ),
    'wrong Homework': _attempt(
      terminal: true,
      homeworkId: '40000000-0000-0000-0000-000000000002',
    ),
    'invalid UUID': _attempt(terminal: true, id: 'invalid'),
    'in progress': _attempt(),
  };
  for (final entry in invalidResults.entries) {
    test('injected typed ${entry.key} is uncertain and cannot adopt', () async {
      final h = _Harness();
      await h.ready();
      final post = h.controller.submitConfirmed(h.token);
      h.repository.posts.single.complete(entry.value);
      await post;
      expect(h.state.status, StudentHomeworkSubmitStatus.uncertain);
      expect(h.state.failure!.kind, ApiFailureKind.invalidResponse);
      expect(
        h.attempt.attempt!.status,
        StudentHomeworkAttemptStatus.inProgress,
      );
      final retry = h.controller.retrySubmission();
      expect(h.repository.posts.last.key, _keyA);
      expect(h.keys.calls, 1);
      h.repository.posts.last.complete(_attempt(terminal: true));
      await retry;
    });
  }

  for (final reason in StudentHomeworkAttemptFinalizationReason.values) {
    test(
      'owned terminal Check $reason adopts under uncertain gate and is reconciled',
      () async {
        final h = _Harness();
        await h.ready();
        await h.makeUncertain();
        final check = h.controller.checkCurrentAttempt();
        expect(h.state.status, StudentHomeworkSubmitStatus.checking);
        expect(h.gate, StudentAttemptRouteOperation.submitUncertain);
        await h.controller.checkCurrentAttempt();
        await h.controller.retrySubmission();
        expect(h.repository.posts, hasLength(1));
        expect(h.repository.getIds.last, _attemptId);
        expect(h.repository.gets, hasLength(2));
        StudentAttemptRouteOperation? gateAtAdoption;
        h.container.listen(studentHomeworkAttemptControllerProvider(_target), (
          _,
          next,
        ) {
          if (next.attempt?.status == StudentHomeworkAttemptStatus.submitted) {
            gateAtAdoption = h.gate;
          }
        });
        h.repository.gets.last.complete(
          _attempt(
            terminal: true,
            reason: reason,
            submitted:
                reason ==
                StudentHomeworkAttemptFinalizationReason.studentSubmit,
          ),
        );
        await check;
        expect(gateAtAdoption, StudentAttemptRouteOperation.submitUncertain);
        expect(h.state.status, StudentHomeworkSubmitStatus.reconciledTerminal);
        expect(h.state.terminalReconciliationReason, switch (reason) {
          StudentHomeworkAttemptFinalizationReason.studentSubmit =>
            StudentHomeworkSubmitTerminalReconciliationReason
                .studentSubmitAlreadyTerminal,
          StudentHomeworkAttemptFinalizationReason.homeworkDeadline =>
            StudentHomeworkSubmitTerminalReconciliationReason
                .homeworkDeadlineAutoFinalized,
          StudentHomeworkAttemptFinalizationReason.taskClosed =>
            StudentHomeworkSubmitTerminalReconciliationReason
                .taskClosedAutoFinalized,
        });
        expect(
          h.state.notice,
          reason == StudentHomeworkAttemptFinalizationReason.studentSubmit
              ? 'This Attempt is already submitted.'
              : null,
        );
        expect(h.gate, StudentAttemptRouteOperation.idle);
        await h.controller.retrySubmission();
        expect(h.repository.posts, hasLength(1));
      },
    );
  }

  for (final outcome in ['in progress', 'failure', 'mismatch']) {
    test('Check $outcome retains uncertainty and same-key Retry', () async {
      final h = _Harness();
      await h.ready();
      await h.makeUncertain();
      final check = h.controller.checkCurrentAttempt();
      if (outcome == 'failure') {
        h.repository.gets.last.completeError(
          studentLocalFailure(ApiFailureKind.connection),
        );
      } else {
        h.repository.gets.last.complete(
          _attempt(
            homeworkId: outcome == 'mismatch'
                ? '40000000-0000-0000-0000-000000000002'
                : _homeworkId,
          ),
        );
      }
      await check;
      expect(h.state.status, StudentHomeworkSubmitStatus.uncertain);
      expect(h.gate, StudentAttemptRouteOperation.submitUncertain);
      final retry = h.controller.retrySubmission();
      expect(h.repository.posts.last.key, _keyA);
      h.repository.posts.last.complete(_attempt(terminal: true));
      await retry;
    });
  }

  test('unrelated parent terminal GET cannot resolve pending Submit', () async {
    final h = _Harness();
    await h.ready();
    await h.makeUncertain();
    h.parent.refresh();
    h.repository.gets.last.complete(_attempt(terminal: true));
    await h.flush();
    expect(h.state.status, StudentHomeworkSubmitStatus.uncertain);
    expect(h.gate, StudentAttemptRouteOperation.submitUncertain);
    final retry = h.controller.retrySubmission();
    expect(h.repository.posts.last.key, _keyA);
    h.repository.posts.last.complete(_attempt(terminal: true));
    await retry;
    expect(h.state.status, StudentHomeworkSubmitStatus.completed);
  });

  test(
    'late Check after explicit cleanup cannot overwrite newer same-key Retry success',
    () async {
      final h = _Harness();
      await h.ready();
      await h.makeUncertain();
      final oldCheck = h.controller.checkCurrentAttempt();
      final oldGet = h.repository.gets.last;
      h.controller.clearLocalState();
      expect(h.state.status, StudentHomeworkSubmitStatus.idle);
      expect(h.gate, StudentAttemptRouteOperation.idle);
      await h.makeUncertain();
      final retry = h.controller.retrySubmission();
      expect(h.repository.posts.map((p) => p.key), [_keyA, _keyB, _keyB]);
      h.repository.posts.last.complete(_attempt(terminal: true));
      await retry;
      oldGet.complete(_attempt());
      await oldCheck;
      expect(h.state.status, StudentHomeworkSubmitStatus.completed);
      expect(h.attempt.attempt!.status, StudentHomeworkAttemptStatus.submitted);
    },
  );

  for (final code in [
    ApiErrorCodes.deadlinePassed,
    ApiErrorCodes.attemptNotEditable,
    ApiErrorCodes.taskNotActive,
    ApiErrorCodes.taskClosed,
    ApiErrorCodes.taskArchived,
    ApiErrorCodes.resourceNotFound,
    ApiErrorCodes.idempotencyKeyReused,
    ApiErrorCodes.businessConflict,
    ApiErrorCodes.validationFailed,
  ]) {
    test(
      'deterministic $code clears ownership and waits for refreshed alignment',
      () async {
        final h = _Harness();
        await h.ready();
        final oldToken = h.token;
        final post = h.controller.submitConfirmed(oldToken);
        h.repository.posts.single.fail(
          studentServerFailure(
            code,
            statusCode: code == ApiErrorCodes.validationFailed
                ? 422
                : code == ApiErrorCodes.resourceNotFound
                ? 404
                : 409,
          ),
        );
        await post;
        expect(h.state.status, StudentHomeworkSubmitStatus.failure);
        expect(h.gate, StudentAttemptRouteOperation.idle);
        expect(h.attempt.status, StudentHomeworkAttemptLoadStatus.refreshing);
        expect(h.repository.gets, hasLength(2));
        if (code == ApiErrorCodes.validationFailed) {
          expect(
            h.state.notice,
            'The submission request could not be validated. Refresh and try again.',
          );
        }
        if (code == ApiErrorCodes.deadlinePassed) {
          expect(h.state.notice, 'The Homework deadline has passed.');
        }
        final refreshesHomework = [
          ApiErrorCodes.deadlinePassed,
          ApiErrorCodes.resourceNotFound,
          ApiErrorCodes.taskNotActive,
          ApiErrorCodes.taskClosed,
          ApiErrorCodes.taskArchived,
        ].contains(code);
        expect(h.homework.details.length, refreshesHomework ? 2 : 1);
        await h.controller.retrySubmission();
        await h.controller.submitConfirmed(oldToken);
        expect(h.keys.calls, 1);
        h.repository.gets.last.complete(_attempt());
        await h.flush();
        await h.controller.submitConfirmed(oldToken);
        expect(h.repository.posts, hasLength(1));
        final next = h.controller.submitConfirmed(h.token);
        expect(h.repository.posts.last.key, _keyB);
        h.repository.posts.last.complete(_attempt(terminal: true));
        await next;
      },
    );
  }

  for (final mutation in [
    'answer edit',
    'answer save',
    'file picker',
    'file upload',
    'publication',
    'terminal',
    'session',
  ]) {
    test(
      '$mutation after confirmation invalidates token before key or gate',
      () async {
        final h = _Harness();
        await h.ready();
        final token = h.token;
        Future<void>? mutationFuture;
        switch (mutation) {
          case 'answer edit':
          case 'answer save':
            h.answers.updateDraft(
              _answerId,
              StudentAnswerDraft.fromAnswer(
                _questions.first,
                const StudentTextAnswerValue(text: 'draft'),
              ),
            );
            if (mutation == 'answer save') {
              mutationFuture = h.answers.saveAnswer(_answerId);
            }
          case 'file picker':
            mutationFuture = h.files.chooseFile(_fileId);
          case 'file upload':
            final selection = h.files.chooseFile(_fileId);
            h.picker.pending.complete(
              StudentSubmissionUploadFile(
                name: 'answer.pdf',
                length: 2,
                openRead: () => Stream.value([1, 2]),
              ),
            );
            await selection;
            mutationFuture = h.files.uploadAnswer(_fileId);
          case 'publication':
            h.parent.refresh();
            h.repository.gets.last.complete(_attempt());
            await h.flush();
          case 'terminal':
            h.parent.acceptAuthoritativeTerminalAttempt(
              _attempt(terminal: true),
            );
          case 'session':
            h.auth.replaceUser(studentUser('student-b'));
        }
        await h.controller.submitConfirmed(token);
        expect(h.repository.posts, isEmpty);
        expect(h.keys.calls, 0);
        expect(h.gate, StudentAttemptRouteOperation.idle);
        if (mutation == 'answer save') {
          h.repository.saves.single.completeError(
            studentLocalFailure(ApiFailureKind.timeout),
          );
        }
        if (mutation == 'file picker') h.picker.pending.complete(null);
        if (mutation == 'file upload') {
          h.repository.uploads.single.completeError(
            studentLocalFailure(ApiFailureKind.timeout),
          );
        }
        if (mutationFuture != null) await mutationFuture;
      },
    );
  }

  for (final checking in [false, true]) {
    test(
      'session loss rejects late ${checking ? 'Check' : 'Submit'} and releases gate',
      () async {
        final h = _Harness();
        await h.ready();
        final Future<void> pending;
        if (checking) {
          await h.makeUncertain();
          pending = h.controller.checkCurrentAttempt();
        } else {
          pending = h.controller.submitConfirmed(h.token);
        }
        h.auth.logOut();
        await h.flush();
        expect(h.gate, StudentAttemptRouteOperation.idle);
        expect(h.state.status, StudentHomeworkSubmitStatus.idle);
        if (checking) {
          h.repository.gets.last.complete(_attempt(terminal: true));
        } else {
          h.repository.posts.last.complete(_attempt(terminal: true));
        }
        await pending;
        expect(h.state.status, StudentHomeworkSubmitStatus.idle);
        expect(h.attempt.attempt, isNull);
      },
    );
  }

  test('disposed target cannot adopt late Submit completion', () async {
    final h = _Harness();
    await h.ready();
    final pending = h.controller.submitConfirmed(h.token);
    h.close();
    h.repository.posts.last.complete(_attempt(terminal: true));
    await pending;
    expect(h.homework.details, hasLength(1));
  });
}

class _Harness {
  _Harness({bool rejectAdoption = false}) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        idempotencyKeyGeneratorProvider.overrideWithValue(keys),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(repository),
        studentHomeworkRepositoryProvider.overrideWithValue(homework),
        studentSubmissionFilePickerProvider.overrideWithValue(picker),
        if (rejectAdoption)
          studentHomeworkAttemptControllerProvider(
            _target,
          ).overrideWith(_RejectingParent.new),
      ],
    );
    container.listen(
      studentHomeworkDetailControllerProvider(_detailTarget),
      (_, _) {},
    );
    container.listen(
      studentHomeworkSubmitControllerProvider(_target),
      (_, _) {},
    );
    addTearDown(close);
  }
  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  final repository = _Repository();
  final homework = _Homework();
  final keys = _Keys();
  final picker = _Picker();
  late final ProviderContainer container;
  var closed = false;
  StudentHomeworkSubmitController get controller =>
      container.read(studentHomeworkSubmitControllerProvider(_target).notifier);
  StudentHomeworkSubmitState get state =>
      container.read(studentHomeworkSubmitControllerProvider(_target));
  StudentHomeworkAttemptController get parent => container.read(
    studentHomeworkAttemptControllerProvider(_target).notifier,
  );
  StudentHomeworkAttemptState get attempt =>
      container.read(studentHomeworkAttemptControllerProvider(_target));
  StudentHomeworkDetailState get detail =>
      container.read(studentHomeworkDetailControllerProvider(_detailTarget));
  StudentAttemptAnswerEditorController get answers => container.read(
    studentAttemptAnswerEditorControllerProvider(_target).notifier,
  );
  StudentFileAnswerController get files =>
      container.read(studentFileAnswerControllerProvider(_target).notifier);
  StudentAttemptRouteOperation get gate =>
      container.read(studentAttemptRouteOperationGateProvider(_target));
  StudentHomeworkSubmitReadyToken get token => container
      .read(studentHomeworkSubmitReadinessProvider(_target))
      .readyToken!;
  Future<void> ready() async {
    await flush();
    repository.gets.single.complete(_attempt());
    homework.details.single.complete(_detail());
    await flush();
    expect(
      container.read(studentHomeworkSubmitReadinessProvider(_target)).isReady,
      isTrue,
    );
  }

  Future<void> makeUncertain() async {
    final pending = controller.submitConfirmed(token);
    repository.posts.last.fail(studentLocalFailure(ApiFailureKind.timeout));
    await pending;
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

class _RejectingParent extends StudentHomeworkAttemptController {
  _RejectingParent() : super(_target);

  @override
  bool acceptAuthoritativeTerminalAttempt(StudentHomeworkAttempt attempt) =>
      false;
}

class _Keys implements IdempotencyKeyGenerator {
  int calls = 0;
  @override
  String generate() => calls++ == 0 ? _keyA : _keyB;
}

class _Picker implements StudentSubmissionFilePicker {
  final pending = Completer<StudentSubmissionUploadFile?>();
  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) => pending.future;
}

class _Repository implements StudentHomeworkAttemptRepository {
  final posts = <_Post>[];
  final gets = <Completer<StudentHomeworkAttempt>>[];
  final getIds = <String>[];
  final saves = <Completer<StudentAttemptAnswerMutationResult>>[];
  final uploads = <Completer<StudentAttemptAnswerMutationResult>>[];
  @override
  Future<StudentHomeworkSubmitResult> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  ) {
    final post = _Post(attemptId, expectedHomeworkId, idempotencyKey);
    posts.add(post);
    return post.completer.future;
  }

  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) {
    getIds.add(attemptId);
    final pending = Completer<StudentHomeworkAttempt>();
    gets.add(pending);
    return pending.future;
  }

  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) {
    final pending = Completer<StudentAttemptAnswerMutationResult>();
    saves.add(pending);
    return pending.future;
  }

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) {
    final pending = Completer<StudentAttemptAnswerMutationResult>();
    uploads.add(pending);
    return pending.future;
  }

  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) => throw StateError('Submit must not start an Attempt.');
}

class _Post {
  _Post(this.attemptId, this.homeworkId, this.key);
  final String attemptId;
  final String homeworkId;
  final String key;
  final completer = Completer<StudentHomeworkSubmitResult>();
  void complete(StudentHomeworkAttempt attempt) =>
      completer.complete(StudentHomeworkSubmitResult(attempt: attempt));
  void fail(Object error) => completer.completeError(error);
}

class _Homework implements StudentHomeworkRepository {
  final details = <Completer<StudentHomeworkDetail>>[];
  final lists = <Completer<StudentHomeworkList>>[];
  @override
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) {
    final pending = Completer<StudentHomeworkDetail>();
    details.add(pending);
    return pending.future;
  }

  @override
  Future<StudentHomeworkList> fetchHomework(StudentHomeworkListQuery query) {
    final pending = Completer<StudentHomeworkList>();
    lists.add(pending);
    return pending.future;
  }
}

final _questions = [
  const StudentQuestion(
    id: _answerId,
    type: StudentQuestionType.shortWritten,
    prompt: 'Answer',
    instructions: null,
    points: 1,
    position: 1,
    answerUi: StudentEmptyAnswerUi(),
  ),
  StudentQuestion(
    id: _fileId,
    type: StudentQuestionType.fileBased,
    prompt: 'Upload',
    instructions: null,
    points: 1,
    position: 2,
    answerUi: StudentFileAnswerUi(
      allowedExtensions: ['pdf'],
      maxSizeBytes: 100,
    ),
  ),
];
StudentHomeworkAttempt _attempt({
  bool terminal = false,
  StudentHomeworkAttemptFinalizationReason? reason =
      StudentHomeworkAttemptFinalizationReason.studentSubmit,
  bool submitted = true,
  bool unequalFinalized = false,
  String id = _attemptId,
  String homeworkId = _homeworkId,
}) => StudentHomeworkAttempt(
  id: id,
  assessmentId: homeworkId,
  attemptNumber: 1,
  status: terminal
      ? StudentHomeworkAttemptStatus.submitted
      : StudentHomeworkAttemptStatus.inProgress,
  startedAt: DateTime.utc(2026, 9, 1),
  submittedAt: terminal && submitted ? DateTime.utc(2026, 9, 1, 1) : null,
  finalizedAt: terminal
      ? DateTime.utc(2026, 9, 1, unequalFinalized ? 2 : 1)
      : null,
  finalizationReason: terminal ? reason : null,
  deadlineAt: null,
  questions: _questions,
  answers: [],
);
StudentHomeworkDetail _detail() => StudentHomeworkDetail(
  id: _homeworkId,
  topic: const StudentHomeworkTopicSummary(id: studentTopicId, title: 'Topic'),
  title: 'Homework',
  description: null,
  studentInstructions: 'Read.',
  status: StudentHomeworkStatus.active,
  deadlineAt: null,
  totalPossiblePoints: 2,
  attempts: StudentHomeworkAttemptSummary(
    allowed: 3,
    used: 1,
    remaining: 2,
    officialScorePolicy: 'highest_valid_completed',
    inProgressAttempt: StudentInProgressHomeworkAttempt(
      id: _attemptId,
      attemptNumber: 1,
      startedAt: DateTime.utc(2026, 9, 1),
    ),
  ),
  myStatus: StudentHomeworkMyStatus.inProgress,
  scoreVisible: false,
  questions: _questions,
);
