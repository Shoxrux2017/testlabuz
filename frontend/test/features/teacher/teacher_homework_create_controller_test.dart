import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_create_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_create_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_form.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _studentA = '60000000-0000-0000-0000-000000000001';
const _groupA = '00000000-0000-0000-0000-000000000001';
const _groupB = '00000000-0000-0000-0000-000000000002';

void main() {
  group('TeacherHomeworkCreateController Topic gate', () {
    test('stays loading until authoritative Topic resolves', () async {
      final pendingTopic = Completer<TeacherTopic>();
      final harness = _Harness(
        topics: FakeTeacherTopicRepository(onFetch: (_) => pendingTopic.future),
      );
      final subscription = harness.listenCreate();

      await flushTeacherControllers();
      expect(subscription.read().status, TeacherHomeworkCreateStatus.loading);

      pendingTopic.complete(teacherTopic());
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherHomeworkCreateStatus.editing);
    });

    test('renders unavailable state when current Topic is not found', () async {
      final harness = _Harness(
        topics: FakeTeacherTopicRepository(
          onFetch: (_) async => throw teacherServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        ),
      );
      final subscription = harness.listenCreate();

      await flushTeacherControllers();

      expect(
        subscription.read().status,
        TeacherHomeworkCreateStatus.unavailable,
      );
      expect(subscription.read().topic, isNull);
      expect(subscription.read().canEdit, isFalse);
      expect(subscription.read().formError, contains('no longer available'));
    });

    test('closed and archived Topics are review-only', () async {
      for (final status in [
        TeacherTopicStatus.closed,
        TeacherTopicStatus.archived,
      ]) {
        final harness = _Harness(
          topics: FakeTeacherTopicRepository(
            onFetch: (_) async => teacherTopic(status: status),
          ),
        );
        final subscription = harness.listenCreate();

        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherHomeworkCreateStatus.topicNotEditable,
        );
        expect(subscription.read().topic!.status, status);
        expect(subscription.read().canEdit, isFalse);
      }
    });

    test('draft Topic opens with exact default whole-group form', () async {
      final harness = _Harness();
      final subscription = harness.listenCreate();

      await flushTeacherControllers();

      expect(subscription.read().status, TeacherHomeworkCreateStatus.editing);
      expect(subscription.read().form, TeacherHomeworkFormValue());
      expect(
        subscription.read().form.assignmentMode,
        TeacherHomeworkAssignmentMode.group,
      );
      expect(subscription.read().form.selectedStudentIds, isEmpty);
      expect(subscription.read().isDirty, isFalse);
    });
  });

  group('TeacherHomeworkCreateController form', () {
    test(
      'rune-safe local validation reports deterministic first focus',
      () async {
        final harness = _Harness();
        final subscription = harness.listenCreate();
        await flushTeacherControllers();
        final controller = harness.enterCreateRoute();
        final emoji = String.fromCharCode(0x1f600);

        controller
          ..updateTitle(List.filled(256, emoji).join())
          ..updateDescription(List.filled(10001, emoji).join())
          ..updateStudentInstructions(List.filled(10001, emoji).join());
        await controller.submit();

        final state = subscription.read();
        expect(
          state.status,
          TeacherHomeworkCreateStatus.localValidationFailure,
        );
        expect(
          state.fieldErrors.keys,
          containsAll([
            TeacherHomeworkFormField.title,
            TeacherHomeworkFormField.description,
            TeacherHomeworkFormField.studentInstructions,
          ]),
        );
        expect(state.firstErrorField, TeacherHomeworkFormField.title);
        expect(harness.homework.createRequests, isEmpty);
      },
    );

    test(
      'selected mode requires IDs and remembers selection across modes',
      () async {
        final harness = _Harness();
        final subscription = harness.listenCreate();
        await flushTeacherControllers();
        final controller = harness.enterCreateRoute();
        _fillValidForm(controller);

        controller.updateAssignmentMode(
          TeacherHomeworkAssignmentMode.selectedStudents,
        );
        await controller.submit();
        expect(
          subscription.read().firstErrorField,
          TeacherHomeworkFormField.studentIds,
        );
        expect(harness.homework.createRequests, isEmpty);

        controller.updateSelectedStudentIds(const {_studentA});
        controller.updateAssignmentMode(TeacherHomeworkAssignmentMode.group);
        expect(subscription.read().form.selectedStudentIds, isEmpty);
        expect(subscription.read().rememberedSelectedIds, {_studentA});

        controller.updateAssignmentMode(
          TeacherHomeworkAssignmentMode.selectedStudents,
        );
        expect(subscription.read().form.selectedStudentIds, {_studentA});
        expect(
          subscription.read().errorFor(TeacherHomeworkFormField.studentIds),
          isNull,
        );
      },
    );
  });

  group('TeacherHomeworkCreateController mutation', () {
    test(
      'confirmed create refreshes mounted list and publishes destination',
      () async {
        final homework = FakeTeacherHomeworkRepository(
          onCreate: (topicId, request) async => teacherHomework(
            id: _homeworkId,
            topicId: topicId,
            title: request.title,
            description: request.description,
            studentInstructions: request.studentInstructions,
            assignmentMode: request.assignmentMode,
            studentIds: request.studentIds,
            hasDeadline: false,
          ),
        );
        final harness = _Harness(homework: homework);
        final createSubscription = harness.listenCreate();
        final listSubscription = harness.container.listen(
          teacherHomeworkListControllerProvider(_topicId),
          (_, _) {},
          fireImmediately: true,
        );
        await flushTeacherControllers();
        final controller = harness.enterCreateRoute();
        _fillValidForm(controller);

        await controller.submit();
        await flushTeacherControllers();

        expect(
          createSubscription.read().status,
          TeacherHomeworkCreateStatus.confirmedSuccess,
        );
        expect(createSubscription.read().confirmedHomeworkId, _homeworkId);
        expect(homework.createRequests, hasLength(1));
        expect(homework.createRequests.single.topicId, _topicId);
        expect(homework.createRequests.single.request.toJson().length, 7);
        expect(homework.listRequests, hasLength(2));
        expect(homework.listRequests.last.query, listSubscription.read().query);
      },
    );

    test(
      '422 maps known fields and Questions/unknown keys to form failure',
      () async {
        final homework = FakeTeacherHomeworkRepository(
          onCreate: (_, _) async => throw ApiRequestException(
            ApiFailure(
              kind: ApiFailureKind.validation,
              statusCode: 422,
              serverCode: ApiErrorCodes.validationFailed,
              message: 'Raw validation response.',
              fieldErrors: const {
                'title': ['Raw title message.'],
                'student_ids': ['Raw roster message.'],
                'questions': ['Raw Question message.'],
                'future_field': ['Raw future message.'],
              },
            ),
          ),
        );
        final harness = _Harness(homework: homework);
        final subscription = harness.listenCreate();
        await flushTeacherControllers();
        final controller = harness.enterCreateRoute();
        _fillValidForm(controller);

        await controller.submit();

        final state = subscription.read();
        expect(
          state.status,
          TeacherHomeworkCreateStatus.serverValidationFailure,
        );
        expect(
          state.errorFor(TeacherHomeworkFormField.title),
          'Review the Homework title.',
        );
        expect(
          state.errorFor(TeacherHomeworkFormField.studentIds),
          contains('no longer be eligible'),
        );
        expect(state.firstErrorField, TeacherHomeworkFormField.title);
        expect(state.formError, 'The Homework could not be created.');
        expect(state.formError, isNot(contains('Raw')));
      },
    );

    test('404 makes the Topic unavailable without replay', () async {
      final homework = FakeTeacherHomeworkRepository(
        onCreate: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      );
      final harness = _Harness(homework: homework);
      final subscription = harness.listenCreate();
      await flushTeacherControllers();
      final controller = harness.enterCreateRoute();
      _fillValidForm(controller);

      await controller.submit();

      expect(
        subscription.read().status,
        TeacherHomeworkCreateStatus.unavailable,
      );
      expect(subscription.read().topic, isNull);
      expect(subscription.read().formError, contains('no longer available'));
      expect(homework.createRequests, hasLength(1));
    });

    test('topic_not_editable refreshes and publishes current Topic', () async {
      var topicFetches = 0;
      final topics = FakeTeacherTopicRepository(
        onFetch: (_) async {
          topicFetches += 1;
          return teacherTopic(
            status: topicFetches == 1
                ? TeacherTopicStatus.draft
                : TeacherTopicStatus.closed,
          );
        },
      );
      final homework = FakeTeacherHomeworkRepository(
        onCreate: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.topicNotEditable,
          statusCode: 409,
        ),
      );
      final harness = _Harness(topics: topics, homework: homework);
      final subscription = harness.listenCreate();
      await flushTeacherControllers();
      final controller = harness.enterCreateRoute();
      _fillValidForm(controller);

      await controller.submit();

      expect(topics.fetchIds, hasLength(2));
      expect(homework.createRequests, hasLength(1));
      expect(
        subscription.read().status,
        TeacherHomeworkCreateStatus.topicNotEditable,
      );
      expect(subscription.read().topic!.status, TeacherTopicStatus.closed);
      expect(subscription.read().formError, contains('server state'));
    });

    test(
      'unknown outcome cannot replay and Review Homework refreshes list',
      () async {
        final homework = FakeTeacherHomeworkRepository(
          onCreate: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
        );
        final harness = _Harness(homework: homework);
        final subscription = harness.listenCreate();
        harness.container.listen(
          teacherHomeworkListControllerProvider(_topicId),
          (_, _) {},
          fireImmediately: true,
        );
        await flushTeacherControllers();
        final controller = harness.enterCreateRoute();
        _fillValidForm(controller);

        await controller.submit();
        await controller.submit();

        expect(
          subscription.read().status,
          TeacherHomeworkCreateStatus.outcomeUnknown,
        );
        expect(homework.createRequests, hasLength(1));
        expect(controller.reviewHomework(), isTrue);
        await flushTeacherControllers();
        expect(homework.listRequests, hasLength(2));
        expect(controller.reviewHomework(), isFalse);
        expect(homework.createRequests, hasLength(1));
      },
    );

    test(
      'duplicate submit is suppressed while the first request is active',
      () async {
        final pending = Completer<TeacherHomework>();
        final homework = FakeTeacherHomeworkRepository(
          onCreate: (_, _) => pending.future,
        );
        final harness = _Harness(homework: homework);
        final subscription = harness.listenCreate();
        await flushTeacherControllers();
        final controller = harness.enterCreateRoute();
        _fillValidForm(controller);

        final first = controller.submit();
        final duplicate = controller.submit();
        expect(
          subscription.read().status,
          TeacherHomeworkCreateStatus.submitting,
        );
        expect(homework.createRequests, hasLength(1));

        pending.complete(teacherHomework(id: _homeworkId, topicId: _topicId));
        await Future.wait([first, duplicate]);
        expect(homework.createRequests, hasLength(1));
        expect(
          subscription.read().status,
          TeacherHomeworkCreateStatus.confirmedSuccess,
        );
      },
    );

    test('completion after leaving the route cannot publish success', () async {
      final pending = Completer<TeacherHomework>();
      final homework = FakeTeacherHomeworkRepository(
        onCreate: (_, _) => pending.future,
      );
      final harness = _Harness(homework: homework);
      final subscription = harness.listenCreate();
      await flushTeacherControllers();
      final controller = harness.enterCreateRoute();
      _fillValidForm(controller);

      final submission = controller.submit();
      controller.leaveRoute();
      pending.complete(teacherHomework(id: _homeworkId, topicId: _topicId));
      await submission;

      expect(subscription.read().confirmedHomeworkId, isNull);
      expect(homework.createRequests, hasLength(1));
    });

    test('completion from a replaced Teacher session is ignored', () async {
      final pending = Completer<TeacherHomework>();
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final homework = FakeTeacherHomeworkRepository(
        onCreate: (_, _) => pending.future,
      );
      final harness = _Harness(auth: auth, homework: homework);
      final subscription = harness.listenCreate();
      await flushTeacherControllers();
      final controller = harness.enterCreateRoute();
      _fillValidForm(controller);

      final submission = controller.submit();
      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(teacherHomework(id: _homeworkId, topicId: _topicId));
      await submission;
      await flushTeacherControllers();

      expect(subscription.read().confirmedHomeworkId, isNull);
      expect(homework.createRequests, hasLength(1));
    });
  });

  test(
    'picker and submit use confirmed current Topic and Group authority',
    () async {
      final homework = FakeTeacherHomeworkRepository();
      final harness = _Harness(homework: homework);
      final subscription = harness.listenCreate();
      await flushTeacherControllers();
      final controller = harness.enterCreateRoute();
      _fillValidForm(controller);

      final refreshedTopic = teacherTopic(
        title: 'Current Topic title',
        group: teacherGroup(id: _groupB, name: 'Current Group'),
      );
      harness.container
          .read(teacherTopicDetailControllerProvider(_topicId).notifier)
          .acceptAuthoritativeTopic(refreshedTopic);
      await flushTeacherControllers();
      controller.updateAssignmentMode(
        TeacherHomeworkAssignmentMode.selectedStudents,
      );
      final launch = controller.beginStudentPicker();

      expect(subscription.read().topic!.title, 'Current Topic title');
      expect(subscription.read().topic!.group.id, _groupB);
      expect(launch, isNotNull);
      expect(launch!.target.groupId, _groupB);

      harness.container
          .read(teacherTopicDetailControllerProvider(_topicId).notifier)
          .acceptAuthoritativeTopic(
            teacherTopic(
              title: 'Newer Topic context',
              group: teacherGroup(id: _groupA, name: 'Newer Group'),
            ),
          );
      await flushTeacherControllers();
      controller.applyStudentSelection(const {_studentA}, launch.owner);
      expect(subscription.read().form.selectedStudentIds, isEmpty);

      final currentLaunch = controller.beginStudentPicker();
      expect(currentLaunch, isNotNull);
      expect(currentLaunch!.target.groupId, _groupA);
      controller.applyStudentSelection(const {_studentA}, currentLaunch.owner);
      expect(subscription.read().form.selectedStudentIds, {_studentA});

      harness.container
          .read(teacherTopicDetailControllerProvider(_topicId).notifier)
          .acceptAuthoritativeTopic(
            teacherTopic(
              title: 'Closed current Topic',
              group: teacherGroup(id: _groupA, name: 'Newer Group'),
              status: TeacherTopicStatus.closed,
            ),
          );
      await flushTeacherControllers();
      await controller.submit();

      expect(homework.createRequests, isEmpty);
      expect(
        subscription.read().status,
        TeacherHomeworkCreateStatus.topicNotEditable,
      );
      expect(subscription.read().topic!.title, 'Closed current Topic');
    },
  );
}

void _fillValidForm(TeacherHomeworkCreateController controller) {
  controller
    ..updateTitle('Homework title')
    ..updateStudentInstructions('Complete every exercise.');
}

class _Harness {
  _Harness({
    FakeTeacherAuthSessionController? auth,
    FakeTeacherTopicRepository? topics,
    FakeTeacherHomeworkRepository? homework,
  }) : auth =
           auth ??
           FakeTeacherAuthSessionController.authenticated(
             teacherUser('teacher-a'),
           ),
       topics = topics ?? FakeTeacherTopicRepository(),
       homework = homework ?? FakeTeacherHomeworkRepository() {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherTopicRepositoryProvider.overrideWithValue(this.topics),
        teacherHomeworkRepositoryProvider.overrideWithValue(this.homework),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherTopicRepository topics;
  final FakeTeacherHomeworkRepository homework;
  late final ProviderContainer container;

  ProviderSubscription<TeacherHomeworkCreateState> listenCreate() {
    return container.listen(
      teacherHomeworkCreateControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherHomeworkCreateController enterCreateRoute() {
    return container.read(
      teacherHomeworkCreateControllerProvider(_topicId).notifier,
    )..enterRoute();
  }
}
