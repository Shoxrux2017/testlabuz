import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_submission_repository_impl.dart';
import '../domain/teacher_submission.dart';
import '../domain/teacher_submission_list.dart';
import '../domain/teacher_submission_list_query.dart';
import 'teacher_review_queue_filter.dart';
import 'teacher_review_queue_scope.dart';
import 'teacher_review_queue_state.dart';
import 'teacher_session_key.dart';

final teacherReviewQueueControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherReviewQueueController,
      TeacherReviewQueueState,
      TeacherReviewQueueScope
    >(TeacherReviewQueueController.new);

/// The desktop review queue (`S09-D7`): filters, sort and pages over
/// `GET /teacher/submissions`.
class TeacherReviewQueueController extends Notifier<TeacherReviewQueueState> {
  TeacherReviewQueueController(this.scope);

  final TeacherReviewQueueScope scope;
  TeacherSessionKey? _activeSessionKey;
  TeacherSubmissionListQuery? _inFlightQuery;
  Map<TeacherReviewQueueFilterKind, String> _filterLabels = const {};
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherReviewQueueState build() {
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
      return TeacherReviewQueueState(query: scope.initialQuery);
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    final query = scope.initialQuery;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLoad(query, retainResult: false);
      }
    });

    return TeacherReviewQueueState(
      status: TeacherReviewQueueStatus.loading,
      query: query,
    );
  }

  void setCheckingStatus(TeacherSubmissionCheckingFilter? value) {
    if (value != state.query.checkingStatus) {
      _startLoad(state.query.withCheckingStatus(value), retainResult: false);
    }
  }

  void setType(TeacherSubmissionTaskType? value) {
    if (value != state.query.type) {
      _startLoad(state.query.withType(value), retainResult: false);
    }
  }

  void setOfficial(bool? value) {
    if (value != state.query.official) {
      _startLoad(state.query.withOfficial(value), retainResult: false);
    }
  }

  void setOverdueOnly(bool value) {
    if (value != state.query.overdueOnly) {
      _startLoad(state.query.withOverdueOnly(value), retainResult: false);
    }
  }

  void setSort(TeacherSubmissionSort value) {
    if (value != state.query.sort) {
      _startLoad(state.query.withSort(value), retainResult: false);
    }
  }

  void setDirection(TeacherSubmissionSortDirection value) {
    if (value != state.query.direction &&
        state.query.sort != TeacherSubmissionSort.recommended) {
      _startLoad(state.query.withDirection(value), retainResult: false);
    }
  }

  void clearFilters() {
    final query = scope.initialQuery;
    if (query != state.query) {
      _filterLabels = const {};
      _startLoad(query, retainResult: false);
    }
  }

  /// Narrows the queue to [filter]'s Topic, group or Student (`CL9-5`); a
  /// value the scope fixes never changes.
  void filterByRow(TeacherReviewQueueRowFilter filter) {
    if (scope.fixes(filter.kind) || _activeSessionKey == null) {
      return;
    }
    final query = _withRowFilter(state.query, filter.kind, filter.id);
    if (query == state.query) {
      return;
    }
    _filterLabels = {..._filterLabels, filter.kind: filter.label};
    _startLoad(query, retainResult: false);
  }

  void removeRowFilter(TeacherReviewQueueFilterKind kind) {
    if (scope.fixes(kind) ||
        _activeSessionKey == null ||
        !_filterLabels.containsKey(kind)) {
      return;
    }
    _filterLabels = {..._filterLabels}..remove(kind);
    _startLoad(_withRowFilter(state.query, kind, null), retainResult: false);
  }

  void previousPage() {
    if (state.canGoPrevious) {
      _startLoad(
        state.query.withPage(state.query.page - 1),
        retainResult: false,
      );
    }
  }

  void nextPage() {
    if (state.canGoNext) {
      _startLoad(
        state.query.withPage(state.query.page + 1),
        retainResult: false,
      );
    }
  }

  void refresh() {
    if (_activeSessionKey != null) {
      _startLoad(state.query, retainResult: state.result != null);
    }
  }

  /// Reloads after a review save owned by [originatingSessionKey]. A load in
  /// flight may have been read before that save, so it is replaced.
  void refreshAfterReview(TeacherSessionKey originatingSessionKey) {
    if (_activeSessionKey != originatingSessionKey ||
        !_matchesSession(originatingSessionKey)) {
      return;
    }
    _inFlightQuery = null;
    _startLoad(state.query, retainResult: state.result != null);
  }

  void retry() {
    if (state.status == TeacherReviewQueueStatus.error &&
        _activeSessionKey != null) {
      _startLoad(state.query, retainResult: state.result != null);
    }
  }

  void _startLoad(
    TeacherSubmissionListQuery query, {
    required bool retainResult,
  }) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_matchesSession(sessionKey) ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }

    final retainedResult = retainResult ? state.result : null;
    final generation = ++_generation;
    _inFlightQuery = query;
    state = TeacherReviewQueueState(
      status: retainedResult == null
          ? TeacherReviewQueueStatus.loading
          : TeacherReviewQueueStatus.refreshing,
      query: query,
      result: retainedResult,
      filterLabels: _filterLabels,
    );
    unawaited(
      _load(
        query,
        sessionKey: sessionKey,
        generation: generation,
        retainedResult: retainedResult,
      ),
    );
  }

  Future<void> _load(
    TeacherSubmissionListQuery query, {
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherSubmissionList? retainedResult,
  }) async {
    try {
      final result = await ref
          .read(teacherSubmissionRepositoryProvider)
          .fetchSubmissions(query);
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      state = TeacherReviewQueueState(
        status: TeacherReviewQueueStatus.data,
        query: query,
        result: result,
        filterLabels: _filterLabels,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishFailure(query, retainedResult, exception.failure);
    } catch (_) {
      if (_canPublish(generation, sessionKey, query)) {
        _publishFailure(
          query,
          retainedResult,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher review queue failure.',
          ),
        );
      }
    } finally {
      if (generation == _generation && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  void _publishFailure(
    TeacherSubmissionListQuery query,
    TeacherSubmissionList? retainedResult,
    ApiFailure failure,
  ) {
    state = TeacherReviewQueueState(
      status: TeacherReviewQueueStatus.error,
      query: query,
      result: retainedResult,
      failure: failure,
      isStale: retainedResult != null,
      filterLabels: _filterLabels,
    );
  }

  bool _canPublish(
    int generation,
    TeacherSessionKey sessionKey,
    TeacherSubmissionListQuery query,
  ) {
    return ref.mounted &&
        !_isDisposed &&
        generation == _generation &&
        _inFlightQuery == query &&
        state.query == query &&
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
    state = TeacherReviewQueueState(query: scope.initialQuery);
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _inFlightQuery = null;
    _filterLabels = const {};
    _generation += 1;
  }
}

TeacherSubmissionListQuery _withRowFilter(
  TeacherSubmissionListQuery query,
  TeacherReviewQueueFilterKind kind,
  String? id,
) {
  return switch (kind) {
    TeacherReviewQueueFilterKind.topic => query.withTopic(id),
    TeacherReviewQueueFilterKind.group => query.withGroup(id),
    TeacherReviewQueueFilterKind.student => query.withStudent(id),
  };
}
