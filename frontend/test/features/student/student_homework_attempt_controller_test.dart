import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
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
const _otherAttemptId = '60000000-0000-0000-0000-000000000002';

void main() {
  test(
    'every authoritative GET and terminal acceptance creates a fresh token',
    () async {
      final h = _Harness();
      final view = h.listen();
      expect(view.read().publicationToken, isNull);
      await h.flush();
      h.repository.requests.single.complete(_attempt());
      await h.flush();
      final first = view.read().publicationToken;
      expect(first, isNotNull);
      h.controller.refresh();
      expect(view.read().publicationToken, same(first));
      h.repository.requests.last.complete(_attempt());
      await h.flush();
      final second = view.read().publicationToken;
      expect(second, isNotNull);
      expect(second, isNot(same(first)));
      h.controller.refresh();
      final older = h.repository.requests.last;
      final terminal = _attempt(status: StudentHomeworkAttemptStatus.submitted);
      expect(h.controller.acceptAuthoritativeTerminalAttempt(terminal), isTrue);
      final terminalPublication = view.read().publicationToken;
      expect(terminalPublication, isNotNull);
      expect(terminalPublication, isNot(same(second)));
      older.complete(_attempt());
      await h.flush();
      expect(view.read().publicationToken, same(terminalPublication));
      expect(view.read().attempt, same(terminal));
    },
  );

  test(
    'retained error and refresh preserve token, notFound clears it',
    () async {
      final h = _Harness();
      final view = h.listen();
      await h.flush();
      h.repository.requests.single.complete(_attempt());
      await h.flush();
      final publication = view.read().publicationToken;
      h.controller.refresh();
      expect(view.read().publicationToken, same(publication));
      h.repository.requests.last.fail(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await h.flush();
      expect(view.read().status, StudentHomeworkAttemptLoadStatus.error);
      expect(view.read().publicationToken, same(publication));
      h.controller.retry();
      expect(view.read().publicationToken, same(publication));
      h.repository.requests.last.complete(_attempt(id: _otherAttemptId));
      await h.flush();
      expect(view.read().status, StudentHomeworkAttemptLoadStatus.notFound);
      expect(view.read().publicationToken, isNull);
    },
  );

  test(
    'initial load failure and session loss cannot retain publication',
    () async {
      final h = _Harness();
      final view = h.listen();
      expect(view.read().publicationToken, isNull);
      await h.flush();
      h.repository.requests.single.fail(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await h.flush();
      expect(view.read().status, StudentHomeworkAttemptLoadStatus.error);
      expect(view.read().publicationToken, isNull);
      h.controller.retry();
      expect(view.read().status, StudentHomeworkAttemptLoadStatus.loading);
      expect(view.read().publicationToken, isNull);
      h.repository.requests.last.complete(_attempt());
      await h.flush();
      expect(view.read().publicationToken, isNotNull);
      h.auth.logOut();
      await h.flush();
      expect(view.read().status, StudentHomeworkAttemptLoadStatus.initial);
      expect(view.read().publicationToken, isNull);
    },
  );

  test(
    'terminal acceptance compares canonical UUID letters case-insensitively',
    () async {
      const attemptId = 'abcdefab-0000-0000-0000-000000000001';
      const homeworkId = 'fedcbafe-0000-0000-0000-000000000001';
      final target = StudentHomeworkAttemptRouteTarget(
        topicId: studentTopicId,
        homeworkId: homeworkId,
        attemptId: attemptId,
      );
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          authSessionControllerProvider.overrideWith(
            () => FakeStudentAuthSessionController.authenticated(
              studentUser('student-a'),
            ),
          ),
          appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
          studentHomeworkAttemptRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      final view = container.listen(
        studentHomeworkAttemptControllerProvider(target),
        (_, _) {},
      );
      await Future<void>.value();
      await container.pump();
      final terminal = _attempt(
        id: attemptId.toUpperCase(),
        homeworkId: homeworkId.toUpperCase(),
        status: StudentHomeworkAttemptStatus.submitted,
      );
      expect(
        container
            .read(studentHomeworkAttemptControllerProvider(target).notifier)
            .acceptAuthoritativeTerminalAttempt(terminal),
        isTrue,
      );
      expect(view.read().status, StudentHomeworkAttemptLoadStatus.data);
      expect(view.read().attempt, same(terminal));
      repository.requests.single.complete(
        _attempt(id: attemptId, homeworkId: homeworkId),
      );
      await Future<void>.value();
      await container.pump();
      expect(view.read().attempt, same(terminal));
    },
  );

  test('accepted terminal snapshot invalidates an older parent GET', () async {
    final harness = _Harness();
    final view = harness.listen();
    await harness.flush();
    final older = harness.repository.requests.single;
    final terminal = _attempt(status: StudentHomeworkAttemptStatus.submitted);
    expect(
      harness.controller.acceptAuthoritativeTerminalAttempt(terminal),
      isTrue,
    );
    expect(view.read().status, StudentHomeworkAttemptLoadStatus.data);
    expect(view.read().attempt, same(terminal));
    older.complete(_attempt());
    await harness.flush();
    expect(view.read().attempt, same(terminal));
  });

  for (final invalid in [
    _attempt(),
    _attempt(id: 'bad', status: StudentHomeworkAttemptStatus.submitted),
    _attempt(homeworkId: 'bad', status: StudentHomeworkAttemptStatus.submitted),
    _attempt(
      id: _otherAttemptId,
      status: StudentHomeworkAttemptStatus.submitted,
    ),
    _attempt(
      homeworkId: '40000000-0000-0000-0000-000000000002',
      status: StudentHomeworkAttemptStatus.submitted,
    ),
  ]) {
    test(
      'rejects terminal acceptance for ${invalid.id}/${invalid.assessmentId}/${invalid.status}',
      () async {
        final harness = _Harness();
        final view = harness.listen();
        await harness.flush();
        final before = view.read();
        expect(
          harness.controller.acceptAuthoritativeTerminalAttempt(invalid),
          isFalse,
        );
        expect(view.read(), same(before));
      },
    );
  }

  test(
    'terminal acceptance rejects an obsolete session and disposed target',
    () async {
      final harness = _Harness();
      harness.listen();
      await harness.flush();
      final controller = harness.controller;
      final terminal = _attempt(status: StudentHomeworkAttemptStatus.submitted);
      harness.auth.logOut();
      expect(controller.acceptAuthoritativeTerminalAttempt(terminal), isFalse);
      await harness.flush();
      harness.close();
      expect(controller.acceptAuthoritativeTerminalAttempt(terminal), isFalse);
    },
  );

  test('eligible Student auto-loads then refreshes retained Attempt', () async {
    final harness = _Harness();
    final attempt = harness.listen();
    expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.loading);
    await harness.flush();
    expect(harness.repository.requests.single.id, _attemptId);
    harness.repository.requests.single.complete(_attempt());
    await harness.flush();
    expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.data);
    harness.controller.refresh();
    expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.refreshing);
    expect(attempt.read().attempt!.id, _attemptId);
    harness.repository.requests.last.complete(_attempt(number: 2));
    await harness.flush();
    expect(attempt.read().attempt!.attemptNumber, 2);
  });

  for (final status in StudentHomeworkAttemptStatus.values) {
    test('server lifecycle $status remains readable', () async {
      final harness = _Harness();
      final attempt = harness.listen();
      await harness.flush();
      harness.repository.requests.single.complete(_attempt(status: status));
      await harness.flush();
      expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.data);
      expect(attempt.read().attempt!.status, status);
    });
  }

  test('ineligible session does not read protected Attempt', () async {
    final harness = _Harness();
    harness.container.read(authSessionControllerProvider);
    harness.auth.logOut();
    final attempt = harness.listen();
    await harness.flush();
    expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.initial);
    expect(harness.repository.requests, isEmpty);
  });

  test(
    '404 removes Attempt and reconciles Homework detail and topic list',
    () async {
      final harness = _Harness();
      final detail = harness.container.listen(
        studentHomeworkDetailControllerProvider(_homeworkTarget()),
        (_, _) {},
      );
      final list = harness.container.listen(
        studentHomeworkListControllerProvider(studentTopicId),
        (_, _) {},
      );
      final attempt = harness.listen();
      await harness.flush();
      harness.homework.details.single.complete(_detail());
      harness.homework.lists.single.complete(_page());
      await harness.flush();
      harness.repository.requests.single.fail(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      await harness.flush();
      expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.notFound);
      expect(attempt.read().attempt, isNull);
      expect(attempt.read().failure, isNull);
      expect(detail.read().status, StudentHomeworkDetailStatus.loading);
      expect(harness.homework.details, hasLength(2));
      expect(list.read().status, StudentHomeworkListStatus.refreshing);
      expect(list.read().isStale, isTrue);
    },
  );

  for (final returned in [
    _attempt(id: _otherAttemptId),
    _attempt(homeworkId: '40000000-0000-0000-0000-000000000002'),
  ]) {
    test(
      'wrong returned hierarchy ${returned.id}/${returned.assessmentId} is unavailable',
      () async {
        final harness = _Harness();
        final attempt = harness.listen();
        await harness.flush();
        harness.repository.requests.single.complete(returned);
        await harness.flush();
        expect(
          attempt.read().status,
          StudentHomeworkAttemptLoadStatus.notFound,
        );
        expect(attempt.read().attempt, isNull);
      },
    );
  }

  test(
    'typed read failure offers retry and retains only prior Attempt',
    () async {
      final harness = _Harness();
      final attempt = harness.listen();
      await harness.flush();
      harness.repository.requests.single.complete(_attempt());
      await harness.flush();
      harness.controller.refresh();
      harness.repository.requests.last.fail(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await harness.flush();
      expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.error);
      expect(attempt.read().attempt!.id, _attemptId);
      expect(attempt.read().failure!.kind, ApiFailureKind.timeout);
      harness.controller.retry();
      expect(
        attempt.read().status,
        StudentHomeworkAttemptLoadStatus.refreshing,
      );
      harness.repository.requests.last.complete(_attempt(number: 2));
      await harness.flush();
      expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.data);
      expect(attempt.read().attempt!.attemptNumber, 2);
    },
  );

  test('404 without resource_not_found stays a typed read failure', () async {
    final harness = _Harness();
    final attempt = harness.listen();
    await harness.flush();
    harness.repository.requests.single.fail(
      studentServerFailure('other_failure', statusCode: 404),
    );
    await harness.flush();
    expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.error);
  });

  for (final code in [
    ApiErrorCodes.authenticationRequired,
    ApiErrorCodes.passwordChangeRequired,
    ApiErrorCodes.userInactive,
    ApiErrorCodes.institutionInactive,
  ]) {
    test(
      '$code clears Attempt and uses existing session reconciliation',
      () async {
        final harness = _Harness();
        final attempt = harness.listen();
        await harness.flush();
        harness.repository.requests.single.complete(_attempt());
        await harness.flush();
        harness.controller.refresh();
        harness.repository.requests.last.fail(studentServerFailure(code));
        await harness.flush();
        expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.initial);
        expect(attempt.read().attempt, isNull);
        expect(attempt.read().failure, isNull);
        expect(
          harness.auth.bootstrapCalls,
          code == ApiErrorCodes.authenticationRequired ? 0 : 1,
        );
      },
    );
  }

  test(
    'Student switch rejects old refresh before and after current load',
    () async {
      final harness = _Harness();
      final attempt = harness.listen();
      await harness.flush();
      harness.repository.requests.single.complete(_attempt());
      await harness.flush();
      harness.controller.refresh();
      final old = harness.repository.requests.last;
      harness.auth.replaceUser(studentUser('student-b'));
      await harness.flush();
      expect(attempt.read().attempt, isNull);
      harness.repository.requests.last.complete(_attempt(number: 2));
      await harness.flush();
      old.fail(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      await harness.flush();
      expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.data);
      expect(attempt.read().attempt!.attemptNumber, 2);
      expect(harness.homework.details, isEmpty);
    },
  );

  test('equivalent session rebuild preserves the same read', () async {
    final user = studentUser('student-a');
    final harness = _Harness(
      auth: FakeStudentAuthSessionController.authenticated(user),
    );
    final attempt = harness.listen();
    await harness.flush();
    harness.auth.replaceUser(user);
    await harness.flush();
    expect(harness.repository.requests, hasLength(1));
    harness.repository.requests.single.complete(_attempt());
    await harness.flush();
    expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.data);
  });

  test('surface change rejects former surface completion', () async {
    final harness = _Harness();
    final attempt = harness.listen();
    await harness.flush();
    final old = harness.repository.requests.single;
    harness.container
        .read(_surfaceProvider.notifier)
        .change(AppDeviceSurface.mobile);
    await harness.flush();
    harness.repository.requests.last.complete(_attempt(number: 2));
    await harness.flush();
    old.complete(_attempt());
    await harness.flush();
    expect(attempt.read().attempt!.attemptNumber, 2);
  });

  test('old target completion cannot publish to the current route', () async {
    final harness = _Harness();
    final old = harness.listen();
    await harness.flush();
    final pending = harness.repository.requests.single;
    old.close();
    final current = harness.listen(attemptId: _otherAttemptId);
    await harness.flush();
    harness.repository.requests.last.complete(_attempt(id: _otherAttemptId));
    await harness.flush();
    pending.complete(_attempt());
    await harness.flush();
    expect(current.read().attempt!.id, _otherAttemptId);
    expect(harness.homework.details, isEmpty);
  });

  test(
    'logout removes read ownership and suppresses late completion',
    () async {
      final harness = _Harness();
      final attempt = harness.listen();
      await harness.flush();
      harness.auth.logOut();
      await harness.flush();
      harness.repository.requests.single.complete(_attempt());
      await harness.flush();
      expect(attempt.read().status, StudentHomeworkAttemptLoadStatus.initial);
      expect(attempt.read().attempt, isNull);
    },
  );

  test(
    'disposal ignores late failure without auth or parent effects',
    () async {
      final harness = _Harness();
      harness.listen();
      await harness.flush();
      harness.close();
      harness.repository.requests.single.fail(
        studentServerFailure(ApiErrorCodes.userInactive),
      );
      await Future<void>.value();
      expect(harness.auth.bootstrapCalls, 0);
      expect(harness.homework.details, isEmpty);
    },
  );

  test('disposal before scheduled loading makes no request', () async {
    final harness = _Harness();
    harness.listen();
    harness.close();
    await Future<void>.value();
    expect(harness.repository.requests, isEmpty);
  });
}

