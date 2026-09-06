import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_official_homework_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_official_homework_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_lifecycle.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair_repository.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _otherTopicId = '10000000-0000-0000-0000-000000000002';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _otherHomeworkId = '50000000-0000-0000-0000-000000000002';

void main() {
  group('official Homework eligibility', () {
    test('offers no-pair draft/active and unlocked replacement candidates', () {
      for (final status in [
        TeacherHomeworkStatus.draft,
        TeacherHomeworkStatus.active,
      ]) {
        expect(
          canSubmitOfficialHomework(
            homework: teacherHomework(status: status),
            pairState: _confirmedPairState(),
          ),
          isTrue,
        );
      }

      expect(
        canSubmitOfficialHomework(
          homework: teacherHomework(),
          pairState: _confirmedPairState(_pair(homeworkId: _otherHomeworkId)),
        ),
        isTrue,
      );
    });

    test(
      'rejects selected, terminal, current, locked, and Blitz candidates',
      () {
        final candidates =
            <({TeacherHomework homework, TeacherTopicResultPair? pair})>[
              (
                homework: teacherHomework(
                  assignmentMode:
                      TeacherHomeworkAssignmentMode.selectedStudents,
                ),
                pair: null,
              ),
              (
                homework: teacherHomework(status: TeacherHomeworkStatus.closed),
                pair: null,
              ),
              (
                homework: teacherHomework(
                  status: TeacherHomeworkStatus.archived,
                ),
                pair: null,
              ),
              (homework: teacherHomework(), pair: _pair()),
              (
                homework: teacherHomework(),
                pair: _pair(
                  homeworkId: _otherHomeworkId,
                  cohortSnapshottedAt: DateTime.utc(2026, 9, 3, 10, 1),
                  lockedAt: DateTime.utc(2026, 9, 3, 10, 2),
                ),
              ),
              (
                homework: teacherHomework(),
                pair: _pair(
                  homeworkId: _otherHomeworkId,
                  blitzId: '30000000-0000-0000-0000-000000000001',
                ),
              ),
            ];

        for (final candidate in candidates) {
          expect(
            canSubmitOfficialHomework(
              homework: candidate.homework,
              pairState: _confirmedPairState(candidate.pair),
            ),
            isFalse,
          );
        }
      },
    );
  });

  group('TeacherOfficialHomeworkController', () {
    test(
      'designates no-pair draft and active Homework and publishes pair',
      () async {
        for (final status in [
          TeacherHomeworkStatus.draft,
          TeacherHomeworkStatus.active,
        ]) {
          final harness = _Harness(homework: teacherHomework(status: status));
          final subscription = harness.listenOfficial();
          await flushTeacherControllers();

          await harness.controller.setOfficial();

          expect(harness.pairs.setRequests, [
            (topicId: _topicId, homeworkId: _homeworkId),
          ]);
          expect(
            subscription.read().status,
            TeacherOfficialHomeworkStatus.confirmedSuccess,
          );
          expect(
            subscription.read().feedback,
            'Official Homework updated successfully.',
          );
          expect(harness.pairState.pair?.homeworkAssessmentId, _homeworkId);
        }
      },
    );

    test('replaces another eligible official Homework', () async {
      final harness = _Harness(
        initialPair: _pair(homeworkId: _otherHomeworkId),
      );
      final subscription = harness.listenOfficial();
      await flushTeacherControllers();

      await harness.controller.setOfficial();

      expect(harness.pairs.setRequests, hasLength(1));
      expect(
        subscription.read().status,
        TeacherOfficialHomeworkStatus.confirmedSuccess,
      );
      expect(harness.pairState.pair?.homeworkAssessmentId, _homeworkId);
    });

    test(
      'does not invoke the repository for locally ineligible candidates',
      () async {
        final candidates =
            <({TeacherHomework homework, TeacherTopicResultPair? pair})>[
              (
                homework: teacherHomework(
                  assignmentMode:
                      TeacherHomeworkAssignmentMode.selectedStudents,
                ),
                pair: null,
              ),
              (
                homework: teacherHomework(status: TeacherHomeworkStatus.closed),
                pair: null,
              ),
              (
                homework: teacherHomework(
                  status: TeacherHomeworkStatus.archived,
                ),
                pair: null,
              ),
              (homework: teacherHomework(), pair: _pair()),
              (
                homework: teacherHomework(),
                pair: _pair(
                  homeworkId: _otherHomeworkId,
                  cohortSnapshottedAt: DateTime.utc(2026, 9, 3, 10, 1),
                  lockedAt: DateTime.utc(2026, 9, 3, 10, 2),
                ),
              ),
              (
                homework: teacherHomework(),
                pair: _pair(
                  homeworkId: _otherHomeworkId,
                  blitzId: '30000000-0000-0000-0000-000000000001',
                ),
              ),
            ];

        for (final candidate in candidates) {
          final harness = _Harness(
            homework: candidate.homework,
            initialPair: candidate.pair,
          );
          final subscription = harness.listenOfficial();
          await flushTeacherControllers();

          await harness.controller.setOfficial();

          expect(harness.pairs.setRequests, isEmpty);
          expect(
            subscription.read().status,
            TeacherOfficialHomeworkStatus.idle,
          );
        }
      },
    );

    test(
      'accepts a matching direct response after local state becomes stale',
      () async {
        final pending = Completer<TeacherTopicResultPair>();
        final pairs = _FakeResultPairRepository(
          onSet: (_, _) => pending.future,
        );
        final harness = _Harness(pairs: pairs);
        final subscription = harness.listenOfficial();
        await flushTeacherControllers();

        final submission = harness.controller.setOfficial();
        expect(
          subscription.read().status,
          TeacherOfficialHomeworkStatus.submitting,
        );
        final matchingLocked = _pair(
          cohortSnapshottedAt: DateTime.utc(2026, 9, 3, 10, 1),
          lockedAt: DateTime.utc(2026, 9, 3, 10, 2),
        );
        harness.pairController.acceptAuthoritativePair(
          matchingLocked,
          harness.sessionKey,
        );
        pending.complete(matchingLocked);
        await submission;

        expect(
          subscription.read().status,
          TeacherOfficialHomeworkStatus.confirmedSuccess,
        );
        expect(harness.pairState.pair, same(matchingLocked));
        expect(pairs.setRequests, hasLength(1));
      },
    );

    test(
      'unknown PUT plus matching GET confirms success without replay',
      () async {
        var fetchCount = 0;
        final pairs = _FakeResultPairRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return fetchCount == 1 ? null : _pair();
          },
          onSet: (_, _) async =>
              throw const TeacherTopicResultPairMutationOutcomeUnknownException(),
        );
        final harness = _Harness(pairs: pairs);
        final subscription = harness.listenOfficial();
        await flushTeacherControllers();

        await harness.controller.setOfficial();

        expect(
          subscription.read().status,
          TeacherOfficialHomeworkStatus.confirmedSuccess,
        );
        expect(harness.pairState.pair?.homeworkAssessmentId, _homeworkId);
        expect(pairs.fetchRequests, [_topicId, _topicId]);
        expect(pairs.setRequests, hasLength(1));
      },
    );

    test('dual-ID response mismatches reconcile before publication', () async {
      for (final mismatch in [
        _pair(topicId: _otherTopicId),
        _pair(homeworkId: _otherHomeworkId),
      ]) {
        var fetchCount = 0;
        final pairs = _FakeResultPairRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return fetchCount == 1 ? null : _pair();
          },
          onSet: (_, _) async => mismatch,
        );
        final harness = _Harness(pairs: pairs);
        final subscription = harness.listenOfficial();
        await flushTeacherControllers();

        await harness.controller.setOfficial();

        expect(
          subscription.read().status,
          TeacherOfficialHomeworkStatus.confirmedSuccess,
        );
        expect(harness.pairState.pair?.topicId, _topicId);
        expect(harness.pairState.pair?.homeworkAssessmentId, _homeworkId);
        expect(pairs.fetchRequests, [_topicId, _topicId]);
        expect(pairs.setRequests, hasLength(1));
      }
    });

    test('unknown PUT plus different or null GET remains unconfirmed', () async {
      for (final reconciled in <TeacherTopicResultPair?>[
        null,
        _pair(homeworkId: _otherHomeworkId),
      ]) {
        var fetchCount = 0;
        final pairs = _FakeResultPairRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return fetchCount == 1 ? null : reconciled;
          },
          onSet: (_, _) async =>
              throw const TeacherTopicResultPairMutationOutcomeUnknownException(),
        );
        final harness = _Harness(pairs: pairs);
        final subscription = harness.listenOfficial();
        await flushTeacherControllers();

        await harness.controller.setOfficial();

        expect(
          subscription.read().status,
          TeacherOfficialHomeworkStatus.outcomeReview,
        );
        expect(subscription.read().requiresCurrentCheck, isFalse);
        expect(harness.pairState.pair, same(reconciled));
        expect(pairs.setRequests, hasLength(1));
      }
    });

    test(
      'failed reconciliation blocks mutation and Check current sends GET only',
      () async {
        var fetchCount = 0;
        final pairs = _FakeResultPairRepository(
          onFetch: (_) async {
            fetchCount += 1;
            if (fetchCount == 1) {
              return null;
            }
            if (fetchCount == 2) {
              throw teacherLocalFailure(ApiFailureKind.timeout);
            }
            return _pair();
          },
          onSet: (_, _) async =>
              throw const TeacherTopicResultPairMutationOutcomeUnknownException(),
        );
        final harness = _Harness(pairs: pairs);
        final subscription = harness.listenOfficial();
        await flushTeacherControllers();

        await harness.controller.setOfficial();

        expect(subscription.read().canCheckCurrent, isTrue);
        expect(harness.activityState.outcomeReviewBlocking, isTrue);
        await harness.controller.setOfficial();
        expect(pairs.setRequests, hasLength(1));

        await harness.controller.checkCurrentOfficialHomework();

        expect(
          subscription.read().status,
          TeacherOfficialHomeworkStatus.confirmedSuccess,
        );
        expect(pairs.fetchRequests, [_topicId, _topicId, _topicId]);
        expect(pairs.setRequests, hasLength(1));
      },
    );

    test('publishes exact definite conflicts and 404 after safe refresh', () async {
      final failures = <(int, String, String)>[
        (
          409,
          ApiErrorCodes.officialTaskRequiresGroupAssignment,
          'Only whole-group Homework can be the official Homework.',
        ),
        (
          409,
          ApiErrorCodes.resultPairLocked,
          'Official Homework selection is locked by the current server state.',
        ),
        (
          409,
          ApiErrorCodes.businessConflict,
          'This Homework cannot become the official Homework in the current server state.\nReview the current Homework and Topic.',
        ),
        (
          409,
          ApiErrorCodes.topicNotEditable,
          'The Topic is no longer editable.',
        ),
        (
          404,
          ApiErrorCodes.resourceNotFound,
          'The requested Homework or Topic is no longer available in your current Teacher workspace.',
        ),
        (
          422,
          ApiErrorCodes.validationFailed,
          'The official Homework selection could not be validated.\nRefresh and review the current state.',
        ),
      ];

      for (final failure in failures) {
        final pairs = _FakeResultPairRepository(
          onSet: (_, _) async =>
              throw teacherServerFailure(failure.$2, statusCode: failure.$1),
        );
        final homework = _FakeHomeworkRepository(teacherHomework());
        final harness = _Harness(pairs: pairs, homeworkRepository: homework);
        final subscription = harness.listenOfficial();
        await flushTeacherControllers();

        await harness.controller.setOfficial();

        expect(
          subscription.read().status,
          TeacherOfficialHomeworkStatus.definiteFailure,
        );
        expect(subscription.read().conflictCode, failure.$2);
        expect(subscription.read().feedback, failure.$3);
        expect(pairs.setRequests, hasLength(1));
        expect(
          pairs.fetchRequests,
          failure.$1 == 422 ? [_topicId] : [_topicId, _topicId],
        );
        expect(
          homework.fetchRequests,
          failure.$1 == 422 ? [_homeworkId] : [_homeworkId, _homeworkId],
        );
      }
    });

    test('a lifecycle lease suppresses a rapid official mutation', () async {
      final harness = _Harness();
      final subscription = harness.listenOfficial();
      await flushTeacherControllers();
      final activity = harness.activityController;
      final lease = activity.begin(
        TeacherHomeworkRouteMutationOperation.lifecycle,
      );
      expect(lease, isNotNull);

      await harness.controller.setOfficial();

      expect(harness.pairs.setRequests, isEmpty);
      expect(subscription.read().status, TeacherOfficialHomeworkStatus.idle);
      activity.release(lease!);
      await harness.controller.setOfficial();
      expect(harness.pairs.setRequests, hasLength(1));
    });

    test('a replacement session rejects a pending completion', () async {
      final pending = Completer<TeacherTopicResultPair>();
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final pairs = _FakeResultPairRepository(onSet: (_, _) => pending.future);
      final harness = _Harness(auth: auth, pairs: pairs);
      final subscription = harness.listenOfficial();
      await flushTeacherControllers();

      final submission = harness.controller.setOfficial();
      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(_pair());
      await submission;
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherOfficialHomeworkStatus.idle);
      expect(subscription.read().feedback, isNull);
      expect(pairs.setRequests, hasLength(1));
    });

    test('leaving the route target rejects a pending completion', () async {
      final pending = Completer<TeacherTopicResultPair>();
      final pairs = _FakeResultPairRepository(onSet: (_, _) => pending.future);
      final harness = _Harness(pairs: pairs);
      final subscription = harness.listenOfficial();
      await flushTeacherControllers();

      final submission = harness.controller.setOfficial();
      harness.controller.leaveRoute();
      pending.complete(_pair());
      await submission;

      expect(subscription.read().status, TeacherOfficialHomeworkStatus.idle);
      expect(subscription.read().feedback, isNull);
    });

    test('provider disposal rejects a pending completion', () async {
      final pending = Completer<TeacherTopicResultPair>();
      final pairs = _FakeResultPairRepository(onSet: (_, _) => pending.future);
      final harness = _Harness(pairs: pairs);
      final observed = <TeacherOfficialHomeworkState>[];
      final subscription = harness.container.listen(
        teacherOfficialHomeworkControllerProvider(harness.target),
        (_, next) => observed.add(next),
        fireImmediately: true,
      );
      await flushTeacherControllers();

      final submission = harness.controller.setOfficial();
      subscription.close();
      await flushTeacherControllers();
      final observationsAtDisposal = observed.length;
      pending.complete(_pair());
      await submission;
      await flushTeacherControllers();

      expect(observed, hasLength(observationsAtDisposal));
      expect(pairs.setRequests, hasLength(1));
    });
  });
}

