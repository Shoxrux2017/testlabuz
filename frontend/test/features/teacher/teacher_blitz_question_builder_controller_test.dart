import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_question_builder_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_blitz_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_builder_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _blitzId = '80000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherBlitzQuestionBuilderController editability', () {
    test('Draft and Scheduled Blitz permit staged keyboard moves', () async {
      for (final status in [
        TeacherBlitzStatus.draft,
        TeacherBlitzStatus.scheduled,
      ]) {
        final questions = _questions(2);
        final harness = _BuilderHarness(
          initialBlitz: teacherBlitz(
            status: status,
            scheduledAt: status == TeacherBlitzStatus.scheduled
                ? DateTime.utc(2026, 9, 18, 4)
                : null,
            questions: questions,
          ),
        );
        final subscription = await harness.listenAndEnterRoute();

        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: harness.ownerGeneration!,
        );

        expect(subscription.read().draftOrderIds, [
          questions[1].id,
          questions[0].id,
        ], reason: status.value);
        expect(subscription.read().orderDirty, isTrue, reason: status.value);
      }
    });

    test('Active, Closed, and Archived Blitz are review-only', () async {
      for (final status in [
        TeacherBlitzStatus.active,
        TeacherBlitzStatus.closed,
        TeacherBlitzStatus.archived,
      ]) {
        final questions = _questions(2);
        final harness = _BuilderHarness(
          initialBlitz: teacherBlitz(status: status, questions: questions),
        );
        final subscription = await harness.listenAndEnterRoute();

        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: harness.ownerGeneration!,
        );
        await harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: harness.ownerGeneration!,
        );
        await harness.controller.saveOrder(
          ownerGeneration: harness.ownerGeneration!,
        );

        expect(subscription.read().draftOrderIds, _ids(questions));
        expect(
          harness.repository.deleteQuestionIds,
          isEmpty,
          reason: '$status',
        );
        expect(harness.repository.reorderQuestionRequests, isEmpty);
      }
    });

    test('a result-pair lock is not a Blitz Question-authoring lock', () async {
      final questions = _questions(2);
      final harness = _BuilderHarness(
        initialBlitz: teacherBlitz(questions: questions),
        onDelete: (_) async => throw teacherServerFailure(
          ApiErrorCodes.resultPairLocked,
          statusCode: 409,
        ),
      );
      final subscription = await harness.listenAndEnterRoute();
      final readsBefore = harness.repository.fetchIds.length;

      await harness.controller.deleteQuestion(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );

      expect(subscription.read().serverLocked, isFalse);
      expect(
        subscription.read().notice,
        'The Question change could not be completed.',
      );
      expect(harness.repository.fetchIds.length, readsBefore);
      harness.controller.moveQuestionDown(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      expect(subscription.read().orderDirty, isTrue);
    });
  });

  group('TeacherBlitzQuestionBuilderController order', () {
    test('move up/down stages order and Reset restores authority', () async {
      final questions = _questions(3);
      final harness = _BuilderHarness(
        initialBlitz: teacherBlitz(questions: questions),
      );
      final subscription = await harness.listenAndEnterRoute();

      harness.controller.moveQuestionUp(
        questions[2].id,
        ownerGeneration: harness.ownerGeneration!,
      );
      expect(subscription.read().draftOrderIds, [
        questions[0].id,
        questions[2].id,
        questions[1].id,
      ]);

      harness.controller.resetOrder(ownerGeneration: harness.ownerGeneration!);

      expect(subscription.read().draftOrderIds, _ids(questions));
      expect(subscription.read().orderDirty, isFalse);
    });

    test('Save order sends every ID and adopts the returned Blitz', () async {
      final questions = _questions(3);
      final reordered = [questions[1], questions[0], questions[2]];
      final harness = _BuilderHarness(
        initialBlitz: teacherBlitz(questions: questions),
        onReorder: (id, request) async => teacherBlitz(
          id: id,
          totalPossiblePoints: 30,
          questions: _positioned(reordered),
        ),
      );
      final subscription = await harness.listenAndEnterRoute();
      harness.listenToList();
      await flushTeacherControllers();
      final listReadsBefore = harness.repository.listRequests.length;
      harness.controller.moveQuestionDown(
        questions[0].id,
        ownerGeneration: harness.ownerGeneration!,
      );

      await harness.controller.saveOrder(
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(
        harness.repository.reorderQuestionRequests.single.request.questionIds,
        _ids(reordered),
      );
      expect(subscription.read().status, TeacherQuestionBuilderStatus.ready);
      expect(subscription.read().notice, 'Questions reordered successfully.');
      expect(subscription.read().authoritativeOrderIds, _ids(reordered));
      expect(subscription.read().orderDirty, isFalse);
      expect(harness.currentDetail!.totalPossiblePoints, 30);
      expect(harness.repository.listRequests.length, listReadsBefore + 1);
      expect(harness.mutationActivity.isActive, isFalse);
    });

    test('an uncertain reorder is success only for the exact order', () async {
      final questions = _questions(2);
      final reordered = [questions[1], questions[0]];
      var reads = 0;
      final harness = _BuilderHarness(
        repository: FakeTeacherBlitzRepository(
          onFetch: (id) async {
            reads += 1;
            return teacherBlitz(
              id: id,
              questions: reads == 1 ? questions : _positioned(reordered),
            );
          },
          onReorderQuestions: (_, _) async =>
              throw const TeacherQuestionMutationOutcomeUnknownException(
                TeacherQuestionMutationOperation.reorder,
              ),
        ),
      );
      final subscription = await harness.listenAndEnterRoute();
      harness.controller.moveQuestionDown(
        questions[0].id,
        ownerGeneration: harness.ownerGeneration!,
      );

      await harness.controller.saveOrder(
        ownerGeneration: harness.ownerGeneration!,
      );

      expect(subscription.read().notice, 'Questions reordered successfully.');
      expect(harness.repository.reorderQuestionRequests, hasLength(1));
    });

    test(
      'an uncertain reorder with a different order requires review',
      () async {
        final questions = _questions(2);
        final harness = _BuilderHarness(
          initialBlitz: teacherBlitz(questions: questions),
          onReorder: (_, _) async =>
              throw const TeacherQuestionMutationOutcomeUnknownException(
                TeacherQuestionMutationOperation.reorder,
              ),
        );
        final subscription = await harness.listenAndEnterRoute();
        harness.controller.moveQuestionDown(
          questions[0].id,
          ownerGeneration: harness.ownerGeneration!,
        );

        await harness.controller.saveOrder(
          ownerGeneration: harness.ownerGeneration!,
        );

        expect(
          subscription.read().notice,
          'The reorder result could not be confirmed. Review the current '
          'Question order before trying again.',
        );
        expect(subscription.read().draftOrderIds, _ids(questions));
        expect(harness.repository.reorderQuestionRequests, hasLength(1));
      },
    );
  });

  group('TeacherBlitzQuestionBuilderController delete', () {
    test(
      'a confirmed delete adopts the returned authoritative Blitz',
      () async {
        final questions = _questions(2);
        final harness = _BuilderHarness(
          initialBlitz: teacherBlitz(questions: questions),
          onDelete: (_) async => teacherBlitz(
            totalPossiblePoints: 5,
            questions: _positioned([questions[1]]),
          ),
        );
        final subscription = await harness.listenAndEnterRoute();

        await harness.controller.deleteQuestion(
          questions[0].id,
          ownerGeneration: harness.ownerGeneration!,
        );

        expect(harness.repository.deleteQuestionIds, [questions[0].id]);
        expect(subscription.read().notice, 'Question deleted successfully.');
        expect(subscription.read().authoritativeOrderIds, _ids([questions[1]]));
        expect(harness.currentDetail!.totalPossiblePoints, 5);
      },
    );

    test(
      'an uncertain delete is success only when the Question is absent',
      () async {
        for (final absent in [true, false]) {
          final questions = _questions(2);
          var reads = 0;
          final harness = _BuilderHarness(
            repository: FakeTeacherBlitzRepository(
              onFetch: (id) async {
                reads += 1;
                return teacherBlitz(
                  id: id,
                  questions: reads > 1 && absent
                      ? _positioned([questions[1]])
                      : questions,
                );
              },
              onDeleteQuestion: (_) async =>
                  throw const TeacherQuestionMutationOutcomeUnknownException(
                    TeacherQuestionMutationOperation.delete,
                  ),
            ),
          );
          final subscription = await harness.listenAndEnterRoute();

          await harness.controller.deleteQuestion(
            questions[0].id,
            ownerGeneration: harness.ownerGeneration!,
          );

          expect(
            subscription.read().notice,
            absent
                ? 'Question deleted successfully.'
                : 'The delete result could not be confirmed. Review the current '
                      'Question list before trying again.',
          );
          expect(harness.repository.deleteQuestionIds, hasLength(1));
        }
      },
    );

    test('an unreadable outcome blocks until Check current Blitz', () async {
      final questions = _questions(2);
      var reads = 0;
      final harness = _BuilderHarness(
        repository: FakeTeacherBlitzRepository(
          onFetch: (id) async {
            reads += 1;
            if (reads == 2) {
              throw teacherLocalFailure(ApiFailureKind.connection);
            }
            return teacherBlitz(
              id: id,
              questions: reads == 1 ? questions : _positioned([questions[1]]),
            );
          },
          onDeleteQuestion: (_) async =>
              throw const TeacherQuestionMutationOutcomeUnknownException(
                TeacherQuestionMutationOperation.delete,
              ),
        ),
      );
      final subscription = await harness.listenAndEnterRoute();

      await harness.controller.deleteQuestion(
        questions[0].id,
        ownerGeneration: harness.ownerGeneration!,
      );
      expect(
        subscription.read().status,
        TeacherQuestionBuilderStatus.outcomeReview,
      );
      expect(
        subscription.read().notice,
        'The current Blitz could not be confirmed. Check the current Blitz '
        'before taking another action.',
      );
      expect(subscription.read().blocksNavigation, isTrue);
      await harness.controller.deleteQuestion(
        questions[1].id,
        ownerGeneration: harness.ownerGeneration!,
      );
      expect(harness.repository.deleteQuestionIds, hasLength(1));

      await harness.controller.checkCurrentBlitz(
        ownerGeneration: harness.ownerGeneration!,
      );

      expect(subscription.read().notice, 'Question deleted successfully.');
      expect(harness.repository.deleteQuestionIds, hasLength(1));
      expect(harness.mutationActivity.isActive, isFalse);
    });
  });

  group('TeacherBlitzQuestionBuilderController conflicts', () {
    test('lifecycle conflicts refresh the Blitz without retrying', () async {
      for (final (code, message, refreshedStatus) in [
        (
          ApiErrorCodes.businessConflict,
          'Question editing is locked by the current server state. Review '
              'the current Blitz before continuing.',
          TeacherBlitzStatus.active,
        ),
        (
          ApiErrorCodes.taskClosed,
          'This Blitz is closed.',
          TeacherBlitzStatus.closed,
        ),
        (
          ApiErrorCodes.taskArchived,
          'This Blitz is archived.',
          TeacherBlitzStatus.archived,
        ),
        (
          ApiErrorCodes.topicNotEditable,
          'The Topic is no longer editable.',
          TeacherBlitzStatus.draft,
        ),
      ]) {
        final questions = _questions(2);
        var reads = 0;
        final harness = _BuilderHarness(
          repository: FakeTeacherBlitzRepository(
            onFetch: (id) async {
              reads += 1;
              return teacherBlitz(
                id: id,
                status: reads == 1 ? TeacherBlitzStatus.draft : refreshedStatus,
                questions: questions,
              );
            },
            onDeleteQuestion: (_) async =>
                throw teacherServerFailure(code, statusCode: 409),
          ),
        );
        final subscription = await harness.listenAndEnterRoute();

        await harness.controller.deleteQuestion(
          questions[0].id,
          ownerGeneration: harness.ownerGeneration!,
        );
        harness.controller.moveQuestionDown(
          questions[0].id,
          ownerGeneration: harness.ownerGeneration!,
        );

        expect(subscription.read().notice, message, reason: code);
        expect(subscription.read().orderDirty, isFalse, reason: code);
        expect(harness.currentDetail!.status, refreshedStatus);
        expect(
          subscription.read().serverLocked,
          code == ApiErrorCodes.businessConflict,
        );
        expect(
          subscription.read().topicNotEditable,
          code == ApiErrorCodes.topicNotEditable,
        );
        expect(harness.repository.deleteQuestionIds, hasLength(1));
      }
    });
  });

  group('TeacherBlitzQuestionBuilderController ownership', () {
    test('a Blitz lifecycle mutation blocks Question mutations', () async {
      final questions = _questions(2);
      final harness = _BuilderHarness(
        initialBlitz: teacherBlitz(questions: questions),
      );
      await harness.listenAndEnterRoute();
      harness.container
          .read(
            teacherBlitzRouteMutationActivityProvider(harness.target).notifier,
          )
          .begin(TeacherBlitzRouteMutationOperation.activate);

      await harness.controller.deleteQuestion(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );

      expect(harness.repository.deleteQuestionIds, isEmpty);
    });

    test('a completion after route exit cannot publish', () async {
      final questions = _questions(2);
      final pending = Completer<TeacherBlitz>();
      final harness = _BuilderHarness(
        initialBlitz: teacherBlitz(questions: questions),
        onDelete: (_) => pending.future,
      );
      final subscription = await harness.listenAndEnterRoute();
      unawaited(
        harness.controller.deleteQuestion(
          questions[0].id,
          ownerGeneration: harness.ownerGeneration!,
        ),
      );
      await flushTeacherControllers();

      harness.controller.leaveRoute(harness.ownerGeneration);
      pending.complete(teacherBlitz(questions: _positioned([questions[1]])));
      await flushTeacherControllers();

      expect(
        subscription.read().notice,
        isNot('Question deleted successfully.'),
      );
      expect(harness.currentDetail!.questions, hasLength(2));
    });

    test('a completion from a replaced session is ignored', () async {
      final questions = _questions(2);
      final pending = Completer<TeacherBlitz>();
      final harness = _BuilderHarness(
        initialBlitz: teacherBlitz(questions: questions),
        onDelete: (_) => pending.future,
      );
      final subscription = await harness.listenAndEnterRoute();
      unawaited(
        harness.controller.deleteQuestion(
          questions[0].id,
          ownerGeneration: harness.ownerGeneration!,
        ),
      );
      await flushTeacherControllers();

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(teacherBlitz(questions: _positioned([questions[1]])));
      await flushTeacherControllers();

      expect(
        subscription.read().notice,
        isNot('Question deleted successfully.'),
      );
      expect(harness.repository.deleteQuestionIds, hasLength(1));
    });
  });
}