class _Harness {
  _Harness({FakeStudentAuthSessionController? auth})
    : auth =
          auth ??
          FakeStudentAuthSessionController.authenticated(
            studentUser('student-a'),
          ) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWith(
          (ref) => ref.watch(_surfaceProvider),
        ),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(repository),
        studentHomeworkRepositoryProvider.overrideWithValue(homework),
      ],
    );
    addTearDown(close);
  }
  final FakeStudentAuthSessionController auth;
  final repository = _Repository();
  final homework = _Homework();
  late final ProviderContainer container;
  var closed = false;
  StudentHomeworkAttemptController get controller => container.read(
    studentHomeworkAttemptControllerProvider(_target()).notifier,
  );
  ProviderSubscription<StudentHomeworkAttemptState> listen({
    String attemptId = _attemptId,
  }) => container.listen(
    studentHomeworkAttemptControllerProvider(_target(attemptId: attemptId)),
    (_, _) {},
  );
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

final _surfaceProvider = NotifierProvider<_Surface, AppDeviceSurface>(
  _Surface.new,
);

class _Surface extends Notifier<AppDeviceSurface> {
  @override
  AppDeviceSurface build() => AppDeviceSurface.desktop;
  void change(AppDeviceSurface surface) => state = surface;
}

class _Repository implements StudentHomeworkAttemptRepository {
  @override
  Future<StudentHomeworkSubmitResult> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  ) async {
    throw StateError(
      'This regression must not submit a Student Homework Attempt.',
    );
  }

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) =>
      throw StateError('This regression must not upload Student file answers.');

  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) => throw StateError('This regression must not save answers.');

  final requests = <_Request>[];
  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) {
    final request = _Request(attemptId);
    requests.add(request);
    return request.completer.future;
  }

  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) => throw StateError('Read controller must not Start.');
}

