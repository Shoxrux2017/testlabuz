import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_question_builder_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';

void main() {
  testWidgets(
    'Builder shows server totals, all nine Question types, and no lifecycle',
    (tester) async {
      final questions = teacherHomeworkQuestions();
      await _pumpBuilder(
        tester,
        repository: FakeTeacherBlitzRepository(
          onFetch: (id) async => teacherBlitz(
            id: id,
            title: 'All nine Blitz Questions',
            totalPossiblePoints: 12.5,
            questions: questions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Question Builder'), findsOneWidget);
      expect(find.text('All nine Blitz Questions'), findsOneWidget);
      expect(find.text('Draft'), findsWidgets);
      expect(find.text('Total points: 12.5'), findsOneWidget);
      expect(find.text('Questions: 10'), findsOneWidget);
      for (final label in [
        'Single choice',
        'Multiple choice',
        'True/False',
        'Short written',
        'Open written',
        'File based',
        'Matching',
        'Ordering',
        'Fill in the blank',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(
        find.byKey(const Key('teacherBlitzQuestionBuilderAddButton')),
        findsOneWidget,
      );
      for (final lifecycle in [
        'Schedule',
        'Activate',
        'Close',
        'Archive',
        'Official Blitz',
      ]) {
        expect(find.text(lifecycle), findsNothing, reason: lifecycle);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Scheduled Blitz keeps Question controls', (tester) async {
    final questions = teacherHomeworkQuestions().take(2).toList();
    await _pumpBuilder(
      tester,
      repository: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(
          id: id,
          status: TeacherBlitzStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 18, 4),
          questions: questions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _filledButton(tester, 'teacherBlitzQuestionBuilderAddButton'),
      isNotNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(ValueKey('teacherQuestionEdit${questions.first.id}')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Active, Closed, and Archived Blitz are review-only', (
    tester,
  ) async {
    for (final status in [
      TeacherBlitzStatus.active,
      TeacherBlitzStatus.closed,
      TeacherBlitzStatus.archived,
    ]) {
      await _pumpBuilder(
        tester,
        repository: FakeTeacherBlitzRepository(
          onFetch: (id) async => teacherBlitz(
            id: id,
            status: status,
            questions: [teacherHomeworkQuestions().first],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Question editing is unavailable for this Blitz.'),
        findsOneWidget,
        reason: status.value,
      );
      expect(
        find.byKey(const Key('teacherBlitzQuestionBuilderBackToBlitzButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherBlitzQuestionBuilderAddButton')),
        findsNothing,
      );
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(
        find.text(teacherHomeworkQuestions().first.prompt),
        findsOneWidget,
      );
    }
  });

  testWidgets('Delete requires confirmation and adopts the returned Blitz', (
    tester,
  ) async {
    final questions = teacherHomeworkQuestions().take(2).toList();
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async => teacherBlitz(id: id, questions: questions),
      onDeleteQuestion: (_) async => teacherBlitz(
        totalPossiblePoints: 4,
        questions: [
          TeacherQuestion(
            id: questions[1].id,
            type: questions[1].type,
            prompt: questions[1].prompt,
            instructions: questions[1].instructions,
            points: questions[1].points,
            position: 1,
            checkingMode: questions[1].checkingMode,
            configuration: questions[1].configuration,
          ),
        ],
      ),
    );
    await _pumpBuilder(tester, repository: repository);
    await tester.pumpAndSettle();

    final delete = find.byKey(
      ValueKey('teacherQuestionDelete${questions.first.id}'),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('Delete Question 1?'), findsOneWidget);
    expect(
      find.text('This removes the Question and its answer configuration.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('teacherBlitzQuestionDeleteCancelButton')),
    );
    await tester.pumpAndSettle();
    expect(repository.deleteQuestionIds, isEmpty);

    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherBlitzQuestionDeleteConfirmButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteQuestionIds, [questions.first.id]);
    expect(find.text('Question deleted successfully.'), findsOneWidget);
    expect(find.text('Total points: 4'), findsOneWidget);
    expect(find.text('Questions: 1'), findsOneWidget);
  });

  testWidgets('staged order guards Back and Refresh and saves every ID', (
    tester,
  ) async {
    final questions = teacherHomeworkQuestions().take(2).toList();
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async => teacherBlitz(id: id, questions: questions),
      onReorderQuestions: (id, _) async => teacherBlitz(
        id: id,
        questions: [
          for (final (index, question) in [questions[1], questions[0]].indexed)
            TeacherQuestion(
              id: question.id,
              type: question.type,
              prompt: question.prompt,
              instructions: question.instructions,
              points: question.points,
              position: index + 1,
              checkingMode: question.checkingMode,
              configuration: question.configuration,
            ),
        ],
      ),
    );
    await _pumpBuilder(tester, repository: repository);
    await tester.pumpAndSettle();

    final moveSecondUp = find.byKey(
      ValueKey('teacherQuestionMoveUp${questions[1].id}'),
    );
    await tester.ensureVisible(moveSecondUp);
    await tester.tap(moveSecondUp);
    await tester.pump();

    expect(
      _filledButton(tester, 'teacherBlitzQuestionBuilderAddButton'),
      isNull,
    );
    final refresh = find.byKey(
      const Key('teacherBlitzQuestionBuilderRefreshButton'),
    );
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved Question order?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('teacherBlitzQuestionRefreshKeepOrderButton')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('teacherBlitzQuestionBuilderBackButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved Question order?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('teacherBlitzQuestionBackKeepOrderButton')),
    );
    await tester.pumpAndSettle();

    final save = find.byKey(
      const Key('teacherBlitzQuestionBuilderSaveOrderButton'),
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.reorderQuestionRequests.single.request.questionIds, [
      questions[1].id,
      questions[0].id,
    ]);
    expect(find.text('Questions reordered successfully.'), findsOneWidget);
    expect(
      find.byKey(const Key('teacherBlitzQuestionBuilderSaveOrderButton')),
      findsNothing,
    );
  });

  testWidgets('maximum Question count disables Add', (tester) async {
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
      repository: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(id: id, questions: questions),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maximum 100 Questions.'), findsOneWidget);
    expect(
      _filledButton(tester, 'teacherBlitzQuestionBuilderAddButton'),
      isNull,
    );
  });

  testWidgets('a server lock stays visible and blocks mutations', (
    tester,
  ) async {
    final questions = teacherHomeworkQuestions().take(2).toList();
    await _pumpBuilder(
      tester,
      repository: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(id: id, questions: questions),
        onDeleteQuestion: (_) async => throw teacherServerFailure(
          ApiErrorCodes.businessConflict,
          statusCode: 409,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final delete = find.byKey(
      ValueKey('teacherQuestionDelete${questions.first.id}'),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherBlitzQuestionDeleteConfirmButton')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherBlitzQuestionBuilderLockedBanner')),
      findsOneWidget,
    );
    expect(
      _filledButton(tester, 'teacherBlitzQuestionBuilderAddButton'),
      isNull,
    );
  });

  testWidgets('a stale Blitz keeps Questions visible but disables changes', (
    tester,
  ) async {
    final questions = teacherHomeworkQuestions().take(2).toList();
    var reads = 0;
    await _pumpBuilder(
      tester,
      repository: FakeTeacherBlitzRepository(
        onFetch: (id) async {
          reads += 1;
          if (reads > 1) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherBlitz(id: id, questions: questions);
        },
      ),
    );
    await tester.pumpAndSettle();

    final refresh = find.byKey(
      const Key('teacherBlitzQuestionBuilderRefreshButton'),
    );
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherBlitzQuestionBuilderStaleMessage')),
      findsOneWidget,
    );
    expect(find.text(questions.first.prompt), findsOneWidget);
    expect(
      _filledButton(tester, 'teacherBlitzQuestionBuilderAddButton'),
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
  });

  testWidgets('loading, error, and missing Blitz states are safe', (
    tester,
  ) async {
    final pending = Completer<TeacherBlitz>();
    await _pumpBuilder(
      tester,
      repository: FakeTeacherBlitzRepository(onFetch: (_) => pending.future),
    );
    expect(
      find.byKey(const Key('teacherBlitzQuestionBuilderLoading')),
      findsOneWidget,
    );
    pending.completeError(teacherLocalFailure(ApiFailureKind.connection));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherBlitzQuestionBuilderError')),
      findsOneWidget,
    );
    expect(find.textContaining('Raw local failure'), findsNothing);

    await _pumpBuilder(
      tester,
      repository: FakeTeacherBlitzRepository(
        onFetch: (_) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherBlitzQuestionBuilderUnavailable')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpBuilder(
  WidgetTester tester, {
  required FakeTeacherBlitzRepository repository,
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
        teacherBlitzRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: TeacherBlitzQuestionBuilderScreen(
          topicId: _topicId,
          blitzId: _blitzId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

VoidCallback? _filledButton(WidgetTester tester, String key) {
  return tester.widget<FilledButton>(find.byKey(Key(key))).onPressed;
}

String _questionId(int value) {
  return '70000000-0000-0000-0000-${value.toString().padLeft(12, '0')}';
}
