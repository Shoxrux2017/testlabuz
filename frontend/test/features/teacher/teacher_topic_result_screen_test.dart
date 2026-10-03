import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_list_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_list.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_result_detail_screen.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_results_card.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_results_screen.dart';

import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

const _secondStudentId = '60000000-0000-0000-0000-000000000002';
const _thirdStudentId = '60000000-0000-0000-0000-000000000003';

void main() {
  group('Topic results entry card', () {
    testWidgets('shows the cohort size and every non-zero status', (
      tester,
    ) async {
      await _pump(
        tester,
        const TeacherTopicResultsCard(topicId: teacherResultTopicId),
        _repository(
          counts: teacherResultCountsJson(
            waitingForBlitz: 4,
            calculated: 21,
            notCompleted: 2,
            closed: 1,
          ),
          total: 28,
        ),
      );

      expect(find.text('Topic results'), findsOneWidget);
      expect(find.text('Students: 28'), findsOneWidget);
      expect(find.text('Waiting for Blitz: 4'), findsOneWidget);
      expect(find.text('Calculated: 21'), findsOneWidget);
      expect(find.text('Not completed: 2'), findsOneWidget);
      expect(find.text('Closed: 1'), findsOneWidget);
      expect(find.textContaining('Waiting for Homework'), findsNothing);
      expect(find.textContaining('Waiting for result settings'), findsNothing);
      expect(
        find.byKey(const Key('teacherTopicResultsOpenButton')),
        findsOneWidget,
      );
    });

    testWidgets('an empty cohort explains when results appear', (tester) async {
      await _pump(
        tester,
        const TeacherTopicResultsCard(topicId: teacherResultTopicId),
        FakeTeacherTopicResultRepository(),
      );

      expect(
        find.text(
          'No results yet. Results appear once the official Homework is '
          'activated.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherTopicResultsOpenButton')),
        findsNothing,
      );
    });

    testWidgets('a failed first load offers Retry', (tester) async {
      var fetches = 0;
      final repository = FakeTeacherTopicResultRepository(
        onFetchResults: (_, query) async {
          fetches += 1;
          if (fetches == 1) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherTopicResultList(query: query);
        },
      );
      await _pump(
        tester,
        const TeacherTopicResultsCard(topicId: teacherResultTopicId),
        repository,
      );

      expect(find.text('Topic results could not be loaded.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('teacherTopicResultsCardRetry')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Students: 1'), findsOneWidget);
      expect(fetches, 2);
    });

    testWidgets('counts kept after a failed load are marked as stale', (
      tester,
    ) async {
      var fetches = 0;
      await _pump(
        tester,
        const TeacherTopicResultsCard(topicId: teacherResultTopicId),
        FakeTeacherTopicResultRepository(
          onFetchResults: (_, query) async {
            fetches += 1;
            if (fetches == 2) {
              throw teacherLocalFailure(ApiFailureKind.timeout);
            }
            return teacherTopicResultList(query: query);
          },
        ),
      );
      expect(
        find.byKey(const Key('teacherTopicResultsCardStale')),
        findsNothing,
      );

      ProviderScope.containerOf(
            tester.element(find.byType(TeacherTopicResultsCard)),
          )
          .read(
            teacherTopicResultListControllerProvider(
              teacherResultTopicId,
            ).notifier,
          )
          .refresh();
      await tester.pumpAndSettle();

      expect(find.text('Students: 1'), findsOneWidget);
      expect(find.text('These counts may be out of date.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('teacherTopicResultsCardRetry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherTopicResultsCardStale')),
        findsNothing,
      );
      expect(fetches, 3);
    });

    testWidgets('results the Teacher cannot open have no Retry', (
      tester,
    ) async {
      await _pump(
        tester,
        const TeacherTopicResultsCard(topicId: teacherResultTopicId),
        FakeTeacherTopicResultRepository(
          onFetchResults: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        ),
      );

      expect(
        find.text('These Topic results are not available.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherTopicResultsCardRetry')),
        findsNothing,
      );
    });

    testWidgets('the card fits a narrow phone with large text', (tester) async {
      _useNarrowPhone(tester);
      await _pump(
        tester,
        const TeacherTopicResultsCard(topicId: teacherResultTopicId),
        _repository(
          counts: teacherResultCountsJson(
            waitingForTeacherReview: 3,
            waitingForSettings: 2,
          ),
          items: [
            waitingTeacherTopicResultJson(
              status: 'waiting_for_settings',
              blitzState: 'ready',
            ),
          ],
          total: 5,
        ),
        surface: AppDeviceSurface.mobile,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Waiting for result settings: 2'), findsOneWidget);
    });

    testWidgets('shows progress while the counts are unknown', (tester) async {
      await _pump(
        tester,
        const TeacherTopicResultsCard(topicId: teacherResultTopicId),
        FakeTeacherTopicResultRepository(),
        settle: false,
      );

      expect(
        find.byKey(const Key('teacherTopicResultsCardLoading')),
        findsOneWidget,
      );
    });
  });

  group('Topic results screen', () {
    testWidgets('rows show status, scores, category and visibility', (
      tester,
    ) async {
      await _pump(
        tester,
        const TeacherTopicResultsScreen(topicId: teacherResultTopicId),
        _repository(
          items: [
            teacherTopicResultJson(
              visibility: teacherResultVisibilityJson(studentVisible: true),
            ),
            notCompletedTeacherTopicResultJson(
              studentId: _secondStudentId,
              closed: true,
            ),
            waitingTeacherTopicResultJson(
              studentId: _thirdStudentId,
              fullName: 'Bobur Aliyev',
            ),
          ],
          counts: teacherResultCountsJson(
            calculated: 1,
            closed: 1,
            waitingForBlitz: 1,
          ),
        ),
      );

      final first = _rowText(tester, teacherResultStudentId);
      expect(first, contains('Aziza Karimova'));
      expect(first, contains('Calculated'));
      expect(first, contains('Homework 88.0 · Blitz 84.0 · Final 86.0'));
      expect(first, contains('Category: Understood well'));
      expect(first, contains('Student: Visible · Parents: Not visible'));

      final closed = _rowText(tester, _secondStudentId);
      expect(closed, contains('Closed · Not completed'));
      expect(closed, contains('Missing: Blitz'));
      expect(closed, contains('Homework 88.0'));
      expect(closed, contains('Category: Not completed'));

      final waiting = _rowText(tester, _thirdStudentId);
      expect(waiting, contains('Bobur Aliyev'));
      expect(waiting, contains('Waiting for Blitz'));
      expect(waiting, contains('Homework 88.0'));
      expect(waiting.any((line) => line.startsWith('Category')), isFalse);

      expect(find.text('3 Students'), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsOneWidget);
    });

    testWidgets('the status filter shows the counts and filters the list', (
      tester,
    ) async {
      final repository = _repository(
        counts: teacherResultCountsJson(calculated: 1),
        filtered: (query) =>
            query.status == null && query.category == null ? null : const [],
      );
      await _pump(
        tester,
        const TeacherTopicResultsScreen(topicId: teacherResultTopicId),
        repository,
      );

      await tester.tap(
        find.byKey(const Key('teacherTopicResultsStatusFilter')),
      );
      await tester.pumpAndSettle();
      expect(find.text('All statuses (1)').last, findsOneWidget);
      expect(find.text('Calculated (1)').last, findsOneWidget);
      expect(find.text('Waiting for Homework (0)').last, findsOneWidget);
      await tester.tap(find.text('Closed (0)').last);
      await tester.pumpAndSettle();

      expect(
        repository.listRequests.last.query,
        const TeacherTopicResultListQuery(
          status: TeacherTopicResultStatus.closed,
        ),
      );
      expect(find.text('No results match these filters.'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('teacherTopicResultsCategoryFilter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Needs teacher support').last);
      await tester.pumpAndSettle();
      expect(
        repository.listRequests.last.query,
        const TeacherTopicResultListQuery(
          status: TeacherTopicResultStatus.closed,
          category: TeacherTopicResultCategoryCode.needsTeacherSupport,
        ),
      );

      await tester.tap(
        find.byKey(const Key('teacherTopicResultsClearFilters')),
      );
      await tester.pumpAndSettle();
      expect(
        repository.listRequests.last.query,
        const TeacherTopicResultListQuery(),
      );
      expect(find.text('1 Student'), findsOneWidget);
    });

    testWidgets('an empty cohort explains when results appear', (tester) async {
      await _pump(
        tester,
        const TeacherTopicResultsScreen(topicId: teacherResultTopicId),
        FakeTeacherTopicResultRepository(),
      );

      expect(
        find.text(
          'No results yet. Results appear once the official Homework is '
          'activated.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherTopicResultsClearFilters')),
        findsOneWidget,
      );
    });

    testWidgets('Next loads the following page', (tester) async {
      final repository = _repository(
        total: 30,
        counts: teacherResultCountsJson(calculated: 30),
      );
      await _pump(
        tester,
        const TeacherTopicResultsScreen(topicId: teacherResultTopicId),
        repository,
      );
      expect(find.text('30 Students'), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);

      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(repository.listRequests.last.query.page, 2);
      expect(find.text('Page 2 of 2'), findsOneWidget);
    });

    testWidgets('a failed first load explains the failure and retries', (
      tester,
    ) async {
      var fetches = 0;
      final repository = FakeTeacherTopicResultRepository(
        onFetchResults: (_, query) async {
          fetches += 1;
          if (fetches == 1) {
            throw teacherServerFailure(
              ApiErrorCodes.resourceNotFound,
              statusCode: 404,
            );
          }
          return teacherTopicResultList(query: query);
        },
      );
      await _pump(
        tester,
        const TeacherTopicResultsScreen(topicId: teacherResultTopicId),
        repository,
      );

      expect(
        find.text('These Topic results are not available.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('teacherTopicResultsRetryButton')));
      await tester.pumpAndSettle();
      expect(find.text('Aziza Karimova'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the rows under a stale banner', (
      tester,
    ) async {
      var fetches = 0;
      final repository = FakeTeacherTopicResultRepository(
        onFetchResults: (_, query) async {
          fetches += 1;
          if (fetches == 2) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return teacherTopicResultList(query: query);
        },
      );
      await _pump(
        tester,
        const TeacherTopicResultsScreen(topicId: teacherResultTopicId),
        repository,
      );

      await tester.tap(
        find.byKey(const Key('teacherTopicResultsRefreshButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherTopicResultsStaleMessage')),
        findsOneWidget,
      );
      expect(find.text('Aziza Karimova'), findsOneWidget);
    });

    testWidgets('fits a narrow phone with large text', (tester) async {
      _useNarrowPhone(tester);
      await _pump(
        tester,
        const TeacherTopicResultsScreen(topicId: teacherResultTopicId),
        _repository(
          items: [
            teacherTopicResultJson(
              fullName: 'Aziza Karimova Abdullayevna Toshkentova',
            ),
          ],
        ),
        surface: AppDeviceSurface.mobile,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Final 86.0'), findsOneWidget);
    });
  });

  group('Topic result detail screen', () {
    testWidgets('a calculated result shows every section', (tester) async {
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: teacherTopicResultJson(
            teacherComment: 'Revise question 4.',
            homework: teacherResultSideJson(attemptNumber: 2),
            visibility: teacherResultVisibilityJson(
              studentMode: 'automatic',
              studentVisible: true,
              studentReleasedAt: '2026-10-04T08:00:00Z',
              canReleaseToStudent: false,
            ),
          ),
          commentUpdatedAt: '2026-10-03T07:30:00Z',
          commentUpdatedBy: teacherResultActorJson(),
          studentReleasedBy: teacherResultActorJson(fullName: 'Second Teacher'),
        ),
      );

      final text = _screenText(tester);
      expect(text, contains('Aziza Karimova'));
      expect(text, containsAllInOrder(['Status', 'Calculated']));
      expect(
        text,
        containsAllInOrder([
          'Homework',
          'State',
          'Ready',
          'Official Attempt',
          'Attempt 2',
          'Score',
          '88.0',
        ]),
      );
      expect(text, containsAllInOrder(['Blitz', 'Ready', 'Attempt 1', '84.0']));
      expect(
        text,
        containsAllInOrder([
          'Final score',
          '86.0',
          'Category',
          'Understood well',
          'Method',
          'Average of both scores',
          'Score difference',
          '4.0',
          'Allowed difference',
          '10.0',
          'The scores are within the allowed difference, so the final score '
              'is their average.',
        ]),
      );
      expect(
        text,
        containsAllInOrder([
          "Teacher's comment",
          'Revise question 4.',
          'Last changed 2026-10-03 12:30 by Dilnoza Teacher',
        ]),
      );
      expect(
        text,
        containsAllInOrder([
          'Visibility',
          'Student release',
          'Automatic',
          'Student',
          'Visible now',
          'Released to the Student',
          '2026-10-04 13:00 by Second Teacher',
          'Parent release',
          'With the Student',
          'Parents',
          'Not visible',
        ]),
      );
      _expectNoAccusingWords(text);
    });

    testWidgets('an inconsistent result explains the Blitz score kindly', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: inconsistentTeacherTopicResultJson(),
        ),
      );

      final text = _screenText(tester);
      expect(
        text,
        contains(
          'The scores differ by more than the allowed difference, so the '
          'Blitz score is used.',
        ),
      );
      expect(text, containsAllInOrder(['Method', 'Blitz score']));
      expect(text, containsAllInOrder(['Score difference', '35.0']));
      _expectNoAccusingWords(text);
    });

    testWidgets('a waiting result has no final result section', (tester) async {
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: waitingTeacherTopicResultJson(
            status: 'waiting_for_teacher_review',
            blitzState: 'waiting_for_teacher_review',
          ),
        ),
      );

      final text = _screenText(tester);
      expect(text, containsAllInOrder(['Status', 'Waiting for review']));
      expect(
        text,
        containsAllInOrder(['Blitz', 'State', 'Waiting for review']),
      );
      expect(text, isNot(contains('Final score')));
      expect(text, isNot(contains('Category')));
      expect(text, contains('No comment yet.'));
      expect(
        text,
        containsAllInOrder(['Student release', 'Manual by the Teacher']),
      );
    });

    testWidgets('waiting for settings names who sets them', (tester) async {
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: waitingTeacherTopicResultJson(
            status: 'waiting_for_settings',
            blitzState: 'ready',
          ),
        ),
      );

      expect(
        find.text(
          'The Institution Admin has not set the allowed difference or the '
          'categories yet.',
        ),
        findsOneWidget,
      );
      expect(find.text('Waiting for result settings'), findsOneWidget);
    });

    testWidgets('a Not completed result names the missing side', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: notCompletedTeacherTopicResultJson(missing: 'homework'),
        ),
      );

      final text = _screenText(tester);
      expect(text, contains('Missing: Homework'));
      expect(text, containsAllInOrder(['Homework', 'State', 'Missing']));
      expect(text, containsAllInOrder(['Category', 'Not completed']));
      expect(text, isNot(contains('Final score')));
      expect(text, isNot(contains('Method')));
    });

    testWidgets('a closed result shows when, by whom and why', (tester) async {
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: closedCalculatedTeacherTopicResultJson(),
          closedBy: teacherResultActorJson(),
          closureReason: 'teacher',
        ),
      );

      final text = _screenText(tester);
      expect(text, containsAllInOrder(['Status', 'Closed · Calculated']));
      expect(
        text,
        containsAllInOrder([
          'Closed at',
          '2026-10-05 14:00',
          'Closed by',
          'Dilnoza Teacher',
          'Closure',
          'Closed by the Teacher',
        ]),
      );
    });

    testWidgets('a result closed at Topic archive says so', (tester) async {
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: notCompletedTeacherTopicResultJson(closed: true),
          closureReason: 'topic_archived',
        ),
      );

      final text = _screenText(tester);
      expect(text, contains('Closed · Not completed'));
      expect(text, contains('Closed when the Topic was archived'));
      expect(text, isNot(contains('Closed by')));
    });

    testWidgets('visibility shows unconfigured modes and Parent releases', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: closedCalculatedTeacherTopicResultJson(
            visibility: teacherResultVisibilityJson(
              studentMode: null,
              canReleaseToStudent: false,
              parentMode: 'manual_teacher',
              parentVisible: true,
              parentReleasedAt: '2026-10-06T04:15:00Z',
            ),
          ),
          parentReleasedBy: teacherResultActorJson(),
          closureReason: 'teacher',
        ),
      );

      expect(
        _screenText(tester),
        containsAllInOrder([
          'Student release',
          'Not configured',
          'Student',
          'Not visible',
          'Parent release',
          'Manual by the Teacher',
          'Parents',
          'Visible now',
          'Released to Parents',
          '2026-10-06 09:15 by Dilnoza Teacher',
        ]),
      );
    });

    testWidgets('a result outside the cohort is not available', (tester) async {
      await _pump(
        tester,
        const TeacherTopicResultDetailScreen(
          topicId: teacherResultTopicId,
          studentId: teacherResultStudentId,
        ),
        FakeTeacherTopicResultRepository(
          onFetchResult: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        ),
      );

      expect(find.text('This result is not available.'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherTopicResultRetryButton')),
        findsOneWidget,
      );
    });

    testWidgets('a failed refresh keeps the result under a stale banner', (
      tester,
    ) async {
      var fetches = 0;
      await _pump(
        tester,
        const TeacherTopicResultDetailScreen(
          topicId: teacherResultTopicId,
          studentId: teacherResultStudentId,
        ),
        FakeTeacherTopicResultRepository(
          onFetchResult: (_, _) async {
            fetches += 1;
            if (fetches == 2) {
              throw teacherLocalFailure(ApiFailureKind.connection);
            }
            return teacherTopicResultDetail();
          },
        ),
      );

      await tester.tap(
        find.byKey(const Key('teacherTopicResultRefreshButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherTopicResultStaleMessage')),
        findsOneWidget,
      );
      expect(find.text('Aziza Karimova'), findsOneWidget);
    });

    testWidgets('fits a narrow phone with large text', (tester) async {
      _useNarrowPhone(tester);
      await _pumpDetail(
        tester,
        teacherTopicResultDetailJson(
          item: inconsistentTeacherTopicResultJson(),
          closedBy: null,
        ),
        surface: AppDeviceSurface.mobile,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Needs revision'), findsOneWidget);
    });
  });
}

