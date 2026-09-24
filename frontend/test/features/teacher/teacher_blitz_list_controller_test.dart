import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_list_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_list_query.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherBlitzListController', () {
    test('initially loads the Topic list on desktop and mobile', () async {
      for (final surface in [
        AppDeviceSurface.desktop,
        AppDeviceSurface.mobile,
      ]) {
        final repository = FakeTeacherBlitzRepository(
          onFetchList: (_, query) async => _list(query),
        );
        final harness = _Harness(repository: repository, surface: surface);
        final subscription = harness.listen();

        expect(subscription.read().status, TeacherBlitzListStatus.loading);
        await flushTeacherControllers();

        expect(repository.listRequests, [
          (topicId: _topicId, query: const TeacherBlitzListQuery.initial()),
        ]);
        expect(subscription.read().status, TeacherBlitzListStatus.data);
        expect(subscription.read().result!.items.single.title, 'Blitz 1');
        expect(subscription.read().failure, isNull);
        expect(subscription.read().isStale, isFalse);
      }
    });

    test('invalid Topic ID remains initial and sends no request', () async {
      final repository = FakeTeacherBlitzRepository();
      final harness = _Harness(repository: repository);
      final subscription = harness.listen(topicId: 'not-a-topic');

      await flushTeacherControllers();

      expect(repository.listRequests, isEmpty);
      expect(subscription.read().status, TeacherBlitzListStatus.initial);
    });

    test('status filter resets the page and loads the server query', () async {
      final repository = FakeTeacherBlitzRepository(
        onFetchList: (_, query) async => _list(query, total: 45, lastPage: 3),
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      harness.controller.nextPage();
      await flushTeacherControllers();
      expect(subscription.read().query.page, 2);

      harness.controller.setStatus(TeacherBlitzStatus.closed);
      await flushTeacherControllers();
      expect(
        repository.listRequests.last.query.status,
        TeacherBlitzStatus.closed,
      );
      expect(repository.listRequests.last.query.page, 1);
      expect(subscription.read().query.status, TeacherBlitzStatus.closed);
      expect(subscription.read().status, TeacherBlitzListStatus.data);

      final requestsBeforeSameStatus = repository.listRequests.length;
      harness.controller.setStatus(TeacherBlitzStatus.closed);
      await flushTeacherControllers();
      expect(repository.listRequests, hasLength(requestsBeforeSameStatus));

      harness.controller.setStatus(null);
      await flushTeacherControllers();
      expect(
        repository.listRequests.last.query,
        const TeacherBlitzListQuery.initial(),
      );
    });

    test('previous and next move only within confirmed pagination', () async {
      final repository = FakeTeacherBlitzRepository(
        onFetchList: (_, query) async => _list(query, total: 41, lastPage: 3),
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      expect(subscription.read().canGoPrevious, isFalse);
      expect(subscription.read().canGoNext, isTrue);
      harness.controller.previousPage();
      await flushTeacherControllers();
      expect(repository.listRequests, hasLength(1));

      harness.controller
        ..nextPage()
        ..nextPage();
      await flushTeacherControllers();
      expect(repository.listRequests.map((request) => request.query.page), [
        1,
        2,
      ]);
      harness.controller.nextPage();
      await flushTeacherControllers();
      expect(subscription.read().query.page, 3);
      expect(subscription.read().canGoNext, isFalse);

      harness.controller.nextPage();
      await flushTeacherControllers();
      expect(repository.listRequests, hasLength(3));

      harness.controller.previousPage();
      await flushTeacherControllers();
      expect(repository.listRequests.last.query.page, 2);
      expect(subscription.read().canGoPrevious, isTrue);
    });

    test(
      'refresh retains confirmed rows, suppresses a duplicate, and marks failure stale',
      () async {
        final refresh = Completer<TeacherBlitzList>();
        var calls = 0;
        final repository = FakeTeacherBlitzRepository(
          onFetchList: (_, query) {
            calls += 1;
            return calls == 1 ? Future.value(_list(query)) : refresh.future;
          },
        );
        final harness = _Harness(repository: repository);
        final subscription = harness.listen();
        await flushTeacherControllers();
        final confirmed = subscription.read().result;

        harness.controller.refresh();

        expect(subscription.read().status, TeacherBlitzListStatus.refreshing);
        expect(subscription.read().result, same(confirmed));
        expect(subscription.read().canGoNext, isFalse);
        harness.controller
          ..refresh()
          ..retry();
        expect(repository.listRequests, hasLength(2));

        refresh.completeError(teacherLocalFailure(ApiFailureKind.timeout));
        await flushTeacherControllers();

        expect(subscription.read().status, TeacherBlitzListStatus.error);
        expect(subscription.read().result, same(confirmed));
        expect(subscription.read().isStale, isTrue);
        expect(subscription.read().failure!.kind, ApiFailureKind.timeout);
      },
    );

    test('initial failure has no result and retry loads again', () async {
      var calls = 0;
      final repository = FakeTeacherBlitzRepository(
        onFetchList: (_, query) async {
          calls += 1;
          if (calls == 1) {
            throw teacherLocalFailure(ApiFailureKind.invalidResponse);
          }
          return _list(query, title: 'Recovered');
        },
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzListStatus.error);
      expect(subscription.read().result, isNull);
      expect(subscription.read().isStale, isFalse);
      expect(subscription.read().failure!.kind, ApiFailureKind.invalidResponse);

      harness.controller.retry();
      expect(subscription.read().status, TeacherBlitzListStatus.loading);
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzListStatus.data);
      expect(subscription.read().result!.items.single.title, 'Recovered');
      expect(repository.listRequests, hasLength(2));

      harness.controller.retry();
      await flushTeacherControllers();
      expect(repository.listRequests, hasLength(2));
    });

    test('an unexpected failure becomes a retryable unknown error', () async {
      final repository = FakeTeacherBlitzRepository(
        onFetchList: (_, _) async => throw StateError('Unexpected.'),
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzListStatus.error);
      expect(subscription.read().failure!.kind, ApiFailureKind.unknown);
    });

    test('an older query completion cannot overwrite a newer query', () async {
      final older = Completer<TeacherBlitzList>();
      final newer = Completer<TeacherBlitzList>();
      final repository = FakeTeacherBlitzRepository(
        onFetchList: (_, query) =>
            query.status == null ? older.future : newer.future,
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      harness.controller.setStatus(TeacherBlitzStatus.active);
      newer.complete(
        _list(repository.listRequests.last.query, title: 'Current row'),
      );
      await flushTeacherControllers();
      older.complete(
        _list(const TeacherBlitzListQuery.initial(), title: 'Old row'),
      );
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzListStatus.data);
      expect(subscription.read().query.status, TeacherBlitzStatus.active);
      expect(subscription.read().result!.items.single.title, 'Current row');
    });

    test('an older failure cannot mark a newer query as failed', () async {
      final older = Completer<TeacherBlitzList>();
      final repository = FakeTeacherBlitzRepository(
        onFetchList: (_, query) => query.status == null
            ? older.future
            : Future.value(_list(query, title: 'Current row')),
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      harness.controller.setStatus(TeacherBlitzStatus.draft);
      await flushTeacherControllers();
      older.completeError(teacherLocalFailure(ApiFailureKind.connection));
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzListStatus.data);
      expect(subscription.read().failure, isNull);
      expect(subscription.read().result!.items.single.title, 'Current row');
    });

    test(
      'replacement session rejects old completion and starts a new load',
      () async {
        final oldSession = Completer<TeacherBlitzList>();
        final newSession = Completer<TeacherBlitzList>();
        var calls = 0;
        final repository = FakeTeacherBlitzRepository(
          onFetchList: (_, _) {
            calls += 1;
            return calls == 1 ? oldSession.future : newSession.future;
          },
        );
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = _Harness(repository: repository, auth: auth);
        final subscription = harness.listen();
        await flushTeacherControllers();

        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        oldSession.complete(
          _list(const TeacherBlitzListQuery.initial(), title: 'Old session'),
        );
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherBlitzListStatus.loading);
        expect(subscription.read().result, isNull);

        newSession.complete(
          _list(const TeacherBlitzListQuery.initial(), title: 'New session'),
        );
        await flushTeacherControllers();
        expect(subscription.read().result!.items.single.title, 'New session');
        expect(repository.listRequests, hasLength(2));
      },
    );

    test('a device-surface identity change rejects old completion', () async {
      final desktopLoad = Completer<TeacherBlitzList>();
      final mobileLoad = Completer<TeacherBlitzList>();
      var calls = 0;
      final repository = FakeTeacherBlitzRepository(
        onFetchList: (_, _) {
          calls += 1;
          return calls == 1 ? desktopLoad.future : mobileLoad.future;
        },
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      harness.setSurface(AppDeviceSurface.mobile);
      await flushTeacherControllers();
      desktopLoad.complete(
        _list(const TeacherBlitzListQuery.initial(), title: 'Desktop'),
      );
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherBlitzListStatus.loading);
      expect(subscription.read().result, isNull);

      mobileLoad.complete(
        _list(const TeacherBlitzListQuery.initial(), title: 'Mobile'),
      );
      await flushTeacherControllers();
      expect(subscription.read().result!.items.single.title, 'Mobile');
      expect(repository.listRequests, hasLength(2));
    });

    test('logout and provider disposal reject pending completions', () async {
      final pendingLogout = Completer<TeacherBlitzList>();
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final logoutHarness = _Harness(
        repository: FakeTeacherBlitzRepository(
          onFetchList: (_, _) => pendingLogout.future,
        ),
        auth: auth,
      );
      final logoutSubscription = logoutHarness.listen();
      await flushTeacherControllers();

      auth.logOut();
      await flushTeacherControllers();
      pendingLogout.complete(_list(const TeacherBlitzListQuery.initial()));
      await flushTeacherControllers();
      expect(logoutSubscription.read().status, TeacherBlitzListStatus.initial);
      expect(logoutSubscription.read().result, isNull);

      final pendingDisposal = Completer<TeacherBlitzList>();
      final disposalHarness = _Harness(
        repository: FakeTeacherBlitzRepository(
          onFetchList: (_, _) => pendingDisposal.future,
        ),
      );
      final observed = <TeacherBlitzListState>[];
      final disposalSubscription = disposalHarness.container.listen(
        teacherBlitzListControllerProvider(_topicId),
        (_, next) => observed.add(next),
        fireImmediately: true,
      );
      await flushTeacherControllers();
      disposalSubscription.close();
      await flushTeacherControllers();
      expect(
        disposalHarness.container.exists(
          teacherBlitzListControllerProvider(_topicId),
        ),
        isFalse,
      );
      final observationsAtDisposal = observed.length;
      pendingDisposal.complete(_list(const TeacherBlitzListQuery.initial()));
      await flushTeacherControllers();
      expect(observed, hasLength(observationsAtDisposal));
    });

    test(
      'structured session failures clear ownership and reconcile auth',
      () async {
        for (final code in [
          ApiErrorCodes.authenticationRequired,
          ApiErrorCodes.passwordChangeRequired,
          ApiErrorCodes.userInactive,
          ApiErrorCodes.institutionInactive,
        ]) {
          final auth = FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          );
          final repository = FakeTeacherBlitzRepository(
            onFetchList: (_, _) async => throw teacherServerFailure(code),
          );
          final harness = _Harness(repository: repository, auth: auth);
          final subscription = harness.listen();

          await flushTeacherControllers();

          expect(subscription.read().status, TeacherBlitzListStatus.initial);
          expect(subscription.read().result, isNull);
          expect(
            auth.bootstrapCalls,
            code == ApiErrorCodes.authenticationRequired ? 0 : 1,
          );
          harness.controller.refresh();
          await flushTeacherControllers();
          expect(repository.listRequests, hasLength(1));
        }
      },
    );

    test(
      'refresh after mutation keeps the query and supersedes older reads',
      () async {
        final older = Completer<TeacherBlitzList>();
        var calls = 0;
        final repository = FakeTeacherBlitzRepository(
          onFetchList: (_, query) {
            calls += 1;
            if (calls == 2) {
              return older.future;
            }
            return Future.value(
              _list(query, title: 'Read $calls', total: 41, lastPage: 3),
            );
          },
        );
        final harness = _Harness(repository: repository);
        final subscription = harness.listen();
        await flushTeacherControllers();
        harness.controller.setStatus(TeacherBlitzStatus.draft);
        expect(subscription.read().status, TeacherBlitzListStatus.loading);

        harness.controller.refreshAfterMutation(harness.sessionKey);
        final afterMutation = repository.listRequests.last.query;
        expect(afterMutation.status, TeacherBlitzStatus.draft);
        expect(afterMutation.page, 1);
        await flushTeacherControllers();
        older.complete(_list(afterMutation, title: 'Superseded read'));
        await flushTeacherControllers();

        expect(repository.listRequests, hasLength(3));
        expect(subscription.read().status, TeacherBlitzListStatus.data);
        expect(subscription.read().result!.items.single.title, 'Read 3');
      },
    );

    test(
      'refresh after mutation retains rows and ignores a stale session',
      () async {
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final refresh = Completer<TeacherBlitzList>();
        var calls = 0;
        final repository = FakeTeacherBlitzRepository(
          onFetchList: (_, query) {
            calls += 1;
            return calls == 1 ? Future.value(_list(query)) : refresh.future;
          },
        );
        final harness = _Harness(repository: repository, auth: auth);
        final subscription = harness.listen();
        await flushTeacherControllers();
        final confirmed = subscription.read().result;

        harness.controller.refreshAfterMutation(harness.sessionKey);
        expect(subscription.read().status, TeacherBlitzListStatus.refreshing);
        expect(subscription.read().result, same(confirmed));
        refresh.complete(_list(const TeacherBlitzListQuery.initial()));
        await flushTeacherControllers();

        final oldSession = harness.sessionKey;
        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        final requestsAfterSwitch = repository.listRequests.length;
        harness.controller.refreshAfterMutation(oldSession);
        await flushTeacherControllers();
        expect(repository.listRequests, hasLength(requestsAfterSwitch));
      },
    );

    test('forbidden and not found remain ordinary list errors', () async {
      for (final failure in [
        teacherServerFailure(ApiErrorCodes.forbidden),
        teacherServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      ]) {
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = _Harness(
          repository: FakeTeacherBlitzRepository(
            onFetchList: (_, _) async => throw failure,
          ),
          auth: auth,
        );
        final subscription = harness.listen();

        await flushTeacherControllers();

        expect(subscription.read().status, TeacherBlitzListStatus.error);
        expect(subscription.read().failure, same(failure.failure));
        expect(auth.bootstrapCalls, 0);
      }
    });
  });
}

