import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_action_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_action_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_bulk_action_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_bulk_action_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_list_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_result_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_mutation.dart';

import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

final _target = TeacherTopicResultTarget(
  topicId: teacherResultTopicId,
  studentId: teacherResultStudentId,
);

void main() {
  group('Teacher Topic result action controller', () {
    test(
      'a Student release shows the returned result and reloads the list',
      () async {
        final harness = _Harness(
          onRelease: (_, _) async => _detail(
            teacherTopicResultJson(
              visibility: teacherResultVisibilityJson(
                studentVisible: true,
                studentReleasedAt: '2026-10-05T09:00:00Z',
                canReleaseToStudent: false,
              ),
            ),
          ),
        );
        await harness.ready();
        final listFetches = harness.repository.listRequests.length;

        await harness.actions().release(TeacherTopicResultAudience.student);

        expect(harness.repository.actions, ['release:student']);
        expect(
          harness.detail().detail?.result.visibility.studentVisible,
          isTrue,
        );
        expect(
          harness.actionState().feedback,
          'Result released to the Student.',
        );
        expect(
          harness.actionState().status,
          TeacherTopicResultActionStatus.idle,
        );
        await flushTeacherControllers();
        expect(harness.repository.listRequests.length, listFetches + 1);
      },
    );

    test('each action reports its own success', () async {
      for (final (run, initial, answer, feedback)
          in <
            (
              Future<void> Function(TeacherTopicResultActionController),
              Map<String, Object?>,
              Map<String, Object?>,
              String,
            )
          >[
            (
              (actions) => actions.release(TeacherTopicResultAudience.parent),
              _parentReleasable(),
              teacherTopicResultJson(
                visibility: teacherResultVisibilityJson(
                  studentMode: 'automatic',
                  studentVisible: true,
                  canReleaseToStudent: false,
                  parentMode: 'manual_teacher',
                  parentVisible: true,
                  parentReleasedAt: '2026-10-05T09:00:00Z',
                ),
              ),
              'Result released to Parents.',
            ),
            (
              (actions) => actions.close(),
              teacherTopicResultJson(),
              closedCalculatedTeacherTopicResultJson(),
              'Result closed.',
            ),
            (
              (actions) => actions.saveComment('Revise question 4.'),
              teacherTopicResultJson(),
              teacherTopicResultJson(teacherComment: 'Revise question 4.'),
              'Comment saved.',
            ),
            (
              (actions) => actions.saveComment('   '),
              teacherTopicResultJson(teacherComment: 'Old comment.'),
              teacherTopicResultJson(),
              'Comment removed.',
            ),
          ]) {
        final returned = answer['result_status'] == 'closed'
            ? _detail(answer, closureReason: 'teacher')
            : _detail(answer);
        final harness = _Harness(
          initial: initial,
          onRelease: (_, _) async => returned,
          onClose: (_) async => returned,
          onUpdateComment: (_, _) async => returned,
        );
        await harness.ready();

        await run(harness.actions());

        expect(harness.actionState().feedback, feedback);
        expect(harness.repository.actions, hasLength(1));
      }
    });

    test('an action the result does not offer is never sent', () async {
      final harness = _Harness(
        initial: waitingTeacherTopicResultJson(),
        onRelease: (_, _) async => throw StateError('not sent'),
      );
      await harness.ready();

      await harness.actions().release(TeacherTopicResultAudience.student);
      await harness.actions().release(TeacherTopicResultAudience.parent);
      await harness.actions().close();

      expect(harness.repository.actions, isEmpty);
    });

    test('a closed result keeps its comment', () async {
      final harness = _Harness(
        initial: closedCalculatedTeacherTopicResultJson(),
        closureReason: 'teacher',
      );
      await harness.ready();

      await harness.actions().saveComment('Late note.');

      expect(harness.repository.actions, isEmpty);
    });

    test(
      'comment and close are desktop-only; release works on mobile',
      () async {
        final harness = _Harness(
          surface: AppDeviceSurface.mobile,
          onRelease: (_, _) async => _detail(
            teacherTopicResultJson(
              visibility: teacherResultVisibilityJson(
                studentVisible: true,
                studentReleasedAt: '2026-10-05T09:00:00Z',
                canReleaseToStudent: false,
              ),
            ),
          ),
        );
        await harness.ready();

        await harness.actions().close();
        await harness.actions().saveComment('Note.');
        await harness.actions().release(TeacherTopicResultAudience.student);

        expect(harness.repository.actions, ['release:student']);
      },
    );

    test('a second action waits for the first', () async {
      final pending = Completer<TeacherTopicResultDetail>();
      final harness = _Harness(onClose: (_) => pending.future);
      await harness.ready();

      final first = harness.actions().close();
      expect(
        harness.actionState().status,
        TeacherTopicResultActionStatus.submitting,
      );
      await harness.actions().release(TeacherTopicResultAudience.student);
      pending.complete(
        _detail(
          closedCalculatedTeacherTopicResultJson(),
          closureReason: 'teacher',
        ),
      );
      await first;

      expect(harness.repository.actions, ['close']);
    });

    test('a stale or refreshing result offers no action', () async {
      final refresh = Completer<TeacherTopicResultDetail>();
      var reads = 0;
      final harness = _Harness(
        onFetchResult: () {
          reads += 1;
          return reads == 1
              ? Future.value(_detail(teacherTopicResultJson()))
              : refresh.future;
        },
      );
      await harness.ready();
      unawaited(harness.detailController().refresh());

      await harness.actions().close();
      expect(harness.repository.actions, isEmpty);

      refresh.completeError(
        teacherServerFailure(ApiErrorCodes.serverError, statusCode: 500),
      );
      await flushTeacherControllers();
      expect(harness.detail().isStale, isTrue);
      await harness.actions().close();
      expect(harness.repository.actions, isEmpty);
    });

    test('conflicts explain themselves and reload the result', () async {
      for (final (code, message) in [
        (
          ApiErrorCodes.manualReleaseNotAllowed,
          "The Institution's release mode does not allow a Teacher release.",
        ),
        (
          ApiErrorCodes.resultNotReady,
          'This result is not ready to be released yet.',
        ),
      ]) {
        final harness = _Harness(
          onRelease: (_, _) async =>
              throw teacherServerFailure(code, statusCode: 409),
        );
        await harness.ready();
        final reads = harness.repository.detailRequests.length;

        await harness.actions().release(TeacherTopicResultAudience.student);
        await flushTeacherControllers();

        expect(harness.actionState().notice, message, reason: code);
        expect(harness.actionState().feedback, isNull);
        expect(harness.repository.detailRequests.length, reads + 1);
      }

      for (final (run, initial, code, message)
          in <
            (
              Future<void> Function(TeacherTopicResultActionController),
              Map<String, Object?>,
              String,
              String,
            )
          >[
            (
              (actions) => actions.release(TeacherTopicResultAudience.parent),
              _parentReleasable(),
              ApiErrorCodes.studentResultNotReleased,
              'Parents can see the result only after the Student can.',
            ),
            (
              (actions) => actions.close(),
              teacherTopicResultJson(),
              ApiErrorCodes.resultNotReadyForClosure,
              'This result cannot be closed yet.',
            ),
            (
              (actions) => actions.saveComment('Note.'),
              teacherTopicResultJson(),
              ApiErrorCodes.resultClosed,
              'This result is closed, so its comment cannot change.',
            ),
          ]) {
        Future<TeacherTopicResultDetail> conflict() async =>
            throw teacherServerFailure(code, statusCode: 409);
        final harness = _Harness(
          initial: initial,
          onRelease: (_, _) => conflict(),
          onClose: (_) => conflict(),
          onUpdateComment: (_, _) => conflict(),
        );
        await harness.ready();
        final reads = harness.repository.detailRequests.length;

        await run(harness.actions());
        await flushTeacherControllers();

        expect(harness.actionState().notice, message, reason: code);
        expect(harness.repository.detailRequests.length, reads + 1);
      }
    });

    test('a missing result, a rejected comment and rate limits', () async {
      for (final (status, code, message, reloads) in [
        (
          404,
          ApiErrorCodes.resourceNotFound,
          'This result is no longer available.',
          true,
        ),
        (
          422,
          ApiErrorCodes.validationFailed,
          'The comment could not be saved. Check it and try again.',
          false,
        ),
        (
          429,
          ApiErrorCodes.rateLimited,
          'Too many requests. Wait a moment and try again.',
          false,
        ),
      ]) {
        final harness = _Harness(
          onUpdateComment: (_, _) async =>
              throw teacherServerFailure(code, statusCode: status),
        );
        await harness.ready();
        final reads = harness.repository.detailRequests.length;

        await harness.actions().saveComment('Note.');
        await flushTeacherControllers();

        expect(harness.actionState().notice, message, reason: code);
        expect(
          harness.repository.detailRequests.length,
          reloads ? reads + 1 : reads,
          reason: code,
        );
      }
    });

    test('an unknown outcome reloads the result and the list', () async {
      final harness = _Harness(
        onClose: (_) async =>
            throw const TeacherTopicResultMutationOutcomeUnknownException(),
      );
      await harness.ready();
      final reads = harness.repository.detailRequests.length;
      final lists = harness.repository.listRequests.length;

      await harness.actions().close();
      await flushTeacherControllers();

      expect(
        harness.actionState().notice,
        'The result could not be confirmed and was reloaded. Check it before '
        'trying again.',
      );
      expect(harness.repository.detailRequests.length, reads + 1);
      expect(harness.repository.listRequests.length, lists + 1);
    });

    test('an answer for an earlier session is never published', () async {
      final pending = Completer<TeacherTopicResultDetail>();
      final harness = _Harness(onClose: (_) => pending.future);
      await harness.ready();

      final action = harness.actions().close();
      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(
        _detail(
          closedCalculatedTeacherTopicResultJson(),
          closureReason: 'teacher',
        ),
      );
      await action;
      await flushTeacherControllers();

      expect(harness.actionState().feedback, isNull);
      expect(
        harness.detail().detail?.result.status,
        isNot(TeacherTopicResultStatus.closed),
      );
    });

    test('session failures clear the state and re-run bootstrap', () async {
      final harness = _Harness(
        onClose: (_) async => throw teacherServerFailure(
          ApiErrorCodes.passwordChangeRequired,
          statusCode: 403,
        ),
      );
      await harness.ready();

      await harness.actions().close();

      expect(harness.actionState().notice, isNull);
      expect(harness.actionState().status, TeacherTopicResultActionStatus.idle);
      expect(harness.auth.bootstrapCalls, 1);
    });

    test(
      'an action finished after its screen closed still reloads the list',
      () async {
        final pending = Completer<TeacherTopicResultDetail>();
        final harness = _Harness(onClose: (_) => pending.future);
        await harness.ready();

        final action = harness.actions().close();
        harness.detailScreenListeners.close();
        harness.actionListener.close();
        await flushTeacherControllers();
        final lists = harness.repository.listRequests.length;
        pending.complete(
          _detail(
            closedCalculatedTeacherTopicResultJson(),
            closureReason: 'teacher',
          ),
        );
        await action;
        await flushTeacherControllers();

        expect(harness.repository.listRequests.length, lists + 1);
        // The closed detail screen's result is not read again.
        expect(harness.repository.detailRequests, hasLength(1));
      },
    );

    test('the returned result replaces a read already in flight', () async {
      final pendingClose = Completer<TeacherTopicResultDetail>();
      final olderRead = Completer<TeacherTopicResultDetail>();
      var reads = 0;
      final harness = _Harness(
        onFetchResult: () {
          reads += 1;
          return reads == 1
              ? Future.value(_detail(teacherTopicResultJson()))
              : olderRead.future;
        },
        onClose: (_) => pendingClose.future,
      );
      await harness.ready();

      final action = harness.actions().close();
      unawaited(harness.detailController().refresh());
      pendingClose.complete(
        _detail(
          closedCalculatedTeacherTopicResultJson(),
          closureReason: 'teacher',
        ),
      );
      await action;
      olderRead.complete(_detail(teacherTopicResultJson()));
      await flushTeacherControllers();

      expect(
        harness.detail().detail?.result.status,
        TeacherTopicResultStatus.closed,
      );
      expect(harness.detail().status, TeacherTopicResultDetailStatus.data);
    });

    test('feedback is consumed once', () async {
      final harness = _Harness(
        onClose: (_) async => _detail(
          closedCalculatedTeacherTopicResultJson(),
          closureReason: 'teacher',
        ),
      );
      await harness.ready();
      await harness.actions().close();

      harness.actions().consumeFeedback();

      expect(harness.actionState().feedback, isNull);
    });
  });

  group('Teacher Topic result bulk action controller', () {
    test('a bulk release reports its counts and reloads the list', () async {
      final harness = _Harness(
        onReleaseAll: (_) async => const TeacherTopicResultBulkOutcome(
          processed: 21,
          alreadyDone: 3,
          notReady: 6,
        ),
      );
      await harness.ready();
      final lists = harness.repository.listRequests.length;

      await harness.bulk().releaseAll(TeacherTopicResultAudience.student);
      await flushTeacherControllers();

      expect(harness.repository.actions, ['releaseAll:student']);
      expect(
        harness.bulkState().report,
        'Released to 21 Students. Skipped: 3 already released, 6 not ready '
        'yet.',
      );
      expect(harness.repository.listRequests.length, lists + 1);
    });

    test('reports name their audience and use singular forms', () async {
      for (final (run, outcome, report)
          in <
            (
              Future<void> Function(TeacherTopicResultBulkActionController),
              TeacherTopicResultBulkOutcome,
              String,
            )
          >[
            (
              (bulk) => bulk.releaseAll(TeacherTopicResultAudience.parent),
              const TeacherTopicResultBulkOutcome(
                processed: 1,
                alreadyDone: 0,
                notReady: 1,
              ),
              'Released to the Parents of 1 Student. Skipped: 1 not ready yet.',
            ),
            (
              (bulk) => bulk.closeAll(),
              const TeacherTopicResultBulkOutcome(
                processed: 5,
                alreadyDone: 1,
                notReady: 0,
              ),
              'Closed 5 results. Skipped: 1 already closed.',
            ),
            (
              (bulk) => bulk.closeAll(),
              const TeacherTopicResultBulkOutcome(
                processed: 1,
                alreadyDone: 0,
                notReady: 0,
              ),
              'Closed 1 result.',
            ),
          ]) {
        final harness = _Harness(
          initial: _parentReleasable(),
          onReleaseAll: (_) async => outcome,
          onCloseAll: () async => outcome,
        );
        await harness.ready();

        await run(harness.bulk());

        expect(harness.bulkState().report, report);
      }
    });

    test(
      'a release the Institution mode does not allow is never sent',
      () async {
        final harness = _Harness(
          initial: teacherTopicResultJson(
            visibility: teacherResultVisibilityJson(
              studentMode: 'automatic',
              canReleaseToStudent: false,
            ),
          ),
        );
        await harness.ready();

        await harness.bulk().releaseAll(TeacherTopicResultAudience.student);
        await harness.bulk().releaseAll(TeacherTopicResultAudience.parent);

        expect(harness.repository.actions, isEmpty);
      },
    );

    test('bulk close is desktop-only', () async {
      final harness = _Harness(surface: AppDeviceSurface.mobile);
      await harness.ready();

      await harness.bulk().closeAll();

      expect(harness.repository.actions, isEmpty);
    });

    test('a forbidden mode and an unknown outcome reload the list', () async {
      for (final (failure, notice) in <(Object, String)>[
        (
          teacherServerFailure(
            ApiErrorCodes.manualReleaseNotAllowed,
            statusCode: 409,
          ),
          "The Institution's release mode does not allow a Teacher release.",
        ),
        (
          const TeacherTopicResultMutationOutcomeUnknownException(),
          'The results could not be confirmed and were reloaded. Check them '
              'before trying again.',
        ),
        (
          teacherServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
          'These Topic results are no longer available.',
        ),
      ]) {
        final harness = _Harness(onReleaseAll: (_) async => throw failure);
        await harness.ready();
        final lists = harness.repository.listRequests.length;

        await harness.bulk().releaseAll(TeacherTopicResultAudience.student);
        await flushTeacherControllers();

        expect(harness.bulkState().notice, notice);
        expect(harness.bulkState().report, isNull);
        expect(harness.repository.listRequests.length, lists + 1);
      }
    });

    test('a rate limit is explained without a reload', () async {
      final harness = _Harness(
        onCloseAll: () async => throw teacherServerFailure(
          ApiErrorCodes.rateLimited,
          statusCode: 429,
        ),
      );
      await harness.ready();
      final lists = harness.repository.listRequests.length;

      await harness.bulk().closeAll();
      await flushTeacherControllers();

      expect(
        harness.bulkState().notice,
        'Too many requests. Wait a moment and try again.',
      );
      expect(harness.repository.listRequests.length, lists);
    });

    test(
      'session failures clear the bulk state and re-run bootstrap',
      () async {
        final harness = _Harness(
          onCloseAll: () async => throw teacherServerFailure(
            ApiErrorCodes.userInactive,
            statusCode: 403,
          ),
        );
        await harness.ready();

        await harness.bulk().closeAll();

        expect(harness.bulkState().notice, isNull);
        expect(harness.bulkState().isBusy, isFalse);
        expect(harness.auth.bootstrapCalls, 1);
      },
    );

    test('a bulk answer for an earlier session is never published', () async {
      final pending = Completer<TeacherTopicResultBulkOutcome>();
      final harness = _Harness(onCloseAll: () => pending.future);
      await harness.ready();

      final action = harness.bulk().closeAll();
      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(
        const TeacherTopicResultBulkOutcome(
          processed: 1,
          alreadyDone: 0,
          notReady: 0,
        ),
      );
      await action;
      await flushTeacherControllers();

      expect(harness.bulkState().report, isNull);
    });

    test(
      'a bulk action finished after leaving the list still reloads it',
      () async {
        final pending = Completer<TeacherTopicResultBulkOutcome>();
        final harness = _Harness(onCloseAll: () => pending.future);
        await harness.ready();

        final action = harness.bulk().closeAll();
        // The Topic detail entry card keeps the shared list controller alive.
        harness.bulkListener.close();
        await flushTeacherControllers();
        final lists = harness.repository.listRequests.length;
        pending.complete(
          const TeacherTopicResultBulkOutcome(
            processed: 1,
            alreadyDone: 0,
            notReady: 0,
          ),
        );
        await action;
        await flushTeacherControllers();

        expect(harness.repository.listRequests.length, lists + 1);
      },
    );

    test('a bulk action needs a current list and waits for another', () async {
      final pending = Completer<TeacherTopicResultBulkOutcome>();
      final reload = Completer<TeacherTopicResultList>();
      final harness = _Harness(
        onCloseAll: () => pending.future,
        onFetchResults: (fetch, query) => fetch == 1
            ? Future.value(teacherTopicResultList(query: query))
            : reload.future,
      );
      await harness.ready();

      final first = harness.bulk().closeAll();
      await harness.bulk().releaseAll(TeacherTopicResultAudience.student);
      pending.complete(
        const TeacherTopicResultBulkOutcome(
          processed: 1,
          alreadyDone: 0,
          notReady: 0,
        ),
      );
      await first;
      expect(harness.repository.actions, ['closeAll']);

      // The reload after the action is in flight: no action on stale rows.
      expect(harness.list().status, TeacherTopicResultListStatus.refreshing);
      await harness.bulk().closeAll();
      expect(harness.repository.actions, ['closeAll']);
    });
  });
}

