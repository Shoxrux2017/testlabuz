import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair_repository.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _otherTopicId = '10000000-0000-0000-0000-000000000002';

void main() {
  test('initial load publishes a confirmed pair', () async {
    final pending = Completer<TeacherTopicResultPair?>();
    final repository = _FakeTeacherTopicResultPairRepository(
      onFetch: (_) => pending.future,
    );
    final harness = _Harness(repository: repository);
    final provider = teacherTopicResultPairControllerProvider(_topicId);
    final subscription = harness.container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );

    expect(subscription.read().status, TeacherTopicResultPairStatus.loading);
    await flushTeacherControllers();
    expect(repository.fetchIds, [_topicId]);

    final pair = _resultPair(topicId: _topicId);
    pending.complete(pair);
    await flushTeacherControllers();

    expect(subscription.read().status, TeacherTopicResultPairStatus.data);
    expect(subscription.read().pair, same(pair));
    expect(subscription.read().hasConfirmedData, isTrue);
    expect(subscription.read().failure, isNull);
  });

  test(
    'null response is confirmed data rather than loading or error',
    () async {
      final repository = _FakeTeacherTopicResultPairRepository(
        onFetch: (_) async => null,
      );
      final harness = _Harness(repository: repository);
      final subscription = harness.container.listen(
        teacherTopicResultPairControllerProvider(_topicId),
        (_, _) {},
        fireImmediately: true,
      );

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherTopicResultPairStatus.data);
      expect(subscription.read().hasConfirmedData, isTrue);
      expect(subscription.read().pair, isNull);
      expect(subscription.read().failure, isNull);
      expect(subscription.read().isStale, isFalse);
    },
  );

  test('refresh retains the explicit confirmed pair or null state', () async {
    for (final initialPair in <TeacherTopicResultPair?>[
      _resultPair(topicId: _topicId),
      null,
    ]) {
      final pendingRefresh = Completer<TeacherTopicResultPair?>();
      var fetches = 0;
      final repository = _FakeTeacherTopicResultPairRepository(
        onFetch: (_) {
          fetches += 1;
          return fetches == 1
              ? Future.value(initialPair)
              : pendingRefresh.future;
        },
      );
      final harness = _Harness(repository: repository);
      final provider = teacherTopicResultPairControllerProvider(_topicId);
      final subscription = harness.container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherTopicResultPairStatus.data);

      final refresh = harness.container.read(provider.notifier).refresh();

      expect(
        subscription.read().status,
        TeacherTopicResultPairStatus.refreshing,
      );
      expect(subscription.read().pair, same(initialPair));
      expect(subscription.read().isRequestInFlight, isTrue);

      final refreshedPair = initialPair == null
          ? _resultPair(
              topicId: _topicId,
              homeworkAssessmentId: '50000000-0000-0000-0000-000000000002',
            )
          : null;
      pendingRefresh.complete(refreshedPair);
      await refresh;

      expect(subscription.read().status, TeacherTopicResultPairStatus.data);
      expect(subscription.read().pair, same(refreshedPair));
      expect(repository.fetchIds, [_topicId, _topicId]);
    }
  });

  test('error stays distinct from null and Retry is GET-only', () async {
    final pendingRetry = Completer<TeacherTopicResultPair?>();
    var fetches = 0;
    final repository = _FakeTeacherTopicResultPairRepository(
      onFetch: (_) {
        fetches += 1;
        return switch (fetches) {
          1 => Future.error(teacherLocalFailure(ApiFailureKind.connection)),
          2 => pendingRetry.future,
          _ => Future.error(teacherLocalFailure(ApiFailureKind.timeout)),
        };
      },
    );
    final harness = _Harness(repository: repository);
    final provider = teacherTopicResultPairControllerProvider(_topicId);
    final subscription = harness.container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();

    expect(subscription.read().status, TeacherTopicResultPairStatus.error);
    expect(subscription.read().pair, isNull);
    expect(subscription.read().hasConfirmedData, isFalse);
    expect(subscription.read().isStale, isFalse);
    expect(subscription.read().failure!.kind, ApiFailureKind.connection);

    final retry = harness.container.read(provider.notifier).retry();
    expect(subscription.read().status, TeacherTopicResultPairStatus.loading);
    pendingRetry.complete(null);
    await retry;

    expect(subscription.read().status, TeacherTopicResultPairStatus.data);
    expect(subscription.read().pair, isNull);
    expect(subscription.read().hasConfirmedData, isTrue);

    await harness.container.read(provider.notifier).refresh();

    expect(subscription.read().status, TeacherTopicResultPairStatus.error);
    expect(subscription.read().pair, isNull);
    expect(subscription.read().isStale, isTrue);
    expect(subscription.read().failure!.kind, ApiFailureKind.timeout);
    expect(repository.fetchIds, [_topicId, _topicId, _topicId]);
    expect(repository.setRequests, isEmpty);
  });

  test('accept authoritative pair cancels an older GET completion', () async {
    final pending = Completer<TeacherTopicResultPair?>();
    final repository = _FakeTeacherTopicResultPairRepository(
      onFetch: (_) => pending.future,
    );
    final harness = _Harness(repository: repository);
    final provider = teacherTopicResultPairControllerProvider(_topicId);
    final subscription = harness.container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
    final accepted = _resultPair(
      topicId: _topicId,
      homeworkAssessmentId: '50000000-0000-0000-0000-000000000002',
    );

    harness.container
        .read(provider.notifier)
        .acceptAuthoritativePair(accepted, harness.sessionKey);

    expect(subscription.read().status, TeacherTopicResultPairStatus.data);
    expect(subscription.read().pair, same(accepted));

    pending.complete(_resultPair(topicId: _topicId));
    await flushTeacherControllers();

    expect(subscription.read().status, TeacherTopicResultPairStatus.data);
    expect(subscription.read().pair, same(accepted));

    harness.container
        .read(provider.notifier)
        .acceptAuthoritativePair(
          _resultPair(topicId: _otherTopicId),
          harness.sessionKey,
        );
    expect(subscription.read().pair, same(accepted));
  });

  test('mutation refresh supersedes a pre-mutation in-flight GET', () async {
    final oldRequest = Completer<TeacherTopicResultPair?>();
    final mutationRefresh = Completer<TeacherTopicResultPair?>();
    var fetches = 0;
    final repository = _FakeTeacherTopicResultPairRepository(
      onFetch: (_) {
        fetches += 1;
        return fetches == 1 ? oldRequest.future : mutationRefresh.future;
      },
    );
    final harness = _Harness(repository: repository);
    final provider = teacherTopicResultPairControllerProvider(_topicId);
    final subscription = harness.container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();

    final refresh = harness.container
        .read(provider.notifier)
        .refreshAfterMutation(harness.sessionKey);
    expect(repository.fetchIds, [_topicId, _topicId]);

    final currentPair = _resultPair(
      topicId: _topicId,
      homeworkAssessmentId: '50000000-0000-0000-0000-000000000002',
    );
    mutationRefresh.complete(currentPair);
    await refresh;
    expect(subscription.read().pair, same(currentPair));

    oldRequest.complete(_resultPair(topicId: _topicId));
    await flushTeacherControllers();

    expect(subscription.read().status, TeacherTopicResultPairStatus.data);
    expect(subscription.read().pair, same(currentPair));
  });

  test('session replacement ignores the stale GET completion', () async {
    final oldRequest = Completer<TeacherTopicResultPair?>();
    final newRequest = Completer<TeacherTopicResultPair?>();
    var fetches = 0;
    final repository = _FakeTeacherTopicResultPairRepository(
      onFetch: (_) {
        fetches += 1;
        return fetches == 1 ? oldRequest.future : newRequest.future;
      },
    );
    final auth = FakeTeacherAuthSessionController.authenticated(
      teacherUser('teacher-a'),
    );
    final harness = _Harness(repository: repository, auth: auth);
    final provider = teacherTopicResultPairControllerProvider(_topicId);
    final subscription = harness.container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();

    auth.replaceUser(teacherUser('teacher-b'));
    await flushTeacherControllers();
    expect(repository.fetchIds, [_topicId, _topicId]);

    final currentPair = _resultPair(
      topicId: _topicId,
      homeworkAssessmentId: '50000000-0000-0000-0000-000000000002',
    );
    newRequest.complete(currentPair);
    await flushTeacherControllers();
    expect(subscription.read().pair, same(currentPair));

    oldRequest.complete(_resultPair(topicId: _topicId));
    await flushTeacherControllers();

    expect(subscription.read().status, TeacherTopicResultPairStatus.data);
    expect(subscription.read().pair, same(currentPair));
  });

  test('disposed topic target cannot overwrite the current target', () async {
    final oldRequest = Completer<TeacherTopicResultPair?>();
    final currentPair = _resultPair(topicId: _otherTopicId);
    final repository = _FakeTeacherTopicResultPairRepository(
      onFetch: (topicId) =>
          topicId == _topicId ? oldRequest.future : Future.value(currentPair),
    );
    final harness = _Harness(repository: repository);
    final oldStates = <TeacherTopicResultPairState>[];
    final oldSubscription = harness.container.listen(
      teacherTopicResultPairControllerProvider(_topicId),
      (_, next) => oldStates.add(next),
      fireImmediately: true,
    );
    await flushTeacherControllers();

    oldSubscription.close();
    await flushTeacherControllers();
    final currentSubscription = harness.container.listen(
      teacherTopicResultPairControllerProvider(_otherTopicId),
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
    expect(currentSubscription.read().pair, same(currentPair));

    oldRequest.complete(_resultPair(topicId: _topicId));
    await flushTeacherControllers();

    expect(
      currentSubscription.read().status,
      TeacherTopicResultPairStatus.data,
    );
    expect(currentSubscription.read().pair, same(currentPair));
    expect(
      oldStates.where(
        (state) => state.status == TeacherTopicResultPairStatus.data,
      ),
      isEmpty,
    );
    expect(repository.fetchIds, [_topicId, _otherTopicId]);
  });
}

