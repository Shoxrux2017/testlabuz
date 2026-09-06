import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_create_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_create_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _studentId = '60000000-0000-0000-0000-000000000001';

void main() {
  testWidgets(
    'create form exposes exact metadata, assignment, and fixed policy',
    (tester) async {
      await _pumpCreate(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherHomeworkTitleField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherHomeworkDescriptionField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherHomeworkInstructionsField')),
        findsOneWidget,
      );
      expect(find.text('Topic title: Linear equations'), findsOneWidget);
      expect(find.text('Group: Group A'), findsOneWidget);
      expect(find.text('Topic status: Draft'), findsOneWidget);
      expect(find.text('Whole group'), findsOneWidget);
      expect(find.text('Selected students'), findsOneWidget);
      expect(find.text('Normal attempts: 3'), findsOneWidget);
      expect(find.text('The attempt limit cannot be changed.'), findsOneWidget);
      expect(
        find.text('Questions can be added after the draft is created.'),
        findsOneWidget,
      );
      expect(find.text('Add Question'), findsNothing);
      expect(find.text('Question Builder'), findsNothing);

      await tester.ensureVisible(find.text('Selected students'));
      await tester.tap(find.text('Selected students'));
      await tester.pump();
      expect(
        find.byKey(const Key('teacherHomeworkStudentSelectionControl')),
        findsOneWidget,
      );
      expect(find.text('0 Students selected'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('teacherHomeworkCreateScreen'))),
      );
      final controller = container.read(
        teacherHomeworkCreateControllerProvider(_topicId).notifier,
      );
      controller.updateSelectedStudentIds(const {_studentId});
      await tester.pump();
      expect(find.text('1 Student selected'), findsOneWidget);

      await tester.ensureVisible(find.text('Whole group'));
      await tester.tap(find.text('Whole group'));
      await tester.pump();
      await tester.ensureVisible(find.text('Selected students'));
      await tester.tap(find.text('Selected students'));
      await tester.pump();
      expect(find.text('1 Student selected'), findsOneWidget);
    },
  );

  testWidgets('deadline picker opens and a chosen wall clock can be cleared', (
    tester,
  ) async {
    await _pumpCreate(tester);
    await tester.pumpAndSettle();

    final deadlineButton = find.byKey(
      const Key('teacherHomeworkChooseDeadlineButton'),
    );
    await tester.ensureVisible(deadlineButton);
    await tester.tap(deadlineButton);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('teacherHomeworkCreateScreen'))),
    );
    container
        .read(teacherHomeworkCreateControllerProvider(_topicId).notifier)
        .updateDeadlineAt(
          const InstitutionWallClock(
            year: 2026,
            month: 9,
            day: 15,
            hour: 17,
            minute: 30,
          ),
        );
    await tester.pump();
    expect(find.text('2026-09-15 17:30'), findsOneWidget);

    final clear = find.byKey(const Key('teacherHomeworkClearDeadlineButton'));
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pump();
    expect(find.text('No deadline'), findsOneWidget);
  });

  testWidgets('dirty Back is guarded and stale confirmation cannot navigate', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController.authenticated(
      teacherUser('teacher-a'),
    );
    await _pumpCreate(tester, auth: auth);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('teacherHomeworkTitleField')),
      'Changed locally',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('teacherHomeworkCreateBackButton')));
    await tester.pump();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('teacherHomeworkCreateKeepEditingButton')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherHomeworkCreateScreen')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('teacherHomeworkCreateBackButton')));
    await tester.pump();
    auth.replaceUser(teacherUser('teacher-b'));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('teacherHomeworkCreateDiscardButton')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkCreateScreen')),
      findsOneWidget,
    );
  });

  testWidgets(
    'submitting disables actions and unknown outcome requires review',
    (tester) async {
      final pending = Completer<TeacherHomework>();
      await _pumpCreate(
        tester,
        homework: FakeTeacherHomeworkRepository(
          onCreate: (_, _) => pending.future,
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('teacherHomeworkCreateScreen'))),
      );
      container.read(teacherHomeworkCreateControllerProvider(_topicId).notifier)
        ..updateTitle('New Homework')
        ..updateStudentInstructions('Complete every problem.');
      await tester.pump();

      final submit = find.byKey(const Key('teacherHomeworkCreateSubmitButton'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(
        find.byKey(const Key('teacherHomeworkCreateProgress')),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('teacherHomeworkCreateCancelButton')),
            )
            .onPressed,
        isNull,
      );

      pending.completeError(Exception('ambiguous transport completion'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherHomeworkCreateUnknownOutcome')),
        findsOneWidget,
      );
      expect(find.text('Creation outcome unknown'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherHomeworkCreateReviewHomeworkButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherHomeworkCreateSubmitButton')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'stale Student picker result cannot update a replacement session',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      await _pumpCreate(tester, auth: auth);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Selected students'));
      await tester.tap(find.text('Selected students'));
      await tester.pump();
      final choose = find.byKey(
        const Key('teacherHomeworkChooseStudentsButton'),
      );
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pump();

      final dialog = find.byKey(
        const Key('teacherHomeworkStudentPickerDialog'),
      );
      expect(dialog, findsOneWidget);
      final dialogContext = tester.element(dialog);
      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      Navigator.of(dialogContext).pop(const {_studentId});
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('teacherHomeworkCreateScreen'))),
      );
      final state = container.read(
        teacherHomeworkCreateControllerProvider(_topicId),
      );
      expect(state.form.selectedStudentIds, isEmpty);
    },
  );

  testWidgets('narrow scaled desktop create form scrolls without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpCreate(tester);
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCreate(
  WidgetTester tester, {
  FakeTeacherAuthSessionController? auth,
  FakeTeacherTopicRepository? topics,
  FakeTeacherHomeworkRepository? homework,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeTeacherAuthSessionController.authenticated(
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
        home: TeacherHomeworkCreateScreen(topicId: _topicId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
