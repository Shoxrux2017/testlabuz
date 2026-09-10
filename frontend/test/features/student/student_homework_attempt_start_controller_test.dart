import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_start_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_start_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_list_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_list_state.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _otherHomeworkId = '40000000-0000-0000-0000-000000000002';
const _attemptId = '60000000-0000-0000-0000-000000000001';
const _keyA = '11111111-1111-4111-8111-111111111111';
const _keyB = '22222222-2222-4222-8222-222222222222';

void main() {
  for (final kind in StudentHomeworkAttemptStartResultKind.values) {
    test(
      '$kind publishes confirmed completion and reconciles counts',
      () async {
        final harness = _Harness();
        await harness.ready();
        final list = harness.listenList();
        await harness.flush();
        harness.homework.lists.last.complete(_page());
        await harness.flush();
        final operation = harness.controller.start();
        expect(
          harness.state.status,
          StudentHomeworkAttemptStartStatus.submitting,
        );
        expect(harness.attempts.starts.single.homeworkId, _homeworkId);
        expect(harness.attempts.starts.single.key, _keyA);
        harness.attempts.starts.single.complete(_result(kind: kind));
        await operation;
        await harness.flush();
        expect(
          harness.state.status,
          StudentHomeworkAttemptStartStatus.completed,
        );
        expect(harness.state.completedAttemptId, _attemptId);
        expect(harness.state.completedResultKind, kind);
        expect(harness.keys.calls, 1);
        expect(harness.homework.details, hasLength(2));
        expect(
          harness.detail.read().status,
          StudentHomeworkDetailStatus.loading,
        );
        expect(list.read().isStale, isTrue);
        expect(list.read().page!.items.single.attempts.remaining, 3);
        expect(harness.controller.consumeCompletion(), isTrue);
        expect(harness.state.status, StudentHomeworkAttemptStartStatus.idle);
        expect(harness.controller.consumeCompletion(), isFalse);
      },
    );
  }

  test('second Start and Retry cannot duplicate an active mutation', () async {
    final harness = _Harness();
    await harness.ready();
    final pending = harness.controller.start();
    await harness.controller.start();
    await harness.controller.retry();
    expect(harness.attempts.starts, hasLength(1));
    expect(harness.keys.calls, 1);
    harness.attempts.starts.single.complete(_result());
    await pending;
  });

  for (final failure in [
    studentLocalFailure(ApiFailureKind.timeout),
    studentLocalFailure(ApiFailureKind.connection),
    studentLocalFailure(ApiFailureKind.cancelled),
    studentLocalFailure(ApiFailureKind.invalidResponse),
    studentLocalFailure(ApiFailureKind.unknown),
    studentServerFailure(ApiErrorCodes.serverError, statusCode: 500),
  ]) {
    test(
      '${failure.failure.kind} uncertainty retries the exact original key',
      () async {
        final harness = _Harness();
        await harness.ready();
        final first = harness.controller.start();
        harness.attempts.starts.single.fail(failure);
        await first;
        expect(
          harness.state.status,
          StudentHomeworkAttemptStartStatus.uncertain,
        );
        expect(harness.state.completedAttemptId, isNull);
        await harness.controller.start();
        expect(harness.attempts.starts, hasLength(1));
        final retry = harness.controller.retry();
        expect(harness.attempts.starts.last.key, _keyA);
        expect(harness.keys.calls, 1);
        harness.attempts.starts.last.complete(_result());
        await retry;
        expect(
          harness.state.status,
          StudentHomeworkAttemptStartStatus.completed,
        );
      },
    );
  }

  test('invalid successful hierarchy retains the same logical key', () async {
    final harness = _Harness();
    await harness.ready();
    final first = harness.controller.start();
    harness.attempts.starts.last.complete(
      _result(homeworkId: _otherHomeworkId),
    );
    await first;
    expect(harness.state.status, StudentHomeworkAttemptStartStatus.uncertain);
    expect(harness.state.failure!.kind, ApiFailureKind.invalidResponse);
    expect(harness.homework.details, hasLength(1));
    final retry = harness.controller.retry();
    expect(harness.attempts.starts.last.key, _keyA);
    harness.attempts.starts.last.complete(_result());
    await retry;
    expect(harness.keys.calls, 1);
    expect(harness.state.completedAttemptId, _attemptId);
  });

  test(
    'deterministic collision clears key and never automatically retries',
    () async {
      final harness = _Harness();
      await harness.ready();
      final first = harness.controller.start();
      harness.attempts.starts.single.fail(
        studentServerFailure(
          ApiErrorCodes.idempotencyKeyReused,
          statusCode: 409,
        ),
      );
      await first;
      expect(harness.state.status, StudentHomeworkAttemptStartStatus.failure);
      expect(harness.attempts.starts, hasLength(1));
      await harness.controller.retry();
      expect(harness.attempts.starts, hasLength(1));
      final next = harness.controller.start();
      expect(harness.attempts.starts.last.key, _keyB);
      harness.attempts.starts.last.complete(_result());
      await next;
      expect(harness.keys.calls, 2);
    },
  );

  for (final code in [
    ApiErrorCodes.deadlinePassed,
    ApiErrorCodes.attemptsExhausted,
    ApiErrorCodes.taskNotActive,
    ApiErrorCodes.taskClosed,
    ApiErrorCodes.taskArchived,
    ApiErrorCodes.assessmentNotAssigned,
    ApiErrorCodes.resourceNotFound,
    ApiErrorCodes.businessConflict,
  ]) {
    test('$code reconciles only the required Homework boundaries', () async {
      final harness = _Harness();
      await harness.ready();
      final list = harness.listenList();
      final otherList = harness.container.listen(
        studentHomeworkListControllerProvider(
          '10000000-0000-0000-0000-000000000002',
        ),
        (_, _) {},
      );
      await harness.flush();
      for (final pending in harness.homework.lists) {
        pending.complete(_page());
      }
      await harness.flush();
      final start = harness.controller.start();
      harness.attempts.starts.single.fail(
        studentServerFailure(code, statusCode: 409),
      );
      await start;
      await harness.flush();
      expect(harness.state.status, StudentHomeworkAttemptStartStatus.failure);
      expect(harness.homework.details, hasLength(2));
      expect(harness.detail.read().status, StudentHomeworkDetailStatus.loading);
      final refreshList =
          code != ApiErrorCodes.deadlinePassed &&
          code != ApiErrorCodes.businessConflict;
      expect(list.read().isStale, refreshList);
      expect(otherList.read().isStale, isFalse);
      expect(harness.attempts.starts, hasLength(1));
    });
  }

  test('pre-outcome detail read cannot restore old Start authority', () async {
    final harness = _Harness();
    await harness.ready();
    final operation = harness.controller.start();
    harness.container
        .read(studentHomeworkDetailControllerProvider(_target()).notifier)
        .refresh();
    final obsoleteRead = harness.homework.details.last;
    harness.attempts.starts.single.complete(_result());
    await operation;
    await harness.flush();
    expect(harness.homework.details, hasLength(3));
    obsoleteRead.complete(_detail());
    await harness.flush();
    expect(harness.detail.read().status, StudentHomeworkDetailStatus.loading);
    expect(harness.detail.read().homework, isNull);
  });

  test(
    'refresh finding an in-progress Attempt does not abandon uncertain key',
    () async {
      final harness = _Harness();
      await harness.ready();
      final operation = harness.controller.start();
      harness.attempts.starts.single.fail(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await operation;
      harness.container
          .read(studentHomeworkDetailControllerProvider(_target()).notifier)
          .refresh();
      harness.homework.details.last.complete(_detail(inProgress: true));
      await harness.flush();
      expect(harness.state.status, StudentHomeworkAttemptStartStatus.uncertain);
      final retry = harness.controller.retry();
      expect(harness.attempts.starts.last.key, _keyA);
      harness.attempts.starts.last.complete(
        _result(kind: StudentHomeworkAttemptStartResultKind.resumed),
      );
      await retry;
      expect(harness.keys.calls, 1);
    },
  );

  for (final status in StudentHomeworkDetailStatus.values) {
    test(
      'only current data detail can authorize new Start from $status',
      () async {
        final detailState = StudentHomeworkDetailState(
          status: status,
          homework: _detail(),
        );
        final harness = _Harness(detailState: detailState);
        final operation = harness.controller.start();
        if (status == StudentHomeworkDetailStatus.data) {
          expect(harness.attempts.starts, hasLength(1));
          harness.attempts.starts.single.complete(_result());
        } else {
          expect(harness.attempts.starts, isEmpty);
          expect(harness.keys.calls, 0);
        }
        await operation;
      },
    );
  }

  for (final detail in [
    null,
    _detail(status: StudentHomeworkStatus.closed),
    _detail(status: StudentHomeworkStatus.archived),
    _detail(remaining: 0),
    _detail(inProgress: true),
  ]) {
    test(
      'missing Homework or unavailable capacity cannot issue Start ${detail?.status}/${detail?.attempts.remaining}/${detail?.attempts.inProgressAttempt != null}',
      () async {
        final harness = _Harness(
          detailState: StudentHomeworkDetailState(
            status: StudentHomeworkDetailStatus.data,
            homework: detail,
          ),
        );
        await harness.controller.start();
        expect(harness.attempts.starts, isEmpty);
        expect(harness.keys.calls, 0);
      },
    );
  }

  for (final code in [
    ApiErrorCodes.authenticationRequired,
    ApiErrorCodes.passwordChangeRequired,
    ApiErrorCodes.userInactive,
    ApiErrorCodes.institutionInactive,
  ]) {
    test(
      '$code clears operation and follows existing auth reconciliation',
      () async {
        final harness = _Harness();
        await harness.ready();
        final operation = harness.controller.start();
        harness.attempts.starts.single.fail(studentServerFailure(code));
        await operation;
        expect(harness.state.status, StudentHomeworkAttemptStartStatus.idle);
        expect(harness.state.failure, isNull);
        expect(harness.state.completedAttemptId, isNull);
        expect(
          harness.auth.bootstrapCalls,
          code == ApiErrorCodes.authenticationRequired ? 0 : 1,
        );
        await harness.controller.retry();
        await harness.controller.start();
        expect(harness.attempts.starts, hasLength(1));
        harness.auth.replaceUser(studentUser('student-b'));
        await harness.flush();
        harness.homework.details.last.complete(_detail());
        await harness.flush();
        final current = harness.controller.start();
        expect(harness.attempts.starts.last.key, _keyB);
        harness.attempts.starts.last.complete(_result());
        await current;
      },
    );
  }

  test(
    'Student switch clears uncertain ownership and old completion is ignored',
    () async {
      final harness = _Harness();
      await harness.ready();
      final oldOperation = harness.controller.start();
      final oldRequest = harness.attempts.starts.single;
      harness.auth.replaceUser(studentUser('student-b'));
      await harness.flush();
      expect(harness.state.status, StudentHomeworkAttemptStartStatus.idle);
      harness.homework.details.last.complete(_detail());
      await harness.flush();
      final current = harness.controller.start();
      expect(harness.attempts.starts.last.key, _keyB);
      oldRequest.complete(_result());
      await oldOperation;
      expect(
        harness.state.status,
        StudentHomeworkAttemptStartStatus.submitting,
      );
      harness.attempts.starts.last.complete(_result());
      await current;
      expect(harness.state.status, StudentHomeworkAttemptStartStatus.completed);
    },
  );

  test('equivalent Student rebuild preserves pending operation', () async {
    final user = studentUser('student-a');
    final harness = _Harness(
      auth: FakeStudentAuthSessionController.authenticated(user),
    );
    await harness.ready();
    final operation = harness.controller.start();
    harness.auth.replaceUser(user);
    await harness.flush();
    expect(harness.state.status, StudentHomeworkAttemptStartStatus.submitting);
    harness.attempts.starts.single.complete(_result());
    await operation;
    expect(harness.state.status, StudentHomeworkAttemptStartStatus.completed);
    expect(harness.keys.calls, 1);
  });

  test('disposed old Homework cannot publish to a different target', () async {
    final harness = _Harness();
    await harness.ready();
    final operation = harness.controller.start();
    final old = harness.attempts.starts.single;
    harness.start.close();
    final current = harness.container.listen(
      studentHomeworkAttemptStartControllerProvider(
        _target(homeworkId: _otherHomeworkId),
      ),
      (_, _) {},
    );
    await harness.flush();
    old.complete(_result());
    await operation;
    expect(current.read().status, StudentHomeworkAttemptStartStatus.idle);
    expect(current.read().completedAttemptId, isNull);
    expect(harness.homework.details, hasLength(1));
  });

  test('dispose ignores late mutation success and reconciliation', () async {
    final harness = _Harness();
    await harness.ready();
    final operation = harness.controller.start();
    harness.close();
    harness.attempts.starts.single.complete(_result());
    await operation;
    expect(harness.homework.details, hasLength(1));
    expect(harness.auth.bootstrapCalls, 0);
  });
}

class _Harness {
  _Harness({
    FakeStudentAuthSessionController? auth,
    StudentHomeworkDetailState? detailState,
  }) : auth =
           auth ??
           FakeStudentAuthSessionController.authenticated(
             studentUser('student-a'),
           ) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        idempotencyKeyGeneratorProvider.overrideWithValue(keys),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(attempts),
        studentHomeworkRepositoryProvider.overrideWithValue(homework),
        if (detailState != null)
          studentHomeworkDetailControllerProvider(
            _target(),
          ).overrideWith(() => _FixedDetail(detailState)),
      ],
    );
    detail = container.listen(
      studentHomeworkDetailControllerProvider(_target()),
      (_, _) {},
    );
    start = container.listen(
      studentHomeworkAttemptStartControllerProvider(_target()),
      (_, _) {},
    );
    addTearDown(close);
  }

  final FakeStudentAuthSessionController auth;
  final keys = _Keys();
  final attempts = _Attempts();
  final homework = _Homework();
  late final ProviderContainer container;
  late final ProviderSubscription<StudentHomeworkDetailState> detail;
  late final ProviderSubscription<StudentHomeworkAttemptStartState> start;
  var closed = false;

  StudentHomeworkAttemptStartController get controller => container.read(
    studentHomeworkAttemptStartControllerProvider(_target()).notifier,
  );
  StudentHomeworkAttemptStartState get state => start.read();
  ProviderSubscription<StudentHomeworkListState> listenList() => container
      .listen(studentHomeworkListControllerProvider(studentTopicId), (_, _) {});

  Future<void> ready() async {
    await flush();
    homework.details.single.complete(_detail());
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

class _FixedDetail extends StudentHomeworkDetailController {
  _FixedDetail(this.initial) : super(_target());
  final StudentHomeworkDetailState initial;
  @override
  StudentHomeworkDetailState build() => initial;
}

class _Keys implements IdempotencyKeyGenerator {
  int calls = 0;
  @override
  String generate() => calls++ == 0 ? _keyA : _keyB;
}

class _Attempts implements StudentHomeworkAttemptRepository {
  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) => throw StateError('This regression must not save answers.');

  final starts = <_StartRequest>[];
  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) {
    final request = _StartRequest(homeworkId, idempotencyKey);
    starts.add(request);
    return request.completer.future;
  }

  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) =>
      throw StateError('Start controller must not fetch Attempt.');
}

