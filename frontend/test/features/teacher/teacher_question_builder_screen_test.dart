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
import 'package:testlabuz_client/features/teacher/presentation/teacher_question_builder_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  testWidgets(
    'Builder shows authoritative context, cards, configurations, and controls',
    (tester) async {
      final questions = teacherHomeworkQuestions();
      await _pumpBuilder(
        tester,
        repository: FakeTeacherHomeworkRepository(
          onFetch: (id) async => teacherHomework(
            id: id,
            title: 'All nine Question types',
            totalPossiblePoints: 12.5,
            questions: questions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Question Builder'), findsOneWidget);
      expect(find.text('All nine Question types'), findsOneWidget);
      expect(find.text('Total points: 12.5'), findsOneWidget);
      expect(find.text('Questions: 10'), findsOneWidget);
      for (final label in [
        'Single choice',
        'Multiple choice',
        'True/False',
        'Open written',
        'File based',
        'Matching',
        'Ordering',
        'Fill in the blank',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('Accepted answers'), findsWidgets);
      expect(find.text('Allowed files: PDF, DOCX, PPT, PPTX'), findsOneWidget);
      expect(find.text('2 + 2 → 4'), findsOneWidget);
      expect(find.text('1. Simplify'), findsOneWidget);
      expect(find.text('sum: Four, 4'), findsOneWidget);

      final firstMoveUp = tester.widget<IconButton>(
        find.byKey(ValueKey('teacherQuestionMoveUp${questions.first.id}')),
      );
      final lastMoveDown = tester.widget<IconButton>(
        find.byKey(ValueKey('teacherQuestionMoveDown${questions.last.id}')),
      );
      expect(firstMoveUp.onPressed, isNull);
      expect(lastMoveDown.onPressed, isNull);
      expect(find.text('Activate'), findsNothing);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Official Homework'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('local order disables mutations and guards refresh and back', (
    tester,
  ) async {
    final questions = teacherHomeworkQuestions().take(2).toList();
    await _pumpBuilder(
      tester,
      repository: FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(id: id, questions: questions),
      ),
    );
    await tester.pumpAndSettle();

    final moveSecondUp = find.byKey(
      ValueKey('teacherQuestionMoveUp${questions[1].id}'),
    );
    await tester.ensureVisible(moveSecondUp);
    expect(tester.widget<IconButton>(moveSecondUp).onPressed, isNotNull);
    await tester.tap(moveSecondUp);
    await tester.pump();

    expect(
      find.byKey(const Key('teacherQuestionBuilderSaveOrderButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('teacherQuestionBuilderResetOrderButton')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('teacherQuestionBuilderAddButton')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(ValueKey('teacherQuestionEdit${questions.first.id}')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(ValueKey('teacherQuestionDelete${questions.first.id}')),
          )
          .onPressed,
      isNull,
    );

    final refresh = find.byKey(
      const Key('teacherQuestionBuilderRefreshButton'),
    );
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(
      find.text('Discard unsaved Question order and refresh?'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionRefreshKeepOrderButton')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherQuestionBuilderSaveOrderButton')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('teacherQuestionBuilderBackButton')));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved Question order?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('teacherQuestionBackKeepOrderButton')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherQuestionBuilderScreen')),
      findsOneWidget,
    );

    final reset = find.byKey(
      const Key('teacherQuestionBuilderResetOrderButton'),
    );
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pump();
    expect(
      find.byKey(const Key('teacherQuestionBuilderSaveOrderButton')),
      findsNothing,
    );
  });

  testWidgets('delete confirmation and server lock remain safe', (
    tester,
  ) async {
    final question = teacherHomeworkQuestions().first;
    final current = teacherHomework(questions: [question]);
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (_) async => current,
      onDeleteQuestion: (_) async => throw teacherServerFailure(
        ApiErrorCodes.businessConflict,
        statusCode: 409,
      ),
    );
    await _pumpBuilder(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('teacherQuestionDelete${question.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete Question 1?'), findsOneWidget);
    expect(
      find.text('This removes the Question and its answer configuration.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionDeleteCancelButton')),
    );
    await tester.pumpAndSettle();
    expect(repository.deleteQuestionIds, isEmpty);

    await tester.tap(
      find.byKey(ValueKey('teacherQuestionDelete${question.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherQuestionDeleteConfirmButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteQuestionIds, [question.id]);
    expect(
      find.byKey(const Key('teacherQuestionBuilderLockedBanner')),
      findsOneWidget,
    );
    expect(find.textContaining('Question editing is locked'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('teacherQuestionBuilderAddButton')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('maximum count and closed Homework are review-safe', (
    tester,
  ) async {
    final questions = List<TeacherQuestion>.generate(
      100,
      (index) => TeacherQuestion(
        id: _questionId(index + 1),
        type: TeacherQuestionType.openWritten,
        prompt: 'Question ${index + 1}',
        instructions: null,
        points: 1,
        position: index + 1,
        checkingMode: TeacherQuestionCheckingMode.manual,
        configuration: const TeacherEmptyQuestionConfiguration(),
      ),
    );
    await _pumpBuilder(
      tester,
      repository: FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(id: id, questions: questions),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maximum 100 Questions.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('teacherQuestionBuilderAddButton')),
          )
          .onPressed,
      isNull,
    );

    await _pumpBuilder(
      tester,
      repository: FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(
          id: id,
          status: TeacherHomeworkStatus.closed,
          questions: [teacherHomeworkQuestions().first],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Question editing is unavailable for this Homework.'),
      findsOneWidget,
    );
    expect(find.text('Back to Homework'), findsWidgets);
    expect(
      find.byKey(const Key('teacherQuestionBuilderAddButton')),
      findsNothing,
    );
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('loading and safe error states do not expose raw failures', (
    tester,
  ) async {
    final pending = Completer<TeacherHomework>();
    await _pumpBuilder(
      tester,
      repository: FakeTeacherHomeworkRepository(onFetch: (_) => pending.future),
    );
    expect(
      find.byKey(const Key('teacherQuestionBuilderLoading')),
      findsOneWidget,
    );

    pending.completeError(teacherLocalFailure(ApiFailureKind.connection));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherQuestionBuilderError')),
      findsOneWidget,
    );
    expect(find.textContaining('Raw local failure'), findsNothing);
  });
}

Future<void> _pumpBuilder(
  WidgetTester tester, {
  required FakeTeacherHomeworkRepository repository,
}) async {
  await tester.binding.setSurfaceSize(const Size(1180, 820));
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
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: TeacherQuestionBuilderScreen(
          topicId: _topicId,
          homeworkId: _homeworkId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _questionId(int value) {
  return '70000000-0000-0000-0000-${value.toString().padLeft(12, '0')}';
}
