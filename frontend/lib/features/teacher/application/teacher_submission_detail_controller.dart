import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_submission_repository_impl.dart';
import '../domain/teacher_submission_detail.dart';
import 'teacher_session_key.dart';
import 'teacher_submission_detail_state.dart';

final teacherSubmissionDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherSubmissionDetailController,
      TeacherSubmissionDetailState,
      String
    >(TeacherSubmissionDetailController.new);

/// One submission as the Teacher reviews it; desktop only (`S09-D7`).
class TeacherSubmissionDetailController
    extends Notifier<TeacherSubmissionDetailState> {
  TeacherSubmissionDetailController(this.submissionId);

  final String submissionId;
  TeacherSessionKey? _activeSessionKey;
  var _requestActive = false;
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherSubmissionDetailState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _clearOwnership();
      });
    }

    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearOwnership();
      return const TeacherSubmissionDetailState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLoad(retainDetail: false);
      }
    });

    return const TeacherSubmissionDetailState(
      status: TeacherSubmissionDetailStatus.loading,
    );
  }

  void refresh() {
    if (_requestActive || _activeSessionKey == null) {
      return;
    }
    _startLoad(retainDetail: state.detail != null);
  }

  void retry() {
    if (_requestActive ||
        _activeSessionKey == null ||
        state.status != TeacherSubmissionDetailStatus.error) {
      return;
    }
    _startLoad(retainDetail: state.detail != null);
  }

  void _startLoad({required bool retainDetail}) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || _requestActive || !_matchesSession(sessionKey)) {
      return;
    }

    final retainedDetail = retainDetail ? state.detail : null;
    final generation = ++_generation;
    _requestActive = true;
    state = TeacherSubmissionDetailState(
      status: retainedDetail == null
          ? TeacherSubmissionDetailStatus.loading
          : TeacherSubmissionDetailStatus.refreshing,
      detail: retainedDetail,
    );
    unawaited(
      _load(
        sessionKey: sessionKey,
        generation: generation,
        retainedDetail: retainedDetail,
      ),
    );
  }

  Future<void> _load({
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherSubmissionDetail? retainedDetail,
  }) async {
    try {
      final detail = await ref
          .read(teacherSubmissionRepositoryProvider)
          .fetchSubmission(submissionId);
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      state = TeacherSubmissionDetailState(
        status: TeacherSubmissionDetailStatus.data,
        detail: detail,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        state = const TeacherSubmissionDetailState(
          status: TeacherSubmissionDetailStatus.notFound,
        );
        return;
      }
      _publishFailure(retainedDetail, exception.failure);
    } catch (_) {
      if (_canPublish(generation, sessionKey)) {
        _publishFailure(
          retainedDetail,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher submission detail failure.',
          ),
        );
      }
    } finally {
      if (generation == _generation) {
        _requestActive = false;
      }
    }
  }

  void _publishFailure(TeacherSubmissionDetail? retained, ApiFailure failure) {
    state = TeacherSubmissionDetailState(
      status: TeacherSubmissionDetailStatus.error,
      detail: retained,
      failure: failure,
      isStale: retained != null,
    );
  }

  bool _canPublish(int generation, TeacherSessionKey sessionKey) {
    return ref.mounted &&
        !_isDisposed &&
        _requestActive &&
        generation == _generation &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
        !_isDisposed &&
        _activeSessionKey == sessionKey &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            sessionKey;
  }

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }

    _clearOwnership();
    state = const TeacherSubmissionDetailState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _requestActive = false;
    _generation += 1;
  }
}
