import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_detail_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _studentId = '60000000-0000-0000-0000-000000000001';
const _matchingClientKey = '80000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('Homework detail exposes loading and unavailable states safely', (
    tester,
  ) async {
    final pending = Completer<TeacherHomework>();
    await _pumpDetail(
      tester,
      FakeTeacherHomeworkRepository(onFetch: (_) => pending.future),
    );

    expect(
      find.byKey(const Key('teacherHomeworkDetailLoading')),
      findsOneWidget,
    );
    pending.completeError(
      teacherServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
    );
    await tester.pumpAndSettle();

    expect(find.text('Homework unavailable'), findsOneWidget);
    expect(find.text('Back to Topic'), findsOneWidget);
    expect(find.textContaining(_homeworkId), findsNothing);
  });

  testWidgets('Homework detail error retries without exposing raw failure', (
    tester,
  ) async {
    var calls = 0;
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (homeworkId) async {
        calls += 1;
        if (calls == 1) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherHomework(id: homeworkId);
      },
    );

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherHomeworkDetailError')), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);

    await tester.tap(find.byKey(const Key('teacherHomeworkDetailRetryButton')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Equation practice'), findsOneWidget);
  });

  testWidgets('metadata and every typed Question configuration are read-only', (
    tester,
  ) async {
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (homeworkId) async => teacherHomework(
        id: homeworkId,
        title: 'Comprehensive equation Homework',
        status: TeacherHomeworkStatus.closed,
        questions: teacherHomeworkQuestions(),
      ),
    );

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Comprehensive equation Homework'), findsOneWidget);
    expect(find.text('Closed'), findsWidgets);
    expect(find.text('Whole group'), findsWidgets);
    expect(find.text('Question count'), findsOneWidget);
    expect(find.text('10'), findsWidgets);
    expect(find.text('Deadline'), findsOneWidget);
    expect(find.text('2026-09-10 17:00'), findsOneWidget);
    expect(find.text('Asia/Tashkent'), findsOneWidget);
    expect(find.text('Normal attempts'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Highest valid completed attempt'), findsOneWidget);
    expect(find.text('Activated'), findsOneWidget);
    expect(find.text('Closed'), findsWidgets);

    expect(find.text('Single choice'), findsOneWidget);
    expect(find.text('Multiple choice'), findsOneWidget);
    expect(find.text('True/False'), findsOneWidget);
    expect(find.text('Short written'), findsNWidgets(2));
    expect(find.text('Open written'), findsOneWidget);
    expect(find.text('File based'), findsOneWidget);
    expect(find.text('Matching'), findsOneWidget);
    expect(find.text('Ordering'), findsOneWidget);
    expect(find.text('Fill in the blank'), findsOneWidget);

    expect(find.textContaining('Correct answer: True'), findsOneWidget);
    expect(find.text('Accepted answers'), findsOneWidget);
    expect(find.text('Manual review'), findsNWidgets(3));
    expect(find.text('Allowed files: PDF, DOCX, PPT, PPTX'), findsOneWidget);
    expect(find.text('2 + 2 → 4'), findsOneWidget);
    expect(find.text('1. Simplify'), findsOneWidget);
    expect(find.text('sum: Four, 4'), findsOneWidget);
    expect(find.textContaining('Correct'), findsWidgets);

    expect(find.textContaining(_matchingClientKey), findsNothing);
    expect(find.textContaining(_studentId), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Reorder'), findsNothing);
    expect(find.text('Activate'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'selected recipients show only count and null deadline is clear',
    (tester) async {
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async => teacherHomework(
          id: homeworkId,
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          studentIds: const [
            _studentId,
            '60000000-0000-0000-0000-000000000002',
          ],
          hasDeadline: false,
        ),
      );

      await _pumpDetail(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('Selected students: 2'), findsOneWidget);
      expect(find.text('No deadline'), findsOneWidget);
      expect(find.textContaining(_studentId), findsNothing);
    },
  );

  testWidgets('refresh retains confirmed detail and marks a failure stale', (
    tester,
  ) async {
    final refresh = Completer<TeacherHomework>();
    var calls = 0;
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (homeworkId) {
        calls += 1;
        if (calls == 1) {
          return Future.value(
            teacherHomework(id: homeworkId, title: 'Confirmed Homework'),
          );
        }
        return refresh.future;
      },
    );

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherHomeworkDetailRefreshButton')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('teacherHomeworkDetailProgress')),
      findsOneWidget,
    );
    expect(find.text('Confirmed Homework'), findsOneWidget);

    refresh.completeError(teacherLocalFailure(ApiFailureKind.connection));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailStaleMessage')),
      findsOneWidget,
    );
    expect(find.text('Confirmed Homework'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);
  });

  testWidgets('long typed detail content fits a scaled mobile surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longText = List.filled(
      20,
      'long responsive Homework content',
    ).join(' ');
    final questions = teacherHomeworkQuestions();
    questions[0] = TeacherQuestion(
      id: questions[0].id,
      type: questions[0].type,
      prompt: longText,
      instructions: longText,
      points: questions[0].points,
      position: questions[0].position,
      checkingMode: questions[0].checkingMode,
      configuration: questions[0].configuration,
    );
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (homeworkId) async => teacherHomework(
        id: homeworkId,
        title: longText,
        description: longText,
        studentInstructions: longText,
        questions: questions,
      ),
    );

    await _pumpDetail(
      tester,
      repository,
      surface: AppDeviceSurface.mobile,
      textScaler: const TextScaler.linear(1.5),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailScroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  FakeTeacherHomeworkRepository repository, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const TeacherHomeworkDetailScreen(
          topicId: _topicId,
          homeworkId: _homeworkId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
