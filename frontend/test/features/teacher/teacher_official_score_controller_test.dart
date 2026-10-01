import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_official_score_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_official_score_state.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_official_score_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_official_score.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';

import 'teacher_submission_test_support.dart';
import 'teacher_test_support.dart';

final _target = TeacherOfficialScoreTarget(
  assessmentId: officialAssessmentId,
  studentId: officialStudentId,
  type: TeacherSubmissionTaskType.homework,
);

TeacherOfficialScore _score([Map<String, Object?>? json]) =>
    TeacherOfficialScoreDto.fromJson(json ?? officialScoreJson()).toDomain();

ApiRequestException _failure(int status, String code) => ApiRequestException(
  ApiFailure(
    kind: ApiFailureKind.server,
    message: 'Failure.',
    statusCode: status,
    serverCode: code,
  ),
);

ApiRequestException _timeout() => ApiRequestException(
  ApiFailure.local(kind: ApiFailureKind.timeout, message: 'Timeout.'),
);

void main() {
  test('loads the official score on build', () async {
    final harness = _Harness();
    final state = harness.listen();
    expect(state.read().status, TeacherOfficialScoreLoadStatus.loading);

    await flushTeacherControllers();

    expect(state.read().status, TeacherOfficialScoreLoadStatus.data);
    expect(state.read().score?.normalizedScore, 87.25);
    expect(harness.submissions.officialTargets, [_target]);
  });

  test('is inactive on mobile', () async {
    final harness = _Harness(surface: AppDeviceSurface.mobile);
    final state = harness.listen();
    await flushTeacherControllers();

    harness.controller.refresh();
    await flushTeacherControllers();

    expect(state.read().status, TeacherOfficialScoreLoadStatus.initial);
    expect(harness.submissions.officialTargets, isEmpty);
  });

  test('404 gives not found', () async {
    final harness = _Harness(
      onFetch: (_) =>
          Future.error(_failure(404, ApiErrorCodes.resourceNotFound)),
    );
    final state = harness.listen();
    await flushTeacherControllers();

    expect(state.read().status, TeacherOfficialScoreLoadStatus.notFound);
  });

  test('an error can be retried', () async {
    var calls = 0;
    final harness = _Harness(
      onFetch: (_) =>
          ++calls == 1 ? Future.error(_timeout()) : Future.value(_score()),
    );
    final state = harness.listen();
    await flushTeacherControllers();
    expect(state.read().status, TeacherOfficialScoreLoadStatus.error);
    expect(state.read().score, isNull);

    harness.controller.retry();
    await flushTeacherControllers();

    expect(state.read().status, TeacherOfficialScoreLoadStatus.data);
  });

  test('a failed refresh keeps the score as stale', () async {
    var calls = 0;
    final reload = Completer<TeacherOfficialScore>();
    final harness = _Harness(
      onFetch: (_) => ++calls == 1 ? Future.value(_score()) : reload.future,
    );
    final state = harness.listen();
    await flushTeacherControllers();

    harness.controller.refresh();
    await flushTeacherControllers();
    expect(state.read().status, TeacherOfficialScoreLoadStatus.refreshing);
    expect(state.read().score, isNotNull);
    reload.completeError(_timeout());
    await flushTeacherControllers();

    expect(state.read().status, TeacherOfficialScoreLoadStatus.error);
    expect(state.read().isStale, isTrue);
    expect(state.read().score?.normalizedScore, 87.25);
  });

  test('a refresh replaces a load in flight', () async {
    final first = Completer<TeacherOfficialScore>();
    var calls = 0;
    final harness = _Harness(
      onFetch: (_) => ++calls == 1 ? first.future : Future.value(_score()),
    );
    final state = harness.listen();
    await flushTeacherControllers();
    expect(state.read().status, TeacherOfficialScoreLoadStatus.loading);

    harness.controller.refresh();
    await flushTeacherControllers();
    first.complete(
      _score(officialScoreJson(status: 'waiting_for_teacher_review')),
    );
    await flushTeacherControllers();

    expect(harness.submissions.officialTargets, [_target, _target]);
    expect(state.read().status, TeacherOfficialScoreLoadStatus.data);
    expect(state.read().score?.status, TeacherOfficialScoreStatus.ready);
  });

  test('a refresh replaces the score', () async {
    var calls = 0;
    final harness = _Harness(
      onFetch: (_) async => ++calls == 1
          ? _score(officialScoreJson(status: 'waiting_for_teacher_review'))
          : _score(),
    );
    final state = harness.listen();
    await flushTeacherControllers();
    expect(
      state.read().score?.status,
      TeacherOfficialScoreStatus.waitingForTeacherReview,
    );

    harness.controller.refresh();
    await flushTeacherControllers();

    expect(state.read().score?.status, TeacherOfficialScoreStatus.ready);
    expect(state.read().isStale, isFalse);
  });

  test('a session failure clears the controller', () async {
    for (final code in [
      ApiErrorCodes.authenticationRequired,
      ApiErrorCodes.passwordChangeRequired,
      ApiErrorCodes.userInactive,
      ApiErrorCodes.institutionInactive,
    ]) {
      final harness = _Harness(
        onFetch: (_) => Future.error(
          _failure(
            code == ApiErrorCodes.authenticationRequired ? 401 : 403,
            code,
          ),
        ),
      );
      final state = harness.listen();
      await flushTeacherControllers();

      expect(
        state.read().status,
        TeacherOfficialScoreLoadStatus.initial,
        reason: code,
      );
      expect(
        harness.auth.bootstrapCalls,
        code == ApiErrorCodes.authenticationRequired ? 0 : 1,
        reason: code,
      );
    }
  });

  test('a load from a previous session is dropped', () async {
    final first = Completer<TeacherOfficialScore>();
    var calls = 0;
    final harness = _Harness(
      onFetch: (_) {
        calls += 1;
        return calls == 1 ? first.future : Future.value(_score());
      },
    );
    final state = harness.listen();
    await flushTeacherControllers();

    harness.auth.replaceUser(teacherUser('teacher-b'));
    await flushTeacherControllers();
    first.complete(_score(officialScoreJson(status: 'no_completed_attempt')));
    await flushTeacherControllers();

    expect(harness.submissions.officialTargets, [_target, _target]);
    expect(state.read().score?.status, TeacherOfficialScoreStatus.ready);
  });
}

class _Harness {
  _Harness({
    Future<TeacherOfficialScore> Function(TeacherOfficialScoreTarget target)?
    onFetch,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ),
       submissions = FakeTeacherSubmissionRepository()
         ..onFetchOfficialScore = onFetch {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherSubmissionRepositoryProvider.overrideWithValue(submissions),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherSubmissionRepository submissions;
  late final ProviderContainer container;

  ProviderSubscription<TeacherOfficialScoreState> listen() => container.listen(
    teacherOfficialScoreControllerProvider(_target),
    (_, _) {},
    fireImmediately: true,
  );

  TeacherOfficialScoreController get controller =>
      container.read(teacherOfficialScoreControllerProvider(_target).notifier);
}