Map<String, Object?> _parentReleasable() {
  return teacherTopicResultJson(
    visibility: teacherResultVisibilityJson(
      studentMode: 'automatic',
      studentVisible: true,
      canReleaseToStudent: false,
      parentMode: 'manual_teacher',
      canReleaseToParent: true,
    ),
  );
}

TeacherTopicResultDetail _detail(
  Map<String, Object?> item, {
  String? closureReason,
}) {
  return teacherTopicResultDetail(
    teacherTopicResultDetailJson(item: item, closureReason: closureReason),
  );
}

class _Harness {
  _Harness({
    Map<String, Object?>? initial,
    String? closureReason,
    Future<TeacherTopicResultDetail> Function()? onFetchResult,
    Future<TeacherTopicResultList> Function(
      int fetch,
      TeacherTopicResultListQuery query,
    )?
    onFetchResults,
    Future<TeacherTopicResultDetail> Function(
      String studentId,
      TeacherTopicResultAudience audience,
    )?
    onRelease,
    Future<TeacherTopicResultDetail> Function(String studentId)? onClose,
    Future<TeacherTopicResultDetail> Function(String studentId, String text)?
    onUpdateComment,
    Future<TeacherTopicResultBulkOutcome> Function(
      TeacherTopicResultAudience audience,
    )?
    onReleaseAll,
    Future<TeacherTopicResultBulkOutcome> Function()? onCloseAll,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ) {
    final item = initial ?? teacherTopicResultJson();
    var listFetches = 0;
    repository = FakeTeacherTopicResultRepository(
      onFetchResults: (_, query) {
        listFetches += 1;
        return onFetchResults?.call(listFetches, query) ??
            Future.value(teacherTopicResultList(query: query, items: [item]));
      },
      onFetchResult: (_, _) =>
          onFetchResult?.call() ??
          Future.value(_detail(item, closureReason: closureReason)),
      onRelease: onRelease,
      onClose: onClose,
      onUpdateComment: onUpdateComment,
      onReleaseAll: onReleaseAll,
      onCloseAll: onCloseAll,
    );
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherTopicResultRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  late final FakeTeacherTopicResultRepository repository;
  late final ProviderContainer container;

  /// The listeners of the list, the detail screen and the bulk bar; closing
  /// one models leaving that screen.
  late final ProviderSubscription<Object?> listListener;
  late final ProviderSubscription<Object?> detailScreenListeners;
  late final ProviderSubscription<Object?> actionListener;
  late final ProviderSubscription<Object?> bulkListener;

  Future<void> ready() async {
    listListener = container.listen(
      teacherTopicResultListControllerProvider(teacherResultTopicId),
      (_, _) {},
    );
    detailScreenListeners = container.listen(
      teacherTopicResultDetailControllerProvider(_target),
      (_, _) {},
    );
    actionListener = container.listen(
      teacherTopicResultActionControllerProvider(_target),
      (_, _) {},
    );
    bulkListener = container.listen(
      teacherTopicResultBulkActionControllerProvider(teacherResultTopicId),
      (_, _) {},
    );
    for (final subscription in [
      listListener,
      detailScreenListeners,
      actionListener,
      bulkListener,
    ]) {
      addTearDown(subscription.close);
    }
    await flushTeacherControllers();
  }

  TeacherTopicResultListState list() => container.read(
    teacherTopicResultListControllerProvider(teacherResultTopicId),
  );

  TeacherTopicResultDetailState detail() =>
      container.read(teacherTopicResultDetailControllerProvider(_target));

  TeacherTopicResultDetailController detailController() => container.read(
    teacherTopicResultDetailControllerProvider(_target).notifier,
  );

  TeacherTopicResultActionState actionState() =>
      container.read(teacherTopicResultActionControllerProvider(_target));

  TeacherTopicResultActionController actions() => container.read(
    teacherTopicResultActionControllerProvider(_target).notifier,
  );

  TeacherTopicResultBulkActionState bulkState() => container.read(
    teacherTopicResultBulkActionControllerProvider(teacherResultTopicId),
  );

  TeacherTopicResultBulkActionController bulk() => container.read(
    teacherTopicResultBulkActionControllerProvider(
      teacherResultTopicId,
    ).notifier,
  );
}
