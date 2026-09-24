import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _otherTopicId = '10000000-0000-0000-0000-000000000002';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _otherBlitzId = '80000000-0000-0000-0000-000000000002';

void main() {
  group('TeacherBlitzRouteTarget', () {
    test('requires canonical IDs and has case-insensitive value equality', () {
      final lowercase = TeacherBlitzRouteTarget(
        topicId: _topicId,
        blitzId: _blitzId,
      );
      final uppercase = TeacherBlitzRouteTarget(
        topicId: _topicId.toUpperCase(),
        blitzId: _blitzId.toUpperCase(),
      );

      expect(uppercase, lowercase);
      expect(uppercase.hashCode, lowercase.hashCode);
      expect(
        lowercase ==
            TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _otherBlitzId),
        isFalse,
      );
      expect(
        lowercase ==
            TeacherBlitzRouteTarget(topicId: _otherTopicId, blitzId: _blitzId),
        isFalse,
      );
      for (final (topicId, blitzId) in [
        ('not-a-topic', _blitzId),
        (_topicId, 'not-a-blitz'),
        (' $_topicId', _blitzId),
        (_topicId, '$_blitzId '),
      ]) {
        expect(
          () => TeacherBlitzRouteTarget(topicId: topicId, blitzId: blitzId),
          throwsArgumentError,
        );
      }
    });
  });

  group('TeacherBlitzDetailController', () {
    test('initially loads the route target on desktop and mobile', () async {
      for (final surface in [
        AppDeviceSurface.desktop,
        AppDeviceSurface.mobile,
      ]) {
        final repository = FakeTeacherBlitzRepository();
        final harness = _Harness(repository: repository, surface: surface);
        final subscription = harness.listen();

        expect(subscription.read().status, TeacherBlitzDetailStatus.loading);
        await flushTeacherControllers();

        expect(repository.fetchIds, [_blitzId]);
        expect(subscription.read().status, TeacherBlitzDetailStatus.data);
        expect(subscription.read().blitz!.id, _blitzId);
        expect(subscription.read().failure, isNull);
        expect(subscription.read().isStale, isFalse);
      }
    });

    test('accepts the route Topic case-insensitively', () async {
      final repository = FakeTeacherBlitzRepository();
      final harness = _Harness(repository: repository);
      final subscription = harness.listen(
        target: TeacherBlitzRouteTarget(
          topicId: _topicId.toUpperCase(),
          blitzId: _blitzId.toUpperCase(),
        ),
      );

      await flushTeacherControllers();

      expect(repository.fetchIds, [_blitzId.toUpperCase()]);
      expect(subscription.read().status, TeacherBlitzDetailStatus.data);
    });

    test('a Blitz from another Topic maps to local notFound', () async {
      final repository = FakeTeacherBlitzRepository(
        onFetch: (blitzId) async =>
            teacherBlitz(id: blitzId, topicId: _otherTopicId),
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzDetailStatus.notFound);
      expect(subscription.read().blitz, isNull);
    });

    test('only exact 404 resource_not_found maps to notFound', () async {
      final cases = <(ApiRequestException, TeacherBlitzDetailStatus)>[
        (
          teacherServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
          TeacherBlitzDetailStatus.notFound,
        ),
        (
          teacherServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 410),
          TeacherBlitzDetailStatus.error,
        ),
        (
          teacherServerFailure(ApiErrorCodes.forbidden, statusCode: 404),
          TeacherBlitzDetailStatus.error,
        ),
        (
          teacherServerFailure(ApiErrorCodes.forbidden),
          TeacherBlitzDetailStatus.error,
        ),
        (
          teacherLocalFailure(ApiFailureKind.invalidResponse),
          TeacherBlitzDetailStatus.error,
        ),
      ];
      for (final (failure, expected) in cases) {
        final harness = _Harness(
          repository: FakeTeacherBlitzRepository(
            onFetch: (_) async => throw failure,
          ),
        );
        final subscription = harness.listen();

        await flushTeacherControllers();

        expect(subscription.read().status, expected);
        expect(subscription.read().blitz, isNull);
        expect(
          subscription.read().failure,
          expected == TeacherBlitzDetailStatus.error
              ? same(failure.failure)
              : isNull,
        );
      }
    });

    test('an unexpected failure becomes a retryable unknown error', () async {
      final harness = _Harness(
        repository: FakeTeacherBlitzRepository(
          onFetch: (_) async => throw StateError('Unexpected.'),
        ),
      );
      final subscription = harness.listen();

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzDetailStatus.error);
      expect(subscription.read().failure!.kind, ApiFailureKind.unknown);
    });

    test(
      'refresh retains the Blitz, suppresses duplicates, and marks failure stale',
      () async {
        final refresh = Completer<TeacherBlitz>();
        var calls = 0;
        final repository = FakeTeacherBlitzRepository(
          onFetch: (blitzId) {
            calls += 1;
            return calls == 1
                ? Future.value(teacherBlitz(id: blitzId))
                : refresh.future;
          },
        );
        final harness = _Harness(repository: repository);
        final subscription = harness.listen();
        await flushTeacherControllers();
        final confirmed = subscription.read().blitz;

        harness.controller.refresh();

        expect(subscription.read().status, TeacherBlitzDetailStatus.refreshing);
        expect(subscription.read().blitz, same(confirmed));
        expect(subscription.read().isLoading, isTrue);
        harness.controller
          ..refresh()
          ..retry();
        expect(repository.fetchIds, hasLength(2));

        refresh.completeError(teacherLocalFailure(ApiFailureKind.connection));
        await flushTeacherControllers();

        expect(subscription.read().status, TeacherBlitzDetailStatus.error);
        expect(subscription.read().blitz, same(confirmed));
        expect(subscription.read().isStale, isTrue);
        expect(subscription.read().failure!.kind, ApiFailureKind.connection);
      },
    );

    test('retry re-requests only from error and clears stale state', () async {
      var calls = 0;
      final repository = FakeTeacherBlitzRepository(
        onFetch: (blitzId) async {
          calls += 1;
          if (calls == 1) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return teacherBlitz(id: blitzId, title: 'Recovered Blitz');
        },
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherBlitzDetailStatus.error);
      expect(subscription.read().blitz, isNull);

      harness.controller.retry();
      expect(subscription.read().status, TeacherBlitzDetailStatus.loading);
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzDetailStatus.data);
      expect(subscription.read().blitz!.title, 'Recovered Blitz');
      expect(subscription.read().isStale, isFalse);

      harness.controller.retry();
      await flushTeacherControllers();
      expect(repository.fetchIds, hasLength(2));
    });

    test(
      'replacement session rejects old completion and reloads the target',
      () async {
        final oldSession = Completer<TeacherBlitz>();
        final newSession = Completer<TeacherBlitz>();
        var calls = 0;
        final repository = FakeTeacherBlitzRepository(
          onFetch: (_) {
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
        oldSession.complete(teacherBlitz(title: 'Old session Blitz'));
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherBlitzDetailStatus.loading);
        expect(subscription.read().blitz, isNull);

        newSession.complete(teacherBlitz(title: 'New session Blitz'));
        await flushTeacherControllers();
        expect(subscription.read().blitz!.title, 'New session Blitz');
        expect(repository.fetchIds, [_blitzId, _blitzId]);
      },
    );

    test(
      'logout, session loss, and disposal reject pending completions',
      () async {
        final pendingLogout = Completer<TeacherBlitz>();
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final logoutHarness = _Harness(
          repository: FakeTeacherBlitzRepository(
            onFetch: (_) => pendingLogout.future,
          ),
          auth: auth,
        );
        final logoutSubscription = logoutHarness.listen();
        await flushTeacherControllers();

        auth.logOut();
        await flushTeacherControllers();
        pendingLogout.complete(teacherBlitz());
        await flushTeacherControllers();
        expect(
          logoutSubscription.read().status,
          TeacherBlitzDetailStatus.initial,
        );
        expect(logoutSubscription.read().blitz, isNull);

        final pendingDisposal = Completer<TeacherBlitz>();
        final disposalHarness = _Harness(
          repository: FakeTeacherBlitzRepository(
            onFetch: (_) => pendingDisposal.future,
          ),
        );
        final observed = <TeacherBlitzDetailState>[];
        final disposalSubscription = disposalHarness.container.listen(
          teacherBlitzDetailControllerProvider(_target()),
          (_, next) => observed.add(next),
          fireImmediately: true,
        );
        await flushTeacherControllers();
        disposalSubscription.close();
        await flushTeacherControllers();
        expect(
          disposalHarness.container.exists(
            teacherBlitzDetailControllerProvider(_target()),
          ),
          isFalse,
        );
        final observationsAtDisposal = observed.length;
        pendingDisposal.complete(teacherBlitz());
        await flushTeacherControllers();
        expect(observed, hasLength(observationsAtDisposal));
      },
    );

    test('a device-surface identity change rejects old completion', () async {
      final desktopLoad = Completer<TeacherBlitz>();
      final mobileLoad = Completer<TeacherBlitz>();
      var calls = 0;
      final repository = FakeTeacherBlitzRepository(
        onFetch: (_) {
          calls += 1;
          return calls == 1 ? desktopLoad.future : mobileLoad.future;
        },
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.listen();
      await flushTeacherControllers();

      harness.setSurface(AppDeviceSurface.mobile);
      await flushTeacherControllers();
      desktopLoad.complete(teacherBlitz(title: 'Desktop Blitz'));
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherBlitzDetailStatus.loading);
      expect(subscription.read().blitz, isNull);

      mobileLoad.complete(teacherBlitz(title: 'Mobile Blitz'));
      await flushTeacherControllers();
      expect(subscription.read().blitz!.title, 'Mobile Blitz');
      expect(repository.fetchIds, [_blitzId, _blitzId]);
    });

    test('a completion for one target never publishes into another', () async {
      final targetA = Completer<TeacherBlitz>();
      final repository = FakeTeacherBlitzRepository(
        onFetch: (blitzId) => blitzId == _blitzId
            ? targetA.future
            : Future.value(
                teacherBlitz(
                  id: blitzId,
                  topicId: _otherTopicId,
                  title: 'Topic B Blitz Y',
                ),
              ),
      );
      final harness = _Harness(repository: repository);
      final subscriptionA = harness.listen();
      final targetB = TeacherBlitzRouteTarget(
        topicId: _otherTopicId,
        blitzId: _otherBlitzId,
      );
      final subscriptionB = harness.listen(target: targetB);
      await flushTeacherControllers();

      targetA.complete(teacherBlitz(title: 'Topic A Blitz X'));
      await flushTeacherControllers();

      expect(subscriptionA.read().blitz!.title, 'Topic A Blitz X');
      expect(subscriptionB.read().blitz!.title, 'Topic B Blitz Y');
      expect(subscriptionB.read().blitz!.id, _otherBlitzId);
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
            onFetch: (_) async => throw teacherServerFailure(code),
          );
          final harness = _Harness(repository: repository, auth: auth);
          final subscription = harness.listen();

          await flushTeacherControllers();

          expect(subscription.read().status, TeacherBlitzDetailStatus.initial);
          expect(subscription.read().blitz, isNull);
          expect(
            auth.bootstrapCalls,
            code == ApiErrorCodes.authenticationRequired ? 0 : 1,
          );
          harness.controller.refresh();
          await flushTeacherControllers();
          expect(repository.fetchIds, hasLength(1));
        }
      },
    );

    test(
      'accepts an authoritative Blitz only for the same session and target',
      () async {
        final pending = Completer<TeacherBlitz>();
        final harness = _Harness(
          repository: FakeTeacherBlitzRepository(
            onFetch: (_) => pending.future,
          ),
        );
        final subscription = harness.listen();
        await flushTeacherControllers();
        final sessionKey = harness.sessionKey;

        harness.controller.acceptAuthoritativeBlitz(
          teacherBlitz(id: _otherBlitzId, title: 'Other Blitz'),
          sessionKey,
        );
        harness.controller.acceptAuthoritativeBlitz(
          teacherBlitz(topicId: _otherTopicId, title: 'Other Topic'),
          sessionKey,
        );
        expect(subscription.read().status, TeacherBlitzDetailStatus.loading);

        harness.controller.acceptAuthoritativeBlitz(
          teacherBlitz(title: 'Accepted Blitz'),
          sessionKey,
        );
        expect(subscription.read().status, TeacherBlitzDetailStatus.data);
        expect(subscription.read().blitz!.title, 'Accepted Blitz');

        pending.complete(teacherBlitz(title: 'Older read'));
        await flushTeacherControllers();
        expect(subscription.read().blitz!.title, 'Accepted Blitz');
      },
    );

    test(
      'ignores an authoritative Blitz or notFound from another session',
      () async {
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = _Harness(
          repository: FakeTeacherBlitzRepository(),
          auth: auth,
        );
        final subscription = harness.listen();
        await flushTeacherControllers();
        final oldSession = harness.sessionKey;

        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        harness.controller
          ..acceptAuthoritativeBlitz(
            teacherBlitz(title: 'Old session'),
            oldSession,
          )
          ..markNotFound(oldSession);

        expect(subscription.read().status, TeacherBlitzDetailStatus.data);
        expect(subscription.read().blitz!.title, isNot('Old session'));

        harness.controller.markNotFound(harness.sessionKey);
        expect(subscription.read().status, TeacherBlitzDetailStatus.notFound);
        expect(subscription.read().blitz, isNull);
      },
    );

    test('an ineligible session performs no read', () async {
      final repository = FakeTeacherBlitzRepository();
      final harness = _Harness(
        repository: repository,
        auth: FakeTeacherAuthSessionController.authenticated(
          teacherUser('student-a', role: UserRole.student),
        ),
      );
      final subscription = harness.listen();

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherBlitzDetailStatus.initial);
      expect(repository.fetchIds, isEmpty);
    });
  });
}

TeacherBlitzRouteTarget _target() {
  return TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId);
}

class _Harness {
  factory _Harness({
    required FakeTeacherBlitzRepository repository,
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

  ProviderSubscription<TeacherBlitzDetailState> listen({
    TeacherBlitzRouteTarget? target,
  }) {
    return container.listen(
      teacherBlitzDetailControllerProvider(target ?? _target()),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherBlitzDetailController get controller =>
      container.read(teacherBlitzDetailControllerProvider(_target()).notifier);
}
