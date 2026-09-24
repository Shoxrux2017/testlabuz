import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_edit_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_edit_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_pair_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_form.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';
const _studentA = '60000000-0000-0000-0000-00000000000a';

void main() {
  group('TeacherBlitzEditController context', () {
    test('loads Draft and Scheduled Blitz into an editable form', () async {
      for (final status in [
        TeacherBlitzStatus.draft,
        TeacherBlitzStatus.scheduled,
      ]) {
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onFetch: (id) async => teacherBlitz(
              id: id,
              status: status,
              durationSeconds: 90,
              scheduledAt: DateTime.utc(2026, 9, 18, 4),
            ),
          ),
        );
        final subscription = harness.listen();
        await flushTeacherControllers();

        final state = subscription.read();
        expect(state.status, TeacherBlitzEditStatus.editing, reason: '$status');
        expect(state.form!.durationSecondsText, '90');
        expect(state.canEdit, isTrue);
        expect(state.isDirty, isFalse);
        expect(state.officialAssignmentLocked, isFalse);
      }
    });

    test('Active, Closed, and Archived Blitz are not editable', () async {
      for (final status in [
        TeacherBlitzStatus.active,
        TeacherBlitzStatus.closed,
        TeacherBlitzStatus.archived,
      ]) {
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onFetch: (id) async => teacherBlitz(id: id, status: status),
          ),
        );
        final subscription = harness.listen();
        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherBlitzEditStatus.lifecycleUnavailable,
        );
        expect(
          subscription.read().formError,
          'Blitz editing is no longer available.',
        );
        expect(subscription.read().canEdit, isFalse);
      }
    });

    test('a lifecycle change while editing retires the draft', () async {
      var reads = 0;
      final harness = _Harness(
        blitz: FakeTeacherBlitzRepository(
          onFetch: (id) async {
            reads += 1;
            return teacherBlitz(
              id: id,
              status: reads == 1
                  ? TeacherBlitzStatus.draft
                  : TeacherBlitzStatus.active,
            );
          },
        ),
      );
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();
      controller.updateTitle('Unsaved title');

      harness.container
          .read(teacherBlitzDetailControllerProvider(_target()).notifier)
          .refresh();
      await flushTeacherControllers();

      expect(
        subscription.read().status,
        TeacherBlitzEditStatus.lifecycleUnavailable,
      );
      await controller.submit();
      expect(harness.blitz.updateRequests, isEmpty);
    });
  });

  group('TeacherBlitzEditController save', () {
    test('a no-op Save sends no request', () async {
      final harness = _Harness();
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();

      await controller.submit();

      expect(harness.blitz.updateRequests, isEmpty);
      expect(subscription.read().formError, 'No changes to save.');
      expect(subscription.read().status, TeacherBlitzEditStatus.editing);
    });

    test(
      'sends only changed fields and adopts the authoritative result',
      () async {
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onFetch: (id) async => teacherBlitz(
              id: id,
              status: TeacherBlitzStatus.scheduled,
              scheduledAt: DateTime.utc(2026, 9, 18, 4),
            ),
            onUpdate: (id, _) async => teacherBlitz(
              id: id,
              title: 'Renamed Blitz',
              durationSeconds: 90,
              status: TeacherBlitzStatus.scheduled,
              scheduledAt: DateTime.utc(2026, 9, 18, 4),
            ),
          ),
        );
        final subscription = harness.listen();
        harness.container.listen(
          teacherBlitzListControllerProvider(_topicId),
          (_, _) {},
        );
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        final listReadsBefore = harness.blitz.listRequests.length;
        final detailReadsBefore = harness.blitz.fetchIds.length;
        controller
          ..updateTitle('  Renamed Blitz ')
          ..updateDurationSeconds('90');

        await controller.submit();
        await flushTeacherControllers();

        expect(harness.blitz.updateRequests.single.request.toJson(), {
          'title': 'Renamed Blitz',
          'duration_seconds': 90,
        });
        expect(
          subscription.read().status,
          TeacherBlitzEditStatus.confirmedSuccess,
        );
        final detail = harness.container.read(
          teacherBlitzDetailControllerProvider(_target()),
        );
        expect(detail.blitz!.title, 'Renamed Blitz');
        expect(harness.blitz.fetchIds.length, detailReadsBefore);
        expect(harness.blitz.listRequests.length, listReadsBefore + 1);
      },
    );

    test('assignment transitions send mode and Students together', () async {
      final harness = _Harness();
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();

      controller.updateAssignmentMode(
        TeacherBlitzAssignmentMode.selectedStudents,
      );
      final launch = controller.beginStudentPicker()!;
      expect(launch.target.groupId, '00000000-0000-0000-0000-000000000001');
      controller.applyStudentSelection({_studentA}, launch.owner);
      expect(subscription.read().isDirty, isTrue);

      await controller.submit();

      expect(harness.blitz.updateRequests.single.request.toJson(), {
        'assignment_mode': 'selected_students',
        'student_ids': [_studentA],
      });
    });

    test('a confirmed official Blitz keeps whole-group assignment', () async {
      final harness = _Harness(
        pairs: FakeTeacherTopicResultPairRepository(
          onFetch: (_) async =>
              teacherResultPair(blitzAssessmentId: _blitzId.toUpperCase()),
        ),
      );
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();

      expect(subscription.read().officialAssignmentLocked, isTrue);
      controller.updateAssignmentMode(
        TeacherBlitzAssignmentMode.selectedStudents,
      );
      expect(
        subscription.read().form!.assignmentMode,
        TeacherBlitzAssignmentMode.group,
      );
      expect(controller.beginStudentPicker(), isNull);

      controller.updateTitle('Official title');
      await controller.submit();
      expect(harness.blitz.updateRequests.single.request.toJson(), {
        'title': 'Official title',
      });
    });

    test('unconfirmed official state does not lock assignment', () async {
      for (final pair in <Future<TeacherTopicResultPair?> Function()>[
        () => Completer<TeacherTopicResultPair?>().future,
        () async => throw teacherLocalFailure(ApiFailureKind.connection),
        () async => teacherResultPair(
          blitzAssessmentId: '80000000-0000-0000-0000-000000000002',
        ),
      ]) {
        final harness = _Harness(
          pairs: FakeTeacherTopicResultPairRepository(onFetch: (_) => pair()),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();

        expect(subscription.read().officialAssignmentLocked, isFalse);
        controller.updateAssignmentMode(
          TeacherBlitzAssignmentMode.selectedStudents,
        );
        expect(
          subscription.read().form!.assignmentMode,
          TeacherBlitzAssignmentMode.selectedStudents,
        );
      }
    });

    test(
      'an official selected-student Blitz is inconsistent and read-only',
      () async {
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onFetch: (id) async => teacherBlitz(
              id: id,
              assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
            ),
          ),
          pairs: FakeTeacherTopicResultPairRepository(
            onFetch: (_) async =>
                teacherResultPair(blitzAssessmentId: _blitzId),
          ),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherBlitzEditStatus.officialInconsistent,
        );
        expect(
          subscription.read().formError,
          'The current official Blitz assignment is inconsistent. Refresh the '
          'Blitz before editing.',
        );
        controller.updateTitle('Changed');
        await controller.submit();
        expect(harness.blitz.updateRequests, isEmpty);
      },
    );

    test(
      'refreshing an inconsistent official state can resume editing',
      () async {
        var reads = 0;
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onFetch: (id) async {
              reads += 1;
              return teacherBlitz(
                id: id,
                assignmentMode: reads == 1
                    ? TeacherBlitzAssignmentMode.selectedStudents
                    : TeacherBlitzAssignmentMode.group,
              );
            },
          ),
          pairs: FakeTeacherTopicResultPairRepository(
            onFetch: (_) async =>
                teacherResultPair(blitzAssessmentId: _blitzId),
          ),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        expect(
          subscription.read().status,
          TeacherBlitzEditStatus.officialInconsistent,
        );
        final pairReadsBefore = harness.pairs.fetchTopicIds.length;

        controller.refreshAuthoritativeState();
        await flushTeacherControllers();

        expect(harness.pairs.fetchTopicIds.length, pairReadsBefore + 1);
        expect(subscription.read().status, TeacherBlitzEditStatus.editing);
        expect(subscription.read().officialAssignmentLocked, isTrue);
      },
    );

    test('an inconsistent official state waits for a confirmed pair', () async {
      var pairReads = 0;
      final pendingPair = Completer<TeacherTopicResultPair?>();
      final harness = _Harness(
        blitz: FakeTeacherBlitzRepository(
          onFetch: (id) async => teacherBlitz(
            id: id,
            assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
          ),
        ),
        pairs: FakeTeacherTopicResultPairRepository(
          onFetch: (_) {
            pairReads += 1;
            return pairReads == 1
                ? Future.value(teacherResultPair(blitzAssessmentId: _blitzId))
                : pendingPair.future;
          },
        ),
      );
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();

      controller.refreshAuthoritativeState();
      await flushTeacherControllers();

      expect(
        subscription.read().status,
        TeacherBlitzEditStatus.officialInconsistent,
      );
      controller.updateTitle('Changed');
      await controller.submit();
      expect(harness.blitz.updateRequests, isEmpty);

      pendingPair.completeError(teacherLocalFailure(ApiFailureKind.connection));
      await flushTeacherControllers();
      expect(
        subscription.read().status,
        TeacherBlitzEditStatus.officialInconsistent,
      );
    });

    test('a refreshing pair keeps the confirmed official lock', () async {
      var pairReads = 0;
      final pendingPair = Completer<TeacherTopicResultPair?>();
      final harness = _Harness(
        pairs: FakeTeacherTopicResultPairRepository(
          onFetch: (_) {
            pairReads += 1;
            return pairReads == 1
                ? Future.value(teacherResultPair(blitzAssessmentId: _blitzId))
                : pendingPair.future;
          },
        ),
      );
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();
      expect(subscription.read().officialAssignmentLocked, isTrue);

      unawaited(
        harness.container
            .read(teacherTopicResultPairControllerProvider(_topicId).notifier)
            .refresh(),
      );
      await flushTeacherControllers();

      expect(subscription.read().officialAssignmentLocked, isTrue);
      controller.updateAssignmentMode(
        TeacherBlitzAssignmentMode.selectedStudents,
      );
      expect(
        subscription.read().form!.assignmentMode,
        TeacherBlitzAssignmentMode.group,
      );
    });

    test(
      'official assignment conflict refreshes Blitz and pair without retry',
      () async {
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onUpdate: (_, _) async => throw teacherServerFailure(
              ApiErrorCodes.officialTaskRequiresGroupAssignment,
              statusCode: 409,
            ),
          ),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        final pairReadsBefore = harness.pairs.fetchTopicIds.length;
        final blitzReadsBefore = harness.blitz.fetchIds.length;
        controller.updateAssignmentMode(
          TeacherBlitzAssignmentMode.selectedStudents,
        );
        final launch = controller.beginStudentPicker()!;
        controller.applyStudentSelection({_studentA}, launch.owner);

        await controller.submit();
        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherBlitzEditStatus.conflictReview,
        );
        expect(
          subscription.read().formError,
          'The official Blitz must remain assigned to the whole group.',
        );
        expect(harness.blitz.fetchIds.length, greaterThan(blitzReadsBefore));
        expect(
          harness.pairs.fetchTopicIds.length,
          greaterThan(pairReadsBefore),
        );
        expect(harness.blitz.updateRequests, hasLength(1));
      },
    );

    test('lifecycle conflicts become review states with safe copy', () async {
      for (final (code, message) in [
        (
          ApiErrorCodes.taskClosed,
          'This Blitz is closed and cannot be edited.',
        ),
        (
          ApiErrorCodes.taskArchived,
          'This Blitz is archived and cannot be edited.',
        ),
        (ApiErrorCodes.topicNotEditable, 'The Topic is no longer editable.'),
        (
          ApiErrorCodes.businessConflict,
          'Some Blitz settings are locked by current server state. Review '
              'the current Blitz before making another change.',
        ),
      ]) {
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onUpdate: (_, _) async =>
                throw teacherServerFailure(code, statusCode: 409),
          ),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        controller.updateTitle('Changed');

        await controller.submit();

        expect(
          subscription.read().status,
          TeacherBlitzEditStatus.conflictReview,
        );
        expect(subscription.read().formError, message);
        expect(harness.blitz.updateRequests, hasLength(1));
      }
    });

    test('server validation maps editable fields', () async {
      final harness = _Harness(
        blitz: FakeTeacherBlitzRepository(
          onUpdate: (_, _) async => throw ApiRequestException(
            ApiFailure.fromServerError(
              statusCode: 422,
              error: ApiErrorResponse(
                message: 'Invalid.',
                code: ApiErrorCodes.validationFailed,
                fieldErrors: const {
                  'student_ids': ['Not eligible.'],
                },
                requestId: 'req-1',
              ),
            ),
          ),
        ),
      );
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();
      controller.updateTitle('Changed');

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherBlitzEditStatus.serverValidationFailure,
      );
      expect(
        subscription.read().fieldErrors[TeacherBlitzFormField.studentIds],
        'Review the selected Students. One or more selections may no longer be eligible.',
      );
    });
  });

  group('TeacherBlitzEditController uncertain outcome', () {
    test('a matching server state reconciles as success', () async {
      var reads = 0;
      final harness = _Harness(
        blitz: FakeTeacherBlitzRepository(
          onFetch: (id) async {
            reads += 1;
            return teacherBlitz(
              id: id,
              title: reads == 1 ? 'Equation Blitz' : 'Renamed',
            );
          },
          onUpdate: (_, _) async =>
              throw const TeacherBlitzMutationOutcomeUnknownException(),
        ),
      );
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();
      controller.updateTitle('Renamed');

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherBlitzEditStatus.confirmedSuccess,
      );
      expect(harness.blitz.updateRequests, hasLength(1));
    });

    test('a different server state requires explicit review', () async {
      final harness = _Harness(
        blitz: FakeTeacherBlitzRepository(
          onUpdate: (_, _) async =>
              throw const TeacherBlitzMutationOutcomeUnknownException(),
        ),
      );
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();
      controller.updateTitle('Renamed');

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherBlitzEditStatus.unconfirmedCurrentState,
      );
      expect(
        subscription.read().formError,
        'The server state differs from the attempted changes. Review the '
        'current Blitz before saving again.',
      );
      expect(subscription.read().form!.title, 'Renamed');
      await controller.submit();
      expect(harness.blitz.updateRequests, hasLength(1));
      final detail = harness.container.read(
        teacherBlitzDetailControllerProvider(_target()),
      );
      expect(detail.blitz!.title, 'Equation Blitz');
    });

    test(
      'an unreadable server state blocks until Check current Blitz',
      () async {
        var reads = 0;
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onFetch: (id) async {
              reads += 1;
              if (reads == 2) {
                throw teacherLocalFailure(ApiFailureKind.connection);
              }
              return teacherBlitz(
                id: id,
                title: reads == 1 ? 'Equation Blitz' : 'Renamed',
              );
            },
            onUpdate: (_, _) async =>
                throw const TeacherBlitzMutationOutcomeUnknownException(),
          ),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        controller.updateTitle('Renamed');

        await controller.submit();
        expect(
          subscription.read().status,
          TeacherBlitzEditStatus.outcomeReview,
        );
        expect(subscription.read().blocksNavigation, isTrue);
        await controller.submit();
        expect(harness.blitz.updateRequests, hasLength(1));

        await controller.checkCurrentBlitz();
        expect(
          subscription.read().status,
          TeacherBlitzEditStatus.confirmedSuccess,
        );
        expect(harness.blitz.updateRequests, hasLength(1));
      },
    );

    test(
      'a completion after session change or route exit cannot publish',
      () async {
        final pending = Completer<TeacherBlitz>();
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = _Harness(
          auth: auth,
          blitz: FakeTeacherBlitzRepository(onUpdate: (_, _) => pending.future),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        controller.updateTitle('Renamed');
        unawaited(controller.submit());
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherBlitzEditStatus.submitting);

        controller.leaveRoute();
        pending.complete(teacherBlitz(title: 'Renamed'));
        await flushTeacherControllers();
        expect(
          subscription.read().status,
          isNot(TeacherBlitzEditStatus.confirmedSuccess),
        );
        final detail = harness.container.read(
          teacherBlitzDetailControllerProvider(_target()),
        );
        expect(detail.blitz!.title, 'Equation Blitz');
      },
    );
  });

  test('mobile surfaces never own the edit form', () async {
    final harness = _Harness(surface: AppDeviceSurface.mobile);
    final subscription = harness.listen();
    await flushTeacherControllers();
    expect(subscription.read().status, TeacherBlitzEditStatus.loading);
    expect(harness.blitz.fetchIds, isEmpty);
  });
}

TeacherBlitzRouteTarget _target() {
  return TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId);
}

class _Harness {
  _Harness({
    FakeTeacherAuthSessionController? auth,
    FakeTeacherBlitzRepository? blitz,
    FakeTeacherTopicResultPairRepository? pairs,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth =
           auth ??
           FakeTeacherAuthSessionController.authenticated(
             teacherUser('teacher-a'),
           ),
       blitz = blitz ?? FakeTeacherBlitzRepository(),
       pairs = pairs ?? FakeTeacherTopicResultPairRepository() {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherBlitzRepositoryProvider.overrideWithValue(this.blitz),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(this.pairs),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherBlitzRepository blitz;
  final FakeTeacherTopicResultPairRepository pairs;
  late final ProviderContainer container;

  ProviderSubscription<TeacherBlitzEditState> listen() {
    return container.listen(
      teacherBlitzEditControllerProvider(_target()),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherBlitzEditController enterRoute() {
    return container.read(
      teacherBlitzEditControllerProvider(_target()).notifier,
    )..enterRoute();
  }
}
