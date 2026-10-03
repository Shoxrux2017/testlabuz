import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_mutation.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_result_detail_screen.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_results_screen.dart';

import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

const _releaseStudent = Key('teacherTopicResultReleaseStudentButton');
const _releaseParent = Key('teacherTopicResultReleaseParentButton');
const _close = Key('teacherTopicResultCloseButton');
const _commentField = Key('teacherTopicResultCommentField');
const _commentSave = Key('teacherTopicResultCommentSave');
const _confirm = Key('teacherTopicResultConfirmButton');
const _bulkStudents = Key('teacherTopicResultsReleaseStudentsButton');
const _bulkParents = Key('teacherTopicResultsReleaseParentsButton');
const _bulkClose = Key('teacherTopicResultsCloseAllButton');

void main() {
  group('result detail actions', () {
    testWidgets('desktop offers the flagged actions and confirms a release', (
      tester,
    ) async {
      final repository = _detailRepository(
        teacherTopicResultJson(),
        onRelease: (_, _) async => _released(),
      );
      await _pumpDetail(tester, repository);

      expect(find.byKey(_releaseStudent), findsOneWidget);
      expect(find.byKey(_releaseParent), findsNothing);
      expect(find.byKey(_close), findsOneWidget);

      await tester.tap(find.byKey(_releaseStudent));
      await tester.pumpAndSettle();
      expect(find.text('Release to the Student?'), findsOneWidget);
      expect(
        find.text(
          'Aziza Karimova will see the scores, the category and your '
          'comment. A release cannot be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.actions, isEmpty);

      await tester.tap(find.byKey(_releaseStudent));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();

      expect(repository.actions, ['release:student']);
      expect(find.text('Result released to the Student.'), findsOneWidget);
      expect(find.byKey(_releaseStudent), findsNothing);
    });

    testWidgets('mobile releases but neither comments nor closes', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _detailRepository(_parentReleasable(teacherComment: 'Well done.')),
        surface: AppDeviceSurface.mobile,
      );

      expect(find.byKey(_releaseParent), findsOneWidget);
      expect(find.byKey(_close), findsNothing);
      expect(find.byKey(_commentField), findsNothing);
      expect(find.text('Well done.'), findsOneWidget);
    });

    testWidgets('closing asks first and then locks the comment', (
      tester,
    ) async {
      final repository = _detailRepository(
        teacherTopicResultJson(teacherComment: 'Well done.'),
        onClose: (_) async => teacherTopicResultDetail(
          teacherTopicResultDetailJson(
            item: closedCalculatedTeacherTopicResultJson(),
            closureReason: 'teacher',
          ),
        ),
      );
      await _pumpDetail(tester, repository);
      expect(find.byKey(_commentField), findsOneWidget);

      await tester.tap(find.byKey(_close));
      await tester.pumpAndSettle();
      expect(find.text('Close this result?'), findsOneWidget);
      expect(
        find.text(
          'The result of Aziza Karimova becomes final: corrections of the '
          'official answers and comment changes are no longer possible. '
          'Closing cannot be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();

      expect(repository.actions, ['close']);
      expect(find.text('Result closed.'), findsOneWidget);
      expect(find.byKey(_close), findsNothing);
      expect(find.byKey(_commentField), findsNothing);
    });

    testWidgets('the comment counts code points and saves when changed', (
      tester,
    ) async {
      final repository = _detailRepository(
        teacherTopicResultJson(),
        onUpdateComment: (_, text) async => teacherTopicResultDetail(
          teacherTopicResultDetailJson(
            item: teacherTopicResultJson(teacherComment: text.trim()),
          ),
        ),
      );
      await _pumpDetail(tester, repository);

      expect(find.text('0 / 2000'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);

      await tester.enterText(find.byKey(_commentField), '😀' * 2001);
      await tester.pump();
      expect(find.text('2001 / 2000'), findsOneWidget);
      expect(find.text('Use at most 2000 characters.'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);

      await tester.enterText(
        find.byKey(_commentField),
        '  Revise question 4. ',
      );
      await tester.pump();
      expect(find.text('18 / 2000'), findsOneWidget);
      expect(_saveEnabled(tester), isTrue);
      await tester.ensureVisible(find.byKey(_commentSave));
      await tester.tap(find.byKey(_commentSave));
      await tester.pumpAndSettle();

      expect(repository.actions, ['comment:  Revise question 4. ']);
      expect(find.text('Comment saved.'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('a conflict is explained and the result reloaded', (
      tester,
    ) async {
      final repository = _detailRepository(
        teacherTopicResultJson(),
        onRelease: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.resultNotReady,
          statusCode: 409,
        ),
      );
      await _pumpDetail(tester, repository);

      await tester.tap(find.byKey(_releaseStudent));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();

      expect(
        find.text('This result is not ready to be released yet.'),
        findsOneWidget,
      );
      expect(repository.detailRequests, hasLength(2));
    });

    testWidgets('a stale result hides its actions', (tester) async {
      var reads = 0;
      final repository = FakeTeacherTopicResultRepository(
        onFetchResult: (_, _) async {
          reads += 1;
          if (reads == 2) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return teacherTopicResultDetail();
        },
      );
      await _pumpDetail(tester, repository);
      expect(find.byKey(_close), findsOneWidget);
      await tester.enterText(find.byKey(_commentField), 'Draft note.');
      await tester.pump();
      expect(_saveEnabled(tester), isTrue);

      await tester.tap(
        find.byKey(const Key('teacherTopicResultRefreshButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherTopicResultStaleMessage')),
        findsOneWidget,
      );
      expect(find.byKey(_close), findsNothing);
      expect(find.byKey(_releaseStudent), findsNothing);
      expect(find.text('Draft note.'), findsOneWidget);
      expect(find.byKey(_commentSave), findsNothing);
    });

    testWidgets('actions fit a narrow phone with large text', (tester) async {
      _useNarrowPhone(tester);
      await _pumpDetail(
        tester,
        _detailRepository(_parentReleasable()),
        surface: AppDeviceSurface.mobile,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(_releaseParent), findsOneWidget);
    });

    testWidgets('desktop shows who changed the comment under the editor', (
      tester,
    ) async {
      await _pump(
        tester,
        const TeacherTopicResultDetailScreen(
          topicId: teacherResultTopicId,
          studentId: teacherResultStudentId,
        ),
        FakeTeacherTopicResultRepository(
          onFetchResult: (_, _) async => teacherTopicResultDetail(
            teacherTopicResultDetailJson(
              item: teacherTopicResultJson(teacherComment: 'Well done.'),
              commentUpdatedAt: '2026-10-03T07:30:00Z',
              commentUpdatedBy: teacherResultActorJson(),
            ),
          ),
        ),
        surface: AppDeviceSurface.desktop,
      );

      expect(find.byKey(_commentField), findsOneWidget);
      expect(find.text('Well done.'), findsOneWidget);
      expect(
        find.text('Last changed 2026-10-03 12:30 by Dilnoza Teacher'),
        findsOneWidget,
      );
    });
  });

  group('results list bulk actions', () {
    testWidgets('desktop offers the allowed bulk actions and reports', (
      tester,
    ) async {
      final repository = _listRepository(
        teacherTopicResultJson(),
        onReleaseAll: (_) async => const TeacherTopicResultBulkOutcome(
          processed: 21,
          alreadyDone: 3,
          notReady: 6,
        ),
      );
      await _pumpList(tester, repository);

      expect(find.byKey(_bulkStudents), findsOneWidget);
      expect(find.byKey(_bulkParents), findsNothing);
      expect(find.byKey(_bulkClose), findsOneWidget);

      await tester.tap(find.byKey(_bulkStudents));
      await tester.pumpAndSettle();
      expect(find.text('Release ready results to Students?'), findsOneWidget);
      expect(
        find.textContaining('not only this page or filter'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();

      expect(repository.actions, ['releaseAll:student']);
      expect(
        find.text(
          'Released to 21 Students. Skipped: 3 already released, 6 not ready '
          'yet.',
        ),
        findsOneWidget,
      );
      expect(repository.listRequests, hasLength(2));
    });

    testWidgets('closing all asks first and names what it blocks', (
      tester,
    ) async {
      final repository = _listRepository(
        teacherTopicResultJson(),
        onCloseAll: () async => const TeacherTopicResultBulkOutcome(
          processed: 1,
          alreadyDone: 0,
          notReady: 0,
        ),
      );
      await _pumpList(tester, repository);

      await tester.tap(find.byKey(_bulkClose));
      await tester.pumpAndSettle();
      expect(find.text('Close ready results?'), findsOneWidget);
      expect(
        find.textContaining('comment changes are blocked'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.actions, isEmpty);

      await tester.tap(find.byKey(_bulkClose));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text('Closed 1 result.'), findsOneWidget);
    });

    testWidgets('mobile releases in bulk but never closes', (tester) async {
      await _pumpList(
        tester,
        _listRepository(_parentReleasable()),
        surface: AppDeviceSurface.mobile,
      );

      expect(find.byKey(_bulkStudents), findsNothing);
      expect(find.byKey(_bulkParents), findsOneWidget);
      expect(find.byKey(_bulkClose), findsNothing);
    });

    testWidgets('a forbidden release mode is explained', (tester) async {
      await _pumpList(
        tester,
        _listRepository(
          teacherTopicResultJson(),
          onReleaseAll: (_) async => throw teacherServerFailure(
            ApiErrorCodes.manualReleaseNotAllowed,
            statusCode: 409,
          ),
        ),
      );

      await tester.tap(find.byKey(_bulkStudents));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "The Institution's release mode does not allow a Teacher release.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('a stale list offers no bulk action', (tester) async {
      var reads = 0;
      final repository = FakeTeacherTopicResultRepository(
        onFetchResults: (_, query) async {
          reads += 1;
          if (reads == 2) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return teacherTopicResultList(query: query);
        },
      );
      await _pumpList(tester, repository);
      expect(find.byKey(_bulkStudents), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('teacherTopicResultsRefreshButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherTopicResultsStaleMessage')),
        findsOneWidget,
      );
      expect(find.byKey(_bulkStudents), findsNothing);
      expect(find.byKey(_bulkClose), findsNothing);
    });

    testWidgets('bulk actions fit a narrow phone with large text', (
      tester,
    ) async {
      _useNarrowPhone(tester);
      await _pumpList(
        tester,
        _listRepository(_parentReleasable()),
        surface: AppDeviceSurface.mobile,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(_bulkParents), findsOneWidget);
    });

    testWidgets('an empty cohort offers no bulk action', (tester) async {
      await _pumpList(tester, FakeTeacherTopicResultRepository());

      expect(find.byKey(_bulkStudents), findsNothing);
      expect(find.byKey(_bulkClose), findsNothing);
    });
  });
}

bool _saveEnabled(WidgetTester tester) {
  return tester.widget<ButtonStyleButton>(find.byKey(_commentSave)).enabled;
}

Map<String, Object?> _parentReleasable({String? teacherComment}) {
  return teacherTopicResultJson(
    teacherComment: teacherComment,
    visibility: teacherResultVisibilityJson(
      studentMode: 'automatic',
      studentVisible: true,
      canReleaseToStudent: false,
      parentMode: 'manual_teacher',
      canReleaseToParent: true,
    ),
  );
}

TeacherTopicResultDetail _released() {
  return teacherTopicResultDetail(
    teacherTopicResultDetailJson(
      item: teacherTopicResultJson(
        visibility: teacherResultVisibilityJson(
          studentVisible: true,
          studentReleasedAt: '2026-10-05T09:00:00Z',
          canReleaseToStudent: false,
        ),
      ),
    ),
  );
}

FakeTeacherTopicResultRepository _detailRepository(
  Map<String, Object?> item, {
  Future<TeacherTopicResultDetail> Function(
    String studentId,
    TeacherTopicResultAudience audience,
  )?
  onRelease,
  Future<TeacherTopicResultDetail> Function(String studentId)? onClose,
  Future<TeacherTopicResultDetail> Function(String studentId, String text)?
  onUpdateComment,
}) {
  return FakeTeacherTopicResultRepository(
    onFetchResult: (_, _) async =>
        teacherTopicResultDetail(teacherTopicResultDetailJson(item: item)),
    onRelease: onRelease,
    onClose: onClose,
    onUpdateComment: onUpdateComment,
  );
}

FakeTeacherTopicResultRepository _listRepository(
  Map<String, Object?> item, {
  Future<TeacherTopicResultBulkOutcome> Function(
    TeacherTopicResultAudience audience,
  )?
  onReleaseAll,
  Future<TeacherTopicResultBulkOutcome> Function()? onCloseAll,
}) {
  return FakeTeacherTopicResultRepository(
    onFetchResults: (_, query) async =>
        teacherTopicResultList(query: query, items: [item]),
    onReleaseAll: onReleaseAll,
    onCloseAll: onCloseAll,
  );
}

void _useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpDetail(
  WidgetTester tester,
  FakeTeacherTopicResultRepository repository, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  double textScale = 1,
}) {
  return _pump(
    tester,
    const TeacherTopicResultDetailScreen(
      topicId: teacherResultTopicId,
      studentId: teacherResultStudentId,
    ),
    repository,
    surface: surface,
    textScale: textScale,
  );
}

Future<void> _pumpList(
  WidgetTester tester,
  FakeTeacherTopicResultRepository repository, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  double textScale = 1,
}) {
  return _pump(
    tester,
    const TeacherTopicResultsScreen(topicId: teacherResultTopicId),
    repository,
    surface: surface,
    textScale: textScale,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  FakeTeacherTopicResultRepository repository, {
  required AppDeviceSurface surface,
  double textScale = 1,
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
        teacherTopicResultRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
