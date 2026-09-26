import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_official_blitz_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_official_blitz_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_state.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _otherBlitzId = '80000000-0000-0000-0000-000000000002';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  group('official Blitz option projection', () {
    TeacherOfficialBlitzOption option(
      TeacherBlitz blitz,
      TeacherTopicResultPair? pair, {
      bool confirmed = true,
    }) {
      return teacherOfficialBlitzOption(
        blitz: blitz,
        pairState: TeacherTopicResultPairState(
          status: confirmed
              ? TeacherTopicResultPairStatus.data
              : TeacherTopicResultPairStatus.loading,
          pair: pair,
        ),
      );
    }

    final locked = DateTime.utc(2026, 9, 20);

    test('no pair asks for the official Homework first', () {
      expect(
        option(teacherBlitz(), null),
        TeacherOfficialBlitzOption.requiresOfficialHomework,
      );
      expect(
        canSubmitOfficialBlitz(
          blitz: teacherBlitz(),
          pairState: const TeacherTopicResultPairState(
            status: TeacherTopicResultPairStatus.data,
          ),
        ),
        isFalse,
      );
    });

    test('an empty Blitz side can be filled even when the pair is locked', () {
      expect(option(teacherBlitz(), _pair()), TeacherOfficialBlitzOption.set);
      expect(
        option(teacherBlitz(), _pair(lockedAt: locked)),
        TeacherOfficialBlitzOption.fillLocked,
      );
      expect(
        canSubmitOfficialBlitz(
          blitz: teacherBlitz(),
          pairState: TeacherTopicResultPairState(
            status: TeacherTopicResultPairStatus.data,
            pair: _pair(lockedAt: locked),
          ),
        ),
        isTrue,
      );
    });

    test('another official Blitz is replaceable only while unlocked', () {
      expect(
        option(teacherBlitz(), _pair(blitzId: _otherBlitzId)),
        TeacherOfficialBlitzOption.replace,
      );
      expect(
        option(teacherBlitz(), _pair(blitzId: _otherBlitzId, lockedAt: locked)),
        TeacherOfficialBlitzOption.lockedByOther,
      );
    });

    test('the current official Blitz stays official in every lifecycle', () {
      for (final status in TeacherBlitzStatus.values) {
        expect(
          option(teacherBlitz(status: status), _pair(blitzId: _blitzId)),
          TeacherOfficialBlitzOption.official,
          reason: status.value,
        );
      }
    });

    test(
      'selected, non-preparation and unconfirmed candidates are blocked',
      () {
        expect(
          option(
            teacherBlitz(
              assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
            ),
            _pair(),
          ),
          TeacherOfficialBlitzOption.selectedStudents,
        );
        for (final status in [
          TeacherBlitzStatus.active,
          TeacherBlitzStatus.closed,
          TeacherBlitzStatus.archived,
        ]) {
          expect(
            option(teacherBlitz(status: status), _pair()),
            TeacherOfficialBlitzOption.notCandidate,
          );
        }
        expect(
          option(teacherBlitz(), _pair(), confirmed: false),
          TeacherOfficialBlitzOption.unconfirmed,
        );
      },
    );
  });

  group('TeacherOfficialBlitzController', () {
    test('sends the current Homework ID and publishes the pair', () async {
      final harness = _Harness(pair: _pair());
      await harness.start();

      await harness.controller.setOfficial();

      final request = harness.pairs.setOfficialBlitzRequests.single;
      expect(request.topicId, _topicId);
      expect(request.homeworkId, _homeworkId);
      expect(request.blitzId, _blitzId);
      expect(harness.state.status, TeacherOfficialBlitzStatus.confirmedSuccess);
      expect(harness.state.feedback, 'Official Blitz updated successfully.');
      expect(harness.pairState.pair?.blitzAssessmentId, _blitzId);
      expect(harness.activity.isActive, isFalse);
    });

    test('a locked partial pair is filled with the same request', () async {
      final harness = _Harness(
        pair: _pair(lockedAt: DateTime.utc(2026, 9, 20)),
      );
      await harness.start();

      await harness.controller.setOfficial();

      expect(harness.pairs.setOfficialBlitzRequests, hasLength(1));
      expect(harness.state.status, TeacherOfficialBlitzStatus.confirmedSuccess);
    });

    test('blocked options never send a PUT', () async {
      for (final (blitz, pair) in [
        (teacherBlitz(), null),
        (teacherBlitz(), _pair(blitzId: _blitzId)),
        (
          teacherBlitz(),
          _pair(blitzId: _otherBlitzId, lockedAt: DateTime.utc(2026, 9, 20)),
        ),
        (
          teacherBlitz(
            assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
          ),
          _pair(),
        ),
        (teacherBlitz(status: TeacherBlitzStatus.active), _pair()),
      ]) {
        final harness = _Harness(blitz: blitz, pair: pair);
        await harness.start();

        await harness.controller.setOfficial();

        expect(harness.pairs.setOfficialBlitzRequests, isEmpty);
      }
    });

    test('an uncertain PUT is success only for the exact pair', () async {
      for (final (current, confirmed) in [
        (_pair(blitzId: _blitzId), true),
        (_pair(blitzId: _otherBlitzId), false),
      ]) {
        var reads = 0;
        final harness = _Harness(
          pairReads: (_) async {
            reads += 1;
            return reads == 1 ? _pair() : current;
          },
          onSet: (_, _, _) async =>
              throw const TeacherTopicResultPairMutationOutcomeUnknownException(),
        );
        await harness.start();

        await harness.controller.setOfficial();

        expect(harness.pairs.setOfficialBlitzRequests, hasLength(1));
        if (confirmed) {
          expect(
            harness.state.status,
            TeacherOfficialBlitzStatus.confirmedSuccess,
          );
        } else {
          expect(
            harness.state.status,
            TeacherOfficialBlitzStatus.outcomeReview,
          );
          expect(
            harness.state.notice,
            'The official Blitz update could not be confirmed.\nReview the '
            'current official Homework and Blitz before trying again.',
          );
          expect(harness.state.canCheckCurrent, isTrue);
        }
      }
    });

    test('definite conflicts refresh state and map safe copy', () async {
      for (final (code, notice) in [
        (
          ApiErrorCodes.resultPairLocked,
          'Official Blitz selection is locked by the current server state.',
        ),
        (
          ApiErrorCodes.officialTaskRequiresGroupAssignment,
          'Only a whole-group Blitz can be the official Blitz.',
        ),
        (
          ApiErrorCodes.businessConflict,
          'This Blitz cannot become the official Blitz in the current server '
              'state.\nRefresh the Blitz and official pair before trying again.',
        ),
        (ApiErrorCodes.topicNotEditable, 'The Topic is no longer editable.'),
      ]) {
        final harness = _Harness(
          pair: _pair(),
          onSet: (_, _, _) async =>
              throw teacherServerFailure(code, statusCode: 409),
        );
        await harness.start();
        final pairReads = harness.pairs.fetchTopicIds.length;
        final blitzReads = harness.blitz.fetchIds.length;

        await harness.controller.setOfficial();

        expect(
          harness.state.status,
          TeacherOfficialBlitzStatus.definiteFailure,
        );
        expect(harness.state.notice, notice, reason: code);
        expect(harness.pairs.fetchTopicIds.length, pairReads + 1);
        expect(harness.blitz.fetchIds.length, blitzReads + 1);
        expect(harness.pairs.setOfficialBlitzRequests, hasLength(1));
      }
    });

    test('a completion after a session change is ignored', () async {
      final pending = Completer<TeacherTopicResultPair>();
      final harness = _Harness(
        pair: _pair(),
        onSet: (_, _, _) => pending.future,
      );
      await harness.start();
      unawaited(harness.controller.setOfficial());
      await flushTeacherControllers();

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(_pair(blitzId: _blitzId));
      await flushTeacherControllers();

      expect(harness.state.feedback, isNull);
    });

    test('an unreadable pair blocks until the current pair is checked', () async {
      var reads = 0;
      final harness = _Harness(
        pairReads: (_) async {
          reads += 1;
          if (reads == 2) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return reads == 1 ? _pair() : _pair(blitzId: _blitzId);
        },
        onSet: (_, _, _) async =>
            throw const TeacherTopicResultPairMutationOutcomeUnknownException(),
      );
      await harness.start();

      await harness.controller.setOfficial();

      expect(harness.state.hasBlockingOutcome, isTrue);
      expect(harness.activity.isActive, isTrue);

      await harness.controller.checkCurrentOfficialPair();

      expect(harness.state.status, TeacherOfficialBlitzStatus.confirmedSuccess);
      expect(harness.activity.isActive, isFalse);
      expect(harness.pairs.setOfficialBlitzRequests, hasLength(1));
    });

    test('a lifecycle lease blocks designation', () async {
      final harness = _Harness(pair: _pair());
      await harness.start();
      harness.container
          .read(teacherBlitzRouteMutationActivityProvider(_target()).notifier)
          .begin(TeacherBlitzRouteMutationOperation.activate);

      await harness.controller.setOfficial();

      expect(harness.pairs.setOfficialBlitzRequests, isEmpty);
    });
  });
}

