import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_institution_admin_repository_impl.dart';
import '../domain/platform_institution_admin_list_query.dart';
import 'platform_institution_admin_list_state.dart';

final platformInstitutionAdminListControllerProvider = NotifierProvider
    .autoDispose
    .family<
      PlatformInstitutionAdminListController,
      PlatformInstitutionAdminListState,
      PlatformInstitutionAdminListKey
    >((key) => PlatformInstitutionAdminListController(key));

class PlatformInstitutionAdminListController
    extends Notifier<PlatformInstitutionAdminListState> {
  PlatformInstitutionAdminListController(this.key);

  final PlatformInstitutionAdminListKey key;

  String? _sessionUserId;
  int? _sessionInstanceId;
  String? _institutionId;
  PlatformInstitutionAdminListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformInstitutionAdminListState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _searchDebounce?.cancel();
      _operationGeneration += 1;
    });

    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;

    if (session.status != AuthSessionStatus.authenticated ||
        user == null ||
        user.id != key.sessionUserId ||
        identityHashCode(user) != key.sessionInstanceId ||
        user.role != UserRole.platformOwner ||
        user.mustChangePassword) {
      _clearSessionState();

      return const PlatformInstitutionAdminListState.initial();
    }

    if (_sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId &&
        _institutionId == key.institutionId) {
      return state;
    }

    _sessionUserId = key.sessionUserId;
    _sessionInstanceId = key.sessionInstanceId;
    _institutionId = key.institutionId;
    _searchDebounce?.cancel();
    _inFlightQuery = null;
    _operationGeneration += 1;

    const initialQuery = PlatformInstitutionAdminListQuery.initial();
    scheduleMicrotask(() {
      if (!_isDisposed &&
          _sessionUserId == key.sessionUserId &&
          _sessionInstanceId == key.sessionInstanceId &&
          _institutionId == key.institutionId) {
        unawaited(
          _load(
            initialQuery,
            sessionUserId: key.sessionUserId,
            institutionId: key.institutionId,
          ),
        );
      }
    });

    return const PlatformInstitutionAdminListState.loading(
      query: initialQuery,
      searchText: '',
    );
  }

  void updateSearchText(String value) {
    final errorText =
        PlatformInstitutionAdminListQuery.isSearchInputValid(value)
        ? null
        : 'Search must be 254 characters or fewer.';

    _searchDebounce?.cancel();
    state = state.withSearchText(value, errorText: errorText);

    if (errorText != null) {
      return;
    }

    _searchDebounce = Timer(
      PlatformInstitutionAdminListQuery.searchDebounceDuration,
      commitSearchNow,
    );
  }

  void commitSearchNow() {
    _searchDebounce?.cancel();
    if (!PlatformInstitutionAdminListQuery.isSearchInputValid(
      state.searchText,
    )) {
      state = state.withSearchText(
        state.searchText,
        errorText: 'Search must be 254 characters or fewer.',
      );
      return;
    }

    final normalized = PlatformInstitutionAdminListQuery.normalizeSearch(
      state.searchText,
    );
    _commitQuery(state.query.withSearchInput(normalized));
  }

  void setStatus(PlatformInstitutionAdminStatus? status) {
    _commitQuery(state.query.withStatus(status));
  }

  void toggleSort(PlatformInstitutionAdminListSort sort) {
    _commitQuery(state.query.withSort(sort));
  }

  void setPerPage(int perPage) {
    _commitQuery(state.query.withPageSize(perPage));
  }

  void previousPage() {
    if (!state.canGoPrevious) {
      return;
    }

    _commitQuery(state.query.withPage(state.query.page - 1));
  }

  void nextPage() {
    if (!state.canGoNext) {
      return;
    }

    _commitQuery(state.query.withPage(state.query.page + 1));
  }

  void returnToFirstPage() {
    if (state.query.page == PlatformInstitutionAdminListQuery.initialPage) {
      return;
    }

    _commitQuery(
      state.query.withPage(PlatformInstitutionAdminListQuery.initialPage),
    );
  }

  void reset() {
    const initialQuery = PlatformInstitutionAdminListQuery.initial();
    _searchDebounce?.cancel();
    state = state.withSearchText('');
    _commitQuery(initialQuery, searchText: '');
  }

  Future<void> retry() async {
    if (state.status != PlatformInstitutionAdminListStatus.error ||
        state.isRetryInFlight) {
      return;
    }

    final sessionUserId = _sessionUserId;
    final institutionId = _institutionId;
    if (sessionUserId == null || institutionId == null) {
      return;
    }

    state = state.retrying();
    await _load(
      state.query,
      sessionUserId: sessionUserId,
      institutionId: institutionId,
      isRetry: true,
    );
  }

  Future<void> refreshAfterMutation() {
    final sessionUserId = _sessionUserId;
    final institutionId = _institutionId;
    if (sessionUserId == null || institutionId == null) {
      return Future<void>.value();
    }

    final query = state.query;
    state = PlatformInstitutionAdminListState.queryLoading(
      query: query,
      searchText: state.searchText,
    );

    return _load(
      query,
      sessionUserId: sessionUserId,
      institutionId: institutionId,
    );
  }

  void _commitQuery(
    PlatformInstitutionAdminListQuery query, {
    String? searchText,
  }) {
    if (query == state.query) {
      if (searchText != null && searchText != state.searchText) {
        state = state.withSearchText(searchText);
      }
      return;
    }

    final sessionUserId = _sessionUserId;
    final institutionId = _institutionId;
    if (sessionUserId == null || institutionId == null) {
      return;
    }

    final nextSearchText = searchText ?? state.searchText;
    state = PlatformInstitutionAdminListState.queryLoading(
      query: query,
      searchText: nextSearchText,
    );
    unawaited(
      _load(query, sessionUserId: sessionUserId, institutionId: institutionId),
    );
  }

  Future<void> _load(
    PlatformInstitutionAdminListQuery query, {
    required String sessionUserId,
    required String institutionId,
    bool isRetry = false,
  }) async {
    if (!isRetry && state.isRequestInFlight && _inFlightQuery == query) {
      return;
    }

    final generation = _beginOperation(query);
    final repository = ref.read(platformInstitutionAdminRepositoryProvider);

    try {
      final result = await repository.fetchAdmins(
        institutionId: institutionId,
        query: query,
      );
      if (!_canComplete(generation, sessionUserId, institutionId, query)) {
        return;
      }

      state = PlatformInstitutionAdminListState.fromResult(
        query: query,
        searchText: state.searchText,
        result: result,
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, sessionUserId, institutionId, query)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      state = PlatformInstitutionAdminListState.error(
        query: query,
        searchText: state.searchText,
        failure: exception.failure,
      );
    } finally {
      if (_inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  int _beginOperation(PlatformInstitutionAdminListQuery query) {
    _operationGeneration += 1;
    _inFlightQuery = query;

    return _operationGeneration;
  }

  bool _canComplete(
    int generation,
    String sessionUserId,
    String institutionId,
    PlatformInstitutionAdminListQuery query,
  ) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        sessionUserId == _sessionUserId &&
        institutionId == _institutionId &&
        query == state.query;
  }

  void _clearSessionState() {
    _sessionUserId = null;
    _sessionInstanceId = null;
    _institutionId = null;
    _inFlightQuery = null;
    _searchDebounce?.cancel();
    _operationGeneration += 1;
  }

  void _reconcileSessionForFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }
}
