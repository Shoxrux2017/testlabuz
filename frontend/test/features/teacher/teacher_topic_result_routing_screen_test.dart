import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';

import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

const _topicId = teacherResultTopicId;
const _studentId = teacherResultStudentId;

void main() {
  test('the results route helpers accept only the canonical path', () {
    final location = AppRoutePaths.teacherTopicResultsLocation(_topicId);

    expect(location, '/teacher/topics/$_topicId/results');
    expect(AppRouteNames.teacherTopicResults, 'teacher-topic-results');
    expect(
      AppRoutePaths.teacherTopicResults,
      '/teacher/topics/:topicId/results',
    );
    expect(AppRoutePaths.isTeacherTopicResultsPath(location), isTrue);
    expect(AppRoutePaths.isTeacherTopicResultDetailPath(location), isFalse);
    expect(AppRoutePaths.isTeacherTopicDetailPath(location), isFalse);
    expect(AppRoutePaths.isTeacherApprovedLocation(location), isTrue);
    expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);

    final uppercase = AppRoutePaths.teacherTopicResultsLocation(
      _topicId.toUpperCase(),
    );
    expect(AppRoutePaths.isTeacherTopicResultsPath(uppercase), isTrue);

    for (final invalid in [
      '/teacher/topics/not-a-uuid/results',
      '/teacher/topics/new/results',
      '/teacher/topics/$_topicId/result',
      '/teacher/topics/$_topicId/results/',
      '/teacher/topics/$_topicId/results?status=closed',
      '/teacher/topics/$_topicId/results#fragment',
    ]) {
      expect(
        AppRoutePaths.isTeacherTopicResultsPath(invalid),
        isFalse,
        reason: invalid,
      );
      expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
      expect(AppRoutePaths.teacherTopicIdFromPath(invalid), isNull);
    }
    for (final invalid in ['not-a-uuid', ' $_topicId', 'new']) {
      expect(
        () => AppRoutePaths.teacherTopicResultsLocation(invalid),
        throwsArgumentError,
      );
    }
  });

  test('the result detail route helpers accept only the canonical path', () {
    final location = AppRoutePaths.teacherTopicResultDetailLocation(
      _topicId,
      _studentId,
    );

    expect(location, '/teacher/topics/$_topicId/results/$_studentId');
    expect(
      AppRouteNames.teacherTopicResultDetail,
      'teacher-topic-result-detail',
    );
    expect(
      AppRoutePaths.teacherTopicResultDetail,
      '/teacher/topics/:topicId/results/:studentId',
    );
    expect(AppRoutePaths.isTeacherTopicResultDetailPath(location), isTrue);
    expect(AppRoutePaths.isTeacherTopicResultsPath(location), isFalse);
    expect(AppRoutePaths.isTeacherApprovedLocation(location), isTrue);
    expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);
    expect(AppRoutePaths.teacherHomeworkIdFromPath(location), isNull);
    expect(AppRoutePaths.teacherBlitzIdFromPath(location), isNull);

    for (final invalid in [
      '/teacher/topics/not-a-uuid/results/$_studentId',
      '/teacher/topics/$_topicId/results/not-a-uuid',
      '/teacher/topics/$_topicId/results/$_studentId/',
      '/teacher/topics/$_topicId/results/$_studentId/extra',
      '/teacher/topics/$_topicId/homework/$_studentId/results',
      '/teacher/topics/$_topicId/results/$_studentId?private=1',
    ]) {
      expect(
        AppRoutePaths.isTeacherTopicResultDetailPath(invalid),
        isFalse,
        reason: invalid,
      );
      expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
      expect(AppRoutePaths.teacherTopicIdFromPath(invalid), isNull);
    }
    for (final (topicId, studentId) in [
      ('not-a-uuid', _studentId),
      (_topicId, 'not-a-uuid'),
      (_topicId, '$_studentId '),
    ]) {
      expect(
        () =>
            AppRoutePaths.teacherTopicResultDetailLocation(topicId, studentId),
        throwsArgumentError,
      );
    }
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets('${surface.name} opens the results list directly', (
      tester,
    ) async {
      await _useSurface(tester, surface);
      final results = _resultsWithOneRow();
      final location = AppRoutePaths.teacherTopicResultsLocation(_topicId);

      await _pumpApp(
        tester,
        location: location,
        results: results,
        surface: surface,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherTopicResultsScreen')),
        findsOneWidget,
      );
      expect(_routerPath(tester), location);
      expect(results.listRequests.first.topicId, _topicId);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${surface.name} opens one result directly', (tester) async {
      await _useSurface(tester, surface);
      final results = FakeTeacherTopicResultRepository();
      final location = AppRoutePaths.teacherTopicResultDetailLocation(
        _topicId,
        _studentId,
      );

      await _pumpApp(
        tester,
        location: location,
        results: results,
        surface: surface,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherTopicResultDetailScreen')),
        findsOneWidget,
      );
      expect(_routerPath(tester), location);
      expect(results.detailRequests, [
        (topicId: _topicId, studentId: _studentId),
      ]);
    });

    testWidgets('${surface.name} a result deep link survives bootstrap', (
      tester,
    ) async {
      await _useSurface(tester, surface);
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      final results = FakeTeacherTopicResultRepository();
      final location = AppRoutePaths.teacherTopicResultDetailLocation(
        _topicId,
        _studentId,
      );

      await _pumpApp(
        tester,
        location: location,
        results: results,
        auth: auth,
        surface: surface,
      );
      await tester.pump();
      expect(results.detailRequests, isEmpty);

      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();

      expect(_routerPath(tester), location);
      expect(
        find.byKey(const Key('teacherTopicResultDetailScreen')),
        findsOneWidget,
      );
      expect(results.detailRequests, hasLength(1));
    });

    testWidgets(
      '${surface.name} the Topic detail shows the results card first',
      (tester) async {
        await _useSurface(tester, surface);
        await _pumpApp(
          tester,
          location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
          results: _resultsWithOneRow(),
          surface: surface,
        );
        await tester.pumpAndSettle();

        final card = find.byKey(const Key('teacherTopicResultsCard'));
        expect(card, findsOneWidget);
        expect(find.text('Calculated: 1'), findsOneWidget);
        final information = find.text('Topic information');
        await tester.ensureVisible(information);
        expect(
          tester.getTopLeft(card).dy,
          lessThan(tester.getTopLeft(information).dy),
        );
      },
    );
  }

  testWidgets('Open results, a row and Back walk the result routes', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
      results: _resultsWithOneRow(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherTopicResultsOpenButton')));
    await tester.pumpAndSettle();
    expect(
      _routerPath(tester),
      AppRoutePaths.teacherTopicResultsLocation(_topicId),
    );

    await tester.tap(
      find.byKey(const Key('teacherTopicResultRow:$teacherResultStudentId')),
    );
    await tester.pumpAndSettle();
    expect(
      _routerPath(tester),
      AppRoutePaths.teacherTopicResultDetailLocation(_topicId, _studentId),
    );
    expect(find.text('Final result'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherTopicResultBackButton')));
    await tester.pumpAndSettle();
    expect(
      _routerPath(tester),
      AppRoutePaths.teacherTopicResultsLocation(_topicId),
    );

    await tester.tap(find.byKey(const Key('teacherTopicResultsBackButton')));
    await tester.pumpAndSettle();
    expect(
      _routerPath(tester),
      AppRoutePaths.teacherTopicDetailLocation(_topicId),
    );
  });

  testWidgets('direct-entry Back returns to the parent locations', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicResultDetailLocation(
        _topicId,
        _studentId,
      ),
      results: _resultsWithOneRow(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherTopicResultBackButton')));
    await tester.pumpAndSettle();
    expect(
      _routerPath(tester),
      AppRoutePaths.teacherTopicResultsLocation(_topicId),
    );

    await tester.tap(find.byKey(const Key('teacherTopicResultsBackButton')));
    await tester.pumpAndSettle();
    expect(
      _routerPath(tester),
      AppRoutePaths.teacherTopicDetailLocation(_topicId),
    );
  });

  testWidgets('a non-Teacher role does not gain the result routes', (
    tester,
  ) async {
    final results = FakeTeacherTopicResultRepository();
    for (final location in [
      AppRoutePaths.teacherTopicResultsLocation(_topicId),
      AppRoutePaths.teacherTopicResultDetailLocation(_topicId, _studentId),
    ]) {
      await _pumpApp(
        tester,
        location: location,
        results: results,
        auth: FakeTeacherAuthSessionController.authenticated(
          teacherUser('student-a', role: UserRole.student),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacherTopicResultsScreen')), findsNothing);
      expect(
        find.byKey(const Key('teacherTopicResultDetailScreen')),
        findsNothing,
      );
    }
    expect(results.listRequests, isEmpty);
    expect(results.detailRequests, isEmpty);
  });

  testWidgets('malformed result paths fall back to the Teacher root', (
    tester,
  ) async {
    for (final location in [
      '/teacher/topics/$_topicId/results/not-a-uuid',
      '/teacher/topics/$_topicId/results/$_studentId/extra',
      '/teacher/topics/$_topicId/results?result_status=closed',
      '/teacher/topics/$_topicId/results/$_studentId#visibility',
    ]) {
      final results = FakeTeacherTopicResultRepository();
      await _pumpApp(tester, location: location, results: results);
      await tester.pumpAndSettle();

      expect(_routerPath(tester), AppRoutePaths.teacher, reason: location);
      expect(results.detailRequests, isEmpty);
    }
  });
}

FakeTeacherTopicResultRepository _resultsWithOneRow() {
  return FakeTeacherTopicResultRepository(
    onFetchResults: (_, query) async => teacherTopicResultList(query: query),
  );
}

Future<void> _useSurface(WidgetTester tester, AppDeviceSurface surface) async {
  if (surface == AppDeviceSurface.mobile) {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
}

String _routerPath(WidgetTester tester) {
  final router = ProviderScope.containerOf(
    tester.element(find.byType(TestLabUzApp)),
  ).read(appRouterProvider);
  return router.routeInformationProvider.value.uri.path;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String location,
  required FakeTeacherTopicResultRepository results,
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
          FakeTeacherHomeworkRepository(),
        ),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          FakeTeacherTopicResultPairRepository(),
        ),
        teacherBlitzRepositoryProvider.overrideWithValue(
          FakeTeacherBlitzRepository(),
        ),
        teacherTopicResultRepositoryProvider.overrideWithValue(results),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}
