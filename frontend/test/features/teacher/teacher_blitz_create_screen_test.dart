import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_list_pagination.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_create_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _groupId = '00000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _studentId = '60000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('Create shows exact fields, fixed policy, and no scheduling', (
    tester,
  ) async {
    await _pumpCreate(tester);
    await tester.pumpAndSettle();

    expect(find.text('Create Blitz'), findsOneWidget);
    expect(find.byTooltip('Back to Topic'), findsOneWidget);
    for (final label in [
      'Blitz information',
      'Assignment',
      'Duration',
      'Blitz attempts',
      'Title',
      'Description (optional)',
      'Student instructions',
      'Assignment mode',
      'Duration (seconds)',
      'Whole-Blitz duration. Example: 600 seconds = 10 minutes.',
      'Normal attempts: 1',
      'Maximum additional exception attempts: 1',
      'Create the Blitz first, then add Questions from Blitz detail.',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.byKey(const Key('teacherBlitzTimerModeNote')), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    for (final absent in [
      'Scheduled at',
      'Schedule',
      'Timer mode',
      'Activate',
      'Add Question',
    ]) {
      expect(find.text(absent), findsNothing, reason: absent);
    }
  });

  testWidgets('duration preview appears only for valid whole seconds', (
    tester,
  ) async {
    await _pumpCreate(tester);
    await tester.pumpAndSettle();
    final duration = find.byKey(const Key('teacherBlitzDurationField'));

    await tester.enterText(duration, '90');
    await tester.pump();
    expect(find.text('Duration: 1 min 30 sec'), findsOneWidget);

    await tester.enterText(duration, '1.5');
    await tester.pump();
    expect(find.byKey(const Key('teacherBlitzDurationPreview')), findsNothing);
  });

  testWidgets('local errors are shown and focus the first invalid field', (
    tester,
  ) async {
    final blitz = FakeTeacherBlitzRepository();
    await _pumpCreate(tester, blitz: blitz);
    await tester.pumpAndSettle();

    await _tapSubmit(tester);

    expect(find.text('Review the highlighted fields.'), findsOneWidget);
    expect(find.text('Duration is required.'), findsOneWidget);
    expect(blitz.createRequests, isEmpty);
    final title = tester.widget<TextField>(
      find.byKey(const Key('teacherBlitzTitleField')),
    );
    expect(title.focusNode!.hasFocus, isTrue);
  });

  testWidgets('selected assignment uses the picker and confirms clearing', (
    tester,
  ) async {
    final students = FakeTeacherGroupStudentRepository(
      onFetch: (groupId, query) async => _roster(),
    );
    await _pumpCreate(tester, students: students);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Selected students'));
    await tester.tap(find.text('Selected students'));
    await tester.pump();
    expect(find.text('Selected: 0'), findsOneWidget);
    expect(
      find.text(
        'A selected-student Blitz cannot be designated as the official Topic '
        'Blitz. Only whole-group Blitz can be official.',
      ),
      findsOneWidget,
    );

    final choose = find.byKey(const Key('teacherBlitzChooseStudentsButton'));
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(students.requests.first.groupId, _groupId);
    await tester.tap(
      find.byKey(const ValueKey('teacherHomeworkPickerStudent$_studentId')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('teacherHomeworkStudentPickerApplyButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);
    expect(find.text(_studentId), findsNothing);

    await tester.ensureVisible(find.text('Whole group'));
    await tester.tap(find.text('Whole group'));
    await tester.pumpAndSettle();
    expect(find.text('Clear selected Students?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('teacherBlitzKeepSelectionButton')));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Whole group'));
    await tester.tap(find.text('Whole group'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('teacherBlitzClearSelectionButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherBlitzGroupAssignmentNote')),
      findsOneWidget,
    );
  });

  testWidgets('busy create shows progress and success opens the Blitz', (
    tester,
  ) async {
    final pending = Completer<TeacherBlitz>();
    final blitz = FakeTeacherBlitzRepository(
      onCreate: (_, _) => pending.future,
    );
    final router = await _pumpCreate(tester, blitz: blitz);
    await tester.pumpAndSettle();
    await _fillValidForm(tester);

    await _tapSubmit(tester);
    expect(find.text('Creating Blitz'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('teacherBlitzCreateSubmitButton')),
          )
          .onPressed,
      isNull,
    );

    pending.complete(teacherBlitz(id: _blitzId));
    await tester.pumpAndSettle();

    expect(blitz.createRequests, hasLength(1));
    expect(find.text('Blitz created successfully.'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
    );
  });

  testWidgets('an uncertain create offers only a Blitz list review', (
    tester,
  ) async {
    final blitz = FakeTeacherBlitzRepository(
      onCreate: (_, _) async =>
          throw const TeacherBlitzMutationOutcomeUnknownException(),
    );
    final router = await _pumpCreate(tester, blitz: blitz);
    await tester.pumpAndSettle();
    await _fillValidForm(tester);

    await _tapSubmit(tester);

    expect(find.text('Creation outcome unknown'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('teacherBlitzCreateBackButton')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const Key('teacherBlitzCreateCheckListButton')),
    );
    await tester.pumpAndSettle();

    expect(blitz.createRequests, hasLength(1));
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutePaths.teacherTopicDetailLocation(_topicId),
    );
  });

  testWidgets('a dirty form asks before leaving', (tester) async {
    final router = await _pumpCreate(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('teacherBlitzTitleField')),
      'Unsaved Blitz',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('teacherBlitzCreateBackButton')));
    await tester.pumpAndSettle();
    expect(find.text('Discard Blitz changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('teacherBlitzKeepEditingButton')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved Blitz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherBlitzCreateBackButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('teacherBlitzDiscardButton')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutePaths.teacherTopicDetailLocation(_topicId),
    );
  });

  testWidgets('narrow scaled desktop form scrolls without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpCreate(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selected students'));
    await tester.tap(find.text('Selected students'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('teacherBlitzTitleField')),
    'Equation Blitz',
  );
  await tester.enterText(
    find.byKey(const Key('teacherBlitzInstructionsField')),
    'Answer quickly.',
  );
  await tester.enterText(
    find.byKey(const Key('teacherBlitzDurationField')),
    '600',
  );
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('teacherBlitzCreateSubmitButton'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pump();
  await tester.pump();
}

TeacherGroupStudentList _roster() {
  return TeacherGroupStudentList(
    items: const [
      TeacherGroupStudent(
        id: _studentId,
        fullName: 'Aziza Karimova',
        loginName: 'aziza',
      ),
    ],
    pagination: const TeacherListPagination(
      page: 1,
      perPage: 50,
      total: 1,
      lastPage: 1,
    ),
  );
}

Future<GoRouter> _pumpCreate(
  WidgetTester tester, {
  FakeTeacherBlitzRepository? blitz,
  FakeTeacherGroupStudentRepository? students,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutePaths.teacherBlitzCreateLocation(_topicId),
    routes: [
      GoRoute(
        path: AppRoutePaths.teacherTopicDetail,
        builder: (_, _) => const Scaffold(body: Text('Topic stub')),
        routes: [
          GoRoute(
            path:
                '${AppRoutePaths.teacherBlitzSegment}/'
                '${AppRoutePaths.teacherBlitzCreateSegment}',
            builder: (_, state) => TeacherBlitzCreateScreen(
              topicId:
                  state.pathParameters[AppRoutePaths.teacherTopicIdParameter]!,
            ),
          ),
          GoRoute(
            path:
                '${AppRoutePaths.teacherBlitzSegment}/'
                ':${AppRoutePaths.teacherBlitzIdParameter}',
            builder: (_, _) => const Scaffold(body: Text('Blitz detail stub')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
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
          FakeTeacherTopicRepository(),
        ),
        teacherBlitzRepositoryProvider.overrideWithValue(
          blitz ?? FakeTeacherBlitzRepository(),
        ),
        teacherGroupStudentRepositoryProvider.overrideWithValue(
          students ?? FakeTeacherGroupStudentRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return router;
}