TeacherBlitzRouteTarget _target() {
  return TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId);
}

TeacherTopicResultPair _pair({String? blitzId, DateTime? lockedAt}) {
  return TeacherTopicResultPair(
    id: '95000000-0000-0000-0000-000000000001',
    topicId: _topicId,
    homeworkAssessmentId: _homeworkId,
    blitzAssessmentId: blitzId,
    cohortSnapshottedAt: lockedAt,
    lockedAt: lockedAt,
    designatedAt: DateTime.utc(2026, 9, 17, 12),
    createdAt: DateTime.utc(2026, 9, 17, 12),
    updatedAt: DateTime.utc(2026, 9, 17, 12),
  );
}

class _Harness {
  _Harness({
    TeacherBlitz? blitz,
    TeacherTopicResultPair? pair,
    Future<TeacherTopicResultPair?> Function(String topicId)? pairReads,
    Future<TeacherTopicResultPair> Function(
      String topicId,
      String homeworkId,
      String blitzId,
    )?
    onSet,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ),
       blitz = FakeTeacherBlitzRepository(
         onFetch: (_) async => blitz ?? teacherBlitz(),
       ),
       pairs = FakeTeacherTopicResultPairRepository(
         onFetch: pairReads ?? (_) async => pair,
         onSetOfficialBlitz: onSet,
       ) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherBlitzRepositoryProvider.overrideWithValue(this.blitz),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(pairs),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherBlitzRepository blitz;
  final FakeTeacherTopicResultPairRepository pairs;
  late final ProviderContainer container;
  late ProviderSubscription<TeacherOfficialBlitzState> _subscription;

  Future<void> start() async {
    container
      ..listen(teacherBlitzDetailControllerProvider(_target()), (_, _) {})
      ..listen(teacherTopicResultPairControllerProvider(_topicId), (_, _) {})
      ..listen(teacherBlitzRouteMutationActivityProvider(_target()), (_, _) {});
    _subscription = container.listen(
      teacherOfficialBlitzControllerProvider(_target()),
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
  }

  TeacherOfficialBlitzController get controller => container.read(
    teacherOfficialBlitzControllerProvider(_target()).notifier,
  );

  TeacherOfficialBlitzState get state => _subscription.read();

  TeacherTopicResultPairState get pairState =>
      container.read(teacherTopicResultPairControllerProvider(_topicId));

  TeacherBlitzRouteMutationActivityState get activity =>
      container.read(teacherBlitzRouteMutationActivityProvider(_target()));
}
