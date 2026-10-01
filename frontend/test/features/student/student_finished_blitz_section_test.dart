import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/data/dto/student_finished_blitz_dto.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_finished_blitz.dart';
import 'package:testlabuz_client/features/student/presentation/student_learning_workspace_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_topic_formatters.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

const _hiddenId = 'b1000000-0000-0000-0000-000000000002';
const _replacementId = 'b1000000-0000-0000-0000-000000000003';
const _noReplacementId = 'b1000000-0000-0000-0000-000000000004';
const _neverStartedId = 'b1000000-0000-0000-0000-000000000005';

StudentFinishedBlitzPage _page(
  List<Map<String, Object?>> items, {
  int page = 1,
  int? total,
}) => StudentFinishedBlitzPageDto.fromJson(
  finishedBlitzPageJson(items, page: page, total: total),
  page: page,
  perPage: 5,
).toDomain();

/// Every result shape; 1.45 is stored just below 1.45, so only S09-T3
/// rounding shows 1.5.
StudentFinishedBlitzPage _shapes() => _page([
  finishedBlitzJson(
    result: finishedResultJson(
      normalized: 1.45,
      feedback: [
        {
          'question_id': finishedQuestionId,
          'position': 3,
          'text': 'Good explanation.',
        },
        {
          'question_id': 'b3000000-0000-0000-0000-000000000002',
          'position': 5,
          'text': 'Check the units.',
        },
      ],
    ),
  ),
  finishedBlitzJson(
    id: _hiddenId,
    status: 'archived',
    result: finishedResultJson(visible: false),
  ),
  finishedBlitzJson(id: _replacementId, attemptException: true),
  finishedBlitzJson(id: _noReplacementId, attemptException: true, result: null),
  finishedBlitzJson(id: _neverStartedId, result: null),
]);

Finder _inCard(String id, String text) => find.descendant(
  of: find.byKey(ValueKey('studentFinishedBlitzCard$id')),
  matching: find.text(text),
);

