import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_edit_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('edit initializes controlled metadata and fixed attempt policy', (
    tester,
  ) async {
    await _pumpEdit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Edit Homework'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Topic title: Linear equations'), findsOneWidget);
    expect(find.text('Group: Group A'), findsOneWidget);
    expect(find.text('Normal attempts: 3'), findsOneWidget);
    expect(find.text('The attempt limit cannot be changed.'), findsOneWidget);
    expect(find.text('Questions can be added'), findsNothing);
    expect(find.text('Add Question'), findsNothing);

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('teacherHomeworkTitleField')))
          .controller!
          .text,
      'Equation practice',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('teacherHomeworkDescriptionField')),
          )
          .controller!
          .text,
      'Practice the lesson concepts.',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('teacherHomeworkInstructionsField')),
          )
          .controller!
          .text,
      'Answer every question.',
    );
    expect(find.text('2026-09-10 17:00'), findsOneWidget);
  });

  testWidgets(
    'active Homework displays the server-authority information note',
    (tester) async {
      await _pumpEdit(
        tester,
        homework: FakeTeacherHomeworkRepository(
          onFetch: (id) async =>
              teacherHomework(id: id, status: TeacherHomeworkStatus.active),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherHomeworkEditActiveNote')),
        findsOneWidget,
      );
      expect(
        find.textContaining('server will confirm what is still editable'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherHomeworkEditSubmitButton')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'closed Homework deep link is review-only without a false draft',
    (tester) async {
      await _pumpEdit(
        tester,
        homework: FakeTeacherHomeworkRepository(
          onFetch: (id) async =>
              teacherHomework(id: id, status: TeacherHomeworkStatus.closed),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This Homework is no longer editable.'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherHomeworkCurrentServerState')),
        findsOneWidget,
      );
      expect(find.text('Attempted changes (read-only)'), findsNothing);
      expect(find.byKey(const Key('teacherHomeworkTitleField')), findsNothing);
      expect(
        find.byKey(const Key('teacherHomeworkEditBackToHomeworkButton')),
        findsOneWidget,
      );
    },
  );

  testWidgets('dirty edit Back requires an explicit discard decision', (
    tester,
  ) async {
    await _pumpEdit(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('teacherHomeworkTitleField')),
      'Locally changed Homework',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('teacherHomeworkEditBackButton')));
    await tester.pump();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('teacherHomeworkEditKeepEditingButton')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherHomeworkEditScreen')), findsOneWidget);
  });

  testWidgets(
    'recognized conflict presents current and attempted values safely',
    (tester) async {
      final current = teacherHomework(
        id: _homeworkId,
        title: 'Current server Homework',
        description: null,
        studentInstructions: 'Current server instructions',
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => current,
        onUpdate: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.businessConflict,
          statusCode: 409,
        ),
      );
      await _pumpEdit(tester, homework: repository);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('teacherHomeworkTitleField')),
        'Attempted Homework title',
      );
      await tester.pump();
      final save = find.byKey(const Key('teacherHomeworkEditSubmitButton'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherHomeworkEditReviewMessage')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherHomeworkCurrentServerState')),
        findsOneWidget,
      );
      expect(find.text('Title: Current server Homework'), findsOneWidget);
      expect(find.text('Description: No description'), findsOneWidget);
      expect(
        find.text('Student instructions: Current server instructions'),
        findsOneWidget,
      );
      expect(find.text('Attempted changes (read-only)'), findsOneWidget);
      expect(find.text('Attempted Homework title'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherHomeworkEditReviewHomeworkButton')),
        findsOneWidget,
      );
      expect(find.textContaining('Raw server failure'), findsNothing);
    },
  );

  testWidgets(
    'unknown update requires current-Homework reconciliation before leaving',
    (tester) async {
      var fetchCount = 0;
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          if (fetchCount == 1) {
            return teacherHomework(id: _homeworkId);
          }
          throw Exception('ambiguous reconciliation failure');
        },
        onUpdate: (_, _) async {
          throw Exception('ambiguous mutation completion');
        },
      );
      await _pumpEdit(tester, homework: repository);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('teacherHomeworkTitleField')),
        'Attempted Homework title',
      );
      await tester.pump();
      final save = find.byKey(const Key('teacherHomeworkEditSubmitButton'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherHomeworkEditCheckCurrentButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherHomeworkEditReviewHomeworkButton')),
        findsNothing,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('teacherHomeworkEditBackButton')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('narrow scaled desktop edit form scrolls without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final longText = List.filled(20, 'long Homework metadata').join(' ');
    await _pumpEdit(
      tester,
      homework: FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(
          id: id,
          title: longText,
          description: longText,
          studentInstructions: longText,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpEdit(
  WidgetTester tester, {
  FakeTeacherTopicRepository? topics,
  FakeTeacherHomeworkRepository? homework,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherTopicRepositoryProvider.overrideWithValue(
          topics ?? FakeTeacherTopicRepository(),
        ),
        teacherHomeworkRepositoryProvider.overrideWithValue(
          homework ?? FakeTeacherHomeworkRepository(),
        ),
        teacherGroupStudentRepositoryProvider.overrideWithValue(
          FakeTeacherGroupStudentRepository(),
        ),
      ],
      child: const MaterialApp(
        home: TeacherHomeworkEditScreen(
          topicId: _topicId,
          homeworkId: _homeworkId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
