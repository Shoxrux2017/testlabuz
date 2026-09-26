import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_attempt_exception_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_attempt_exception_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_monitoring_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_monitoring_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';

import 'teacher_blitz_json_fixtures.dart';
import 'teacher_test_support.dart';

const monitoringTopicId = '10000000-0000-0000-0000-000000000001';
const monitoringOtherTopicId = '10000000-0000-0000-0000-000000000002';
const monitoringGrantKeyA = '3f1c2a4b-5d6e-4f70-8a9b-0c1d2e3f4a5b';
const monitoringGrantKeyB = '4a2d3b5c-6e7f-4081-9bac-1d2e3f4a5b6c';

final monitoringTarget = TeacherBlitzRouteTarget(
  topicId: monitoringTopicId,
  blitzId: blitzJsonId,
);

class MonitoringSequenceKeys implements IdempotencyKeyGenerator {
  final _keys = [monitoringGrantKeyA, monitoringGrantKeyB];
  var generated = 0;

  @override
  String generate() => _keys[generated++];
}

/// Drives the monitoring and grant controllers in the widget-test fake clock,
/// so a 5-second poll is a `pump`, never a real wait.
class MonitoringHarness {
  MonitoringHarness(
    this.tester, {
    AppDeviceSurface surface = AppDeviceSurface.desktop,
    Future<TeacherBlitz> Function(String blitzId)? onFetch,
  }) : repository = FakeTeacherBlitzRepository(
         onFetch:
             onFetch ??
             (id) async =>
                 teacherBlitz(id: id, status: TeacherBlitzStatus.active),
       ) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        teacherTestSurfaceProvider.overrideWith(
          () => TeacherTestSurfaceController(surface),
        ),
        appDeviceSurfaceProvider.overrideWith(
          (ref) => ref.watch(teacherTestSurfaceProvider),
        ),
        teacherBlitzRepositoryProvider.overrideWithValue(repository),
        idempotencyKeyGeneratorProvider.overrideWithValue(keys),
      ],
    );
  }

  final WidgetTester tester;
  final auth = FakeTeacherAuthSessionController.authenticated(
    teacherUser('teacher-a'),
  );
  final FakeTeacherBlitzRepository repository;
  final keys = MonitoringSequenceKeys();
  late final ProviderContainer container;

  TeacherBlitzMonitoringController get monitoring => container.read(
    teacherBlitzMonitoringControllerProvider(monitoringTarget).notifier,
  );

  TeacherBlitzMonitoringState get state => container.read(
    teacherBlitzMonitoringControllerProvider(monitoringTarget),
  );

  TeacherBlitzAttemptExceptionController get grant => container.read(
    teacherBlitzAttemptExceptionControllerProvider(monitoringTarget).notifier,
  );

  TeacherBlitzAttemptExceptionState get grantState => container.read(
    teacherBlitzAttemptExceptionControllerProvider(monitoringTarget),
  );

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    container.read(appDeviceSurfaceProvider),
  ).eligibleKey!;

  Future<void> start({bool enterRoute = true}) async {
    container
      ..listen(
        teacherBlitzMonitoringControllerProvider(monitoringTarget),
        (_, _) {},
        fireImmediately: true,
      )
      ..listen(
        teacherBlitzAttemptExceptionControllerProvider(monitoringTarget),
        (_, _) {},
        fireImmediately: true,
      );
    await settle();
    if (enterRoute) {
      monitoring.enterLiveRoute();
      await settle();
    }
  }

  /// Flushes microtasks and zero-length timers without advancing the poll.
  Future<void> settle() async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> tick() => tester.pump(const Duration(seconds: 5));

  void markDetailNotFound() {
    container
        .read(teacherBlitzDetailControllerProvider(monitoringTarget).notifier)
        .markNotFound(sessionKey);
  }

  void dispose() => container.dispose();
}

/// A widget test that always disposes its controllers, so no poll timer
/// outlives the test body.
void monitoringTest(
  String description,
  Future<void> Function(MonitoringHarness harness) body, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  Future<TeacherBlitz> Function(String blitzId)? onFetch,
}) {
  testWidgets(description, (tester) async {
    final harness = MonitoringHarness(
      tester,
      surface: surface,
      onFetch: onFetch,
    );
    try {
      await body(harness);
    } finally {
      harness.dispose();
    }
  });
}