void main() {
  testWidgets('Finished Blitz sits between Active Blitz and My Topics', (
    tester,
  ) async {
    final pending = Completer<StudentFinishedBlitzPage>();
    final harness = _Harness(onFetchFinished: (_, _) => pending.future);
    await harness.pump(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('studentFinishedBlitzLoading')),
        matching: find.text('Loading finished Blitz tasks'),
        matchRoot: true,
      ),
      findsOneWidget,
    );
    final heading = find.text('Finished Blitz');
    expect(
      tester.getTopLeft(heading).dy,
      greaterThan(tester.getTopLeft(find.text('Active Blitz')).dy),
    );
    expect(
      tester.getTopLeft(heading).dy,
      lessThan(tester.getTopLeft(find.text('My Topics')).dy),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.header ?? false) &&
            widget.child is Text &&
            (widget.child! as Text).data == 'Finished Blitz',
      ),
      findsOneWidget,
    );
    expect(harness.blitz.finishedPages, [1]);

    pending.complete(_page(const []));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('studentFinishedBlitzEmpty')),
        matching: find.text('No finished Blitz tasks yet.'),
        matchRoot: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('each card shows its result, exception and feedback', (
    tester,
  ) async {
    final harness = _Harness(onFetchFinished: (_, _) async => _shapes());
    await harness.pump(tester);
    final closed =
        'Closed ${formatStudentInstitutionInstant(DateTime.utc(2026, 9, 30, 10), 'Asia/Tashkent')}';

    for (final (id, lines) in [
      (studentBlitzId, ['Classroom Blitz', 'Topic: Internet Basics', closed]),
      (_hiddenId, ['Archived', 'Result not available yet']),
      (_replacementId, ['Attempt 1 was invalidated.']),
      (
        _noReplacementId,
        ['Attempt 1 was invalidated.', 'No replacement attempt was taken.'],
      ),
      (_neverStartedId, ['No attempt counts for this Blitz.']),
    ]) {
      await tester.ensureVisible(
        find.byKey(ValueKey('studentFinishedBlitzCard$id')),
      );
      for (final line in lines) {
        expect(_inCard(id, line), findsOneWidget, reason: '$id $line');
      }
    }
    for (final (id, line) in [
      (studentBlitzId, 'Score 1.5'),
      (_hiddenId, 'Result not available yet'),
      (_replacementId, 'Score 82.0'),
      (_noReplacementId, 'No replacement attempt was taken.'),
      (_neverStartedId, 'No attempt counts for this Blitz.'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('studentFinishedBlitzResult$id')),
          matching: find.text(line),
        ),
        findsOneWidget,
        reason: id,
      );
    }
    expect(
      _inCard(_neverStartedId, 'Attempt 1 was invalidated.'),
      findsNothing,
    );
    expect(_inCard(_hiddenId, 'Teacher feedback'), findsNothing);

    final feedback = find.byKey(
      const ValueKey('studentFinishedBlitzFeedback$studentBlitzId'),
    );
    await tester.ensureVisible(feedback);
    expect(
      find.descendant(of: feedback, matching: find.text('Teacher feedback')),
      findsOneWidget,
    );
    for (final line in [
      'Question 3: Good explanation.',
      'Question 5: Check the units.',
    ]) {
      expect(
        find.descendant(
          of: feedback,
          matching: find.widgetWithText(SelectableText, line),
        ),
        findsOneWidget,
      );
    }
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: feedback,
              matching: find.text('Question 3: Good explanation.'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: feedback,
                matching: find.text('Question 5: Check the units.'),
              ),
            )
            .dy,
      ),
    );
    // Only the two released results carry feedback.
    expect(find.text('Teacher feedback'), findsNWidgets(2));
    // A finished Blitz cannot be opened, so its card has no button.
    for (final id in [
      studentBlitzId,
      _hiddenId,
      _replacementId,
      _noReplacementId,
      _neverStartedId,
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('studentFinishedBlitzCard$id')),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        ),
        findsNothing,
        reason: id,
      );
    }
  });

  testWidgets('an initial failure explains itself and retries', (tester) async {
    var fail = true;
    final harness = _Harness(
      onFetchFinished: (_, _) async {
        if (fail) throw studentLocalFailure(ApiFailureKind.timeout);
        return _shapes();
      },
    );
    await harness.pump(tester);

    expect(
      find.text('Finished Blitz tasks could not be loaded.'),
      findsOneWidget,
    );
    expect(find.text('The finished Blitz request timed out.'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);

    fail = false;
    await tester.ensureVisible(
      find.byKey(const Key('studentFinishedBlitzRetryButton')),
    );
    await tester.tap(find.byKey(const Key('studentFinishedBlitzRetryButton')));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(ValueKey('studentFinishedBlitzCard$studentBlitzId')),
      findsOneWidget,
    );
  });

  testWidgets('every failure has its own message', (tester) async {
    for (final (kind, message) in [
      (ApiFailureKind.connection, 'Could not reach the server.'),
      (
        ApiFailureKind.invalidResponse,
        'The server returned an unexpected finished Blitz response.',
      ),
      (ApiFailureKind.unknown, 'Try again.'),
    ]) {
      final harness = _Harness(
        onFetchFinished: (_, _) async => throw studentLocalFailure(kind),
      );
      await harness.pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('studentFinishedBlitzSection')),
          matching: find.text(message),
        ),
        findsOneWidget,
        reason: kind.name,
      );
    }
  });

  testWidgets('a failed refresh keeps the cards and marks them stale', (
    tester,
  ) async {
    var calls = 0;
    final refresh = Completer<StudentFinishedBlitzPage>();
    final harness = _Harness(
      onFetchFinished: (_, _) =>
          ++calls == 1 ? Future.value(_shapes()) : refresh.future,
    );
    await harness.pump(tester);
    final button = find.byKey(const Key('studentFinishedBlitzRefreshButton'));
    await tester.ensureVisible(button);

    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('studentFinishedBlitzRefreshing')),
          )
          .semanticsLabel,
      'Refreshing finished Blitz tasks',
    );
    refresh.completeError(studentLocalFailure(ApiFailureKind.connection));
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('studentFinishedBlitzStale')),
        matching: find.text('The finished Blitz list may be out of date.'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('studentFinishedBlitzCard$studentBlitzId')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('studentFinishedBlitzStaleRetryButton')),
    );
    await tester.pump();
    expect(calls, 3);
  });

  testWidgets('a close time without a usable time zone says so', (
    tester,
  ) async {
    final harness = _Harness(
      timezone: 'Not/AZone',
      onFetchFinished: (_, _) async => _page([finishedBlitzJson()]),
    );
    await harness.pump(tester);

    expect(
      _inCard(studentBlitzId, 'Closed Institution timezone unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('pages move with Previous and Next', (tester) async {
    final harness = _Harness(
      onFetchFinished: (page, _) async => page == 1
          ? _page([finishedBlitzJson()], total: 6)
          : _page([finishedBlitzJson(id: _hiddenId)], page: 2, total: 6),
    );
    await harness.pump(tester);
    final previous = find.byKey(
      const Key('studentFinishedBlitzPreviousButton'),
    );
    final next = find.byKey(const Key('studentFinishedBlitzNextButton'));
    await tester.ensureVisible(next);

    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(previous).onPressed, isNull);

    await tester.tap(next);
    await tester.pump();
    await tester.pump();

    expect(harness.blitz.finishedPages, [1, 2]);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(
      find.byKey(ValueKey('studentFinishedBlitzCard$_hiddenId')),
      findsOneWidget,
    );
    expect(tester.widget<ButtonStyleButton>(next).onPressed, isNull);

    await tester.tap(previous);
    await tester.pump();
    await tester.pump();
    expect(harness.blitz.finishedPages, [1, 2, 1]);
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets('${surface.name} narrow layout wraps without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness(
        surface: surface,
        onFetchFinished: (_, _) async => _page([
          finishedBlitzJson(
            title:
                'A very long finished Blitz title that must wrap on a '
                'narrow phone screen without any horizontal overflow',
            result: finishedResultJson(
              feedback: [
                {
                  'question_id': finishedQuestionId,
                  'position': 1,
                  'text':
                      'A long piece of feedback that also has to wrap '
                      'cleanly on a narrow phone screen.',
                },
              ],
            ),
          ),
        ]),
      );
      await harness.pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('A very long finished Blitz'), findsOneWidget);
    });
  }
}

class _Harness {
  _Harness({
    required Future<StudentFinishedBlitzPage> Function(int page, int perPage)
    onFetchFinished,
    this.surface = AppDeviceSurface.desktop,
    this.timezone = 'Asia/Tashkent',
  }) : blitz = FakeStudentBlitzRepository(onFetchFinished: onFetchFinished);

  final FakeStudentBlitzRepository blitz;
  final AppDeviceSurface surface;
  final String timezone;

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutePaths.student,
      routes: [
        GoRoute(
          path: AppRoutePaths.student,
          builder: (_, _) => const StudentLearningWorkspaceScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          authSessionControllerProvider.overrideWith(
            () => FakeStudentAuthSessionController.authenticated(
              studentUser('student-a', institutionTimezone: timezone),
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
