import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_group_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_group_list_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_list_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list_query.dart';

import 'teacher_test_support.dart';

void main() {
  group('TeacherTopicListController', () {
    test('initial load is unfiltered on both eligible surfaces', () async {
      for (final surface in [
        AppDeviceSurface.desktop,
        AppDeviceSurface.mobile,
      ]) {
        final repositories = _Repositories();
        final container = _container(
          repositories: repositories,
          surface: surface,
        );
        final subscription = _listenTopics(container);
        await flushTeacherControllers();

        expect(repositories.topics.queries, [
          const TeacherTopicListQuery.initial(),
        ]);
        expect(subscription.read().status, TeacherTopicListStatus.data);
      }
    });

    test(
      'pending search plus status or Group sends one resulting query',
      () async {
        final repositories = _Repositories();
        final container = _container(repositories: repositories);
        _listenTopics(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherTopicListControllerProvider.notifier,
        );

        controller.updateSearchDraft('  Algebra  ');
        controller.setStatus(TeacherTopicStatus.active);
        await flushTeacherControllers();
        expect(repositories.topics.queries, hasLength(2));
        expect(repositories.topics.queries.last.search, 'Algebra');
        expect(
          repositories.topics.queries.last.status,
          TeacherTopicStatus.active,
        );
        expect(repositories.topics.queries.last.page, 1);
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repositories.topics.queries, hasLength(2));

        final selectedGroup = teacherGroup(name: 'Selected');
        controller.updateSearchDraft('  Geometry  ');
        controller.selectGroup(selectedGroup);
        await flushTeacherControllers();
        expect(repositories.topics.queries, hasLength(3));
        expect(repositories.topics.queries.last.search, 'Geometry');
        expect(
          repositories.topics.queries.last.status,
          TeacherTopicStatus.active,
        );
        expect(repositories.topics.queries.last.groupId, selectedGroup.id);

        controller.updateSearchDraft('  Refreshed  ');
        controller.refresh();
        await flushTeacherControllers();
        expect(repositories.topics.queries.last.search, 'Refreshed');
        final callsAfterRefresh = repositories.topics.queries.length;
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repositories.topics.queries, hasLength(callsAfterRefresh));

        controller.clearGroupFilter();
        await flushTeacherControllers();
        expect(repositories.topics.queries.last.groupId, isNull);
        expect(repositories.topics.queries.last.search, 'Refreshed');
        expect(
          repositories.topics.queries.last.status,
          TeacherTopicStatus.active,
        );
        for (final status in TeacherTopicStatus.values) {
          controller.setStatus(status);
          await flushTeacherControllers();
          expect(repositories.topics.queries.last.status, status);
        }
      },
    );

    test(
      'debounce Enter deduplicate and invalid drafts block queries',
      () async {
        final repositories = _Repositories();
        final container = _container(repositories: repositories);
        final subscription = _listenTopics(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherTopicListControllerProvider.notifier,
        );

        controller.updateSearchDraft('Draft');
        await Future<void>.delayed(const Duration(milliseconds: 310));
        expect(repositories.topics.queries.last.search, 'Draft');
        final callsAfterDebounce = repositories.topics.queries.length;
        controller.commitSearchNow();
        await flushTeacherControllers();
        expect(repositories.topics.queries, hasLength(callsAfterDebounce));

        controller.updateSearchDraft('Enter');
        controller.commitSearchNow();
        await flushTeacherControllers();
        final callsAfterEnter = repositories.topics.queries.length;
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repositories.topics.queries, hasLength(callsAfterEnter));

        controller.updateSearchDraft(List.filled(255, '😀').join());
        controller.setStatus(TeacherTopicStatus.closed);
        controller.selectGroup(teacherGroup());
        controller.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repositories.topics.queries, hasLength(callsAfterEnter));
        expect(
          subscription.read().searchErrorText,
          'Search must be 254 characters or fewer.',
        );
      },
    );

    test('pagination refresh retry and result classifications work', () async {
      var failNext = false;
      final repositories = _Repositories(
        topics: FakeTeacherTopicListRepository(
          onFetch: (query) async {
            if (failNext) {
              failNext = false;
              throw teacherLocalFailure(ApiFailureKind.timeout);
            }
            return teacherTopicPage(page: query.page, total: 60, lastPage: 3);
          },
        ),
      );
      final container = _container(repositories: repositories);
      final subscription = _listenTopics(container);
      await flushTeacherControllers();
      final controller = container.read(
        teacherTopicListControllerProvider.notifier,
      );

      controller.nextPage();
      await flushTeacherControllers();
      expect(repositories.topics.queries.last.page, 2);
      controller.previousPage();
      await flushTeacherControllers();
      expect(repositories.topics.queries.last.page, 1);

      controller.refresh();
      expect(subscription.read().status, TeacherTopicListStatus.refreshing);
      await flushTeacherControllers();
      failNext = true;
      controller.refresh();
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherTopicListStatus.error);
      controller.updateSearchDraft('   ');
      final callsBeforeRetry = repositories.topics.queries.length;
      controller.retry();
      await flushTeacherControllers();
      expect(repositories.topics.queries, hasLength(callsBeforeRetry + 1));
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repositories.topics.queries, hasLength(callsBeforeRetry + 1));
      expect(subscription.read().status, TeacherTopicListStatus.data);

      expect(
        TeacherTopicListState.fromResult(
          query: const TeacherTopicListQuery.initial(),
          searchDraft: '',
          selectedGroup: null,
          result: teacherTopicPage(topics: const [], total: 0),
        ).status,
        TeacherTopicListStatus.globalEmpty,
      );
      expect(
        TeacherTopicListState.fromResult(
          query: const TeacherTopicListQuery.initial().withStatus(
            TeacherTopicStatus.draft,
          ),
          searchDraft: '',
          selectedGroup: null,
          result: teacherTopicPage(topics: const [], total: 0),
        ).status,
        TeacherTopicListStatus.filteredEmpty,
      );
      expect(
        TeacherTopicListState.fromResult(
          query: const TeacherTopicListQuery.initial().withPage(2),
          searchDraft: '',
          selectedGroup: null,
          result: teacherTopicPage(
            topics: const [],
            page: 2,
            total: 21,
            lastPage: 2,
          ),
        ).status,
        TeacherTopicListStatus.emptyPage,
      );
    });

    test(
      'retry blocks an invalid draft and commits one valid pending search',
      () async {
        var failNext = false;
        final topics = FakeTeacherTopicListRepository(
          onFetch: (query) async {
            if (failNext) {
              failNext = false;
              throw teacherLocalFailure(ApiFailureKind.timeout);
            }
            return teacherTopicPage(page: query.page, total: 60, lastPage: 3);
          },
        );
        final repositories = _Repositories(topics: topics);
        final container = _container(repositories: repositories);
        final subscription = _listenTopics(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherTopicListControllerProvider.notifier,
        );
        final selectedGroup = teacherGroup(name: 'Selected');

        controller.selectGroup(selectedGroup);
        await flushTeacherControllers();
        controller.setStatus(TeacherTopicStatus.active);
        await flushTeacherControllers();
        controller.nextPage();
        await flushTeacherControllers();
        expect(subscription.read().query.page, 2);
        failNext = true;
        controller.refresh();
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherTopicListStatus.error);
        final callsAtError = topics.queries.length;

        controller.updateSearchDraft(
          String.fromCharCodes(List.filled(255, 0x1f600)),
        );
        controller.retry();
        await flushTeacherControllers();
        expect(topics.queries, hasLength(callsAtError));
        expect(
          subscription.read().searchErrorText,
          'Search must be 254 characters or fewer.',
        );

        controller.updateSearchDraft('  Geometry  ');
        expect(subscription.read().searchErrorText, isNull);
        controller.retry();
        await flushTeacherControllers();

        expect(topics.queries, hasLength(callsAtError + 1));
        expect(topics.queries.last.search, 'Geometry');
        expect(topics.queries.last.page, 1);
        expect(topics.queries.last.groupId, selectedGroup.id);
        expect(topics.queries.last.status, TeacherTopicStatus.active);
        expect(subscription.read().selectedGroup?.id, selectedGroup.id);
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(topics.queries, hasLength(callsAtError + 1));
      },
    );

    test('empty-page correction is bounded to one request', () async {
      var correctionPhase = false;
      final repositories = _Repositories(
        topics: FakeTeacherTopicListRepository(
          onFetch: (query) async {
            if (query.page == 3) {
              correctionPhase = true;
              return teacherTopicPage(
                topics: const [],
                page: 3,
                total: 21,
                lastPage: 2,
              );
            }
            if (correctionPhase && query.page == 2) {
              return teacherTopicPage(
                topics: const [],
                page: 2,
                total: 21,
                lastPage: 2,
              );
            }
            return teacherTopicPage(page: query.page, total: 60, lastPage: 3);
          },
        ),
      );
      final container = _container(repositories: repositories);
      final subscription = _listenTopics(container);
      await flushTeacherControllers();
      final controller = container.read(
        teacherTopicListControllerProvider.notifier,
      );

      controller.nextPage();
      await flushTeacherControllers();
      controller.nextPage();
      await flushTeacherControllers();

      expect(repositories.topics.queries.map((query) => query.page), [
        1,
        2,
        3,
        2,
      ]);
      expect(subscription.read().status, TeacherTopicListStatus.emptyPage);
    });

    test(
      'invalid draft remains visible when an older request completes',
      () async {
        final pending = Completer<TeacherTopicListPage>();
        final topics = FakeTeacherTopicListRepository(
          onFetch: (_) => pending.future,
        );
        final repositories = _Repositories(topics: topics);
        final container = _container(repositories: repositories);
        final subscription = _listenTopics(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherTopicListControllerProvider.notifier,
        );

        controller.updateSearchDraft(List.filled(255, '😀').join());
        pending.complete(teacherTopicPage());
        await flushTeacherControllers();

        expect(subscription.read().status, TeacherTopicListStatus.data);
        expect(
          subscription.read().searchErrorText,
          'Search must be 254 characters or fewer.',
        );
        controller.setStatus(TeacherTopicStatus.archived);
        controller.refresh();
        await flushTeacherControllers();
        expect(topics.queries, hasLength(1));
      },
    );

    test(
      'selected Group 404 clears filter refreshes Groups and reloads once',
      () async {
        final topics = FakeTeacherTopicListRepository(
          onFetch: (query) async {
            if (query.groupId != null) {
              throw teacherServerFailure(
                ApiErrorCodes.resourceNotFound,
                statusCode: 404,
              );
            }
            return teacherTopicPage();
          },
        );
        final repositories = _Repositories(topics: topics);
        final container = _container(repositories: repositories);
        final topicSubscription = _listenTopics(container);
        final groupSubscription = _listenGroups(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherTopicListControllerProvider.notifier,
        );

        controller.selectGroup(teacherGroup());
        await flushTeacherControllers();

        expect(topics.queries.map((query) => query.groupId), [
          null,
          teacherGroup().id,
          null,
        ]);
        expect(repositories.groups.queries, hasLength(2));
        expect(topicSubscription.read().query.groupId, isNull);
        expect(topicSubscription.read().selectedGroup, isNull);
        expect(
          topicSubscription.read().notice,
          teacherSelectedGroupUnavailableNotice,
        );
        expect(groupSubscription.read().status, TeacherGroupListStatus.data);
      },
    );

    test(
      'unfiltered resource_not_found after reconciliation does not loop',
      () async {
        var initialComplete = false;
        final topics = FakeTeacherTopicListRepository(
          onFetch: (query) async {
            if (!initialComplete) {
              initialComplete = true;
              return teacherTopicPage();
            }
            throw teacherServerFailure(
              ApiErrorCodes.resourceNotFound,
              statusCode: 404,
            );
          },
        );
        final repositories = _Repositories(topics: topics);
        final container = _container(repositories: repositories);
        final subscription = _listenTopics(container);
        _listenGroups(container);
        await flushTeacherControllers();

        container
            .read(teacherTopicListControllerProvider.notifier)
            .selectGroup(teacherGroup());
        await flushTeacherControllers();

        expect(topics.queries, hasLength(3));
        expect(subscription.read().status, TeacherTopicListStatus.error);
        expect(subscription.read().query.groupId, isNull);
      },
    );

    test('stale query replacement and logout reject old completions', () async {
      final first = Completer<TeacherTopicListPage>();
      final second = Completer<TeacherTopicListPage>();
      final topics = FakeTeacherTopicListRepository();
      topics.onFetch = (_) =>
          topics.queries.length == 1 ? first.future : second.future;
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final repositories = _Repositories(topics: topics);
      final container = _container(repositories: repositories, auth: auth);
      final subscription = _listenTopics(container);
      await flushTeacherControllers();
      final controller = container.read(
        teacherTopicListControllerProvider.notifier,
      );

      controller.updateSearchDraft('New');
      controller.commitSearchNow();
      await flushTeacherControllers();
      second.complete(teacherTopicPage());
      await flushTeacherControllers();
      first.completeError(teacherLocalFailure(ApiFailureKind.connection));
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherTopicListStatus.data);

      final replacement = Completer<TeacherTopicListPage>();
      topics.onFetch = (_) => replacement.future;
      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      auth.logOut();
      await flushTeacherControllers();
      replacement.complete(teacherTopicPage());
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherTopicListStatus.initial);
      expect(subscription.read().result, isNull);
    });
  });
}

class _Repositories {
  _Repositories({
    FakeTeacherGroupListRepository? groups,
    FakeTeacherTopicListRepository? topics,
  }) : groups = groups ?? FakeTeacherGroupListRepository(),
       topics = topics ?? FakeTeacherTopicListRepository();

  final FakeTeacherGroupListRepository groups;
  final FakeTeacherTopicListRepository topics;
}

ProviderContainer _container({
  required _Repositories repositories,
  FakeTeacherAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () =>
            auth ??
            FakeTeacherAuthSessionController.authenticated(
              teacherUser('teacher-a'),
            ),
      ),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      teacherGroupListRepositoryProvider.overrideWithValue(repositories.groups),
      teacherTopicListRepositoryProvider.overrideWithValue(repositories.topics),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<TeacherTopicListState> _listenTopics(
  ProviderContainer container,
) {
  final subscription = container.listen(
    teacherTopicListControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  return subscription;
}

ProviderSubscription<TeacherGroupListState> _listenGroups(
  ProviderContainer container,
) {
  final subscription = container.listen(
    teacherGroupListControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  return subscription;
}
