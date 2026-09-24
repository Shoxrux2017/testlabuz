import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_question_builder_screen.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_question_configuration_fields.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('Add opens the shared nine-type editor without a timer', (
    tester,
  ) async {
    await _pumpBuilder(
      tester,
      repository: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(id: id),
      ),
    );
    await _openAddEditor(tester);

    expect(find.byType(TeacherQuestionConfigurationFields), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<TeacherQuestionType>));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Single choice').last);
    await tester.pumpAndSettle();
    for (final timer in ['Time limit', 'Duration', 'Timer', 'seconds']) {
      expect(
        _inEditor(find.textContaining(timer)),
        findsNothing,
        reason: timer,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a valid add appends and adopts the returned Blitz', (
    tester,
  ) async {
    final existing = teacherHomeworkQuestions().take(2).toList();
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async => teacherBlitz(id: id, questions: existing),
      onAddQuestion: (id, _) async => teacherBlitz(
        id: id,
        totalPossiblePoints: 20,
        questions: [...existing, _openWritten(position: 3)],
      ),
    );
    await _pumpBuilder(tester, repository: repository);
    await _openAddEditor(tester);

    await _selectType(tester, TeacherQuestionType.openWritten);
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'Explain the timed method.',
    );
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPointsField')),
      '2',
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorSubmitButton')),
    );
    await tester.pumpAndSettle();

    final request = repository.addQuestionRequests.single;
    expect(request.blitzId, _blitzId);
    expect(request.request.position, 3);
    expect(request.request.toJson().containsKey('id'), isFalse);
    expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsNothing);
    expect(find.text('Question created successfully.'), findsOneWidget);
    expect(find.text('Total points: 20'), findsOneWidget);
  });

  testWidgets('Edit starts from the current Question and skips no-op PATCH', (
    tester,
  ) async {
    final question = teacherHomeworkQuestions()[5];
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async => teacherBlitz(id: id, questions: [question]),
    );
    await _pumpBuilder(tester, repository: repository);
    await _openEditEditor(tester, question.id);

    expect(_inEditor(find.text(question.prompt)), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorSubmitButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.updateQuestionRequests, isEmpty);
    expect(find.text('No changes to save.'), findsOneWidget);
    expect(
      find.byKey(const Key('teacherQuestionEditorDialog')),
      findsOneWidget,
    );
  });

  testWidgets('a changed edit sends only the change and closes on success', (
    tester,
  ) async {
    final question = teacherHomeworkQuestions()[5];
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async => teacherBlitz(id: id, questions: [question]),
      onUpdateQuestion: (_, _) async =>
          teacherBlitz(questions: [_openWritten(position: 1, id: question.id)]),
    );
    await _pumpBuilder(tester, repository: repository);
    await _openEditEditor(tester, question.id);

    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'A clearer written prompt.',
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorSubmitButton')),
    );
    await tester.pumpAndSettle();

    final update = repository.updateQuestionRequests.single;
    expect(update.questionId, question.id);
    expect(update.request.toJson(), {'prompt': 'A clearer written prompt.'});
    expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsNothing);
    expect(find.text('Question updated successfully.'), findsOneWidget);
  });

  testWidgets('server validation maps to the shared editor fields', (
    tester,
  ) async {
    await _pumpBuilder(
      tester,
      repository: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(id: id),
        onAddQuestion: (_, _) async => throw ApiRequestException(
          ApiFailure.fromServerError(
            statusCode: 422,
            error: ApiErrorResponse(
              message: 'Invalid.',
              code: ApiErrorCodes.validationFailed,
              fieldErrors: const {
                'prompt': ['Too long.'],
              },
              requestId: 'req-1',
            ),
          ),
        ),
      ),
    );
    await _openAddEditor(tester);
    await _selectType(tester, TeacherQuestionType.openWritten);
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'Explain the method.',
    );
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPointsField')),
      '2',
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorSubmitButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review the Question prompt.'), findsOneWidget);
    expect(
      find.byKey(const Key('teacherQuestionEditorDialog')),
      findsOneWidget,
    );
  });

  testWidgets('an unreadable outcome blocks until Check current Blitz', (
    tester,
  ) async {
    final question = teacherHomeworkQuestions()[5];
    var reads = 0;
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async {
        reads += 1;
        if (reads == 2) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherBlitz(id: id, questions: [question]);
      },
      onUpdateQuestion: (_, _) async =>
          throw const TeacherQuestionMutationOutcomeUnknownException(
            TeacherQuestionMutationOperation.update,
          ),
    );
    await _pumpBuilder(tester, repository: repository);
    await _openEditEditor(tester, question.id);
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'A clearer written prompt.',
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorSubmitButton')),
    );
    // The retained lease keeps the Builder progress indicator animating.
    await _pumpFrames(tester);

    expect(
      find.text(
        'The current Blitz could not be confirmed. Check the current Blitz '
        'before taking another action.',
      ),
      findsOneWidget,
    );
    expect(find.text('Check current Blitz'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('teacherQuestionEditorCancelButton')),
          )
          .onPressed,
      isNull,
    );
    expect(repository.updateQuestionRequests, hasLength(1));

    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorCheckCurrentButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.updateQuestionRequests, hasLength(1));
    expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsNothing);
    expect(
      find.text(
        'The Question update result could not be confirmed. Review the '
        'current Question before editing again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an uncertain update is success when the fields now match', (
    tester,
  ) async {
    final question = teacherHomeworkQuestions()[5];
    var reads = 0;
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async {
        reads += 1;
        return teacherBlitz(
          id: id,
          questions: [
            reads == 1 ? question : _openWritten(position: 1, id: question.id),
          ],
        );
      },
      onUpdateQuestion: (_, _) async =>
          throw const TeacherQuestionMutationOutcomeUnknownException(
            TeacherQuestionMutationOperation.update,
          ),
    );
    await _pumpBuilder(tester, repository: repository);
    await _openEditEditor(tester, question.id);
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'A clearer written prompt.',
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorSubmitButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.updateQuestionRequests, hasLength(1));
    expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsNothing);
    expect(find.text('Question updated successfully.'), findsOneWidget);
  });

  testWidgets('an uncertain add is never replayed and asks for review', (
    tester,
  ) async {
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async => teacherBlitz(id: id),
      onAddQuestion: (_, _) async =>
          throw const TeacherQuestionMutationOutcomeUnknownException(
            TeacherQuestionMutationOperation.add,
          ),
    );
    await _pumpBuilder(tester, repository: repository);
    await _openAddEditor(tester);
    await _selectType(tester, TeacherQuestionType.openWritten);
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'Explain the method.',
    );
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPointsField')),
      '2',
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorSubmitButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.addQuestionRequests, hasLength(1));
    expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsNothing);
    expect(
      find.text(
        'The Question creation result could not be confirmed. Review the '
        'current Question list before adding another Question.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a lifecycle change locks an open editor', (tester) async {
    var status = TeacherBlitzStatus.draft;
    final question = teacherHomeworkQuestions()[5];
    final repository = FakeTeacherBlitzRepository(
      onFetch: (id) async =>
          teacherBlitz(id: id, status: status, questions: [question]),
    );
    await _pumpBuilder(tester, repository: repository);
    await _openEditEditor(tester, question.id);

    status = TeacherBlitzStatus.active;
    final container = ProviderScope.containerOf(
      tester.element(
        find.byKey(const Key('teacherBlitzQuestionBuilderScreen')),
      ),
    );
    container
        .read(
          teacherBlitzDetailControllerProvider(
            TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId),
          ).notifier,
        )
        .refresh();
    await tester.pumpAndSettle();

    expect(
      _inEditor(
        find.text('Question editing is no longer available for this Blitz.'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('teacherQuestionEditorSubmitButton')),
      findsNothing,
    );
    expect(repository.updateQuestionRequests, isEmpty);
  });

  testWidgets('a dirty editor asks before discarding changes', (tester) async {
    await _pumpBuilder(
      tester,
      repository: FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(id: id),
      ),
    );
    await _openAddEditor(tester);
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'Keep this Blitz draft',
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorCancelButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Discard Question changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('teacherQuestionKeepEditingButton')));
    await tester.pumpAndSettle();
    expect(find.text('Keep this Blitz draft'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorCancelButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherQuestionDiscardChangesButton')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsNothing);
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
  await tester.pumpAndSettle();
}

Future<void> _openAddEditor(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('teacherBlitzQuestionBuilderAddButton')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsOneWidget);
}

