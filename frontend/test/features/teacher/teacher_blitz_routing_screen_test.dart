import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  test('Blitz route helpers accept only the canonical nested path', () {
    final location = AppRoutePaths.teacherBlitzDetailLocation(
      _topicId,
      _blitzId,
    );

    expect(location, '/teacher/topics/$_topicId/blitz/$_blitzId');
    expect(AppRouteNames.teacherBlitzDetail, 'teacher-blitz-detail');
    expect(
      AppRoutePaths.teacherBlitzDetail,
      '/teacher/topics/:topicId/blitz/:blitzId',
    );
    expect(AppRoutePaths.isTeacherBlitzDetailPath(location), isTrue);
    expect(AppRoutePaths.isTeacherApprovedLocation(location), isTrue);
    expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);
    expect(AppRoutePaths.isTeacherTopicDetailPath(location), isFalse);
    expect(AppRoutePaths.isTeacherHomeworkDetailPath(location), isFalse);
    expect(AppRoutePaths.teacherHomeworkIdFromPath(location), isNull);

    final uppercase = AppRoutePaths.teacherBlitzDetailLocation(
      _topicId.toUpperCase(),
      _blitzId.toUpperCase(),
    );
    expect(AppRoutePaths.isTeacherBlitzDetailPath(uppercase), isTrue);
    expect(
      AppRoutePaths.teacherTopicIdFromPath(uppercase),
      _topicId.toUpperCase(),
    );

    final homeworkLocation = AppRoutePaths.teacherHomeworkDetailLocation(
      _topicId,
      _homeworkId,
    );
    expect(AppRoutePaths.isTeacherBlitzDetailPath(homeworkLocation), isFalse);
    expect(AppRoutePaths.isTeacherHomeworkDetailPath(homeworkLocation), isTrue);

    for (final invalid in [
      '/teacher/topics/not-a-uuid/blitz/$_blitzId',
      '/teacher/topics/$_topicId/blitz/not-a-uuid',
      '/teacher/topics/$_topicId/blitz',
      '/teacher/topics/$_topicId/blitz/$_blitzId/',
      '/teacher/topics/$_topicId/blitz/$_blitzId/extra',
      '/teacher/topics/$_topicId/blitz/$_blitzId?private=1',
      '/teacher/topics/$_topicId/blitz/$_blitzId#fragment',
    ]) {
      expect(AppRoutePaths.isTeacherBlitzDetailPath(invalid), isFalse);
      expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
      expect(AppRoutePaths.teacherTopicIdFromPath(invalid), isNull);
    }

    for (final (topicId, blitzId) in [
      ('not-a-uuid', _blitzId),
      (_topicId, 'not-a-uuid'),
      (' $_topicId', _blitzId),
      (_topicId, '$_blitzId '),
      (_topicId, 'new'),
    ]) {
      expect(
        () => AppRoutePaths.teacherBlitzDetailLocation(topicId, blitzId),
        throwsArgumentError,
      );
    }
  });

  test('the monitoring route helpers accept only the canonical path', () {
    final location = AppRoutePaths.teacherBlitzMonitoringLocation(
      _topicId,
      _blitzId,
    );

    expect(location, '/teacher/topics/$_topicId/blitz/$_blitzId/monitoring');
    expect(AppRouteNames.teacherBlitzMonitoring, 'teacher-blitz-monitoring');
    expect(
      AppRoutePaths.teacherBlitzMonitoring,
      '/teacher/topics/:topicId/blitz/:blitzId/monitoring',
    );
    expect(AppRoutePaths.isTeacherBlitzMonitoringPath(location), isTrue);
    expect(AppRoutePaths.isTeacherBlitzDetailPath(location), isFalse);
    expect(AppRoutePaths.isTeacherBlitzEditPath(location), isFalse);
    expect(AppRoutePaths.isTeacherApprovedLocation(location), isTrue);
    expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);
    expect(AppRoutePaths.teacherBlitzIdFromPath(location), _blitzId);
    expect(AppRoutePaths.teacherHomeworkIdFromPath(location), isNull);

    for (final invalid in [
      '/teacher/topics/not-a-uuid/blitz/$_blitzId/monitoring',
      '/teacher/topics/$_topicId/blitz/not-a-uuid/monitoring',
      '/teacher/topics/$_topicId/blitz/new/monitoring',
      '/teacher/topics/$_topicId/blitz/$_blitzId/monitoring/',
      '/teacher/topics/$_topicId/blitz/$_blitzId/monitoring/extra',
      '/teacher/topics/$_topicId/homework/$_blitzId/monitoring',
      '/teacher/topics/$_topicId/blitz/$_blitzId/monitoring?private=1',
      '/teacher/topics/$_topicId/blitz/$_blitzId/monitoring#fragment',
    ]) {
      expect(
        AppRoutePaths.isTeacherBlitzMonitoringPath(invalid),
        isFalse,
        reason: invalid,
      );
      expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
      expect(AppRoutePaths.teacherTopicIdFromPath(invalid), isNull);
      expect(AppRoutePaths.teacherBlitzIdFromPath(invalid), isNull);
    }
    expect(
      () => AppRoutePaths.teacherBlitzMonitoringLocation(_topicId, 'new'),
      throwsArgumentError,
    );
  });

  test('Blitz authoring route helpers accept only canonical paths', () {
    final create = AppRoutePaths.teacherBlitzCreateLocation(_topicId);
    final edit = AppRoutePaths.teacherBlitzEditLocation(_topicId, _blitzId);
    final questions = AppRoutePaths.teacherBlitzQuestionsLocation(
      _topicId,
      _blitzId,
    );

    expect(create, '/teacher/topics/$_topicId/blitz/new');
    expect(edit, '/teacher/topics/$_topicId/blitz/$_blitzId/edit');
    expect(questions, '/teacher/topics/$_topicId/blitz/$_blitzId/questions');
    expect(AppRouteNames.teacherBlitzCreate, 'teacher-blitz-create');
    expect(AppRouteNames.teacherBlitzEdit, 'teacher-blitz-edit');
    expect(AppRouteNames.teacherBlitzQuestions, 'teacher-blitz-questions');
    expect(
      AppRoutePaths.teacherBlitzCreate,
      '/teacher/topics/:topicId/blitz/new',
    );
    expect(
      AppRoutePaths.teacherBlitzEdit,
      '/teacher/topics/:topicId/blitz/:blitzId/edit',
    );
    expect(
      AppRoutePaths.teacherBlitzQuestions,
      '/teacher/topics/:topicId/blitz/:blitzId/questions',
    );

    expect(AppRoutePaths.isTeacherBlitzCreatePath(create), isTrue);
    expect(AppRoutePaths.isTeacherBlitzDetailPath(create), isFalse);
    expect(AppRoutePaths.teacherBlitzIdFromPath(create), isNull);
    expect(AppRoutePaths.isTeacherBlitzEditPath(edit), isTrue);
    expect(AppRoutePaths.isTeacherBlitzQuestionsPath(questions), isTrue);
    for (final location in [create, edit, questions]) {
      expect(AppRoutePaths.isTeacherApprovedLocation(location), isTrue);
      expect(AppRoutePaths.teacherTopicIdFromPath(location), _topicId);
      expect(AppRoutePaths.teacherHomeworkIdFromPath(location), isNull);
    }
    expect(AppRoutePaths.teacherBlitzIdFromPath(edit), _blitzId);
    expect(AppRoutePaths.teacherBlitzIdFromPath(questions), _blitzId);

    for (final invalid in [
      '/teacher/topics/not-a-uuid/blitz/new',
      '/teacher/topics/$_topicId/blitz/new/',
      '/teacher/topics/$_topicId/blitz/new/edit',
      '/teacher/topics/$_topicId/blitz/not-a-uuid/edit',
      '/teacher/topics/$_topicId/blitz/$_blitzId/edit/',
      '/teacher/topics/$_topicId/blitz/$_blitzId/questions/extra',
      '/teacher/topics/$_topicId/blitz/$_blitzId/new',
      '/teacher/topics/$_topicId/blitz/$_blitzId/edit?private=1',
      '/teacher/topics/$_topicId/blitz/new#fragment',
    ]) {
      expect(AppRoutePaths.isTeacherApprovedLocation(invalid), isFalse);
      expect(AppRoutePaths.teacherTopicIdFromPath(invalid), isNull);
      expect(AppRoutePaths.teacherBlitzIdFromPath(invalid), isNull);
    }
  });

  testWidgets('desktop opens every Blitz authoring route', (tester) async {
    for (final (location, screenKey) in [
      (
        AppRoutePaths.teacherBlitzCreateLocation(_topicId),
        'teacherBlitzCreateScreen',
      ),
      (
        AppRoutePaths.teacherBlitzEditLocation(_topicId, _blitzId),
        'teacherBlitzEditScreen',
      ),
      (
        AppRoutePaths.teacherBlitzQuestionsLocation(_topicId, _blitzId),
        'teacherBlitzQuestionBuilderScreen',
      ),
    ]) {
      await _pumpApp(
        tester,
        location: location,
        blitz: FakeTeacherBlitzRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key(screenKey)), findsOneWidget, reason: location);
      expect(_routerPath(tester), location);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('mobile Blitz authoring routes redirect to read-only screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final blitzDetail = AppRoutePaths.teacherBlitzDetailLocation(
      _topicId,
      _blitzId,
    );
    for (final (location, expected) in [
      (
        AppRoutePaths.teacherBlitzCreateLocation(_topicId),
        AppRoutePaths.teacherTopicDetailLocation(_topicId),
      ),
      (AppRoutePaths.teacherBlitzEditLocation(_topicId, _blitzId), blitzDetail),
      (
        AppRoutePaths.teacherBlitzQuestionsLocation(_topicId, _blitzId),
        blitzDetail,
      ),
    ]) {
      await _pumpApp(
        tester,
        location: location,
        blitz: FakeTeacherBlitzRepository(),
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();

      expect(_routerPath(tester), expected, reason: location);
      expect(find.byKey(const Key('teacherBlitzCreateScreen')), findsNothing);
      expect(find.byKey(const Key('teacherBlitzEditScreen')), findsNothing);
      expect(
        find.byKey(const Key('teacherBlitzQuestionBuilderScreen')),
        findsNothing,
      );
    }
  });

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} Blitz authoring deep links survive bootstrap',
      (tester) async {
        if (surface == AppDeviceSurface.mobile) {
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
        }
        final edit = AppRoutePaths.teacherBlitzEditLocation(_topicId, _blitzId);
        final auth = FakeTeacherAuthSessionController(
          const AuthSessionState.bootstrapping(),
        );
        await _pumpApp(
          tester,
          location: edit,
          blitz: FakeTeacherBlitzRepository(),
          auth: auth,
          surface: surface,
        );
        await tester.pump();

        expect(find.byKey(const Key('teacherBlitzEditScreen')), findsNothing);

        auth.replaceUser(teacherUser('teacher-a'));
        await tester.pumpAndSettle();

        expect(
          _routerPath(tester),
          surface == AppDeviceSurface.desktop
              ? edit
              : AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
        );
        expect(
          find.byKey(const Key('teacherBlitzEditScreen')),
          surface == AppDeviceSurface.desktop ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} supports direct read-only Blitz detail entry',
      (tester) async {
        if (surface == AppDeviceSurface.mobile) {
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
        }
        final blitz = FakeTeacherBlitzRepository();

        await _pumpApp(
          tester,
          location: AppRoutePaths.teacherBlitzDetailLocation(
            _topicId,
            _blitzId,
          ),
          blitz: blitz,
          surface: surface,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('teacherBlitzDetailScreen')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('teacherTopicDetailScreen')), findsNothing);
        expect(find.text('Equation Blitz'), findsOneWidget);
        expect(blitz.fetchIds, [_blitzId]);
        expect(
          _routerPath(tester),
          '/teacher/topics/$_topicId/blitz/$_blitzId',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${surface.name} Blitz deep link survives Teacher bootstrap', (
      tester,
    ) async {
      if (surface == AppDeviceSurface.mobile) {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      final blitz = FakeTeacherBlitzRepository();

      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
        blitz: blitz,
        auth: auth,
        surface: surface,
      );
      await tester.pump();

      expect(find.byKey(const Key('teacherBlitzDetailScreen')), findsNothing);
      expect(blitz.fetchIds, isEmpty);

      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacherBlitzDetailScreen')), findsOneWidget);
      expect(blitz.fetchIds, [_blitzId]);
    });
  }

  testWidgets('mobile read detail is not redirected by the authoring gate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final blitz = FakeTeacherBlitzRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
      blitz: blitz,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pumpAndSettle();

    _router(
      tester,
    ).go(AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherBlitzDetailScreen')), findsOneWidget);
    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsNothing);
    expect(_routerPath(tester), '/teacher/topics/$_topicId/blitz/$_blitzId');
  });

  testWidgets(
    'malformed Blitz paths plus query and fragment redirect without GET',
    (tester) async {
      for (final location in [
        '/teacher/topics/not-a-uuid/blitz/$_blitzId',
        '/teacher/topics/$_topicId/blitz/not-a-uuid',
        '/teacher/topics/$_topicId/blitz',
        '/teacher/topics/$_topicId/blitz/$_blitzId/extra',
        '/teacher/topics/$_topicId/blitz/$_blitzId/monitoring/extra',
        '/teacher/topics/$_topicId/blitz/$_blitzId/monitoring?private=1',
        '/teacher/topics/$_topicId/blitz/$_blitzId/monitoring#fragment',
        '/teacher/topics/$_topicId/blitz/$_blitzId?private=1',
        '/teacher/topics/$_topicId/blitz/$_blitzId#fragment',
      ]) {
        for (final surface in [
          AppDeviceSurface.desktop,
          AppDeviceSurface.mobile,
        ]) {
          final blitz = FakeTeacherBlitzRepository();
          await _pumpApp(
            tester,
            location: location,
            blitz: blitz,
            surface: surface,
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('teacherLearningWorkspace')),
            findsOneWidget,
            reason: '$location on ${surface.name}',
          );
          expect(_routerPath(tester), AppRoutePaths.teacher);
          expect(
            find.byKey(const Key('teacherBlitzDetailScreen')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('teacherBlitzMonitoringScreen')),
            findsNothing,
          );
          expect(blitz.fetchIds, isEmpty);
          expect(blitz.monitoringIds, isEmpty);
        }
      }
    },
  );

  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets(
      '${surface.name} direct monitoring entry confirms, then reads',
      (tester) async {
        await _useSurface(tester, surface);
        final blitz = _activeBlitz();
        final location = AppRoutePaths.teacherBlitzMonitoringLocation(
          _topicId,
          _blitzId,
        );

        await _pumpApp(
          tester,
          location: location,
          blitz: blitz,
          surface: surface,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('teacherBlitzMonitoringScreen')),
          findsOneWidget,
        );
        expect(blitz.fetchIds, [_blitzId]);
        expect(blitz.monitoringIds, [_blitzId]);
        expect(find.text('Live · updates every 5 seconds'), findsOneWidget);
        expect(_routerPath(tester), location);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${surface.name} a Blitz of another Topic is never monitored', (
      tester,
    ) async {
      await _useSurface(tester, surface);
      final blitz = FakeTeacherBlitzRepository(
        onFetch: (id) async => teacherBlitz(
          id: id,
          topicId: '10000000-0000-0000-0000-000000000002',
          status: TeacherBlitzStatus.active,
        ),
      );

      await _pumpApp(
        tester,
        location: AppRoutePaths.teacherBlitzMonitoringLocation(
          _topicId,
          _blitzId,
        ),
        blitz: blitz,
        surface: surface,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherBlitzMonitoringUnavailable')),
        findsOneWidget,
      );
      expect(blitz.monitoringIds, isEmpty);
      expect(find.textContaining('Grant'), findsNothing);
    });

    testWidgets('${surface.name} monitoring deep link survives bootstrap', (
      tester,
    ) async {
      await _useSurface(tester, surface);
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      final blitz = _activeBlitz();
      final location = AppRoutePaths.teacherBlitzMonitoringLocation(
        _topicId,
        _blitzId,
      );

      await _pumpApp(
        tester,
        location: location,
        blitz: blitz,
        auth: auth,
        surface: surface,
      );
      await tester.pump();
      expect(blitz.monitoringIds, isEmpty);

      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();

      expect(_routerPath(tester), location);
      expect(
        find.byKey(const Key('teacherBlitzMonitoringScreen')),
        findsOneWidget,
      );
      expect(blitz.monitoringIds, [_blitzId]);
    });
  }

  testWidgets('a missing parent Blitz is a safe not-found state', (
    tester,
  ) async {
    final blitz = FakeTeacherBlitzRepository(
      onFetch: (_) async => throw teacherServerFailure(
        ApiErrorCodes.resourceNotFound,
        statusCode: 404,
      ),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherBlitzMonitoringLocation(
        _topicId,
        _blitzId,
      ),
      blitz: blitz,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherBlitzMonitoringUnavailable')),
      findsOneWidget,
    );
    expect(blitz.monitoringIds, isEmpty);
  });

  testWidgets('a parent read failure offers Retry, not monitoring', (
    tester,
  ) async {
    await _useSurface(tester, AppDeviceSurface.mobile);
    final blitz = FakeTeacherBlitzRepository(
      onFetch: (_) async => throw teacherLocalFailure(ApiFailureKind.timeout),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherBlitzMonitoringLocation(
        _topicId,
        _blitzId,
      ),
      blitz: blitz,
      surface: AppDeviceSurface.mobile,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherBlitzMonitoringParentRetryButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('teacherBlitzMonitoringUnavailable')),
      findsNothing,
    );
    expect(blitz.monitoringIds, isEmpty);
  });

  testWidgets('a non-Teacher role does not gain the monitoring route', (
    tester,
  ) async {
    final blitz = _activeBlitz();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherBlitzMonitoringLocation(
        _topicId,
        _blitzId,
      ),
      blitz: blitz,
      auth: FakeTeacherAuthSessionController.authenticated(
        teacherUser('student-a', role: UserRole.student),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherBlitzMonitoringScreen')), findsNothing);
    expect(blitz.fetchIds, isEmpty);
    expect(blitz.monitoringIds, isEmpty);
  });

  testWidgets('Monitor opens monitoring and Back returns to the Blitz', (
    tester,
  ) async {
    final blitz = _activeBlitz();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
      blitz: blitz,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherBlitzMonitorButton')));
    await tester.pumpAndSettle();

    expect(
      _routerPath(tester),
      AppRoutePaths.teacherBlitzMonitoringLocation(_topicId, _blitzId),
    );
    expect(blitz.monitoringIds, [_blitzId]);

    await tester.tap(find.byKey(const Key('teacherBlitzMonitoringBackButton')));
    await tester.pumpAndSettle();

    expect(
      _routerPath(tester),
      AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
    );
    expect(find.byKey(const Key('teacherBlitzDetailScreen')), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(blitz.monitoringIds, [_blitzId]);
  });

  testWidgets('malformed Blitz paths fall back to root during bootstrap', (
    tester,
  ) async {
    for (final location in [
      '/teacher/topics/$_topicId/blitz/not-a-uuid',
      '/teacher/topics/$_topicId/blitz/$_blitzId/extra',
      '/teacher/topics/$_topicId/blitz/$_blitzId?private=1',
    ]) {
      final auth = FakeTeacherAuthSessionController(
        const AuthSessionState.bootstrapping(),
      );
      final blitz = FakeTeacherBlitzRepository();
      await _pumpApp(tester, location: location, blitz: blitz, auth: auth);
      await tester.pump();

      expect(_routerPath(tester), AppRoutePaths.root, reason: location);
      expect(find.byKey(const Key('teacherBlitzDetailScreen')), findsNothing);

      auth.replaceUser(teacherUser('teacher-a'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacherLearningWorkspace')), findsOneWidget);
      expect(blitz.fetchIds, isEmpty);
    }
  });

  testWidgets('a non-Teacher role does not gain the Blitz detail route', (
    tester,
  ) async {
    final blitz = FakeTeacherBlitzRepository();
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
      blitz: blitz,
      auth: FakeTeacherAuthSessionController.authenticated(
        teacherUser('parent-a', role: UserRole.parent),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherBlitzDetailScreen')), findsNothing);
    expect(_routerPath(tester), AppRoutePaths.unsupportedDevice);
    expect(blitz.fetchIds, isEmpty);
  });

  testWidgets('Blitz card pushes detail and Back returns to Topic', (
    tester,
  ) async {
    final blitz = FakeTeacherBlitzRepository(
      onFetchList: (topicId, query) async => teacherBlitzList(
        items: [teacherBlitzSummary()],
        page: query.page,
        perPage: query.perPage,
        total: 1,
      ),
    );
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherTopicDetailLocation(_topicId),
      blitz: blitz,
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('teacherBlitzCard$_blitzId'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherBlitzDetailScreen')), findsOneWidget);
    expect(blitz.fetchIds, [_blitzId]);
    expect(_routerPath(tester), '/teacher/topics/$_topicId/blitz/$_blitzId');

    await tester.tap(find.byKey(const Key('teacherBlitzBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(find.byKey(const Key('teacherBlitzDetailScreen')), findsNothing);
  });

  testWidgets('direct-entry Back returns to the canonical Topic location', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherBlitzDetailLocation(_topicId, _blitzId),
      blitz: FakeTeacherBlitzRepository(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacherBlitzBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacherTopicDetailScreen')), findsOneWidget);
    expect(
      _routerPath(tester),
      AppRoutePaths.teacherTopicDetailLocation(_topicId),
    );
  });

  testWidgets('existing Homework detail and authoring routes remain valid', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkDetailLocation(
        _topicId,
        _homeworkId,
      ),
      blitz: FakeTeacherBlitzRepository(),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teacherHomeworkDetailScreen')),
      findsOneWidget,
    );

    await _pumpApp(
      tester,
      location: AppRoutePaths.teacherHomeworkEditLocation(
        _topicId,
        _homeworkId,
      ),
      blitz: FakeTeacherBlitzRepository(),
      surface: AppDeviceSurface.mobile,
    );
    await tester.pumpAndSettle();
    expect(
      _routerPath(tester),
      AppRoutePaths.teacherHomeworkDetailLocation(_topicId, _homeworkId),
    );
  });
}

FakeTeacherBlitzRepository _activeBlitz() {
  return FakeTeacherBlitzRepository(
    onFetch: (id) async =>
        teacherBlitz(id: id, status: TeacherBlitzStatus.active),
  );
}

Future<void> _useSurface(WidgetTester tester, AppDeviceSurface surface) async {
  if (surface == AppDeviceSurface.mobile) {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
}

GoRouter _router(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(TestLabUzApp)),
  ).read(appRouterProvider);
}

String _routerPath(WidgetTester tester) {
  return _router(tester).routeInformationProvider.value.uri.path;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String location,
  required FakeTeacherBlitzRepository blitz,
  FakeTeacherAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
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
        teacherBlitzRepositoryProvider.overrideWithValue(blitz),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}
