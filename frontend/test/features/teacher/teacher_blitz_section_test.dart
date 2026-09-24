import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_section.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_detail_screen.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _secondBlitzId = '80000000-0000-0000-0000-000000000002';

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets('${surface.name} Topic detail shows Blitz after Homework', (
      tester,
    ) async {
      if (surface == AppDeviceSurface.mobile) {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }
      final blitz = FakeTeacherBlitzRepository(
        onFetchList: (_, query) async => _list([teacherBlitzSummary()]),
      );
      await _pumpTopicDetail(tester, blitz: blitz, surface: surface);
      await tester.pumpAndSettle();

      final homework = find.byKey(const Key('teacherHomeworkSection'));
      final section = find.byKey(const Key('teacherBlitzSection'));
      expect(homework, findsOneWidget);
      expect(section, findsOneWidget);
      expect(
        tester.getTopLeft(homework).dy,
        lessThan(tester.getTopLeft(section).dy),
      );
      expect(blitz.listRequests.single.topicId, _topicId);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('initial loading and empty Topic states are intentional', (
    tester,
  ) async {
    final pending = Completer<TeacherBlitzList>();
    await _pumpSection(
      tester,
      FakeTeacherBlitzRepository(onFetchList: (_, _) => pending.future),
    );

    expect(find.byKey(const Key('teacherBlitzLoading')), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(const Key('teacherBlitzLoading')),
          )
          .semanticsLabel,
      'Loading Blitz',
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('teacherBlitzRefreshButton')),
          )
          .onPressed,
      isNull,
    );

    pending.complete(_list(const []));
    await tester.pumpAndSettle();

    expect(
      find.text('No Blitz has been created for this Topic yet.'),
      findsOneWidget,
    );
    expect(find.textContaining('Create'), findsNothing);
    expect(find.text('Page 1 of 1'), findsOneWidget);
  });

  testWidgets('initial error offers Retry and then shows loaded cards', (
    tester,
  ) async {
    var calls = 0;
    final repository = FakeTeacherBlitzRepository(
      onFetchList: (_, _) async {
        calls += 1;
        if (calls == 1) {
          throw teacherLocalFailure(ApiFailureKind.connection);
        }
        return _list([teacherBlitzSummary()]);
      },
    );
    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Blitz could not be loaded.'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);

    await tester.tap(find.byKey(const Key('teacherBlitzRetryButton')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Equation Blitz'), findsOneWidget);
    expect(find.text('Blitz could not be loaded.'), findsNothing);
  });

  testWidgets('refresh retains cards and a failure marks them stale', (
    tester,
  ) async {
    final refresh = Completer<TeacherBlitzList>();
    var calls = 0;
    final repository = FakeTeacherBlitzRepository(
      onFetchList: (_, _) {
        calls += 1;
        return calls == 1
            ? Future.value(_list([teacherBlitzSummary()]))
            : refresh.future;
      },
    );
    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherBlitzRefreshButton')));
    await tester.pump();

    expect(find.byKey(const Key('teacherBlitzRefreshing')), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('teacherBlitzRefreshing')),
          )
          .semanticsLabel,
      'Refreshing Blitz',
    );
    expect(find.text('Equation Blitz'), findsOneWidget);

    refresh.completeError(teacherLocalFailure(ApiFailureKind.timeout));
    await tester.pumpAndSettle();

    expect(
      find.text('The displayed Blitz list may be out of date.'),
      findsOneWidget,
    );
    expect(find.text('Equation Blitz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherBlitzStaleRetryButton')));
    await tester.pumpAndSettle();
    expect(calls, 3);
  });

  testWidgets('status filter offers exact options and reloads page one', (
    tester,
  ) async {
    final repository = FakeTeacherBlitzRepository(
      onFetchList: (_, query) async => _list(
        const [],
        page: query.page,
        total: query.status == null ? 45 : 0,
      ),
    );
    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('teacherBlitzStatusFilter')),
        matching: find.byType(DropdownButton<TeacherBlitzStatus?>),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in [
      'All statuses',
      'Draft',
      'Scheduled',
      'Active',
      'Closed',
      'Archived',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Scheduled').last);
    await tester.pumpAndSettle();

    expect(
      repository.listRequests.last.query.status,
      TeacherBlitzStatus.scheduled,
    );
    expect(repository.listRequests.last.query.page, 1);
    expect(repository.listRequests.last.topicId, _topicId);
    expect(
      find.text('No Blitz matches the current status filter.'),
      findsOneWidget,
    );
  });

  testWidgets('cards show read metadata and expose an actionable label', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      FakeTeacherBlitzRepository(
        onFetchList: (_, _) async => _list([
          teacherBlitzSummary(durationSeconds: 90),
          teacherBlitzSummary(
            id: _secondBlitzId,
            title: 'Scheduled selected Blitz',
            status: TeacherBlitzStatus.scheduled,
            assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
            totalPossiblePoints: 7.5,
            questionCount: 4,
            durationSeconds: 3661,
            scheduledAt: DateTime.utc(2026, 9, 18, 4),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Equation Blitz'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Whole group'), findsOneWidget);
    expect(find.text('Questions: 3'), findsOneWidget);
    expect(find.text('Total points: 12'), findsOneWidget);
    expect(find.text('Duration: 1 min 30 sec'), findsOneWidget);
    expect(find.text('Scheduled time: Not scheduled'), findsOneWidget);

    expect(find.text('Scheduled selected Blitz'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Selected students'), findsOneWidget);
    expect(find.text('Questions: 4'), findsOneWidget);
    expect(find.text('Total points: 7.5'), findsOneWidget);
    expect(find.text('Duration: 1 hr 1 min 1 sec'), findsOneWidget);
    expect(find.text('Scheduled time: 2026-09-18 09:00'), findsOneWidget);

    expect(find.bySemanticsLabel('Open Blitz Equation Blitz'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Open Blitz Scheduled selected Blitz'),
      findsOneWidget,
    );
  });

  testWidgets('pagination moves between confirmed server pages', (
    tester,
  ) async {
    final repository = FakeTeacherBlitzRepository(
      onFetchList: (_, query) async => _list(
        [teacherBlitzSummary(title: 'Page ${query.page} Blitz')],
        page: query.page,
        total: 41,
      ),
    );
    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(_button(tester, 'Previous').onPressed, isNull);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(repository.listRequests.last.query.page, 2);
    expect(find.text('Page 2 Blitz'), findsOneWidget);
    expect(find.text('Page 2 of 3'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(repository.listRequests.last.query.page, 1);
  });

  testWidgets('no create, edit, lifecycle, exception, or monitor controls', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      FakeTeacherBlitzRepository(
        onFetchList: (_, _) async =>
            _list([teacherBlitzSummary(status: TeacherBlitzStatus.active)]),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Create Blitz',
      'Create',
      'Edit',
      'Schedule',
      'Activate',
      'Close',
      'Archive',
      'Monitor',
      'Monitoring',
      'Grant exception',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Official chip requires a confirmed exact pair Blitz ID', (
    tester,
  ) async {
    final cases =
        <({Future<TeacherTopicResultPair?> Function() pair, bool official})>[
          (
            pair: () async =>
                teacherResultPair(blitzAssessmentId: _blitzId.toUpperCase()),
            official: true,
          ),
          (
            pair: () async =>
                teacherResultPair(blitzAssessmentId: _secondBlitzId),
            official: false,
          ),
          (pair: () async => teacherResultPair(), official: false),
          (pair: () async => null, official: false),
          (
            pair: () async =>
                throw teacherLocalFailure(ApiFailureKind.connection),
            official: false,
          ),
          (
            pair: () => Completer<TeacherTopicResultPair?>().future,
            official: false,
          ),
        ];
    for (final testCase in cases) {
      await _pumpSection(
        tester,
        FakeTeacherBlitzRepository(
          onFetchList: (_, _) async => _list([teacherBlitzSummary()]),
        ),
        pairs: FakeTeacherTopicResultPairRepository(
          onFetch: (_) => testCase.pair(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Equation Blitz'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('teacherBlitzOfficial$_blitzId')),
        testCase.official ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Official'),
        testCase.official ? findsOneWidget : findsNothing,
      );
      expect(find.text('Practice'), findsNothing);
    }
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets('long card content fits a ${width.toInt()}px surface', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final longTitle = List.filled(
        12,
        'long responsive Blitz title',
      ).join(' ');
      await _pumpSection(
        tester,
        FakeTeacherBlitzRepository(
          onFetchList: (_, _) async => _list([
            teacherBlitzSummary(
              title: longTitle,
              durationSeconds: 3661,
              assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
              status: TeacherBlitzStatus.archived,
            ),
          ]),
        ),
        pairs: FakeTeacherTopicResultPairRepository(
          onFetch: (_) async => teacherResultPair(blitzAssessmentId: _blitzId),
        ),
        surface: width < 600
            ? AppDeviceSurface.mobile
            : AppDeviceSurface.desktop,
        textScaler: const TextScaler.linear(1.5),
      );
      await tester.pumpAndSettle();

      expect(find.text(longTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

TeacherBlitzList _list(
  List<TeacherBlitzSummary> items, {
  int page = 1,
  int? total,
}) {
  final resolvedTotal = total ?? items.length;
  return teacherBlitzList(
    items: items,
    page: page,
    total: resolvedTotal,
    lastPage: resolvedTotal == 0 ? 1 : (resolvedTotal + 19) ~/ 20,
  );
}

OutlinedButton _button(WidgetTester tester, String label) {
  return tester.widget<OutlinedButton>(
    find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton)),
  );
}

Future<void> _pumpSection(
  WidgetTester tester,
  FakeTeacherBlitzRepository repository, {
  FakeTeacherTopicResultPairRepository? pairs,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  TextScaler textScaler = TextScaler.noScaling,
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
        teacherBlitzRepositoryProvider.overrideWithValue(repository),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          pairs ?? FakeTeacherTopicResultPairRepository(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: TeacherBlitzSection(topicId: _topicId),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpTopicDetail(
  WidgetTester tester, {
  required FakeTeacherBlitzRepository blitz,
  required AppDeviceSurface surface,
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
        teacherTopicRepositoryProvider.overrideWithValue(
          FakeTeacherTopicRepository(),
        ),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(
          FakeTeacherLearningMaterialRepository(),
        ),
        teacherHomeworkRepositoryProvider.overrideWithValue(
          FakeTeacherHomeworkRepository(),
        ),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          FakeTeacherTopicResultPairRepository(),
        ),
        teacherBlitzRepositoryProvider.overrideWithValue(blitz),
      ],
      child: const MaterialApp(
        home: TeacherTopicDetailScreen(topicId: _topicId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
