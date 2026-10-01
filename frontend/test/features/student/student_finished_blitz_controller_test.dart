import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_finished_blitz_controller.dart';
import 'package:testlabuz_client/features/student/application/student_finished_blitz_state.dart';
import 'package:testlabuz_client/features/student/data/dto/student_finished_blitz_dto.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_finished_blitz.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

/// A page of [total] finished Blitz tasks, five per page.
StudentFinishedBlitzPage _page(int page, {int total = 12}) {
  final start = (page - 1) * 5;
  final count = (total - start).clamp(0, 5);
  return StudentFinishedBlitzPageDto.fromJson(
    finishedBlitzPageJson(
      [
        for (var index = 0; index < count; index++)
          finishedBlitzJson(
            id: 'b1000000-0000-0000-0000-${(start + index + 1).toString().padLeft(12, '0')}',
          ),
      ],
      page: page,
      total: total,
    ),
    page: page,
    perPage: 5,
  ).toDomain();
}

void main() {
  test('loads page 1 of five on build', () async {
    final harness = _Harness();
    expect(harness.state.status, StudentFinishedBlitzLoadStatus.loading);
    await flushStudentControllers();

    expect(harness.requests, [(1, 5)]);
    harness.pending.single.complete(_page(1));
    await flushStudentControllers();

    expect(harness.state.status, StudentFinishedBlitzLoadStatus.data);
    expect(harness.state.page?.items, hasLength(5));
    expect(harness.state.isStale, isFalse);
  });

  test('pages move forward and back and stop at the ends', () async {
    final harness = await _Harness.loaded();

    harness.controller.previousPage();
    expect(harness.requests, hasLength(1));

    harness.controller.nextPage();
    harness.controller.nextPage();
    expect(harness.requests, [(1, 5), (2, 5)]);
    harness.pending.last.complete(_page(2));
    await flushStudentControllers();
    harness.controller.nextPage();
    harness.pending.last.complete(_page(3));
    await flushStudentControllers();
    expect(harness.state.page?.page, 3);

    harness.controller.nextPage();
    expect(harness.requests, hasLength(3));

    harness.controller.previousPage();
    harness.pending.last.complete(_page(2));
    await flushStudentControllers();
    expect(harness.requests.last, (2, 5));
    expect(harness.state.page?.page, 2);
  });

  test('refresh keeps the page and a failed refresh is stale', () async {
    final harness = await _Harness.loaded();
    harness.controller.nextPage();
    harness.pending.last.complete(_page(2));
    await flushStudentControllers();

    harness.controller.refresh();
    expect(harness.state.status, StudentFinishedBlitzLoadStatus.refreshing);
    expect(harness.requests.last, (2, 5));
    harness.pending.last.completeError(
      studentLocalFailure(ApiFailureKind.timeout),
    );
    await flushStudentControllers();

    expect(harness.state.status, StudentFinishedBlitzLoadStatus.error);
    expect(harness.state.isStale, isTrue);
    expect(harness.state.page?.page, 2);
    expect(harness.state.failure?.kind, ApiFailureKind.timeout);

    harness.controller.retry();
    harness.pending.last.complete(_page(2));
    await flushStudentControllers();
    expect(harness.requests.last, (2, 5));
    expect(harness.state.isStale, isFalse);
  });

  test(
    'a failed page change keeps the page and retries the asked page',
    () async {
      final harness = await _Harness.loaded();

      harness.controller.nextPage();
      harness.pending.last.completeError(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await flushStudentControllers();

      expect(harness.state.status, StudentFinishedBlitzLoadStatus.error);
      expect(harness.state.isStale, isTrue);
      expect(harness.state.page?.page, 1);

      harness.controller.retry();
      expect(harness.requests.last, (2, 5));
      harness.pending.last.complete(_page(2));
      await flushStudentControllers();
      expect(harness.state.page?.page, 2);

      harness.controller.refresh();
      expect(harness.requests.last, (2, 5));
    },
  );

  test('refresh reloads the shown page after a failed page change', () async {
    final harness = await _Harness.loaded();
    harness.controller.nextPage();
    harness.pending.last.completeError(
      studentLocalFailure(ApiFailureKind.timeout),
    );
    await flushStudentControllers();

    harness.controller.refresh();

    expect(harness.requests.last, (1, 5));
  });

  test('an initial failure can be retried', () async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.completeError(
      studentLocalFailure(ApiFailureKind.connection),
    );
    await flushStudentControllers();
    expect(harness.state.status, StudentFinishedBlitzLoadStatus.error);
    expect(harness.state.page, isNull);

    harness.controller.retry();
    harness.pending.last.complete(_page(1));
    await flushStudentControllers();

    expect(harness.state.status, StudentFinishedBlitzLoadStatus.data);
  });

  test('requests are ignored while one is in flight', () async {
    final harness = await _Harness.loaded();
    harness.controller.nextPage();

    harness.controller
      ..nextPage()
      ..refresh()
      ..previousPage();

    expect(harness.requests, [(1, 5), (2, 5)]);
  });

  test('a session failure clears the list and reconciles auth', () async {
    for (final (code, status) in [
      (ApiErrorCodes.authenticationRequired, 401),
      (ApiErrorCodes.passwordChangeRequired, 403),
      (ApiErrorCodes.userInactive, 403),
      (ApiErrorCodes.institutionInactive, 403),
    ]) {
      final harness = await _Harness.loaded();
      harness.controller.refresh();
      harness.pending.last.completeError(
        studentServerFailure(code, statusCode: status),
      );
      await flushStudentControllers();

      expect(
        harness.state.status,
        StudentFinishedBlitzLoadStatus.initial,
        reason: code,
      );
      expect(harness.state.page, isNull, reason: code);
      expect(
        harness.auth.bootstrapCalls,
        code == ApiErrorCodes.authenticationRequired ? 0 : 1,
        reason: code,
      );
    }
  });

  test('a completion from a previous session is dropped', () async {
    final harness = _Harness();
    await flushStudentControllers();
    final first = harness.pending.single;

    harness.auth.replaceUser(studentUser('student-b'));
    await flushStudentControllers();
    first.complete(_page(1, total: 1));
    await flushStudentControllers();
    expect(harness.state.page, isNull);

    harness.pending.last.complete(_page(1));
    await flushStudentControllers();
    expect(harness.requests, hasLength(2));
    expect(harness.state.page?.items, hasLength(5));
  });
}

class _Harness {
  _Harness() {
    repository.onFetchFinished = (page, perPage) {
      requests.add((page, perPage));
      final completer = Completer<StudentFinishedBlitzPage>();
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
      studentFinishedBlitzControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
  }

  static Future<_Harness> loaded() async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pending.single.complete(_page(1));
    await flushStudentControllers();
    return harness;
  }

  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  final repository = FakeStudentBlitzRepository();
  final pending = <Completer<StudentFinishedBlitzPage>>[];
  final requests = <(int, int)>[];
  late final ProviderContainer container;
  late final ProviderSubscription<StudentFinishedBlitzState> subscription;

  StudentFinishedBlitzState get state => subscription.read();
  StudentFinishedBlitzController get controller =>
      container.read(studentFinishedBlitzControllerProvider.notifier);
}
