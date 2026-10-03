import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_topic_result_controller.dart';
import 'package:testlabuz_client/features/student/application/student_topic_result_state.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_result.dart';

import 'student_test_support.dart';

const _hexTopicId = 'abcdef12-3456-4789-8abc-def012345678';

void main() {
  group('Student Topic result controller', () {
    test('loads the result and refreshes with the result retained', () async {
      final pendingRefresh = Completer<StudentTopicResult?>();
      var fetches = 0;
      final repository = FakeStudentTopicRepository(
        onFetchTopicResult: (_) {
          fetches += 1;
          return fetches == 1
              ? Future.value(studentTopicResult(topicId: _hexTopicId))
              : pendingRefresh.future;
        },
      );
      final container = _container(repository: repository);
      final subscription = _listen(container, _hexTopicId.toUpperCase());
      await flushStudentControllers();
      expect(subscription.read().status, StudentTopicResultLoadStatus.data);
      expect(subscription.read().result?.finalScore, 86.0);

      container
          .read(
            studentTopicResultControllerProvider(
              _hexTopicId.toUpperCase(),
            ).notifier,
          )
          .refresh();
      expect(
        subscription.read().status,
        StudentTopicResultLoadStatus.refreshing,
      );
      expect(subscription.read().result, isNotNull);
      pendingRefresh.complete(
        studentTopicResult(topicId: _hexTopicId, finalScore: 80),
      );
      await flushStudentControllers();

      expect(subscription.read().result?.finalScore, 80.0);
      expect(repository.resultIds, [_hexTopicId, _hexTopicId]);
    });

    test('a controller disposed before its first load does not fail', () async {
      final repository = FakeStudentTopicRepository();
      final container = _container(repository: repository);
      container.listen(
        studentTopicResultControllerProvider(studentTopicId),
        (_, _) {},
        fireImmediately: true,
      );
      // Disposed before the scheduled first load runs: no load, no use of a disposed Ref.
      container.dispose();
      await flushStudentControllers();

      expect(repository.resultIds, isEmpty);
    });

    test('a Student without a result has data and no result', () async {
      final container = _container(repository: FakeStudentTopicRepository());
      final subscription = _listen(container, studentTopicId);
      await flushStudentControllers();

      expect(subscription.read().status, StudentTopicResultLoadStatus.data);
      expect(subscription.read().result, isNull);
    });

    test('an invalid Topic id never loads', () async {
      final repository = FakeStudentTopicRepository();
      final container = _container(repository: repository);
      final subscription = _listen(container, 'invalid-topic');
      await flushStudentControllers();

      expect(subscription.read().status, StudentTopicResultLoadStatus.initial);
      expect(repository.resultIds, isEmpty);
    });

    test('a stale result cannot publish after the session changed', () async {
      final pending = Completer<StudentTopicResult?>();
      final replacement = Completer<StudentTopicResult?>();
      var fetches = 0;
      final repository = FakeStudentTopicRepository(
        onFetchTopicResult: (_) {
          fetches += 1;
          return fetches == 1 ? pending.future : replacement.future;
        },
      );
      final auth = FakeStudentAuthSessionController.authenticated(
        studentUser('student-a'),
      );
      final container = _container(repository: repository, auth: auth);
      final subscription = _listen(container, studentTopicId);
      await flushStudentControllers();

      auth.replaceUser(studentUser('student-b'));
      await flushStudentControllers();
      pending.complete(studentTopicResult(finalScore: 10));
      await flushStudentControllers();
      expect(subscription.read().result?.finalScore, isNot(10.0));

      replacement.complete(studentTopicResult(finalScore: 70));
      await flushStudentControllers();
      expect(subscription.read().result?.finalScore, 70.0);
    });

    test(
      'a failure keeps the earlier result and a retry loads again',
      () async {
        var fetches = 0;
        final repository = FakeStudentTopicRepository(
          onFetchTopicResult: (_) async {
            fetches += 1;
            if (fetches == 2) {
              throw studentServerFailure(
                ApiErrorCodes.serverError,
                statusCode: 500,
              );
            }
            return studentTopicResult(finalScore: fetches == 1 ? 86 : 90);
          },
        );
        final container = _container(repository: repository);
        final subscription = _listen(container, studentTopicId);
        await flushStudentControllers();
        final notifier = container.read(
          studentTopicResultControllerProvider(studentTopicId).notifier,
        );

        notifier.refresh();
        await flushStudentControllers();
        expect(subscription.read().status, StudentTopicResultLoadStatus.error);
        expect(subscription.read().failure?.statusCode, 500);
        expect(subscription.read().result?.finalScore, 86.0);

        notifier.refresh();
        await flushStudentControllers();
        expect(subscription.read().status, StudentTopicResultLoadStatus.data);
        expect(subscription.read().result?.finalScore, 90.0);
      },
    );

    test('an unexpected error becomes a local unknown failure', () async {
      final repository = FakeStudentTopicRepository(
        onFetchTopicResult: (_) async => throw StateError('unexpected'),
      );
      final container = _container(repository: repository);
      final subscription = _listen(container, studentTopicId);
      await flushStudentControllers();

      expect(subscription.read().status, StudentTopicResultLoadStatus.error);
      expect(subscription.read().failure?.kind, ApiFailureKind.unknown);
    });

    test('session failures clear the state and re-run bootstrap', () async {
      for (final (code, bootstraps) in [
        (ApiErrorCodes.authenticationRequired, 0),
        (ApiErrorCodes.passwordChangeRequired, 1),
      ]) {
        final repository = FakeStudentTopicRepository(
          onFetchTopicResult: (_) async =>
              throw studentServerFailure(code, statusCode: 401),
        );
        final auth = FakeStudentAuthSessionController.authenticated(
          studentUser('student-a'),
        );
        final container = _container(repository: repository, auth: auth);
        final subscription = _listen(container, studentTopicId);
        await flushStudentControllers();

        expect(
          subscription.read().status,
          StudentTopicResultLoadStatus.initial,
          reason: code,
        );
        expect(auth.bootstrapCalls, bootstraps, reason: code);
      }
    });
  });
}

ProviderContainer _container({
  required FakeStudentTopicRepository repository,
  FakeStudentAuthSessionController? auth,
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
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.mobile),
      studentTopicRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<StudentTopicResultState> _listen(
  ProviderContainer container,
  String topicId,
) {
  final subscription = container.listen(
    studentTopicResultControllerProvider(topicId),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return subscription;
}
