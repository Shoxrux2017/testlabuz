import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_edit_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_edit_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_form.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';
const _groupA = '00000000-0000-0000-0000-000000000001';
const _groupB = '00000000-0000-0000-0000-000000000002';
const _studentA = '60000000-0000-0000-0000-000000000001';
const _studentB = '60000000-0000-0000-0000-000000000002';

void main() {
  group('TeacherHomeworkEditController initial state', () {
    test(
      'initializes draft and active Homework as clean editable forms',
      () async {
        for (final status in [
          TeacherHomeworkStatus.draft,
          TeacherHomeworkStatus.active,
        ]) {
          final initial = teacherHomework(status: status);
          final harness = _Harness(
            homework: FakeTeacherHomeworkRepository(
              onFetch: (_) async => initial,
            ),
          );
          final subscription = harness.listenEdit();

          await flushTeacherControllers();

          final state = subscription.read();
          expect(state.status, TeacherHomeworkEditStatus.editing);
          expect(state.homework, same(initial));
          expect(state.form!.title, initial.title);
          expect(state.form!.studentInstructions, initial.studentInstructions);
          expect(state.isDirty, isFalse);
          expect(state.canEdit, isTrue);
        }
      },
    );

    test(
      'closed and archived Homework are current-state review only',
      () async {
        for (final status in [
          TeacherHomeworkStatus.closed,
          TeacherHomeworkStatus.archived,
        ]) {
          final harness = _Harness(
            homework: FakeTeacherHomeworkRepository(
              onFetch: (_) async => teacherHomework(status: status),
            ),
          );
          final subscription = harness.listenEdit();

          await flushTeacherControllers();

          final state = subscription.read();
          expect(
            state.status,
            status == TeacherHomeworkStatus.closed
                ? TeacherHomeworkEditStatus.taskClosed
                : TeacherHomeworkEditStatus.taskArchived,
          );
          expect(state.isReviewOnly, isTrue);
          expect(state.canEdit, isFalse);
          expect(state.attemptedDraft, isNull);
          expect(state.pendingRequest, isNull);
          expect(state.isDirty, isFalse);
        }
      },
    );

    test('uses Institution timezone for initial deadline wall clock', () async {
      final harness = _Harness(
        homework: FakeTeacherHomeworkRepository(
          onFetch: (_) async =>
              teacherHomework(deadlineAt: DateTime.utc(2026, 9, 10, 12)),
        ),
      );
      final subscription = harness.listenEdit();

      await flushTeacherControllers();

      expect(
        subscription.read().form!.deadlineWallClock,
        const InstitutionWallClock(
          year: 2026,
          month: 9,
          day: 10,
          hour: 17,
          minute: 0,
        ),
      );
      expect(subscription.read().institutionTimezone, 'Asia/Tashkent');
    });

    test('adopts confirmed current Topic and Group for the picker', () async {
      final harness = _Harness();
      final subscription = harness.listenEdit();
      await flushTeacherControllers();
      final controller = harness.enterEditRoute();

      harness.container
          .read(teacherTopicDetailControllerProvider(_topicId).notifier)
          .acceptAuthoritativeTopic(
            teacherTopic(
              title: 'Current Topic title',
              group: teacherGroup(id: _groupB, name: 'Current Group'),
            ),
          );
      await flushTeacherControllers();
      controller.updateAssignmentMode(
        TeacherHomeworkAssignmentMode.selectedStudents,
      );
      controller.updateSelectedStudentIds(const {_studentA});

      final launch = controller.beginStudentPicker();

      expect(subscription.read().topic!.title, 'Current Topic title');
      expect(subscription.read().topic!.group.id, _groupB);
      expect(launch, isNotNull);
      expect(launch!.target.groupId, _groupB);

      harness.container
          .read(teacherTopicDetailControllerProvider(_topicId).notifier)
          .acceptAuthoritativeTopic(
            teacherTopic(
              title: 'Newer Topic title',
              group: teacherGroup(id: _groupA, name: 'Newer Group'),
            ),
          );
      await flushTeacherControllers();
      controller.applyStudentSelection(const {_studentB}, launch.owner);

      expect(subscription.read().form!.selectedStudentIds, {_studentA});
    });

    test(
      'adopts later authoritative Homework while preserving a dirty draft',
      () async {
        final harness = _Harness();
        final subscription = harness.listenEdit();
        await flushTeacherControllers();
        final controller = harness.enterEditRoute();
        final sessionKey = _sessionKey(harness);
        final detail = harness.container.read(
          teacherHomeworkDetailControllerProvider(harness.target).notifier,
        );

        final refreshed = teacherHomework(
          title: 'Refreshed server title',
          status: TeacherHomeworkStatus.active,
        );
        detail.acceptAuthoritativeHomework(refreshed, sessionKey);
        await flushTeacherControllers();

        expect(subscription.read().homework, same(refreshed));
        expect(subscription.read().form!.title, 'Refreshed server title');
        expect(subscription.read().isDirty, isFalse);

        controller.updateTitle('Local unsaved title');
        final newer = teacherHomework(
          title: 'Newer server title',
          status: TeacherHomeworkStatus.active,
        );
        detail.acceptAuthoritativeHomework(newer, sessionKey);
        await flushTeacherControllers();

        expect(subscription.read().homework, same(newer));
        expect(subscription.read().form!.title, 'Local unsaved title');
        expect(subscription.read().isDirty, isTrue);
      },
    );

    test(
      'later authoritative terminal detail closes the stale editor',
      () async {
        final closedHarness = _Harness();
        final closedSubscription = closedHarness.listenEdit();
        await flushTeacherControllers();
        closedHarness.enterEditRoute();
        closedHarness.container
            .read(
              teacherHomeworkDetailControllerProvider(
                closedHarness.target,
              ).notifier,
            )
            .acceptAuthoritativeHomework(
              teacherHomework(status: TeacherHomeworkStatus.closed),
              _sessionKey(closedHarness),
            );
        await flushTeacherControllers();

        expect(
          closedSubscription.read().status,
          TeacherHomeworkEditStatus.taskClosed,
        );
        expect(closedSubscription.read().canEdit, isFalse);
        expect(closedSubscription.read().form, isNull);

        final missingHarness = _Harness();
        final missingSubscription = missingHarness.listenEdit();
        await flushTeacherControllers();
        missingHarness.enterEditRoute();
        missingHarness.container
            .read(
              teacherHomeworkDetailControllerProvider(
                missingHarness.target,
              ).notifier,
            )
            .markNotFound(_sessionKey(missingHarness));
        await flushTeacherControllers();

        expect(
          missingSubscription.read().status,
          TeacherHomeworkEditStatus.unavailable,
        );
        expect(missingSubscription.read().homework, isNull);
        expect(missingSubscription.read().form, isNull);
      },
    );
  });

  group('TeacherHomeworkEditController form', () {
    test(
      'dirty state is based on the semantic PATCH and no-op sends nothing',
      () async {
        final harness = _Harness();
        final subscription = harness.listenEdit();
        await flushTeacherControllers();
        final controller = harness.enterEditRoute();

        controller.updateTitle('  Equation practice  ');
        expect(subscription.read().isDirty, isFalse);
        expect(subscription.read().blocksNavigation, isFalse);

        await controller.submit();

        expect(harness.homework.updateRequests, isEmpty);
        expect(subscription.read().formError, 'No changes to save.');

        controller.updateTitle('Changed title');
        expect(subscription.read().isDirty, isTrue);
        expect(subscription.read().blocksNavigation, isTrue);
      },
    );

    test(
      '422 maps student_ids and known fields without clearing selection',
      () async {
        final homework = FakeTeacherHomeworkRepository(
          onUpdate: (_, _) async => throw ApiRequestException(
            ApiFailure(
              kind: ApiFailureKind.validation,
              statusCode: 422,
              serverCode: ApiErrorCodes.validationFailed,
              message: 'Raw validation response.',
              fieldErrors: const {
                'title': ['Raw title message.'],
                'student_ids': ['Raw Student message.'],
              },
            ),
          ),
        );
        final harness = _Harness(homework: homework);
        final subscription = harness.listenEdit();
        await flushTeacherControllers();
        final controller = harness.enterEditRoute();
        const studentId = '60000000-0000-0000-0000-000000000001';
        controller
          ..updateTitle('Changed title')
          ..updateAssignmentMode(TeacherHomeworkAssignmentMode.selectedStudents)
          ..updateSelectedStudentIds(const {studentId});

        await controller.submit();

        final state = subscription.read();
        expect(state.status, TeacherHomeworkEditStatus.serverValidationFailure);
        expect(state.firstErrorField, TeacherHomeworkFormField.title);
        expect(
          state.errorFor(TeacherHomeworkFormField.studentIds),
          contains('no longer be eligible'),
        );
        expect(state.form!.selectedStudentIds, {studentId});
        expect(state.formError, isNull);
      },
    );
  });

  group('TeacherHomeworkEditController mutation', () {
    test(
      'confirmed success updates detail and refreshes the mounted list once',
      () async {
        final updated = teacherHomework(title: 'Changed title');
        final homework = FakeTeacherHomeworkRepository(
          onUpdate: (_, _) async => updated,
        );
        final harness = _Harness(homework: homework);
        final editSubscription = harness.listenEdit();
        final listSubscription = harness.container.listen(
          teacherHomeworkListControllerProvider(_topicId),
          (_, _) {},
          fireImmediately: true,
        );
        await flushTeacherControllers();
        final controller = harness.enterEditRoute();
        final listController = harness.container.read(
          teacherHomeworkListControllerProvider(_topicId).notifier,
        );
        final invalidSearchDraft = List.filled(161, 'x').join();
        listController.updateSearchDraft(invalidSearchDraft);
        controller.updateTitle('Changed title');

        await controller.submit();
        await flushTeacherControllers();

        expect(
          editSubscription.read().status,
          TeacherHomeworkEditStatus.confirmedSuccess,
        );
        expect(editSubscription.read().confirmedHomework, same(updated));
        expect(editSubscription.read().isDirty, isFalse);
        expect(homework.updateRequests, hasLength(1));
        expect(homework.updateRequests.single.homeworkId, _homeworkId);
        expect(homework.updateRequests.single.request.toJson(), {
          'title': 'Changed title',
        });
        expect(
          harness.container
              .read(teacherHomeworkDetailControllerProvider(harness.target))
              .homework,
          same(updated),
        );
        expect(homework.listRequests, hasLength(2));
        expect(homework.listRequests.last.query, listSubscription.read().query);
        expect(listSubscription.read().searchDraft, invalidSearchDraft);
        expect(listSubscription.read().searchErrorText, isNotNull);
      },
    );

    test(
      'each recognized 409 keeps the attempted draft after one authoritative GET',
      () async {
        const cases = <(String, TeacherHomeworkEditStatus)>[
          (
            ApiErrorCodes.topicNotEditable,
            TeacherHomeworkEditStatus.topicNotEditable,
          ),
          (ApiErrorCodes.taskClosed, TeacherHomeworkEditStatus.taskClosed),
          (ApiErrorCodes.taskArchived, TeacherHomeworkEditStatus.taskArchived),
          (
            ApiErrorCodes.businessConflict,
            TeacherHomeworkEditStatus.businessConflict,
          ),
          (
            ApiErrorCodes.officialTaskRequiresGroupAssignment,
            TeacherHomeworkEditStatus.officialTaskRequiresGroupAssignment,
          ),
        ];
        for (final conflict in cases) {
          var fetches = 0;
          final current = teacherHomework(title: 'Current server title');
          final homework = FakeTeacherHomeworkRepository(
            onFetch: (_) async {
              fetches += 1;
              return fetches == 1 ? teacherHomework() : current;
            },
            onUpdate: (_, _) async =>
                throw teacherServerFailure(conflict.$1, statusCode: 409),
          );
          final harness = _Harness(homework: homework);
          final subscription = harness.listenEdit();
          await flushTeacherControllers();
          final controller = harness.enterEditRoute();
          controller.updateTitle('Attempted title');

          await controller.submit();

          final state = subscription.read();
          expect(state.status, conflict.$2, reason: conflict.$1);
          expect(state.homework, same(current), reason: conflict.$1);
          expect(state.attemptedDraft!.title, 'Attempted title');
          expect(state.reconciliationConflictCode, conflict.$1);
          expect(homework.fetchIds, hasLength(2), reason: conflict.$1);
          expect(homework.updateRequests, hasLength(1), reason: conflict.$1);
          expect(
            harness.container
                .read(teacherHomeworkDetailControllerProvider(harness.target))
                .homework,
            same(current),
            reason: conflict.$1,
          );
        }
      },
    );

    test(
      'unknown mutation matching GET becomes success with one list refresh',
      () async {
        var fetches = 0;
        final current = teacherHomework(title: 'Changed title');
        final homework = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetches += 1;
            return fetches == 1 ? teacherHomework() : current;
          },
          onUpdate: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
        );
        final harness = _Harness(homework: homework);
        final subscription = harness.listenEdit();
        harness.container.listen(
          teacherHomeworkListControllerProvider(_topicId),
          (_, _) {},
          fireImmediately: true,
        );
        await flushTeacherControllers();
        final controller = harness.enterEditRoute();
        controller.updateTitle('Changed title');

        await controller.submit();
        await flushTeacherControllers();

        expect(
          subscription.read().status,
          TeacherHomeworkEditStatus.confirmedSuccess,
        );
        expect(subscription.read().confirmedHomework, same(current));
        expect(homework.fetchIds, hasLength(2));
        expect(homework.updateRequests, hasLength(1));
        expect(homework.listRequests, hasLength(2));
      },
    );

    test(
      'unknown mutation differing GET preserves attempted and current values',
      () async {
        var fetches = 0;
        final current = teacherHomework(title: 'Different server title');
        final homework = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetches += 1;
            return fetches == 1 ? teacherHomework() : current;
          },
          onUpdate: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
        );
        final harness = _Harness(homework: homework);
        final subscription = harness.listenEdit();
        await flushTeacherControllers();
        final controller = harness.enterEditRoute();
        controller.updateTitle('Attempted title');

        await controller.submit();

        final state = subscription.read();
        expect(state.status, TeacherHomeworkEditStatus.unconfirmedCurrentState);
        expect(state.homework, same(current));
        expect(state.attemptedDraft!.title, 'Attempted title');
        expect(state.pendingRequest, isNotNull);
        expect(homework.updateRequests, hasLength(1));
        expect(homework.fetchIds, hasLength(2));
      },
    );

    test(
      'failed reconciliation exposes Check current Homework without replay',
      () async {
        var fetches = 0;
        final current = teacherHomework(title: 'Changed title');
        final homework = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetches += 1;
            if (fetches == 1) {
              return teacherHomework();
            }
            if (fetches == 2) {
              throw teacherLocalFailure(ApiFailureKind.timeout);
            }
            return current;
          },
          onUpdate: (_, _) async =>
              throw const TeacherHomeworkMutationOutcomeUnknownException(),
        );
        final harness = _Harness(homework: homework);
        final subscription = harness.listenEdit();
        await flushTeacherControllers();
        final controller = harness.enterEditRoute();
        controller.updateTitle('Changed title');

        await controller.submit();

        expect(
          subscription.read().status,
          TeacherHomeworkEditStatus.outcomeUnknown,
        );
        expect(subscription.read().pendingRequest, isNotNull);
        expect(homework.updateRequests, hasLength(1));

        await controller.checkCurrentHomework();

        expect(
          subscription.read().status,
          TeacherHomeworkEditStatus.confirmedSuccess,
        );
        expect(homework.fetchIds, hasLength(3));
        expect(homework.updateRequests, hasLength(1));
      },
    );

    test('404 marks detail notFound and refreshes the Topic list', () async {
      final homework = FakeTeacherHomeworkRepository(
        onUpdate: (_, _) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      );
      final harness = _Harness(homework: homework);
      final subscription = harness.listenEdit();
      harness.container.listen(
        teacherHomeworkListControllerProvider(_topicId),
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();
      final controller = harness.enterEditRoute();
      controller.updateTitle('Changed title');

      await controller.submit();
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherHomeworkEditStatus.unavailable);
      expect(
        harness.container
            .read(teacherHomeworkDetailControllerProvider(harness.target))
            .status,
        TeacherHomeworkDetailStatus.notFound,
      );
      expect(homework.updateRequests, hasLength(1));
      expect(homework.listRequests, hasLength(2));
    });

    test(
      'completion after route target ownership is left cannot publish',
      () async {
        final pending = Completer<TeacherHomework>();
        final homework = FakeTeacherHomeworkRepository(
          onUpdate: (_, _) => pending.future,
        );
        final harness = _Harness(homework: homework);
        final subscription = harness.listenEdit();
        await flushTeacherControllers();
        final controller = harness.enterEditRoute();
        controller.updateTitle('Changed title');

        final submission = controller.submit();
        controller.leaveRoute();
        pending.complete(teacherHomework(title: 'Changed title'));
        await submission;

        expect(subscription.read().confirmedHomework, isNull);
        expect(homework.updateRequests, hasLength(1));
      },
    );

    test('completion from a replaced Teacher session is ignored', () async {
      final pending = Completer<TeacherHomework>();
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final homework = FakeTeacherHomeworkRepository(
        onUpdate: (_, _) => pending.future,
      );
      final harness = _Harness(auth: auth, homework: homework);
      final subscription = harness.listenEdit();
      await flushTeacherControllers();
      final controller = harness.enterEditRoute();
      controller.updateTitle('Changed title');

      final submission = controller.submit();
      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(teacherHomework(title: 'Changed title'));
      await submission;
      await flushTeacherControllers();

      expect(subscription.read().confirmedHomework, isNull);
      expect(homework.updateRequests, hasLength(1));
    });
  });
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
    target = TeacherHomeworkRouteTarget(
      topicId: _topicId,
      homeworkId: _homeworkId,
    );
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
  late final TeacherHomeworkRouteTarget target;
  late final ProviderContainer container;

  ProviderSubscription<TeacherHomeworkEditState> listenEdit() {
    return container.listen(
      teacherHomeworkEditControllerProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherHomeworkEditController enterEditRoute() {
    return container.read(
      teacherHomeworkEditControllerProvider(target).notifier,
    )..enterRoute();
  }
}

TeacherSessionKey _sessionKey(_Harness harness) {
  return TeacherSessionSnapshot.fromSession(
    harness.container.read(authSessionControllerProvider),
    AppDeviceSurface.desktop,
  ).eligibleKey!;
}
