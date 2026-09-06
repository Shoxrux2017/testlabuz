import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_lifecycle_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_lifecycle_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_list_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_lifecycle.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair_repository.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _otherTopicId = '10000000-0000-0000-0000-000000000002';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _otherHomeworkId = '50000000-0000-0000-0000-000000000002';

void main() {
  group('Homework lifecycle action matrix', () {
    test('offers only state-valid actions', () {
      expect(teacherHomeworkLifecycleActions(teacherHomework()), const [
        TeacherHomeworkLifecycleAction.activate,
        TeacherHomeworkLifecycleAction.archive,
      ]);
      expect(
        teacherHomeworkLifecycleActions(
          teacherHomework(status: TeacherHomeworkStatus.active),
        ),
        const [TeacherHomeworkLifecycleAction.close],
      );
      expect(
        teacherHomeworkLifecycleActions(
          teacherHomework(status: TeacherHomeworkStatus.closed),
        ),
        const [TeacherHomeworkLifecycleAction.archive],
      );
      expect(
        teacherHomeworkLifecycleActions(
          teacherHomework(status: TeacherHomeworkStatus.archived),
        ),
        isEmpty,
      );
    });
  });

  group('TeacherHomeworkLifecycleController', () {
    test(
      'confirms each action and refreshes only its required readers',
      () async {
        final cases =
            <(TeacherHomeworkStatus, TeacherHomeworkLifecycleAction, String)>[
              (
                TeacherHomeworkStatus.draft,
                TeacherHomeworkLifecycleAction.activate,
                'Homework activated successfully.',
              ),
              (
                TeacherHomeworkStatus.active,
                TeacherHomeworkLifecycleAction.close,
                'Homework closed successfully.',
              ),
              (
                TeacherHomeworkStatus.closed,
                TeacherHomeworkLifecycleAction.archive,
                'Homework archived successfully.',
              ),
            ];

        for (final testCase in cases) {
          final repository = FakeTeacherHomeworkRepository(
            onFetch: (_) async => teacherHomework(status: testCase.$1),
            onLifecycle: (_, action) async =>
                teacherHomework(status: action.expectedStatus),
          );
          final pairs = _FakePairRepository();
          final harness = _Harness(repository: repository, pairs: pairs);
          final lifecycle = harness.listenLifecycle();
          harness.listenDetail();
          harness.listenList();
          harness.listenPair();
          await flushTeacherControllers();

          await harness.controller.perform(testCase.$2);
          await flushTeacherControllers();

          expect(repository.lifecycleRequests, [
            (homeworkId: _homeworkId, action: testCase.$2),
          ]);
          expect(
            lifecycle.read().status,
            TeacherHomeworkLifecycleStatus.confirmedSuccess,
          );
          expect(lifecycle.read().feedback, testCase.$3);
          expect(harness.detail.homework?.status, testCase.$2.expectedStatus);
          expect(repository.listRequests, hasLength(2));
          expect(
            pairs.fetchRequests,
            hasLength(
              testCase.$2 == TeacherHomeworkLifecycleAction.activate ? 2 : 1,
            ),
          );
          expect(harness.activity.isActive, isFalse);
        }
      },
    );

    test(
      'dual-target response mismatches reconcile before publication',
      () async {
        for (final mismatch in [
          teacherHomework(
            id: _otherHomeworkId,
            status: TeacherHomeworkStatus.active,
          ),
          teacherHomework(
            topicId: _otherTopicId,
            status: TeacherHomeworkStatus.active,
          ),
        ]) {
          var fetchCount = 0;
          final repository = FakeTeacherHomeworkRepository(
            onFetch: (_) async {
              fetchCount += 1;
              return teacherHomework(
                status: fetchCount == 1
                    ? TeacherHomeworkStatus.draft
                    : TeacherHomeworkStatus.active,
              );
            },
            onLifecycle: (_, _) async => mismatch,
          );
          final harness = _Harness(repository: repository);
          final lifecycle = harness.listenLifecycle();
          harness.listenDetail();
          await flushTeacherControllers();

          await harness.controller.perform(
            TeacherHomeworkLifecycleAction.activate,
          );

          expect(repository.lifecycleRequests, hasLength(1));
          expect(repository.fetchIds, [_homeworkId, _homeworkId]);
          expect(
            lifecycle.read().status,
            TeacherHomeworkLifecycleStatus.confirmedSuccess,
          );
          expect(harness.detail.homework?.topicId, _topicId);
        }
      },
    );

    test(
      'unknown POST plus matching GET confirms success without replay',
      () async {
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return teacherHomework(
              status: fetchCount == 1
                  ? TeacherHomeworkStatus.draft
                  : TeacherHomeworkStatus.active,
            );
          },
          onLifecycle: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        await flushTeacherControllers();

        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );

        expect(repository.lifecycleRequests, hasLength(1));
        expect(repository.fetchIds, [_homeworkId, _homeworkId]);
        expect(
          lifecycle.read().status,
          TeacherHomeworkLifecycleStatus.confirmedSuccess,
        );
      },
    );

    test(
      'different authoritative GET requires review but releases the lease',
      () async {
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(),
          onLifecycle: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        await flushTeacherControllers();

        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );

        expect(
          lifecycle.read().status,
          TeacherHomeworkLifecycleStatus.outcomeReview,
        );
        expect(lifecycle.read().requiresCheckCurrent, isFalse);
        expect(
          lifecycle.read().notice,
          'The lifecycle result could not be confirmed.\nReview the current Homework state before taking another action.',
        );
        expect(harness.activity.isActive, isFalse);
        expect(repository.lifecycleRequests, hasLength(1));
      },
    );

    test(
      'failed reconciliation blocks both mutation kinds until GET review',
      () async {
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            if (fetchCount == 1) {
              return teacherHomework();
            }
            if (fetchCount == 2) {
              throw teacherLocalFailure(ApiFailureKind.timeout);
            }
            return teacherHomework(status: TeacherHomeworkStatus.active);
          },
          onLifecycle: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        await flushTeacherControllers();

        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );

        expect(lifecycle.read().canCheckCurrent, isTrue);
        expect(harness.activity.outcomeReviewBlocking, isTrue);
        expect(
          harness.activityController.begin(
            TeacherHomeworkRouteMutationOperation.official,
          ),
          isNull,
        );
        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );
        expect(repository.lifecycleRequests, hasLength(1));

        await harness.controller.checkCurrentHomework();

        expect(repository.fetchIds, [_homeworkId, _homeworkId, _homeworkId]);
        expect(repository.lifecycleRequests, hasLength(1));
        expect(
          lifecycle.read().status,
          TeacherHomeworkLifecycleStatus.confirmedSuccess,
        );
        expect(harness.activity.isActive, isFalse);
      },
    );

    test(
      'a mismatched reconciliation GET never publishes another target',
      () async {
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return fetchCount == 1
                ? teacherHomework()
                : teacherHomework(
                    topicId: _otherTopicId,
                    status: TeacherHomeworkStatus.active,
                  );
          },
          onLifecycle: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        await flushTeacherControllers();

        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );

        expect(lifecycle.read().canCheckCurrent, isTrue);
        expect(harness.detail.homework?.topicId, _topicId);
        expect(harness.activity.outcomeReviewBlocking, isTrue);
      },
    );

    test(
      'resource_not_found makes detail unavailable and refreshes list',
      () async {
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(),
          onLifecycle: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        harness.listenList();
        await flushTeacherControllers();

        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );
        await flushTeacherControllers();

        expect(
          lifecycle.read().status,
          TeacherHomeworkLifecycleStatus.unavailable,
        );
        expect(
          lifecycle.read().notice,
          'This Homework is no longer available.',
        );
        expect(harness.detail.status, TeacherHomeworkDetailStatus.notFound);
        expect(repository.listRequests, hasLength(2));
        expect(repository.lifecycleRequests, hasLength(1));
      },
    );

    test(
      'exact 404 during a conflict refresh makes detail unavailable',
      () async {
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            if (fetchCount == 1) {
              return teacherHomework();
            }
            throw teacherServerFailure(
              ApiErrorCodes.resourceNotFound,
              statusCode: 404,
            );
          },
          onLifecycle: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.businessConflict,
            statusCode: 409,
          ),
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        harness.listenList();
        await flushTeacherControllers();

        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );
        await flushTeacherControllers();

        expect(
          lifecycle.read().status,
          TeacherHomeworkLifecycleStatus.unavailable,
        );
        expect(harness.detail.status, TeacherHomeworkDetailStatus.notFound);
        expect(repository.lifecycleRequests, hasLength(1));
        expect(repository.fetchIds, [_homeworkId, _homeworkId]);
        expect(repository.listRequests, hasLength(2));
      },
    );

    test('publishes exact lifecycle conflict guidance after one safe GET', () async {
      final cases = <(TeacherHomeworkLifecycleAction, TeacherHomeworkStatus, String, String)>[
        (
          TeacherHomeworkLifecycleAction.activate,
          TeacherHomeworkStatus.draft,
          ApiErrorCodes.assessmentHasNoScoreablePoints,
          'This Homework needs at least one scoreable Question before activation.\nReview the Questions and points.',
        ),
        (
          TeacherHomeworkLifecycleAction.activate,
          TeacherHomeworkStatus.draft,
          ApiErrorCodes.assessmentNotAssigned,
          'Review the Homework assignment.\nThe server could not confirm an eligible recipient set.',
        ),
        (
          TeacherHomeworkLifecycleAction.activate,
          TeacherHomeworkStatus.draft,
          ApiErrorCodes.deadlinePassed,
          'The Homework deadline has already passed.\nUpdate the deadline before activation.',
        ),
        (
          TeacherHomeworkLifecycleAction.activate,
          TeacherHomeworkStatus.draft,
          ApiErrorCodes.topicNotEditable,
          'The Topic is not in a state that allows this Homework to be activated.\nReview the current Topic.',
        ),
        (
          TeacherHomeworkLifecycleAction.activate,
          TeacherHomeworkStatus.draft,
          ApiErrorCodes.businessConflict,
          'The Homework cannot be activated in the current server state.\nRefresh and review its configuration.',
        ),
        (
          TeacherHomeworkLifecycleAction.activate,
          TeacherHomeworkStatus.draft,
          ApiErrorCodes.resultPairLocked,
          'Official Homework activation is locked by the current server state.\nReview the current official Homework status before taking another action.',
        ),
        (
          TeacherHomeworkLifecycleAction.close,
          TeacherHomeworkStatus.active,
          ApiErrorCodes.taskNotActive,
          'This Homework is not active.\nReview its current state.',
        ),
        (
          TeacherHomeworkLifecycleAction.close,
          TeacherHomeworkStatus.active,
          ApiErrorCodes.taskArchived,
          'This Homework is archived.',
        ),
        (
          TeacherHomeworkLifecycleAction.close,
          TeacherHomeworkStatus.active,
          ApiErrorCodes.businessConflict,
          'This Homework cannot be closed in the current server state.\nReview the current Homework before trying again.',
        ),
        (
          TeacherHomeworkLifecycleAction.archive,
          TeacherHomeworkStatus.closed,
          ApiErrorCodes.businessConflict,
          'This Homework cannot be archived in the current server state.',
        ),
      ];

      for (final testCase in cases) {
        var pairFetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(status: testCase.$2),
          onLifecycle: (_, _) async =>
              throw teacherServerFailure(testCase.$3, statusCode: 409),
        );
        final pairs = _FakePairRepository(
          onFetch: (_) async {
            pairFetchCount += 1;
            if (testCase.$3 == ApiErrorCodes.resultPairLocked &&
                pairFetchCount > 1) {
              throw teacherLocalFailure(ApiFailureKind.timeout);
            }
            return null;
          },
        );
        final harness = _Harness(repository: repository, pairs: pairs);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        harness.listenPair();
        await flushTeacherControllers();

        await harness.controller.perform(testCase.$1);
        await flushTeacherControllers();

        expect(
          lifecycle.read().status,
          TeacherHomeworkLifecycleStatus.definiteFailure,
        );
        expect(lifecycle.read().conflictCode, testCase.$3);
        expect(lifecycle.read().notice, testCase.$4);
        expect(repository.fetchIds, [_homeworkId, _homeworkId]);
        expect(repository.lifecycleRequests, hasLength(1));
        expect(harness.activity.isActive, isFalse);
        expect(
          pairs.fetchRequests,
          hasLength(testCase.$3 == ApiErrorCodes.resultPairLocked ? 2 : 1),
        );
        if (testCase.$3 == ApiErrorCodes.resultPairLocked) {
          expect(harness.pair.status, TeacherTopicResultPairStatus.error);
        }
      }
    });

    test(
      'archive conflict uses refreshed active state for specific guidance',
      () async {
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return teacherHomework(
              status: fetchCount == 1
                  ? TeacherHomeworkStatus.closed
                  : TeacherHomeworkStatus.active,
            );
          },
          onLifecycle: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.businessConflict,
            statusCode: 409,
          ),
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        await flushTeacherControllers();

        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.archive,
        );

        expect(
          lifecycle.read().notice,
          'Close the active Homework before archiving it.',
        );
        expect(harness.detail.homework?.status, TeacherHomeworkStatus.active);
      },
    );

    test(
      'confirmed official draft hides archive without sending POST',
      () async {
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(),
        );
        final harness = _Harness(
          repository: repository,
          pairs: _FakePairRepository(initial: _pair()),
        );
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        harness.listenPair();
        await flushTeacherControllers();

        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.archive,
        );

        expect(repository.lifecycleRequests, isEmpty);
        expect(lifecycle.read().status, TeacherHomeworkLifecycleStatus.idle);
      },
    );

    test(
      'shared activity suppresses rapid lifecycle and official starts',
      () async {
        final pending = Completer<TeacherHomework>();
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(),
          onLifecycle: (_, _) => pending.future,
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        await flushTeacherControllers();

        final submission = harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );
        expect(
          lifecycle.read().status,
          TeacherHomeworkLifecycleStatus.submitting,
        );
        expect(
          harness.activityController.begin(
            TeacherHomeworkRouteMutationOperation.official,
          ),
          isNull,
        );
        await harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );
        expect(repository.lifecycleRequests, hasLength(1));
        pending.complete(teacherHomework(status: TeacherHomeworkStatus.active));
        await submission;

        final officialLease = harness.activityController.begin(
          TeacherHomeworkRouteMutationOperation.official,
        );
        expect(officialLease, isNotNull);
        await harness.controller.perform(TeacherHomeworkLifecycleAction.close);
        expect(repository.lifecycleRequests, hasLength(1));
        harness.activityController.release(officialLease!);
      },
    );

    test('endRoute clears a retained blocking activity lease', () {
      final harness = _Harness(repository: FakeTeacherHomeworkRepository());
      harness.listenLifecycle();
      final activity = harness.activityController;
      final lease = activity.begin(
        TeacherHomeworkRouteMutationOperation.official,
      );
      expect(lease, isNotNull);
      activity.markOutcomeReviewBlocking(lease!);
      expect(harness.activity.outcomeReviewBlocking, isTrue);

      activity.endRoute();

      expect(harness.activity.isActive, isFalse);
      final next = activity.begin(
        TeacherHomeworkRouteMutationOperation.lifecycle,
      );
      expect(next, isNotNull);
      activity.release(next!);
    });

    test(
      'leaveRoute releases blocking review and rejects stale completion',
      () async {
        final pending = Completer<TeacherHomework>();
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(),
          onLifecycle: (_, _) => pending.future,
        );
        final harness = _Harness(repository: repository);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        await flushTeacherControllers();

        final submission = harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );
        harness.controller.leaveRoute();
        pending.complete(teacherHomework(status: TeacherHomeworkStatus.active));
        await submission;

        expect(lifecycle.read().status, TeacherHomeworkLifecycleStatus.idle);
        expect(harness.activity.isActive, isFalse);
        expect(harness.detail.homework?.status, TeacherHomeworkStatus.draft);
      },
    );

    test(
      'replacement session rejects a pending lifecycle completion',
      () async {
        final pending = Completer<TeacherHomework>();
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(),
          onLifecycle: (_, _) => pending.future,
        );
        final harness = _Harness(repository: repository, auth: auth);
        final lifecycle = harness.listenLifecycle();
        harness.listenDetail();
        await flushTeacherControllers();

        final submission = harness.controller.perform(
          TeacherHomeworkLifecycleAction.activate,
        );
        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        pending.complete(teacherHomework(status: TeacherHomeworkStatus.active));
        await submission;

        expect(lifecycle.read().status, TeacherHomeworkLifecycleStatus.idle);
        expect(lifecycle.read().feedback, isNull);
        expect(harness.activity.isActive, isFalse);
      },
    );
  });
}

