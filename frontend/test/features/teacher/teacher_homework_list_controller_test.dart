import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_list_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_list_pagination.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '20000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherHomeworkListController', () {
    test('initially loads the default query on desktop and mobile', () async {
      for (final surface in [
        AppDeviceSurface.desktop,
        AppDeviceSurface.mobile,
      ]) {
        final repository = _FakeTeacherHomeworkRepository();
        final harness = _Harness(repository: repository, surface: surface);
        final subscription = harness.listen();

        await flushTeacherControllers();

        expect(repository.listRequests, [
          (topicId: _topicId, query: const TeacherHomeworkListQuery.initial()),
        ]);
        expect(subscription.read().status, TeacherHomeworkListStatus.data);
        expect(subscription.read().result!.items, hasLength(1));
      }
    });

    test('invalid Topic ID remains initial and sends no request', () async {
      final repository = _FakeTeacherHomeworkRepository();
      final harness = _Harness(repository: repository);
      final subscription = harness.listen(topicId: 'not-a-topic');

      await flushTeacherControllers();

      expect(repository.listRequests, isEmpty);
      expect(subscription.read().status, TeacherHomeworkListStatus.initial);
    });

    test(
      'refresh retains confirmed rows, suppresses a duplicate, and marks failure stale',
      () async {
        final refresh = Completer<TeacherHomeworkList>();
        var calls = 0;
        final repository = _FakeTeacherHomeworkRepository(
          onFetchList: (_, query) {
            calls += 1;
            return calls == 1
                ? Future.value(_homeworkList(query: query))
                : refresh.future;
          },
        );
        final harness = _Harness(repository: repository);
        final subscription = harness.listen();
        await flushTeacherControllers();
        final controller = harness.controller;
        final confirmed = subscription.read().result;

        controller.refresh();

        expect(
          subscription.read().status,
          TeacherHomeworkListStatus.refreshing,
        );
        expect(subscription.read().result, same(confirmed));
        controller.refresh();
        expect(repository.listRequests, hasLength(2));

        refresh.completeError(teacherLocalFailure(ApiFailureKind.timeout));
        await flushTeacherControllers();

        expect(subscription.read().status, TeacherHomeworkListStatus.error);
        expect(subscription.read().result, same(confirmed));
        expect(subscription.read().isStale, isTrue);
        expect(subscription.read().failure!.kind, ApiFailureKind.timeout);
      },
    );

    test(
      'search trims, clears, validates, and avoids unchanged requests',
      () async {
        final repository = _FakeTeacherHomeworkRepository();
        final harness = _Harness(repository: repository);
        final subscription = harness.listen();
        await flushTeacherControllers();
        final controller = harness.controller;

        controller.updateSearchDraft('  Algebra  ');
        controller.submitSearch();
        await flushTeacherControllers();
        expect(repository.listRequests.last.query.search, 'Algebra');
        expect(repository.listRequests.last.query.page, 1);

        final callsAfterSearch = repository.listRequests.length;
        controller.updateSearchDraft('Algebra');
        controller.submitSearch();
        await flushTeacherControllers();
        expect(repository.listRequests, hasLength(callsAfterSearch));

        controller.updateSearchDraft('   ');
        controller.submitSearch();
        await flushTeacherControllers();
        expect(repository.listRequests.last.query.search, isNull);

        final callsBeforeInvalid = repository.listRequests.length;
        controller.updateSearchDraft(
          String.fromCharCodes(List.filled(161, 0x1f600)),
        );
        controller.submitSearch();
        controller.refresh();
        await flushTeacherControllers();
        expect(repository.listRequests, hasLength(callsBeforeInvalid));
        expect(
          subscription.read().searchErrorText,
          teacherHomeworkSearchLengthError,
        );
      },
    );

    test(
      'status, assignment, search, and pagination own exact query state',
      () async {
        final repository = _FakeTeacherHomeworkRepository(
          onFetchList: (_, query) async =>
              _homeworkList(query: query, total: 60, lastPage: 3),
        );
        final harness = _Harness(repository: repository);
        final subscription = harness.listen();
        await flushTeacherControllers();
        final controller = harness.controller;

        controller.nextPage();
        await flushTeacherControllers();
        expect(subscription.read().query.page, 2);

        controller.setStatus(TeacherHomeworkStatus.active);
        await flushTeacherControllers();
        expect(
          repository.listRequests.last.query.status,
          TeacherHomeworkStatus.active,
        );
        expect(repository.listRequests.last.query.page, 1);

        controller.nextPage();
        await flushTeacherControllers();
        controller.setAssignmentMode(
          TeacherHomeworkAssignmentMode.selectedStudents,
        );
        await flushTeacherControllers();
        expect(
          repository.listRequests.last.query.assignmentMode,
          TeacherHomeworkAssignmentMode.selectedStudents,
        );
        expect(repository.listRequests.last.query.page, 1);

        controller.nextPage();
        await flushTeacherControllers();
        controller.updateSearchDraft('  Equations ');
        controller.submitSearch();
        await flushTeacherControllers();
        expect(repository.listRequests.last.query.search, 'Equations');
        expect(repository.listRequests.last.query.page, 1);

        expect(subscription.read().canGoPrevious, isFalse);
        controller.nextPage();
        await flushTeacherControllers();
        expect(subscription.read().canGoPrevious, isTrue);
        controller.previousPage();
        await flushTeacherControllers();
        expect(subscription.read().query.page, 1);
      },
    );

    test('an older search completion cannot overwrite a newer query', () async {
      final older = Completer<TeacherHomeworkList>();
      final newer = Completer<TeacherHomeworkList>();
      var calls = 0;
      final repository = _FakeTeacherHomeworkRepository(
        onFetchList: (_, __) {
          calls += 1;
          return calls == 1 ? older.future : newer.future;
        },
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      harness.controller
        ..updateSearchDraft('Current')
        ..submitSearch();
      await flushTeacherControllers();
      newer.complete(
        _homeworkList(
          query: repository.listRequests.last.query,
          title: 'Current row',
        ),
      );
      await flushTeacherControllers();
      older.completeError(teacherLocalFailure(ApiFailureKind.connection));
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherHomeworkListStatus.data);
      expect(subscription.read().query.search, 'Current');
      expect(subscription.read().result!.items.single.title, 'Current row');
    });

    test(
      'replacement session rejects old completion and starts a new load',
      () async {
        final oldSession = Completer<TeacherHomeworkList>();
        final newSession = Completer<TeacherHomeworkList>();
        var calls = 0;
        final repository = _FakeTeacherHomeworkRepository(
          onFetchList: (_, __) {
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
        oldSession.complete(
          _homeworkList(
            query: const TeacherHomeworkListQuery.initial(),
            title: 'Old session',
          ),
        );
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherHomeworkListStatus.loading);

        newSession.complete(
          _homeworkList(
            query: const TeacherHomeworkListQuery.initial(),
            title: 'New session',
          ),
        );
        await flushTeacherControllers();
        expect(subscription.read().result!.items.single.title, 'New session');
      },
    );

    test('logout and provider disposal reject pending completions', () async {
      final pendingLogout = Completer<TeacherHomeworkList>();
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final logoutRepository = _FakeTeacherHomeworkRepository(
        onFetchList: (_, __) => pendingLogout.future,
      );
      final logoutHarness = _Harness(repository: logoutRepository, auth: auth);
      final logoutSubscription = logoutHarness.listen();
      await flushTeacherControllers();

      auth.logOut();
      await flushTeacherControllers();
      pendingLogout.complete(
        _homeworkList(query: const TeacherHomeworkListQuery.initial()),
      );
      await flushTeacherControllers();
      expect(
        logoutSubscription.read().status,
        TeacherHomeworkListStatus.initial,
      );
      expect(logoutSubscription.read().result, isNull);

      final pendingDisposal = Completer<TeacherHomeworkList>();
      final disposalRepository = _FakeTeacherHomeworkRepository(
        onFetchList: (_, __) => pendingDisposal.future,
      );
      final disposalHarness = _Harness(repository: disposalRepository);
      final observed = <TeacherHomeworkListState>[];
      final disposalSubscription = disposalHarness.container.listen(
        teacherHomeworkListControllerProvider(_topicId),
        (_, next) => observed.add(next),
        fireImmediately: true,
      );
      await flushTeacherControllers();
      disposalSubscription.close();
      await flushTeacherControllers();
      final observationsAtDisposal = observed.length;
      pendingDisposal.complete(
        _homeworkList(query: const TeacherHomeworkListQuery.initial()),
      );
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
            onFetchList: (_, __) async => throw teacherServerFailure(code),
          );
          final harness = _Harness(repository: repository, auth: auth);
          final subscription = harness.listen();

          await flushTeacherControllers();

          expect(subscription.read().status, TeacherHomeworkListStatus.initial);
          expect(subscription.read().result, isNull);
          expect(
            auth.bootstrapCalls,
            code == ApiErrorCodes.authenticationRequired ? 0 : 1,
          );
        }
      },
    );

    test('invalid success response failure becomes retryable error', () async {
      final repository = _FakeTeacherHomeworkRepository(
        onFetchList: (_, __) async =>
            throw teacherLocalFailure(ApiFailureKind.invalidResponse),
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherHomeworkListStatus.error);
      expect(subscription.read().failure!.kind, ApiFailureKind.invalidResponse);
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
    );
  }

  const _Harness._({
    required this.repository,
    required this.auth,
    required this.container,
  });

  final _FakeTeacherHomeworkRepository repository;
  final FakeTeacherAuthSessionController auth;
  final ProviderContainer container;

  ProviderSubscription<TeacherHomeworkListState> listen({
    String topicId = _topicId,
  }) {
    return container.listen(
      teacherHomeworkListControllerProvider(topicId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherHomeworkListController get controller =>
      container.read(teacherHomeworkListControllerProvider(_topicId).notifier);
}

class _FakeTeacherHomeworkRepository implements TeacherHomeworkRepository {
  _FakeTeacherHomeworkRepository({this.onFetchList, this.onFetchHomework});

  Future<TeacherHomeworkList> Function(
    String topicId,
    TeacherHomeworkListQuery query,
  )?
  onFetchList;
  Future<TeacherHomework> Function(String homeworkId)? onFetchHomework;
  final listRequests = <({String topicId, TeacherHomeworkListQuery query})>[];

  @override
  Future<TeacherHomework> addQuestion(
    String homeworkId,
    TeacherQuestionCreateRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by list tests.');
  }

  @override
  Future<TeacherHomework> createHomework(
    String topicId,
    TeacherHomeworkCreateRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by list tests.');
  }

  @override
  Future<TeacherHomeworkList> fetchHomeworkList(
    String topicId,
    TeacherHomeworkListQuery query,
  ) {
    listRequests.add((topicId: topicId, query: query));
    return onFetchList?.call(topicId, query) ??
        Future.value(_homeworkList(query: query));
  }

  @override
  Future<TeacherHomework> fetchHomework(String homeworkId) {
    return onFetchHomework?.call(homeworkId) ??
        Future.value(_homework(homeworkId: homeworkId));
  }

  @override
  Future<TeacherHomework> deleteQuestion(String questionId) {
    throw UnimplementedError('Mutations are not used by list tests.');
  }

  @override
  Future<TeacherHomework> reorderQuestions(
    String homeworkId,
    TeacherQuestionReorderRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by list tests.');
  }

  @override
  Future<TeacherHomework> updateHomework(
    String homeworkId,
    TeacherHomeworkEditRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by list tests.');
  }

  @override
  Future<TeacherHomework> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  ) {
    throw UnimplementedError('Mutations are not used by list tests.');
  }
}

TeacherHomeworkList _homeworkList({
  required TeacherHomeworkListQuery query,
  String title = 'Homework 1',
  int total = 1,
  int lastPage = 1,
}) {
  return TeacherHomeworkList(
    items: [
      TeacherHomeworkSummary(
        id: _homeworkId,
        topicId: _topicId,
        title: title,
        assignmentMode: TeacherHomeworkAssignmentMode.group,
        totalPossiblePoints: 10,
        questionCount: 1,
        deadlineAt: null,
        institutionTimezone: 'Asia/Tashkent',
        status: TeacherHomeworkStatus.draft,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    ],
    pagination: TeacherListPagination(
      page: query.page,
      perPage: query.perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

TeacherHomework _homework({
  String homeworkId = _homeworkId,
  String topicId = _topicId,
}) {
  return TeacherHomework(
    id: homeworkId,
    topicId: topicId,
    title: 'Homework 1',
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
