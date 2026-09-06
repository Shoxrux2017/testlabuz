import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_create_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_edit_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_create_screen.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_edit_screen.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_question_builder_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _topicBId = '10000000-0000-0000-0000-000000000002';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _homeworkBId = '50000000-0000-0000-0000-000000000002';
const _studentId = '60000000-0000-0000-0000-000000000001';

void main() {
  test('Homework route helpers accept only the canonical nested path', () {
    final location = AppRoutePaths.teacherHomeworkDetailLocation(
      _topicId,
      _homeworkId,
    );

    expect(location, '/teacher/topics/$_topicId/homework/$_homeworkId');
    expect(AppRoutePaths.isTeacherHomeworkDetailPath(location), isTrue);
    expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);
    expect(AppRoutePaths.teacherHomeworkIdFromPath(location), _homeworkId);
    expect(AppRoutePaths.isTeacherTopicDetailPath(location), isFalse);
    expect(AppRoutePaths.isTeacherTopicEditPath(location), isFalse);

    for (final invalid in [
      '/teacher/topics/not-a-uuid/homework/$_homeworkId',
      '/teacher/topics/$_topicId/homework/not-a-uuid',
      '/teacher/topics/$_topicId/homework/$_homeworkId/extra',
      '/teacher/topics/$_topicId/homework/$_homeworkId/',
    ]) {
      expect(AppRoutePaths.isTeacherHomeworkDetailPath(invalid), isFalse);
      expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
    }

    expect(
      () => AppRoutePaths.teacherHomeworkDetailLocation(
        'not-a-uuid',
        _homeworkId,
      ),
      throwsArgumentError,
    );
    expect(
      () => AppRoutePaths.teacherHomeworkDetailLocation(_topicId, 'not-a-uuid'),
      throwsArgumentError,
    );

    final create = AppRoutePaths.teacherHomeworkCreateLocation(_topicId);
    final edit = AppRoutePaths.teacherHomeworkEditLocation(
      _topicId,
      _homeworkId,
    );
    expect(create, '/teacher/topics/$_topicId/homework/new');
    expect(edit, '/teacher/topics/$_topicId/homework/$_homeworkId/edit');
    expect(AppRoutePaths.isTeacherHomeworkCreatePath(create), isTrue);
    expect(AppRoutePaths.isTeacherHomeworkEditPath(edit), isTrue);
    expect(AppRoutePaths.isTeacherHomeworkDetailPath(create), isFalse);
    expect(AppRoutePaths.isTeacherHomeworkDetailPath(edit), isFalse);
    expect(AppRoutePaths.teacherTopicIdFromPath(create), _topicId);
    expect(AppRoutePaths.teacherTopicIdFromPath(edit), _topicId);
    expect(AppRoutePaths.teacherHomeworkIdFromPath(create), isNull);
    expect(AppRoutePaths.teacherHomeworkIdFromPath(edit), _homeworkId);
  });

  test('Question Builder route helpers accept only the exact nested path', () {
    final location = AppRoutePaths.teacherHomeworkQuestionsLocation(
      _topicId,
      _homeworkId,
    );

    expect(
      location,
      '/teacher/topics/$_topicId/homework/$_homeworkId/questions',
    );
    expect(AppRoutePaths.isTeacherHomeworkQuestionsPath(location), isTrue);
    expect(AppRoutePaths.isTeacherHomeworkDetailPath(location), isFalse);
    expect(AppRoutePaths.isTeacherApprovedLocation(location), isTrue);
    expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);
    expect(AppRoutePaths.teacherHomeworkIdFromPath(location), _homeworkId);

    for (final invalid in [
      '/teacher/topics/not-a-uuid/homework/$_homeworkId/questions',
      '/teacher/topics/$_topicId/homework/not-a-uuid/questions',
      '/teacher/topics/$_topicId/homework/$_homeworkId/questions/extra',
      '/teacher/topics/$_topicId/homework/$_homeworkId/questions/',
      '/teacher/topics/$_topicId/homework/$_homeworkId/questions?private=1',
      '/teacher/topics/$_topicId/homework/$_homeworkId/questions#fragment',
    ]) {
      expect(AppRoutePaths.isTeacherHomeworkQuestionsPath(invalid), isFalse);
      expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
      expect(AppRoutePaths.teacherTopicIdFromPath(invalid), isNull);
      expect(AppRoutePaths.teacherHomeworkIdFromPath(invalid), isNull);
    }
  });

  testWidgets('desktop create and edit routes mount the authoring screens', (
    tester,
  ) async {
    final createHomework = FakeTeacherHomeworkRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkCreateLocation(_topicId),
      homework: createHomework,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkCreateScreen')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
    expect(createHomework.fetchIds, isEmpty);

    final editHomework = FakeTeacherHomeworkRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkEditLocation(
        _topicId,
        _homeworkId,
      ),
      homework: editHomework,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherHomeworkEditScreen')), findsOneWidget);
    expect(editHomework.fetchIds, [_homeworkId]);
  });

  testWidgets('desktop direct Question Builder route mounts authoring screen', (
    tester,
  ) async {
    final homework = FakeTeacherHomeworkRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkQuestionsLocation(
        _topicId,
        _homeworkId,
      ),
      homework: homework,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherQuestionBuilderScreen')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
    expect(homework.fetchIds, [_homeworkId]);
  });

  testWidgets(
    'Create Topic A to B replaces State and rejects pending A success',
    (tester) async {
      final pendingCreate = Completer<TeacherHomework>();
      final topics = FakeTeacherTopicRepository(
        onFetch: (topicId) async => teacherTopic(
          id: topicId,
          title: topicId == _topicId ? 'Topic A' : 'Topic B',
        ),
      );
      final homework = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async => teacherHomework(
          id: homeworkId,
          topicId: _topicBId,
          title: 'Created for Topic B',
        ),
        onCreate: (topicId, _) {
          if (topicId == _topicId) {
            return pendingCreate.future;
          }
          return Future.value(
            teacherHomework(
              id: _homeworkBId,
              topicId: topicId,
              title: 'Created for Topic B',
            ),
          );
        },
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherHomeworkCreateLocation(_topicId),
        topics: topics,
        homework: homework,
      );
      await tester.pumpAndSettle();

      final oldScreenState = tester.state(
        find.byType(TeacherHomeworkCreateScreen),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherHomeworkCreateScreen)),
      );
      final oldProvider = teacherHomeworkCreateControllerProvider(_topicId);
      final oldSubscription = container.listen(oldProvider, (_, _) {});
      addTearDown(oldSubscription.close);
      final oldController = container.read(oldProvider.notifier);
      oldController
        ..updateTitle('Pending Topic A Homework')
        ..updateStudentInstructions('Pending Topic A instructions');
      await tester.pump();
      final oldSubmit = find.byKey(
        const Key('teacherHomeworkCreateSubmitButton'),
      );
      await tester.ensureVisible(oldSubmit);
      await tester.tap(oldSubmit);
      await tester.pump();
      expect(homework.createRequests.map((entry) => entry.topicId), [_topicId]);

      final router = container.read(appRouterProvider);
      router.go(AppRoutePaths.teacherHomeworkCreateLocation(_topicBId));
      await tester.pumpAndSettle();

      expect(
        tester.state(find.byType(TeacherHomeworkCreateScreen)),
        isNot(same(oldScreenState)),
      );
      expect(find.text('Topic title: Topic B'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('teacherHomeworkTitleField')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await oldController.submit();
      expect(homework.createRequests.map((entry) => entry.topicId), [_topicId]);

      pendingCreate.complete(
        teacherHomework(
          id: _homeworkId,
          topicId: _topicId,
          title: 'Late Topic A success',
        ),
      );
      await tester.pumpAndSettle();

      expect(oldSubscription.read().confirmedHomeworkId, isNull);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherHomeworkCreateLocation(_topicBId),
      );
      expect(find.text('Topic title: Topic B'), findsOneWidget);

      final newProvider = teacherHomeworkCreateControllerProvider(_topicBId);
      final newController = container.read(newProvider.notifier);
      newController
        ..updateTitle('Owned Topic B Homework')
        ..updateStudentInstructions('Owned Topic B instructions');
      await tester.pump();
      expect(container.read(newProvider).form.title, 'Owned Topic B Homework');

      final newSubmit = find.byKey(
        const Key('teacherHomeworkCreateSubmitButton'),
      );
      await tester.ensureVisible(newSubmit);
      await tester.tap(newSubmit);
      await tester.pumpAndSettle();

      expect(homework.createRequests.map((entry) => entry.topicId), [
        _topicId,
        _topicBId,
      ]);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherHomeworkDetailLocation(_topicBId, _homeworkBId),
      );
    },
  );

  testWidgets(
    'Edit Homework A to B replaces State and rejects the open A picker result',
    (tester) async {
      final topics = FakeTeacherTopicRepository(
        onFetch: (topicId) async => teacherTopic(
          id: topicId,
          title: topicId == _topicId ? 'Topic A' : 'Topic B',
          group: teacherGroup(
            id: topicId == _topicId
                ? '00000000-0000-0000-0000-000000000001'
                : '00000000-0000-0000-0000-000000000002',
          ),
        ),
      );
      final homework = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async => teacherHomework(
          id: homeworkId,
          topicId: homeworkId == _homeworkId ? _topicId : _topicBId,
          title: homeworkId == _homeworkId ? 'Homework A' : 'Homework B',
        ),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherHomeworkEditLocation(
          _topicId,
          _homeworkId,
        ),
        topics: topics,
        homework: homework,
        groupStudents: FakeTeacherGroupStudentRepository(),
      );
      await tester.pumpAndSettle();

      final oldScreenState = tester.state(
        find.byType(TeacherHomeworkEditScreen),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherHomeworkEditScreen)),
      );
      final oldTarget = TeacherHomeworkRouteTarget(
        topicId: _topicId,
        homeworkId: _homeworkId,
      );
      final oldProvider = teacherHomeworkEditControllerProvider(oldTarget);
      final oldSubscription = container.listen(oldProvider, (_, _) {});
      addTearDown(oldSubscription.close);

      await tester.ensureVisible(find.text('Selected students'));
      await tester.tap(find.text('Selected students'));
      await tester.pump();
      final chooseStudents = find.byKey(
        const Key('teacherHomeworkChooseStudentsButton'),
      );
      await tester.ensureVisible(chooseStudents);
      await tester.tap(chooseStudents);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherHomeworkStudentPickerDialog')),
        findsOneWidget,
      );

      final router = container.read(appRouterProvider);
      router.go(
        AppRoutePaths.teacherHomeworkEditLocation(_topicBId, _homeworkBId),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester.state(find.byType(TeacherHomeworkEditScreen)),
        isNot(same(oldScreenState)),
      );
      final stalePicker = find.byKey(
        const Key('teacherHomeworkStudentPickerDialog'),
      );
      expect(stalePicker, findsOneWidget);
      Navigator.of(tester.element(stalePicker)).pop(const {_studentId});
      await tester.pumpAndSettle();

      expect(find.text('Homework B'), findsOneWidget);
      expect(oldSubscription.read().form?.selectedStudentIds, isEmpty);
      final newTarget = TeacherHomeworkRouteTarget(
        topicId: _topicBId,
        homeworkId: _homeworkBId,
      );
      final newProvider = teacherHomeworkEditControllerProvider(newTarget);
      expect(container.read(newProvider).form?.selectedStudentIds, isEmpty);
      container.read(newProvider.notifier).updateTitle('Owned Homework B edit');
      await tester.pump();
      expect(container.read(newProvider).form?.title, 'Owned Homework B edit');
      expect(homework.updateRequests, isEmpty);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherHomeworkEditLocation(_topicBId, _homeworkBId),
      );
    },
  );

  testWidgets(
    'Question Builder A to B replaces State and closes the stale A editor',
    (tester) async {
      final homework = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async => teacherHomework(
          id: homeworkId,
          topicId: homeworkId == _homeworkId ? _topicId : _topicBId,
          title: homeworkId == _homeworkId
              ? 'Builder Homework A'
              : 'Builder Homework B',
        ),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherHomeworkQuestionsLocation(
          _topicId,
          _homeworkId,
        ),
        homework: homework,
      );
      await tester.pumpAndSettle();

      final oldScreenState = tester.state(
        find.byType(TeacherQuestionBuilderScreen),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherQuestionBuilderScreen)),
      );
      final addQuestion = find.byKey(
        const Key('teacherQuestionBuilderAddButton'),
      );
      await tester.ensureVisible(addQuestion);
      await tester.tap(addQuestion);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('teacherQuestionPromptField')),
        'Unsaved Question for Homework A',
      );
      await tester.pump();
      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsOneWidget,
      );

      final router = container.read(appRouterProvider);
      router.go(
        AppRoutePaths.teacherHomeworkQuestionsLocation(_topicBId, _homeworkBId),
      );
      await tester.pumpAndSettle();

      expect(
        tester.state(find.byType(TeacherQuestionBuilderScreen)),
        isNot(same(oldScreenState)),
      );
      expect(find.text('Builder Homework B'), findsOneWidget);
      expect(find.text('Builder Homework A'), findsNothing);
      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsNothing,
      );
      expect(homework.addQuestionRequests, isEmpty);

      final newAddQuestion = find.byKey(
        const Key('teacherQuestionBuilderAddButton'),
      );
      await tester.ensureVisible(newAddQuestion);
      await tester.tap(newAddQuestion);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherQuestionEditorDialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('teacherQuestionEditorCancelButton')),
      );
      await tester.pumpAndSettle();
      expect(homework.addQuestionRequests, isEmpty);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherHomeworkQuestionsLocation(_topicBId, _homeworkBId),
      );
    },
  );

  testWidgets(
    'case-only UUID spelling preserves canonical authoring State ownership',
    (tester) async {
      final topics = FakeTeacherTopicRepository(
        onFetch: (topicId) async => teacherTopic(id: topicId),
      );
      final homework = FakeTeacherHomeworkRepository(
        onFetch: (homeworkId) async =>
            teacherHomework(id: homeworkId, topicId: _topicId),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherHomeworkCreateLocation(_topicId),
        topics: topics,
        homework: homework,
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherHomeworkCreateScreen)),
      );
      final router = container.read(appRouterProvider);
      final createState = tester.state(
        find.byType(TeacherHomeworkCreateScreen),
      );
      router.go(
        AppRoutePaths.teacherHomeworkCreateLocation(_topicId.toUpperCase()),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(TeacherHomeworkCreateScreen)),
        same(createState),
      );

      router.go(
        AppRoutePaths.teacherHomeworkEditLocation(_topicId, _homeworkId),
      );
      await tester.pumpAndSettle();
      final editState = tester.state(find.byType(TeacherHomeworkEditScreen));
      router.go(
        AppRoutePaths.teacherHomeworkEditLocation(
          _topicId.toUpperCase(),
          _homeworkId.toUpperCase(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(TeacherHomeworkEditScreen)),
        same(editState),
      );

      router.go(
        AppRoutePaths.teacherHomeworkQuestionsLocation(_topicId, _homeworkId),
      );
      await tester.pumpAndSettle();
      final builderState = tester.state(
        find.byType(TeacherQuestionBuilderScreen),
      );
      router.go(
        AppRoutePaths.teacherHomeworkQuestionsLocation(
          _topicId.toUpperCase(),
          _homeworkId.toUpperCase(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(TeacherQuestionBuilderScreen)),
        same(builderState),
      );
    },
  );

  testWidgets('mobile authoring deep links redirect to exact read routes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final createHomework = FakeTeacherHomeworkRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkCreateLocation(_topicId),
      homework: createHomework,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(find.byKey(const Key('teacherHomeworkCreateScreen')), findsNothing);
    expect(createHomework.fetchIds, isEmpty);

    final editHomework = FakeTeacherHomeworkRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkEditLocation(
        _topicId,
        _homeworkId,
      ),
      homework: editHomework,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherHomeworkEditScreen')), findsNothing);
    expect(editHomework.fetchIds, [_homeworkId]);

    final questionsHomework = FakeTeacherHomeworkRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkQuestionsLocation(
        _topicId,
        _homeworkId,
      ),
      homework: questionsHomework,
      surface: AppDeviceSurface.mobile,
    );
    expect(find.byKey(const Key('teacherQuestionBuilderScreen')), findsNothing);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherQuestionBuilderScreen')), findsNothing);
    expect(questionsHomework.fetchIds, [_homeworkId]);
  });

  testWidgets('mobile authoring redirects remain exact during bootstrap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final createAuth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkCreateLocation(_topicId),
      auth: createAuth,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pump();
    createAuth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);

    final editAuth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkEditLocation(
        _topicId,
        _homeworkId,
      ),
      auth: editAuth,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pump();
    editAuth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherHomeworkEditScreen')), findsNothing);

    final questionsAuth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkQuestionsLocation(
        _topicId,
        _homeworkId,
      ),
      auth: questionsAuth,
      surface: AppDeviceSurface.mobile,
    );
    expect(find.byKey(const Key('teacherQuestionBuilderScreen')), findsNothing);
    questionsAuth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherQuestionBuilderScreen')), findsNothing);
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets('${surface.name} supports direct Homework detail entry', (
      tester,
    ) async {
      if (surface == AppDeviceSurface.mobile) {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }
      final homework = FakeTeacherHomeworkRepository();

      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherHomeworkDetailLocation(
          _topicId,
          _homeworkId,
        ),
        homework: homework,
        surface: surface,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherHomeworkDetailScreen')),
        findsOneWidget,
      );
      expect(homework.fetchIds, [_homeworkId]);
      expect(find.text('Equation practice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Homework detail deep link survives Teacher bootstrap', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    final homework = FakeTeacherHomeworkRepository();

    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkDetailLocation(
        _topicId,
        _homeworkId,
      ),
      homework: homework,
      auth: auth,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pump();

    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
    expect(homework.fetchIds, isEmpty);

    auth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );
    expect(homework.fetchIds, [_homeworkId]);
  });

  testWidgets(
    'malformed Homework paths plus query and fragment redirect without GET',
    (tester) async {
      for (final location in [
        '/teacher/topics/not-a-uuid/homework/$_homeworkId',
        '/teacher/topics/$_topicId/homework/not-a-uuid',
        '/teacher/topics/$_topicId/homework/$_homeworkId/extra',
        '/teacher/topics/$_topicId/homework/$_homeworkId/',
        '/teacher/topics/$_topicId/homework/$_homeworkId?private=1',
        '/teacher/topics/$_topicId/homework/$_homeworkId#fragment',
        '/teacher/topics/$_topicId/homework/new?private=1',
        '/teacher/topics/$_topicId/homework/new#fragment',
        '/teacher/topics/$_topicId/homework/$_homeworkId/edit?private=1',
        '/teacher/topics/$_topicId/homework/$_homeworkId/edit#fragment',
        '/teacher/topics/not-a-uuid/homework/$_homeworkId/questions',
        '/teacher/topics/$_topicId/homework/not-a-uuid/questions',
        '/teacher/topics/$_topicId/homework/$_homeworkId/questions/extra',
        '/teacher/topics/$_topicId/homework/$_homeworkId/questions/',
        '/teacher/topics/$_topicId/homework/$_homeworkId/questions?private=1',
        '/teacher/topics/$_topicId/homework/$_homeworkId/questions#fragment',
      ]) {
        final homework = FakeTeacherHomeworkRepository();
        await _pumpApp(tester, location: location, homework: homework);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('teacherLearningWorkspace')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('teacherHomeworkDetailScreen')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('teacherHomeworkCreateScreen')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('teacherHomeworkEditScreen')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('teacherQuestionBuilderScreen')),
          findsNothing,
        );
        expect(homework.fetchIds, isEmpty);
      }
    },
  );

  testWidgets('Homework card pushes detail and Back returns to Topic', (
    tester,
  ) async {
    final homework = FakeTeacherHomeworkRepository(
      onFetchList: (topicId, query) async => teacherHomeworkList(
        items: [teacherHomeworkSummary()],
        page: query.page,
        perPage: query.perPage,
        total: 1,
      ),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
      homework: homework,
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('teacherHomeworkCard$_homeworkId'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );
    expect(homework.fetchIds, [_homeworkId]);

    await tester.tap(find.byKey(const Key('teacherHomeworkBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
  });

  testWidgets('direct-entry Back returns to the canonical Topic fallback', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkDetailLocation(
        _topicId,
        _homeworkId,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherHomeworkBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
  });

  testWidgets('Manage Questions opens the canonical desktop Builder route', (
    tester,
  ) async {
    final homework = FakeTeacherHomeworkRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkDetailLocation(
        _topicId,
        _homeworkId,
      ),
      homework: homework,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('teacherHomeworkManageQuestionsButton')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherQuestionBuilderScreen')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherHomeworkDetailScreen')), findsNothing);
  });

  testWidgets('session loss removes an open dirty Question editor safely', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController.authenticated(
      teacherUser('teacher-a'),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkQuestionsLocation(
        _topicId,
        _homeworkId,
      ),
      homework: FakeTeacherHomeworkRepository(),
      auth: auth,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('teacherQuestionBuilderAddButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('teacherQuestionPromptField')),
      'Unsaved session editor',
    );
    await tester.pump();

    auth.logOut();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherQuestionEditorDialog')), findsNothing);
    expect(find.text('Discard Question changes?'), findsNothing);
    expect(find.byKey(const Key('loginField')), findsOneWidget);
    expect(find.byKey(const Key('teacherQuestionBuilderScreen')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String location,
  FakeTeacherHomeworkRepository? homework,
  FakeTeacherTopicRepository? topics,
  FakeTeacherGroupStudentRepository? groupStudents,
  FakeTeacherAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(location),
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeTeacherAuthSessionController.authenticated(
                teacherUser('teacher-a'),
              ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherGroupListRepositoryProvider.overrideWithValue(
          FakeTeacherGroupListRepository(),
        ),
        teacherTopicListRepositoryProvider.overrideWithValue(
          FakeTeacherTopicListRepository(),
        ),
        teacherTopicRepositoryProvider.overrideWithValue(
          topics ?? FakeTeacherTopicRepository(),
        ),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(
          FakeTeacherLearningMaterialRepository(),
        ),
        teacherHomeworkRepositoryProvider.overrideWithValue(
          homework ?? FakeTeacherHomeworkRepository(),
        ),
        teacherGroupStudentRepositoryProvider.overrideWithValue(
          groupStudents ?? FakeTeacherGroupStudentRepository(),
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}