Future<void> _openEditEditor(WidgetTester tester, String questionId) async {
  final edit = find.byKey(ValueKey('teacherQuestionEdit$questionId'));
  await tester.ensureVisible(edit);
  await tester.tap(edit);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsOneWidget);
}

Future<void> _selectType(WidgetTester tester, TeacherQuestionType type) async {
  await tester.tap(find.byType(DropdownButtonFormField<TeacherQuestionType>));
  await tester.pumpAndSettle();
  await tester.tap(
    find.text(switch (type) {
      TeacherQuestionType.openWritten => 'Open written',
      _ => throw UnimplementedError('$type'),
    }).last,
  );
  await tester.pumpAndSettle();
}

TeacherQuestion _openWritten({
  required int position,
  String id = '70000000-0000-0000-0000-0000000000ff',
}) {
  return TeacherQuestion(
    id: id,
    type: TeacherQuestionType.openWritten,
    prompt: 'A clearer written prompt.',
    instructions: null,
    points: 2,
    position: position,
    checkingMode: TeacherQuestionCheckingMode.manual,
    configuration: const TeacherEmptyQuestionConfiguration(),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _inEditor(Finder finder) {
  return find.descendant(
    of: find.byKey(const Key('teacherQuestionEditorDialog')),
    matching: finder,
  );
}