class _BuilderHarness {
  _BuilderHarness({
    TeacherBlitz? initialBlitz,
    FakeTeacherBlitzRepository? repository,
    Future<TeacherBlitz> Function(String questionId)? onDelete,
    Future<TeacherBlitz> Function(
      String blitzId,
      TeacherQuestionReorderRequest request,
    )?
    onReorder,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ),
       repository =
           repository ??
           FakeTeacherBlitzRepository(
             onFetch: (_) async => initialBlitz ?? teacherBlitz(),
             onDeleteQuestion: onDelete,
             onReorderQuestions: onReorder,
           ) {
    target = TeacherBlitzRouteTarget(topicId: _topicId, blitzId: _blitzId);
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherBlitzRepositoryProvider.overrideWithValue(this.repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherBlitzRepository repository;
  late final TeacherBlitzRouteTarget target;
  late final ProviderContainer container;
  int? ownerGeneration;

  Future<ProviderSubscription<TeacherQuestionBuilderState>>
  listenAndEnterRoute() async {
    final subscription = container.listen(
      teacherBlitzQuestionBuilderControllerProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
    ownerGeneration = controller.enterRoute();
    await flushTeacherControllers();
    return subscription;
  }

  void listenToList() {
    container.listen(
      teacherBlitzListControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  TeacherBlitzQuestionBuilderController get controller => container.read(
    teacherBlitzQuestionBuilderControllerProvider(target).notifier,
  );

  TeacherQuestionMutationActivityState get mutationActivity =>
      container.read(teacherQuestionMutationActivityProvider(target));

  TeacherBlitz? get currentDetail =>
      container.read(teacherBlitzDetailControllerProvider(target)).blitz;

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    AppDeviceSurface.desktop,
  ).eligibleKey!;
}

List<TeacherQuestion> _questions(int count) =>
    _positioned(teacherHomeworkQuestions().take(count).toList());

List<String> _ids(List<TeacherQuestion> questions) =>
    questions.map((question) => question.id.toLowerCase()).toList();

List<TeacherQuestion> _positioned(List<TeacherQuestion> questions) {
  return [
    for (var index = 0; index < questions.length; index += 1)
      TeacherQuestion(
        id: questions[index].id,
        type: questions[index].type,
        prompt: questions[index].prompt,
        instructions: questions[index].instructions,
        points: questions[index].points,
        position: index + 1,
        checkingMode: questions[index].checkingMode,
        configuration: questions[index].configuration,
      ),
  ];
}
