import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_active_blitz_controller.dart';
import 'package:testlabuz_client/features/student/application/student_active_blitz_state.dart';
import 'package:testlabuz_client/features/student/application/student_session_key.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  test('loads the global server list once and keeps its order', () async {
    final harness = _Harness();
    expect(harness.state.status, StudentActiveBlitzStatus.loading);
    expect(harness.state.items, isNull);
    await flushStudentControllers();
    expect(harness.repository.activeCalls, 1);
    harness.pending.single.complete([
      studentActiveBlitz(id: otherStudentBlitzId),
      studentActiveBlitz(),
    ]);
    await flushStudentControllers();
    expect(harness.state.status, StudentActiveBlitzStatus.data);
    expect(harness.state.items!.map((item) => item.id), [
      otherStudentBlitzId,
      studentBlitzId,
    ]);
    expect(harness.state.isStale, isFalse);
  });

  test('an empty server list is data with no items', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.complete(const []);
    await flushStudentControllers();
    expect(harness.state.status, StudentActiveBlitzStatus.data);
    expect(harness.state.items, isEmpty);
  });

  test('refresh retains cards and a failed refresh marks them stale', () async {
    final harness = await _Harness.loaded();
    harness.controller.refresh();
    expect(harness.state.status, StudentActiveBlitzStatus.refreshing);
    expect(harness.state.items!.single.id, studentBlitzId);
    harness.pending.last.completeError(
      studentLocalFailure(ApiFailureKind.connection),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentActiveBlitzStatus.error);
    expect(harness.state.items!.single.id, studentBlitzId);
    expect(harness.state.isStale, isTrue);
    expect(harness.state.failure!.kind, ApiFailureKind.connection);

    harness.controller.retry();
    expect(harness.state.status, StudentActiveBlitzStatus.refreshing);
    expect(harness.state.isStale, isTrue);
    harness.pending.last.complete([studentActiveBlitz(title: 'Fresh')]);
    await flushStudentControllers();
    expect(harness.state.status, StudentActiveBlitzStatus.data);
    expect(harness.state.items!.single.title, 'Fresh');
    expect(harness.state.isStale, isFalse);
  });

  test('an initial failure has no data and Retry reloads', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.completeError(
      studentLocalFailure(ApiFailureKind.timeout),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentActiveBlitzStatus.error);
    expect(harness.state.items, isNull);
    expect(harness.state.isStale, isFalse);
    harness.controller.retry();
    expect(harness.state.status, StudentActiveBlitzStatus.loading);
    expect(harness.repository.activeCalls, 2);
  });

  test('a duplicate refresh while one is in flight is suppressed', () async {
    final harness = await _Harness.loaded();
    harness.controller.refresh();
    harness.controller.refresh();
    harness.controller.retry();
    expect(harness.repository.activeCalls, 2);
  });

  test(
    'refreshAfterExecution supersedes an older in-flight list read',
    () async {
      final harness = await _Harness.loaded();
      harness.controller.refresh();
      final older = harness.pending.last;
      harness.controller.refreshAfterExecution(harness.sessionKey);
      expect(harness.repository.activeCalls, 3);
      expect(harness.state.status, StudentActiveBlitzStatus.refreshing);
      expect(harness.state.items!.single.id, studentBlitzId);
      older.complete([studentActiveBlitz(title: 'Older read')]);
      await flushStudentControllers();
      expect(harness.state.status, StudentActiveBlitzStatus.refreshing);
      harness.pending.last.complete([
        studentActiveBlitz(title: 'After execution'),
      ]);
      await flushStudentControllers();
      expect(harness.state.items!.single.title, 'After execution');
    },
  );

  test('refreshAfterExecution rejects a stale session owner', () async {
    final harness = await _Harness.loaded();
    final staleKey = harness.sessionKey;
    harness.auth.replaceUser(studentUser('student-b'));
    await flushStudentControllers();
    final calls = harness.repository.activeCalls;
    harness.controller.refreshAfterExecution(staleKey);
    expect(harness.repository.activeCalls, calls);
  });

  test(
    'a session switch clears items and ignores the old completion',
    () async {
      final harness = _Harness();
      await flushStudentControllers();
      final oldRead = harness.pending.single;
      harness.auth.replaceUser(studentUser('student-b'));
      await flushStudentControllers();
      expect(harness.state.items, isNull);
      expect(harness.repository.activeCalls, 2);
      oldRead.complete([studentActiveBlitz(title: 'Student A Blitz')]);
      await flushStudentControllers();
      expect(harness.state.status, StudentActiveBlitzStatus.loading);
      harness.pending.last.complete([
        studentActiveBlitz(title: 'Student B Blitz'),
      ]);
      await flushStudentControllers();
      expect(harness.state.items!.single.title, 'Student B Blitz');

      harness.auth.logOut();
      await flushStudentControllers();
      expect(harness.state.status, StudentActiveBlitzStatus.initial);
      expect(harness.state.items, isNull);
    },
  );

  test('a session failure clears the list and reconciles auth', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.completeError(
      studentServerFailure(ApiErrorCodes.passwordChangeRequired),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentActiveBlitzStatus.initial);
    expect(harness.state.items, isNull);
    expect(harness.auth.bootstrapCalls, 1);
  });

  test('an unexpected error ends loading with an unknown failure', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.completeError(StateError('unexpected'));
    await flushStudentControllers();
    expect(harness.state.status, StudentActiveBlitzStatus.error);
    expect(harness.state.failure!.kind, ApiFailureKind.unknown);
    expect(harness.state.items, isNull);
  });
}

class _Harness {
  _Harness() {
    repository.onFetchActive = () {
      final completer = Completer<List<StudentActiveBlitzSummary>>();
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
    subscription = container.listen(
      studentActiveBlitzControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
  }

  static Future<_Harness> loaded() async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.complete([studentActiveBlitz()]);
    await flushStudentControllers();
    return harness;
  }

  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  final repository = FakeStudentBlitzRepository();
  final pending = <Completer<List<StudentActiveBlitzSummary>>>[];
  late final ProviderContainer container;
  late final ProviderSubscription<StudentActiveBlitzState> subscription;

  StudentActiveBlitzState get state => subscription.read();
  StudentActiveBlitzController get controller =>
      container.read(studentActiveBlitzControllerProvider.notifier);
  StudentSessionKey get sessionKey => StudentSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    container.read(appDeviceSurfaceProvider),
  ).eligibleKey!;
}
