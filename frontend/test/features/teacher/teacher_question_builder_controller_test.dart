import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_route_target.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_builder_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_builder_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_question_mutation_activity.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_session_key.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '50000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherQuestionBuilderController editability and local order', () {
    test('draft and active Homework permit staged keyboard moves', () async {
      for (final status in [
        TeacherHomeworkStatus.draft,
        TeacherHomeworkStatus.active,
      ]) {
        final questions = teacherHomeworkQuestions().take(2).toList();
        final harness = _BuilderHarness(
          initialHomework: teacherHomework(
            status: status,
            questions: questions,
          ),
        );
        final subscription = await harness.listenAndEnterRoute();

        expect(subscription.read().status, TeacherQuestionBuilderStatus.ready);
        expect(subscription.read().orderInitialized, isTrue);
        expect(subscription.read().serverLocked, isFalse);
        expect(subscription.read().authoritativeOrderIds, _ids(questions));

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

    test('closed and archived Homework remain review-only', () async {
      for (final status in [
        TeacherHomeworkStatus.closed,
        TeacherHomeworkStatus.archived,
      ]) {
        final questions = teacherHomeworkQuestions().take(2).toList();
        final harness = _BuilderHarness(
          initialHomework: teacherHomework(
            status: status,
            questions: questions,
          ),
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

        expect(subscription.read().draftOrderIds, _ids(questions));
        expect(subscription.read().orderDirty, isFalse);
        expect(harness.repository.deleteQuestionIds, isEmpty);
      }
    });

    test('serverLocked blocks all further Question mutations', () async {
      final questions = teacherHomeworkQuestions().take(2).toList();
      final harness = _BuilderHarness(
        initialHomework: teacherHomework(questions: questions),
      );
      final subscription = await harness.listenAndEnterRoute();
      harness.controller.showEditorNotice(
        sessionKey: harness.sessionKey,
        ownerGeneration: harness.ownerGeneration!,
        notice: 'Locked by server.',
        serverLocked: true,
      );

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

      expect(subscription.read().serverLocked, isTrue);
      expect(subscription.read().draftOrderIds, _ids(questions));
      expect(harness.repository.deleteQuestionIds, isEmpty);
      expect(harness.repository.reorderQuestionRequests, isEmpty);
    });

    test('move up/down stages order and Reset restores authority', () async {
      final questions = teacherHomeworkQuestions().take(3).toList();
      final harness = _BuilderHarness(
        initialHomework: teacherHomework(questions: questions),
      );
      final subscription = await harness.listenAndEnterRoute();

      harness.controller.moveQuestionUp(
        questions[1].id,
        ownerGeneration: harness.ownerGeneration!,
      );
      expect(subscription.read().draftOrderIds, [
        questions[1].id,
        questions[0].id,
        questions[2].id,
      ]);
      expect(subscription.read().orderDirty, isTrue);

      harness.controller.moveQuestionDown(
        questions[1].id,
        ownerGeneration: harness.ownerGeneration!,
      );
      expect(subscription.read().draftOrderIds, _ids(questions));
      expect(subscription.read().orderDirty, isFalse);

      harness.controller.moveQuestionDown(
        questions[1].id,
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

    test('authoritative ID/order change discards a dirty local order', () async {
      final questions = teacherHomeworkQuestions().take(3).toList();
      final harness = _BuilderHarness(
        initialHomework: teacherHomework(questions: questions.take(2).toList()),
      );
      final subscription = await harness.listenAndEnterRoute();
      harness.controller.moveQuestionDown(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      expect(subscription.read().orderDirty, isTrue);

      final current = teacherHomework(
        questions: _orderedQuestions([
          questions[1],
          questions[0],
          questions[2],
        ]),
      );
      harness.acceptAuthoritative(current);
      await flushTeacherControllers();

      expect(subscription.read().authoritativeOrderIds, [
        questions[1].id,
        questions[0].id,
        questions[2].id,
      ]);
      expect(subscription.read().draftOrderIds, [
        questions[1].id,
        questions[0].id,
        questions[2].id,
      ]);
      expect(subscription.read().orderDirty, isFalse);
      expect(
        subscription.read().notice,
        'The Question list changed on the server. Review the current order before reordering again.',
      );
    });
  });

  group('TeacherQuestionBuilderController delete', () {
    test(
      'newer detail state forces confirmed delete through reconciliation GET',
      () async {
        final questions = teacherHomeworkQuestions().take(2).toList();
        final initial = teacherHomework(
          questions: questions,
          totalPossiblePoints: 3,
        );
        final newerDetail = teacherHomework(
          title: 'Newer detail authority',
          questions: questions,
          totalPossiblePoints: 30,
        );
        final olderMutationResponse = teacherHomework(
          title: 'Older mutation response',
          questions: [_copyQuestion(questions[1], position: 1)],
          totalPossiblePoints: 2,
        );
        final reconciled = teacherHomework(
          title: 'Post-response GET authority',
          questions: [_copyQuestion(questions[1], position: 1)],
          totalPossiblePoints: 44,
        );
        final pending = Completer<TeacherHomework>();
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return fetchCount == 1 ? initial : reconciled;
          },
          onDeleteQuestion: (_) => pending.future,
        );
        final harness = _BuilderHarness(repository: repository);
        final subscription = await harness.listenAndEnterRoute();

        final deletion = harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: harness.ownerGeneration!,
        );
        harness.acceptAuthoritative(newerDetail);
        await flushTeacherControllers();
        expect(harness.currentDetail, same(newerDetail));

        pending.complete(olderMutationResponse);
        await deletion;
        await flushTeacherControllers();

        expect(fetchCount, 2);
        expect(repository.deleteQuestionIds, [questions.first.id]);
        expect(harness.currentDetail, same(reconciled));
        expect(harness.currentDetail, isNot(same(olderMutationResponse)));
        expect(harness.currentDetail!.totalPossiblePoints, 44);
        expect(subscription.read().notice, 'Question deleted successfully.');
      },
    );

    test('confirmed delete accepts complete authoritative Homework', () async {
      final questions = teacherHomeworkQuestions().take(2).toList();
      final returned = teacherHomework(
        questions: [_copyQuestion(questions[1], position: 1)],
        totalPossiblePoints: 42,
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => teacherHomework(questions: questions),
        onDeleteQuestion: (_) async => returned,
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();

      await harness.controller.deleteQuestion(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(repository.deleteQuestionIds, [questions.first.id]);
      expect(subscription.read().status, TeacherQuestionBuilderStatus.ready);
      expect(subscription.read().notice, 'Question deleted successfully.');
      expect(subscription.read().draftOrderIds, [questions[1].id]);
      expect(harness.currentDetail, same(returned));
      expect(harness.currentDetail!.totalPossiblePoints, 42);
    });

    test('unknown delete is success only when target is absent', () async {
      final questions = teacherHomeworkQuestions().take(2).toList();
      var fetchCount = 0;
      final current = teacherHomework(
        questions: [_copyQuestion(questions[1], position: 1)],
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return fetchCount == 1
              ? teacherHomework(questions: questions)
              : current;
        },
        onDeleteQuestion: (_) async =>
            throw const TeacherQuestionMutationOutcomeUnknownException(
              TeacherQuestionMutationOperation.delete,
            ),
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();

      await harness.controller.deleteQuestion(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(repository.deleteQuestionIds, hasLength(1));
      expect(fetchCount, 2);
      expect(subscription.read().notice, 'Question deleted successfully.');
      expect(subscription.read().draftOrderIds, [questions[1].id]);
      expect(harness.currentDetail, same(current));
    });

    test('unknown delete with target present enters safe review', () async {
      final questions = teacherHomeworkQuestions().take(2).toList();
      var fetchCount = 0;
      final current = teacherHomework(questions: questions);
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return current;
        },
        onDeleteQuestion: (_) async =>
            throw const TeacherQuestionMutationOutcomeUnknownException(
              TeacherQuestionMutationOperation.delete,
            ),
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();

      await harness.controller.deleteQuestion(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(fetchCount, 2);
      expect(
        subscription.read().notice,
        'The delete result could not be confirmed. Review the current Question list before trying again.',
      );
      expect(subscription.read().draftOrderIds, _ids(questions));
      expect(harness.currentDetail, same(current));
    });

    test('scoreable conflict reconciles without setting serverLocked', () async {
      final question = teacherHomeworkQuestions().first;
      final current = teacherHomework(
        status: TeacherHomeworkStatus.active,
        questions: [question],
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => current,
        onDeleteQuestion: (_) async => throw teacherServerFailure(
          ApiErrorCodes.assessmentHasNoScoreablePoints,
          statusCode: 409,
        ),
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();

      await harness.controller.deleteQuestion(
        question.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(subscription.read().serverLocked, isFalse);
      expect(
        subscription.read().notice,
        'An active Homework must keep at least one scoreable Question. Add or adjust another Question before deleting this one.',
      );
      expect(subscription.read().draftOrderIds, [question.id]);
      expect(harness.currentDetail, same(current));
    });

    test(
      'business and result-pair locks survive refresh and block mutations',
      () async {
        for (final code in [
          ApiErrorCodes.businessConflict,
          ApiErrorCodes.resultPairLocked,
        ]) {
          final questions = teacherHomeworkQuestions().take(2).toList();
          var fetchCount = 0;
          final current = teacherHomework(questions: questions);
          final repository = FakeTeacherHomeworkRepository(
            onFetch: (_) async {
              fetchCount += 1;
              return current;
            },
            onDeleteQuestion: (_) async =>
                throw teacherServerFailure(code, statusCode: 409),
          );
          final harness = _BuilderHarness(repository: repository);
          final subscription = await harness.listenAndEnterRoute();

          await harness.controller.deleteQuestion(
            questions.first.id,
            ownerGeneration: harness.ownerGeneration!,
          );
          await flushTeacherControllers();

          expect(fetchCount, 2, reason: code);
          expect(subscription.read().serverLocked, isTrue, reason: code);
          expect(
            subscription.read().notice,
            contains('locked by the current server state'),
            reason: code,
          );

          harness.controller.refresh(ownerGeneration: harness.ownerGeneration!);
          await flushTeacherControllers();

          expect(fetchCount, 3, reason: code);
          expect(subscription.read().serverLocked, isTrue, reason: code);

          harness.controller.moveQuestionDown(
            questions.first.id,
            ownerGeneration: harness.ownerGeneration!,
          );
          await harness.controller.saveOrder(
            ownerGeneration: harness.ownerGeneration!,
          );
          await harness.controller.deleteQuestion(
            questions.last.id,
            ownerGeneration: harness.ownerGeneration!,
          );

          expect(subscription.read().draftOrderIds, _ids(questions));
          expect(repository.deleteQuestionIds, [questions.first.id]);
          expect(repository.reorderQuestionRequests, isEmpty);
        }
      },
    );
  });

  group('TeacherQuestionBuilderController reorder', () {
    test(
      'Save sends one complete order and accepts confirmed response',
      () async {
        final questions = teacherHomeworkQuestions().take(2).toList();
        late TeacherHomework returned;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(questions: questions),
          onReorderQuestions: (_, _) async => returned,
        );
        final harness = _BuilderHarness(repository: repository);
        final subscription = await harness.listenAndEnterRoute();
        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: harness.ownerGeneration!,
        );
        returned = teacherHomework(
          questions: _orderedQuestions([questions[1], questions[0]]),
          totalPossiblePoints: 23,
        );

        await harness.controller.saveOrder(
          ownerGeneration: harness.ownerGeneration!,
        );
        await flushTeacherControllers();

        expect(repository.reorderQuestionRequests, hasLength(1));
        expect(repository.reorderQuestionRequests.single.request.questionIds, [
          questions[1].id,
          questions[0].id,
        ]);
        expect(subscription.read().orderDirty, isFalse);
        expect(subscription.read().authoritativeOrderIds, [
          questions[1].id,
          questions[0].id,
        ]);
        expect(subscription.read().notice, 'Questions reordered successfully.');
        expect(harness.currentDetail, same(returned));
      },
    );

    test('unknown reorder exact GET order proves success', () async {
      final questions = teacherHomeworkQuestions().take(2).toList();
      var fetchCount = 0;
      final initial = teacherHomework(questions: questions);
      final current = teacherHomework(
        questions: _orderedQuestions([questions[1], questions[0]]),
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return fetchCount == 1 ? initial : current;
        },
        onReorderQuestions: (_, _) async =>
            throw const TeacherQuestionMutationOutcomeUnknownException(
              TeacherQuestionMutationOperation.reorder,
            ),
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();
      harness.controller.moveQuestionDown(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );

      await harness.controller.saveOrder(
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(repository.reorderQuestionRequests, hasLength(1));
      expect(fetchCount, 2);
      expect(subscription.read().notice, 'Questions reordered successfully.');
      expect(subscription.read().draftOrderIds, [
        questions[1].id,
        questions[0].id,
      ]);
      expect(subscription.read().orderDirty, isFalse);
    });

    test(
      'unknown reorder mismatch resets to authoritative review order',
      () async {
        final questions = teacherHomeworkQuestions().take(3).toList();
        var fetchCount = 0;
        final initial = teacherHomework(questions: questions);
        final current = teacherHomework(
          questions: _orderedQuestions([
            questions[2],
            questions[0],
            questions[1],
          ]),
        );
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return fetchCount == 1 ? initial : current;
          },
          onReorderQuestions: (_, _) async =>
              throw const TeacherQuestionMutationOutcomeUnknownException(
                TeacherQuestionMutationOperation.reorder,
              ),
        );
        final harness = _BuilderHarness(repository: repository);
        final subscription = await harness.listenAndEnterRoute();
        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: harness.ownerGeneration!,
        );

        await harness.controller.saveOrder(
          ownerGeneration: harness.ownerGeneration!,
        );
        await flushTeacherControllers();

        expect(subscription.read().draftOrderIds, [
          questions[2].id,
          questions[0].id,
          questions[1].id,
        ]);
        expect(subscription.read().orderDirty, isFalse);
        expect(
          subscription.read().notice,
          'The reorder result could not be confirmed. Review the current Question order before trying again.',
        );
      },
    );

    test(
      '422 reorder reconciliation resets stale IDs with safe notice',
      () async {
        final questions = teacherHomeworkQuestions().take(3).toList();
        var fetchCount = 0;
        final initial = teacherHomework(questions: questions.take(2).toList());
        final current = teacherHomework(questions: questions);
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async {
            fetchCount += 1;
            return fetchCount == 1 ? initial : current;
          },
          onReorderQuestions: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.validationFailed,
            statusCode: 422,
          ),
        );
        final harness = _BuilderHarness(repository: repository);
        final subscription = await harness.listenAndEnterRoute();
        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: harness.ownerGeneration!,
        );

        await harness.controller.saveOrder(
          ownerGeneration: harness.ownerGeneration!,
        );
        await flushTeacherControllers();

        expect(subscription.read().draftOrderIds, _ids(questions));
        expect(subscription.read().orderDirty, isFalse);
        expect(
          subscription.read().notice,
          'The Question list changed. Review the current order and try again.',
        );
      },
    );
  });

  group('TeacherQuestionBuilderController mutation ownership', () {
    test(
      'takeover reloads authority before the newer owner can mutate',
      () async {
        final questions = teacherHomeworkQuestions().take(2).toList();
        final initial = teacherHomework(questions: questions);
        final refreshed = teacherHomework(
          questions: questions,
          totalPossiblePoints: 12,
        );
        final confirmed = teacherHomework(
          questions: [_copyQuestion(questions.first, position: 1)],
          totalPossiblePoints: 11,
        );
        final oldPending = Completer<TeacherHomework>();
        final reloadPending = Completer<TeacherHomework>();
        var fetchCount = 0;
        var deleteCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) {
            fetchCount += 1;
            return fetchCount == 1
                ? Future.value(initial)
                : reloadPending.future;
          },
          onDeleteQuestion: (_) {
            deleteCount += 1;
            return deleteCount == 1
                ? oldPending.future
                : Future.value(confirmed);
          },
        );
        final harness = _BuilderHarness(repository: repository);
        final subscription = await harness.listenAndEnterRoute();
        final oldOwnerGeneration = harness.ownerGeneration!;

        final oldDeletion = harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: oldOwnerGeneration,
        );
        expect(harness.mutationActivity.isActive, isTrue);

        final newOwnerGeneration = harness.controller.enterRoute();
        expect(newOwnerGeneration, isNot(oldOwnerGeneration));
        expect(harness.mutationActivity.isActive, isTrue);
        expect(subscription.read().pendingOperation, isNull);
        expect(subscription.read().authoritativeReloadPending, isTrue);
        expect(subscription.read().sharedMutationActive, isTrue);

        final staleCallbackHomework = teacherHomework(
          questions: const [],
          totalPossiblePoints: 99,
        );
        harness.controller
          ..moveQuestionDown(
            questions.first.id,
            ownerGeneration: oldOwnerGeneration,
          )
          ..refresh(ownerGeneration: oldOwnerGeneration)
          ..showEditorNotice(
            sessionKey: harness.sessionKey,
            ownerGeneration: oldOwnerGeneration,
            notice: 'Stale editor callback.',
            serverLocked: true,
          )
          ..acceptEditorAuthoritativeHomework(
            homework: staleCallbackHomework,
            sessionKey: harness.sessionKey,
            ownerGeneration: oldOwnerGeneration,
            notice: 'Stale authoritative callback.',
          )
          ..markEditorTargetUnavailable(
            harness.sessionKey,
            ownerGeneration: oldOwnerGeneration,
          );
        await harness.controller.deleteQuestion(
          questions[1].id,
          ownerGeneration: oldOwnerGeneration,
        );
        await flushTeacherControllers();
        expect(subscription.read().draftOrderIds, _ids(questions));
        expect(subscription.read().serverLocked, isFalse);
        expect(subscription.read().notice, isNull);
        expect(harness.currentDetail, same(initial));
        expect(fetchCount, 1);
        expect(repository.deleteQuestionIds, [questions.first.id]);

        harness.controller.leaveRoute(oldOwnerGeneration);
        expect(
          harness.controller.isCurrentRouteOwner(
            harness.sessionKey,
            ownerGeneration: newOwnerGeneration,
          ),
          isTrue,
        );
        expect(harness.mutationActivity.isActive, isTrue);

        await harness.controller.deleteQuestion(
          questions[1].id,
          ownerGeneration: newOwnerGeneration,
        );
        oldPending.complete(
          teacherHomework(
            questions: [_copyQuestion(questions[1], position: 1)],
            totalPossiblePoints: 81,
          ),
        );
        await oldDeletion;
        await flushTeacherControllers();

        expect(harness.mutationActivity.isActive, isFalse);
        expect(fetchCount, 2);
        expect(subscription.read().authoritativeReloadPending, isTrue);
        expect(harness.currentDetail, same(initial));
        expect(repository.deleteQuestionIds, [questions.first.id]);

        await harness.controller.deleteQuestion(
          questions[1].id,
          ownerGeneration: newOwnerGeneration,
        );
        expect(repository.deleteQuestionIds, [questions.first.id]);

        reloadPending.complete(refreshed);
        await flushTeacherControllers();

        expect(subscription.read().authoritativeReloadPending, isFalse);
        expect(subscription.read().sharedMutationActive, isFalse);
        expect(harness.currentDetail, same(refreshed));

        await harness.controller.deleteQuestion(
          questions[1].id,
          ownerGeneration: newOwnerGeneration,
        );
        await flushTeacherControllers();

        expect(repository.deleteQuestionIds, [
          questions.first.id,
          questions[1].id,
        ]);
        expect(harness.currentDetail, same(confirmed));
        expect(subscription.read().notice, 'Question deleted successfully.');

        harness.controller.leaveRoute(newOwnerGeneration);
        expect(
          harness.controller.isCurrentRouteOwner(
            harness.sessionKey,
            ownerGeneration: newOwnerGeneration,
          ),
          isFalse,
        );
        expect(harness.mutationActivity.isActive, isFalse);
      },
    );

    test('a second mutation cannot start while delete is pending', () async {
      final questions = teacherHomeworkQuestions().take(2).toList();
      final pending = Completer<TeacherHomework>();
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => teacherHomework(questions: questions),
        onDeleteQuestion: (_) => pending.future,
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();

      final first = harness.controller.deleteQuestion(
        questions.first.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      await harness.controller.deleteQuestion(
        questions[1].id,
        ownerGeneration: harness.ownerGeneration!,
      );

      expect(subscription.read().status, TeacherQuestionBuilderStatus.deleting);
      expect(repository.deleteQuestionIds, [questions.first.id]);
      pending.complete(
        teacherHomework(questions: [_copyQuestion(questions[1], position: 1)]),
      );
      await first;
      expect(repository.deleteQuestionIds, hasLength(1));
    });

    test('failed reconciliation blocks replay until Check current', () async {
      final question = teacherHomeworkQuestions().first;
      var fetchCount = 0;
      final initial = teacherHomework(questions: [question]);
      final current = teacherHomework(questions: const []);
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          if (fetchCount == 1) return initial;
          if (fetchCount == 2) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return current;
        },
        onDeleteQuestion: (_) async =>
            throw const TeacherQuestionMutationOutcomeUnknownException(
              TeacherQuestionMutationOperation.delete,
            ),
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();

      await harness.controller.deleteQuestion(
        question.id,
        ownerGeneration: harness.ownerGeneration!,
      );

      expect(
        subscription.read().status,
        TeacherQuestionBuilderStatus.outcomeReview,
      );
      expect(
        subscription.read().notice,
        contains('Check the current Homework'),
      );
      await harness.controller.deleteQuestion(
        question.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      expect(repository.deleteQuestionIds, hasLength(1));

      await harness.controller.checkCurrentHomework(
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(fetchCount, 3);
      expect(repository.deleteQuestionIds, hasLength(1));
      expect(subscription.read().status, TeacherQuestionBuilderStatus.ready);
      expect(subscription.read().notice, 'Question deleted successfully.');
    });

    test(
      'outcome review survives listener disposal as a required reload',
      () async {
        final questions = teacherHomeworkQuestions().take(2).toList();
        final initial = teacherHomework(questions: questions);
        final naturalReentry = Completer<TeacherHomework>();
        final requiredReload = Completer<TeacherHomework>();
        var fetchCount = 0;
        var deleteCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) {
            fetchCount += 1;
            return switch (fetchCount) {
              1 => Future.value(initial),
              2 => Future.error(teacherLocalFailure(ApiFailureKind.timeout)),
              3 => naturalReentry.future,
              _ => requiredReload.future,
            };
          },
          onDeleteQuestion: (_) {
            deleteCount += 1;
            if (deleteCount == 1) {
              return Future.error(
                const TeacherQuestionMutationOutcomeUnknownException(
                  TeacherQuestionMutationOperation.delete,
                ),
              );
            }
            return Future.value(
              teacherHomework(
                questions: [_copyQuestion(questions[1], position: 1)],
              ),
            );
          },
        );
        final harness = _BuilderHarness(repository: repository);
        final oldSubscription = await harness.listenAndEnterRoute();
        final oldOwnerGeneration = harness.ownerGeneration!;

        await harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: oldOwnerGeneration,
        );

        expect(
          oldSubscription.read().status,
          TeacherQuestionBuilderStatus.outcomeReview,
        );
        expect(harness.mutationActivity.isActive, isTrue);
        expect(harness.mutationActivity.outcomeReviewBlocking, isTrue);

        harness.controller.leaveRoute(oldOwnerGeneration);
        oldSubscription.close();
        await flushTeacherControllers();

        expect(harness.mutationActivity.isActive, isFalse);
        expect(harness.mutationActivity.authoritativeReloadRequired, isTrue);
        expect(
          harness.container.exists(
            teacherQuestionBuilderControllerProvider(harness.target),
          ),
          isFalse,
        );

        final newSubscription = await harness.listenAndEnterRoute();
        final newOwnerGeneration = harness.ownerGeneration!;
        expect(fetchCount, 3);
        expect(newSubscription.read().authoritativeReloadPending, isTrue);
        await harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: newOwnerGeneration,
        );
        expect(repository.deleteQuestionIds, [questions.first.id]);

        naturalReentry.complete(initial);
        await flushTeacherControllers();
        expect(fetchCount, 4);
        expect(newSubscription.read().authoritativeReloadPending, isTrue);

        requiredReload.complete(initial);
        await flushTeacherControllers();
        expect(newSubscription.read().authoritativeReloadPending, isFalse);
        expect(harness.mutationActivity.authoritativeReloadRequired, isFalse);

        await harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: newOwnerGeneration,
        );
        await flushTeacherControllers();
        expect(repository.deleteQuestionIds, [
          questions.first.id,
          questions.first.id,
        ]);
        expect(harness.currentDetail?.questions, hasLength(1));
      },
    );

    test(
      'takeover releases Builder outcome review and reloads authority',
      () async {
        final question = teacherHomeworkQuestions().first;
        final initial = teacherHomework(questions: [question]);
        final refreshed = teacherHomework(
          title: 'Takeover GET authority',
          questions: [question],
          totalPossiblePoints: 31,
        );
        final reloadPending = Completer<TeacherHomework>();
        var fetchCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) {
            fetchCount += 1;
            if (fetchCount == 1) return Future.value(initial);
            if (fetchCount == 2) {
              return Future.error(teacherLocalFailure(ApiFailureKind.timeout));
            }
            return reloadPending.future;
          },
          onDeleteQuestion: (_) async =>
              throw const TeacherQuestionMutationOutcomeUnknownException(
                TeacherQuestionMutationOperation.delete,
              ),
        );
        final harness = _BuilderHarness(repository: repository);
        final subscription = await harness.listenAndEnterRoute();
        final oldOwnerGeneration = harness.ownerGeneration!;
        await harness.controller.deleteQuestion(
          question.id,
          ownerGeneration: oldOwnerGeneration,
        );
        expect(subscription.read().hasBlockingOutcome, isTrue);
        expect(harness.mutationActivity.outcomeReviewBlocking, isTrue);

        final newOwnerGeneration = harness.controller.enterRoute();

        expect(harness.mutationActivity.isActive, isFalse);
        expect(subscription.read().pendingOperation, isNull);
        expect(subscription.read().authoritativeReloadPending, isTrue);
        harness.controller.leaveRoute(oldOwnerGeneration);
        expect(
          harness.controller.isCurrentRouteOwner(
            harness.sessionKey,
            ownerGeneration: newOwnerGeneration,
          ),
          isTrue,
        );
        await flushTeacherControllers();
        expect(fetchCount, 3);

        reloadPending.complete(refreshed);
        await flushTeacherControllers();

        expect(harness.currentDetail, same(refreshed));
        expect(subscription.read().authoritativeReloadPending, isFalse);
        expect(subscription.read().sharedMutationActive, isFalse);
      },
    );

    test(
      'route token survives null session bootstrap to the same Teacher',
      () async {
        final user = teacherUser('teacher-a');
        final auth = FakeTeacherAuthSessionController.authenticated(user);
        final questions = teacherHomeworkQuestions().take(2).toList();
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => teacherHomework(questions: questions),
        );
        final harness = _BuilderHarness(repository: repository, auth: auth);
        final subscription = await harness.listenAndEnterRoute();
        final ownerGeneration = harness.ownerGeneration!;

        auth.logOut();
        await flushTeacherControllers();
        expect(harness.controller.ownsRouteGeneration(ownerGeneration), isTrue);

        auth.onBootstrap = () => AuthSessionState.authenticated(user);
        await auth.bootstrap();
        await flushTeacherControllers();

        expect(
          harness.controller.isCurrentRouteOwner(
            harness.sessionKey,
            ownerGeneration: ownerGeneration,
          ),
          isTrue,
        );
        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: ownerGeneration,
        );
        expect(subscription.read().orderDirty, isTrue);
      },
    );

    test('mismatched returned Homework is never published', () async {
      final question = teacherHomeworkQuestions().first;
      var fetchCount = 0;
      final initial = teacherHomework(questions: [question]);
      final wrongTarget = teacherHomework(
        id: '50000000-0000-0000-0000-000000000099',
        questions: const [],
        totalPossiblePoints: 99,
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return initial;
        },
        onDeleteQuestion: (_) async => wrongTarget,
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();

      await harness.controller.deleteQuestion(
        question.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(fetchCount, 2);
      expect(harness.currentDetail, same(initial));
      expect(harness.currentDetail, isNot(same(wrongTarget)));
      expect(subscription.read().notice, contains('could not be confirmed'));
    });

    test('returned Homework for another Topic is never published', () async {
      final question = teacherHomeworkQuestions().first;
      var fetchCount = 0;
      final initial = teacherHomework(questions: [question]);
      final wrongTopic = teacherHomework(
        topicId: '10000000-0000-0000-0000-000000000099',
        questions: const [],
        totalPossiblePoints: 99,
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async {
          fetchCount += 1;
          return initial;
        },
        onDeleteQuestion: (_) async => wrongTopic,
      );
      final harness = _BuilderHarness(repository: repository);
      final subscription = await harness.listenAndEnterRoute();

      await harness.controller.deleteQuestion(
        question.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      await flushTeacherControllers();

      expect(fetchCount, 2);
      expect(harness.currentDetail, same(initial));
      expect(harness.currentDetail, isNot(same(wrongTopic)));
      expect(subscription.read().notice, contains('could not be confirmed'));
    });

    test(
      'route leave retains pending delete transport until stale completion',
      () async {
        final question = teacherHomeworkQuestions().first;
        final pending = Completer<TeacherHomework>();
        final initial = teacherHomework(questions: [question]);
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => initial,
          onDeleteQuestion: (_) => pending.future,
        );
        final harness = _BuilderHarness(repository: repository);
        final subscription = await harness.listenAndEnterRoute();

        final deletion = harness.controller.deleteQuestion(
          question.id,
          ownerGeneration: harness.ownerGeneration!,
        );
        expect(harness.mutationActivity.isActive, isTrue);
        harness.controller.leaveRoute(harness.ownerGeneration);
        expect(harness.mutationActivity.isActive, isTrue);
        expect(subscription.read().sharedMutationActive, isTrue);
        expect(subscription.read().pendingOperation, isNull);
        final stale = teacherHomework(
          questions: const [],
          totalPossiblePoints: 91,
        );
        pending.complete(stale);
        await deletion;
        await flushTeacherControllers();

        expect(repository.deleteQuestionIds, hasLength(1));
        expect(harness.mutationActivity.isActive, isFalse);
        expect(
          subscription.read().notice,
          isNot('Question deleted successfully.'),
        );
        expect(harness.currentDetail, same(initial));
      },
    );

    test(
      'pending delete survives listener disposal and gates re-entry on a fresh GET',
      () async {
        final questions = teacherHomeworkQuestions().take(2).toList();
        final initial = teacherHomework(questions: questions);
        final staleMutationResponse = teacherHomework(
          title: 'Stale delete response',
          questions: [_copyQuestion(questions[1], position: 1)],
          totalPossiblePoints: 81,
        );
        final naturalReentryResult = teacherHomework(
          title: 'Natural re-entry result',
          questions: questions,
          totalPossiblePoints: 82,
        );
        final requiredReloadResult = teacherHomework(
          title: 'Required post-transport authority',
          questions: questions,
          totalPossiblePoints: 83,
        );
        final confirmed = teacherHomework(
          questions: [_copyQuestion(questions[1], position: 1)],
        );
        final oldPending = Completer<TeacherHomework>();
        final naturalReentry = Completer<TeacherHomework>();
        final requiredReload = Completer<TeacherHomework>();
        var fetchCount = 0;
        var deleteCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) {
            fetchCount += 1;
            return switch (fetchCount) {
              1 => Future.value(initial),
              2 => naturalReentry.future,
              _ => requiredReload.future,
            };
          },
          onDeleteQuestion: (_) {
            deleteCount += 1;
            return deleteCount == 1
                ? oldPending.future
                : Future.value(confirmed);
          },
        );
        final harness = _BuilderHarness(repository: repository);
        final oldSubscription = await harness.listenAndEnterRoute();
        final oldOwnerGeneration = harness.ownerGeneration!;

        final deletion = harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: oldOwnerGeneration,
        );
        harness.controller.leaveRoute(oldOwnerGeneration);
        oldSubscription.close();
        await flushTeacherControllers();

        expect(
          harness.container.exists(
            teacherQuestionBuilderControllerProvider(harness.target),
          ),
          isFalse,
        );
        expect(harness.mutationActivity.isActive, isTrue);
        expect(harness.mutationActivity.authoritativeReloadRequired, isTrue);

        oldPending.complete(staleMutationResponse);
        await deletion;
        await flushTeacherControllers();

        expect(harness.mutationActivity.isActive, isFalse);
        expect(harness.mutationActivity.authoritativeReloadRequired, isTrue);
        expect(
          harness.container.exists(
            teacherQuestionMutationActivityProvider(harness.target),
          ),
          isTrue,
        );

        final newSubscription = await harness.listenAndEnterRoute();
        final newOwnerGeneration = harness.ownerGeneration!;
        expect(fetchCount, 2);
        expect(newSubscription.read().authoritativeReloadPending, isTrue);
        await harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: newOwnerGeneration,
        );
        expect(repository.deleteQuestionIds, [questions.first.id]);

        naturalReentry.complete(naturalReentryResult);
        await flushTeacherControllers();

        expect(fetchCount, 3);
        expect(newSubscription.read().authoritativeReloadPending, isTrue);
        expect(harness.mutationActivity.authoritativeReloadRequired, isTrue);
        await harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: newOwnerGeneration,
        );
        expect(repository.deleteQuestionIds, [questions.first.id]);

        requiredReload.complete(requiredReloadResult);
        await flushTeacherControllers();

        expect(harness.currentDetail, same(requiredReloadResult));
        expect(harness.currentDetail, isNot(same(staleMutationResponse)));
        expect(newSubscription.read().authoritativeReloadPending, isFalse);
        expect(harness.mutationActivity.authoritativeReloadRequired, isFalse);

        await harness.controller.deleteQuestion(
          questions.first.id,
          ownerGeneration: newOwnerGeneration,
        );
        await flushTeacherControllers();

        expect(repository.deleteQuestionIds, [
          questions.first.id,
          questions.first.id,
        ]);
        expect(harness.currentDetail, same(confirmed));
      },
    );

    test(
      'route leave retains pending reorder transport until stale completion',
      () async {
        final questions = teacherHomeworkQuestions().take(2).toList();
        final pending = Completer<TeacherHomework>();
        final initial = teacherHomework(questions: questions);
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) async => initial,
          onReorderQuestions: (_, _) => pending.future,
        );
        final harness = _BuilderHarness(repository: repository);
        final subscription = await harness.listenAndEnterRoute();
        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: harness.ownerGeneration!,
        );

        final reorder = harness.controller.saveOrder(
          ownerGeneration: harness.ownerGeneration!,
        );
        expect(harness.mutationActivity.isActive, isTrue);
        harness.controller.leaveRoute(harness.ownerGeneration);
        expect(harness.mutationActivity.isActive, isTrue);
        expect(subscription.read().sharedMutationActive, isTrue);
        expect(subscription.read().pendingOperation, isNull);
        final stale = teacherHomework(
          questions: _orderedQuestions([questions[1], questions[0]]),
          totalPossiblePoints: 93,
        );
        pending.complete(stale);
        await reorder;
        await flushTeacherControllers();

        expect(repository.reorderQuestionRequests, hasLength(1));
        expect(harness.mutationActivity.isActive, isFalse);
        expect(
          subscription.read().notice,
          isNot('Questions reordered successfully.'),
        );
        expect(harness.currentDetail, same(initial));
      },
    );

    test(
      'pending reorder survives listener disposal until post-transport authority reloads',
      () async {
        final questions = teacherHomeworkQuestions().take(2).toList();
        final initial = teacherHomework(questions: questions);
        final reorderedQuestions = _orderedQuestions([
          questions[1],
          questions[0],
        ]);
        final staleMutationResponse = teacherHomework(
          title: 'Stale reorder response',
          questions: reorderedQuestions,
          totalPossiblePoints: 91,
        );
        final naturalReentryResult = teacherHomework(
          title: 'Natural reorder re-entry result',
          questions: questions,
          totalPossiblePoints: 92,
        );
        final requiredReloadResult = teacherHomework(
          title: 'Required reorder authority',
          questions: questions,
          totalPossiblePoints: 93,
        );
        final confirmed = teacherHomework(questions: reorderedQuestions);
        final oldPending = Completer<TeacherHomework>();
        final naturalReentry = Completer<TeacherHomework>();
        final requiredReload = Completer<TeacherHomework>();
        var fetchCount = 0;
        var reorderCount = 0;
        final repository = FakeTeacherHomeworkRepository(
          onFetch: (_) {
            fetchCount += 1;
            return switch (fetchCount) {
              1 => Future.value(initial),
              2 => naturalReentry.future,
              _ => requiredReload.future,
            };
          },
          onReorderQuestions: (_, _) {
            reorderCount += 1;
            return reorderCount == 1
                ? oldPending.future
                : Future.value(confirmed);
          },
        );
        final harness = _BuilderHarness(repository: repository);
        final oldSubscription = await harness.listenAndEnterRoute();
        final oldOwnerGeneration = harness.ownerGeneration!;
        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: oldOwnerGeneration,
        );

        final reorder = harness.controller.saveOrder(
          ownerGeneration: oldOwnerGeneration,
        );
        harness.controller.leaveRoute(oldOwnerGeneration);
        oldSubscription.close();
        await flushTeacherControllers();

        expect(
          harness.container.exists(
            teacherQuestionBuilderControllerProvider(harness.target),
          ),
          isFalse,
        );
        expect(harness.mutationActivity.isActive, isTrue);
        oldPending.complete(staleMutationResponse);
        await reorder;
        await flushTeacherControllers();
        expect(harness.mutationActivity.isActive, isFalse);
        expect(harness.mutationActivity.authoritativeReloadRequired, isTrue);

        final newSubscription = await harness.listenAndEnterRoute();
        final newOwnerGeneration = harness.ownerGeneration!;
        expect(fetchCount, 2);
        naturalReentry.complete(naturalReentryResult);
        await flushTeacherControllers();

        expect(fetchCount, 3);
        expect(newSubscription.read().authoritativeReloadPending, isTrue);
        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: newOwnerGeneration,
        );
        expect(newSubscription.read().draftOrderIds, _ids(questions));
        expect(repository.reorderQuestionRequests, hasLength(1));

        requiredReload.complete(requiredReloadResult);
        await flushTeacherControllers();

        expect(harness.currentDetail, same(requiredReloadResult));
        expect(harness.currentDetail, isNot(same(staleMutationResponse)));
        expect(newSubscription.read().authoritativeReloadPending, isFalse);
        expect(harness.mutationActivity.authoritativeReloadRequired, isFalse);
        harness.controller.moveQuestionDown(
          questions.first.id,
          ownerGeneration: newOwnerGeneration,
        );
        await harness.controller.saveOrder(ownerGeneration: newOwnerGeneration);
        await flushTeacherControllers();

        expect(repository.reorderQuestionRequests, hasLength(2));
        expect(harness.currentDetail, same(confirmed));
      },
    );

    test('completion from a replaced session is ignored', () async {
      final question = teacherHomeworkQuestions().first;
      final pending = Completer<TeacherHomework>();
      final initial = teacherHomework(questions: [question]);
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final repository = FakeTeacherHomeworkRepository(
        onFetch: (_) async => initial,
        onDeleteQuestion: (_) => pending.future,
      );
      final harness = _BuilderHarness(repository: repository, auth: auth);
      final subscription = await harness.listenAndEnterRoute();

      final deletion = harness.controller.deleteQuestion(
        question.id,
        ownerGeneration: harness.ownerGeneration!,
      );
      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      final stale = teacherHomework(
        questions: const [],
        totalPossiblePoints: 92,
      );
      pending.complete(stale);
      await deletion;
      await flushTeacherControllers();

      expect(repository.deleteQuestionIds, hasLength(1));
      expect(
        subscription.read().notice,
        isNot('Question deleted successfully.'),
      );
      expect(harness.currentDetail, isNot(same(stale)));
      expect(harness.currentDetail?.totalPossiblePoints, isNot(92));
    });
  });
}

