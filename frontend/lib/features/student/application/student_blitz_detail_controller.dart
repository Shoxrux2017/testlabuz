import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_blitz_repository_impl.dart';
import '../domain/student_blitz_route_target.dart';
import 'student_active_blitz_controller.dart';
import 'student_blitz_detail_state.dart';
import 'student_session_key.dart';

final studentBlitzDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentBlitzDetailController,
      StudentBlitzDetailState,
      StudentBlitzRouteTarget
    >(StudentBlitzDetailController.new);

class StudentBlitzDetailController extends Notifier<StudentBlitzDetailState> {
  StudentBlitzDetailController(this.target);

  final StudentBlitzRouteTarget target;
  StudentSessionKey? _activeSessionKey;
  var _generation = 0;
  var _dataSerial = 0;
  int? _expiryReconciledSerial;

  @override
  StudentBlitzDetailState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearOwnership();
      return const StudentBlitzDetailState();
    }
    if (_activeSessionKey == key && !ref.isRefresh) {
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
    return const StudentBlitzDetailState(
      status: StudentBlitzDetailStatus.loading,
    );
  }

  /// Student-requested refresh; ignored while a read is already in flight.
  void refresh() {
    final key = _activeSessionKey;
    if (key != null && !state.isRequestInFlight && _matchesSession(key)) {
      unawaited(_load(key));
    }
  }

  void retry() {
    if (state.status == StudentBlitzDetailStatus.error) {
      refresh();
    }
  }

  /// Authoritative re-read after an execution outcome; it supersedes any
  /// older in-flight read so a pre-outcome response cannot publish.
  void reconcile() {
    final key = _activeSessionKey;
    if (key != null && _matchesSession(key)) {
      unawaited(_load(key));
    }
  }

  /// One authoritative detail read (plus active-list refresh) when a local
  /// countdown reaches zero. The read itself runs the backend timeout
  /// reconciliation; the device never finalizes anything. It supersedes a
  /// read begun before zero, which could return the same pre-zero snapshot.
  void reconcileAfterLocalExpiry() {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        _expiryReconciledSerial == _dataSerial) {
      return;
    }
    _expiryReconciledSerial = _dataSerial;
    unawaited(_load(key));
    _refreshActiveList(key);
  }

  Future<void> _load(StudentSessionKey key) async {
    final generation = ++_generation;
    final requestTarget = target;
    final retained = state.blitz;
    state = StudentBlitzDetailState(
      status: retained == null
          ? StudentBlitzDetailStatus.loading
          : StudentBlitzDetailStatus.refreshing,
      blitz: retained,
    );
    try {
      final blitz = await ref
          .read(studentBlitzRepositoryProvider)
          .fetchBlitz(requestTarget.blitzId);
      if (!_canPublish(generation, key, requestTarget)) {
        return;
      }
      if (blitz.id.toLowerCase() != requestTarget.blitzId ||
          blitz.topic.id.toLowerCase() != requestTarget.topicId) {
        state = const StudentBlitzDetailState(
          status: StudentBlitzDetailStatus.notFound,
        );
        return;
      }
      _dataSerial += 1;
      state = StudentBlitzDetailState(
        status: StudentBlitzDetailStatus.data,
        blitz: blitz,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, requestTarget) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      final conflict = _conflictStatus(exception.failure);
      if (conflict != null) {
        state = StudentBlitzDetailState(status: conflict);
        _refreshActiveList(key);
        return;
      }
      state = StudentBlitzDetailState(
        status: StudentBlitzDetailStatus.error,
        failure: exception.failure,
      );
    } catch (_) {
      // Like the Topic detail, an unexpected failure is a retryable error.
      if (_canPublish(generation, key, requestTarget)) {
        state = StudentBlitzDetailState(
          status: StudentBlitzDetailStatus.error,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Student Blitz failure.',
          ),
        );
      }
    }
  }

  StudentBlitzDetailStatus? _conflictStatus(ApiFailure failure) => switch ((
    failure.statusCode,
    failure.serverCode,
  )) {
    (404, ApiErrorCodes.resourceNotFound) => StudentBlitzDetailStatus.notFound,
    (409, ApiErrorCodes.blitzNotActive) => StudentBlitzDetailStatus.notActive,
    (409, ApiErrorCodes.blitzTimeExpired) =>
      StudentBlitzDetailStatus.timeExpired,
    _ => null,
  };

  void _refreshActiveList(StudentSessionKey key) {
    if (ref.exists(studentActiveBlitzControllerProvider)) {
      ref
          .read(studentActiveBlitzControllerProvider.notifier)
          .refreshAfterExecution(key);
    }
  }

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    StudentBlitzRouteTarget requestTarget,
  ) =>
      ref.mounted &&
      generation == _generation &&
      target == requestTarget &&
      _matchesSession(key);

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
    state = const StudentBlitzDetailState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _generation += 1;
    _expiryReconciledSerial = null;
  }
}
