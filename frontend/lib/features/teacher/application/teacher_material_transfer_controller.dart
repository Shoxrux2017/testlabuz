import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/files/local_file_actions.dart';
import '../../../core/files/protected_learning_material_transfer.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/teacher_learning_material.dart';
import '../domain/teacher_topic.dart';
import 'teacher_material_list_controller.dart';
import 'teacher_material_mutation_activity.dart';
import 'teacher_material_transfer_state.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_controller.dart';

final teacherMaterialTransferControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherMaterialTransferController,
      TeacherMaterialTransferState,
      String
    >(TeacherMaterialTransferController.new);

class TeacherMaterialTransferController
    extends Notifier<TeacherMaterialTransferState> {
  TeacherMaterialTransferController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherMaterialTransferAction? _activeAction;
  String? _activeMaterialId;
  String? _activeFileId;
  int _operationGeneration = 0;

  @override
  TeacherMaterialTransferState build() {
    final key = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!isCanonicalTeacherTopicId(topicId) ||
        key == null ||
        key.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherMaterialTransferState();
    }
    if (_activeSessionKey == key) {
      return state;
    }
    _clearSession();
    _activeSessionKey = key;
    return const TeacherMaterialTransferState();
  }

  Future<void> saveAs(TeacherLearningMaterial material) {
    return _transfer(material, TeacherMaterialTransferAction.saveAs);
  }

  Future<void> open(TeacherLearningMaterial material) {
    return _transfer(material, TeacherMaterialTransferAction.open);
  }

  bool isBusyForMaterial(String materialId) {
    return state.isBusyForMaterial(materialId);
  }

  void consumeFeedback() {
    if (state.feedback != null) {
      state = state.copyWith(feedback: null);
    }
  }

  Future<void> _transfer(
    TeacherLearningMaterial material,
    TeacherMaterialTransferAction action,
  ) async {
    final owner = _begin(material, action);
    if (owner == null) {
      return;
    }
    try {
      final downloaded = await ref
          .read(protectedLearningMaterialTransferProvider)
          .download(
            material.file.id,
            onReceiveProgress: (received, total) {
              if (_canPublish(owner)) {
                state = state.copyWith(
                  receivedBytes: received,
                  totalBytes: total,
                );
              }
            },
          );
      if (!_canPublish(owner) || _targetMutationBlocks(owner.materialId)) {
        return;
      }
      final localActions = ref.read(localFileActionsProvider);
      switch (action) {
        case TeacherMaterialTransferAction.saveAs:
          state = state.copyWith(status: TeacherMaterialTransferStatus.saving);
          final saved = await localActions.saveAs(downloaded);
          if (!_canPublish(owner)) {
            return;
          }
          _clearActive();
          state = saved
              ? const TeacherMaterialTransferState(
                  feedback: 'Learning material saved.',
                )
              : const TeacherMaterialTransferState();
        case TeacherMaterialTransferAction.open:
          state = state.copyWith(status: TeacherMaterialTransferStatus.opening);
          final outcome = await localActions.open(material.file.id, downloaded);
          if (!_canPublish(owner)) {
            return;
          }
          _clearActive();
          state = outcome == LocalFileOpenOutcome.opened
              ? const TeacherMaterialTransferState()
              : const TeacherMaterialTransferState(
                  status: TeacherMaterialTransferStatus.failure,
                  feedback:
                      'No application is available to open this file. Save the file instead.',
                );
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(owner)) {
        return;
      }
      await _publishFailure(owner, exception.failure);
    } catch (_) {
      if (_canPublish(owner)) {
        _clearActive();
        state = const TeacherMaterialTransferState(
          status: TeacherMaterialTransferStatus.failure,
          feedback: 'The learning material could not be downloaded.',
        );
      }
    }
  }

  _TransferOwner? _begin(
    TeacherLearningMaterial material,
    TeacherMaterialTransferAction action,
  ) {
    final key = _activeSessionKey;
    if (state.isBusy ||
        key == null ||
        !_matchesSession(key) ||
        !_targetIsCurrent(material.id, material.file.id) ||
        _targetMutationBlocks(material.id)) {
      return null;
    }
    final generation = ++_operationGeneration;
    _activeAction = action;
    _activeMaterialId = material.id;
    _activeFileId = material.file.id;
    state = TeacherMaterialTransferState(
      status: TeacherMaterialTransferStatus.downloading,
      action: action,
      materialId: material.id,
      fileId: material.file.id,
    );
    return _TransferOwner(
      key: key,
      generation: generation,
      action: action,
      materialId: material.id,
      fileId: material.file.id,
    );
  }

  Future<void> _publishFailure(_TransferOwner owner, ApiFailure failure) async {
    if (_clearForSessionFailure(failure)) {
      return;
    }
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      await ref
          .read(teacherMaterialListControllerProvider(topicId).notifier)
          .refreshAuthoritative();
      if (!_canPublish(owner)) {
        return;
      }
    }
    final feedback = switch (failure.serverCode) {
      ApiErrorCodes.resourceNotFound =>
        'This learning material is no longer available.',
      ApiErrorCodes.fileNotAvailable =>
        'The file is temporarily unavailable. Try again.',
      _ when failure.kind == ApiFailureKind.invalidResponse =>
        'The server returned an unexpected file response.',
      _ when failure.kind == ApiFailureKind.timeout =>
        'The download timed out. Try again.',
      _ => 'The learning material could not be downloaded.',
    };
    _clearActive();
    state = TeacherMaterialTransferState(
      status: TeacherMaterialTransferStatus.failure,
      feedback: feedback,
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
    _clearSession();
    state = const TeacherMaterialTransferState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  bool _canPublish(_TransferOwner owner) {
    return ref.mounted &&
        owner.generation == _operationGeneration &&
        owner.action == _activeAction &&
        owner.materialId == _activeMaterialId &&
        owner.fileId == _activeFileId &&
        _matchesSession(owner.key) &&
        _targetIsCurrent(owner.materialId, owner.fileId);
  }

  bool _matchesSession(TeacherSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        key.surface == AppDeviceSurface.desktop &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key &&
        ref
                .read(teacherTopicDetailControllerProvider(topicId))
                .topic
                ?.id
                .toLowerCase() ==
            topicId.toLowerCase();
  }

  bool _targetIsCurrent(String materialId, String fileId) {
    final current = ref
        .read(teacherMaterialListControllerProvider(topicId))
        .collection
        ?.materialById(materialId);
    return current?.file.id.toLowerCase() == fileId.toLowerCase();
  }

  bool _targetMutationBlocks(String materialId) {
    return ref
        .read(teacherMaterialMutationActivityProvider(topicId))
        .blocksTransfer(materialId, _activeSessionKey);
  }

  void _clearActive() {
    _activeAction = null;
    _activeMaterialId = null;
    _activeFileId = null;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _operationGeneration += 1;
    _clearActive();
  }
}

class _TransferOwner {
  const _TransferOwner({
    required this.key,
    required this.generation,
    required this.action,
    required this.materialId,
    required this.fileId,
  });

  final TeacherSessionKey key;
  final int generation;
  final TeacherMaterialTransferAction action;
  final String materialId;
  final String fileId;
}
