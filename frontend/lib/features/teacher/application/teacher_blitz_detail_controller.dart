import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_blitz_repository_impl.dart';
import '../domain/teacher_blitz.dart';
import 'teacher_blitz_detail_state.dart';
import 'teacher_blitz_route_target.dart';
import 'teacher_session_key.dart';

final teacherBlitzDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherBlitzDetailController,
      TeacherBlitzDetailState,
      TeacherBlitzRouteTarget
    >(TeacherBlitzDetailController.new);

class TeacherBlitzDetailController extends Notifier<TeacherBlitzDetailState> {
  TeacherBlitzDetailController(this.target);

  final TeacherBlitzRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  var _requestActive = false;
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherBlitzDetailState build() {
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
    if (sessionKey == null) {
      _clearOwnership();
      return const TeacherBlitzDetailState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLoad(retainBlitz: false);
      }
    });

    return const TeacherBlitzDetailState(
      status: TeacherBlitzDetailStatus.loading,
    );
  }

  void refresh() {
    if (_requestActive || _activeSessionKey == null) {
      return;
    }
    _startLoad(retainBlitz: state.blitz != null);
  }

  void retry() {
    if (_requestActive ||
        _activeSessionKey == null ||
        state.status != TeacherBlitzDetailStatus.error) {
      return;
    }
    _startLoad(retainBlitz: state.blitz != null);
  }

  /// Publishes a mutation's authoritative resource without another GET.
  void acceptAuthoritativeBlitz(
    TeacherBlitz blitz,
    TeacherSessionKey originatingSessionKey,
  ) {
    if (!_matchesSession(originatingSessionKey) ||
        blitz.id.toLowerCase() != target.blitzId.toLowerCase() ||
        blitz.topicId.toLowerCase() != target.topicId.toLowerCase()) {
      return;
    }

    _cancelActiveRequest();
    state = TeacherBlitzDetailState(
      status: TeacherBlitzDetailStatus.data,
      blitz: blitz,
    );
  }

  void markNotFound(TeacherSessionKey originatingSessionKey) {
    if (!_matchesSession(originatingSessionKey)) {
      return;
    }

    _cancelActiveRequest();
    state = const TeacherBlitzDetailState(
      status: TeacherBlitzDetailStatus.notFound,
    );
  }

  void _startLoad({required bool retainBlitz}) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || _requestActive || !_matchesSession(sessionKey)) {
      return;
    }

    final retainedBlitz = retainBlitz ? state.blitz : null;
    final generation = ++_generation;
    _requestActive = true;
    state = TeacherBlitzDetailState(
      status: retainedBlitz == null
          ? TeacherBlitzDetailStatus.loading
          : TeacherBlitzDetailStatus.refreshing,
      blitz: retainedBlitz,
    );
    unawaited(
      _load(
        sessionKey: sessionKey,
        generation: generation,
        retainedBlitz: retainedBlitz,
      ),
    );
  }

  Future<void> _load({
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherBlitz? retainedBlitz,
  }) async {
    try {
      final blitz = await ref
          .read(teacherBlitzRepositoryProvider)
          .fetchBlitz(target.blitzId);
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      // The backend reads by Blitz ID only; never show it under another Topic.
      if (blitz.topicId.toLowerCase() != target.topicId.toLowerCase()) {
        state = const TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.notFound,
        );
        return;
      }
      state = TeacherBlitzDetailState(
        status: TeacherBlitzDetailStatus.data,
        blitz: blitz,
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
        state = const TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.notFound,
        );
        return;
      }
      state = TeacherBlitzDetailState(
        status: TeacherBlitzDetailStatus.error,
        blitz: retainedBlitz,
        failure: exception.failure,
        isStale: retainedBlitz != null,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey)) {
        state = TeacherBlitzDetailState(
          status: TeacherBlitzDetailStatus.error,
          blitz: retainedBlitz,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher Blitz detail failure.',
          ),
          isStale: retainedBlitz != null,
        );
      }
    } finally {
      if (generation == _generation) {
        _requestActive = false;
      }
    }
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
    state = const TeacherBlitzDetailState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }

    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _cancelActiveRequest();
  }

  void _cancelActiveRequest() {
    _requestActive = false;
    _generation += 1;
  }
}
