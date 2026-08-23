import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_learning_workspace_screen.dart';

import 'teacher_test_support.dart';

void main() {
  testWidgets('wide desktop renders two independent sections and create', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repositories = _Repositories();

    await _pumpWorkspace(tester, repositories: repositories);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherLearningWorkspace')), findsOneWidget);
    expect(find.byKey(const Key('teacherWorkspaceWideLayout')), findsOneWidget);
    expect(find.text('TestLabUz'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Current user: teacher-a User'), findsOneWidget);
    expect(find.text('Institution: Example School'), findsOneWidget);
    expect(find.text('Assigned Groups'), findsOneWidget);
    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('Group A'), findsWidgets);
    expect(find.text('Linear equations'), findsOneWidget);
    expect(find.text('Create Topic'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Activate'), findsNothing);
    expect(find.text('Close'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.textContaining('2026-08-25'), findsNothing);
    expect(find.byKey(const Key('entryLogoutButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow desktop stacks sections without horizontal overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(820, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpWorkspace(tester, repositories: _Repositories());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherWorkspaceStackedLayout')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherWorkspaceWideLayout')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile layout supports Group selection and all Topic statuses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repositories = _Repositories();

    await _pumpWorkspace(
      tester,
      repositories: repositories,
      surface: AppDeviceSurface.mobile,
      textScale: 2,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherWorkspaceStackedLayout')),
      findsOneWidget,
    );
    final groupCard = find.byKey(
      const ValueKey('teacherGroupCard00000000-0000-0000-0000-000000000001'),
    );
    await tester.ensureVisible(groupCard);
    await tester.tap(groupCard);
    await tester.pumpAndSettle();
    expect(repositories.topics.queries.last.groupId, isNotNull);
    expect(find.text('Selected for Topics'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('teacherTopicStatusFilter')),
    );
    await tester.tap(find.byKey(const Key('teacherTopicStatusFilter')));
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Closed'), findsWidgets);
    expect(find.text('Archived'), findsWidgets);
    await tester.tap(find.text('Closed').last);
    await tester.pumpAndSettle();
    expect(repositories.topics.queries.last.status?.value, 'closed');

    expect(find.text('Create Topic'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Group and Topic loading, errors, and empty states are independent',
    (tester) async {
      final pendingGroups = Completer<TeacherGroupListPage>();
      final repositories = _Repositories(
        groups: FakeTeacherGroupListRepository(
          onFetch: (_) => pendingGroups.future,
        ),
        topics: FakeTeacherTopicListRepository(
          onFetch: (_) async => teacherTopicPage(),
        ),
      );

      await _pumpWorkspace(tester, repositories: repositories);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('teacherGroupInitialLoading')),
        findsOneWidget,
      );
      expect(find.text('Linear equations'), findsOneWidget);

      pendingGroups.completeError(
        teacherLocalFailure(ApiFailureKind.connection),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacherGroupListError')), findsOneWidget);
      expect(find.text('Linear equations'), findsOneWidget);

      final topicErrorRepositories = _Repositories(
        groups: FakeTeacherGroupListRepository(),
        topics: FakeTeacherTopicListRepository(
          onFetch: (_) async =>
              throw teacherLocalFailure(ApiFailureKind.timeout),
        ),
      );
      await _pumpWorkspace(tester, repositories: topicErrorRepositories);
      await tester.pumpAndSettle();
      expect(find.text('Group A'), findsWidgets);
      expect(find.byKey(const Key('teacherTopicListError')), findsOneWidget);

      final emptyRepositories = _Repositories(
        groups: FakeTeacherGroupListRepository(
          onFetch: (_) async => teacherGroupPage(groups: const [], total: 0),
        ),
        topics: FakeTeacherTopicListRepository(
          onFetch: (_) async => teacherTopicPage(topics: const [], total: 0),
        ),
      );
      await _pumpWorkspace(tester, repositories: emptyRepositories);
      await tester.pumpAndSettle();
      expect(find.text('No active assigned groups'), findsOneWidget);
      expect(find.text('No topics yet'), findsOneWidget);
    },
  );

  testWidgets('Retry is disabled only while its search draft is invalid', (
    tester,
  ) async {
    final repositories = _Repositories(
      groups: FakeTeacherGroupListRepository(
        onFetch: (_) async =>
            throw teacherLocalFailure(ApiFailureKind.connection),
      ),
      topics: FakeTeacherTopicListRepository(
        onFetch: (_) async => throw teacherLocalFailure(ApiFailureKind.timeout),
      ),
    );
    await _pumpWorkspace(tester, repositories: repositories);
    await tester.pumpAndSettle();

    final groupRetry = find.descendant(
      of: find.byKey(const Key('teacherGroupListError')),
      matching: find.byType(FilledButton),
    );
    final topicRetry = find.descendant(
      of: find.byKey(const Key('teacherTopicListError')),
      matching: find.byType(FilledButton),
    );
    final invalidDraft = String.fromCharCodes(List.filled(255, 0x1f600));

    expect(tester.widget<FilledButton>(groupRetry).onPressed, isNotNull);
    await tester.enterText(
      find.byKey(const Key('teacherGroupSearchField')),
      invalidDraft,
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(groupRetry).onPressed, isNull);
    expect(
      find.descendant(of: groupRetry, matching: find.text('Retry')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: groupRetry, matching: find.text('Retrying')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('teacherGroupSearchField')),
      'corrected',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(groupRetry).onPressed, isNotNull);

    expect(tester.widget<FilledButton>(topicRetry).onPressed, isNotNull);
    await tester.enterText(
      find.byKey(const Key('teacherTopicSearchField')),
      invalidDraft,
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(topicRetry).onPressed, isNull);
    expect(
      find.descendant(of: topicRetry, matching: find.text('Retry')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('teacherTopicSearchField')),
      '',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(topicRetry).onPressed, isNotNull);
  });

  testWidgets('sign out remains available and clears Teacher feature state', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController.authenticated(
      teacherUser('teacher-a'),
    );

    await _pumpWorkspace(tester, repositories: _Repositories(), auth: auth);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entryLogoutButton')));
    await tester.pump();

    expect(auth.state.status, AuthSessionStatus.unauthenticated);
    expect(find.text('Linear equations'), findsNothing);
  });
}

class _Repositories {
  _Repositories({
    FakeTeacherGroupListRepository? groups,
    FakeTeacherTopicListRepository? topics,
  }) : groups = groups ?? FakeTeacherGroupListRepository(),
       topics = topics ?? FakeTeacherTopicListRepository();

  final FakeTeacherGroupListRepository groups;
  final FakeTeacherTopicListRepository topics;
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required _Repositories repositories,
  FakeTeacherAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeTeacherAuthSessionController.authenticated(
                teacherUser('teacher-a'),
              ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherGroupListRepositoryProvider.overrideWithValue(
          repositories.groups,
        ),
        teacherTopicListRepositoryProvider.overrideWithValue(
          repositories.topics,
        ),
      ],
      child: MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: const TeacherLearningWorkspaceScreen(),
      ),
    ),
  );
}
