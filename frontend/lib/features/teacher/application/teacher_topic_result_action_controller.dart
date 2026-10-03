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
import 'teacher_topic_result_action_state.dart';
import 'teacher_topic_result_detail_controller.dart';
import 'teacher_topic_result_detail_state.dart';
import 'teacher_topic_result_list_controller.dart';
import 'teacher_topic_result_target.dart';

final teacherTopicResultActionControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherTopicResultActionController,
      TeacherTopicResultActionState,
      TeacherTopicResultTarget
    >(TeacherTopicResultActionController.new);

/// Release, close and comment for one Student's Topic result. Release works on
/// desktop and mobile; comment and close are desktop-only (`S10-FE-D1`). The
/// shown result's server flags decide which action may be sent.
class TeacherTopicResultActionController
    extends Notifier<TeacherTopicResultActionState> {
  TeacherTopicResultActionController(this.target);

  final TeacherTopicResultTarget target;
  TeacherSessionKey? _activeSessionKey;
  var _generation = 0;

  @override
  TeacherTopicResultActionState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      _clearSession();
      return const TeacherTopicResultActionState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherTopicResultActionState();
  }

  Future<void> release(TeacherTopicResultAudience audience) {
    final toStudent = audience == TeacherTopicResultAudience.student;
    return _run(
      desktopOnly: false,
      allowed: (result) => toStudent
          ? result.visibility.canReleaseToStudent
          : result.visibility.canReleaseToParent,
      send: (repository) =>
          repository.release(target.topicId, target.studentId, audience),
      success: toStudent
          ? 'Result released to the Student.'
          : 'Result released to Parents.',
    );
  }

  Future<void> close() {
    return _run(
      desktopOnly: true,
      allowed: (result) => result.canClose,
      send: (repository) => repository.close(target.topicId, target.studentId),
      success: 'Result closed.',
    );
  }

  /// Saves [text] trimmed; an empty text removes the comment.
  Future<void> saveComment(String text) {
    final trimmed = text.trim();
    return _run(
      desktopOnly: true,
      allowed: (result) =>
          result.status != TeacherTopicResultStatus.closed &&
          trimmed != (result.teacherComment ?? '') &&
          trimmed.runes.length <= teacherTopicResultCommentMaxLength,
      send: (repository) =>
          repository.updateComment(target.topicId, target.studentId, text),
      success: trimmed.isEmpty ? 'Comment removed.' : 'Comment saved.',
    );
  }

  void consumeFeedback() {
    if (state.feedback != null) {
      state = state.withoutFeedback();
    }
  }

  Future<void> _run({
    required bool desktopOnly,
    required bool Function(TeacherTopicResult result) allowed,
    required Future<TeacherTopicResultDetail> Function(
      TeacherTopicResultRepository repository,
    )
    send,
    required String success,
  }) async {
    final owner = _activeSessionKey;
    final shown = ref.read(teacherTopicResultDetailControllerProvider(target));
    final result = shown.detail?.result;
    // Only a confirmed current result may decide an action.
    if (owner == null ||
        state.isBusy ||
        result == null ||
        shown.status != TeacherTopicResultDetailStatus.data ||
        (desktopOnly && owner.surface != AppDeviceSurface.desktop) ||
        !allowed(result) ||
        !_matchesSession(owner)) {
      return;
    }

    final generation = ++_generation;
    state = const TeacherTopicResultActionState(
      status: TeacherTopicResultActionStatus.submitting,
    );
    // Leaving the screen must not drop the answer: the list underneath still
    // has to reload.
    final keepAlive = ref.keepAlive();
    try {
      final detail = await send(ref.read(teacherTopicResultRepositoryProvider));
      if (!_canPublish(generation, owner)) {
        return;
      }
      final shownDetail = teacherTopicResultDetailControllerProvider(target);
      if (ref.exists(shownDetail)) {
        ref.read(shownDetail.notifier).acceptAuthoritativeDetail(detail, owner);
      }
      _refreshList(owner);
      state = TeacherTopicResultActionState(feedback: success);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, owner)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure.serverCode)) {
        return;
      }
      _publishFailure(
        owner,
        teacherTopicResultActionFailureMessage(exception.failure, bulk: false),
        reload: teacherTopicResultActionFailureReloads(exception.failure),
      );
    } catch (_) {
      // An unknown outcome, or any unexpected failure, is reconciled by a read.
      if (_canPublish(generation, owner)) {
        _publishFailure(
          owner,
          teacherTopicResultActionUnknownMessage,
          reload: true,
        );
      }
    } finally {
      keepAlive.close();
    }
  }

  void _publishFailure(
    TeacherSessionKey owner,
    String notice, {
    required bool reload,
  }) {
    state = TeacherTopicResultActionState(notice: notice);
    if (reload) {
      final shownDetail = teacherTopicResultDetailControllerProvider(target);
      if (ref.exists(shownDetail)) {
        unawaited(ref.read(shownDetail.notifier).refreshAfterAction(owner));
      }
      _refreshList(owner);
    }
  }

  void _refreshList(TeacherSessionKey owner) {
    final list = teacherTopicResultListControllerProvider(target.topicId);
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
    state = const TeacherTopicResultActionState();
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
