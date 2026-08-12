import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_institution_list_repository_impl.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_list_query.dart';
import 'platform_institution_list_state.dart';

final platformInstitutionListControllerProvider =
    NotifierProvider.autoDispose<
      PlatformInstitutionListController,
      PlatformInstitutionListState
    >(PlatformInstitutionListController.new);

final platformInstitutionListRetainedQueryProvider =
    Provider<PlatformInstitutionListRetainedQueryStore>((ref) {
      return PlatformInstitutionListRetainedQueryStore();
    });

class PlatformInstitutionListController
    extends Notifier<PlatformInstitutionListState> {
  String? _sessionUserId;
  int? _sessionInstanceId;
  PlatformInstitutionListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformInstitutionListState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _searchDebounce?.cancel();
      _operationGeneration += 1;
    });

    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;

    if (session.status != AuthSessionStatus.authenticated ||
        user == null ||
        user.role != UserRole.platformOwner ||
        user.mustChangePassword) {
      _clearSessionState();

      return const PlatformInstitutionListState.initial();
    }

    final sessionInstanceId = identityHashCode(user);
    if (_sessionUserId == user.id && _sessionInstanceId == sessionInstanceId) {
      return state;
    }

    _sessionUserId = user.id;
    _sessionInstanceId = sessionInstanceId;
    _searchDebounce?.cancel();
    _inFlightQuery = null;
    _operationGeneration += 1;

    final retained = ref
        .read(platformInstitutionListRetainedQueryProvider)
        .value;
    final initialQuery = retained?.matches(user.id, sessionInstanceId) ?? false
        ? retained!.query
        : const PlatformInstitutionListQuery.initial();
    final initialSearchText =
        retained?.matches(user.id, sessionInstanceId) ?? false
        ? retained!.searchText
        : initialQuery.search ?? '';
    scheduleMicrotask(() {
      if (!_isDisposed &&
          _sessionUserId == user.id &&
          _sessionInstanceId == sessionInstanceId) {
        unawaited(_load(initialQuery, sessionUserId: user.id));
      }
    });

    return PlatformInstitutionListState.loading(
      query: initialQuery,
      searchText: initialSearchText,
    );
  }

  void updateSearchText(String value) {
    final errorText = PlatformInstitutionListQuery.isSearchInputValid(value)
        ? null
        : 'Search must be 200 characters or fewer.';

    _searchDebounce?.cancel();
    state = state.withSearchText(value, errorText: errorText);
    _rememberListQuery();

    if (errorText != null) {
      return;
    }

    _searchDebounce = Timer(
      PlatformInstitutionListQuery.searchDebounceDuration,
      commitSearchNow,
    );
  }

  void commitSearchNow() {
    _searchDebounce?.cancel();
    if (!PlatformInstitutionListQuery.isSearchInputValid(state.searchText)) {
      state = state.withSearchText(
        state.searchText,
        errorText: 'Search must be 200 characters or fewer.',
      );
      return;
    }

    final normalized = PlatformInstitutionListQuery.normalizeSearch(
      state.searchText,
    );
    _commitQuery(state.query.withSearch(normalized));
  }

  void setStatus(PlatformInstitutionStatus? status) {
    _commitQuery(state.query.withStatus(status));
  }

  void setType(PlatformInstitutionType? type) {
    _commitQuery(state.query.withType(type));
  }

  void toggleSort(PlatformInstitutionListSort sort) {
    _commitQuery(state.query.withSort(sort));
  }

  void setPerPage(int perPage) {
    _commitQuery(state.query.withPerPage(perPage));
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
    if (state.query.page == PlatformInstitutionListQuery.initialPage) {
      return;
    }

    _commitQuery(
      state.query.withPage(PlatformInstitutionListQuery.initialPage),
    );
  }

  void reset() {
    const initialQuery = PlatformInstitutionListQuery.initial();
    _searchDebounce?.cancel();
    state = state.withSearchText('');
    _commitQuery(initialQuery, searchText: '');
  }

  Future<void> retry() async {
    if (state.status != PlatformInstitutionListStatus.error ||
        state.isRetryInFlight) {
      return;
    }

    final sessionUserId = _sessionUserId;
    if (sessionUserId == null) {
      return;
    }

    state = state.retrying();
    await _load(state.query, sessionUserId: sessionUserId, isRetry: true);
  }

  void _commitQuery(PlatformInstitutionListQuery query, {String? searchText}) {
    if (query == state.query) {
      if (searchText != null && searchText != state.searchText) {
        state = state.withSearchText(searchText);
        _rememberListQuery();
      }
      return;
    }

    final sessionUserId = _sessionUserId;
    if (sessionUserId == null) {
      return;
    }

    final nextSearchText = searchText ?? state.searchText;
    state = PlatformInstitutionListState.queryLoading(
      query: query,
      searchText: nextSearchText,
    );
    _rememberListQuery();
    unawaited(_load(query, sessionUserId: sessionUserId));
  }

  Future<void> _load(
    PlatformInstitutionListQuery query, {
    required String sessionUserId,
    bool isRetry = false,
  }) async {
    if (!isRetry && state.isRequestInFlight && _inFlightQuery == query) {
      return;
    }

    final generation = _beginOperation(query);
    final repository = ref.read(platformInstitutionListRepositoryProvider);

    try {
      final result = await repository.fetchInstitutions(query);
      if (!_canComplete(generation, sessionUserId, query)) {
        return;
      }

      state = PlatformInstitutionListState.fromResult(
        query: query,
        searchText: state.searchText,
        result: result,
      );
      _rememberListQuery();
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, sessionUserId, query)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      state = PlatformInstitutionListState.error(
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

  int _beginOperation(PlatformInstitutionListQuery query) {
    _operationGeneration += 1;
    _inFlightQuery = query;

    return _operationGeneration;
  }

  bool _canComplete(
    int generation,
    String sessionUserId,
    PlatformInstitutionListQuery query,
  ) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        sessionUserId == _sessionUserId &&
        query == state.query;
  }

  void _clearSessionState() {
    ref
        .read(platformInstitutionListRetainedQueryProvider)
        .clearIfMatches(_sessionUserId, _sessionInstanceId);
    _sessionUserId = null;
    _sessionInstanceId = null;
    _inFlightQuery = null;
    _searchDebounce?.cancel();
    _operationGeneration += 1;
  }

  void _rememberListQuery() {
    final sessionUserId = _sessionUserId;
    final sessionInstanceId = _sessionInstanceId;
    if (sessionUserId == null || sessionInstanceId == null) {
      return;
    }

    ref
        .read(platformInstitutionListRetainedQueryProvider)
        .value = PlatformInstitutionListRetainedQuery(
      sessionUserId: sessionUserId,
      sessionInstanceId: sessionInstanceId,
      query: state.query,
      searchText: state.searchText,
    );
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

class PlatformInstitutionListRetainedQueryStore {
  PlatformInstitutionListRetainedQuery? value;

  void clearIfMatches(String? userId, int? userInstanceId) {
    final retained = value;
    if (retained != null &&
        userId != null &&
        userInstanceId != null &&
        retained.matches(userId, userInstanceId)) {
      value = null;
    }
  }
}

class PlatformInstitutionListRetainedQuery {
  const PlatformInstitutionListRetainedQuery({
    required this.sessionUserId,
    required this.sessionInstanceId,
    required this.query,
    required this.searchText,
  });

  final String sessionUserId;
  final int sessionInstanceId;
  final PlatformInstitutionListQuery query;
  final String searchText;

  bool matches(String userId, int userInstanceId) {
    return sessionUserId == userId && sessionInstanceId == userInstanceId;
  }
}
