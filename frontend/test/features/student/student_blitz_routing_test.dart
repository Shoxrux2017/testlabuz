import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/app/router/technical_root_screen.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_repository.dart';
import 'package:testlabuz_client/features/student/presentation/student_blitz_detail_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_read_view.dart';

import '../../router_bootstrap_test.dart' show FakeAuthRepository;
import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

const _location = '/student/topics/$studentTopicId/blitz/$studentBlitzId';

void main() {
  test('canonical helpers classify the Blitz route without overlap', () {
    expect(
      AppRoutePaths.studentBlitzDetailLocation(studentTopicId, studentBlitzId),
      _location,
    );
    expect(AppRouteNames.studentBlitzDetail, 'student-blitz-detail');
    expect(AppRoutePaths.isStudentBlitzDetailPath(_location), isTrue);
    expect(AppRoutePaths.isStudentApprovedLocation(_location), isTrue);
    expect(AppRoutePaths.isStudentTopicDetailPath(_location), isFalse);
    expect(AppRoutePaths.isStudentHomeworkDetailPath(_location), isFalse);
    expect(AppRoutePaths.isStudentHomeworkAttemptPath(_location), isFalse);
    expect(AppRoutePaths.studentTopicIdFromPath(_location), studentTopicId);
    expect(AppRoutePaths.studentBlitzIdFromPath(_location), studentBlitzId);
    expect(AppRoutePaths.studentHomeworkIdFromPath(_location), isNull);

    const homework = '/student/topics/$studentTopicId/homework/$studentBlitzId';
    expect(AppRoutePaths.isStudentHomeworkDetailPath(homework), isTrue);
    expect(AppRoutePaths.isStudentBlitzDetailPath(homework), isFalse);
    expect(AppRoutePaths.studentBlitzIdFromPath(homework), isNull);
    final topic = AppRoutePaths.studentTopicDetailLocation(studentTopicId);
    expect(AppRoutePaths.isStudentTopicDetailPath(topic), isTrue);
    expect(AppRoutePaths.isStudentBlitzDetailPath(topic), isFalse);
  });

  test('malformed, extended and Attempt-shaped Blitz paths are rejected', () {
    for (final path in [
      '$_location/',
      '$_location/attempts',
      '$_location/attempts/$studentBlitzAttemptId',
      '$_location?start=true',
      '$_location#questions',
      '/student/topics/bad/blitz/$studentBlitzId',
      '/student/topics/$studentTopicId/blitz/bad',
      '/student/topics/$studentTopicId/blitz/active',
      '/student/topics/$studentTopicId/blitz',
      '/student/blitz/$studentBlitzId',
    ]) {
      expect(
        AppRoutePaths.isStudentBlitzDetailPath(path),
        isFalse,
        reason: path,
      );
      expect(
        AppRoutePaths.isStudentApprovedLocation(path),
        isFalse,
        reason: path,
      );
      expect(AppRoutePaths.studentBlitzIdFromPath(path), isNull, reason: path);
    }
    for (final invalid in [
      '',
      'bad',
      ' $studentBlitzId',
      '$studentBlitzId/x',
    ]) {
      expect(
        () => AppRoutePaths.studentBlitzDetailLocation(studentTopicId, invalid),
        throwsArgumentError,
      );
      expect(
        () => AppRoutePaths.studentBlitzDetailLocation(invalid, studentBlitzId),
        throwsArgumentError,
      );
    }
  });

  test('route target identity is both canonical IDs and no Attempt', () {
    final target = StudentBlitzRouteTarget(
      topicId: studentTopicId.toUpperCase(),
      blitzId: studentBlitzId.toUpperCase(),
    );
    final same = StudentBlitzRouteTarget(
      topicId: studentTopicId,
      blitzId: studentBlitzId,
    );
    expect(target, same);
    expect(target.hashCode, same.hashCode);
    expect(target.blitzId, studentBlitzId);
    expect(
      target,
      isNot(
        StudentBlitzRouteTarget(
          topicId: studentTopicId,
          blitzId: otherStudentBlitzId,
        ),
      ),
    );
    expect(
      () => StudentBlitzRouteTarget(topicId: 'bad', blitzId: studentBlitzId),
      throwsArgumentError,
    );
    expect(
      () => StudentBlitzRouteTarget(topicId: studentTopicId, blitzId: 'bad'),
      throwsArgumentError,
    );
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} direct entry keeps the route and never auto-starts',
      (tester) async {
        final user = Completer<AuthUser>();
        final blitz = FakeStudentBlitzRepository(
          onFetchBlitz: (_) async => inProgressBlitzDetail(),
        );
        final attempts = FakeStudentBlitzAttemptRepository();
        final container = await _pump(
          tester,
          surface: surface,
          auth: FakeAuthRepository(
            storedToken: 'token',
            onCurrentUser: () => user.future,
          ),
          blitz: blitz,
          attempts: attempts,
        );
        expect(_path(container), _location);
        expect(find.byType(TechnicalRootScreen), findsOneWidget);
        expect(blitz.detailIds, isEmpty);

        user.complete(studentUser('assigned-student'));
        await tester.pumpAndSettle();
        expect(find.byType(StudentBlitzDetailScreen), findsOneWidget);
        expect(_path(container), _location);
        expect(blitz.detailIds, [studentBlitzId]);
        expect(
          find.byKey(const Key('studentBlitzResumeButton')),
          findsOneWidget,
        );
        expect(find.byType(StudentQuestionReadView), findsNothing);
        expect(attempts.requests, isEmpty);
        final screen = tester.widget<StudentBlitzDetailScreen>(
          find.byType(StudentBlitzDetailScreen),
        );
        expect(
          screen.key,
          ValueKey(
            StudentBlitzRouteTarget(
              topicId: studentTopicId,
              blitzId: studentBlitzId,
            ),
          ),
        );

        await tester.tap(find.byTooltip('Back to Topic'));
        await tester.pumpAndSettle();
        expect(
          _path(container),
          AppRoutePaths.studentTopicDetailLocation(studentTopicId),
        );
        expect(attempts.requests, isEmpty);
      },
    );
  }

  testWidgets('query, fragment, Attempt and malformed routes fall back', (
    tester,
  ) async {
    for (final location in [
      '$_location?start=true',
      '$_location#questions',
      '$_location/attempts/$studentBlitzAttemptId',
      '/student/topics/bad/blitz/$studentBlitzId',
      '/student/topics/$studentTopicId/blitz/bad',
    ]) {
      final blitz = FakeStudentBlitzRepository();
      final container = await _pump(tester, location: location, blitz: blitz);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('studentLearningWorkspace')), findsOneWidget);
      expect(find.byType(StudentBlitzDetailScreen), findsNothing);
      expect(blitz.detailIds, isEmpty);
      expect(_path(container), AppRoutePaths.student);
    }
  });

  testWidgets('unauthenticated and wrong-role users cannot load a Blitz', (
    tester,
  ) async {
    for (final auth in [
      FakeAuthRepository(),
      FakeAuthRepository(
        storedToken: 'token',
        onCurrentUser: () async => studentUser('parent', role: UserRole.parent),
      ),
      FakeAuthRepository(
        storedToken: 'token',
        onCurrentUser: () async =>
            studentUser('teacher', role: UserRole.teacher),
      ),
    ]) {
      final blitz = FakeStudentBlitzRepository();
      await _pump(tester, auth: auth, blitz: blitz);
      await tester.pumpAndSettle();
      expect(find.byType(StudentBlitzDetailScreen), findsNothing);
      expect(blitz.detailIds, isEmpty);
    }
  });
}

String _path(ProviderContainer container) =>
    container.read(appRouterProvider).routeInformationProvider.value.uri.path;

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String location = _location,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  FakeAuthRepository? auth,
  FakeStudentBlitzRepository? blitz,
  FakeStudentBlitzAttemptRepository? attempts,
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
      studentBlitzRepositoryProvider.overrideWithValue(
        blitz ??
            FakeStudentBlitzRepository(
              onFetchBlitz: (_) async => individualBlitzDetail(),
            ),
      ),
      studentBlitzAttemptRepositoryProvider.overrideWithValue(
        attempts ?? FakeStudentBlitzAttemptRepository(),
      ),
      studentTopicRepositoryProvider.overrideWithValue(
        FakeStudentTopicRepository(),
      ),
      studentHomeworkRepositoryProvider.overrideWithValue(_NoHomework()),
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

class _NoHomework implements StudentHomeworkRepository {
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
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) =>
      throw UnimplementedError();
}
