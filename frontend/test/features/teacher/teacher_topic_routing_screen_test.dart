import 'dart:async';

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
import 'package:testlabuz_client/features/teacher/application/teacher_topic_edit_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_mutation.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_detail_screen.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_edit_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _topicBId = '10000000-0000-0000-0000-000000000002';
const _caseTopicId = 'a0000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

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
      AppRoutePaths.isTeacherTopicDetailPath(
        '/teacher/topics/$_topicId/homework/$_homeworkId',
      ),
      isFalse,
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
      expect(find.byKey(const Key('teacherHomeworkSection')), findsOneWidget);
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

  testWidgets(
    'Topic Edit A to B replaces State and transfers route ownership to B',
    (tester) async {
      final topics = FakeTeacherTopicRepository(
        onFetch: (topicId) async => teacherTopic(
          id: topicId,
          title: topicId == _topicId ? 'Topic A' : 'Topic B',
        ),
        onUpdate: (topicId, request) async => teacherTopic(
          id: topicId,
          title:
              (request.changedFields['title'] as String?) ??
              (topicId == _topicId ? 'Topic A' : 'Topic B'),
        ),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        topics: topics,
      );
      await tester.pumpAndSettle();

      final oldScreenState = tester.state(find.byType(TeacherTopicEditScreen));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherTopicEditScreen)),
      );
      final oldProvider = teacherTopicEditControllerProvider(_topicId);
      final oldSubscription = container.listen(oldProvider, (_, _) {});
      addTearDown(oldSubscription.close);
      final oldController = container.read(oldProvider.notifier);
      final oldForm = oldSubscription.read().form;
      final router = container.read(appRouterProvider);

      router.go(AppRoutePaths.teacherTopicEditLocation(_topicBId));
      await tester.pumpAndSettle();

      expect(
        tester.state(find.byType(TeacherTopicEditScreen)),
        isNot(same(oldScreenState)),
      );
      oldController.updateTitle('Stale Topic A edit');
      expect(oldSubscription.read().form, same(oldForm));

      final newProvider = teacherTopicEditControllerProvider(_topicBId);
      expect(container.read(newProvider).topic?.title, 'Topic B');
      expect(container.read(newProvider).canEdit, isTrue);
      await tester.enterText(
        find.byKey(const Key('teacherTopicTitleField')),
        'Owned Topic B edit',
      );
      await tester.pump();
      expect(container.read(newProvider).form?.title, 'Owned Topic B edit');

      final save = find.byKey(const Key('teacherTopicEditSaveButton'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(topics.updateRequests.map((entry) => entry.topicId), [_topicBId]);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherTopicDetailLocation(_topicBId),
      );
    },
  );

  testWidgets(
    'late Topic A PATCH cannot publish or navigate from Topic Edit B',
    (tester) async {
      final pendingPatch = Completer<TeacherTopic>();
      final topics = FakeTeacherTopicRepository(
        onFetch: (topicId) async => teacherTopic(
          id: topicId,
          title: topicId == _topicId ? 'Topic A' : 'Topic B',
        ),
        onUpdate: (_, _) => pendingPatch.future,
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        topics: topics,
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherTopicEditScreen)),
      );
      final oldProvider = teacherTopicEditControllerProvider(_topicId);
      final oldSubscription = container.listen(oldProvider, (_, _) {});
      addTearDown(oldSubscription.close);
      container.read(oldProvider.notifier).updateTitle('Pending Topic A edit');
      await tester.pump();

      final save = find.byKey(const Key('teacherTopicEditSaveButton'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(oldSubscription.read().status, TeacherTopicEditStatus.submitting);
      expect(topics.updateRequests.map((entry) => entry.topicId), [_topicId]);

      final router = container.read(appRouterProvider);
      router.go(AppRoutePaths.teacherTopicEditLocation(_topicBId));
      await tester.pumpAndSettle();

      pendingPatch.complete(
        teacherTopic(id: _topicId, title: 'Pending Topic A edit'),
      );
      await tester.pumpAndSettle();

      expect(oldSubscription.read().status, TeacherTopicEditStatus.submitting);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherTopicEditLocation(_topicBId),
      );
      expect(
        container
            .read(teacherTopicEditControllerProvider(_topicBId))
            .topic
            ?.title,
        'Topic B',
      );
      expect(find.text('Topic updated successfully.'), findsNothing);
    },
  );

  testWidgets(
    'late Topic A reconciliation cannot publish or navigate from Topic Edit B',
    (tester) async {
      final pendingReconciliation = Completer<TeacherTopic>();
      var topicAFetches = 0;
      final topics = FakeTeacherTopicRepository(
        onFetch: (topicId) {
          if (topicId == _topicId) {
            topicAFetches += 1;
            if (topicAFetches == 2) {
              return pendingReconciliation.future;
            }
          }
          return Future.value(
            teacherTopic(
              id: topicId,
              title: topicId == _topicId ? 'Topic A' : 'Topic B',
            ),
          );
        },
        onUpdate: (_, _) async {
          throw const TeacherTopicMutationOutcomeUnknownException();
        },
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_topicId),
        topics: topics,
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherTopicEditScreen)),
      );
      final oldProvider = teacherTopicEditControllerProvider(_topicId);
      final oldSubscription = container.listen(oldProvider, (_, _) {});
      addTearDown(oldSubscription.close);
      container
          .read(oldProvider.notifier)
          .updateTitle('Reconciling Topic A edit');
      await tester.pump();

      final save = find.byKey(const Key('teacherTopicEditSaveButton'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      await tester.pump();
      expect(oldSubscription.read().status, TeacherTopicEditStatus.reconciling);
      expect(topics.fetchIds.where((id) => id == _topicId), hasLength(2));

      final router = container.read(appRouterProvider);
      router.go(AppRoutePaths.teacherTopicEditLocation(_topicBId));
      await tester.pumpAndSettle();

      pendingReconciliation.complete(
        teacherTopic(id: _topicId, title: 'Reconciling Topic A edit'),
      );
      await tester.pumpAndSettle();

      expect(oldSubscription.read().status, TeacherTopicEditStatus.reconciling);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherTopicEditLocation(_topicBId),
      );
      expect(
        container
            .read(teacherTopicEditControllerProvider(_topicBId))
            .topic
            ?.title,
        'Topic B',
      );
      expect(find.text('Topic updated successfully.'), findsNothing);
    },
  );

  testWidgets(
    'stale Topic A lifecycle confirmation cannot mutate Topic Detail B',
    (tester) async {
      final topics = FakeTeacherTopicRepository(
        onFetch: (topicId) async => teacherTopic(
          id: topicId,
          title: topicId == _topicId ? 'Topic A' : 'Topic B',
        ),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
        topics: topics,
      );
      await tester.pumpAndSettle();

      final oldDetailElement = tester.element(
        find.byType(TeacherTopicDetailScreen),
      );
      final container = ProviderScope.containerOf(oldDetailElement);
      final router = container.read(appRouterProvider);
      await tester.tap(
        find.byKey(const ValueKey('teacherTopicLifecycleactivate')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Activate Topic?'), findsOneWidget);

      router.go(AppRoutePaths.teacherTopicDetailLocation(_topicBId));
      await tester.pumpAndSettle();

      expect(
        tester.element(find.byType(TeacherTopicDetailScreen)),
        isNot(same(oldDetailElement)),
      );
      expect(find.text('Topic B'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherTopicDetailLocation(_topicBId),
      );
      expect(
        find.byKey(const Key('teacherTopicLifecycleConfirmButton')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('teacherTopicLifecycleConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(topics.lifecycleRequests, isEmpty);
      expect(find.text('Topic B'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutePaths.teacherTopicDetailLocation(_topicBId),
      );
    },
  );

  testWidgets(
    'case-only Topic UUID spelling preserves semantic screen ownership',
    (tester) async {
      final topics = FakeTeacherTopicRepository(
        onFetch: (topicId) async =>
            teacherTopic(id: topicId, title: 'Case Topic'),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicEditLocation(_caseTopicId),
        topics: topics,
      );
      await tester.pumpAndSettle();

      final editState = tester.state(find.byType(TeacherTopicEditScreen));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherTopicEditScreen)),
      );
      final provider = teacherTopicEditControllerProvider(_caseTopicId);
      final controller = container.read(provider.notifier);
      controller.updateTitle('Preserved case-only draft');
      await tester.pump();

      final router = container.read(appRouterProvider);
      final uppercaseEditLocation = AppRoutePaths.teacherTopicEditLocation(
        _caseTopicId.toUpperCase(),
      );
      router.go(uppercaseEditLocation);
      await tester.pumpAndSettle();

      expect(
        tester.state(find.byType(TeacherTopicEditScreen)),
        same(editState),
      );
      expect(container.read(provider).form?.title, 'Preserved case-only draft');
      expect(container.read(provider.notifier), same(controller));
      expect(
        router.routeInformationProvider.value.uri.path,
        uppercaseEditLocation,
      );

      await tester.enterText(
        find.byKey(const Key('teacherTopicTitleField')),
        'Edited after case-only navigation',
      );
      await tester.pump();
      expect(
        container.read(provider).form?.title,
        'Edited after case-only navigation',
      );

      router.go(AppRoutePaths.teacherTopicDetailLocation(_caseTopicId));
      await tester.pumpAndSettle();
      final detailElement = tester.element(
        find.byType(TeacherTopicDetailScreen),
      );
      final uppercaseDetailLocation = AppRoutePaths.teacherTopicDetailLocation(
        _caseTopicId.toUpperCase(),
      );
      router.go(uppercaseDetailLocation);
      await tester.pumpAndSettle();

      expect(
        tester.element(find.byType(TeacherTopicDetailScreen)),
        same(detailElement),
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        uppercaseDetailLocation,
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
    expect(find.byKey(const Key('teacherHomeworkSection')), findsOneWidget);
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
    'open Homework conflict keeps Homework visible and gives safe guidance',
    (tester) async {
      final topics = FakeTeacherTopicRepository(
        onFetch: (id) async =>
            teacherTopic(id: id, status: TeacherTopicStatus.active),
        onLifecycle: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.topicHasOpenAssessments,
          statusCode: 409,
        ),
      );
      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
        topics: topics,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('teacherTopicLifecycleclose')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherTopicLifecycleConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(topics.lifecycleRequests, hasLength(1));
      expect(topics.fetchIds, hasLength(2));
      expect(
        find.text(
          "Close or archive the Topic's draft/active Homework before closing or archiving the Topic.",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('teacherHomeworkSection')), findsOneWidget);
      expect(
        find.byKey(const Key('teacherTopicLifecycleCheckCurrentButton')),
        findsNothing,
      );
    },
  );

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
        teacherHomeworkRepositoryProvider.overrideWithValue(
          FakeTeacherHomeworkRepository(),
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}
