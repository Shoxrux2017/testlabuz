import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_learning_material_repository_impl.dart';
import '../domain/teacher_learning_material.dart';
import '../domain/teacher_learning_material_mutation.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_mutation.dart';
import 'teacher_material_list_controller.dart';
import 'teacher_material_mutation_activity.dart';
import 'teacher_material_mutation_state.dart';
import 'teacher_material_transfer_controller.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_controller.dart';
import 'teacher_topic_lifecycle_controller.dart';

final teacherMaterialMutationControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherMaterialMutationController,
      TeacherMaterialMutationState,
      String
    >(TeacherMaterialMutationController.new);

class TeacherMaterialMutationController
    extends Notifier<TeacherMaterialMutationState> {
  TeacherMaterialMutationController(this.topicId);

  static const titleMaxLength = 255;

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherMaterialMutationOperation? _activeOperation;
  String? _activeMaterialId;
  String? _activeFileId;
  String? _pendingTitle;
  int _operationGeneration = 0;

  @override
  TeacherMaterialMutationState build() {
    final key = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    ref.watch(teacherMaterialMutationActivityProvider(topicId));
    if (!isCanonicalTeacherTopicId(topicId) ||
        key == null ||
        key.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return TeacherMaterialMutationState();
    }
    if (_activeSessionKey == key) {
      return state;
    }
    _clearSession();
    _activeSessionKey = key;
    return TeacherMaterialMutationState();
  }

  Future<bool> uploadMaterial({
    required TeacherMaterialUploadFile file,
    required String title,
  }) async {
    if (state.canCheckCurrent) {
      return false;
    }
    final capability = ref
        .read(teacherMaterialListControllerProvider(topicId))
        .collection
        ?.uploadCapability;
    final normalizedTitle = title.trim().isEmpty ? null : title.trim();
    final errors = _validateFile(file, capability);
    if (normalizedTitle != null &&
        normalizedTitle.runes.length > titleMaxLength) {
      errors['title'] = 'Title must be 255 characters or fewer.';
    }
    if (errors.isNotEmpty) {
      state = TeacherMaterialMutationState(
        status: TeacherMaterialMutationStatus.definiteFailure,
        operation: TeacherMaterialMutationOperation.upload,
        fieldErrors: errors,
      );
      return false;
    }
    final owner = _begin(
      TeacherMaterialMutationOperation.upload,
      TeacherMaterialMutationActivityKind.upload,
    );
    if (owner == null) {
      return false;
    }
    try {
      await ref
          .read(teacherLearningMaterialRepositoryProvider)
          .uploadMaterial(
            topicId: topicId,
            file: file,
            title: normalizedTitle,
            onProgress: (sent, total) => _publishProgress(owner, sent, total),
          );
      return await _confirmedMutation(owner, 'Learning material uploaded.');
    } on TeacherMaterialMutationOutcomeUnknownException {
      return _reconcileUnknown(owner);
    } on ApiRequestException catch (exception) {
      return _handleDefiniteFailure(owner, exception.failure);
    } catch (_) {
      return _reconcileUnknown(owner);
    } finally {
      _finishActivity(owner);
    }
  }

  Future<bool> replaceMaterialFile({
    required TeacherLearningMaterial current,
    required TeacherMaterialUploadFile file,
  }) async {
    if (state.canCheckCurrent) {
      return false;
    }
    final capability = ref
        .read(teacherMaterialListControllerProvider(topicId))
        .collection
        ?.uploadCapability;
    final errors = _validateFile(file, capability);
    if (errors.isNotEmpty) {
      state = TeacherMaterialMutationState(
        status: TeacherMaterialMutationStatus.definiteFailure,
        operation: TeacherMaterialMutationOperation.replace,
        materialId: current.id,
        fieldErrors: errors,
      );
      return false;
    }
    final owner = _begin(
      TeacherMaterialMutationOperation.replace,
      TeacherMaterialMutationActivityKind.replace,
      current: current,
      refuseWhileTargetTransfers: true,
    );
    if (owner == null) {
      return false;
    }
    try {
      await ref
          .read(teacherLearningMaterialRepositoryProvider)
          .replaceMaterialFile(
            topicId: topicId,
            current: current,
            file: file,
            onProgress: (sent, total) => _publishProgress(owner, sent, total),
          );
      return await _confirmedMutation(
        owner,
        'Learning material file replaced.',
      );
    } on TeacherMaterialMutationOutcomeUnknownException {
      return _reconcileUnknown(owner);
    } on ApiRequestException catch (exception) {
      return _handleDefiniteFailure(owner, exception.failure);
    } catch (_) {
      return _reconcileUnknown(owner);
    } finally {
      _finishActivity(owner);
    }
  }

  Future<bool> updateMaterialTitle({
    required TeacherLearningMaterial current,
    required String title,
    required bool useOriginalFileName,
  }) async {
    if (state.canCheckCurrent) {
      return false;
    }
    final normalizedTitle = useOriginalFileName ? null : title.trim();
    if (!useOriginalFileName && normalizedTitle!.isEmpty) {
      state = TeacherMaterialMutationState(
        status: TeacherMaterialMutationStatus.definiteFailure,
        operation: TeacherMaterialMutationOperation.updateTitle,
        materialId: current.id,
        fieldErrors: const {'title': 'Enter a title or use the original name.'},
      );
      return false;
    }
    if (normalizedTitle != null &&
        normalizedTitle.runes.length > titleMaxLength) {
      state = TeacherMaterialMutationState(
        status: TeacherMaterialMutationStatus.definiteFailure,
        operation: TeacherMaterialMutationOperation.updateTitle,
        materialId: current.id,
        fieldErrors: const {'title': 'Title must be 255 characters or fewer.'},
      );
      return false;
    }
    if (normalizedTitle == current.title) {
      state = TeacherMaterialMutationState(
        status: TeacherMaterialMutationStatus.noChanges,
        operation: TeacherMaterialMutationOperation.updateTitle,
        materialId: current.id,
        feedback: 'No changes to save.',
      );
      return false;
    }
    final owner = _begin(
      TeacherMaterialMutationOperation.updateTitle,
      TeacherMaterialMutationActivityKind.updateTitle,
      current: current,
      pendingTitle: normalizedTitle,
    );
    if (owner == null) {
      return false;
    }
    try {
      await ref
          .read(teacherLearningMaterialRepositoryProvider)
          .updateMaterialTitle(
            topicId: topicId,
            current: current,
            title: normalizedTitle,
          );
      return await _confirmedMutation(
        owner,
        'Learning material title updated.',
      );
    } on TeacherMaterialMutationOutcomeUnknownException {
      return _reconcileUnknown(owner);
    } on ApiRequestException catch (exception) {
      return _handleDefiniteFailure(owner, exception.failure);
    } catch (_) {
      return _reconcileUnknown(owner);
    } finally {
      _finishActivity(owner);
    }
  }

  Future<bool> removeMaterial(TeacherLearningMaterial current) async {
    if (state.canCheckCurrent) {
      return false;
    }
    final owner = _begin(
      TeacherMaterialMutationOperation.remove,
      TeacherMaterialMutationActivityKind.remove,
      current: current,
      refuseWhileTargetTransfers: true,
    );
    if (owner == null) {
      return false;
    }
    try {
      await ref
          .read(teacherLearningMaterialRepositoryProvider)
          .removeMaterial(topicId: topicId, current: current);
      return await _confirmedMutation(owner, 'Learning material removed.');
    } on TeacherMaterialMutationOutcomeUnknownException {
      return _reconcileUnknown(owner);
    } on ApiRequestException catch (exception) {
      return _handleDefiniteFailure(owner, exception.failure);
    } catch (_) {
      return _reconcileUnknown(owner);
    } finally {
      _finishActivity(owner);
    }
  }

  Future<void> checkCurrentMaterials() async {
    final key = _activeSessionKey;
    final operation = state.operation;
    if (!state.canCheckCurrent ||
        key == null ||
        operation == null ||
        !_matchesSession(key)) {
      return;
    }
    final owner = _MutationOwner(
      key: key,
      generation: ++_operationGeneration,
      activityGeneration: -1,
      operation: operation,
      materialId: _activeMaterialId,
      fileId: _activeFileId,
    );
    _activeOperation = operation;
    state = state.copyWith(
      status: TeacherMaterialMutationStatus.reconciling,
      feedback: null,
      fieldErrors: const {},
    );
    await _publishUnknownReconciliation(owner);
  }

  void consumeFeedback() {
    if (state.feedback != null) {
      state = state.copyWith(feedback: null);
    }
  }

  _MutationOwner? _begin(
    TeacherMaterialMutationOperation operation,
    TeacherMaterialMutationActivityKind activityKind, {
    TeacherLearningMaterial? current,
    String? pendingTitle,
    bool refuseWhileTargetTransfers = false,
  }) {
    final key = _activeSessionKey;
    final lifecycleBusy = ref
        .read(teacherTopicLifecycleControllerProvider(topicId))
        .isBusy;
    final activity = ref.read(teacherMaterialMutationActivityProvider(topicId));
    final transfer = ref.read(
      teacherMaterialTransferControllerProvider(topicId),
    );
    final currentTopic = ref
        .read(teacherTopicDetailControllerProvider(topicId))
        .topic;
    if (state.isBusy ||
        state.canCheckCurrent ||
        key == null ||
        lifecycleBusy ||
        activity.isActiveFor(key) ||
        currentTopic == null ||
        !teacherTopicCanEdit(currentTopic) ||
        !_matchesSession(key) ||
        !_targetIsCurrent(current) ||
        (refuseWhileTargetTransfers &&
            transfer.isBusyForMaterial(current!.id))) {
      return null;
    }
    final generation = ++_operationGeneration;
    _activeOperation = operation;
    _activeMaterialId = current?.id;
    _activeFileId = current?.file.id;
    _pendingTitle = pendingTitle;
    final activityGeneration = ref
        .read(teacherMaterialMutationActivityProvider(topicId).notifier)
        .activate(
          owner: key,
          kind: activityKind,
          materialId: current?.id,
          fileId: current?.file.id,
        );
    if (activityGeneration < 0) {
      _activeOperation = null;
      return null;
    }
    state = TeacherMaterialMutationState(
      status: TeacherMaterialMutationStatus.submitting,
      operation: operation,
      materialId: current?.id,
    );
    return _MutationOwner(
      key: key,
      generation: generation,
      activityGeneration: activityGeneration,
      operation: operation,
      materialId: current?.id,
      fileId: current?.file.id,
    );
  }

  void _publishProgress(_MutationOwner owner, int sent, int total) {
    if (!_canPublish(owner)) {
      return;
    }
    state = state.copyWith(sentBytes: sent, totalBytes: total);
  }

  Future<bool> _confirmedMutation(_MutationOwner owner, String feedback) async {
    if (!_canPublish(owner)) {
      return false;
    }
    state = state.copyWith(
      status: TeacherMaterialMutationStatus.reconciling,
      feedback: null,
    );
    ref
        .read(teacherMaterialListControllerProvider(topicId).notifier)
        .markStale();
    await ref
        .read(teacherMaterialListControllerProvider(topicId).notifier)
        .refreshAuthoritative();
    if (!_canPublish(owner)) {
      return false;
    }
    _activeOperation = null;
    state = state.copyWith(
      status: TeacherMaterialMutationStatus.confirmedSuccess,
      feedback: feedback,
      fieldErrors: const {},
    );
    return true;
  }

  Future<bool> _reconcileUnknown(_MutationOwner owner) async {
    if (!_canPublish(owner)) {
      return false;
    }
    state = state.copyWith(
      status: TeacherMaterialMutationStatus.reconciling,
      feedback: null,
    );
    return _publishUnknownReconciliation(owner);
  }

  Future<bool> _publishUnknownReconciliation(_MutationOwner owner) async {
    ref
        .read(teacherMaterialListControllerProvider(topicId).notifier)
        .markStale();
    final collection = await ref
        .read(teacherMaterialListControllerProvider(topicId).notifier)
        .refreshAuthoritative();
    if (!_canPublish(owner)) {
      return false;
    }
    if (collection == null) {
      state = state.copyWith(
        status: TeacherMaterialMutationStatus.outcomeUnknown,
        feedback: _unknownFeedback(owner.operation),
      );
      return false;
    }

    final current = owner.materialId == null
        ? null
        : collection.materialById(owner.materialId!);
    final reconciledSuccess = switch (owner.operation) {
      TeacherMaterialMutationOperation.updateTitle =>
        current != null && current.title == _pendingTitle,
      TeacherMaterialMutationOperation.remove => current == null,
      TeacherMaterialMutationOperation.upload ||
      TeacherMaterialMutationOperation.replace => false,
    };
    _activeOperation = null;
    if (reconciledSuccess) {
      state = state.copyWith(
        status: TeacherMaterialMutationStatus.confirmedSuccess,
        feedback: owner.operation == TeacherMaterialMutationOperation.remove
            ? 'Learning material removed.'
            : 'Learning material title updated.',
      );
      return true;
    }
    state = state.copyWith(
      status: TeacherMaterialMutationStatus.unconfirmedCurrentState,
      feedback: _unknownFeedback(owner.operation),
    );
    return false;
  }

  Future<bool> _handleDefiniteFailure(
    _MutationOwner owner,
    ApiFailure failure,
  ) async {
    if (!_canPublish(owner)) {
      return false;
    }
    if (_clearForSessionFailure(failure)) {
      return false;
    }
    if (failure.statusCode == 409 &&
        failure.serverCode == ApiErrorCodes.topicNotEditable) {
      state = state.copyWith(
        status: TeacherMaterialMutationStatus.reconciling,
        feedback: null,
      );
      final topic = await ref
          .read(teacherTopicDetailControllerProvider(topicId).notifier)
          .refreshForMaterialReconciliation();
      if (!_canPublish(owner)) {
        return false;
      }
      if (topic == null) {
        _activeOperation = null;
        state = TeacherMaterialMutationState();
        return false;
      }
      await ref
          .read(teacherMaterialListControllerProvider(topicId).notifier)
          .refreshAuthoritative();
      if (!_canPublish(owner)) {
        return false;
      }
      _activeOperation = null;
      state = state.copyWith(
        status: TeacherMaterialMutationStatus.notEditable,
        feedback:
            'Learning materials are no longer editable in the current Topic state.',
      );
      return false;
    }
    if (failure.serverCode == ApiErrorCodes.fileTooLarge ||
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      await ref
          .read(teacherMaterialListControllerProvider(topicId).notifier)
          .refreshAuthoritative();
      if (!_canPublish(owner)) {
        return false;
      }
    }
    _activeOperation = null;
    state = state.copyWith(
      status: TeacherMaterialMutationStatus.definiteFailure,
      feedback: _safeFailureMessage(failure),
      fieldErrors: _safeFieldErrors(failure),
    );
    return false;
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
    state = TeacherMaterialMutationState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  Map<String, String> _validateFile(
    TeacherMaterialUploadFile file,
    TeacherMaterialUploadCapability? capability,
  ) {
    if (capability == null) {
      return const {'form': 'Check current materials before uploading.'};
    }
    if (file.length < 1) {
      return const {'file': 'Select a non-empty file.'};
    }
    if (file.length > capability.maxSizeBytes) {
      return const {
        'file': 'The selected file exceeds the current allowed size.',
      };
    }
    final extension = file.extension;
    if (extension == null ||
        !capability.allowedExtensions.contains(extension)) {
      return const {
        'file':
            'The selected file is not a valid supported PDF, DOCX, PPT or PPTX file.',
      };
    }
    return <String, String>{};
  }

  bool _targetIsCurrent(TeacherLearningMaterial? material) {
    if (material == null) {
      return true;
    }
    final current = ref
        .read(teacherMaterialListControllerProvider(topicId))
        .collection
        ?.materialById(material.id);
    return current?.file.id.toLowerCase() == material.file.id.toLowerCase();
  }

  bool _canPublish(_MutationOwner owner) {
    return ref.mounted &&
        owner.generation == _operationGeneration &&
        owner.operation == _activeOperation &&
        owner.materialId == _activeMaterialId &&
        owner.fileId == _activeFileId &&
        _matchesSession(owner.key);
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

  void _finishActivity(_MutationOwner owner) {
    if (!ref.mounted || owner.activityGeneration < 0) {
      return;
    }
    ref
        .read(teacherMaterialMutationActivityProvider(topicId).notifier)
        .clear(owner.activityGeneration);
  }

  void _clearSession() {
    _activeSessionKey = null;
    _operationGeneration += 1;
    _activeOperation = null;
    _activeMaterialId = null;
    _activeFileId = null;
    _pendingTitle = null;
  }
}

class _MutationOwner {
  const _MutationOwner({
    required this.key,
    required this.generation,
    required this.activityGeneration,
    required this.operation,
    required this.materialId,
    required this.fileId,
  });

  final TeacherSessionKey key;
  final int generation;
  final int activityGeneration;
  final TeacherMaterialMutationOperation operation;
  final String? materialId;
  final String? fileId;
}

String _unknownFeedback(TeacherMaterialMutationOperation operation) {
  return switch (operation) {
    TeacherMaterialMutationOperation.upload =>
      'Upload outcome could not be confirmed. Review the current materials before uploading again.',
    TeacherMaterialMutationOperation.replace =>
      'Replacement outcome could not be confirmed. Review the current material before replacing it again.',
    TeacherMaterialMutationOperation.updateTitle =>
      'Title update outcome could not be confirmed.',
    TeacherMaterialMutationOperation.remove =>
      'Removal outcome could not be confirmed. Review the current materials.',
  };
}

String _safeFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.unsupportedFileType =>
      'The selected file is not a valid supported PDF, DOCX, PPT or PPTX file.',
    ApiErrorCodes.fileTooLarge =>
      'The selected file exceeds the current allowed size.',
    ApiErrorCodes.fileUploadFailed =>
      'The file could not be uploaded. No successful upload was confirmed.',
    ApiErrorCodes.resourceNotFound =>
      'This learning material is no longer available.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to change this learning material.',
    ApiErrorCodes.rateLimited => 'Too many requests. Wait before trying again.',
    _ => 'The learning material action could not be completed.',
  };
}

Map<String, String> _safeFieldErrors(ApiFailure failure) {
  if (failure.serverCode == ApiErrorCodes.unsupportedFileType) {
    return const {
      'file':
          'The selected file is not a valid supported PDF, DOCX, PPT or PPTX file.',
    };
  }
  if (failure.serverCode == ApiErrorCodes.fileTooLarge) {
    return const {
      'file': 'The selected file exceeds the current allowed size.',
    };
  }
  if (failure.serverCode != ApiErrorCodes.validationFailed) {
    return const {};
  }
  final errors = <String, String>{};
  for (final key in failure.fieldErrors.keys) {
    switch (key) {
      case 'file':
        errors['file'] = 'Check the selected file.';
      case 'title':
        errors['title'] = 'Check the title.';
      case 'body':
        errors['form'] = 'Check the submitted learning material.';
      default:
        errors['form'] = 'The learning material form could not be accepted.';
    }
  }
  if (errors.isEmpty) {
    errors['form'] = 'The learning material form could not be accepted.';
  }
  return errors;
}
