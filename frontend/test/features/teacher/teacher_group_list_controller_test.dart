import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_group_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_group_list_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list_query.dart';

import 'teacher_test_support.dart';

void main() {
  group('TeacherGroupListController', () {
    test(
      'eligible desktop and mobile Teachers load, ineligible sessions do not',
      () async {
        for (final surface in [
          AppDeviceSurface.desktop,
          AppDeviceSurface.mobile,
        ]) {
          final repository = FakeTeacherGroupListRepository();
          final container = _container(
            repository: repository,
            surface: surface,
          );
          final subscription = _listen(container);
          await flushTeacherControllers();

          expect(repository.queries, [const TeacherGroupListQuery.initial()]);
          expect(subscription.read().status, TeacherGroupListStatus.data);
        }

        for (final auth in [
          FakeTeacherAuthSessionController.authenticated(
            teacherUser('student', role: UserRole.student),
          ),
          FakeTeacherAuthSessionController(
            const AuthSessionState.unauthenticated(),
          ),
        ]) {
          final repository = FakeTeacherGroupListRepository();
          final container = _container(repository: repository, auth: auth);
          final subscription = _listen(container);
          await flushTeacherControllers();

          expect(repository.queries, isEmpty);
          expect(subscription.read().status, TeacherGroupListStatus.initial);
        }
      },
    );

    test(
      'debounce Enter deduplication and invalid draft follow contract',
      () async {
        final repository = FakeTeacherGroupListRepository();
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherGroupListControllerProvider.notifier,
        );

        controller.updateSearchDraft('  Alpha  ');
        await Future<void>.delayed(const Duration(milliseconds: 290));
        expect(repository.queries, hasLength(1));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(repository.queries.last.search, 'Alpha');

        controller.commitSearchNow();
        await flushTeacherControllers();
        expect(repository.queries, hasLength(2));

        controller.updateSearchDraft('  Beta  ');
        controller.commitSearchNow();
        await flushTeacherControllers();
        expect(repository.queries.last.search, 'Beta');
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repository.queries, hasLength(3));

        controller.updateSearchDraft(List.filled(255, '😀').join());
        controller.commitSearchNow();
        controller.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repository.queries, hasLength(3));
        expect(
          subscription.read().searchErrorText,
          'Search must be 254 characters or fewer.',
        );

        controller.clearSearch();
        await flushTeacherControllers();
        expect(subscription.read().searchDraft, '');
        expect(subscription.read().searchErrorText, isNull);
        expect(repository.queries.last.search, isNull);
      },
    );

    test(
      'pagination refresh retry and result classifications are focused',
      () async {
        var failNext = false;
        final repository = FakeTeacherGroupListRepository(
          onFetch: (query) async {
            if (failNext) {
              failNext = false;
              throw teacherLocalFailure(ApiFailureKind.connection);
            }
            return teacherGroupPage(page: query.page, total: 60, lastPage: 3);
          },
        );
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherGroupListControllerProvider.notifier,
        );

        controller.nextPage();
        await flushTeacherControllers();
        expect(repository.queries.last.page, 2);
        controller.previousPage();
        await flushTeacherControllers();
        expect(repository.queries.last.page, 1);

        controller.refresh();
        expect(subscription.read().status, TeacherGroupListStatus.refreshing);
        await flushTeacherControllers();
        failNext = true;
        controller.refresh();
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherGroupListStatus.error);
        controller.updateSearchDraft('   ');
        final callsBeforeRetry = repository.queries.length;
        controller.retry();
        await flushTeacherControllers();
        expect(repository.queries, hasLength(callsBeforeRetry + 1));
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repository.queries, hasLength(callsBeforeRetry + 1));
        expect(subscription.read().status, TeacherGroupListStatus.data);

        expect(
          TeacherGroupListState.fromResult(
            query: const TeacherGroupListQuery.initial(),
            searchDraft: '',
            result: teacherGroupPage(groups: const [], total: 0),
          ).status,
          TeacherGroupListStatus.globalEmpty,
        );
        expect(
          TeacherGroupListState.fromResult(
            query: const TeacherGroupListQuery.initial().withSearch('none'),
            searchDraft: 'none',
            result: teacherGroupPage(groups: const [], total: 0),
          ).status,
          TeacherGroupListStatus.filteredEmpty,
        );
        expect(
          TeacherGroupListState.fromResult(
            query: const TeacherGroupListQuery.initial().withPage(2),
            searchDraft: '',
            result: teacherGroupPage(
              groups: const [],
              page: 2,
              total: 21,
              lastPage: 2,
            ),
          ).status,
          TeacherGroupListStatus.emptyPage,
        );
      },
    );

    test(
      'retry blocks an invalid draft and commits one valid pending search',
      () async {
        var failNext = false;
        final repository = FakeTeacherGroupListRepository(
          onFetch: (query) async {
            if (failNext) {
              failNext = false;
              throw teacherLocalFailure(ApiFailureKind.connection);
            }
            return teacherGroupPage(page: query.page, total: 60, lastPage: 3);
          },
        );
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherGroupListControllerProvider.notifier,
        );

        controller.nextPage();
        await flushTeacherControllers();
        expect(subscription.read().query.page, 2);
        failNext = true;
        controller.refresh();
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherGroupListStatus.error);
        final callsAtError = repository.queries.length;

        controller.updateSearchDraft(
          String.fromCharCodes(List.filled(255, 0x1f600)),
        );
        controller.retry();
        await flushTeacherControllers();
        expect(repository.queries, hasLength(callsAtError));
        expect(
          subscription.read().searchErrorText,
          'Search must be 254 characters or fewer.',
        );

        controller.updateSearchDraft('  Replacement  ');
        expect(subscription.read().searchErrorText, isNull);
        controller.retry();
        await flushTeacherControllers();

        expect(repository.queries, hasLength(callsAtError + 1));
        expect(repository.queries.last.search, 'Replacement');
        expect(repository.queries.last.page, 1);
        expect(subscription.read().query, repository.queries.last);
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(repository.queries, hasLength(callsAtError + 1));
      },
    );

    test('empty-page correction is bounded to one request', () async {
      var correctionPhase = false;
      final repository = FakeTeacherGroupListRepository(
        onFetch: (query) async {
          if (query.page == 3) {
            correctionPhase = true;
            return teacherGroupPage(
              groups: const [],
              page: 3,
              total: 21,
              lastPage: 2,
            );
          }
          if (correctionPhase && query.page == 2) {
            return teacherGroupPage(
              groups: const [],
              page: 2,
              total: 21,
              lastPage: 2,
            );
          }
          return teacherGroupPage(page: query.page, total: 60, lastPage: 3);
        },
      );
      final container = _container(repository: repository);
      final subscription = _listen(container);
      await flushTeacherControllers();
      final controller = container.read(
        teacherGroupListControllerProvider.notifier,
      );

      controller.nextPage();
      await flushTeacherControllers();
      controller.nextPage();
      await flushTeacherControllers();

      expect(repository.queries.map((query) => query.page), [1, 2, 3, 2]);
      expect(subscription.read().query.page, 2);
      expect(subscription.read().status, TeacherGroupListStatus.emptyPage);
    });

    test(
      'invalid draft remains visible when an older request completes',
      () async {
        final pending = Completer<TeacherGroupListPage>();
        final repository = FakeTeacherGroupListRepository(
          onFetch: (_) => pending.future,
        );
        final container = _container(repository: repository);
        final subscription = _listen(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherGroupListControllerProvider.notifier,
        );

        controller.updateSearchDraft(List.filled(255, '😀').join());
        pending.complete(teacherGroupPage());
        await flushTeacherControllers();

        expect(subscription.read().status, TeacherGroupListStatus.data);
        expect(
          subscription.read().searchErrorText,
          'Search must be 254 characters or fewer.',
        );
        controller.refresh();
        await flushTeacherControllers();
        expect(repository.queries, hasLength(1));
      },
    );

    test(
      'stale query and replaced or logged-out sessions cannot publish',
      () async {
        final first = Completer<TeacherGroupListPage>();
        final second = Completer<TeacherGroupListPage>();
        final repository = FakeTeacherGroupListRepository();
        repository.onFetch = (_) =>
            repository.queries.length == 1 ? first.future : second.future;
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final container = _container(repository: repository, auth: auth);
        final subscription = _listen(container);
        await flushTeacherControllers();
        final controller = container.read(
          teacherGroupListControllerProvider.notifier,
        );

        controller.updateSearchDraft('New');
        controller.commitSearchNow();
        await flushTeacherControllers();
        second.complete(teacherGroupPage());
        await flushTeacherControllers();
        first.completeError(teacherLocalFailure(ApiFailureKind.connection));
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherGroupListStatus.data);

        final replacement = Completer<TeacherGroupListPage>();
        repository.onFetch = (_) => replacement.future;
        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        auth.logOut();
        await flushTeacherControllers();
        replacement.complete(teacherGroupPage());
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherGroupListStatus.initial);
        expect(subscription.read().result, isNull);
      },
    );

    test('session-authority failures clear state and reconcile auth', () async {
      for (final code in [
        ApiErrorCodes.authenticationRequired,
        ApiErrorCodes.passwordChangeRequired,
        ApiErrorCodes.userInactive,
        ApiErrorCodes.institutionInactive,
      ]) {
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        auth.onBootstrap = () => const AuthSessionState.unauthenticated();
        final repository = FakeTeacherGroupListRepository(
          onFetch: (_) async => throw teacherServerFailure(
            code,
            statusCode: code == ApiErrorCodes.authenticationRequired
                ? 401
                : 403,
          ),
        );
        final container = _container(repository: repository, auth: auth);
        final subscription = _listen(container);
        await flushTeacherControllers();

        expect(subscription.read().status, TeacherGroupListStatus.initial);
        expect(subscription.read().result, isNull);
        expect(
          auth.bootstrapCalls,
          code == ApiErrorCodes.authenticationRequired ? 0 : 1,
        );
      }
    });
  });
}

ProviderContainer _container({
  required FakeTeacherGroupListRepository repository,
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
      teacherGroupListRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<TeacherGroupListState> _listen(
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
