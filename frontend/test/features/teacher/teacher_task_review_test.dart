import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_review_summary.dart';

import 'teacher_submission_test_support.dart';
import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';

final _homeworkReviews =
    '/teacher/topics/$_topicId/homework/$_homeworkId/reviews';
final _blitzReviews = '/teacher/topics/$_topicId/blitz/$_blitzId/reviews';

void main() {
  test('the task review paths and helpers are exact', () {
    expect(
      AppRoutePaths.teacherHomeworkReviewsLocation(_topicId, _homeworkId),
      _homeworkReviews,
    );
    expect(
      AppRoutePaths.teacherBlitzReviewsLocation(_topicId, _blitzId),
      _blitzReviews,
    );
    expect(AppRouteNames.teacherHomeworkReviews, 'teacher-homework-reviews');
    expect(AppRouteNames.teacherBlitzReviews, 'teacher-blitz-reviews');
    expect(
      AppRoutePaths.isTeacherHomeworkReviewsPath(_homeworkReviews),
      isTrue,
    );
    expect(AppRoutePaths.isTeacherBlitzReviewsPath(_blitzReviews), isTrue);
    for (final path in [_homeworkReviews, _blitzReviews]) {
      expect(
        AppRoutePaths.isTeacherApprovedLocation(path),
        isTrue,
        reason: path,
      );
      expect(
        AppRoutePaths.teacherTopicIdFromPath(path),
        _topicId,
        reason: path,
      );
    }
    expect(
      AppRoutePaths.teacherHomeworkIdFromPath(_homeworkReviews),
      _homeworkId,
    );
    expect(AppRoutePaths.teacherBlitzIdFromPath(_blitzReviews), _blitzId);
    expect(AppRoutePaths.isTeacherHomeworkReviewsPath(_blitzReviews), isFalse);
    expect(AppRoutePaths.isTeacherBlitzReviewsPath(_homeworkReviews), isFalse);
    for (final invalid in [
      '/teacher/topics/not-a-uuid/homework/$_homeworkId/reviews',
      '/teacher/topics/$_topicId/homework/not-a-uuid/reviews',
      '/teacher/topics/$_topicId/homework/$_homeworkId/reviews/',
      '/teacher/topics/$_topicId/homework/$_homeworkId/reviews/extra',
      '/teacher/topics/$_topicId/blitz/not-a-uuid/reviews',
      '/teacher/topics/$_topicId/blitz/$_blitzId/review',
    ]) {
      expect(
        AppRoutePaths.isTeacherHomeworkReviewsPath(invalid),
        isFalse,
        reason: invalid,
      );
      expect(
        AppRoutePaths.isTeacherBlitzReviewsPath(invalid),
        isFalse,
        reason: invalid,
      );
      expect(
        AppRoutePaths.isTeacherApprovedLocation(invalid),
        isFalse,
        reason: invalid,
      );
    }
    expect(
      () =>
          AppRoutePaths.teacherHomeworkReviewsLocation(_topicId, 'not-a-uuid'),
      throwsArgumentError,
    );
  });

  testWidgets(
    'the Homework detail shows the counts and opens its queue on desktop',
    (tester) async {
      final submissions = FakeTeacherSubmissionRepository();
      await _pumpApp(
        tester,
        location: '/teacher/topics/$_topicId/homework/$_homeworkId',
        submissions: submissions,
        homework: FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(
            reviewSummary: const TeacherReviewSummary(
              waitingForTeacherReview: 4,
              overdue: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherTaskReviewSummary')),
      );

      expect(find.text('Waiting for review: 4'), findsOneWidget);
      expect(find.text('Overdue: 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('teacherTaskReviewQueueButton')));
      await tester.pumpAndSettle();

      expect(_routerPath(tester), _homeworkReviews);
      expect(find.text('Submissions of this Homework'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherReviewQueueTypeFilter')),
        findsNothing,
      );
      expect(submissions.queries.single.toQueryParameters(), {
        'topic_id': _topicId,
        'assessment_id': _homeworkId,
        'checking_status': 'waiting_for_teacher_review',
        'sort': 'default',
        'page': 1,
        'per_page': 25,
      });

      await tester.tap(find.byKey(const Key('teacherReviewQueueBackButton')));
      await tester.pumpAndSettle();
      expect(
        _routerPath(tester),
        '/teacher/topics/$_topicId/homework/$_homeworkId',
      );
    },
  );

  testWidgets(
    'the Blitz detail shows waiting only and opens its queue on desktop',
    (tester) async {
      final submissions = FakeTeacherSubmissionRepository(
        onFetch: (_) async => teacherSubmissionList([]),
      );
      await _pumpApp(
        tester,
        location: '/teacher/topics/$_topicId/blitz/$_blitzId',
        submissions: submissions,
        blitz: FakeTeacherBlitzRepository(
          onFetch: (_) async => teacherBlitz(
            id: _blitzId,
            reviewSummary: const TeacherReviewSummary(
              waitingForTeacherReview: 2,
              overdue: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherTaskReviewSummary')),
      );

      expect(find.text('Waiting for review: 2'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherTaskReviewOverdueCount')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('teacherTaskReviewQueueButton')));
      await tester.pumpAndSettle();

      expect(_routerPath(tester), _blitzReviews);
      expect(find.text('Submissions of this Blitz'), findsOneWidget);
      expect(
        find.text('No submissions of this task are waiting for review.'),
        findsOneWidget,
      );
      expect(submissions.queries.single.assessmentId, _blitzId);

      await tester.tap(find.byKey(const Key('teacherReviewQueueBackButton')));
      await tester.pumpAndSettle();
      expect(_routerPath(tester), '/teacher/topics/$_topicId/blitz/$_blitzId');
    },
  );

  testWidgets('mobile shows read-only counts and no queue button', (
    tester,
  ) async {
    for (final location in [
      '/teacher/topics/$_topicId/homework/$_homeworkId',
      '/teacher/topics/$_topicId/blitz/$_blitzId',
    ]) {
      await _pumpApp(
        tester,
        location: location,
        submissions: FakeTeacherSubmissionRepository(),
        surface: AppDeviceSurface.mobile,
        homework: FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(
            reviewSummary: const TeacherReviewSummary(
              waitingForTeacherReview: 3,
              overdue: 2,
            ),
          ),
        ),
        blitz: FakeTeacherBlitzRepository(
          onFetch: (_) async => teacherBlitz(
            id: _blitzId,
            reviewSummary: const TeacherReviewSummary(
              waitingForTeacherReview: 5,
              overdue: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherTaskReviewSummary')),
      );

      final homework = location.contains('/homework/');
      expect(
        find.text('Waiting for review: ${homework ? 3 : 5}'),
        findsOneWidget,
        reason: location,
      );
      expect(
        find.text('Overdue: 2'),
        homework ? findsOneWidget : findsNothing,
        reason: location,
      );
      expect(
        find.byKey(const Key('teacherTaskReviewOverdueCount')),
        homework ? findsOneWidget : findsNothing,
        reason: location,
      );
      expect(
        find.byKey(const Key('teacherTaskReviewQueueButton')),
        findsNothing,
        reason: location,
      );
    }
  });

  testWidgets('the queue button is hidden while the task route lease is held', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: '/teacher/topics/$_topicId/homework/$_homeworkId',
      submissions: FakeTeacherSubmissionRepository(),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherTaskReviewQueueButton')),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TestLabUzApp)),
    );
    final homeworkActivity = container.read(
      teacherHomeworkRouteMutationActivityProvider(
        TeacherHomeworkRouteTarget(topicId: _topicId, homeworkId: _homeworkId),
      ).notifier,
    );
    expect(
      homeworkActivity.begin(TeacherHomeworkRouteMutationOperation.lifecycle),
      isNotNull,
    );
    await tester.pump();
    expect(find.byKey(const Key('teacherTaskReviewQueueButton')), findsNothing);

    await _pumpApp(
      tester,
      location: '/teacher/topics/$_topicId/blitz/$_blitzId',
      submissions: FakeTeacherSubmissionRepository(),
      blitz: FakeTeacherBlitzRepository(
        onFetch: (_) async => teacherBlitz(id: _blitzId),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherTaskReviewQueueButton')),
      findsOneWidget,
    );
    final blitzContainer = ProviderScope.containerOf(
      tester.element(find.byType(TestLabUzApp)),
    );
    final blitzActivity = blitzContainer.read(
      teacherBlitzRouteMutationActivityProvider(
        TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId),
      ).notifier,
    );
    expect(
      blitzActivity.begin(TeacherBlitzRouteMutationOperation.close),
      isNotNull,
    );
    await tester.pump();
    expect(find.byKey(const Key('teacherTaskReviewQueueButton')), findsNothing);
  });

  testWidgets('desktop direct entries and bootstrap keep the task queues', (
    tester,
  ) async {
    for (final location in [_homeworkReviews, _blitzReviews]) {
      final submissions = FakeTeacherSubmissionRepository();
      await _pumpApp(tester, location: location, submissions: submissions);
      await tester.pumpAndSettle();
      expect(_routerPath(tester), location);
      expect(
        find.byKey(const Key('teacherReviewQueueScopeLabel')),
        findsOneWidget,
      );
      expect(submissions.queries, hasLength(1));

      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      await _pumpApp(
        tester,
        location: location,
        submissions: FakeTeacherSubmissionRepository(),
        auth: auth,
      );
      await tester.pump();
      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();
      expect(_routerPath(tester), location);
    }
  });

  testWidgets(
    'mobile is sent to the task detail; queries go to the workspace',
    (tester) async {
      for (final (location, expected) in [
        (_homeworkReviews, '/teacher/topics/$_topicId/homework/$_homeworkId'),
        (_blitzReviews, '/teacher/topics/$_topicId/blitz/$_blitzId'),
      ]) {
        final submissions = FakeTeacherSubmissionRepository();
        await _pumpApp(
          tester,
          location: location,
          submissions: submissions,
          surface: AppDeviceSurface.mobile,
        );
        await tester.pumpAndSettle();
        expect(_routerPath(tester), expected, reason: location);
        expect(submissions.queries, isEmpty);

        final auth = FakeTeacherAuthSessionController(
          const AuthSessionState.bootstrapping(),
        );
        await _pumpApp(
          tester,
          location: location,
          submissions: FakeTeacherSubmissionRepository(),
          surface: AppDeviceSurface.mobile,
          auth: auth,
        );
        await tester.pump();
        auth.replaceUser(teacherUser('teacher-a'));
        await tester.pumpAndSettle();
        expect(_routerPath(tester), expected, reason: 'bootstrap $location');

        for (final suffix in ['?private=1', '#fragment']) {
          await _pumpApp(
            tester,
            location: '$location$suffix',
            submissions: FakeTeacherSubmissionRepository(),
          );
          await tester.pumpAndSettle();
          expect(_routerPath(tester), AppRoutePaths.teacher, reason: suffix);
        }
      }
    },
  );

  testWidgets(
    'malformed task review entries go to the workspace; the names resolve',
    (tester) async {
      for (final location in [
        '/teacher/topics/not-a-uuid/homework/$_homeworkId/reviews',
        '/teacher/topics/$_topicId/blitz/not-a-uuid/reviews',
      ]) {
        final submissions = FakeTeacherSubmissionRepository();
        await _pumpApp(tester, location: location, submissions: submissions);
        await tester.pumpAndSettle();
        expect(_routerPath(tester), AppRoutePaths.teacher, reason: location);
        expect(submissions.queries, isEmpty);
      }

      expect(
        _router(tester).namedLocation(
          AppRouteNames.teacherHomeworkReviews,
          pathParameters: {'topicId': _topicId, 'homeworkId': _homeworkId},
        ),
        _homeworkReviews,
      );
      expect(
        _router(tester).namedLocation(
          AppRouteNames.teacherBlitzReviews,
          pathParameters: {'topicId': _topicId, 'blitzId': _blitzId},
        ),
        _blitzReviews,
      );
    },
  );
}

GoRouter _router(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(TestLabUzApp)),
  ).read(appRouterProvider);
}

String _routerPath(WidgetTester tester) =>
    _router(tester).routeInformationProvider.value.uri.path;

Future<void> _pumpApp(
  WidgetTester tester, {
  required String location,
  required FakeTeacherSubmissionRepository submissions,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  FakeTeacherAuthSessionController? auth,
  FakeTeacherHomeworkRepository? homework,
  FakeTeacherBlitzRepository? blitz,
}) async {
  await tester.binding.setSurfaceSize(
    surface == AppDeviceSurface.mobile
        ? const Size(390, 844)
        : const Size(1400, 1000),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
        teacherTopicResultRepositoryProvider.overrideWithValue(
          FakeTeacherTopicResultRepository(),
        ),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(
          FakeTeacherLearningMaterialRepository(),
        ),
        teacherHomeworkRepositoryProvider.overrideWithValue(
          homework ?? FakeTeacherHomeworkRepository(),
        ),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          FakeTeacherTopicResultPairRepository(),
        ),
        teacherBlitzRepositoryProvider.overrideWithValue(
          blitz ??
              FakeTeacherBlitzRepository(
                onFetch: (_) async => teacherBlitz(id: _blitzId),
              ),
        ),
        teacherSubmissionRepositoryProvider.overrideWithValue(submissions),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}
