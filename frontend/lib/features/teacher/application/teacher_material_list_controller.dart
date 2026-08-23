import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_learning_material_repository_impl.dart';
import '../domain/teacher_learning_material.dart';
import '../domain/teacher_topic.dart';
import 'teacher_material_list_state.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_controller.dart';
import 'teacher_topic_detail_state.dart';

final teacherMaterialListControllerProvider = NotifierProvider.autoDispose
    .family<TeacherMaterialListController, TeacherMaterialListState, String>(
      TeacherMaterialListController.new,
    );

class TeacherMaterialListController extends Notifier<TeacherMaterialListState> {
  TeacherMaterialListController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  int _generation = 0;
  var _disposeRegistered = false;

  @override
  TeacherMaterialListState build() {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() => _generation += 1);
    }
    final key = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(teacherTopicDetailControllerProvider(topicId));
    final ownsReadableTopic =
        detail.topic != null &&
        (detail.status == TeacherTopicDetailStatus.data ||
            detail.status == TeacherTopicDetailStatus.refreshing);
    if (!isCanonicalTeacherTopicId(topicId) ||
        key == null ||
        key.surface != AppDeviceSurface.desktop ||
        !ownsReadableTopic) {
      _clearOwnership();
      return const TeacherMaterialListState();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    scheduleMicrotask(() => _load(key, retainCollection: false));
    return const TeacherMaterialListState(
      status: TeacherMaterialListStatus.loading,
    );
  }

  Future<TeacherLearningMaterialCollection?> refreshAuthoritative() async {
    final key = _activeSessionKey;
    if (key == null || state.isLoading || !_matchesSession(key)) {
      return null;
    }
    return _load(key, retainCollection: state.collection != null);
  }

  void refresh() {
    unawaited(refreshAuthoritative());
  }

  void markStale() {
    final collection = state.collection;
    if (collection == null) {
      return;
    }
    state = TeacherMaterialListState(
      status: TeacherMaterialListStatus.data,
      collection: collection,
      failure: state.failure,
      isStale: true,
    );
  }

  Future<TeacherLearningMaterialCollection?> _load(
    TeacherSessionKey key, {
    required bool retainCollection,
  }) async {
    final generation = ++_generation;
    final retained = retainCollection ? state.collection : null;
    state = TeacherMaterialListState(
      status: retained == null
          ? TeacherMaterialListStatus.loading
          : TeacherMaterialListStatus.refreshing,
      collection: retained,
      isStale: retained != null,
    );
    try {
      final collection = await ref
          .read(teacherLearningMaterialRepositoryProvider)
          .fetchMaterials(topicId);
      if (!_canPublish(generation, key)) {
        return null;
      }
      state = TeacherMaterialListState(
        status: TeacherMaterialListStatus.data,
        collection: collection,
      );
      return collection;
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key)) {
        return null;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return null;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        ref
            .read(teacherTopicDetailControllerProvider(topicId).notifier)
            .markNotFound();
        _clearOwnership();
        state = const TeacherMaterialListState();
        return null;
      }
      _publishFailure(exception.failure, retained);
      return null;
    } catch (_) {
      if (_canPublish(generation, key)) {
        _publishFailure(
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher Material list failure.',
          ),
          retained,
        );
      }
      return null;
    }
  }

  void _publishFailure(
    ApiFailure failure,
    TeacherLearningMaterialCollection? retained,
  ) {
    state = TeacherMaterialListState(
      status: retained == null
          ? TeacherMaterialListStatus.error
          : TeacherMaterialListStatus.data,
      collection: retained,
      failure: failure,
      isStale: retained != null,
    );
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
    state = const TeacherMaterialListState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  bool _canPublish(int generation, TeacherSessionKey key) {
    return ref.mounted &&
        generation == _generation &&
        _activeSessionKey == key &&
        _matchesSession(key);
  }

  bool _matchesSession(TeacherSessionKey key) {
    if (!ref.mounted || _activeSessionKey != key) {
      return false;
    }
    final detail = ref.read(teacherTopicDetailControllerProvider(topicId));
    return detail.topic?.id.toLowerCase() == topicId.toLowerCase() &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key &&
        key.surface == AppDeviceSurface.desktop;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _generation += 1;
  }
}