TeacherTopicResultPair _resultPair({
  required String topicId,
  String homeworkAssessmentId = '50000000-0000-0000-0000-000000000001',
}) {
  return TeacherTopicResultPair(
    id: '60000000-0000-0000-0000-000000000001',
    topicId: topicId,
    homeworkAssessmentId: homeworkAssessmentId,
    blitzAssessmentId: null,
    cohortSnapshottedAt: null,
    lockedAt: null,
    designatedAt: DateTime.utc(2026, 9, 1, 8),
    createdAt: DateTime.utc(2026, 9, 1, 8),
    updatedAt: DateTime.utc(2026, 9, 1, 8),
  );
}

class _Harness {
  _Harness({required this.repository, FakeTeacherAuthSessionController? auth})
    : auth =
          auth ??
          FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final _FakeTeacherTopicResultPairRepository repository;
  final FakeTeacherAuthSessionController auth;
  late final ProviderContainer container;

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    container.read(appDeviceSurfaceProvider),
  ).eligibleKey!;
}

class _FakeTeacherTopicResultPairRepository
    implements TeacherTopicResultPairRepository {
  _FakeTeacherTopicResultPairRepository({required this.onFetch});

  final Future<TeacherTopicResultPair?> Function(String topicId) onFetch;
  final fetchIds = <String>[];
  final setRequests = <({String topicId, String homeworkId})>[];

  @override
  Future<TeacherTopicResultPair?> fetchResultPair(String topicId) {
    fetchIds.add(topicId);
    return onFetch(topicId);
  }

  @override
  Future<TeacherTopicResultPair> setOfficialHomework(
    String topicId,
    String homeworkId,
  ) {
    setRequests.add((topicId: topicId, homeworkId: homeworkId));
    throw UnsupportedError('Official mutation is outside this focused test.');
  }
}
