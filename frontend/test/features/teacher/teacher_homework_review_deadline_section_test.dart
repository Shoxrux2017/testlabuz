import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair_repository.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_detail_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
// 2026-09-20 18:30 in Asia/Tashkent.
final _existing = DateTime.utc(2026, 9, 20, 13, 30);

final _target = TeacherHomeworkRouteTarget(
  topicId: _topicId,
  homeworkId: _homeworkId,
);
const _section = Key('teacherHomeworkReviewDeadlineSection');
const _setButton = Key('teacherHomeworkReviewDeadlineSetButton');
const _clearButton = Key('teacherHomeworkReviewDeadlineClearButton');

void main() {
  testWidgets(
    'the summary shows the review deadline or Not set on every surface',
    (tester) async {
      for (final surface in [
        AppDeviceSurface.desktop,
        AppDeviceSurface.mobile,
      ]) {
        await _pump(
          tester,
          FakeTeacherHomeworkRepository(
            onFetch: (_) async => teacherHomework(reviewDueAt: _existing),
          ),
          surface: surface,
        );
        await tester.pumpAndSettle();
        expect(_summaryValue(tester), '2026-09-20 18:30', reason: surface.name);

        await _pump(tester, FakeTeacherHomeworkRepository(), surface: surface);
        await tester.pumpAndSettle();
        expect(_summaryValue(tester), 'Not set', reason: surface.name);
      }
    },
  );

  testWidgets(
    'the editing section appears only on desktop for draft, active and closed',
    (tester) async {
      for (final status in TeacherHomeworkStatus.values) {
        await _pump(
          tester,
          FakeTeacherHomeworkRepository(
            onFetch: (_) async => teacherHomework(status: status),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(_section),
          status == TeacherHomeworkStatus.archived
              ? findsNothing
              : findsOneWidget,
          reason: status.name,
        );
      }

      await _pump(
        tester,
        FakeTeacherHomeworkRepository(
          onFetch: (_) async =>
              teacherHomework(status: TeacherHomeworkStatus.closed),
        ),
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_section), findsNothing);
    },
  );

  testWidgets('without a deadline the section offers Set and no Clear', (
    tester,
  ) async {
    await _pump(tester, FakeTeacherHomeworkRepository());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_section));

    expect(find.text('No review deadline.'), findsOneWidget);
    expect(
      find.text(
        'A reminder for checking submissions. It never changes scores.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Set review deadline'),
      findsOneWidget,
    );
    expect(find.byKey(_clearButton), findsNothing);
  });

  testWidgets('changing the deadline sends the picked Institution-local time', (
    tester,
  ) async {
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (_) async => teacherHomework(
        status: TeacherHomeworkStatus.closed,
        reviewDueAt: _existing,
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_section));
    expect(
      find.descendant(
        of: find.byKey(_section),
        matching: find.text('2026-09-20 18:30'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, 'Change review deadline'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('21'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      repository.reviewDueAtRequests.single.request.reviewDueAtSerialized,
      '2026-09-21T18:30:00+05:00',
    );
    expect(find.text('Review deadline saved.'), findsOneWidget);
    expect(_summaryValue(tester), '2026-09-21 18:30');
  });

  testWidgets('a stored deadline after 2100 still opens the picker', (
    tester,
  ) async {
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (_) async =>
          teacherHomework(reviewDueAt: DateTime.utc(2150, 1, 2, 10)),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_section));

    await tester.tap(find.byKey(_setButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('cancelling either picker sends nothing', (tester) async {
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (_) async => teacherHomework(reviewDueAt: _existing),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_section));

    await tester.tap(find.byKey(_setButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_setButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.reviewDueAtRequests, isEmpty);
  });

  testWidgets('Clear sends null and hides itself', (tester) async {
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (_) async => teacherHomework(reviewDueAt: _existing),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_section));

    await tester.tap(find.byKey(_clearButton));
    await tester.pumpAndSettle();

    expect(
      repository.reviewDueAtRequests.single.request.reviewDueAtSerialized,
      isNull,
    );
    expect(find.text('Review deadline cleared.'), findsOneWidget);
    expect(find.byKey(_clearButton), findsNothing);
    expect(_summaryValue(tester), 'Not set');
  });

  testWidgets(
    'the buttons are disabled while a Homework mutation holds the lease',
    (tester) async {
      final pending = Completer<TeacherHomework>();
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => teacherHomework(reviewDueAt: _existing),
        onSetReviewDueAt: (_, _) => pending.future,
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_section));

      await tester.tap(find.byKey(_clearButton));
      await tester.pump();

      expect(
        find.byKey(const Key('teacherHomeworkReviewDeadlineProgress')),
        findsOneWidget,
      );
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(_setButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(_clearButton)).onPressed,
        isNull,
      );

      pending.complete(teacherHomework());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('teacherHomeworkReviewDeadlineProgress')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the buttons are disabled while another Homework mutation holds the lease',
    (tester) async {
      await _pump(
        tester,
        FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(reviewDueAt: _existing),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_section));
      final activity = ProviderScope.containerOf(
        tester.element(find.byType(TeacherHomeworkDetailScreen)),
      ).read(teacherHomeworkRouteMutationActivityProvider(_target).notifier);

      final lease = activity.begin(
        TeacherHomeworkRouteMutationOperation.lifecycle,
      );
      await tester.pump();

      expect(lease, isNotNull);
      expect(
        find.byKey(const Key('teacherHomeworkReviewDeadlineProgress')),
        findsNothing,
      );
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(_setButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(_clearButton)).onPressed,
        isNull,
      );

      activity.release(lease!);
      await tester.pump();
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(_setButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'a local time that does not exist is explained and nothing is sent',
    (tester) async {
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => teacherHomework(
          institutionTimezone: 'Europe/Berlin',
          // 2026-03-28 02:30 in Berlin; the next day skips 02:00-03:00.
          reviewDueAt: DateTime.utc(2026, 3, 28, 1, 30),
        ),
        onSetReviewDueAt: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.rateLimited,
          statusCode: 429,
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_section));
      // An earlier failure must not hide the new local message.
      await tester.tap(find.byKey(_clearButton));
      await tester.pumpAndSettle();
      repository.reviewDueAtRequests.clear();

      await tester.tap(find.byKey(_setButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('29'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repository.reviewDueAtRequests, isEmpty);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('teacherHomeworkReviewDeadlineFeedback')),
            )
            .data,
        'This local time does not exist in the Institution timezone.',
      );
    },
  );

  testWidgets(
    'an archived-Homework conflict is announced after the section closes',
    (tester) async {
      var fetches = 0;
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetches += 1;
          return teacherHomework(
            reviewDueAt: _existing,
            status: fetches == 1
                ? TeacherHomeworkStatus.closed
                : TeacherHomeworkStatus.archived,
          );
        },
        onSetReviewDueAt: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.taskArchived,
          statusCode: 409,
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_section));

      await tester.tap(find.byKey(_clearButton));
      await tester.pumpAndSettle();

      expect(find.byKey(_section), findsNothing);
      expect(
        find.text(
          'This Homework is archived. Its review deadline can no longer be changed.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an archived conflict whose refresh fails is explained once, inline',
    (tester) async {
      var fetches = 0;
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetches += 1;
          if (fetches > 1) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return teacherHomework(
            reviewDueAt: _existing,
            status: TeacherHomeworkStatus.closed,
          );
        },
        onSetReviewDueAt: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.taskArchived,
          statusCode: 409,
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_section));

      await tester.tap(find.byKey(_clearButton));
      await tester.pumpAndSettle();

      const message =
          'This Homework is archived. Its review deadline can no longer be '
          'changed.';
      expect(find.byKey(_section), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('a stale detail hides the section', (tester) async {
    var fetches = 0;
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (_) async {
        fetches += 1;
        if (fetches == 2) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return teacherHomework(reviewDueAt: _existing);
      },
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(_section), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('teacherHomeworkDetailRefreshButton')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkDetailStaleMessage')),
      findsOneWidget,
    );
    expect(find.byKey(_section), findsNothing);
    expect(_summaryValue(tester), '2026-09-20 18:30');
  });

  testWidgets('a definite failure is explained in the section', (tester) async {
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (_) async =>
          teacherHomework(status: TeacherHomeworkStatus.closed),
      onSetReviewDueAt: (_, _) async => throw teacherServerFailure(
        ApiErrorCodes.topicNotEditable,
        statusCode: 409,
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_section));

    await tester.tap(find.byKey(_setButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('teacherHomeworkReviewDeadlineFeedback')),
          )
          .data,
      'The Topic is closed or archived. The review deadline can no longer be changed.',
    );
  });

  testWidgets('an unconfirmed outcome offers Check current Homework', (
    tester,
  ) async {
    var fetches = 0;
    final repository = FakeTeacherHomeworkRepository(
      onFetch: (_) async {
        fetches += 1;
        if (fetches == 2) {
          throw teacherLocalFailure(ApiFailureKind.timeout);
        }
        return teacherHomework(reviewDueAt: fetches == 1 ? _existing : null);
      },
      onSetReviewDueAt: (_, _) async =>
          throw const TeacherHomeworkMutationOutcomeUnknownException(),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_section));

    await tester.tap(find.byKey(_clearButton));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('teacherHomeworkReviewDeadlineFeedback')),
          )
          .data,
      'The review deadline change could not be confirmed.\nReview the current Homework before trying again.',
    );
    await tester.tap(
      find.byKey(const Key('teacherHomeworkReviewDeadlineCheckCurrentButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review deadline cleared.'), findsOneWidget);
    expect(
      find.byKey(const Key('teacherHomeworkReviewDeadlineCheckCurrentButton')),
      findsNothing,
    );
  });
}

