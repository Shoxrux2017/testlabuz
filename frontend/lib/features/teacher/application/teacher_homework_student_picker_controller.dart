import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_group_student_repository_impl.dart';
import '../domain/teacher_group_student.dart';
import '../domain/teacher_group_student_list_query.dart';
import '../domain/teacher_homework.dart';
import 'teacher_homework_student_picker_state.dart';
import 'teacher_homework_student_picker_target.dart';
import 'teacher_session_key.dart';

final teacherHomeworkStudentPickerControllerProvider = NotifierProvider
    .autoDispose
    .family<
      TeacherHomeworkStudentPickerController,
      TeacherHomeworkStudentPickerState,
      TeacherHomeworkStudentPickerTarget
    >(TeacherHomeworkStudentPickerController.new);

const teacherHomeworkStudentSearchLengthError =
    'Search must be 100 characters or fewer.';

class TeacherHomeworkStudentPickerController
    extends Notifier<TeacherHomeworkStudentPickerState> {
  TeacherHomeworkStudentPickerController(this.target);

  final TeacherHomeworkStudentPickerTarget target;
  TeacherSessionKey? _activeSessionKey;
  TeacherGroupStudentListQuery? _inFlightQuery;
  int _pickerGeneration = 0;
  int _queryGeneration = 0;
  var _sessionInvalidated = false;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherHomeworkStudentPickerState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _clearOwnership(invalidateSession: true);
      });
    }

    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearOwnership(invalidateSession: _activeSessionKey != null);
      return TeacherHomeworkStudentPickerState();
    }
    if (_sessionInvalidated) {
      return TeacherHomeworkStudentPickerState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }
    if (_activeSessionKey != null) {
      _clearOwnership(invalidateSession: true);
      return TeacherHomeworkStudentPickerState();
    }

    _activeSessionKey = sessionKey;
    final pickerGeneration = ++_pickerGeneration;
    const query = TeacherGroupStudentListQuery.initial();
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey, pickerGeneration)) {
        _startLoad(query);
      }
    });
    return TeacherHomeworkStudentPickerState(
      status: TeacherHomeworkStudentPickerStatus.loading,
      query: query,
      selectedIds: target.initialSelectedIds,
    );
  }

  void updateSearchDraft(String value) {
    if (!_canInteract()) {
      return;
    }
    state = state.copyWith(
      searchDraft: value,
      searchErrorText: TeacherGroupStudentListQuery.isSearchInputValid(value)
          ? null
          : teacherHomeworkStudentSearchLengthError,
    );
  }

  void submitSearch() {
    if (!_canInteract() || !_validateSearchDraft()) {
      return;
    }
    final query = state.query.withSearch(state.searchDraft);
    if (query != state.query) {
      _startLoad(query);
    }
  }

  void commitSearchNow() => submitSearch();

  void previousPage() {
    if (state.canPrevious && _canInteract()) {
      _startLoad(state.query.withPage(state.query.page - 1));
    }
  }

  void nextPage() {
    if (state.canNext && _canInteract()) {
      _startLoad(state.query.withPage(state.query.page + 1));
    }
  }

  void refresh() {
    if (!state.isLoading && _canInteract() && _validateSearchDraft()) {
      _startLoad(state.query);
    }
  }

  void setStudentSelected(String studentId, bool selected) {
    if (!_canInteract() || !isCanonicalTeacherHomeworkId(studentId)) {
      return;
    }
    final existingId = _matchingId(state.selectedIds, studentId);
    if (selected &&
        existingId == null &&
        state.resolvedStudent(studentId) == null) {
      return;
    }
    if ((selected && existingId != null) || (!selected && existingId == null)) {
      return;
    }

    final selectedIds = <String>{...state.selectedIds};
    if (selected) {
      selectedIds.add(studentId.toLowerCase());
    } else {
      selectedIds.remove(existingId);
    }
    state = state.copyWith(selectedIds: selectedIds);
  }

  void removeSelectedStudent(String studentId) {
    setStudentSelected(studentId, false);
  }

  Set<String>? completeSelection() {
    if (!_canInteract()) {
      return null;
    }
    return Set<String>.unmodifiable(state.selectedIds);
  }

  void _startLoad(TeacherGroupStudentListQuery query) {
    final sessionKey = _activeSessionKey;
    final pickerGeneration = _pickerGeneration;
    if (sessionKey == null ||
        !_matchesSession(sessionKey, pickerGeneration) ||
        (_inFlightQuery == query && state.isLoading)) {
      return;
    }
    unawaited(_load(query, sessionKey, pickerGeneration));
  }

  Future<void> _load(
    TeacherGroupStudentListQuery query,
    TeacherSessionKey sessionKey,
    int pickerGeneration,
  ) async {
    final queryGeneration = ++_queryGeneration;
    _inFlightQuery = query;
    state = state.copyWith(
      status: TeacherHomeworkStudentPickerStatus.loading,
      query: query,
      result: null,
      failure: null,
    );
    try {
      final result = await ref
          .read(teacherGroupStudentRepositoryProvider)
          .fetchGroupStudents(target.groupId, query);
      if (!_canPublish(
        sessionKey: sessionKey,
        pickerGeneration: pickerGeneration,
        queryGeneration: queryGeneration,
        query: query,
      )) {
        return;
      }

      final resolvedStudents = <String, TeacherGroupStudent>{
        ...state.resolvedStudentsById,
      };
      for (final student in result.items) {
        final previousKey = _matchingId(resolvedStudents.keys, student.id);
        if (previousKey != null) {
          resolvedStudents.remove(previousKey);
        }
        resolvedStudents[student.id] = student;
      }
      state = state.copyWith(
        status: result.items.isEmpty
            ? TeacherHomeworkStudentPickerStatus.empty
            : TeacherHomeworkStudentPickerStatus.data,
        result: result,
        failure: null,
        resolvedStudentsById: resolvedStudents,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(
        sessionKey: sessionKey,
        pickerGeneration: pickerGeneration,
        queryGeneration: queryGeneration,
        query: query,
      )) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state = state.copyWith(
        status: TeacherHomeworkStudentPickerStatus.error,
        result: null,
        failure: exception.failure,
      );
    } catch (_) {
      if (_canPublish(
        sessionKey: sessionKey,
        pickerGeneration: pickerGeneration,
        queryGeneration: queryGeneration,
        query: query,
      )) {
        state = state.copyWith(
          status: TeacherHomeworkStudentPickerStatus.error,
          result: null,
          failure: ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'Unexpected Student roster response.',
          ),
        );
      }
    } finally {
      if (queryGeneration == _queryGeneration) {
        _inFlightQuery = null;
      }
    }
  }

  bool _canPublish({
    required TeacherSessionKey sessionKey,
    required int pickerGeneration,
    required int queryGeneration,
    required TeacherGroupStudentListQuery query,
  }) {
    return ref.mounted &&
        !_isDisposed &&
        pickerGeneration == _pickerGeneration &&
        queryGeneration == _queryGeneration &&
        _inFlightQuery == query &&
        state.query == query &&
        _matchesSession(sessionKey, pickerGeneration);
  }

  bool _canInteract() {
    final sessionKey = _activeSessionKey;
    return sessionKey != null && _matchesSession(sessionKey, _pickerGeneration);
  }

  bool _matchesSession(TeacherSessionKey sessionKey, int pickerGeneration) {
    return ref.mounted &&
        !_isDisposed &&
        !_sessionInvalidated &&
        pickerGeneration == _pickerGeneration &&
        _activeSessionKey == sessionKey &&
        sessionKey.surface == AppDeviceSurface.desktop &&
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

    _clearOwnership(invalidateSession: true);
    state = TeacherHomeworkStudentPickerState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  bool _validateSearchDraft() {
    final isValid = TeacherGroupStudentListQuery.isSearchInputValid(
      state.searchDraft,
    );
    state = state.copyWith(
      searchErrorText: isValid ? null : teacherHomeworkStudentSearchLengthError,
    );
    return isValid;
  }

  void _clearOwnership({required bool invalidateSession}) {
    _activeSessionKey = null;
    _inFlightQuery = null;
    _pickerGeneration += 1;
    _queryGeneration += 1;
    if (invalidateSession) {
      _sessionInvalidated = true;
    }
  }
}

String? _matchingId(Iterable<String> ids, String candidate) {
  final normalized = candidate.toLowerCase();
  for (final id in ids) {
    if (id.toLowerCase() == normalized) {
      return id;
    }
  }
  return null;
}