class _StartRequest {
  _StartRequest(this.homeworkId, this.key);
  final String homeworkId;
  final String key;
  final completer = Completer<StudentHomeworkAttemptStartResult>();
  void complete(StudentHomeworkAttemptStartResult result) =>
      completer.complete(result);
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

StudentHomeworkRouteTarget _target({String homeworkId = _homeworkId}) =>
    StudentHomeworkRouteTarget(topicId: studentTopicId, homeworkId: homeworkId);

StudentHomeworkDetail _detail({
  StudentHomeworkStatus status = StudentHomeworkStatus.active,
  int remaining = 3,
  bool inProgress = false,
}) => StudentHomeworkDetail(
  id: _homeworkId,
  topic: const StudentHomeworkTopicSummary(id: studentTopicId, title: 'Topic'),
  title: 'Homework',
  description: null,
  studentInstructions: 'Read.',
  status: status,
  deadlineAt: null,
  totalPossiblePoints: 0,
  attempts: StudentHomeworkAttemptSummary(
    allowed: 3,
    used: 3 - remaining,
    remaining: remaining,
    officialScorePolicy: 'highest_valid_completed',
    inProgressAttempt: inProgress
        ? StudentInProgressHomeworkAttempt(
            id: _attemptId,
            attemptNumber: 1,
            startedAt: DateTime.utc(2026, 9, 1),
          )
        : null,
  ),
  myStatus: StudentHomeworkMyStatus.notStarted,
  scoreVisible: false,
  questions: [],
);

StudentHomeworkAttemptStartResult _result({
  StudentHomeworkAttemptStartResultKind kind =
      StudentHomeworkAttemptStartResultKind.created,
  String homeworkId = _homeworkId,
}) => StudentHomeworkAttemptStartResult(
  attempt: StudentHomeworkAttempt(
    id: _attemptId,
    assessmentId: homeworkId,
    attemptNumber: 1,
    status: StudentHomeworkAttemptStatus.inProgress,
    startedAt: DateTime.utc(2026, 9, 1),
    submittedAt: null,
    finalizedAt: null,
    finalizationReason: null,
    deadlineAt: null,
    questions: [],
    answers: [],
  ),
  resultKind: kind,
);

StudentHomeworkList _page() => StudentHomeworkList(
  items: [
    StudentHomeworkSummary(
      id: _homeworkId,
      topic: _detail().topic,
      title: 'Homework',
      status: StudentHomeworkStatus.active,
      deadlineAt: null,
      attempts: _detail().attempts,
      myStatus: StudentHomeworkMyStatus.notStarted,
      scoreVisible: false,
    ),
  ],
  page: 1,
  perPage: 20,
  total: 1,
  lastPage: 1,
);
