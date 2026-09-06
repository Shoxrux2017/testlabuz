import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_section.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('Homework section keeps loading and empty states local', (
    tester,
  ) async {
    final pending = Completer<TeacherHomeworkList>();
    final repository = FakeTeacherHomeworkRepository(
      onFetchList: (topicId, query) => pending.future,
    );

    await _pumpSection(tester, repository);
    expect(find.byKey(const Key('teacherHomeworkLoading')), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);

    pending.complete(teacherHomeworkList());
    await tester.pumpAndSettle();

    expect(
      find.text('No Homework has been created for this Topic yet.'),
      findsOneWidget,
    );
  });

  testWidgets('Homework list error is safe and Retry is section-local', (
    tester,
  ) async {
    var calls = 0;
    final repository = FakeTeacherHomeworkRepository(
      onFetchList: (topicId, query) async {
        calls += 1;
        if (calls == 1) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherHomeworkList();
      },
    );

    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherHomeworkError')), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);

    await tester.tap(find.byKey(const Key('teacherHomeworkRetryButton')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(
      find.text('No Homework has been created for this Topic yet.'),
      findsOneWidget,
    );
  });

  testWidgets('search and both filters apply typed local query state', (
    tester,
  ) async {
    final repository = FakeTeacherHomeworkRepository();
    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('teacherHomeworkSearchField')),
      '  equations  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.listRequests.last.query.search, 'equations');
    expect(repository.listRequests.last.query.page, 1);

    await _selectDropdownOption<TeacherHomeworkStatus>(
      tester,
      key: const Key('teacherHomeworkStatusFilter'),
      label: 'Active',
    );
    expect(
      repository.listRequests.last.query.status,
      TeacherHomeworkStatus.active,
    );
    expect(repository.listRequests.last.query.page, 1);

    await _selectDropdownOption<TeacherHomeworkAssignmentMode>(
      tester,
      key: const Key('teacherHomeworkAssignmentFilter'),
      label: 'Selected students',
    );
    expect(
      repository.listRequests.last.query.assignmentMode,
      TeacherHomeworkAssignmentMode.selectedStudents,
    );
    expect(repository.listRequests.last.query.page, 1);
    expect(
      find.text('No Homework matches the current filters.'),
      findsOneWidget,
    );
  });

  testWidgets('data cards present metadata and Institution-timezone deadline', (
    tester,
  ) async {
    final repository = FakeTeacherHomeworkRepository(
      onFetchList: (topicId, query) async => teacherHomeworkList(
        items: [
          teacherHomeworkSummary(
            title: 'Long equation practice title that remains readable',
            assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
            status: TeacherHomeworkStatus.active,
            questionCount: 4,
            totalPossiblePoints: 12.5,
            deadlineAt: DateTime.utc(2026, 9, 10, 12),
          ),
        ],
        total: 1,
      ),
    );

    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.text('Long equation practice title that remains readable'),
      findsOneWidget,
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Selected students'), findsOneWidget);
    expect(find.text('Questions: 4'), findsOneWidget);
    expect(find.text('Total points: 12.5'), findsOneWidget);
    expect(find.text('Deadline: 2026-09-10 17:00'), findsOneWidget);
    expect(find.text('Create Homework'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Activate'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination and refresh dispatch only current list operations', (
    tester,
  ) async {
    final refresh = Completer<TeacherHomeworkList>();
    var calls = 0;
    final repository = FakeTeacherHomeworkRepository(
      onFetchList: (topicId, query) {
        calls += 1;
        if (calls == 3) {
          return refresh.future;
        }
        return Future.value(
          teacherHomeworkList(
            items: [teacherHomeworkSummary()],
            page: query.page,
            perPage: query.perPage,
            total: 2,
            lastPage: 2,
          ),
        );
      },
    );

    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherHomeworkNextButton')));
    await tester.pumpAndSettle();
    expect(repository.listRequests.last.query.page, 2);
    expect(find.text('Page 2 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherHomeworkRefreshButton')));
    await tester.pump();
    expect(find.byKey(const Key('teacherHomeworkRefreshing')), findsOneWidget);
    expect(find.text('Equation practice'), findsOneWidget);

    refresh.complete(
      teacherHomeworkList(
        items: [teacherHomeworkSummary(title: 'Refreshed practice')],
        page: 2,
        total: 2,
        lastPage: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Refreshed practice'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherHomeworkPreviousButton')));
    await tester.pumpAndSettle();
    expect(repository.listRequests.last.query.page, 1);
  });

  testWidgets('Create action requires confirmed editable Topic on desktop', (
    tester,
  ) async {
    for (final status in [
      TeacherTopicStatus.draft,
      TeacherTopicStatus.active,
    ]) {
      await _pumpSection(
        tester,
        FakeTeacherHomeworkRepository(),
        topics: FakeTeacherTopicRepository(
          onFetch: (id) async => teacherTopic(id: id, status: status),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherHomeworkCreateButton')),
        findsOneWidget,
      );
    }

    for (final status in [
      TeacherTopicStatus.closed,
      TeacherTopicStatus.archived,
    ]) {
      await _pumpSection(
        tester,
        FakeTeacherHomeworkRepository(),
        topics: FakeTeacherTopicRepository(
          onFetch: (id) async => teacherTopic(id: id, status: status),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherHomeworkCreateButton')),
        findsNothing,
      );
    }
  });

  testWidgets(
    'Create action stays hidden while Topic is loading and on mobile',
    (tester) async {
      final pending = Completer<TeacherTopic>();
      await _pumpSection(
        tester,
        FakeTeacherHomeworkRepository(),
        topics: FakeTeacherTopicRepository(onFetch: (_) => pending.future),
      );
      expect(
        find.byKey(const Key('teacherHomeworkCreateButton')),
        findsNothing,
      );
      pending.complete(teacherTopic(id: _topicId));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherHomeworkCreateButton')),
        findsOneWidget,
      );

      await _pumpSection(
        tester,
        FakeTeacherHomeworkRepository(),
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherHomeworkCreateButton')),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpSection(
  WidgetTester tester,
  FakeTeacherHomeworkRepository repository, {
  FakeTeacherTopicRepository? topics,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
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
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
        teacherTopicRepositoryProvider.overrideWithValue(
          topics ?? FakeTeacherTopicRepository(),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: TeacherHomeworkSection(topicId: _topicId),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _selectDropdownOption<T>(
  WidgetTester tester, {
  required Key key,
  required String label,
}) async {
  final dropdown = find.descendant(
    of: find.byKey(key),
    matching: find.byType(DropdownButton<T?>),
  );
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
