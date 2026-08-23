import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_create_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_edit_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('Teacher route helpers reject invalid child locations', (
    tester,
  ) async {
    expect(
      AppRoutePaths.isTeacherTopicCreatePath('/teacher/topics/new'),
      isTrue,
    );
    expect(
      AppRoutePaths.isTeacherTopicDetailPath('/teacher/topics/$_topicId'),
      isTrue,
    );
    expect(
      AppRoutePaths.isTeacherTopicEditPath('/teacher/topics/$_topicId/edit'),
      isTrue,
    );
    expect(
      AppRoutePaths.isTeacherTopicDetailPath('/teacher/topics/new'),
      isFalse,
    );
    expect(
      AppRoutePaths.isTeacherApprovedLocation('/teacher/topics/not-uuid'),
      isFalse,
    );
    expect(
      AppRoutePaths.isTeacherApprovedLocation(
        '/teacher/topics/$_topicId/extra',
      ),
      isFalse,
    );
  });

  testWidgets(
    'desktop create/detail/edit routes are canonical and literal new is safe',
    (tester) async {
      final topics = FakeTeacherTopicRepository();

      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicCreate,
        topics: topics,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacherTopicCreateScreen')), findsOneWidget);
      expect(topics.fetchIds, isEmpty);

      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
        topics: topics,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
      expect(find.text('Linear equations'), findsOneWidget);
      expect(find.text('2026-08-25 13:00'), findsOneWidget);
      expect(find.text('Asia/Tashkent'), findsOneWidget);

      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        topics: topics,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacherTopicEditScreen')), findsOneWidget);
      expect(
        find.byKey(const Key('teacherTopicEditReadOnlyGroup')),
        findsOneWidget,
      );
    },
  );

  testWidgets('mobile detail is read-only and create/edit redirect safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final topics = FakeTeacherTopicRepository();

    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicCreate,
      topics: topics,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherLearningWorkspace')), findsOneWidget);
    expect(find.byKey(const Key('teacherTopicCreateScreen')), findsNothing);

    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicEditLocation(_topicId),
      topics: topics,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(find.byKey(const Key('teacherTopicEditScreen')), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Activate'), findsNothing);
    expect(find.text('Close'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid UUID, extra segment, query and fragment dispatch no Topic GET',
    (tester) async {
      for (final location in [
        '/teacher/topics/not-a-uuid',
        '/teacher/topics/$_topicId/extra',
        '/teacher/topics/$_topicId?private=1',
        '/teacher/topics/$_topicId#fragment',
      ]) {
        final topics = FakeTeacherTopicRepository();
        await _pumpApp(tester, location: location, topics: topics);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('teacherLearningWorkspace')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('teacherTopicDetailScreen')), findsNothing);
        expect(topics.fetchIds, isEmpty);
      }
    },
  );

  testWidgets('valid detail deep link survives auth bootstrap', (tester) async {
    final auth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    final topics = FakeTeacherTopicRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
      topics: topics,
      auth: auth,
    );
    await tester.pump();
    expect(topics.fetchIds, isEmpty);

    auth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(topics.fetchIds, [_topicId]);
  });

  testWidgets(
    'desktop create deep link stays neutral and protected until bootstrap completes',
    (tester) async {
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      final topics = FakeTeacherTopicRepository();
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicCreate,
        topics: topics,
        auth: auth,
      );
      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);
      expect(find.byKey(const Key('teacherTopicCreateScreen')), findsNothing);
      expect(
        find.byKey(const Key('teacherTopicCreateSubmitButton')),
        findsNothing,
      );
      expect(topics.fetchIds, isEmpty);

      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacherTopicCreateScreen')), findsOneWidget);
      expect(topics.fetchIds, isEmpty);
    },
  );

  testWidgets(
    'desktop edit deep link stays neutral and dispatches no GET before bootstrap completes',
    (tester) async {
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      final topics = FakeTeacherTopicRepository();
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        topics: topics,
        auth: auth,
      );
      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);
      expect(find.byKey(const Key('teacherTopicEditScreen')), findsNothing);
      expect(topics.fetchIds, isEmpty);

      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacherTopicEditScreen')), findsOneWidget);
      expect(topics.fetchIds, [_topicId]);
    },
  );

  testWidgets('mobile detail deep link stays neutral through bootstrap', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    final topics = FakeTeacherTopicRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
      topics: topics,
      auth: auth,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pump();

    expect(find.text('Loading'), findsOneWidget);
    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsNothing);
    expect(topics.fetchIds, isEmpty);

    auth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(topics.fetchIds, [_topicId]);
  });

  testWidgets(
    'mobile edit canonicalizes during bootstrap and preserves Topic identity',
    (tester) async {
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      final topics = FakeTeacherTopicRepository();
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        topics: topics,
        auth: auth,
        surface: AppDeviceSurface.mobile,
      );
      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);
      expect(find.byKey(const Key('teacherTopicEditScreen')), findsNothing);
      expect(topics.fetchIds, isEmpty);

      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
      expect(find.byKey(const Key('teacherTopicEditScreen')), findsNothing);
      expect(topics.fetchIds, [_topicId]);
    },
  );

  testWidgets('mobile create resolves to Teacher during bootstrap', (
    tester,
  ) async {
    final auth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    final topics = FakeTeacherTopicRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicCreate,
      topics: topics,
      auth: auth,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pump();

    expect(find.text('Loading'), findsOneWidget);
    expect(find.byKey(const Key('teacherTopicCreateScreen')), findsNothing);
    expect(find.byKey(const Key('teacherTopicEditScreen')), findsNothing);
    expect(topics.fetchIds, isEmpty);

    auth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherLearningWorkspace')), findsOneWidget);
    expect(find.byKey(const Key('teacherTopicCreateScreen')), findsNothing);
    expect(topics.fetchIds, isEmpty);
  });

  testWidgets(
    'initial Edit GET failure is recoverable through one GET-only Retry',
    (tester) async {
      var fetches = 0;
      final topics = FakeTeacherTopicRepository(
        onFetch: (id) async {
          fetches += 1;
          if (fetches == 1) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherTopic(id: id);
        },
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        topics: topics,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherTopicEditInitialLoadError')),
        findsOneWidget,
      );
      expect(topics.fetchIds, [_topicId]);
      expect(topics.updateRequests, isEmpty);

      await tester.tap(
        find.byKey(const Key('teacherTopicEditInitialLoadRetryButton')),
      );
      await tester.pumpAndSettle();

      expect(topics.fetchIds, [_topicId, _topicId]);
      expect(
        find.byKey(const Key('teacherTopicEditReadOnlyGroup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherTopicEditSaveButton')),
        findsOneWidget,
      );
      expect(topics.updateRequests, isEmpty);
    },
  );

  testWidgets('Topic card opens detail and desktop exposes Create Topic', (
    tester,
  ) async {
    await _pumpApp(tester, location: AppRoutePaths.teacher);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherCreateTopicButton')), findsOneWidget);
    final card = find.byKey(const ValueKey('teacherTopicCard$_topicId'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
  });

  testWidgets('create Group picker debounces search for exactly 300 ms', (
    tester,
  ) async {
    final groups = FakeTeacherGroupListRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicCreate,
      groups: groups,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('teacherTopicChooseGroupButton')));
    await tester.pumpAndSettle();
    final initialQueryCount = groups.queries.length;
    expect(initialQueryCount, greaterThanOrEqualTo(1));

    await tester.enterText(
      find.byKey(const Key('teacherTopicGroupPickerSearchField')),
      'Alpha',
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(groups.queries, hasLength(initialQueryCount));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(groups.queries, hasLength(initialQueryCount + 1));
    expect(groups.queries.last.search, 'Alpha');
  });

  testWidgets(
    'stale Group picker result is ignored after session replacement',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicCreate,
        auth: auth,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('teacherTopicChooseGroupButton')));
      await tester.pumpAndSettle();

      final dialog = find.byKey(const Key('teacherTopicGroupPickerDialog'));
      expect(dialog, findsOneWidget);
      final dialogContext = tester.element(dialog);
      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      Navigator.of(dialogContext).pop(teacherGroup(name: 'Stale Group'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('teacherTopicCreateScreen'))),
      );
      expect(
        container.read(teacherTopicCreateControllerProvider).form.selectedGroup,
        isNull,
      );
      expect(find.text('Stale Group'), findsNothing);
    },
  );

  testWidgets(
    'stale Create lesson date is ignored before the time picker opens',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicCreate,
        auth: auth,
      );
      await tester.pumpAndSettle();
      final lessonButton = find.byKey(
        const Key('teacherTopicChooseLessonAtButton'),
      );
      await tester.ensureVisible(lessonButton);
      await tester.tap(lessonButton);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('teacherTopicCreateScreen'))),
      );
      expect(
        container.read(teacherTopicCreateControllerProvider).form.lessonAt,
        isNull,
      );
    },
  );

  testWidgets(
    'stale Edit lesson time result is ignored after session replacement',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        auth: auth,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherTopicChooseLessonAtButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('26'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);

      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('teacherTopicEditScreen'))),
      );
      expect(
        container
            .read(teacherTopicEditControllerProvider(_topicId))
            .form!
            .lessonAt,
        const InstitutionWallClock(
          year: 2026,
          month: 8,
          day: 25,
          hour: 13,
          minute: 0,
        ),
      );
    },
  );

  testWidgets('lifecycle action requires confirmation before POST', (
    tester,
  ) async {
    final topics = FakeTeacherTopicRepository(
      onLifecycle: (id, action) async =>
          teacherTopic(id: id, status: action.expectedStatus),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
      topics: topics,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('teacherTopicLifecycleactivate')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Activate Topic?'), findsOneWidget);
    expect(topics.lifecycleRequests, isEmpty);

    await tester.tap(
      find.byKey(const Key('teacherTopicLifecycleConfirmButton')),
    );
    await tester.pumpAndSettle();
    expect(
      topics.lifecycleRequests.single.action,
      TeacherTopicLifecycleAction.activate,
    );
  });

  testWidgets(
    'stale lifecycle confirmation dispatches no POST after session replacement',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final topics = FakeTeacherTopicRepository();
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
        topics: topics,
        auth: auth,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('teacherTopicLifecycleactivate')),
      );
      await tester.pumpAndSettle();
      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('teacherTopicLifecycleConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(topics.lifecycleRequests, isEmpty);
    },
  );

  testWidgets('dirty edit navigation asks before discarding', (tester) async {
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicEditLocation(_topicId),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('teacherTopicTitleField')),
      'Changed locally',
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('teacherTopicEditScreen'))),
    );
    expect(
      container.read(teacherTopicEditControllerProvider(_topicId)).isDirty,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('teacherTopicEditBackButton')));
    await tester.pump();
    expect(find.text('Discard unsaved Topic changes?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherTopicKeepEditingButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherTopicEditScreen')), findsOneWidget);
  });

  testWidgets(
    'stale dirty-discard confirmation cannot navigate replacement session',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        auth: auth,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('teacherTopicTitleField')),
        'Changed by old session',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('teacherTopicEditBackButton')));
      await tester.pump();
      expect(find.text('Discard unsaved Topic changes?'), findsOneWidget);

      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('teacherTopicDiscardChangesButton')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacherTopicEditScreen')), findsOneWidget);
      expect(find.byKey(const Key('teacherTopicDetailScreen')), findsNothing);
    },
  );

  testWidgets('Create lesson_at validation focuses the lesson control', (
    tester,
  ) async {
    final topics = FakeTeacherTopicRepository(
      onCreate: (_) async => throw _lessonAtValidationFailure(),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicCreate,
      topics: topics,
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('teacherTopicCreateScreen'))),
    );
    container.read(teacherTopicCreateControllerProvider.notifier)
      ..selectGroup(teacherGroup())
      ..updateTitle('Topic title')
      ..updateSubject('Subject')
      ..updateStudentInstructions('Instructions');
    await tester.pump();

    final submit = find.byKey(const Key('teacherTopicCreateSubmitButton'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('teacherTopicChooseLessonAtButton')),
    );
    expect(button.focusNode!.hasFocus, isTrue);
  });

  testWidgets('Edit lesson_at validation focuses the lesson control', (
    tester,
  ) async {
    final topics = FakeTeacherTopicRepository(
      onUpdate: (_, _) async => throw _lessonAtValidationFailure(),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicEditLocation(_topicId),
      topics: topics,
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('teacherTopicEditScreen'))),
    );
    container
        .read(teacherTopicEditControllerProvider(_topicId).notifier)
        .updateLessonAt(
          const InstitutionWallClock(
            year: 2026,
            month: 8,
            day: 26,
            hour: 13,
            minute: 0,
          ),
        );
    await tester.pump();

    final save = find.byKey(const Key('teacherTopicEditSaveButton'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('teacherTopicChooseLessonAtButton')),
    );
    expect(button.focusNode!.hasFocus, isTrue);
  });

  testWidgets(
    'narrow desktop create form and scaled mobile detail do not overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpApp(tester, location: AppRoutePaths.teacherTopicCreate);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacherTopicCreateScreen')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('teacherTopicDetailScroll')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closed Topic edit deep link is read-only', (tester) async {
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicEditLocation(_topicId),
      topics: FakeTeacherTopicRepository(
        onFetch: (id) async =>
            teacherTopic(id: id, status: TeacherTopicStatus.closed),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherTopicEditReadOnlyGroup')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherTopicEditSaveButton')), findsNothing);
    expect(
      find.byKey(const Key('teacherTopicEditReviewTopicButton')),
      findsOneWidget,
    );
  });
}

ApiRequestException _lessonAtValidationFailure() {
  return ApiRequestException(
    ApiFailure(
      kind: ApiFailureKind.validation,
      statusCode: 422,
      serverCode: ApiErrorCodes.validationFailed,
      message: 'Raw validation response.',
      fieldErrors: const {
        'lesson_at': ['Raw lesson error.'],
      },
    ),
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String location,
  FakeTeacherTopicRepository? topics,
  FakeTeacherGroupListRepository? groups,
  FakeTeacherAuthSessionController? auth,
  FakeTeacherLearningMaterialRepository? materials,
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
          groups ?? FakeTeacherGroupListRepository(),
        ),
        teacherTopicListRepositoryProvider.overrideWithValue(
          FakeTeacherTopicListRepository(),
        ),
        teacherTopicRepositoryProvider.overrideWithValue(
          topics ?? FakeTeacherTopicRepository(),
        ),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(
          materials ?? FakeTeacherLearningMaterialRepository(),
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}
