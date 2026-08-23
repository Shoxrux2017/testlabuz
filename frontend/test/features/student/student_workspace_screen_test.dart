import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_topic.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_list.dart';
import 'package:testlabuz_client/features/student/presentation/student_learning_workspace_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_topic_detail_screen.dart';

import 'student_test_support.dart';

void main() {
  testWidgets('workspace replaces placeholder with Student Topic controls', (
    tester,
  ) async {
    await _pumpWorkspace(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('studentLearningWorkspace')), findsOneWidget);
    expect(find.text('TestLabUz'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Current user: student-a User'), findsOneWidget);
    expect(find.text('Institution: Example School'), findsOneWidget);
    expect(find.text('My Topics'), findsOneWidget);
    expect(find.text('Search topics'), findsOneWidget);
    expect(find.text('Status filter'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Internet Basics'), findsOneWidget);
    expect(find.text('Lesson time: 2026-08-25 09:00'), findsOneWidget);
    expect(find.text('Create Topic'), findsNothing);
    expect(find.text('Upload material'), findsNothing);
    expect(find.textContaining('Device:'), findsNothing);
  });

  testWidgets('workspace supports mobile width without horizontal overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpWorkspace(
      tester,
      surface: AppDeviceSurface.mobile,
      topic: studentTopicSummary(
        title: 'A very long Topic title that must wrap safely on mobile',
        group: studentGroup(
          name: 'A very long mobile Group name',
          subjectDirection: 'A long subject direction that wraps',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Topics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace renders loading empty and safe error states', (
    tester,
  ) async {
    final pending = Completer<StudentTopicListPage>();
    await _pumpWorkspace(
      tester,
      repository: FakeStudentTopicRepository(
        onFetchTopics: (_) => pending.future,
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('studentTopicInitialLoading')), findsOneWidget);

    await _pumpWorkspace(
      tester,
      repository: FakeStudentTopicRepository(
        onFetchTopics: (_) async =>
            studentTopicPage(topics: const [], total: 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No Topics are available yet.'), findsOneWidget);

    await _pumpWorkspace(
      tester,
      repository: FakeStudentTopicRepository(
        onFetchTopics: (_) async =>
            throw studentLocalFailure(ApiFailureKind.connection),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load Topics'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('detail projects Student fields and ordered Materials only', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      topic: studentTopicDetail(
        materials: [
          studentMaterial(),
          studentMaterial(
            id: '20000000-0000-0000-0000-000000000002',
            fileId: '30000000-0000-0000-0000-000000000002',
            title: null,
            originalName: 'notes.pdf',
            extension: 'pdf',
            sizeBytes: 2048,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Internet Basics'), findsOneWidget);
    expect(find.text('Informatics'), findsWidgets);
    expect(find.text('Optional description'), findsOneWidget);
    expect(find.text('Study the materials.'), findsOneWidget);
    expect(find.text('2026-08-25 09:00'), findsOneWidget);
    expect(find.text('Learning Materials'), findsOneWidget);
    expect(find.text('Lesson slides'), findsOneWidget);
    expect(find.text('lesson.pptx'), findsOneWidget);
    expect(find.text('notes.pdf'), findsOneWidget);
    expect(find.text('PPTX · 1.2 MiB'), findsOneWidget);
    expect(find.text('PDF · 2.0 KiB'), findsOneWidget);
    expect(find.text('Open'), findsNWidgets(2));
    expect(find.text('Save as…'), findsNWidgets(2));
    expect(find.text('Homework'), findsNothing);
    expect(find.text('Blitz'), findsNothing);
    expect(find.text('Result'), findsNothing);
    expect(find.text('Upload material'), findsNothing);
    expect(find.text('Remove material'), findsNothing);
  });

  testWidgets('detail supports mobile, empty Materials, and unknown timezone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpDetail(
      tester,
      surface: AppDeviceSurface.mobile,
      timezone: 'Unknown/Timezone',
      topic: studentTopicDetail(
        studentInstructions:
            'Long instructions remain readable and wrap without horizontal overflow.',
        materials: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Institution timezone unavailable'), findsOneWidget);
    expect(
      find.text('No learning materials are available for this Topic.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail renders privacy-safe unavailable and retry states', (
    tester,
  ) async {
    await _pumpDetailWithRepository(
      tester,
      FakeStudentTopicRepository(
        onFetchTopic: (_) async => throw studentServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This Topic is no longer available.'), findsOneWidget);
    expect(find.text('Back to Topics'), findsOneWidget);

    await _pumpDetailWithRepository(
      tester,
      FakeStudentTopicRepository(
        onFetchTopic: (_) async =>
            throw studentLocalFailure(ApiFailureKind.connection),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load Topic'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);
  });
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  StudentTopicSummary? topic,
  FakeStudentTopicRepository? repository,
}) async {
  final effectiveRepository =
      repository ??
      FakeStudentTopicRepository(
        onFetchTopics: (query) async => studentTopicPage(
          topics: [topic ?? studentTopicSummary()],
          page: query.page,
        ),
      );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeStudentAuthSessionController.authenticated(
            studentUser('student-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentTopicRepositoryProvider.overrideWithValue(effectiveRepository),
      ],
      child: const MaterialApp(home: StudentLearningWorkspaceScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required StudentTopicDetail topic,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  String timezone = 'Asia/Tashkent',
}) async {
  return _pumpDetailWithRepository(
    tester,
    FakeStudentTopicRepository(onFetchTopic: (_) async => topic),
    surface: surface,
    timezone: timezone,
  );
}

Future<void> _pumpDetailWithRepository(
  WidgetTester tester,
  FakeStudentTopicRepository repository, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  String timezone = 'Asia/Tashkent',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeStudentAuthSessionController.authenticated(
            studentUser('student-a', institutionTimezone: timezone),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentTopicRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: StudentTopicDetailScreen(topicId: studentTopicId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