class _BuilderHarness {
  _BuilderHarness({
    TeacherHomework? initialHomework,
    FakeTeacherHomeworkRepository? repository,
    FakeTeacherAuthSessionController? auth,
  }) : auth =
           auth ??
           FakeTeacherAuthSessionController.authenticated(
             teacherUser('teacher-a'),
           ),
       repository =
           repository ??
           FakeTeacherHomeworkRepository(
             onFetch: (_) async => initialHomework ?? teacherHomework(),
           ) {
    target = TeacherHomeworkRouteTarget(
      topicId: _topicId,
      homeworkId: _homeworkId,
    );
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherHomeworkRepositoryProvider.overrideWithValue(this.repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherHomeworkRepository repository;
  late final TeacherHomeworkRouteTarget target;
  late final ProviderContainer container;
  int? ownerGeneration;

  Future<ProviderSubscription<TeacherQuestionBuilderState>>
  listenAndEnterRoute() async {
    final subscription = container.listen(
      teacherQuestionBuilderControllerProvider(target),
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
    ownerGeneration = controller.enterRoute();
    await flushTeacherControllers();
    return subscription;
  }

  TeacherQuestionBuilderController get controller =>
      container.read(teacherQuestionBuilderControllerProvider(target).notifier);

  TeacherQuestionMutationActivityState get mutationActivity =>
      container.read(teacherQuestionMutationActivityProvider(target));

  TeacherHomework? get currentDetail =>
      container.read(teacherHomeworkDetailControllerProvider(target)).homework;

  void acceptAuthoritative(TeacherHomework homework) {
    container
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .acceptAuthoritativeHomework(homework, sessionKey);
  }

  TeacherSessionKey get sessionKey => TeacherSessionSnapshot.fromSession(
    container.read(authSessionControllerProvider),
    AppDeviceSurface.desktop,
  ).eligibleKey!;
}

List<String> _ids(List<TeacherQuestion> questions) =>
    questions.map((question) => question.id.toLowerCase()).toList();

List<TeacherQuestion> _orderedQuestions(List<TeacherQuestion> questions) {
  return [
    for (var index = 0; index < questions.length; index += 1)
      _copyQuestion(questions[index], position: index + 1),
  ];
}

TeacherQuestion _copyQuestion(TeacherQuestion question, {int? position}) {
  return TeacherQuestion(
    id: question.id,
    type: question.type,
    prompt: question.prompt,
    instructions: question.instructions,
    points: question.points,
    position: position ?? question.position,
    checkingMode: question.checkingMode,
    configuration: question.configuration,
  );
}
