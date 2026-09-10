import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_homework_repository_impl.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_list.dart';
import '../domain/student_homework_list_query.dart';
import 'student_homework_list_state.dart';
import 'student_session_key.dart';

final studentHomeworkListControllerProvider = NotifierProvider.autoDispose
    .family<StudentHomeworkListController, StudentHomeworkListState, String>(
      StudentHomeworkListController.new,
    );

class StudentHomeworkListController extends Notifier<StudentHomeworkListState> {
  StudentHomeworkListController(this.topicId);

  final String topicId;
  StudentSessionKey? _activeSessionKey;
  StudentHomeworkListQuery? _inFlightQuery;
  var _generation = 0;

  @override
  StudentHomeworkListState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final query = StudentHomeworkListQuery(topicId: topicId);
    if (key == null) {
      _clearOwnership();
      return StudentHomeworkListState(query: query);
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    final generation = _generation;
    scheduleMicrotask(() {
      if (_matchesSession(key) && generation == _generation) {
        _startLoad(query);
      }
    });
    return StudentHomeworkListState(
      query: query,
      status: StudentHomeworkListStatus.loading,
    );
  }

  void refresh() => _startLoad(state.query, retainPage: true);

  void retry() {
    if (state.status == StudentHomeworkListStatus.error) {
      _startLoad(state.query, retainPage: true);
    }
  }

  void setStatus(StudentHomeworkStatus? status) {
    final query = state.query.withStatus(status);
    if (query != state.query) {
      _startLoad(query);
    }
  }

  void previousPage() {
    if (state.canGoPrevious) {
      _startLoad(state.query.withPage(state.page!.page - 1));
    }
  }

  void nextPage() {
    if (state.canGoNext) {
      _startLoad(state.query.withPage(state.page!.page + 1));
    }
  }

  void markAuthoritativeRowsStale(StudentSessionKey key) {
    if (!_matchesSession(key)) {
      return;
    }
    _generation += 1;
    _inFlightQuery = null;
    state = StudentHomeworkListState(
      query: state.query,
      status: state.status,
      page: state.page,
      failure: state.failure,
      isStale: state.page != null,
    );
    _startLoad(state.query, retainPage: true);
  }

  void _startLoad(StudentHomeworkListQuery query, {bool retainPage = false}) {
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key) || _inFlightQuery == query) {
      return;
    }
    final retainedPage = retainPage && query == state.query ? state.page : null;
    final generation = ++_generation;
    _inFlightQuery = query;
    state = StudentHomeworkListState(
      query: query,
      status: retainedPage == null
          ? StudentHomeworkListStatus.loading
          : StudentHomeworkListStatus.refreshing,
      page: retainedPage,
      isStale: retainedPage != null && state.isStale,
    );
    unawaited(
      _load(query, key: key, generation: generation, correctionUsed: false),
    );
  }

  Future<void> _load(
    StudentHomeworkListQuery query, {
    required StudentSessionKey key,
    required int generation,
    required bool correctionUsed,
  }) async {
    try {
      final page = await ref
          .read(studentHomeworkRepositoryProvider)
          .fetchHomework(query);
      if (!_canPublish(generation, key, query)) {
        return;
      }
      final correction = _correctionTarget(query, page, correctionUsed);
      if (correction != null) {
        final correctedQuery = query.withPage(correction);
        _inFlightQuery = correctedQuery;
        state = StudentHomeworkListState(
          query: correctedQuery,
          status: StudentHomeworkListStatus.loading,
        );
        await _load(
          correctedQuery,
          key: key,
          generation: generation,
          correctionUsed: true,
        );
        return;
      }
      state = StudentHomeworkListState.fromPage(query: query, page: page);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, query) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishFailure(query, exception.failure);
    } finally {
      if (generation == _generation && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  void _publishFailure(StudentHomeworkListQuery query, ApiFailure failure) {
    state = StudentHomeworkListState(
      query: query,
      status: StudentHomeworkListStatus.error,
      page: state.page,
      failure: failure,
      isStale: state.page != null,
    );
  }

  int? _correctionTarget(
    StudentHomeworkListQuery query,
    StudentHomeworkList page,
    bool correctionUsed,
  ) {
    if (correctionUsed || page.items.isNotEmpty || query.page <= 1) {
      return null;
    }
    final target = page.total == 0
        ? 1
        : math.max(1, math.min(page.lastPage, query.page - 1));
    return target == query.page ? null : target;
  }

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    StudentHomeworkListQuery query,
  ) =>
      ref.mounted &&
      generation == _generation &&
      _inFlightQuery == query &&
      state.query == query &&
      query.topicId.toLowerCase() == topicId.toLowerCase() &&
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
    state = StudentHomeworkListState(
      query: StudentHomeworkListQuery(topicId: topicId),
    );
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _generation += 1;
    _inFlightQuery = null;
  }
}
