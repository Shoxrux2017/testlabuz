import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_submission_repository_impl.dart';
import '../domain/teacher_official_score.dart';
import 'teacher_official_score_state.dart';
import 'teacher_session_key.dart';

final teacherOfficialScoreControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherOfficialScoreController,
      TeacherOfficialScoreState,
      TeacherOfficialScoreTarget
    >(TeacherOfficialScoreController.new);

/// One Student's official task score next to a submission
/// (`S09-FE-003C`); desktop only.
class TeacherOfficialScoreController
    extends Notifier<TeacherOfficialScoreState> {
  TeacherOfficialScoreController(this.target);

  final TeacherOfficialScoreTarget target;
  TeacherSessionKey? _activeSessionKey;
  var _requestActive = false;
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherOfficialScoreState build() {
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
      return const TeacherOfficialScoreState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLoad(retainScore: false);
      }
    });

    return const TeacherOfficialScoreState(
      status: TeacherOfficialScoreLoadStatus.loading,
    );
  }

  /// Replaces a load in flight: it may have read the score before a review
  /// save committed.
  void refresh() {
    if (_activeSessionKey == null) {
      return;
    }
    _requestActive = false;
    _startLoad(retainScore: state.score != null);
  }

  void retry() {
    if (_requestActive ||
        _activeSessionKey == null ||
        state.status != TeacherOfficialScoreLoadStatus.error) {
      return;
    }
    _startLoad(retainScore: state.score != null);
  }

  void _startLoad({required bool retainScore}) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || _requestActive || !_matchesSession(sessionKey)) {
      return;
    }

    final retainedScore = retainScore ? state.score : null;
    final generation = ++_generation;
    _requestActive = true;
    state = TeacherOfficialScoreState(
      status: retainedScore == null
          ? TeacherOfficialScoreLoadStatus.loading
          : TeacherOfficialScoreLoadStatus.refreshing,
      score: retainedScore,
    );
    unawaited(
      _load(
        sessionKey: sessionKey,
        generation: generation,
        retainedScore: retainedScore,
      ),
    );
  }

  Future<void> _load({
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherOfficialScore? retainedScore,
  }) async {
    try {
      final score = await ref
          .read(teacherSubmissionRepositoryProvider)
          .fetchOfficialScore(target);
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      state = TeacherOfficialScoreState(
        status: TeacherOfficialScoreLoadStatus.data,
        score: score,
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
        state = const TeacherOfficialScoreState(
          status: TeacherOfficialScoreLoadStatus.notFound,
        );
        return;
      }
      _publishFailure(retainedScore, exception.failure);
    } catch (_) {
      if (_canPublish(generation, sessionKey)) {
        _publishFailure(
          retainedScore,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher official score failure.',
          ),
        );
      }
    } finally {
      if (generation == _generation) {
        _requestActive = false;
      }
    }
  }

  void _publishFailure(TeacherOfficialScore? retained, ApiFailure failure) {
    state = TeacherOfficialScoreState(
      status: TeacherOfficialScoreLoadStatus.error,
      score: retained,
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
    state = const TeacherOfficialScoreState();
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
