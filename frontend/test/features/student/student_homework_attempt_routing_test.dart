import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/app/router/technical_root_screen.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_repository.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_attempt_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_detail_screen.dart';

import '../../router_bootstrap_test.dart' show FakeAuthRepository;
import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _attemptId = '50000000-0000-0000-0000-000000000001';
const _homeworkLocation =
    '/student/topics/$studentTopicId/homework/$_homeworkId';
const _location = '$_homeworkLocation/attempts/$_attemptId';

void main() {
  test(
    'nested canonical classifiers are mutually exclusive and extract IDs',
    () {
      expect(AppRouteNames.studentHomeworkAttempt, 'student-homework-attempt');
      expect(
        AppRoutePaths.studentHomeworkAttemptLocation(
          studentTopicId,
          _homeworkId,
          _attemptId,
        ),
        _location,
      );
      final topic = AppRoutePaths.studentTopicDetailLocation(studentTopicId);
      for (final path in ['/student', topic, _homeworkLocation, _location]) {
        expect(AppRoutePaths.isStudentApprovedLocation(path), isTrue);
        expect(AppRoutePaths.isStudentTopicDetailPath(path), path == topic);
        expect(
          AppRoutePaths.isStudentHomeworkDetailPath(path),
          path == _homeworkLocation,
        );
        expect(
          AppRoutePaths.isStudentHomeworkAttemptPath(path),
          path == _location,
        );
        expect(
          AppRoutePaths.studentTopicIdFromPath(path),
          path == '/student' ? null : studentTopicId,
        );
        expect(
          AppRoutePaths.studentHomeworkIdFromPath(path),
          path == _homeworkLocation || path == _location ? _homeworkId : null,
        );
        expect(
          AppRoutePaths.studentAttemptIdFromPath(path),
          path == _location ? _attemptId : null,
        );
      }
    },
  );

  test('all three route IDs are validated and included in target identity', () {
    final target = StudentHomeworkAttemptRouteTarget(
      topicId: studentTopicId,
      homeworkId: _homeworkId,
      attemptId: _attemptId,
    );
    final same = StudentHomeworkAttemptRouteTarget(
      topicId: studentTopicId,
      homeworkId: _homeworkId,
      attemptId: _attemptId,
    );
    expect(target, same);
    expect(target.hashCode, same.hashCode);
    for (var index = 0; index < 3; index++) {
      final ids = [studentTopicId, _homeworkId, _attemptId];
      ids[index] = '60000000-0000-0000-0000-000000000001';
      expect(
        target,
        isNot(
          StudentHomeworkAttemptRouteTarget(
            topicId: ids[0],
            homeworkId: ids[1],
            attemptId: ids[2],
          ),
        ),
      );
      for (final invalid in [
        '',
        'bad',
        ' $_attemptId',
        '$_attemptId/extra',
        '$_attemptId?x=1',
        '$_attemptId#x',
      ]) {
        ids[index] = invalid;
        expect(
          () => AppRoutePaths.studentHomeworkAttemptLocation(
            ids[0],
            ids[1],
            ids[2],
          ),
          throwsArgumentError,
        );
        expect(
          () => StudentHomeworkAttemptRouteTarget(
            topicId: ids[0],
            homeworkId: ids[1],
            attemptId: ids[2],
          ),
          throwsArgumentError,
        );
      }
    }
  });

  test('malformed paths, aliases and flat frontend paths are rejected', () {
    for (final path in [
      '$_location/',
      '$_location/extra',
      '$_location/edit',
      '$_location/submit',
      '$_location?preview=true',
      '$_location#fragment',
      '$_homeworkLocation/attempt/$_attemptId',
      '$_homeworkLocation/attempts/bad',
      '/student/topics/bad/homework/$_homeworkId/attempts/$_attemptId',
      '/student/topics/$studentTopicId/homework/bad/attempts/$_attemptId',
      '/student/attempts/$_attemptId',
    ]) {
      expect(
        AppRoutePaths.isStudentApprovedLocation(path),
        isFalse,
        reason: path,
      );
      expect(
        AppRoutePaths.isStudentTopicDetailPath(path),
        isFalse,
        reason: path,
      );
      expect(
        AppRoutePaths.isStudentHomeworkDetailPath(path),
        isFalse,
        reason: path,
      );
      expect(
        AppRoutePaths.isStudentHomeworkAttemptPath(path),
        isFalse,
        reason: path,
      );
      expect(AppRoutePaths.studentTopicIdFromPath(path), isNull, reason: path);
      expect(
        AppRoutePaths.studentHomeworkIdFromPath(path),
        isNull,
        reason: path,
      );
      expect(
        AppRoutePaths.studentAttemptIdFromPath(path),
        isNull,
        reason: path,
      );
    }
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} preserves Attempt bootstrap link and returns to Homework',
      (tester) async {
        final user = Completer<AuthUser>();
        final homework = _HomeworkRepository();
        final attempts = _AttemptRepository();
        final container = await _pump(
          tester,
          surface: surface,
          homework: homework,
          attempts: attempts,
          auth: FakeAuthRepository(
            storedToken: 'token',
            onCurrentUser: () => user.future,
          ),
        );
        expect(_path(container), _location);
        expect(find.byType(TechnicalRootScreen), findsOneWidget);
        expect(attempts.readIds, isEmpty);
        expect(homework.detailIds, isEmpty);
        user.complete(studentUser('student'));
        await tester.pumpAndSettle();
        expect(_path(container), _location);
        expect(
          find.byKey(const Key('studentHomeworkAttemptScreen')),
          findsOneWidget,
        );
        expect(find.byType(StudentHomeworkAttemptScreen), findsOneWidget);
        expect(find.text('Homework execution'), findsOneWidget);
        expect(attempts.readIds, [_attemptId]);
        expect(homework.detailIds, [_homeworkId]);
        expect(attempts.startCalls, 0);
        expect(
          tester
              .widget<StudentHomeworkAttemptScreen>(
                find.byType(StudentHomeworkAttemptScreen),
              )
              .key,
          ValueKey(
            StudentHomeworkAttemptRouteTarget(
              topicId: studentTopicId,
              homeworkId: _homeworkId,
              attemptId: _attemptId,
            ),
          ),
        );
        await tester.tap(find.byTooltip('Back to Homework').first);
        await tester.pumpAndSettle();
        expect(_path(container), _homeworkLocation);
        expect(find.byType(StudentHomeworkDetailScreen), findsOneWidget);
        expect(attempts.startCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'invalid Attempt locations follow existing Student fallback without reads',
    (tester) async {
      for (final location in [
        '$_location?preview=true',
        '$_location#fragment',
        '$_location/extra',
        '$_homeworkLocation/attempts/bad',
        '/student/topics/bad/homework/$_homeworkId/attempts/$_attemptId',
        '/student/topics/$studentTopicId/homework/bad/attempts/$_attemptId',
        '/student/attempts/$_attemptId',
      ]) {
        final attempts = _AttemptRepository();
        final container = await _pump(
          tester,
          location: location,
          attempts: attempts,
        );
        await tester.pumpAndSettle();
        expect(_path(container), AppRoutePaths.student);
        expect(
          find.byKey(const Key('studentLearningWorkspace')),
          findsOneWidget,
        );
        expect(find.byType(StudentHomeworkAttemptScreen), findsNothing);
        expect(attempts.readIds, isEmpty);
      }
    },
  );

  testWidgets('unauthenticated and wrong-role sessions cannot load Attempt', (
    tester,
  ) async {
    for (final auth in [
      FakeAuthRepository(),
      FakeAuthRepository(
        storedToken: 'token',
        onCurrentUser: () async => studentUser('parent', role: UserRole.parent),
      ),
    ]) {
      final attempts = _AttemptRepository();
      await _pump(tester, auth: auth, attempts: attempts);
      await tester.pumpAndSettle();
      expect(find.byType(StudentHomeworkAttemptScreen), findsNothing);
      expect(attempts.readIds, isEmpty);
    }
  });

  testWidgets(
    'ineligible Student destination shows technical root without Attempt reads',
    (tester) async {
      for (final user in [
        studentUser('inactive', isActive: false),
        studentUser('inactive-school', institutionStatus: 'inactive'),
        studentUser('wrong-school', nestedInstitutionId: 'institution-2'),
      ]) {
        final attempts = _AttemptRepository();
        await _pump(
          tester,
          attempts: attempts,
          session: FakeStudentAuthSessionController.authenticated(user),
        );
        await tester.pump();
        expect(find.byType(TechnicalRootScreen), findsOneWidget);
        expect(find.byType(StudentHomeworkAttemptScreen), findsNothing);
        expect(attempts.readIds, isEmpty);
      }
    },
  );
}

String _path(ProviderContainer container) =>
    container.read(appRouterProvider).routeInformationProvider.value.uri.path;

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String location = _location,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  FakeAuthRepository? auth,
  FakeStudentAuthSessionController? session,
  _HomeworkRepository? homework,
  _AttemptRepository? attempts,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final container = ProviderContainer(
    overrides: [
      appInitialLocationProvider.overrideWithValue(location),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      authRepositoryProvider.overrideWithValue(
        auth ??
            FakeAuthRepository(
              storedToken: 'token',
              onCurrentUser: () async => studentUser('student'),
            ),
      ),
      if (session != null)
        authSessionControllerProvider.overrideWith(() => session),
      studentHomeworkRepositoryProvider.overrideWithValue(
        homework ?? _HomeworkRepository(),
      ),
      studentHomeworkAttemptRepositoryProvider.overrideWithValue(
        attempts ?? _AttemptRepository(),
      ),
      studentTopicRepositoryProvider.overrideWithValue(
        FakeStudentTopicRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

class _AttemptRepository implements StudentHomeworkAttemptRepository {
  final readIds = <String>[];
  var startCalls = 0;

  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) async {
    readIds.add(attemptId);
    return StudentHomeworkAttempt(
      id: attemptId,
      assessmentId: _homeworkId,
      attemptNumber: 1,
      status: StudentHomeworkAttemptStatus.inProgress,
      startedAt: DateTime.utc(2026, 9, 8, 12),
      submittedAt: null,
      finalizedAt: null,
      finalizationReason: null,
      deadlineAt: null,
      questions: const [],
      answers: const [],
    );
  }

  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) {
    startCalls++;
    throw StateError('Direct Attempt routing must not POST Start.');
  }
}

class _HomeworkRepository implements StudentHomeworkRepository {
  final detailIds = <String>[];

  @override
  Future<StudentHomeworkList> fetchHomework(
    StudentHomeworkListQuery query,
  ) async => StudentHomeworkList(
    items: const [],
    page: query.page,
    perPage: query.perPage,
    total: 0,
    lastPage: 1,
  );

  @override
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) async {
    detailIds.add(homeworkId);
    return StudentHomeworkDetail(
      id: homeworkId,
      topic: const StudentHomeworkTopicSummary(
        id: studentTopicId,
        title: 'Assigned Topic',
      ),
      title: 'Homework execution',
      description: null,
      studentInstructions: 'Read the assignment.',
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
      questions: const [],
    );
  }
}