class _Harness {
  factory _Harness({
    required FakeTeacherBlitzRepository repository,
    FakeTeacherAuthSessionController? auth,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) {
    final effectiveAuth =
        auth ??
        FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => effectiveAuth),
        teacherTestSurfaceProvider.overrideWith(
          () => TeacherTestSurfaceController(surface),
        ),
        appDeviceSurfaceProvider.overrideWith(
          (ref) => ref.watch(teacherTestSurfaceProvider),
        ),
        teacherBlitzRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return _Harness._(container: container);
  }

  const _Harness._({required this.container});

  final ProviderContainer container;

  void setSurface(AppDeviceSurface surface) {
    container.read(teacherTestSurfaceProvider.notifier).change(surface);
  }

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    container.read(appDeviceSurfaceProvider),
  ).eligibleKey!;

  ProviderSubscription<TeacherBlitzListState> listen({
    String topicId = _topicId,
  }) {
    return container.listen(
      teacherBlitzListControllerProvider(topicId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherBlitzListController get controller =>
      container.read(teacherBlitzListControllerProvider(_topicId).notifier);
}

TeacherBlitzList _list(
  TeacherBlitzListQuery query, {
  String title = 'Blitz 1',
  int total = 1,
  int lastPage = 1,
}) {
  return teacherBlitzList(
    items: [teacherBlitzSummary(title: title)],
    page: query.page,
    perPage: query.perPage,
    total: total,
    lastPage: lastPage,
  );
}
