import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_active_blitz_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_detail_state.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_route_target.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  test('loads the exact Blitz for its route target', () async {
    final harness = _Harness();
    expect(harness.state.status, StudentBlitzDetailStatus.loading);
    await flushStudentControllers();
    expect(harness.repository.detailIds, [studentBlitzId]);
    harness.pending.single.complete(studentBlitzDetail());
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.data);
    expect(harness.state.blitz!.title, 'Classroom Blitz');
  });

  test('a Blitz of another Topic is not shown under this route', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.complete(
      studentBlitzDetail(topicId: '10000000-0000-0000-0000-000000000009'),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.notFound);
    expect(harness.state.blitz, isNull);
  });

  test('another Blitz ID in the response is not found', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.complete(
      studentBlitzDetail(id: otherStudentBlitzId),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.notFound);
  });

  for (final (status, code, expected) in [
    (404, ApiErrorCodes.resourceNotFound, StudentBlitzDetailStatus.notFound),
    (409, ApiErrorCodes.blitzNotActive, StudentBlitzDetailStatus.notActive),
    (409, ApiErrorCodes.blitzTimeExpired, StudentBlitzDetailStatus.timeExpired),
  ]) {
    test('$code maps to ${expected.name} and refreshes the list', () async {
      final harness = _Harness();
      await flushStudentControllers();
      harness.pending.single.complete(studentBlitzDetail());
      await flushStudentControllers();
      final listCalls = harness.repository.activeCalls;
      harness.controller.refresh();
      expect(harness.state.status, StudentBlitzDetailStatus.refreshing);
      expect(harness.state.blitz, isNotNull);
      harness.pending.last.completeError(
        studentServerFailure(code, statusCode: status),
      );
      await flushStudentControllers();
      expect(harness.state.status, expected);
      expect(harness.state.blitz, isNull);
      expect(harness.repository.activeCalls, listCalls + 1);
    });
  }

  test('a generic failure is an error without Start authority', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.completeError(
      studentLocalFailure(ApiFailureKind.connection),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.error);
    expect(harness.state.failure!.kind, ApiFailureKind.connection);
    harness.controller.retry();
    expect(harness.state.status, StudentBlitzDetailStatus.loading);
    expect(harness.repository.detailIds, hasLength(2));
  });

  test('refresh retains data while pending and ignores repeats', () async {
    final harness = await _Harness.loaded();
    harness.controller.refresh();
    harness.controller.refresh();
    expect(harness.repository.detailIds, hasLength(2));
    expect(harness.state.status, StudentBlitzDetailStatus.refreshing);
    expect(harness.state.blitz!.id, studentBlitzId);
    harness.pending.last.complete(inProgressBlitzDetail());
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.data);
    expect(
      harness.state.blitz!.attempts.inProgressAttemptId,
      studentBlitzAttemptId,
    );
  });

  test('reconcile supersedes an older in-flight read', () async {
    final harness = await _Harness.loaded();
    harness.controller.refresh();
    final older = harness.pending.last;
    harness.controller.reconcile();
    expect(harness.repository.detailIds, hasLength(3));
    older.complete(studentBlitzDetail(title: 'Older read'));
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.refreshing);
    harness.pending.last.complete(studentBlitzDetail(title: 'Newest read'));
    await flushStudentControllers();
    expect(harness.state.blitz!.title, 'Newest read');
  });

  test(
    'local expiry reconciles once per snapshot and refreshes the list',
    () async {
      final harness = await _Harness.loaded();
      final listCalls = harness.repository.activeCalls;
      harness.controller.reconcileAfterLocalExpiry();
      harness.controller.reconcileAfterLocalExpiry();
      expect(harness.repository.detailIds, hasLength(2));
      expect(harness.repository.activeCalls, listCalls + 1);
      expect(harness.state.status, StudentBlitzDetailStatus.refreshing);
      harness.pending.last.completeError(
        studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
      );
      await flushStudentControllers();
      expect(harness.state.status, StudentBlitzDetailStatus.timeExpired);
      expect(harness.state.blitz, isNull);
    },
  );

  test(
    'expiry after a failed reconciliation stays an error, never data',
    () async {
      final harness = await _Harness.loaded();
      harness.controller.reconcileAfterLocalExpiry();
      harness.pending.last.completeError(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await flushStudentControllers();
      expect(harness.state.status, StudentBlitzDetailStatus.error);
      expect(harness.state.blitz, isNull);
      harness.controller.reconcileAfterLocalExpiry();
      expect(harness.repository.detailIds, hasLength(2));
      harness.controller.reconcile();
      expect(harness.repository.detailIds, hasLength(3));
      harness.pending.last.complete(studentBlitzDetail());
      await flushStudentControllers();
      harness.controller.reconcileAfterLocalExpiry();
      expect(harness.repository.detailIds, hasLength(4));
    },
  );

  test('a session switch ignores the old completion', () async {
    final harness = _Harness();
    await flushStudentControllers();
    final oldRead = harness.pending.single;
    harness.auth.replaceUser(studentUser('student-b'));
    await flushStudentControllers();
    oldRead.complete(studentBlitzDetail(title: 'Student A Blitz'));
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.loading);
    harness.pending.last.complete(studentBlitzDetail(title: 'Student B Blitz'));
    await flushStudentControllers();
    expect(harness.state.blitz!.title, 'Student B Blitz');
    harness.auth.logOut();
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.initial);
    expect(harness.state.blitz, isNull);
  });

  test('a disposed controller never publishes a late completion', () async {
    final harness = _Harness();
    await flushStudentControllers();
    final read = harness.pending.single;
    harness.subscription.close();
    await flushStudentControllers();
    read.complete(studentBlitzDetail());
    await flushStudentControllers();
    expect(harness.container.exists(harness.provider), isFalse);
  });

  test('a session failure clears detail and reconciles auth', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.completeError(
      studentServerFailure(ApiErrorCodes.institutionInactive),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.initial);
    expect(harness.auth.bootstrapCalls, 1);
  });

  test('local expiry supersedes an in-flight read', () async {
    final harness = await _Harness.loaded();
    harness.controller.refresh();
    final older = harness.pending.last;
    final listCalls = harness.repository.activeCalls;
    harness.controller.reconcileAfterLocalExpiry();
    expect(harness.repository.detailIds, hasLength(3));
    expect(harness.repository.activeCalls, listCalls + 1);
    older.complete(studentBlitzDetail(title: 'Read begun before zero'));
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.refreshing);
    harness.controller.reconcileAfterLocalExpiry();
    expect(harness.repository.detailIds, hasLength(3));
    harness.pending.last.completeError(
      studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.timeExpired);
  });

  test('an unexpected error is a load error, not an endless load', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.completeError(StateError('unexpected'));
    await flushStudentControllers();
    expect(harness.state.status, StudentBlitzDetailStatus.error);
    expect(harness.state.failure!.kind, ApiFailureKind.unknown);
  });
}

class _Harness {
  _Harness() {
    repository.onFetchBlitz = (_) {
      final completer = Completer<StudentBlitzDetail>();
      pending.add(completer);
      return completer.future;
    };
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        studentBlitzRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final list = container.listen(
      studentActiveBlitzControllerProvider,
      (_, _) {},
    );
    addTearDown(list.close);
    subscription = container.listen(provider, (_, _) {}, fireImmediately: true);
    addTearDown(subscription.close);
  }

  static Future<_Harness> loaded() async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.complete(studentBlitzDetail());
    await flushStudentControllers();
    return harness;
  }

  final target = StudentBlitzRouteTarget(
    topicId: studentTopicId,
    blitzId: studentBlitzId,
  );
  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  final repository = FakeStudentBlitzRepository();
  final pending = <Completer<StudentBlitzDetail>>[];
  late final ProviderContainer container;
  late final ProviderSubscription<StudentBlitzDetailState> subscription;

  NotifierProvider<StudentBlitzDetailController, StudentBlitzDetailState>
  get provider => studentBlitzDetailControllerProvider(target);
  StudentBlitzDetailState get state => subscription.read();
  StudentBlitzDetailController get controller =>
      container.read(provider.notifier);
}
