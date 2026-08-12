import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_institution_detail_repository_impl.dart';
import 'platform_institution_detail_state.dart';

final platformInstitutionDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      PlatformInstitutionDetailController,
      PlatformInstitutionDetailState,
      PlatformInstitutionDetailKey
    >((key) => PlatformInstitutionDetailController(key));

class PlatformInstitutionDetailController
    extends Notifier<PlatformInstitutionDetailState> {
  PlatformInstitutionDetailController(this.key);

  final PlatformInstitutionDetailKey key;

  String? _sessionUserId;
  int? _sessionInstanceId;
  String? _inFlightInstitutionId;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformInstitutionDetailState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _operationGeneration += 1;
      _inFlightInstitutionId = null;
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

      return const PlatformInstitutionDetailState.initial();
    }

    if (_sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId) {
      return state;
    }

    _sessionUserId = key.sessionUserId;
    _sessionInstanceId = key.sessionInstanceId;
    _operationGeneration += 1;
    _inFlightInstitutionId = null;

    scheduleMicrotask(() {
      if (!_isDisposed &&
          _sessionUserId == key.sessionUserId &&
          _sessionInstanceId == key.sessionInstanceId) {
        unawaited(_loadForKey());
      }
    });

    return const PlatformInstitutionDetailState.loading();
  }

  Future<void> retry() async {
    if (state.status != PlatformInstitutionDetailStatus.error ||
        state.isRetryInFlight) {
      return;
    }

    if (_sessionUserId == null) {
      return;
    }

    state = state.retrying();
    await _loadForKey(isRetry: true);
  }

  Future<void> refreshAfterMutation() async {
    if (_sessionUserId == null || state.isRequestInFlight) {
      return;
    }

    state = const PlatformInstitutionDetailState.loading();
    await _loadForKey();
  }

  Future<void> refreshVisibleAfterRelatedMutation() async {
    if (_sessionUserId == null ||
        state.status != PlatformInstitutionDetailStatus.data ||
        _inFlightInstitutionId == key.institutionId) {
      return;
    }

    await _loadForKey();
  }

  Future<void> _loadForKey({bool isRetry = false}) async {
    if (!isRetry &&
        state.isRequestInFlight &&
        _inFlightInstitutionId == key.institutionId) {
      return;
    }

    final generation = _beginOperation();
    final repository = ref.read(platformInstitutionDetailRepositoryProvider);

    try {
      final detail = await repository.fetchInstitutionDetail(key.institutionId);
      if (!_canComplete(generation)) {
        return;
      }

      state = PlatformInstitutionDetailState.data(detail);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      if (_isResourceNotFound(exception.failure)) {
        state = const PlatformInstitutionDetailState.notFound();
      } else {
        state = PlatformInstitutionDetailState.error(exception.failure);
      }
    } finally {
      if (_inFlightInstitutionId == key.institutionId) {
        _inFlightInstitutionId = null;
      }
    }
  }

  int _beginOperation() {
    _operationGeneration += 1;
    _inFlightInstitutionId = key.institutionId;

    return _operationGeneration;
  }

  bool _canComplete(int generation) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        _sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId;
  }

  void _clearSessionState() {
    _sessionUserId = null;
    _sessionInstanceId = null;
    _inFlightInstitutionId = null;
    _operationGeneration += 1;
  }

  bool _isResourceNotFound(ApiFailure failure) {
    return failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound;
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