class _Harness {
  _Harness({
    TeacherHomework? homework,
    TeacherTopicResultPair? initialPair,
    _FakeResultPairRepository? pairs,
    _FakeHomeworkRepository? homeworkRepository,
    FakeTeacherAuthSessionController? auth,
  }) : auth =
           auth ??
           FakeTeacherAuthSessionController.authenticated(
             teacherUser('teacher-a'),
           ),
       pairs = pairs ?? _FakeResultPairRepository(initialPair: initialPair),
       homework =
           homeworkRepository ??
           _FakeHomeworkRepository(homework ?? teacherHomework()) {
    target = TeacherHomeworkRouteTarget(
      topicId: _topicId,
      homeworkId: _homeworkId,
    );
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(this.pairs),
        teacherHomeworkRepositoryProvider.overrideWithValue(this.homework),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final _FakeResultPairRepository pairs;
  final _FakeHomeworkRepository homework;
  late final TeacherHomeworkRouteTarget target;
  late final ProviderContainer container;

  ProviderSubscription<TeacherOfficialHomeworkState> listenOfficial() {
    return container.listen(
      teacherOfficialHomeworkControllerProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherOfficialHomeworkController get controller => container.read(
    teacherOfficialHomeworkControllerProvider(target).notifier,
  );

  TeacherTopicResultPairController get pairController => container.read(
    teacherTopicResultPairControllerProvider(_topicId).notifier,
  );

  TeacherTopicResultPairState get pairState =>
      container.read(teacherTopicResultPairControllerProvider(_topicId));

  TeacherHomeworkRouteMutationActivityController get activityController =>
      container.read(
        teacherHomeworkRouteMutationActivityProvider(target).notifier,
      );

  TeacherHomeworkRouteMutationActivityState get activityState =>
      container.read(teacherHomeworkRouteMutationActivityProvider(target));

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    AppDeviceSurface.desktop,
  ).eligibleKey!;
}

class _FakeResultPairRepository implements TeacherTopicResultPairRepository {
  _FakeResultPairRepository({this.initialPair, this.onFetch, this.onSet});

  final TeacherTopicResultPair? initialPair;
  final Future<TeacherTopicResultPair?> Function(String topicId)? onFetch;
  final Future<TeacherTopicResultPair> Function(
    String topicId,
    String homeworkId,
  )?
  onSet;
  final fetchRequests = <String>[];
  final setRequests = <({String topicId, String homeworkId})>[];

  @override
  Future<TeacherTopicResultPair?> fetchResultPair(String topicId) {
    fetchRequests.add(topicId);
    return onFetch?.call(topicId) ?? Future.value(initialPair);
  }

  @override
  Future<TeacherTopicResultPair> setOfficialHomework(
    String topicId,
    String homeworkId,
  ) {
    setRequests.add((topicId: topicId, homeworkId: homeworkId));
    return onSet?.call(topicId, homeworkId) ??
        Future.value(_pair(topicId: topicId, homeworkId: homeworkId));
  }
}

class _FakeHomeworkRepository implements TeacherHomeworkRepository {
  _FakeHomeworkRepository(this.initial);

  final TeacherHomework initial;
  final fetchRequests = <String>[];

  @override
  Future<TeacherHomework> fetchHomework(String homeworkId) {
    fetchRequests.add(homeworkId);
    return Future.value(initial);
  }

  @override
  Future<TeacherHomeworkList> fetchHomeworkList(
    String topicId,
    TeacherHomeworkListQuery query,
  ) {
    throw UnimplementedError('List reads are not used by official tests.');
  }

  @override
  Future<TeacherHomework> createHomework(
    String topicId,
    TeacherHomeworkCreateRequest request,
  ) {
    throw UnimplementedError('Authoring is not used by official tests.');
  }

  @override
  Future<TeacherHomework> updateHomework(
    String homeworkId,
    TeacherHomeworkEditRequest request,
  ) {
    throw UnimplementedError('Authoring is not used by official tests.');
  }

  @override
  Future<TeacherHomework> performLifecycleAction(
    String homeworkId,
    TeacherHomeworkLifecycleAction action,
  ) {
    throw UnimplementedError('Lifecycle is not used by official tests.');
  }

  @override
  Future<TeacherHomework> addQuestion(
    String homeworkId,
    TeacherQuestionCreateRequest request,
  ) {
    throw UnimplementedError('Questions are not used by official tests.');
  }

  @override
  Future<TeacherHomework> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  ) {
    throw UnimplementedError('Questions are not used by official tests.');
  }

  @override
  Future<TeacherHomework> deleteQuestion(String questionId) {
    throw UnimplementedError('Questions are not used by official tests.');
  }

  @override
  Future<TeacherHomework> reorderQuestions(
    String homeworkId,
    TeacherQuestionReorderRequest request,
  ) {
    throw UnimplementedError('Questions are not used by official tests.');
  }
}

TeacherTopicResultPairState _confirmedPairState([
  TeacherTopicResultPair? pair,
]) {
  return TeacherTopicResultPairState(
    status: TeacherTopicResultPairStatus.data,
    pair: pair,
  );
}

TeacherTopicResultPair _pair({
  String topicId = _topicId,
  String homeworkId = _homeworkId,
  String? blitzId,
  DateTime? cohortSnapshottedAt,
  DateTime? lockedAt,
}) {
  return TeacherTopicResultPair(
    id: '40000000-0000-0000-0000-000000000001',
    topicId: topicId,
    homeworkAssessmentId: homeworkId,
    blitzAssessmentId: blitzId,
    cohortSnapshottedAt: cohortSnapshottedAt,
    lockedAt: lockedAt,
    designatedAt: DateTime.utc(2026, 9, 3, 10),
    createdAt: DateTime.utc(2026, 9, 3, 10),
    updatedAt: lockedAt ?? cohortSnapshottedAt ?? DateTime.utc(2026, 9, 3, 10),
  );
}
