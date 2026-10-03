import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_filter.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_scope.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_list_query.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_review_queue_screen.dart';

import 'teacher_submission_test_support.dart';
import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _groupId = '20000000-0000-0000-0000-000000000001';
const _studentId = '60000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  group('review queue query and scopes', () {
    test('Topic, group and Student filters are sent and restart paging', () {
      final query = const TeacherSubmissionListQuery.initial()
          .withPage(3)
          .withTopic(_topicId)
          .withGroup(_groupId)
          .withStudent(_studentId);

      expect(query.page, 1);
      expect(query.toQueryParameters(), {
        'topic_id': _topicId,
        'group_id': _groupId,
        'student_id': _studentId,
        'checking_status': 'waiting_for_teacher_review',
        'sort': 'default',
        'page': 1,
        'per_page': 25,
      });
      expect(query.withGroup(null).toQueryParameters()['group_id'], isNull);
      expect(query, isNot(query.withStudent(null)));
    });

    test('a Student scope fixes the Topic and the Student, every status', () {
      final scope = TeacherReviewQueueScope.student(
        topicId: _topicId.toUpperCase(),
        studentId: _studentId.toUpperCase(),
      );

      expect(scope.initialQuery.toQueryParameters(), {
        'topic_id': _topicId,
        'student_id': _studentId,
        'sort': 'default',
        'page': 1,
        'per_page': 25,
      });
      expect(
        scope,
        TeacherReviewQueueScope.student(
          topicId: _topicId,
          studentId: _studentId,
        ),
      );
      expect(scope.fixes(TeacherReviewQueueFilterKind.topic), isTrue);
      expect(scope.fixes(TeacherReviewQueueFilterKind.student), isTrue);
      expect(scope.fixes(TeacherReviewQueueFilterKind.group), isTrue);
      expect(
        () => TeacherReviewQueueScope.student(
          topicId: 'topic-1',
          studentId: _studentId,
        ),
        throwsArgumentError,
      );
      for (final kind in TeacherReviewQueueFilterKind.values) {
        expect(TeacherReviewQueueScope.all.fixes(kind), isFalse);
      }
    });
  });

  group('review queue controller filters', () {
    test('a row filter applies, shows its label and can be removed', () async {
      final harness = _ControllerHarness(TeacherReviewQueueScope.all);
      await harness.ready();

      harness.controller.filterByRow(
        const TeacherReviewQueueRowFilter(
          kind: TeacherReviewQueueFilterKind.student,
          id: _studentId,
          label: 'Aziza Karimova',
        ),
      );
      await flushTeacherControllers();
      expect(harness.state.query.studentId, _studentId);
      expect(harness.state.filterLabels, {
        TeacherReviewQueueFilterKind.student: 'Aziza Karimova',
      });
      expect(harness.repository.queries.last.studentId, _studentId);

      harness.controller.removeRowFilter(TeacherReviewQueueFilterKind.student);
      await flushTeacherControllers();
      expect(harness.state.query.studentId, isNull);
      expect(harness.state.filterLabels, isEmpty);
    });

    test('Clear filters removes the row filters too', () async {
      final harness = _ControllerHarness(TeacherReviewQueueScope.all);
      await harness.ready();
      harness.controller
        ..filterByRow(
          const TeacherReviewQueueRowFilter(
            kind: TeacherReviewQueueFilterKind.group,
            id: _groupId,
            label: '7-A',
          ),
        )
        ..filterByRow(
          const TeacherReviewQueueRowFilter(
            kind: TeacherReviewQueueFilterKind.topic,
            id: _topicId,
            label: 'Internet Basics',
          ),
        );
      await flushTeacherControllers();

      harness.controller.clearFilters();
      await flushTeacherControllers();

      expect(harness.state.query, TeacherReviewQueueScope.all.initialQuery);
      expect(harness.state.filterLabels, isEmpty);
    });

    test('a scope never loses what it fixes', () async {
      final scope = TeacherReviewQueueScope.student(
        topicId: _topicId,
        studentId: _studentId,
      );
      final harness = _ControllerHarness(scope);
      await harness.ready();
      final requests = harness.repository.queries.length;

      harness.controller
        ..filterByRow(
          const TeacherReviewQueueRowFilter(
            kind: TeacherReviewQueueFilterKind.topic,
            id: '10000000-0000-0000-0000-000000000002',
            label: 'Other Topic',
          ),
        )
        ..removeRowFilter(TeacherReviewQueueFilterKind.student);
      await flushTeacherControllers();

      expect(harness.repository.queries.length, requests);
      expect(harness.state.query, scope.initialQuery);
    });
  });

  group('review queue screen filters', () {
    testWidgets('a row filters by its Student and the chip removes it', (
      tester,
    ) async {
      final repository = FakeTeacherSubmissionRepository(
        onFetch: (query) async => teacherSubmissionList([teacherSubmission()]),
      );
      await _pumpQueue(tester, const TeacherReviewQueueScreen(), repository);

      await tester.tap(
        find.byKey(const Key('teacherReviewQueueRowFilter:$submissionId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Only this Topic'), findsOneWidget);
      expect(find.text('Only this group'), findsOneWidget);
      await tester.tap(find.text('Only this Student'));
      await tester.pumpAndSettle();

      expect(repository.queries.last.studentId, _studentId);
      final chip = find.byKey(
        const Key('teacherReviewQueueFilterChip:student'),
      );
      expect(
        find.descendant(
          of: chip,
          matching: find.text('Student: Aziza Karimova'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: chip, matching: find.byTooltip('Remove filter')),
      );
      await tester.pumpAndSettle();
      expect(repository.queries.last.studentId, isNull);
      expect(chip, findsNothing);
    });

    testWidgets('a row filters by its group', (tester) async {
      final repository = FakeTeacherSubmissionRepository(
        onFetch: (query) async => teacherSubmissionList([teacherSubmission()]),
      );
      await _pumpQueue(tester, const TeacherReviewQueueScreen(), repository);

      await tester.tap(
        find.byKey(const Key('teacherReviewQueueRowFilter:$submissionId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only this group'));
      await tester.pumpAndSettle();

      expect(repository.queries.last.groupId, _groupId);
      expect(
        find.descendant(
          of: find.byKey(const Key('teacherReviewQueueFilterChip:group')),
          matching: find.text('Group: 7-A'),
        ),
        findsOneWidget,
      );
    });

    // A Topic belongs to one group, so a fixed Topic fixes the group too.
    testWidgets('a task queue offers neither Topic nor group filters', (
      tester,
    ) async {
      await _pumpQueue(
        tester,
        TeacherReviewQueueScreen(
          scope: TeacherReviewQueueScope.task(
            topicId: _topicId,
            assessmentId: _homeworkId,
            type: TeacherSubmissionTaskType.homework,
          ),
        ),
        FakeTeacherSubmissionRepository(
          onFetch: (_) async => teacherSubmissionList([teacherSubmission()]),
        ),
      );

      await tester.tap(
        find.byKey(const Key('teacherReviewQueueRowFilter:$submissionId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Only this Topic'), findsNothing);
      expect(find.text('Only this group'), findsNothing);
      expect(find.text('Only this Student'), findsOneWidget);
    });
  });

  group('result submissions route', () {
    test('the route helpers accept only the canonical path', () {
      final location = AppRoutePaths.teacherTopicResultReviewsLocation(
        _topicId,
        _studentId,
      );

      expect(location, '/teacher/topics/$_topicId/results/$_studentId/reviews');
      expect(
        AppRouteNames.teacherTopicResultReviews,
        'teacher-topic-result-reviews',
      );
      expect(
        AppRoutePaths.teacherTopicResultReviews,
        '/teacher/topics/:topicId/results/:studentId/reviews',
      );
      expect(AppRoutePaths.isTeacherTopicResultReviewsPath(location), isTrue);
      expect(AppRoutePaths.isTeacherTopicResultDetailPath(location), isFalse);
      expect(AppRoutePaths.isTeacherApprovedLocation(location), isTrue);
      expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);
      for (final invalid in [
        '/teacher/topics/$_topicId/results/not-a-uuid/reviews',
        '/teacher/topics/$_topicId/results/$_studentId/reviews/extra',
        '/teacher/topics/$_topicId/results/reviews',
      ]) {
        expect(AppRoutePaths.isTeacherTopicResultReviewsPath(invalid), isFalse);
        expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
      }
    });

    testWidgets('desktop opens a Student\'s submissions from the result', (
      tester,
    ) async {
      final submissions = FakeTeacherSubmissionRepository(
        onFetch: (_) async => teacherSubmissionList([teacherSubmission()]),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicResultDetailLocation(
          _topicId,
          _studentId,
        ),
        submissions: submissions,
      );

      await tester.tap(
        find.byKey(const Key('teacherTopicResultSubmissionsButton')),
      );
      await tester.pumpAndSettle();

      expect(
        _routerPath(tester),
        AppRoutePaths.teacherTopicResultReviewsLocation(_topicId, _studentId),
      );
      expect(submissions.queries.last.toQueryParameters(), {
        'topic_id': _topicId,
        'student_id': _studentId,
        'sort': 'default',
        'page': 1,
        'per_page': 25,
      });
      expect(
        find.text("This Student's submissions in this Topic"),
        findsOneWidget,
      );
      // Topic, group and Student are all fixed: no row filter is left.
      expect(
        find.byKey(const Key('teacherReviewQueueRowFilter:$submissionId')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('teacherReviewQueueBackButton')));
      await tester.pumpAndSettle();
      expect(
        _routerPath(tester),
        AppRoutePaths.teacherTopicResultDetailLocation(_topicId, _studentId),
      );
    });

    testWidgets('a desktop deep link to the submissions survives bootstrap', (
      tester,
    ) async {
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      final submissions = FakeTeacherSubmissionRepository();
      final location = AppRoutePaths.teacherTopicResultReviewsLocation(
        _topicId,
        _studentId,
      );
      await _pumpApp(
        tester,
        location: location,
        submissions: submissions,
        auth: auth,
        settle: false,
      );
      expect(submissions.queries, isEmpty);

      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();

      expect(_routerPath(tester), location);
      expect(submissions.queries, hasLength(1));
    });

    testWidgets('a mobile deep link falls back to the result at bootstrap', (
      tester,
    ) async {
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicResultReviewsLocation(
          _topicId,
          _studentId,
        ),
        submissions: FakeTeacherSubmissionRepository(),
        auth: auth,
        surface: AppDeviceSurface.mobile,
        settle: false,
      );

      final result = AppRoutePaths.teacherTopicResultDetailLocation(
        _topicId,
        _studentId,
      );
      expect(_routerPath(tester), result);
      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();
      expect(_routerPath(tester), result);
    });

    testWidgets('mobile has no submissions link and is redirected back', (
      tester,
    ) async {
      final submissions = FakeTeacherSubmissionRepository();
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicResultReviewsLocation(
          _topicId,
          _studentId,
        ),
        submissions: submissions,
        surface: AppDeviceSurface.mobile,
      );

      expect(
        _routerPath(tester),
        AppRoutePaths.teacherTopicResultDetailLocation(_topicId, _studentId),
      );
      expect(
        find.byKey(const Key('teacherTopicResultSubmissionsButton')),
        findsNothing,
      );
      expect(submissions.queries, isEmpty);
    });
  });
}

