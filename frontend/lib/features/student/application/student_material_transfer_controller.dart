import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/files/local_file_actions.dart';
import '../../../core/files/protected_learning_material_transfer.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/student_topic.dart';
import 'student_material_transfer_state.dart';
import 'student_session_key.dart';
import 'student_topic_detail_controller.dart';
import 'student_topic_detail_state.dart';

final studentMaterialTransferControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentMaterialTransferController,
      StudentMaterialTransferState,
      String
    >(StudentMaterialTransferController.new);

class StudentMaterialTransferController
    extends Notifier<StudentMaterialTransferState> {
  StudentMaterialTransferController(this.topicId);

  final String topicId;
  StudentSessionKey? _activeSessionKey;
  StudentMaterialTransferAction? _activeAction;
  String? _activeMaterialId;
  String? _activeFileId;
  int _operationGeneration = 0;

  @override
  StudentMaterialTransferState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!isCanonicalStudentTopicId(topicId) || key == null) {
      _clearSession();
      return const StudentMaterialTransferState();
    }
    if (_activeSessionKey == key) {
      return state;
    }
    _clearSession();
    _activeSessionKey = key;
    return const StudentMaterialTransferState();
  }

  Future<void> saveAs(StudentLearningMaterial material) {
    return _transfer(material, StudentMaterialTransferAction.saveAs);
  }

  Future<void> open(StudentLearningMaterial material) {
    return _transfer(material, StudentMaterialTransferAction.open);
  }

  void consumeFeedback() {
    if (state.feedback != null) {
      state = state.copyWith(feedback: null);
    }
  }

  Future<void> _transfer(
    StudentLearningMaterial material,
    StudentMaterialTransferAction action,
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
      if (!_canPublish(owner)) {
        return;
      }
      final localActions = ref.read(localFileActionsProvider);
      switch (action) {
        case StudentMaterialTransferAction.saveAs:
          state = state.copyWith(status: StudentMaterialTransferStatus.saving);
          final saved = await localActions.saveAs(downloaded);
          if (!_canPublish(owner)) {
            return;
          }
          _clearActive();
          state = saved
              ? const StudentMaterialTransferState(
                  feedback: 'Learning material saved.',
                )
              : const StudentMaterialTransferState();
        case StudentMaterialTransferAction.open:
          state = state.copyWith(status: StudentMaterialTransferStatus.opening);
          final outcome = await localActions.open(material.file.id, downloaded);
          if (!_canPublish(owner)) {
            return;
          }
          _clearActive();
          state = outcome == LocalFileOpenOutcome.opened
              ? const StudentMaterialTransferState()
              : const StudentMaterialTransferState(
                  status: StudentMaterialTransferStatus.failure,
                  feedback:
                      'No application is available to open this file. Save the file instead.',
                );
      }
    } on ApiRequestException catch (exception) {
      if (_canPublishRoute(owner)) {
        await _publishFailure(owner, exception.failure);
      }
    } catch (_) {
      if (_canPublishRoute(owner)) {
        _clearActive();
        state = const StudentMaterialTransferState(
          status: StudentMaterialTransferStatus.failure,
          feedback: 'The learning material could not be downloaded.',
        );
      }
    }
  }

  _TransferOwner? _begin(
    StudentLearningMaterial material,
    StudentMaterialTransferAction action,
  ) {
    final key = _activeSessionKey;
    if (state.isBusy ||
        key == null ||
        !_matchesSession(key) ||
        !_targetIsCurrent(material.id, material.file.id)) {
      return null;
    }
    final generation = ++_operationGeneration;
    _activeAction = action;
    _activeMaterialId = material.id;
    _activeFileId = material.file.id;
    state = StudentMaterialTransferState(
      status: StudentMaterialTransferStatus.downloading,
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
          .read(studentTopicDetailControllerProvider(topicId).notifier)
          .refreshForMaterialReconciliation();
      if (!_canPublishRoute(owner)) {
        return;
      }
      final detail = ref.read(studentTopicDetailControllerProvider(topicId));
      if (detail.status == StudentTopicDetailStatus.notFound) {
        _clearActive();
        state = const StudentMaterialTransferState();
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
      _ when failure.kind == ApiFailureKind.connection =>
        'The download could not connect. Try again.',
      _ => 'The learning material could not be downloaded.',
    };
    _clearActive();
    state = StudentMaterialTransferState(
      status: StudentMaterialTransferStatus.failure,
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
    state = const StudentMaterialTransferState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  bool _canPublish(_TransferOwner owner) {
    return _canPublishRoute(owner) &&
        _targetIsCurrent(owner.materialId, owner.fileId);
  }

  bool _canPublishRoute(_TransferOwner owner) {
    return ref.mounted &&
        owner.generation == _operationGeneration &&
        owner.action == _activeAction &&
        owner.materialId == _activeMaterialId &&
        owner.fileId == _activeFileId &&
        _matchesSession(owner.key);
  }

  bool _matchesSession(StudentSessionKey key) {
    if (!ref.mounted || _activeSessionKey != key) {
      return false;
    }
    final surface = key.surface;
    if (surface != AppDeviceSurface.desktop &&
        surface != AppDeviceSurface.mobile) {
      return false;
    }
    return StudentSessionSnapshot.fromSession(
          ref.read(authSessionControllerProvider),
          ref.read(appDeviceSurfaceProvider),
        ).eligibleKey ==
        key;
  }

  bool _targetIsCurrent(String materialId, String fileId) {
    final material = ref
        .read(studentTopicDetailControllerProvider(topicId))
        .topic
        ?.materialById(materialId);
    return material?.file.id.toLowerCase() == fileId.toLowerCase();
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

  final StudentSessionKey key;
  final int generation;
  final StudentMaterialTransferAction action;
  final String materialId;
  final String fileId;
}
