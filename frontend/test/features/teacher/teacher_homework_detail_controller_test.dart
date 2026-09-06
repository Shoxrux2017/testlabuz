import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_lifecycle.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _otherTopicId = '10000000-0000-0000-0000-000000000002';
const _homeworkId = '20000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherHomeworkRouteTarget', () {
    test('requires canonical IDs and has case-insensitive value equality', () {
      final lowercase = TeacherHomeworkRouteTarget(
        topicId: _topicId,
        homeworkId: _homeworkId,
      );
      final uppercase = TeacherHomeworkRouteTarget(
        topicId: _topicId.toUpperCase(),
        homeworkId: _homeworkId.toUpperCase(),
      );

      expect(uppercase, lowercase);
      expect(uppercase.hashCode, lowercase.hashCode);
      expect(
        () => TeacherHomeworkRouteTarget(
          topicId: 'not-a-topic',
          homeworkId: _homeworkId,
        ),
        throwsArgumentError,
      );
      expect(
        () => TeacherHomeworkRouteTarget(
          topicId: _topicId,
          homeworkId: 'not-homework',
        ),
        throwsArgumentError,
      );
    });
  });

  group('TeacherHomeworkDetailController', () {
    test('initially loads on desktop and mobile', () async {
      for (final surface in [
        AppDeviceSurface.desktop,
        AppDeviceSurface.mobile,
      ]) {
        final repository = _FakeTeacherHomeworkRepository();
        final harness = _Harness(repository: repository, surface: surface);
        final subscription = harness.listen();

        await flushTeacherControllers();

        expect(repository.detailRequests, [_homeworkId]);
        expect(subscription.read().status, TeacherHomeworkDetailStatus.data);
        expect(subscription.read().homework!.id, _homeworkId);
      }
    });

    test(
      'refresh retains confirmed Homework, suppresses duplicate, and marks failure stale',
      () async {
        final refresh = Completer<TeacherHomework>();
        var calls = 0;
        final repository = _FakeTeacherHomeworkRepository(
          onFetchHomework: (_) {
            calls += 1;
            return calls == 1
                ? Future.value(_homework(title: 'Confirmed'))
                : refresh.future;
          },
        );
        final harness = _Harness(repository: repository);
        final subscription = harness.listen();
        await flushTeacherControllers();
        final confirmed = subscription.read().homework;

        harness.controller.refresh();

        expect(
          subscription.read().status,
          TeacherHomeworkDetailStatus.refreshing,
        );
        expect(subscription.read().homework, same(confirmed));
        harness.controller.refresh();
        expect(repository.detailRequests, hasLength(2));

        refresh.completeError(teacherLocalFailure(ApiFailureKind.timeout));
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherHomeworkDetailStatus.error);
        expect(subscription.read().homework, same(confirmed));
        expect(subscription.read().isStale, isTrue);
      },
    );

    test('exact resource_not_found maps to generic notFound', () async {
      final repository = _FakeTeacherHomeworkRepository(
        onFetchHomework: (_) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherHomeworkDetailStatus.notFound);
      expect(subscription.read().homework, isNull);
      expect(subscription.read().failure, isNull);
    });

    test('successful Homework under another Topic maps to notFound', () async {
      final repository = _FakeTeacherHomeworkRepository(
        onFetchHomework: (_) async => _homework(topicId: _otherTopicId),
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherHomeworkDetailStatus.notFound);
      expect(subscription.read().homework, isNull);
    });

    test(
      'replacement session rejects old completion and starts a new load',
      () async {
        final oldSession = Completer<TeacherHomework>();
        final newSession = Completer<TeacherHomework>();
        var calls = 0;
        final repository = _FakeTeacherHomeworkRepository(
          onFetchHomework: (_) {
            calls += 1;
            return calls == 1 ? oldSession.future : newSession.future;
          },
        );
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = _Harness(repository: repository, auth: auth);
        final subscription = harness.listen();
        await flushTeacherControllers();

        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        oldSession.complete(_homework(title: 'Old session'));
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherHomeworkDetailStatus.loading);

        newSession.complete(_homework(title: 'New session'));
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherHomeworkDetailStatus.data);
        expect(subscription.read().homework!.title, 'New session');
      },
    );

    test('logout and provider disposal reject pending completions', () async {
      final pendingLogout = Completer<TeacherHomework>();
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final logoutRepository = _FakeTeacherHomeworkRepository(
        onFetchHomework: (_) => pendingLogout.future,
      );
      final logoutHarness = _Harness(repository: logoutRepository, auth: auth);
      final logoutSubscription = logoutHarness.listen();
      await flushTeacherControllers();

      auth.logOut();
      await flushTeacherControllers();
      pendingLogout.complete(_homework());
      await flushTeacherControllers();
      expect(
        logoutSubscription.read().status,
        TeacherHomeworkDetailStatus.initial,
      );
      expect(logoutSubscription.read().homework, isNull);

      final pendingDisposal = Completer<TeacherHomework>();
      final disposalRepository = _FakeTeacherHomeworkRepository(
        onFetchHomework: (_) => pendingDisposal.future,
      );
      final disposalHarness = _Harness(repository: disposalRepository);
      final observed = <TeacherHomeworkDetailState>[];
      final disposalSubscription = disposalHarness.container.listen(
        teacherHomeworkDetailControllerProvider(disposalHarness.target),
        (_, next) => observed.add(next),
        fireImmediately: true,
      );
      await flushTeacherControllers();
      disposalSubscription.close();
      await flushTeacherControllers();
      final observationsAtDisposal = observed.length;
      pendingDisposal.complete(_homework());
      await flushTeacherControllers();
      expect(observed, hasLength(observationsAtDisposal));
    });

    test(
      'structured session failures clear ownership and reconcile auth',
      () async {
        for (final code in [
          ApiErrorCodes.authenticationRequired,
          ApiErrorCodes.passwordChangeRequired,
          ApiErrorCodes.userInactive,
          ApiErrorCodes.institutionInactive,
        ]) {
          final auth = FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          );
          final repository = _FakeTeacherHomeworkRepository(
            onFetchHomework: (_) async => throw teacherServerFailure(code),
          );
          final harness = _Harness(repository: repository, auth: auth);
          final subscription = harness.listen();

          await flushTeacherControllers();

          expect(
            subscription.read().status,
            TeacherHomeworkDetailStatus.initial,
          );
          expect(subscription.read().homework, isNull);
          expect(
            auth.bootstrapCalls,
            code == ApiErrorCodes.authenticationRequired ? 0 : 1,
          );
        }
      },
    );

    test('invalid success response failure becomes retryable error', () async {
      var shouldFail = true;
      final repository = _FakeTeacherHomeworkRepository(
        onFetchHomework: (_) async {
          if (shouldFail) {
            throw teacherLocalFailure(ApiFailureKind.invalidResponse);
          }
          return _homework(title: 'Recovered');
        },
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherHomeworkDetailStatus.error);
      expect(subscription.read().failure!.kind, ApiFailureKind.invalidResponse);

      shouldFail = false;
      harness.controller.retry();
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherHomeworkDetailStatus.data);
      expect(subscription.read().homework!.title, 'Recovered');
    });
  });
}

