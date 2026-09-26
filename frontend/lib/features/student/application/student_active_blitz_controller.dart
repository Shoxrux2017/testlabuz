import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_blitz_repository_impl.dart';
import '../domain/student_blitz.dart';
import 'student_active_blitz_state.dart';
import 'student_session_key.dart';

/// The backend list is global for the current Student, so it is not keyed.
final studentActiveBlitzControllerProvider =
    NotifierProvider.autoDispose<
      StudentActiveBlitzController,
      StudentActiveBlitzState
    >(StudentActiveBlitzController.new);

class StudentActiveBlitzController extends Notifier<StudentActiveBlitzState> {
  StudentSessionKey? _activeSessionKey;
  var _generation = 0;

  @override
  StudentActiveBlitzState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearOwnership();
      return const StudentActiveBlitzState();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    final generation = _generation;
    scheduleMicrotask(() {
      if (_matchesSession(key) && generation == _generation) {
        unawaited(_load(key));
      }
    });
    return const StudentActiveBlitzState(
      status: StudentActiveBlitzStatus.loading,
    );
  }

  void refresh() {
    final key = _activeSessionKey;
    if (key != null && !state.isRequestInFlight && _matchesSession(key)) {
      unawaited(_load(key));
    }
  }

  void retry() {
    if (state.status == StudentActiveBlitzStatus.error) {
      refresh();
    }
  }

  /// Re-reads the server list after a Start/Resume outcome or an expiry
  /// reconciliation owned by [originatingSessionKey]. It supersedes an older
  /// in-flight read and never edits cards locally.
  void refreshAfterExecution(StudentSessionKey originatingSessionKey) {
    if (_activeSessionKey == originatingSessionKey &&
        _matchesSession(originatingSessionKey)) {
      unawaited(_load(originatingSessionKey));
    }
  }

  Future<void> _load(StudentSessionKey key) async {
    final generation = ++_generation;
    final retained = state.items;
    state = StudentActiveBlitzState(
      status: retained == null
          ? StudentActiveBlitzStatus.loading
          : StudentActiveBlitzStatus.refreshing,
      items: retained,
      isStale: state.isStale,
    );
    try {
      final items = await ref
          .read(studentBlitzRepositoryProvider)
          .fetchActiveBlitz();
      if (!_canPublish(generation, key)) {
        return;
      }
      state = StudentActiveBlitzState(
        status: StudentActiveBlitzStatus.data,
        items: items,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishFailure(retained, exception.failure);
    } catch (_) {
      // Like the Topic list beside it, an unexpected failure ends in a
      // retryable error instead of an endless load.
      if (_canPublish(generation, key)) {
        _publishFailure(
          retained,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected active Blitz failure.',
          ),
        );
      }
    }
  }

  void _publishFailure(
    List<StudentActiveBlitzSummary>? retained,
    ApiFailure failure,
  ) {
    state = StudentActiveBlitzState(
      status: StudentActiveBlitzStatus.error,
      items: retained,
      failure: failure,
      isStale: retained != null,
    );
  }

  bool _canPublish(int generation, StudentSessionKey key) =>
      ref.mounted && generation == _generation && _matchesSession(key);

  bool _matchesSession(StudentSessionKey key) =>
      ref.mounted &&
      _activeSessionKey == key &&
      StudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          key;

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearOwnership();
    state = const StudentActiveBlitzState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _generation += 1;
  }
}