/// The value under the `Review deadline` label in the Summary card.
String? _summaryValue(WidgetTester tester) {
  final summary = find
      .ancestor(of: find.text('Summary'), matching: find.byType(Card))
      .first;
  final texts = tester
      .widgetList(
        find.descendant(
          of: summary,
          matching: find.byWidgetPredicate(
            (widget) => widget is Text || widget is SelectableText,
          ),
        ),
      )
      .map(
        (widget) =>
            widget is Text ? widget.data : (widget as SelectableText).data,
      )
      .toList();
  return texts[texts.indexOf('Review deadline') + 1];
}

Future<void> _pump(
  WidgetTester tester,
  FakeTeacherHomeworkRepository repository, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          _NoPairRepository(),
        ),
      ],
      child: const MaterialApp(
        home: TeacherHomeworkDetailScreen(
          topicId: _topicId,
          homeworkId: _homeworkId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _NoPairRepository implements TeacherTopicResultPairRepository {
  @override
  Future<TeacherTopicResultPair?> fetchResultPair(String topicId) async => null;

  @override
  Future<TeacherTopicResultPair> setOfficialHomework(
    String topicId,
    String homeworkId,
  ) {
    throw UnimplementedError(
      'Official selection is outside review deadline tests.',
    );
  }

  @override
  Future<TeacherTopicResultPair> setOfficialBlitz(
    String topicId, {
    required String homeworkId,
    required String blitzId,
  }) {
    throw UnimplementedError(
      'Official selection is outside review deadline tests.',
    );
  }
}
