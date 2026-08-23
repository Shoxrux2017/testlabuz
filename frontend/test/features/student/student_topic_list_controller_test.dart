import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_topic_list_controller.dart';
import 'package:testlabuz_client/features/student/application/student_topic_list_state.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_topic.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_list.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_list_query.dart';

import 'student_test_support.dart';

void main() {
  group('StudentTopicListController', () {
    test('initial load is eligible on desktop and mobile only', () async {
      for (final surface in [
        AppDeviceSurface.desktop,
        AppDeviceSurface.mobile,
      ]) {
        final repository = FakeStudentTopicRepository();
        final container = _container(repository: repository, surface: surface);
        final subscription = _listen(container);
        await flushStudentControllers();

        expect(repository.listQueries, [const StudentTopicListQuery.initial()]);
        expect(subscription.read().status, StudentTopicListStatus.data);
      }

      final repository = FakeStudentTopicRepository();
      final container = _container(
        repository: repository,
        surface: AppDeviceSurface.unsupported,
      );
      _listen(container);
      await flushStudentControllers();
      expect(repository.listQueries, isEmpty);
    });

    test(
      'pending search plus status or refresh produces one request',
      () async {
        final repository = FakeStudentTopicRepository();
        final container = _container(repository: repository);
        _listen(container);
        await flushStudentControllers();
        final controller = container.read(
          studentTopicListControllerProvider.notifier,
        );

        controller.updateSearchDraft('  Internet  ');
        controller.setStatus(StudentTopicStatus.active);
        await flushStudentControllers();
        expect(repository.listQueries, hasLength(2));
        expect(repository.listQueries.last.search, 'Internet');
        expect(repository.listQueries.last.status, StudentTopicStatus.active);
        expect(repository.listQueries.last.page, 1);
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repository.listQueries, hasLength(2));

        controller.updateSearchDraft('  Networks  ');
        controller.refresh();
        await flushStudentControllers();
        expect(repository.listQueries.last.search, 'Networks');
        final calls = repository.listQueries.length;
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repository.listQueries, hasLength(calls));
      },
    );

    test('debounce Enter dedupe and invalid search blocking work', () async {
      final repository = FakeStudentTopicRepository();
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await flushStudentControllers();
      final controller = container.read(
        studentTopicListControllerProvider.notifier,
      );

      controller.updateSearchDraft('Debounced');
      await Future<void>.delayed(const Duration(milliseconds: 310));
      expect(repository.listQueries.last.search, 'Debounced');
      final afterDebounce = repository.listQueries.length;
      controller.commitSearchNow();
      await flushStudentControllers();
      expect(repository.listQueries, hasLength(afterDebounce));

      controller.updateSearchDraft('Enter');
      controller.commitSearchNow();
      await flushStudentControllers();
      final afterEnter = repository.listQueries.length;
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repository.listQueries, hasLength(afterEnter));

      controller.updateSearchDraft(List.filled(255, '😀').join());
      controller.setStatus(StudentTopicStatus.closed);
      controller.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repository.listQueries, hasLength(afterEnter));
      expect(
        subscription.read().searchErrorText,
        'Search must be 254 characters or fewer.',
      );
    });

    test('pagination refresh retry and empty classifications work', () async {
      var failNext = false;
      final repository = FakeStudentTopicRepository(
        onFetchTopics: (query) async {
          if (failNext) {
            failNext = false;
            throw studentLocalFailure(ApiFailureKind.timeout);
          }
          return studentTopicPage(page: query.page, total: 60, lastPage: 3);
        },
      );
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await flushStudentControllers();
      final controller = container.read(
        studentTopicListControllerProvider.notifier,
      );

      controller.nextPage();
      await flushStudentControllers();
      expect(repository.listQueries.last.page, 2);
      controller.previousPage();
      await flushStudentControllers();
      expect(repository.listQueries.last.page, 1);

      controller.refresh();
      expect(subscription.read().status, StudentTopicListStatus.refreshing);
      await flushStudentControllers();
      failNext = true;
      controller.refresh();
      await flushStudentControllers();
      expect(subscription.read().status, StudentTopicListStatus.error);
      controller.retry();
      await flushStudentControllers();
      expect(subscription.read().status, StudentTopicListStatus.data);

      expect(
        StudentTopicListState.fromResult(
          query: const StudentTopicListQuery.initial(),
          searchDraft: '',
          result: studentTopicPage(topics: const [], total: 0),
        ).status,
        StudentTopicListStatus.globalEmpty,
      );
      expect(
        StudentTopicListState.fromResult(
          query: const StudentTopicListQuery.initial().withSearch('x'),
          searchDraft: 'x',
          result: studentTopicPage(topics: const [], total: 0),
        ).status,
        StudentTopicListStatus.filteredEmpty,
      );
    });

    test('empty-page correction is bounded to one request', () async {
      var correctionPhase = false;
      final repository = FakeStudentTopicRepository(
        onFetchTopics: (query) async {
          if (!correctionPhase) {
            return studentTopicPage(page: query.page, total: 60, lastPage: 3);
          }
          return studentTopicPage(
            topics: const [],
            page: query.page,
            total: 21,
            lastPage: 2,
          );
        },
      );
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await flushStudentControllers();
      final controller = container.read(
        studentTopicListControllerProvider.notifier,
      );
      controller.nextPage();
      await flushStudentControllers();
      correctionPhase = true;
      controller.nextPage();
      await flushStudentControllers();

      expect(repository.listQueries.map((query) => query.page), [1, 2, 3, 2]);
      expect(subscription.read().status, StudentTopicListStatus.emptyPage);
      expect(subscription.read().query.page, 2);
    });

    test(
      'stale query and replaced session completions cannot publish',
      () async {
        final first = Completer<StudentTopicListPage>();
        final second = Completer<StudentTopicListPage>();
        final replacement = Completer<StudentTopicListPage>();
        var call = 0;
        final repository = FakeStudentTopicRepository(
          onFetchTopics: (query) {
            call += 1;
            return switch (call) {
              1 => first.future,
              2 => second.future,
              _ => replacement.future,
            };
          },
        );
        final auth = FakeStudentAuthSessionController.authenticated(
          studentUser('student-a'),
        );
        final container = _container(repository: repository, auth: auth);
        final subscription = _listen(container);
        await flushStudentControllers();
        final controller = container.read(
          studentTopicListControllerProvider.notifier,
        );
        controller.updateSearchDraft('new');
        controller.commitSearchNow();
        await flushStudentControllers();

        first.complete(
          studentTopicPage(
            topics: [studentTopicSummary(title: 'Stale query Topic')],
          ),
        );
        await flushStudentControllers();
        expect(subscription.read().status, StudentTopicListStatus.queryLoading);

        auth.replaceUser(studentUser('student-b'));
        await flushStudentControllers();
        second.complete(
          studentTopicPage(
            topics: [studentTopicSummary(title: 'Old session Topic')],
          ),
        );
        await flushStudentControllers();
        expect(
          subscription.read().result?.topics.any(
                (topic) => topic.title == 'Old session Topic',
              ) ??
              false,
          isFalse,
        );
        replacement.complete(
          studentTopicPage(
            topics: [studentTopicSummary(title: 'New session Topic')],
          ),
        );
        await flushStudentControllers();
        expect(
          subscription.read().result!.topics.single.title,
          'New session Topic',
        );
      },
    );

    test('authority failure clears state and reconciles auth', () async {
      final auth = FakeStudentAuthSessionController.authenticated(
        studentUser('student-a'),
      );
      final repository = FakeStudentTopicRepository(
        onFetchTopics: (_) async => throw studentServerFailure(
          ApiErrorCodes.userInactive,
          statusCode: 403,
        ),
      );
      final container = _container(repository: repository, auth: auth);
      final subscription = _listen(container);
      await flushStudentControllers();

      expect(subscription.read().status, StudentTopicListStatus.initial);
      expect(auth.bootstrapCalls, 1);
    });
  });
}

ProviderContainer _container({
  required FakeStudentTopicRepository repository,
  FakeStudentAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () =>
            auth ??
            FakeStudentAuthSessionController.authenticated(
              studentUser('student-a'),
            ),
      ),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      studentTopicRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<StudentTopicListState> _listen(
  ProviderContainer container,
) {
  final subscription = container.listen(
    studentTopicListControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return subscription;
}
