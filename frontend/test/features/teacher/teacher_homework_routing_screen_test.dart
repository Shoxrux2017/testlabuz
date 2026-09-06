import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  test('Homework route helpers accept only the canonical nested path', () {
    final location = AppRoutePaths.teacherHomeworkDetailLocation(
      _topicId,
      _homeworkId,
    );

    expect(location, '/teacher/topics/$_topicId/homework/$_homeworkId');
    expect(AppRoutePaths.isTeacherHomeworkDetailPath(location), isTrue);
    expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);
    expect(AppRoutePaths.teacherHomeworkIdFromPath(location), _homeworkId);
    expect(AppRoutePaths.isTeacherTopicDetailPath(location), isFalse);
    expect(AppRoutePaths.isTeacherTopicEditPath(location), isFalse);

    for (final invalid in [
      '/teacher/topics/not-a-uuid/homework/$_homeworkId',
      '/teacher/topics/$_topicId/homework/not-a-uuid',
      '/teacher/topics/$_topicId/homework/$_homeworkId/extra',
      '/teacher/topics/$_topicId/homework/$_homeworkId/',
    ]) {
      expect(AppRoutePaths.isTeacherHomeworkDetailPath(invalid), isFalse);
      expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
    }

    expect(
      () => AppRoutePaths.teacherHomeworkDetailLocation(
        'not-a-uuid',
        _homeworkId,
      ),
      throwsArgumentError,
    );
    expect(
      () => AppRoutePaths.teacherHomeworkDetailLocation(_topicId, 'not-a-uuid'),
      throwsArgumentError,
    );
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets('${surface.name} supports direct Homework detail entry', (
      tester,
    ) async {
      if (surface == AppDeviceSurface.mobile) {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }
      final homework = FakeTeacherHomeworkRepository();

      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherHomeworkDetailLocation(
          _topicId,
          _homeworkId,
        ),
        homework: homework,
        surface: surface,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherHomeworkDetailScreen')),
        findsOneWidget,
      );
      expect(homework.fetchIds, [_homeworkId]);
      expect(find.text('Equation practice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Homework detail deep link survives Teacher bootstrap', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    final homework = FakeTeacherHomeworkRepository();

    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkDetailLocation(
        _topicId,
        _homeworkId,
      ),
      homework: homework,
      auth: auth,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pump();

    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
    expect(homework.fetchIds, isEmpty);

    auth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );
    expect(homework.fetchIds, [_homeworkId]);
  });

  testWidgets(
    'malformed Homework paths plus query and fragment redirect without GET',
    (tester) async {
      for (final location in [
        '/teacher/topics/not-a-uuid/homework/$_homeworkId',
        '/teacher/topics/$_topicId/homework/not-a-uuid',
        '/teacher/topics/$_topicId/homework/$_homeworkId/extra',
        '/teacher/topics/$_topicId/homework/$_homeworkId/',
        '/teacher/topics/$_topicId/homework/$_homeworkId?private=1',
        '/teacher/topics/$_topicId/homework/$_homeworkId#fragment',
      ]) {
        final homework = FakeTeacherHomeworkRepository();
        await _pumpApp(tester, location: location, homework: homework);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('teacherLearningWorkspace')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('teacherHomeworkDetailScreen')),
          findsNothing,
        );
        expect(homework.fetchIds, isEmpty);
      }
    },
  );

  testWidgets('Homework card pushes detail and Back returns to Topic', (
    tester,
  ) async {
    final homework = FakeTeacherHomeworkRepository(
      onFetchList: (topicId, query) async => teacherHomeworkList(
        items: [teacherHomeworkSummary()],
        page: query.page,
        perPage: query.perPage,
        total: 1,
      ),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
      homework: homework,
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('teacherHomeworkCard$_homeworkId'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );
    expect(homework.fetchIds, [_homeworkId]);

    await tester.tap(find.byKey(const Key('teacherHomeworkBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
  });

  testWidgets('direct-entry Back returns to the canonical Topic fallback', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkDetailLocation(
        _topicId,
        _homeworkId,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherHomeworkBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String location,
  FakeTeacherHomeworkRepository? homework,
  FakeTeacherAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(location),
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeTeacherAuthSessionController.authenticated(
                teacherUser('teacher-a'),
              ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherGroupListRepositoryProvider.overrideWithValue(
          FakeTeacherGroupListRepository(),
        ),
        teacherTopicListRepositoryProvider.overrideWithValue(
          FakeTeacherTopicListRepository(),
        ),
        teacherTopicRepositoryProvider.overrideWithValue(
          FakeTeacherTopicRepository(),
        ),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(
          FakeTeacherLearningMaterialRepository(),
        ),
        teacherHomeworkRepositoryProvider.overrideWithValue(
          homework ?? FakeTeacherHomeworkRepository(),
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}
