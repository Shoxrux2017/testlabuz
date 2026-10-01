import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_list_query.dart';

import 'teacher_submission_test_support.dart';
import 'teacher_test_support.dart';

const _blitzSubmissionId = '70000000-0000-0000-0000-000000000002';

void main() {
  test('the review queue path is exact and desktop-approved', () {
    expect(AppRoutePaths.teacherReviews, '/teacher/reviews');
    expect(AppRouteNames.teacherReviews, 'teacher-reviews');
    expect(AppRoutePaths.isTeacherReviewQueuePath('/teacher/reviews'), isTrue);
    expect(AppRoutePaths.isTeacherApprovedLocation('/teacher/reviews'), isTrue);
    for (final invalid in [
      '/teacher/reviews/',
      '/teacher/reviews/x',
      '/teacher/review',
      '/teacher',
    ]) {
      expect(
        AppRoutePaths.isTeacherReviewQueuePath(invalid),
        isFalse,
        reason: invalid,
      );
    }
  });

  testWidgets('desktop opens the queue directly and from the workspace', (
    tester,
  ) async {
    final submissions = FakeTeacherSubmissionRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacher,
      submissions: submissions,
    );
    await tester.pumpAndSettle();
    expect(submissions.queries, isEmpty);

    await tester.tap(find.byKey(const Key('teacherReviewQueueButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherReviewQueueScreen')), findsOneWidget);
    expect(_routerPath(tester), '/teacher/reviews');
    expect(submissions.queries, [const TeacherSubmissionListQuery.initial()]);

    await tester.tap(find.byKey(const Key('teacherReviewQueueBackButton')));
    await tester.pumpAndSettle();
    expect(_routerPath(tester), AppRoutePaths.teacher);

    final direct = FakeTeacherSubmissionRepository();
    await _pumpApp(tester, location: '/teacher/reviews', submissions: direct);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherReviewQueueScreen')), findsOneWidget);
    expect(direct.queries, hasLength(1));
  });

  testWidgets('mobile and query strings never reach the queue', (tester) async {
    for (final (location, surface) in [
      ('/teacher/reviews', AppDeviceSurface.mobile),
      ('/teacher/reviews?status=checked', AppDeviceSurface.desktop),
      ('/teacher/reviews#fragment', AppDeviceSurface.desktop),
    ]) {
      final submissions = FakeTeacherSubmissionRepository();
      await _pumpApp(
        tester,
        location: location,
        submissions: submissions,
        surface: surface,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherLearningWorkspace')),
        findsOneWidget,
        reason: location,
      );
      expect(_routerPath(tester), AppRoutePaths.teacher);
      expect(submissions.queries, isEmpty);
    }

    await _pumpApp(
      tester,
      location: AppRoutePaths.teacher,
      submissions: FakeTeacherSubmissionRepository(),
      surface: AppDeviceSurface.mobile,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherReviewQueueButton')), findsNothing);
  });

  testWidgets(
    'rows show the Student, task, attempt, review progress and chips',
    (tester) async {
      final submissions = FakeTeacherSubmissionRepository(
        onFetch: (_) async => teacherSubmissionList([
          teacherSubmission(reviewDueAt: DateTime.utc(2026, 10, 2, 13)),
          teacherSubmission(
            id: _blitzSubmissionId,
            status: TeacherSubmissionStatus.waitingForTeacherReview,
            taskType: TeacherSubmissionTaskType.blitz,
            taskTitle: 'Quick quiz',
            official: false,
            officialScoreEligible: false,
            attemptNumber: 1,
            waitingAnswers: 1,
            reviewedAnswers: 0,
            studentName: 'Bekzod Aliev',
          ),
        ]),
      );
      await _pumpApp(
        tester,
        location: '/teacher/reviews',
        submissions: submissions,
      );
      await tester.pumpAndSettle();

      final official = find.byKey(
        const Key('teacherReviewQueueRow:$submissionId'),
      );
      for (final text in [
        'Aziza Karimova',
        'Official',
        'Homework · Equation practice · Internet Basics · 7-A',
        'Attempt 2 · Checked · Finalized 2026-09-30 15:00',
        'Reviewed 2 of 2 answers · Review by 2026-10-02 18:00 · Score 75.0',
      ]) {
        expect(
          find.descendant(of: official, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(
          of: official,
          matching: find.text('Invalidated attempt'),
        ),
        findsNothing,
      );

      final blitz = find.byKey(
        const Key('teacherReviewQueueRow:$_blitzSubmissionId'),
      );
      for (final text in [
        'Bekzod Aliev',
        'Practice',
        'Invalidated attempt',
        'Blitz · Quick quiz · Internet Basics · 7-A',
        'Attempt 1 · Waiting for review · Finalized 2026-09-30 15:00',
        'Reviewed 0 of 1 answer',
      ]) {
        expect(
          find.descendant(of: blitz, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(find.text('2 submissions'), findsOneWidget);
      expect(find.text('Reviewed 0 of 1 answers'), findsNothing);
      expect(find.text('Page 1 of 1'), findsOneWidget);
    },
  );

  testWidgets('an overdue waiting item and a pending item show their labels', (
    tester,
  ) async {
    final submissions = FakeTeacherSubmissionRepository(
      onFetch: (_) async => teacherSubmissionList([
        teacherSubmission(
          status: TeacherSubmissionStatus.waitingForTeacherReview,
          reviewDueAt: DateTime.utc(2026, 9, 29, 13),
          reviewOverdue: true,
          waitingAnswers: 2,
          reviewedAnswers: 1,
        ),
        teacherSubmission(
          id: _blitzSubmissionId,
          status: TeacherSubmissionStatus.timedOutFinalized,
          reviewedAnswers: 0,
        ),
      ]),
    );
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();

    final overdue = find.byKey(
      const Key('teacherReviewQueueRow:$submissionId'),
    );
    expect(
      find.descendant(of: overdue, matching: find.text('Overdue')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: overdue,
        matching: find.text(
          'Reviewed 1 of 3 answers · Review by 2026-09-29 18:00',
        ),
      ),
      findsOneWidget,
    );
    final pending = find.byKey(
      const Key('teacherReviewQueueRow:$_blitzSubmissionId'),
    );
    expect(
      find.descendant(
        of: pending,
        matching: find.text(
          'Attempt 2 · Automatic checking pending · Finalized 2026-09-30 15:00',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a fractional score shows one decimal, half-up', (tester) async {
    final submissions = FakeTeacherSubmissionRepository(
      onFetch: (_) async => teacherSubmissionList([
        teacherSubmission(normalizedScore: 66.66666667),
      ]),
    );
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();

    expect(find.text('Reviewed 2 of 2 answers · Score 66.7'), findsOneWidget);
    expect(find.text('1 submission'), findsOneWidget);
  });

  testWidgets('an unresolvable Institution timezone falls back to UTC', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: FakeTeacherSubmissionRepository(),
      timezone: 'Not/AZone',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Attempt 2 · Checked · Finalized 2026-09-30 10:00 UTC'),
      findsOneWidget,
    );
  });

  testWidgets('every status, task and official option sends its value', (
    tester,
  ) async {
    final submissions = FakeTeacherSubmissionRepository();
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();

    await _choose(
      tester,
      'teacherReviewQueueStatusFilter',
      'Automatic checking pending',
    );
    expect(
      submissions.queries.last.checkingStatus,
      TeacherSubmissionCheckingFilter.automaticCheckingPending,
    );
    await _choose(tester, 'teacherReviewQueueStatusFilter', 'Checked');
    expect(
      submissions.queries.last.checkingStatus,
      TeacherSubmissionCheckingFilter.checked,
    );
    await _choose(tester, 'teacherReviewQueueTypeFilter', 'Homework');
    expect(submissions.queries.last.type, TeacherSubmissionTaskType.homework);
    await _choose(tester, 'teacherReviewQueueOfficialFilter', 'Official only');
    expect(submissions.queries.last.official, isTrue);
  });

  testWidgets('the refresh button retries after a failed first load', (
    tester,
  ) async {
    var calls = 0;
    final submissions = FakeTeacherSubmissionRepository(
      onFetch: (_) async {
        calls += 1;
        if (calls == 1) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherSubmissionList([teacherSubmission()]);
      },
    );
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherReviewQueueRefreshButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherReviewQueueRow:$submissionId')),
      findsOneWidget,
    );
  });

  testWidgets('an emptied later page still offers Previous', (tester) async {
    var calls = 0;
    final submissions = FakeTeacherSubmissionRepository(
      onFetch: (query) async {
        calls += 1;
        // The second page empties once its items leave the filter.
        return calls == 3
            ? teacherSubmissionList([], page: 2, total: 1)
            : teacherSubmissionList(
                [teacherSubmission()],
                page: query.page,
                total: 30,
              );
      },
    );
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('teacherReviewQueueNextButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('teacherReviewQueueRefreshButton')));
    await tester.pumpAndSettle();

    expect(find.text('No submissions are waiting for review.'), findsNothing);
    expect(find.text('No submissions match these filters.'), findsOneWidget);
    expect(find.text('Page 2 of 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('teacherReviewQueuePreviousButton')));
    await tester.pumpAndSettle();

    expect(submissions.queries.last.page, 1);
    expect(
      find.byKey(const Key('teacherReviewQueueRow:$submissionId')),
      findsOneWidget,
    );
  });

  testWidgets('a desktop deep link survives the session bootstrap', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    final submissions = FakeTeacherSubmissionRepository();
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
      auth: auth,
    );
    await tester.pump();

    auth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();

    expect(_routerPath(tester), '/teacher/reviews');
    expect(find.byKey(const Key('teacherReviewQueueScreen')), findsOneWidget);
    expect(submissions.queries, hasLength(1));
  });

  testWidgets('each filter control sends its query', (tester) async {
    final submissions = FakeTeacherSubmissionRepository();
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();
    expect(_direction(tester).onPressed, isNull);

    await _choose(tester, 'teacherReviewQueueStatusFilter', 'All statuses');
    await _choose(tester, 'teacherReviewQueueTypeFilter', 'Blitz');
    await _choose(tester, 'teacherReviewQueueOfficialFilter', 'Practice only');
    await tester.tap(find.byKey(const Key('teacherReviewQueueOverdueFilter')));
    await tester.pumpAndSettle();
    await _choose(tester, 'teacherReviewQueueSortFilter', 'Student name');
    expect(_direction(tester).onPressed, isNotNull);
    await tester.tap(
      find.byKey(const Key('teacherReviewQueueDirectionButton')),
    );
    await tester.pumpAndSettle();

    expect(submissions.queries.last.toQueryParameters(), {
      'type': 'blitz',
      'official': 'false',
      'overdue': 'true',
      'sort': 'student_name',
      'direction': 'desc',
      'page': 1,
      'per_page': 25,
    });

    await tester.tap(
      find.byKey(const Key('teacherReviewQueueClearFiltersButton')),
    );
    await tester.pumpAndSettle();
    expect(
      submissions.queries.last,
      const TeacherSubmissionListQuery.initial(),
    );
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const Key('teacherReviewQueueClearFiltersButton')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('paging moves between pages', (tester) async {
    final submissions = FakeTeacherSubmissionRepository(
      onFetch: (query) async => teacherSubmissionList(
        [teacherSubmission()],
        page: query.page,
        total: 30,
      ),
    );
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();
    expect(find.text('30 submissions'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(
      _button(tester, 'teacherReviewQueuePreviousButton').onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('teacherReviewQueueNextButton')));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(_button(tester, 'teacherReviewQueueNextButton').onPressed, isNull);
    expect(submissions.queries.last.page, 2);
  });

  testWidgets('loading, error and retry hide raw failures', (tester) async {
    final first = Completer<TeacherSubmissionList>();
    var calls = 0;
    final submissions = FakeTeacherSubmissionRepository(
      onFetch: (_) {
        calls += 1;
        return calls == 1
            ? first.future
            : Future.value(teacherSubmissionList([teacherSubmission()]));
      },
    );
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('teacherReviewQueueLoading')), findsOneWidget);

    first.completeError(teacherLocalFailure(ApiFailureKind.connection));
    await tester.pumpAndSettle();
    expect(find.text('The review queue could not be loaded.'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);

    await tester.tap(find.byKey(const Key('teacherReviewQueueRetryButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherReviewQueueRow:$submissionId')),
      findsOneWidget,
    );
  });

  testWidgets('a failed refresh keeps the list under a stale banner', (
    tester,
  ) async {
    var calls = 0;
    final submissions = FakeTeacherSubmissionRepository(
      onFetch: (_) async {
        calls += 1;
        if (calls == 2) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherSubmissionList([teacherSubmission()]);
      },
    );
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherReviewQueueRefreshButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherReviewQueueStaleMessage')),
      findsOneWidget,
    );
    expect(
      find.text('The displayed review queue may be out of date.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('teacherReviewQueueRow:$submissionId')),
      findsOneWidget,
    );
  });

  testWidgets('empty states depend on the filters', (tester) async {
    final submissions = FakeTeacherSubmissionRepository(
      onFetch: (_) async => teacherSubmissionList([]),
    );
    await _pumpApp(
      tester,
      location: '/teacher/reviews',
      submissions: submissions,
    );
    await tester.pumpAndSettle();
    expect(find.text('No submissions are waiting for review.'), findsOneWidget);

    await _choose(tester, 'teacherReviewQueueTypeFilter', 'Homework');

    expect(find.text('No submissions match these filters.'), findsOneWidget);
  });
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

ButtonStyleButton _direction(WidgetTester tester) =>
    _button(tester, 'teacherReviewQueueDirectionButton');

ButtonStyleButton _button(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(Key(key)));

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
  String timezone = 'Asia/Tashkent',
}) async {
  if (surface == AppDeviceSurface.mobile) {
    await tester.binding.setSurfaceSize(const Size(390, 844));
  } else {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
  }
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
                teacherUser('teacher-a', timezone: timezone),
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
        teacherSubmissionRepositoryProvider.overrideWithValue(submissions),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}