class _Request {
  _Request(this.id);
  final String id;
  final completer = Completer<StudentHomeworkAttempt>();
  void complete(StudentHomeworkAttempt attempt) => completer.complete(attempt);
  void fail(Object error) => completer.completeError(error);
}

class _Homework implements StudentHomeworkRepository {
  final details = <Completer<StudentHomeworkDetail>>[];
  final lists = <Completer<StudentHomeworkList>>[];
  @override
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) {
    final request = Completer<StudentHomeworkDetail>();
    details.add(request);
    return request.future;
  }

  @override
  Future<StudentHomeworkList> fetchHomework(StudentHomeworkListQuery query) {
    final request = Completer<StudentHomeworkList>();
    lists.add(request);
    return request.future;
  }
}

StudentHomeworkAttemptRouteTarget _target({String attemptId = _attemptId}) =>
    StudentHomeworkAttemptRouteTarget(
      topicId: studentTopicId,
      homeworkId: _homeworkId,
      attemptId: attemptId,
    );
StudentHomeworkRouteTarget _homeworkTarget() => StudentHomeworkRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
);
StudentHomeworkAttempt _attempt({
  String id = _attemptId,
  String homeworkId = _homeworkId,
  int number = 1,
  StudentHomeworkAttemptStatus status = StudentHomeworkAttemptStatus.inProgress,
}) => StudentHomeworkAttempt(
  id: id,
  assessmentId: homeworkId,
  attemptNumber: number,
  status: status,
  startedAt: DateTime.utc(2026, 9, 1),
  submittedAt: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : DateTime.utc(2026, 9, 1, 1),
  finalizedAt: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : DateTime.utc(2026, 9, 1, 1),
  finalizationReason: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : StudentHomeworkAttemptFinalizationReason.studentSubmit,
  deadlineAt: null,
  questions: [],
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
  totalPossiblePoints: 0,
  attempts: const StudentHomeworkAttemptSummary(
    allowed: 3,
    used: 0,
    remaining: 3,
    officialScorePolicy: 'highest_valid_completed',
  ),
  myStatus: StudentHomeworkMyStatus.notStarted,
  scoreVisible: false,
  questions: [],
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