class _Harness {
  _Harness({
    required this.repository,
    _FakePairRepository? pairs,
    FakeTeacherAuthSessionController? auth,
  }) : pairs = pairs ?? _FakePairRepository(),
       auth =
           auth ??
           FakeTeacherAuthSessionController.authenticated(
             teacherUser('teacher-a'),
           ) {
    target = TeacherHomeworkRouteTarget(
      topicId: _topicId,
      homeworkId: _homeworkId,
    );
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherHomeworkRepositoryProvider.overrideWithValue(repository),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(this.pairs),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherHomeworkRepository repository;
  final _FakePairRepository pairs;
  final FakeTeacherAuthSessionController auth;
  late final TeacherHomeworkRouteTarget target;
  late final ProviderContainer container;

  ProviderSubscription<TeacherHomeworkLifecycleState> listenLifecycle() {
    return container.listen(
      teacherHomeworkLifecycleControllerProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
  }

  ProviderSubscription<TeacherHomeworkDetailState> listenDetail() {
    return container.listen(
      teacherHomeworkDetailControllerProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
  }

  ProviderSubscription<TeacherHomeworkListState> listenList() {
    return container.listen(
      teacherHomeworkListControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  ProviderSubscription<TeacherTopicResultPairState> listenPair() {
    return container.listen(
      teacherTopicResultPairControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherHomeworkLifecycleController get controller => container.read(
    teacherHomeworkLifecycleControllerProvider(target).notifier,
  );

  TeacherHomeworkLifecycleState get lifecycle =>
      container.read(teacherHomeworkLifecycleControllerProvider(target));

  TeacherHomeworkDetailState get detail =>
      container.read(teacherHomeworkDetailControllerProvider(target));

  TeacherTopicResultPairState get pair =>
      container.read(teacherTopicResultPairControllerProvider(_topicId));

  TeacherHomeworkRouteMutationActivityController get activityController =>
      container.read(
        teacherHomeworkRouteMutationActivityProvider(target).notifier,
      );

  TeacherHomeworkRouteMutationActivityState get activity =>
      container.read(teacherHomeworkRouteMutationActivityProvider(target));

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    AppDeviceSurface.desktop,
  ).eligibleKey!;
}

class _FakePairRepository implements TeacherTopicResultPairRepository {
  _FakePairRepository({this.initial, this.onFetch});

  final TeacherTopicResultPair? initial;
  final Future<TeacherTopicResultPair?> Function(String topicId)? onFetch;
  final fetchRequests = <String>[];

  @override
  Future<TeacherTopicResultPair?> fetchResultPair(String topicId) {
    fetchRequests.add(topicId);
    return onFetch?.call(topicId) ?? Future.value(initial);
  }

  @override
  Future<TeacherTopicResultPair> setOfficialHomework(
    String topicId,
    String homeworkId,
  ) {
    throw UnimplementedError(
      'Official writes are not used by lifecycle tests.',
    );
  }
}

TeacherTopicResultPair _pair({
  String topicId = _topicId,
  String homeworkId = _homeworkId,
}) {
  return TeacherTopicResultPair(
    id: '40000000-0000-0000-0000-000000000001',
    topicId: topicId,
    homeworkAssessmentId: homeworkId,
    blitzAssessmentId: null,
    cohortSnapshottedAt: null,
    lockedAt: null,
    designatedAt: DateTime.utc(2026, 9, 3, 10),
    createdAt: DateTime.utc(2026, 9, 3, 10),
    updatedAt: DateTime.utc(2026, 9, 3, 10),
  );
}