FakeTeacherTopicResultRepository _repository({
  List<Map<String, Object?>>? items,
  int? total,
  Map<String, Object?>? counts,
  List<Map<String, Object?>>? Function(TeacherTopicResultListQuery query)?
  filtered,
}) {
  return FakeTeacherTopicResultRepository(
    onFetchResults: (_, query) async {
      final rows = filtered?.call(query) ?? items;
      return teacherTopicResultList(
        query: query,
        items: rows,
        total: rows != null && rows.isEmpty ? 0 : total,
        counts: counts,
      );
    },
  );
}

void _expectNoAccusingWords(List<String> text) {
  final joined = text.join('\n').toLowerCase();
  expect(joined, isNot(contains('inconsistent')));
  expect(joined, isNot(contains('consistency')));
  expect(joined, isNot(contains('category score')));
  expect(joined, isNot(contains('category_score')));
}

void _useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<String> _rowText(WidgetTester tester, String studentId) {
  return _texts(tester, find.byKey(Key('teacherTopicResultRow:$studentId')));
}

List<String> _screenText(WidgetTester tester) {
  return _texts(tester, find.byType(Scaffold));
}

List<String> _texts(WidgetTester tester, Finder scope) {
  return tester
      .widgetList<Text>(find.descendant(of: scope, matching: find.byType(Text)))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .toList();
}

Future<void> _pumpDetail(
  WidgetTester tester,
  Map<String, Object?> json, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  double textScale = 1,
}) {
  return _pump(
    tester,
    const TeacherTopicResultDetailScreen(
      topicId: teacherResultTopicId,
      studentId: teacherResultStudentId,
    ),
    FakeTeacherTopicResultRepository(
      onFetchResult: (_, _) async => teacherTopicResultDetail(json),
    ),
    surface: surface,
    textScale: textScale,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  FakeTeacherTopicResultRepository repository, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  double textScale = 1,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherTopicResultRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: child is TeacherTopicResultsCard
              ? Scaffold(body: SingleChildScrollView(child: child))
              : child,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}
