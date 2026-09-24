import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_create_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_create_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_list_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_form.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _groupId = '00000000-0000-0000-0000-000000000001';
const _createdId = '80000000-0000-0000-0000-000000000009';
const _studentA = '60000000-0000-0000-0000-00000000000a';

void main() {
  group('TeacherBlitzCreateController context', () {
    test('stays loading until the confirmed Topic resolves', () async {
      final pending = Completer<TeacherTopic>();
      final harness = _Harness(
        topics: FakeTeacherTopicRepository(onFetch: (_) => pending.future),
      );
      final subscription = harness.listen();
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherBlitzCreateStatus.loading);

      pending.complete(teacherTopic(status: TeacherTopicStatus.active));
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherBlitzCreateStatus.editing);
      expect(subscription.read().form, TeacherBlitzFormValue());
      expect(subscription.read().canSubmit, isTrue);
    });

    test('draft and active Topics permit creation', () async {
      for (final status in [
        TeacherTopicStatus.draft,
        TeacherTopicStatus.active,
      ]) {
        final harness = _Harness(
          topics: FakeTeacherTopicRepository(
            onFetch: (id) async => teacherTopic(id: id, status: status),
          ),
        );
        final subscription = harness.listen();
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherBlitzCreateStatus.editing);
      }
    });

    test('closed and archived Topics are unavailable for creation', () async {
      for (final status in [
        TeacherTopicStatus.closed,
        TeacherTopicStatus.archived,
      ]) {
        final harness = _Harness(
          topics: FakeTeacherTopicRepository(
            onFetch: (id) async => teacherTopic(id: id, status: status),
          ),
        );
        final subscription = harness.listen();
        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherBlitzCreateStatus.topicNotEditable,
        );
        expect(
          subscription.read().formError,
          'Blitz creation is unavailable for this Topic.',
        );
        expect(subscription.read().canSubmit, isFalse);
      }
    });

    test(
      'a missing Topic is unavailable and a load error is retryable',
      () async {
        final missing = _Harness(
          topics: FakeTeacherTopicRepository(
            onFetch: (_) async => throw teacherServerFailure(
              ApiErrorCodes.resourceNotFound,
              statusCode: 404,
            ),
          ),
        );
        final missingSubscription = missing.listen();
        await flushTeacherControllers();
        expect(
          missingSubscription.read().status,
          TeacherBlitzCreateStatus.unavailable,
        );

        var calls = 0;
        final failing = _Harness(
          topics: FakeTeacherTopicRepository(
            onFetch: (id) async {
              calls += 1;
              if (calls == 1) {
                throw teacherLocalFailure(ApiFailureKind.connection);
              }
              return teacherTopic(id: id);
            },
          ),
        );
        final subscription = failing.listen();
        final controller = failing.enterRoute();
        await flushTeacherControllers();
        expect(
          subscription.read().status,
          TeacherBlitzCreateStatus.initialLoadError,
        );

        controller.retryInitialLoad();
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherBlitzCreateStatus.editing);
      },
    );
  });

  group('TeacherBlitzCreateController submission', () {
    test(
      'local validation blocks the request and names the first field',
      () async {
        final harness = _Harness();
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();

        await controller.submit();

        expect(
          subscription.read().status,
          TeacherBlitzCreateStatus.localValidationFailure,
        );
        expect(subscription.read().fieldErrors.keys, {
          TeacherBlitzFormField.title,
          TeacherBlitzFormField.studentInstructions,
          TeacherBlitzFormField.durationSeconds,
        });
        expect(
          subscription.read().firstErrorField,
          TeacherBlitzFormField.title,
        );
        expect(harness.blitz.createRequests, isEmpty);

        controller.updateTitle('Blitz');
        expect(
          subscription.read().fieldErrors.containsKey(
            TeacherBlitzFormField.title,
          ),
          isFalse,
        );
      },
    );

    test(
      'sends the exact request once and publishes the created Blitz',
      () async {
        final pending = Completer<TeacherBlitz>();
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(onCreate: (_, _) => pending.future),
        );
        final subscription = harness.listen();
        final listSubscription = harness.container.listen(
          teacherBlitzListControllerProvider(_topicId),
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        final listReadsBefore = harness.blitz.listRequests.length;
        _fillValidForm(controller);

        unawaited(controller.submit());
        await flushTeacherControllers();
        expect(subscription.read().status, TeacherBlitzCreateStatus.submitting);
        expect(subscription.read().canSubmit, isFalse);
        await controller.submit();
        expect(harness.blitz.createRequests, hasLength(1));
        expect(harness.blitz.createRequests.single.topicId, _topicId);
        expect(harness.blitz.createRequests.single.request.toJson(), {
          'title': 'Equation Blitz',
          'description': null,
          'student_instructions': 'Answer quickly.',
          'assignment_mode': 'group',
          'student_ids': <String>[],
          'duration_seconds': 600,
          'scheduled_at': null,
          'questions': <Object?>[],
        });

        pending.complete(teacherBlitz(id: _createdId, topicId: _topicId));
        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherBlitzCreateStatus.confirmedSuccess,
        );
        expect(subscription.read().confirmedBlitzId, _createdId);
        expect(harness.blitz.listRequests.length, greaterThan(listReadsBefore));
        listSubscription.close();
      },
    );

    test(
      'a created Blitz that contradicts the Topic or Draft is not success',
      () async {
        for (final contradiction in [
          teacherBlitz(id: _createdId, status: TeacherBlitzStatus.scheduled),
          TeacherBlitz(
            id: _createdId,
            topicId: _topicId,
            groupId: '00000000-0000-0000-0000-000000000002',
            title: 'Blitz',
            description: null,
            studentInstructions: 'Go',
            assignmentMode: TeacherBlitzAssignmentMode.group,
            studentIds: const [],
            totalPossiblePoints: 0,
            durationSeconds: 600,
            scheduledAt: null,
            institutionTimezone: 'Asia/Tashkent',
            status: TeacherBlitzStatus.draft,
            timerStartModeSnapshot: null,
            attemptPolicy: const TeacherBlitzAttemptPolicy(
              normalAttempts: 1,
              maxAdditionalExceptionAttempts: 1,
            ),
            activatedAt: null,
            synchronizedEndsAt: null,
            closedAt: null,
            archivedAt: null,
            createdAt: DateTime.utc(2026, 9, 17),
            updatedAt: DateTime.utc(2026, 9, 17),
            questions: const [],
          ),
        ]) {
          final harness = _Harness(
            blitz: FakeTeacherBlitzRepository(
              onCreate: (_, _) async => contradiction,
            ),
          );
          final subscription = harness.listen();
          final controller = harness.enterRoute();
          await flushTeacherControllers();
          _fillValidForm(controller);

          await controller.submit();

          expect(
            subscription.read().status,
            TeacherBlitzCreateStatus.outcomeReview,
          );
          expect(harness.blitz.createRequests, hasLength(1));
        }
      },
    );

    test(
      'an uncertain create enters blocking review and is never replayed',
      () async {
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onCreate: (_, _) async =>
                throw const TeacherBlitzMutationOutcomeUnknownException(),
          ),
        );
        final subscription = harness.listen();
        final listSubscription = harness.container.listen(
          teacherBlitzListControllerProvider(_topicId),
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        _fillValidForm(controller);

        await controller.submit();

        final review = subscription.read();
        expect(review.status, TeacherBlitzCreateStatus.outcomeReview);
        expect(
          review.formError,
          'Blitz creation outcome is uncertain. Check the Topic Blitz list '
          'before trying to create it again.',
        );
        expect(review.canSubmit, isFalse);
        expect(review.blocksNavigation, isTrue);
        await controller.submit();
        expect(harness.blitz.createRequests, hasLength(1));

        final listReadsBefore = harness.blitz.listRequests.length;
        expect(controller.checkBlitzList(), isTrue);
        await flushTeacherControllers();
        expect(harness.blitz.listRequests.length, greaterThan(listReadsBefore));
        expect(harness.blitz.createRequests, hasLength(1));
        listSubscription.close();
      },
    );

    test(
      'server validation maps fields and keeps fixed fields form-level',
      () async {
        final harness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onCreate: (_, _) async => throw _validation({
              'student_ids': ['Not eligible.'],
              'duration_seconds': ['Too large.'],
            }),
          ),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        _fillValidForm(controller);

        await controller.submit();

        expect(
          subscription.read().status,
          TeacherBlitzCreateStatus.serverValidationFailure,
        );
        expect(
          subscription.read().fieldErrors[TeacherBlitzFormField.studentIds],
          'Review the selected Students. One or more selections may no longer be eligible.',
        );
        expect(
          subscription.read().fieldErrors.keys,
          contains(TeacherBlitzFormField.durationSeconds),
        );
        expect(
          subscription.read().firstErrorField,
          TeacherBlitzFormField.studentIds,
        );

        harness.blitz.onCreate = (_, _) async => throw _validation({
          'scheduled_at': ['Invalid.'],
        });
        await controller.submit();
        expect(subscription.read().fieldErrors, isEmpty);
        expect(
          subscription.read().formError,
          'The Blitz could not be created.',
        );
      },
    );

    test(
      'topic_not_editable refreshes the Topic and becomes unavailable',
      () async {
        var topicReads = 0;
        final harness = _Harness(
          topics: FakeTeacherTopicRepository(
            onFetch: (id) async {
              topicReads += 1;
              return teacherTopic(
                id: id,
                status: topicReads == 1
                    ? TeacherTopicStatus.active
                    : TeacherTopicStatus.closed,
              );
            },
          ),
          blitz: FakeTeacherBlitzRepository(
            onCreate: (_, _) async => throw teacherServerFailure(
              ApiErrorCodes.topicNotEditable,
              statusCode: 409,
            ),
          ),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        _fillValidForm(controller);

        await controller.submit();
        await flushTeacherControllers();

        expect(topicReads, 2);
        expect(
          subscription.read().status,
          TeacherBlitzCreateStatus.topicNotEditable,
        );
        expect(harness.blitz.createRequests, hasLength(1));
      },
    );

    test('404 makes the Topic unavailable; forbidden stays editable', () async {
      final missing = _Harness(
        blitz: FakeTeacherBlitzRepository(
          onCreate: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        ),
      );
      final missingSubscription = missing.listen();
      final missingController = missing.enterRoute();
      await flushTeacherControllers();
      _fillValidForm(missingController);
      await missingController.submit();
      expect(
        missingSubscription.read().status,
        TeacherBlitzCreateStatus.unavailable,
      );

      final forbidden = _Harness(
        blitz: FakeTeacherBlitzRepository(
          onCreate: (_, _) async =>
              throw teacherServerFailure(ApiErrorCodes.forbidden),
        ),
      );
      final subscription = forbidden.listen();
      final controller = forbidden.enterRoute();
      await flushTeacherControllers();
      _fillValidForm(controller);
      await controller.submit();
      expect(
        subscription.read().status,
        TeacherBlitzCreateStatus.definiteFailure,
      );
      expect(subscription.read().canSubmit, isTrue);
    });

    test(
      'a completion after session change or route exit cannot publish',
      () async {
        final pending = Completer<TeacherBlitz>();
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = _Harness(
          auth: auth,
          blitz: FakeTeacherBlitzRepository(onCreate: (_, _) => pending.future),
        );
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        _fillValidForm(controller);
        unawaited(controller.submit());
        await flushTeacherControllers();

        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        pending.complete(teacherBlitz(id: _createdId));
        await flushTeacherControllers();
        expect(
          subscription.read().status,
          isNot(TeacherBlitzCreateStatus.confirmedSuccess),
        );
        expect(subscription.read().confirmedBlitzId, isNull);

        final routePending = Completer<TeacherBlitz>();
        final routeHarness = _Harness(
          blitz: FakeTeacherBlitzRepository(
            onCreate: (_, _) => routePending.future,
          ),
        );
        final routeSubscription = routeHarness.listen();
        final routeController = routeHarness.enterRoute();
        await flushTeacherControllers();
        _fillValidForm(routeController);
        unawaited(routeController.submit());
        await flushTeacherControllers();
        routeController.leaveRoute();
        routePending.complete(teacherBlitz(id: _createdId));
        await flushTeacherControllers();
        expect(routeSubscription.read().confirmedBlitzId, isNull);
      },
    );
  });

  group('TeacherBlitzCreateController assignment', () {
    test(
      'Student picker opens only for selected mode on the Topic group',
      () async {
        final harness = _Harness();
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();

        expect(controller.beginStudentPicker(), isNull);
        controller.updateAssignmentMode(
          TeacherBlitzAssignmentMode.selectedStudents,
        );
        expect(subscription.read().form.selectedStudentIds, isEmpty);

        final launch = controller.beginStudentPicker()!;
        expect(launch.target.groupId, _groupId);
        controller.applyStudentSelection({_studentA}, launch.owner);
        expect(subscription.read().form.selectedStudentIds, {_studentA});
      },
    );

    test(
      'a stale picker completion cannot change a newer form or session',
      () async {
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = _Harness(auth: auth);
        final subscription = harness.listen();
        final controller = harness.enterRoute();
        await flushTeacherControllers();
        controller.updateAssignmentMode(
          TeacherBlitzAssignmentMode.selectedStudents,
        );

        final first = controller.beginStudentPicker()!;
        final second = controller.beginStudentPicker()!;
        controller.applyStudentSelection({_studentA}, first.owner);
        expect(subscription.read().form.selectedStudentIds, isEmpty);

        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        controller.applyStudentSelection({_studentA}, second.owner);
        expect(subscription.read().form.selectedStudentIds, isEmpty);
      },
    );

    test('switching to whole group clears the selected Students', () async {
      final harness = _Harness();
      final subscription = harness.listen();
      final controller = harness.enterRoute();
      await flushTeacherControllers();
      controller.updateAssignmentMode(
        TeacherBlitzAssignmentMode.selectedStudents,
      );
      final launch = controller.beginStudentPicker()!;
      controller.applyStudentSelection({_studentA}, launch.owner);

      controller.updateAssignmentMode(TeacherBlitzAssignmentMode.group);
      expect(subscription.read().form.selectedStudentIds, isEmpty);
      controller.updateAssignmentMode(
        TeacherBlitzAssignmentMode.selectedStudents,
      );
      expect(subscription.read().form.selectedStudentIds, isEmpty);
    });
  });

  test('mobile surfaces never own the create form', () async {
    final harness = _Harness(surface: AppDeviceSurface.mobile);
    final subscription = harness.listen();
    await flushTeacherControllers();
    expect(subscription.read().status, TeacherBlitzCreateStatus.loading);
    expect(harness.topics.fetchIds, isEmpty);
  });
}

