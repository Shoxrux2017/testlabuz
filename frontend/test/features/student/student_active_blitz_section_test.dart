import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/presentation/student_learning_workspace_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_read_view.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  testWidgets('Active Blitz sits above My Topics and loads independently', (
    tester,
  ) async {
    final pending = Completer<List<StudentActiveBlitzSummary>>();
    final harness = _Harness(onFetchActive: () => pending.future);
    await harness.pump(tester);

    expect(find.text('Loading active Blitz tasks'), findsOneWidget);
    expect(find.text('Internet Basics'), findsWidgets);
    expect(
      tester.getTopLeft(find.text('Active Blitz')).dy,
      lessThan(tester.getTopLeft(find.text('My Topics')).dy),
    );
    pending.complete(const []);
    await tester.pump();
    expect(
      find.text('No active Blitz tasks are available right now.'),
      findsOneWidget,
    );
    expect(harness.blitz.activeCalls, 1);
  });

  testWidgets('a failed Blitz list keeps Topics usable and retries', (
    tester,
  ) async {
    var fail = true;
    final harness = _Harness(
      onFetchActive: () async {
        if (fail) throw studentLocalFailure(ApiFailureKind.timeout);
        return [studentActiveBlitz()];
      },
    );
    await harness.pump(tester);

    expect(
      find.text('Active Blitz tasks could not be loaded.'),
      findsOneWidget,
    );
    expect(find.text('The active Blitz request timed out.'), findsOneWidget);
    expect(find.text('Internet Basics'), findsWidgets);
    expect(find.byKey(const Key('studentTopicListError')), findsNothing);
    fail = false;
    await tester.tap(find.byKey(const Key('studentActiveBlitzRetryButton')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Classroom Blitz'), findsOneWidget);
    expect(harness.blitz.activeCalls, 2);
  });

  testWidgets('a failed refresh keeps cards and marks them out of date', (
    tester,
  ) async {
    var fail = false;
    final harness = _Harness(
      onFetchActive: () async {
        if (fail) throw studentLocalFailure(ApiFailureKind.connection);
        return [studentActiveBlitz()];
      },
    );
    await harness.pump(tester);
    fail = true;
    await tester.tap(find.byKey(const Key('studentActiveBlitzRefreshButton')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Classroom Blitz'), findsOneWidget);
    expect(
      find.text('The active Blitz list may be out of date.'),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(
      find.byKey(const Key('studentActiveBlitzStaleRetryButton')),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.text('The active Blitz list may be out of date.'),
      findsNothing,
    );
  });

  testWidgets('cards show the attempt path and snapshot timing, no Questions', (
    tester,
  ) async {
    const ids = [
      'b1000000-0000-0000-0000-000000000011',
      'b1000000-0000-0000-0000-000000000012',
      'b1000000-0000-0000-0000-000000000013',
      'b1000000-0000-0000-0000-000000000014',
      'b1000000-0000-0000-0000-000000000015',
    ];
    final harness = _Harness(
      onFetchActive: () async => [
        studentActiveBlitz(id: ids[0], title: 'Synchronized new'),
        studentActiveBlitz(
          id: ids[1],
          title: 'Individual new',
          timing: studentBlitzTiming(
            mode: StudentBlitzTimerMode.individual,
            noDeadline: true,
          ),
        ),
        studentActiveBlitz(
          id: ids[2],
          title: 'Resumable',
          timing: studentBlitzTiming(remainingSeconds: 252),
          attempts: studentBlitzAttemptSummary(
            normalUsed: 1,
            inProgressAttemptId: studentBlitzAttemptId,
          ),
        ),
        studentActiveBlitz(
          id: ids[3],
          title: 'Replacement ready',
          timing: studentBlitzTiming(noDeadline: true),
          attempts: studentBlitzAttemptSummary(
            normalUsed: 1,
            exceptionGranted: true,
            replacementAvailable: true,
          ),
        ),
        studentActiveBlitz(
          id: ids[4],
          title: 'Replacement running',
          attempts: studentBlitzAttemptSummary(
            normalUsed: 1,
            inProgressAttemptId: studentBlitzReplacementAttemptId,
            exceptionGranted: true,
          ),
        ),
      ],
    );
    await harness.pump(tester);

    _expectCard(ids[0], [
      'Not started',
      'Shared class timer',
      'Duration: 10 min',
      'Class time remaining at last refresh: 5 min',
    ]);
    _expectCard(ids[1], [
      'Not started',
      'Individual timer',
      'Full 10 min starts when you start.',
    ]);
    _expectCard(ids[2], [
      'In progress',
      'Attempt time remaining at last refresh: 4 min 12 sec',
    ]);
    _expectCard(ids[3], [
      'Additional attempt available',
      'Full 10 min additional attempt starts when you start.',
    ]);
    _expectCard(ids[4], ['Additional attempt in progress']);
    expect(find.textContaining('second normal attempt'), findsNothing);
    expect(find.byType(StudentQuestionReadView), findsNothing);
    // Card merges child semantics, so assert the button's own label.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == 'Open Blitz Resumable',
      ),
      findsOneWidget,
    );
  });

  testWidgets('opening a card navigates to its canonical Blitz route only', (
    tester,
  ) async {
    final harness = _Harness(onFetchActive: () async => [studentActiveBlitz()]);
    await harness.pump(tester);
    final open = find.byKey(
      const ValueKey('studentActiveBlitzOpen$studentBlitzId'),
    );
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(
      harness.router.routeInformationProvider.value.uri.path,
      AppRoutePaths.studentBlitzDetailLocation(studentTopicId, studentBlitzId),
    );
    expect(find.text('Blitz route'), findsOneWidget);
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets('${surface.name} narrow layout wraps cards without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness(
        surface: surface,
        onFetchActive: () async => [
          studentActiveBlitz(
            title:
                'A very long Blitz title that must wrap on a narrow phone '
                'screen without any horizontal overflow at all',
          ),
        ],
      );
      await harness.pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('A very long Blitz title'), findsOneWidget);
    });
  }
}

void _expectCard(String id, List<String> texts) {
  final card = find.byKey(ValueKey('studentActiveBlitzCard$id'));
  expect(card, findsOneWidget);
  for (final text in texts) {
    expect(
      find.descendant(of: card, matching: find.text(text)),
      findsOneWidget,
      reason: text,
    );
  }
}

class _Harness {
  _Harness({
    required Future<List<StudentActiveBlitzSummary>> Function() onFetchActive,
    this.surface = AppDeviceSurface.desktop,
  }) : blitz = FakeStudentBlitzRepository(onFetchActive: onFetchActive);

  final FakeStudentBlitzRepository blitz;
  final AppDeviceSurface surface;
  late final GoRouter router;

  Future<void> pump(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: AppRoutePaths.student,
      routes: [
        GoRoute(
          path: AppRoutePaths.student,
          builder: (_, _) => const StudentLearningWorkspaceScreen(),
          routes: [
            GoRoute(
              path: 'topics/:topicId/blitz/:blitzId',
              builder: (_, _) => const Scaffold(body: Text('Blitz route')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith(
            () => FakeStudentAuthSessionController.authenticated(
              studentUser('student-a'),
            ),
          ),
          appDeviceSurfaceProvider.overrideWithValue(surface),
          studentTopicRepositoryProvider.overrideWithValue(
            FakeStudentTopicRepository(),
          ),
          studentBlitzRepositoryProvider.overrideWithValue(blitz),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
  }
}