class _Harness {
  factory _Harness({
    required _FakeTeacherHomeworkRepository repository,
    FakeTeacherAuthSessionController? auth,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) {
    final effectiveAuth =
        auth ??
        FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => effectiveAuth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return _Harness._(
      repository: repository,
      auth: effectiveAuth,
      container: container,
      target: TeacherHomeworkRouteTarget(
        topicId: _topicId,
        homeworkId: _homeworkId,
      ),
    );
  }

  const _Harness._({
    required this.repository,
    required this.auth,
    required this.container,
    required this.target,
  });

  final _FakeTeacherHomeworkRepository repository;
  final FakeTeacherAuthSessionController auth;
  final ProviderContainer container;
  final TeacherHomeworkRouteTarget target;

  ProviderSubscription<TeacherHomeworkDetailState> listen() {
    return container.listen(
      teacherHomeworkDetailControllerProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherHomeworkDetailController get controller =>
      container.read(teacherHomeworkDetailControllerProvider(target).notifier);
}

class _FakeTeacherHomeworkRepository implements TeacherHomeworkRepository {
  _FakeTeacherHomeworkRepository({this.onFetchHomework});

  Future<TeacherHomework> Function(String homeworkId)? onFetchHomework;
  final detailRequests = <String>[];

  @override
  Future<TeacherHomework> addQuestion(
    String homeworkId,
    TeacherQuestionCreateRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by detail tests.');
  }

  @override
  Future<TeacherHomework> createHomework(
    String topicId,
    TeacherHomeworkCreateRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by detail tests.');
  }

  @override
  Future<TeacherHomeworkList> fetchHomeworkList(
    String topicId,
    TeacherHomeworkListQuery query,
  ) {
    throw UnimplementedError('List reads are not used by detail tests.');
  }

  @override
  Future<TeacherHomework> fetchHomework(String homeworkId) {
    detailRequests.add(homeworkId);
    return onFetchHomework?.call(homeworkId) ??
        Future.value(_homework(homeworkId: homeworkId));
  }

  @override
  Future<TeacherHomework> performLifecycleAction(
    String homeworkId,
    TeacherHomeworkLifecycleAction action,
  ) {
    throw UnimplementedError('Mutations are not used by detail tests.');
  }

  @override
  Future<TeacherHomework> deleteQuestion(String questionId) {
    throw UnimplementedError('Mutations are not used by detail tests.');
  }

  @override
  Future<TeacherHomework> reorderQuestions(
    String homeworkId,
    TeacherQuestionReorderRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by detail tests.');
  }

  @override
  Future<TeacherHomework> updateHomework(
    String homeworkId,
    TeacherHomeworkEditRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by detail tests.');
  }

  @override
  Future<TeacherHomework> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by detail tests.');
  }
}

TeacherHomework _homework({
  String homeworkId = _homeworkId,
  String topicId = _topicId,
  String title = 'Homework 1',
}) {
  return TeacherHomework(
    id: homeworkId,
    topicId: topicId,
    title: title,
    description: null,
    studentInstructions: 'Complete the work.',
    assignmentMode: TeacherHomeworkAssignmentMode.group,
    studentIds: const [],
    totalPossiblePoints: 0,
    deadlineAt: null,
    institutionTimezone: 'Asia/Tashkent',
    status: TeacherHomeworkStatus.draft,
    attemptPolicy: const TeacherHomeworkAttemptPolicy(
      normalAttempts: TeacherHomeworkAttemptPolicy.requiredNormalAttempts,
      officialScorePolicy:
          TeacherHomeworkAttemptPolicy.requiredOfficialScorePolicy,
    ),
    activatedAt: null,
    closedAt: null,
    archivedAt: null,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    questions: const [],
  );
}
