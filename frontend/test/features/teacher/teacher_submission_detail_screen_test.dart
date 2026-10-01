import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/files/local_file_actions.dart';
import 'package:testlabuz_client/core/files/protected_learning_material_transfer.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_submission_detail_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_detail.dart';

import 'teacher_submission_test_support.dart';
import 'teacher_test_support.dart';

final _detailPath = '/teacher/reviews/$submissionId';

void main() {
  test('the submission detail path is exact and desktop-approved', () {
    expect(
      AppRoutePaths.teacherSubmissionDetailLocation(submissionId),
      _detailPath,
    );
    expect(AppRouteNames.teacherSubmissionDetail, 'teacher-submission-detail');
    expect(AppRoutePaths.isTeacherSubmissionDetailPath(_detailPath), isTrue);
    expect(AppRoutePaths.isTeacherApprovedLocation(_detailPath), isTrue);
    for (final invalid in [
      '/teacher/reviews/not-a-uuid',
      '$_detailPath/',
      '$_detailPath/extra',
      '/teacher/reviews',
    ]) {
      expect(
        AppRoutePaths.isTeacherSubmissionDetailPath(invalid),
        isFalse,
        reason: invalid,
      );
    }
    expect(
      () => AppRoutePaths.teacherSubmissionDetailLocation('nope'),
      throwsArgumentError,
    );
  });

  testWidgets(
    'a queue row opens the submission and back keeps the queue page',
    (tester) async {
      final submissions = FakeTeacherSubmissionRepository(
        onFetch: (query) async => teacherSubmissionList(
          [teacherSubmission()],
          page: query.page,
          total: 30,
        ),
      );
      final harness = await _pumpApp(
        tester,
        location: '/teacher/reviews',
        submissions: submissions,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('teacherReviewQueueNextButton')));
      await tester.pumpAndSettle();
      expect(submissions.queries, hasLength(2));

      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('^Open submission of Aziza Karimova')),
        findsOneWidget,
      );
      semantics.dispose();
      await tester.tap(
        find.byKey(const Key('teacherReviewQueueRow:$submissionId')),
      );
      await tester.pumpAndSettle();

      expect(_routerPath(tester), _detailPath);
      expect(
        find.byKey(const Key('teacherSubmissionDetailScreen')),
        findsOneWidget,
      );
      expect(submissions.detailIds, [submissionId]);

      await tester.tap(find.byKey(const Key('teacherSubmissionBackButton')));
      await tester.pumpAndSettle();

      expect(_routerPath(tester), '/teacher/reviews');
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(submissions.queries, hasLength(2));
      expect(harness.local.saveCalls, 0);
    },
  );

  testWidgets('back from a submission returns to the task queue it came from', (
    tester,
  ) async {
    const homeworkId = '50000000-0000-0000-0000-000000000001';
    const topicId = '10000000-0000-0000-0000-000000000001';
    const taskQueue = '/teacher/topics/$topicId/homework/$homeworkId/reviews';
    await _pumpApp(tester, location: taskQueue);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('teacherReviewQueueRow:$submissionId')),
    );
    await tester.pumpAndSettle();
    expect(_routerPath(tester), _detailPath);

    await tester.tap(find.byKey(const Key('teacherSubmissionBackButton')));
    await tester.pumpAndSettle();

    expect(_routerPath(tester), taskQueue);
    expect(find.text('Submissions of this Homework'), findsOneWidget);
  });

  testWidgets('desktop entry, bootstrap, mobile and queries', (tester) async {
    await _pumpApp(tester, location: _detailPath);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherSubmissionDetailScreen')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('teacherSubmissionBackButton')));
    await tester.pumpAndSettle();
    expect(_routerPath(tester), '/teacher/reviews');

    final auth = FakeTeacherAuthSessionController(
      const AuthSessionState.bootstrapping(),
    );
    await _pumpApp(tester, location: _detailPath, auth: auth);
    await tester.pump();
    auth.replaceUser(teacherUser('teacher-a'));
    await tester.pumpAndSettle();
    expect(_routerPath(tester), _detailPath);

    for (final (location, surface) in [
      (_detailPath, AppDeviceSurface.mobile),
      ('$_detailPath?private=1', AppDeviceSurface.desktop),
      ('$_detailPath#fragment', AppDeviceSurface.desktop),
      ('/teacher/reviews/not-a-uuid', AppDeviceSurface.desktop),
    ]) {
      final submissions = FakeTeacherSubmissionRepository();
      await _pumpApp(
        tester,
        location: location,
        surface: surface,
        submissions: submissions,
      );
      await tester.pumpAndSettle();
      expect(_routerPath(tester), AppRoutePaths.teacher, reason: location);
      expect(submissions.detailIds, isEmpty);
    }
  });

  testWidgets('the header and every question type read correctly', (
    tester,
  ) async {
    await _pumpApp(tester, location: _detailPath);
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('teacherSubmissionHeader'));
    for (final text in [
      'Aziza Karimova',
      'Official',
      'Homework · Equation practice · Internet Basics · 7-A',
      'Attempt 2 · Waiting for review · Finalized 2026-09-30 15:00',
      'Submitted 2026-09-30 15:00',
      'Reviewed 1 of 2 answers · Review by 2026-10-02 18:00',
    ]) {
      expect(
        find.descendant(of: header, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }

    final expectations = <int, List<String>>{
      1: [
        'Question 1 · Single choice · 1 point',
        'Question 1 prompt',
        'Paris · Student answer · Correct',
        'Rome',
        'Checked automatically · 1 of 1 point',
      ],
      2: [
        'Question 2 · Multiple choice · 1 point',
        'TCP · Student answer · Correct',
        'UDP · Correct',
        'HTML',
        'Checked automatically · 0.5 of 1 point',
      ],
      3: [
        'Question 3 · True/False · 1 point',
        'Student answer: True',
        'Correct answer: False',
        'Checked automatically · 0 of 1 point',
      ],
      4: [
        'Question 4 · Short written · 1 point',
        'Student answer: dns',
        'Accepted answers: DNS, Domain Name System',
        'Checked automatically · 1 of 1 point',
      ],
      5: [
        'Question 5 · Open written · 3 points',
        'Student answer: An essay about DNS.',
        'Reviewed by Dilnoza Teacher · 2.5 of 3 points',
        'Feedback: Good start.',
      ],
      6: [
        'Question 6 · File based · 2 points',
        'report.pdf · PDF · 2.0 KiB',
        'Waiting for review',
      ],
      7: [
        'Question 7 · Matching · 2 points',
        'Student matches:',
        'HTTP → Mail',
        'Correct matches:',
        'HTTP → Web',
        'SMTP → Mail',
        'Checked automatically · 0 of 2 points',
      ],
      8: [
        'Question 8 · Ordering · 1 point',
        'Student order:',
        '1. Build',
        '2. Plan',
        'Correct order:',
        '1. Plan',
        '2. Build',
        'Checked automatically · 0 of 1 point',
      ],
      9: [
        'Question 9 · Fill in the blank · 1 point',
        'The {{proto}} protocol',
        'Student answers:',
        'proto: http',
        'Accepted answers:',
        'proto: HTTP',
        'Checked automatically · 1 of 1 point',
      ],
      10: ['Question 10 · Open written · 1 point', 'No answer.'],
    };
    for (final MapEntry(key: position, value: texts) in expectations.entries) {
      final card = find.byKey(
        Key('teacherSubmissionQuestion:${detailId(100 + position)}'),
      );
      await tester.ensureVisible(card);
      for (final text in texts) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsWidgets,
          reason: 'Q$position $text',
        );
      }
    }
  });

  testWidgets('pending answers and Student matches in the configured order', (
    tester,
  ) async {
    final questions = submissionDetailQuestions();
    for (final question in questions) {
      final answer = question['answer'] as Map<String, Object?>?;
      if (answer != null) {
        answer
          ..['checking_status'] = 'pending'
          ..['awarded_points'] = null
          ..['feedback'] = null
          ..['checked_by'] = null
          ..['checked_at'] = null;
      }
    }
    // Two Student pairs, listed against the configured left order.
    ((questions[6]['answer']! as Map<String, Object?>)['value']!
        as Map<String, Object?>)['pairs'] = [
      <String, Object?>{
        'left_item_id': detailId(14),
        'right_item_id': detailId(12),
      },
      <String, Object?>{
        'left_item_id': detailId(11),
        'right_item_id': detailId(15),
      },
    ];
    final detail = TeacherSubmissionDetailDto.fromJson(
      submissionDetailJson(
        questions: questions,
        status: 'submitted',
        waiting: 0,
        reviewed: 0,
      ),
    ).toDomain();
    await _pumpApp(
      tester,
      location: _detailPath,
      submissions: FakeTeacherSubmissionRepository()
        ..onFetchDetail = (_) async => detail,
    );
    await tester.pumpAndSettle();

    final first = find.byKey(Key('teacherSubmissionQuestion:${detailId(101)}'));
    expect(
      find.descendant(
        of: first,
        matching: find.text('Waiting for automatic checking'),
      ),
      findsOneWidget,
    );
    final matching = find.byKey(
      Key('teacherSubmissionQuestion:${detailId(107)}'),
    );
    await tester.ensureVisible(matching);
    final lines = tester
        .widgetList<Text>(
          find.descendant(of: matching, matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .toList();
    expect(
      lines.sublist(
        lines.indexOf('Student matches:') + 1,
        lines.indexOf('Correct matches:'),
      ),
      ['HTTP → Mail', 'SMTP → Web'],
    );
  });

  testWidgets('a submitted file is saved, with buttons disabled meanwhile', (
    tester,
  ) async {
    final release = Completer<ResponseBody>();
    final harness = await _pumpApp(
      tester,
      location: _detailPath,
      download: (_) => release.future,
    );
    await tester.pumpAndSettle();
    final button = find.byKey(
      const Key('teacherSubmissionFileSaveButton:$detailFileId'),
    );
    await tester.ensureVisible(button);

    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    expect(
      find.byKey(const Key('teacherSubmissionFileProgress')),
      findsOneWidget,
    );

    release.complete(_download());
    await tester.pumpAndSettle();

    expect(harness.local.saveCalls, 1);
    expect(find.text('File saved.'), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
  });

  testWidgets('a file failure is explained under the file', (tester) async {
    await _pumpApp(
      tester,
      location: _detailPath,
      download: (_) => ResponseBody.fromString(
        '{"message":"Safe.","code":"file_not_available","errors":{}}',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(
      const Key('teacherSubmissionFileSaveButton:$detailFileId'),
    );
    await tester.ensureVisible(button);

    await tester.tap(button);
    await tester.pumpAndSettle();

    final card = find.byKey(Key('teacherSubmissionQuestion:${detailId(106)}'));
    expect(
      find.descendant(
        of: card,
        matching: find.text('The file is temporarily unavailable. Try again.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('loading, not found, error with retry and stale states', (
    tester,
  ) async {
    final pending = Completer<TeacherSubmissionDetail>();
    await _pumpApp(
      tester,
      location: _detailPath,
      submissions: FakeTeacherSubmissionRepository()
        ..onFetchDetail = (_) => pending.future,
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const Key('teacherSubmissionDetailLoading')),
      findsOneWidget,
    );

    await _pumpApp(
      tester,
      location: _detailPath,
      submissions: FakeTeacherSubmissionRepository()
        ..onFetchDetail = (_) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This submission is not available.'), findsOneWidget);

    var calls = 0;
    await _pumpApp(
      tester,
      location: _detailPath,
      submissions: FakeTeacherSubmissionRepository()
        ..onFetchDetail = (_) async {
          calls += 1;
          if (calls == 1) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          if (calls == 3) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return TeacherSubmissionDetailDto.fromJson(
            submissionDetailJson(),
          ).toDomain();
        },
    );
    await tester.pumpAndSettle();
    expect(find.text('The submission could not be loaded.'), findsOneWidget);
    expect(find.textContaining('Raw local failure'), findsNothing);

    await tester.tap(
      find.byKey(const Key('teacherSubmissionDetailRetryButton')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherSubmissionHeader')), findsOneWidget);

    await tester.tap(find.byKey(const Key('teacherSubmissionRefreshButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherSubmissionDetailStaleMessage')),
      findsOneWidget,
    );
    expect(
      find.text('The displayed submission may be out of date.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('teacherSubmissionHeader')), findsOneWidget);
  });
}

GoRouter _router(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(TestLabUzApp)),
  ).read(appRouterProvider);
}

String _routerPath(WidgetTester tester) =>
    _router(tester).routeInformationProvider.value.uri.path;

class _Pumped {
  _Pumped(this.local);

  final _LocalAdapter local;
}

Future<_Pumped> _pumpApp(
  WidgetTester tester, {
  required String location,
  FakeTeacherSubmissionRepository? submissions,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  FakeTeacherAuthSessionController? auth,
  FutureOr<ResponseBody> Function(RequestOptions)? download,
}) async {
  await tester.binding.setSurfaceSize(
    surface == AppDeviceSurface.mobile
        ? const Size(390, 844)
        : const Size(1400, 1000),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final local = _LocalAdapter();
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
    ..httpClientAdapter = _Adapter(download ?? (_) => _download());
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(location),
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeTeacherAuthSessionController.authenticated(
                teacherUser('teacher-a'),
              ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherGroupListRepositoryProvider.overrideWithValue(
          FakeTeacherGroupListRepository(),
        ),
        teacherTopicListRepositoryProvider.overrideWithValue(
          FakeTeacherTopicListRepository(),
        ),
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
        teacherBlitzRepositoryProvider.overrideWithValue(
          FakeTeacherBlitzRepository(),
        ),
        teacherSubmissionRepositoryProvider.overrideWithValue(
          submissions ?? FakeTeacherSubmissionRepository(),
        ),
        protectedLearningMaterialTransferProvider.overrideWithValue(
          ProtectedLearningMaterialTransfer(
            dio: dio,
            failureMapper: const DioFailureMapper(),
          ),
        ),
        localFileActionsProvider.overrideWithValue(
          LocalFileActions(platform: local),
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Pumped(local);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

class _LocalAdapter implements LocalFilePlatformAdapter {
  int saveCalls = 0;

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async => LocalFileOpenOutcome.opened;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String dialogTitle,
  }) async {
    saveCalls += 1;
    return Uri.file('saved.pdf');
  }
}

ResponseBody _download() => ResponseBody.fromBytes(
  const [1, 2, 3, 4],
  200,
  headers: {
    Headers.contentTypeHeader: ['application/pdf'],
    'content-disposition': ['attachment; filename="report.pdf"'],
    'cache-control': ['no-store, private'],
    'x-content-type-options': ['nosniff'],
  },
);