void _fillValidForm(TeacherBlitzCreateController controller) {
  controller
    ..updateTitle('  Equation Blitz  ')
    ..updateStudentInstructions('Answer quickly.')
    ..updateDurationSeconds('600');
}

ApiRequestException _validation(Map<String, List<String>> fieldErrors) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: 422,
      error: ApiErrorResponse(
        message: 'Invalid.',
        code: ApiErrorCodes.validationFailed,
        fieldErrors: fieldErrors,
        requestId: 'req-1',
      ),
    ),
  );
}

class _Harness {
  _Harness({
    FakeTeacherAuthSessionController? auth,
    FakeTeacherTopicRepository? topics,
    FakeTeacherBlitzRepository? blitz,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth =
           auth ??
           FakeTeacherAuthSessionController.authenticated(
             teacherUser('teacher-a'),
           ),
       topics = topics ?? FakeTeacherTopicRepository(),
       blitz = blitz ?? FakeTeacherBlitzRepository() {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherTopicRepositoryProvider.overrideWithValue(this.topics),
        teacherBlitzRepositoryProvider.overrideWithValue(this.blitz),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherTopicRepository topics;
  final FakeTeacherBlitzRepository blitz;
  late final ProviderContainer container;

  ProviderSubscription<TeacherBlitzCreateState> listen() {
    return container.listen(
      teacherBlitzCreateControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherBlitzCreateController enterRoute() {
    return container.read(
      teacherBlitzCreateControllerProvider(_topicId).notifier,
    )..enterRoute();
  }
}
