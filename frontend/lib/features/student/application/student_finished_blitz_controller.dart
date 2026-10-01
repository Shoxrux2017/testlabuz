import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_blitz_repository_impl.dart';
import '../domain/student_finished_blitz.dart';
import 'student_finished_blitz_state.dart';
import 'student_session_key.dart';

const studentFinishedBlitzPageSize = 5;

/// The backend list is global for the current Student, so it is not keyed.
final studentFinishedBlitzControllerProvider =
    NotifierProvider.autoDispose<
      StudentFinishedBlitzController,
      StudentFinishedBlitzState
    >(StudentFinishedBlitzController.new);

/// The Student's finished Blitz tasks with their released results
/// (`S09-FE-004B`), one page at a time.
class StudentFinishedBlitzController
    extends Notifier<StudentFinishedBlitzState> {
  StudentSessionKey? _activeSessionKey;
  var _generation = 0;

  /// The page of the latest request, so a retry repeats a failed page change.
  var _requestedPage = 1;

  @override
  StudentFinishedBlitzState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearOwnership();
      return const StudentFinishedBlitzState();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    final generation = _generation;
    scheduleMicrotask(() {
      if (_matchesSession(key) && generation == _generation) {
        unawaited(_load(key, 1));
      }
    });
    return const StudentFinishedBlitzState(
      status: StudentFinishedBlitzLoadStatus.loading,
    );
  }

  void refresh() {
    final key = _activeSessionKey;
    if (key != null && !state.isRequestInFlight && _matchesSession(key)) {
      unawaited(_load(key, state.page?.page ?? 1));
    }
  }

  void retry() {
    final key = _activeSessionKey;
    if (key != null &&
        state.status == StudentFinishedBlitzLoadStatus.error &&
        _matchesSession(key)) {
      unawaited(_load(key, _requestedPage));
    }
  }

  void nextPage() {
    final key = _activeSessionKey;
    if (key != null && state.canGoNext && _matchesSession(key)) {
      unawaited(_load(key, state.page!.page + 1));
    }
  }

  void previousPage() {
    final key = _activeSessionKey;
    if (key != null && state.canGoPrevious && _matchesSession(key)) {
      unawaited(_load(key, state.page!.page - 1));
    }
  }

  Future<void> _load(StudentSessionKey key, int page) async {
    final generation = ++_generation;
    _requestedPage = page;
    final retained = state.page;
    state = StudentFinishedBlitzState(
      status: retained == null
          ? StudentFinishedBlitzLoadStatus.loading
          : StudentFinishedBlitzLoadStatus.refreshing,
      page: retained,
      isStale: state.isStale,
    );
    try {
      final loaded = await ref
          .read(studentBlitzRepositoryProvider)
          .fetchFinishedBlitz(
            page: page,
            perPage: studentFinishedBlitzPageSize,
          );
      if (!_canPublish(generation, key)) {
        return;
      }
      state = StudentFinishedBlitzState(
        status: StudentFinishedBlitzLoadStatus.data,
        page: loaded,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishFailure(retained, exception.failure);
    } catch (_) {
      if (_canPublish(generation, key)) {
        _publishFailure(
          retained,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected finished Blitz failure.',
          ),
        );
      }
    }
  }

  void _publishFailure(StudentFinishedBlitzPage? retained, ApiFailure failure) {
    state = StudentFinishedBlitzState(
      status: StudentFinishedBlitzLoadStatus.error,
      page: retained,
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
    state = const StudentFinishedBlitzState();
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
