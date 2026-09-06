import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_builder_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_question_builder_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  testWidgets(
    'Add editor starts with an accessible typed form and reports local errors',
    (tester) async {
      await _pumpBuilder(
        tester,
        repository: FakeTeacherHomeworkRepository(
          onFetch: (id) async => teacherHomework(id: id),
        ),
      );
      await _openAddEditor(tester);

      expect(find.text('Add Question'), findsWidgets);
      expect(find.byKey(const Key('teacherQuestionTypeField')), findsOneWidget);
      expect(
        find.byKey(const Key('teacherQuestionPromptField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherQuestionInstructionsField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherQuestionPointsField')),
        findsOneWidget,
      );
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Correct Option 1'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(_iconButtonWithTooltip('Remove Option 1'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(_iconButtonWithTooltip('Remove Option 2'))
            .onPressed,
        isNull,
      );
      expect(find.text('Activate'), findsNothing);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Official Homework'), findsNothing);

      await tester.tap(
        find.byKey(const Key('teacherQuestionEditorSubmitButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a Question prompt of 10000 characters or fewer.'),
        findsOneWidget,
      );
      expect(find.text('Review the Question configuration.'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Edit editor renders every delivered Question configuration', (
    tester,
  ) async {
    final cases = <({TeacherQuestion question, List<String> expected})>[
      (
        question: teacherHomeworkQuestions()[0],
        expected: const ['Option 1', 'Option 2', 'Four', 'Five'],
      ),
      (
        question: teacherHomeworkQuestions()[1],
        expected: const [
          'Option 1',
          'Option 2',
          'Option 3',
          'Students may select up to the number of correct options.',
        ],
      ),
      (
        question: teacherHomeworkQuestions()[2],
        expected: const ['Correct answer:', 'True', 'False'],
      ),
      (
        question: teacherHomeworkQuestions()[3],
        expected: const ['Accepted answers', 'Answer 1', 'Answer 2'],
      ),
      (
        question: teacherHomeworkQuestions()[5],
        expected: const ['This Question is reviewed manually.'],
      ),
      (
        question: teacherHomeworkQuestions()[6],
        expected: const ['Allowed files:', 'PDF', 'DOCX', 'PPT', 'PPTX'],
      ),
      (
        question: teacherHomeworkQuestions()[7],
        expected: const ['Pair 1 left', 'Pair 1 right', '2 + 2', '4'],
      ),
      (
        question: teacherHomeworkQuestions()[8],
        expected: const ['Correct order', 'Item 1', 'Item 2'],
      ),
      (
        question: teacherHomeworkQuestions()[9],
        expected: const [
          'Use the placeholder {{key}} in the Question prompt.',
          'Blank 1 key',
          'Blank 1 answer 1',
        ],
      ),
    ];

    for (final testCase in cases) {
      await _pumpBuilder(
        tester,
        repository: FakeTeacherHomeworkRepository(
          onFetch: (id) async =>
              teacherHomework(id: id, questions: [testCase.question]),
        ),
      );
      await _openEditEditor(tester, testCase.question.id);

      expect(find.text('Edit Question'), findsOneWidget);
      for (final text in testCase.expected) {
        expect(
          find.text(text),
          findsWidgets,
          reason: '${testCase.question.type.value} should show "$text".',
        );
      }
      if (testCase.question.type == TeacherQuestionType.matching) {
        expect(find.text('80000000-0000-0000-0000-000000000001'), findsNothing);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const Key('teacherQuestionEditorCancelButton')),
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets('type and Short Written mode changes require explicit consent', (
    tester,
  ) async {
    final single = teacherHomeworkQuestions()[0];
    await _pumpBuilder(
      tester,
      repository: FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(id: id, questions: [single]),
      ),
    );
    await _openEditEditor(tester, single.id);

    await _selectType(tester, TeacherQuestionType.matching);
    expect(find.text('Change Question type?'), findsOneWidget);
    expect(
      find.text('Changing the type will reset its answer configuration.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('teacherQuestionKeepTypeButton')));
    await tester.pumpAndSettle();
    expect(find.text('Option 1'), findsOneWidget);
    expect(find.text('Pair 1 left'), findsNothing);

    await _selectType(tester, TeacherQuestionType.matching);
    await tester.tap(find.byKey(const Key('teacherQuestionConfirmTypeButton')));
    await tester.pumpAndSettle();
    expect(find.text('Pair 1 left'), findsOneWidget);
    expect(find.text('Option 1'), findsNothing);

    await tester.tap(
      find.byKey(const Key('teacherQuestionEditorCancelButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherQuestionDiscardChangesButton')),
    );
    await tester.pumpAndSettle();

    final shortWritten = teacherHomeworkQuestions()[3];
    await _pumpBuilder(
      tester,
      repository: FakeTeacherHomeworkRepository(
        onFetch: (id) async =>
            teacherHomework(id: id, questions: [shortWritten]),
      ),
    );
    await _openEditEditor(tester, shortWritten.id);

    final manual = find.text('Manual');
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(find.text('Change checking mode?'), findsOneWidget);
    expect(
      find.text(
        'Changing to Manual will remove the accepted-answer configuration.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('teacherQuestionKeepCheckingModeButton')),
    );
    await tester.pumpAndSettle();
    expect(_inEditor(find.text('Accepted answers')), findsOneWidget);

    await tester.ensureVisible(find.text('Manual'));
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherQuestionConfirmCheckingModeButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('This Question is reviewed manually.'), findsOneWidget);
    expect(_inEditor(find.text('Accepted answers')), findsNothing);
  });

  testWidgets(
    'dirty editor protects Cancel and preserves work when requested',
    (tester) async {
      await _pumpBuilder(
        tester,
        repository: FakeTeacherHomeworkRepository(
          onFetch: (id) async => teacherHomework(id: id),
        ),
      );
      await _openAddEditor(tester);

      await tester.enterText(
        find.byKey(const Key('teacherQuestionPromptField')),
        'Keep this draft',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('teacherQuestionEditorCancelButton')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Discard Question changes?'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('teacherQuestionKeepEditingButton')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('teacherQuestionEditorCancelButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherQuestionDiscardChangesButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'valid add submits a numeric request and closes on confirmation',
    (tester) async {
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(id: id),
        onAddQuestion: (id, request) async =>
            teacherHomework(id: id, questions: [teacherHomeworkQuestions()[0]]),
      );
      await _pumpBuilder(tester, repository: repository);
      await _openAddEditor(tester);

      await tester.enterText(
        find.byKey(const Key('teacherQuestionPromptField')),
        '  Which value is four?  ',
      );
      await tester.enterText(
        find.byKey(const Key('teacherQuestionPointsField')),
        '1.5',
      );
      await tester.ensureVisible(_textFieldWithLabel('Option 1'));
      await tester.enterText(_textFieldWithLabel('Option 1'), 'Four');
      await tester.ensureVisible(_textFieldWithLabel('Option 2'));
      await tester.enterText(_textFieldWithLabel('Option 2'), 'Five');
      await tester.tap(
        find.byKey(const Key('teacherQuestionEditorSubmitButton')),
      );
      await tester.pumpAndSettle();

      expect(repository.addQuestionRequests, hasLength(1));
      final request = repository.addQuestionRequests.single.request;
      expect(request.position, 1);
      expect(request.prompt, 'Which value is four?');
      expect(request.points, 1.5);
      expect(request.toJson()['points'], isA<num>());
      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsNothing,
      );
      expect(find.text('Question created successfully.'), findsOneWidget);
    },
  );

  testWidgets('unchanged edit stays open and never sends PATCH', (
    tester,
  ) async {
    final question = teacherHomeworkQuestions()[0];
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (id) async => teacherHomework(id: id, questions: [question]),
    );
    await _pumpBuilder(tester, repository: repository);
    await _openEditEditor(tester, question.id);

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

  testWidgets('editor remains scrollable without overflow on compact desktop', (
    tester,
  ) async {
    final question = TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000099',
      type: TeacherQuestionType.multipleChoice,
      prompt: List.filled(20, 'A detailed Unicode prompt \u{1F9EA}').join(' '),
      instructions: List.filled(12, 'Read carefully.').join(' '),
      points: 999999.999999,
      position: 1,
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configuration: TeacherChoiceQuestionConfiguration(
        options: List.generate(
          8,
          (index) => TeacherChoiceOption(
            text: 'Option ${index + 1}',
            isCorrect: index.isEven,
            position: index + 1,
          ),
        ),
      ),
    );
    await _pumpBuilder(
      tester,
      repository: FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(id: id, questions: [question]),
      ),
      size: const Size(800, 620),
      textScaler: const TextScaler.linear(1.25),
    );
    await _openEditEditor(tester, question.id);

    expect(
      find.byKey(const Key('teacherQuestionEditorScroll')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('teacherQuestionEditorScroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Option 8'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same-target Builder takeover dismisses only the stale dirty editor',
    (tester) async {
      await _pumpBuilder(
        tester,
        repository: FakeTeacherHomeworkRepository(
          onFetch: (id) async => teacherHomework(id: id),
        ),
      );
      await _openAddEditor(tester);
      await tester.enterText(
        find.byKey(const Key('teacherQuestionPromptField')),
        'Unsaved stale editor',
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('teacherQuestionBuilderScreen'))),
      );
      final target = TeacherHomeworkRouteTarget(
        topicId: _topicId,
        homeworkId: _homeworkId,
      );
      final builder = container.read(
        teacherQuestionBuilderControllerProvider(target).notifier,
      );
      final newerDialog = showDialog<void>(
        context: tester.element(
          find.byKey(const Key('teacherQuestionEditorDialog')),
        ),
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          key: const Key('newerSameTargetDialog'),
          title: const Text('Newer route dialog'),
          actions: [
            TextButton(
              key: const Key('closeNewerSameTargetDialog'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close newer dialog'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final replacementGeneration = builder.enterRoute();

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('newerSameTargetDialog')), findsOneWidget);
      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('closeNewerSameTargetDialog')));
      await tester.pumpAndSettle();
      await newerDialog;

      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsNothing,
      );
      expect(find.text('Discard Question changes?'), findsNothing);
      expect(
        find.byKey(const Key('teacherQuestionBuilderScreen')),
        findsOneWidget,
      );
      expect(builder.ownsRouteGeneration(replacementGeneration), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('null session dismisses a dirty editor without confirmation', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController.authenticated(
      teacherUser('teacher-a'),
    );
    await _pumpBuilder(
      tester,
      repository: FakeTeacherHomeworkRepository(
        onFetch: (id) async => teacherHomework(id: id),
      ),
      auth: auth,
    );
    await _openAddEditor(tester);
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'Unsaved session editor',
    );
    await tester.pump();

    auth.logOut();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsNothing);
    expect(find.text('Discard Question changes?'), findsNothing);
    expect(
      find.byKey(const Key('teacherQuestionBuilderUnavailable')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpBuilder(
  WidgetTester tester, {
  required FakeTeacherHomeworkRepository repository,
  FakeTeacherAuthSessionController? auth,
  Size size = const Size(1180, 820),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const TeacherQuestionBuilderScreen(
          topicId: _topicId,
          homeworkId: _homeworkId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _openAddEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('teacherQuestionBuilderAddButton')));
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
  await tester.tap(find.text(_typeLabel(type)).last);
  await tester.pumpAndSettle();
}

String _typeLabel(TeacherQuestionType type) => switch (type) {
  TeacherQuestionType.singleChoice => 'Single choice',
  TeacherQuestionType.multipleChoice => 'Multiple choice',
  TeacherQuestionType.trueFalse => 'True/False',
  TeacherQuestionType.shortWritten => 'Short written',
  TeacherQuestionType.openWritten => 'Open written',
  TeacherQuestionType.fileBased => 'File based',
  TeacherQuestionType.matching => 'Matching',
  TeacherQuestionType.ordering => 'Ordering',
  TeacherQuestionType.fillInBlank => 'Fill in the blank',
};

Finder _textFieldWithLabel(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(TextFormField),
  );
}

Finder _iconButtonWithTooltip(String tooltip) {
  return find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );
}

Finder _inEditor(Finder finder) {
  return find.descendant(
    of: find.byKey(const Key('teacherQuestionEditorDialog')),
    matching: finder,
  );
}
