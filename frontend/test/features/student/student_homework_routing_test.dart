import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/app/router/technical_root_screen.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_detail_screen.dart';

import '../../router_bootstrap_test.dart' show FakeAuthRepository;
import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _location = '/student/topics/$studentTopicId/homework/$_homeworkId';

void main() {
  test('canonical helpers classify Topic and Homework without overlap', () {
    expect(
      AppRoutePaths.studentHomeworkDetailLocation(studentTopicId, _homeworkId),
      _location,
    );
    expect(AppRouteNames.studentHomeworkDetail, 'student-homework-detail');
    expect(AppRoutePaths.isStudentApprovedLocation(_location), isTrue);
    expect(AppRoutePaths.isStudentHomeworkDetailPath(_location), isTrue);
    expect(AppRoutePaths.isStudentTopicDetailPath(_location), isFalse);
    expect(AppRoutePaths.studentTopicIdFromPath(_location), studentTopicId);
    expect(AppRoutePaths.studentHomeworkIdFromPath(_location), _homeworkId);
    final topic = AppRoutePaths.studentTopicDetailLocation(studentTopicId);
    expect(AppRoutePaths.isStudentTopicDetailPath(topic), isTrue);
    expect(AppRoutePaths.isStudentHomeworkDetailPath(topic), isFalse);
    expect(AppRoutePaths.studentTopicIdFromPath(topic), studentTopicId);
    expect(AppRoutePaths.studentHomeworkIdFromPath(topic), isNull);
    expect(AppRoutePaths.isStudentApprovedLocation('/student'), isTrue);
    expect(AppRoutePaths.studentTopicIdFromPath('/student'), isNull);
    expect(AppRoutePaths.studentHomeworkIdFromPath('/student'), isNull);
  });

  test(
    'helpers reject malformed UUIDs, aliases, suffixes and extra segments',
    () {
      for (final invalidId in [
        'bad',
        '',
        ' $_homeworkId',
        '$_homeworkId/extra',
      ]) {
        expect(
          () => AppRoutePaths.studentHomeworkDetailLocation(
            invalidId,
            _homeworkId,
          ),
          throwsArgumentError,
        );
        expect(
          () => AppRoutePaths.studentHomeworkDetailLocation(
            studentTopicId,
            invalidId,
          ),
          throwsArgumentError,
        );
      }
      for (final path in [
        '$_location/',
        '$_location/extra',
        '$_location/edit',
        '$_location/questions',
        '$_location/attempts',
        '$_location?preview=true',
        '$_location#fragment',
        '/student/topics/bad/homework/$_homeworkId',
        '/student/topics/$studentTopicId/homework/bad',
        '/student/topics/$studentTopicId/homework/new',
        '/student/topics/$studentTopicId/homework',
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
          AppRoutePaths.studentTopicIdFromPath(path),
          isNull,
          reason: path,
        );
        expect(
          AppRoutePaths.studentHomeworkIdFromPath(path),
          isNull,
          reason: path,
        );
      }
    },
  );

  test('route target identity includes both canonical IDs', () {
    final target = StudentHomeworkRouteTarget(
      topicId: studentTopicId,
      homeworkId: _homeworkId,
    );
    final same = StudentHomeworkRouteTarget(
      topicId: studentTopicId,
      homeworkId: _homeworkId,
    );
    expect(target, same);
    expect(target.hashCode, same.hashCode);
    expect(
      target,
      isNot(
        StudentHomeworkRouteTarget(
          topicId: _homeworkId,
          homeworkId: _homeworkId,
        ),
      ),
    );
    expect(
      target,
      isNot(
        StudentHomeworkRouteTarget(
          topicId: studentTopicId,
          homeworkId: studentTopicId,
        ),
      ),
    );
    expect(
      () => StudentHomeworkRouteTarget(topicId: 'bad', homeworkId: _homeworkId),
      throwsArgumentError,
    );
    expect(
      () => StudentHomeworkRouteTarget(
        topicId: studentTopicId,
        homeworkId: 'bad',
      ),
      throwsArgumentError,
    );
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} bootstrap preserves frozen-assignment deep link and canonical back',
      (tester) async {
        final user = Completer<AuthUser>();
        final auth = FakeAuthRepository(
          storedToken: 'token',
          onCurrentUser: () => user.future,
        );
        final homework = _HomeworkRepository();
        final topics = FakeStudentTopicRepository(
          onFetchTopic: (_) async => throw studentServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final container = await _pump(
          tester,
          auth: auth,
          homework: homework,
          topics: topics,
          surface: surface,
        );
        expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          _location,
        );
        expect(find.byType(TechnicalRootScreen), findsOneWidget);
        expect(homework.detailIds, isEmpty);
        user.complete(studentUser('assigned-student'));
        await tester.pumpAndSettle();
        expect(find.byType(StudentHomeworkDetailScreen), findsOneWidget);
        expect(
          find.byKey(const Key('studentHomeworkDetailScreen')),
          findsOneWidget,
        );
        expect(find.text('Frozen assignment Homework'), findsOneWidget);
        expect(homework.detailIds, [_homeworkId]);
        expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          _location,
        );
        final screen = tester.widget<StudentHomeworkDetailScreen>(
          find.byType(StudentHomeworkDetailScreen),
        );
        expect(
          screen.key,
          ValueKey(
            StudentHomeworkRouteTarget(
              topicId: studentTopicId,
              homeworkId: _homeworkId,
            ),
          ),
        );

        await tester.tap(find.byTooltip('Back to Topic'));
        await tester.pumpAndSettle();
        expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          AppRoutePaths.studentTopicDetailLocation(studentTopicId),
        );
        expect(
          find.byKey(const Key('studentTopicUnavailable')),
          findsOneWidget,
        );
        expect(topics.detailIds, isNotEmpty);
        expect(homework.detailIds, [_homeworkId]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('current Topic summary opens its canonical Homework detail', (
    tester,
  ) async {
    final homework = _HomeworkRepository(
      listItems: const [
        StudentHomeworkSummary(
          id: _homeworkId,
          topic: StudentHomeworkTopicSummary(
            id: studentTopicId,
            title: 'Internet Basics',
          ),
          title: 'Assigned Homework',
          status: StudentHomeworkStatus.active,
          deadlineAt: null,
          attempts: StudentHomeworkAttemptSummary(
            allowed: 3,
            used: 0,
            remaining: 3,
            officialScorePolicy: 'highest_valid_completed',
          ),
          myStatus: StudentHomeworkMyStatus.notStarted,
          scoreVisible: false,
        ),
      ],
    );
    final container = await _pump(
      tester,
      homework: homework,
      location: AppRoutePaths.studentTopicDetailLocation(studentTopicId),
    );
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('studentHomeworkOpen$_homeworkId'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      _location,
    );
    expect(find.byType(StudentHomeworkDetailScreen), findsOneWidget);
    expect(homework.detailIds, [_homeworkId]);
  });

  testWidgets(
    'query, fragment and malformed routes use existing Student fallback',
    (tester) async {
      for (final location in [
        '$_location?preview=true',
        '$_location#fragment',
        '$_location/extra',
        '/student/topics/bad/homework/$_homeworkId',
        '/student/topics/$studentTopicId/homework/bad',
      ]) {
        final homework = _HomeworkRepository();
        final container = await _pump(
          tester,
          homework: homework,
          location: location,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('studentLearningWorkspace')),
          findsOneWidget,
        );
        expect(find.byType(StudentHomeworkDetailScreen), findsNothing);
        expect(homework.detailIds, isEmpty);
        expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          AppRoutePaths.student,
        );
      }
    },
  );

  testWidgets('unauthenticated and wrong-role users cannot load Homework', (
    tester,
  ) async {
    for (final auth in [
      FakeAuthRepository(),
      FakeAuthRepository(
        storedToken: 'token',
        onCurrentUser: () async => studentUser('parent', role: UserRole.parent),
      ),
    ]) {
      final homework = _HomeworkRepository();
      await _pump(tester, auth: auth, homework: homework);
      await tester.pumpAndSettle();
      expect(find.byType(StudentHomeworkDetailScreen), findsNothing);
      expect(homework.detailIds, isEmpty);
    }
  });

  testWidgets(
    'Student destination gate keeps ineligible session at technical root',
    (tester) async {
      for (final user in [
        studentUser('inactive', isActive: false),
        studentUser('inactive-school', institutionStatus: 'inactive'),
        studentUser('wrong-school', nestedInstitutionId: 'institution-2'),
      ]) {
        final homework = _HomeworkRepository();
        await _pump(
          tester,
          homework: homework,
          session: FakeStudentAuthSessionController.authenticated(user),
        );
        await tester.pump();
        expect(find.byType(TechnicalRootScreen), findsOneWidget);
        expect(find.byType(StudentHomeworkDetailScreen), findsNothing);
        expect(homework.detailIds, isEmpty);
      }
    },
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String location = _location,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  FakeAuthRepository? auth,
  FakeStudentAuthSessionController? session,
  _HomeworkRepository? homework,
  FakeStudentTopicRepository? topics,
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
      studentTopicRepositoryProvider.overrideWithValue(
        topics ?? FakeStudentTopicRepository(),
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

class _HomeworkRepository implements StudentHomeworkRepository {
  _HomeworkRepository({this.listItems = const []});

  final List<StudentHomeworkSummary> listItems;
  final detailIds = <String>[];

  @override
  Future<StudentHomeworkList> fetchHomework(
    StudentHomeworkListQuery query,
  ) async => StudentHomeworkList(
    items: listItems,
    page: query.page,
    perPage: query.perPage,
    total: listItems.length,
    lastPage: 1,
  );

  @override
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) async {
    detailIds.add(homeworkId);
    return StudentHomeworkDetail(
      id: homeworkId,
      topic: const StudentHomeworkTopicSummary(
        id: studentTopicId,
        title: 'Historical Topic',
      ),
      title: 'Frozen assignment Homework',
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
