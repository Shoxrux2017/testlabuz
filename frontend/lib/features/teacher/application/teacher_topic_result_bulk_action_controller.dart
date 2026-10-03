import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_topic_result_repository_impl.dart';
import '../domain/teacher_topic_result.dart';
import '../domain/teacher_topic_result_mutation.dart';
import '../domain/teacher_topic_result_repository.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_result_action_messages.dart';
import 'teacher_topic_result_bulk_action_state.dart';
import 'teacher_topic_result_list_controller.dart';
import 'teacher_topic_result_list_state.dart';

/// Keyed by the lowercase Topic id, like the results list it acts beside.
final teacherTopicResultBulkActionControllerProvider = NotifierProvider
    .autoDispose
    .family<
      TeacherTopicResultBulkActionController,
      TeacherTopicResultBulkActionState,
      String
    >(TeacherTopicResultBulkActionController.new);

/// Release all ready results (desktop and mobile) and close all closable
/// results (desktop only, `S10-FE-D1`) of a Topic's whole cohort.
class TeacherTopicResultBulkActionController
    extends Notifier<TeacherTopicResultBulkActionState> {
  TeacherTopicResultBulkActionController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  var _generation = 0;

  @override
  TeacherTopicResultBulkActionState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      _clearSession();
      return const TeacherTopicResultBulkActionState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherTopicResultBulkActionState();
  }

  Future<void> releaseAll(TeacherTopicResultAudience audience) {
    final toStudents = audience == TeacherTopicResultAudience.student;
    return _run(
      toStudents
          ? TeacherTopicResultBulkAction.releaseToStudents
          : TeacherTopicResultBulkAction.releaseToParents,
      desktopOnly: false,
      // Every row carries the Institution's current release modes.
      allowed: (row) => toStudents
          ? row.visibility.studentReleaseMode ==
                TeacherStudentResultReleaseMode.manualTeacher
          : row.visibility.parentReleaseMode ==
                TeacherParentResultReleaseMode.manualTeacher,
      send: (repository) => repository.releaseAll(topicId, audience),
    );
  }

  Future<void> closeAll() {
    return _run(
      TeacherTopicResultBulkAction.close,
      desktopOnly: true,
      allowed: (_) => true,
      send: (repository) => repository.closeAll(topicId),
    );
  }

  Future<void> _run(
    TeacherTopicResultBulkAction action, {
    required bool desktopOnly,
    required bool Function(TeacherTopicResult row) allowed,
    required Future<TeacherTopicResultBulkOutcome> Function(
      TeacherTopicResultRepository repository,
    )
    send,
  }) async {
    final owner = _activeSessionKey;
    final list = ref.read(teacherTopicResultListControllerProvider(topicId));
    final rows = list.result?.items ?? const <TeacherTopicResult>[];
    // Only confirmed current rows may decide an action.
    if (owner == null ||
        state.isBusy ||
        rows.isEmpty ||
        list.status != TeacherTopicResultListStatus.data ||
        (desktopOnly && owner.surface != AppDeviceSurface.desktop) ||
        !allowed(rows.first) ||
        !_matchesSession(owner)) {
      return;
    }

    final generation = ++_generation;
    state = const TeacherTopicResultBulkActionState(
      status: TeacherTopicResultBulkActionStatus.submitting,
    );
    // Leaving the list must not drop the answer: the Topic detail entry card
    // still shows the list's counts.
    final keepAlive = ref.keepAlive();
    try {
      final outcome = await send(
        ref.read(teacherTopicResultRepositoryProvider),
      );
      if (!_canPublish(generation, owner)) {
        return;
      }
      state = TeacherTopicResultBulkActionState(
        report: teacherTopicResultBulkReport(action, outcome),
      );
      _refreshList(owner);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, owner)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure.serverCode)) {
        return;
      }
      state = TeacherTopicResultBulkActionState(
        notice: teacherTopicResultActionFailureMessage(
          exception.failure,
          bulk: true,
        ),
      );
      if (teacherTopicResultActionFailureReloads(exception.failure)) {
        _refreshList(owner);
      }
    } catch (_) {
      // An unknown outcome, or any unexpected failure, is reconciled by a read.
      if (_canPublish(generation, owner)) {
        state = const TeacherTopicResultBulkActionState(
          notice: teacherTopicResultBulkActionUnknownMessage,
        );
        _refreshList(owner);
      }
    } finally {
      keepAlive.close();
    }
  }

  void _refreshList(TeacherSessionKey owner) {
    final list = teacherTopicResultListControllerProvider(topicId);
    if (ref.exists(list)) {
      ref.read(list.notifier).refreshAfterAction(owner);
    }
  }

  bool _canPublish(int generation, TeacherSessionKey owner) {
    return ref.mounted && generation == _generation && _matchesSession(owner);
  }

  bool _matchesSession(TeacherSessionKey owner) {
    return ref.mounted &&
        _activeSessionKey == owner &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            owner;
  }

  bool _clearForSessionFailure(String? code) {
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearSession();
    state = const TeacherTopicResultBulkActionState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _generation += 1;
  }
}
