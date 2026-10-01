import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/files/local_file_actions.dart';
import '../../../core/files/protected_learning_material_transfer.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/teacher_submission_detail.dart';
import 'teacher_session_key.dart';
import 'teacher_submission_file_state.dart';

final teacherSubmissionFileControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherSubmissionFileController,
      TeacherSubmissionFileState,
      String
    >(TeacherSubmissionFileController.new);

/// Saves a Student's submitted file through the protected download
/// (`S09-T5`); one transfer at a time, desktop only.
class TeacherSubmissionFileController
    extends Notifier<TeacherSubmissionFileState> {
  TeacherSubmissionFileController(this.submissionId);

  final String submissionId;
  TeacherSessionKey? _activeSessionKey;
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherSubmissionFileState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _generation += 1;
      });
    }

    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherSubmissionFileState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }
    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherSubmissionFileState();
  }

  Future<void> saveFile(TeacherReviewFile file) async {
    final sessionKey = _activeSessionKey;
    if (state.isBusy || sessionKey == null || !_matchesSession(sessionKey)) {
      return;
    }
    final generation = ++_generation;
    state = TeacherSubmissionFileState(
      status: TeacherSubmissionFileStatus.downloading,
      fileId: file.id,
    );
    try {
      final downloaded = await ref
          .read(protectedLearningMaterialTransferProvider)
          .download(file.id);
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      state = TeacherSubmissionFileState(
        status: TeacherSubmissionFileStatus.saving,
        fileId: file.id,
      );
      final saved = await ref
          .read(localFileActionsProvider)
          .saveAs(downloaded, dialogTitle: 'Save submitted file');
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      state = TeacherSubmissionFileState(
        feedback: saved ? 'File saved.' : null,
      );
    } on ApiRequestException catch (exception) {
      if (_canPublish(generation, sessionKey)) {
        _publishFailure(file, exception.failure);
      }
    } catch (_) {
      if (_canPublish(generation, sessionKey)) {
        state = TeacherSubmissionFileState(
          status: TeacherSubmissionFileStatus.failure,
          fileId: file.id,
          feedback: 'The file could not be downloaded.',
        );
      }
    }
  }

  void consumeFeedback() {
    if (state.status == TeacherSubmissionFileStatus.idle &&
        state.feedback != null) {
      state = const TeacherSubmissionFileState();
    }
  }

  void _publishFailure(TeacherReviewFile file, ApiFailure failure) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      _clearSession();
      state = const TeacherSubmissionFileState();
      if (code != ApiErrorCodes.authenticationRequired) {
        unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
      }
      return;
    }
    state = TeacherSubmissionFileState(
      status: TeacherSubmissionFileStatus.failure,
      fileId: file.id,
      feedback: switch (code) {
        ApiErrorCodes.resourceNotFound => 'This file is no longer available.',
        ApiErrorCodes.fileNotAvailable =>
          'The file is temporarily unavailable. Try again.',
        _ when failure.kind == ApiFailureKind.invalidResponse =>
          'The server returned an unexpected file response.',
        _ when failure.kind == ApiFailureKind.timeout =>
          'The download timed out. Try again.',
        _ => 'The file could not be downloaded.',
      },
    );
  }

  bool _canPublish(int generation, TeacherSessionKey sessionKey) {
    return ref.mounted &&
        !_isDisposed &&
        generation == _generation &&
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

  void _clearSession() {
    _activeSessionKey = null;
    _generation += 1;
  }
}