class _ControllerHarness {
  _ControllerHarness(this.scope)
    : repository = FakeTeacherSubmissionRepository(
        onFetch: (query) async =>
            teacherSubmissionList([teacherSubmission()], page: query.page),
      ) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherSubmissionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final TeacherReviewQueueScope scope;
  final FakeTeacherSubmissionRepository repository;
  late final ProviderContainer container;

  Future<void> ready() async {
    final subscription = container.listen(
      teacherReviewQueueControllerProvider(scope),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await flushTeacherControllers();
  }

  TeacherReviewQueueController get controller =>
      container.read(teacherReviewQueueControllerProvider(scope).notifier);

  TeacherReviewQueueState get state =>
      container.read(teacherReviewQueueControllerProvider(scope));
}

String _routerPath(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(TestLabUzApp)),
  ).read(appRouterProvider).routeInformationProvider.value.uri.path;
}

Future<void> _pumpQueue(
  WidgetTester tester,
  Widget screen,
  FakeTeacherSubmissionRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherSubmissionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String location,
  required FakeTeacherSubmissionRepository submissions,
  FakeTeacherAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(
    surface == AppDeviceSurface.desktop
        ? const Size(1280, 1000)
        : const Size(390, 844),
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
        teacherTopicResultRepositoryProvider.overrideWithValue(
          FakeTeacherTopicResultRepository(
            onFetchResults: (_, query) async =>
                teacherTopicResultList(query: query),
          ),
        ),
        teacherSubmissionRepositoryProvider.overrideWithValue(submissions),
      ],
      child: const TestLabUzApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}
