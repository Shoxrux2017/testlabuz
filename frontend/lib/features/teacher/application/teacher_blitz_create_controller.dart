import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_blitz_repository_impl.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import '../domain/teacher_blitz_mutation.dart';
import '../domain/teacher_topic.dart';
import 'teacher_blitz_create_state.dart';
import 'teacher_blitz_list_controller.dart';
import 'teacher_blitz_server_validation.dart';
import 'teacher_homework_student_picker_target.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_controller.dart';
import 'teacher_topic_detail_state.dart';

final teacherBlitzCreateControllerProvider = NotifierProvider.autoDispose
    .family<TeacherBlitzCreateController, TeacherBlitzCreateState, String>(
      TeacherBlitzCreateController.new,
    );

const _topicNotEditableMessage =
    'Blitz creation is unavailable for this Topic.';
const _topicUnavailableMessage =
    'This Topic is no longer available in your current Teacher workspace.';
const _outcomeReviewMessage =
    'Blitz creation outcome is uncertain. Check the Topic Blitz list before '
    'trying to create it again.';

class TeacherBlitzCreateController extends Notifier<TeacherBlitzCreateState> {
  TeacherBlitzCreateController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherBlitzCreateRequest? _activeRequest;
  TeacherHomeworkStudentPickerOwner? _activePickerOwner;
  int _operationGeneration = 0;
  int _routeGeneration = 0;
  int _studentPickerGeneration = 0;
  var _ownsRoute = false;
  var _initialized = false;

  @override
  TeacherBlitzCreateState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!isCanonicalTeacherTopicId(topicId) ||
        sessionKey == null ||
        sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return TeacherBlitzCreateState.loading();
    }
    final topicDetail = ref.watch(
      teacherTopicDetailControllerProvider(topicId),
    );
    if (_activeSessionKey != sessionKey) {
      _clearSession();
      _activeSessionKey = sessionKey;
    }
    final topic = topicDetail.topic;
    if (_initialized) {
      return _reconcileTopic(topicDetail);
    }

    if (topic != null) {
      _initialized = true;
      return _allowsCreation(topic)
          ? TeacherBlitzCreateState.editing(topic: topic)
          : TeacherBlitzCreateState.review(
              status: TeacherBlitzCreateStatus.topicNotEditable,
              topic: topic,
              form: TeacherBlitzFormValue(),
              formError: _topicNotEditableMessage,
            );
    }
    if (topicDetail.status == TeacherTopicDetailStatus.notFound) {
      _initialized = true;
      return TeacherBlitzCreateState.review(
        status: TeacherBlitzCreateStatus.unavailable,
        topic: null,
        form: TeacherBlitzFormValue(),
        formError: _topicUnavailableMessage,
      );
    }
    if (topicDetail.status == TeacherTopicDetailStatus.error) {
      return TeacherBlitzCreateState.initialLoadError(
        topicDetail.failure ??
            ApiFailure.local(
              kind: ApiFailureKind.unknown,
              message: 'Unexpected Teacher Topic detail failure.',
            ),
      );
    }
    return TeacherBlitzCreateState.loading();
  }

  TeacherBlitzCreateState _reconcileTopic(TeacherTopicDetailState detail) {
    final topic = detail.topic;
    final keepsOperationState =
        state.isBusy ||
        state.status == TeacherBlitzCreateStatus.outcomeReview ||
        state.status == TeacherBlitzCreateStatus.confirmedSuccess;
    if (keepsOperationState) {
      return state;
    }
    if (topic != null) {
      if (state.status != TeacherBlitzCreateStatus.topicNotEditable &&
          !_allowsCreation(topic)) {
        return TeacherBlitzCreateState.review(
          status: TeacherBlitzCreateStatus.topicNotEditable,
          topic: topic,
          form: state.form,
          formError: _topicNotEditableMessage,
        );
      }
      return state.withTopic(topic);
    }
    if (detail.status == TeacherTopicDetailStatus.notFound) {
      return TeacherBlitzCreateState.review(
        status: TeacherBlitzCreateStatus.unavailable,
        topic: null,
        form: state.form,
        formError: _topicUnavailableMessage,
      );
    }
    return state;
  }

  void enterRoute() {
    if (!_ownsRoute) {
      _ownsRoute = true;
      _routeGeneration += 1;
    }
  }

  void leaveRoute() {
    _ownsRoute = false;
    _routeGeneration += 1;
    _invalidateOperation();
  }

  void retryInitialLoad() {
    final sessionKey = _activeSessionKey;
    if (state.status != TeacherBlitzCreateStatus.initialLoadError ||
        sessionKey == null ||
        !_ownsRoute ||
        !_matchesSession(sessionKey)) {
      return;
    }
    ref.read(teacherTopicDetailControllerProvider(topicId).notifier).refresh();
  }

  void updateTitle(String value) {
    _update(state.form.copyWith(title: value), const {
      TeacherBlitzFormField.title,
    });
  }

  void updateDescription(String value) {
    _update(state.form.copyWith(description: value), const {
      TeacherBlitzFormField.description,
    });
  }

  void updateStudentInstructions(String value) {
    _update(state.form.copyWith(studentInstructions: value), const {
      TeacherBlitzFormField.studentInstructions,
    });
  }

  void updateDurationSeconds(String value) {
    _update(state.form.copyWith(durationSecondsText: value), const {
      TeacherBlitzFormField.durationSeconds,
    });
  }

  /// The screen confirms before this clears a non-empty selection.
  void updateAssignmentMode(TeacherBlitzAssignmentMode mode) {
    if (state.form.assignmentMode == mode) {
      return;
    }
    _update(
      state.form.copyWith(assignmentMode: mode, selectedStudentIds: const {}),
      const {
        TeacherBlitzFormField.assignmentMode,
        TeacherBlitzFormField.studentIds,
      },
    );
  }

  TeacherHomeworkStudentPickerLaunch? beginStudentPicker() {
    final sessionKey = _activeSessionKey;
    final topic = _confirmedCurrentTopic();
    if (!_ownsRoute ||
        !state.canEdit ||
        state.form.assignmentMode !=
            TeacherBlitzAssignmentMode.selectedStudents ||
        sessionKey == null ||
        topic == null ||
        !_matchesSession(sessionKey)) {
      return null;
    }
    final owner = (
      sessionKey: sessionKey,
      groupId: topic.group.id,
      routeGeneration: _routeGeneration,
      pickerGeneration: ++_studentPickerGeneration,
    );
    _activePickerOwner = owner;
    return (
      target: TeacherHomeworkStudentPickerTarget(
        groupId: topic.group.id,
        initialSelectedIds: state.form.selectedStudentIds,
      ),
      owner: owner,
    );
  }

  void cancelStudentPicker(TeacherHomeworkStudentPickerOwner owner) {
    if (_activePickerOwner == owner) {
      _activePickerOwner = null;
    }
  }

  void applyStudentSelection(
    Set<String> studentIds,
    TeacherHomeworkStudentPickerOwner owner,
  ) {
    final topic = _confirmedCurrentTopic();
    if (_activePickerOwner != owner ||
        owner.routeGeneration != _routeGeneration ||
        owner.pickerGeneration != _studentPickerGeneration ||
        topic == null ||
        topic.group.id.toLowerCase() != owner.groupId.toLowerCase() ||
        !_matchesSession(owner.sessionKey) ||
        state.form.assignmentMode !=
            TeacherBlitzAssignmentMode.selectedStudents) {
      return;
    }
    _activePickerOwner = null;
    try {
      _update(state.form.copyWith(selectedStudentIds: studentIds), const {
        TeacherBlitzFormField.studentIds,
      });
    } on ArgumentError {
      return;
    }
  }

  Future<void> submit() async {
    final sessionKey = _activeSessionKey;
    final topic = _confirmedCurrentTopic();
    if (!state.canSubmit ||
        !_ownsRoute ||
        sessionKey == null ||
        topic == null ||
        !_matchesSession(sessionKey)) {
      return;
    }
    if (!_allowsCreation(topic)) {
      state = TeacherBlitzCreateState.review(
        status: TeacherBlitzCreateStatus.topicNotEditable,
        topic: topic,
        form: state.form,
        formError: _topicNotEditableMessage,
      );
      return;
    }

    final errors = state.form.validate();
    if (errors.isNotEmpty) {
      state = TeacherBlitzCreateState.editing(
        status: TeacherBlitzCreateStatus.localValidationFailure,
        topic: topic,
        form: state.form,
        fieldErrors: errors,
        formError: 'Review the highlighted fields.',
      );
      return;
    }

    final request = TeacherBlitzCreateRequest.fromForm(state.form);
    final form = state.form;
    final generation = ++_operationGeneration;
    final routeGeneration = _routeGeneration;
    _activeRequest = request;
    _activePickerOwner = null;
    state = TeacherBlitzCreateState.editing(
      status: TeacherBlitzCreateStatus.submitting,
      topic: topic,
      form: form,
    );
    try {
      final created = await ref
          .read(teacherBlitzRepositoryProvider)
          .createBlitz(topicId, request);
      if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
        return;
      }
      if (!_isCreatedInTopic(created, topic)) {
        _publishOutcomeReview(topic, form);
        return;
      }
      _activeRequest = null;
      _refreshBlitzList(sessionKey);
      state = TeacherBlitzCreateState.success(
        topic: topic,
        blitzId: created.id,
      );
    } on TeacherBlitzMutationOutcomeUnknownException {
      if (_canPublish(generation, routeGeneration, sessionKey, request)) {
        _publishOutcomeReview(topic, form);
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 409 &&
          exception.failure.serverCode == ApiErrorCodes.topicNotEditable) {
        await _reconcileTopicNotEditable(
          generation: generation,
          routeGeneration: routeGeneration,
          sessionKey: sessionKey,
          request: request,
          fallbackTopic: topic,
          form: form,
        );
        return;
      }
      _activeRequest = null;
      _publishDefiniteFailure(topic, form, exception.failure);
    } catch (_) {
      if (_canPublish(generation, routeGeneration, sessionKey, request)) {
        _publishOutcomeReview(topic, form);
      }
    }
  }

  /// Refreshes the Topic Blitz list for manual review; never re-creates.
  bool checkBlitzList() {
    final sessionKey = _activeSessionKey;
    if (!_ownsRoute ||
        state.status != TeacherBlitzCreateStatus.outcomeReview ||
        sessionKey == null ||
        !_matchesSession(sessionKey)) {
      return false;
    }
    _refreshBlitzList(sessionKey);
    leaveRoute();
    return true;
  }

  Future<void> _reconcileTopicNotEditable({
    required int generation,
    required int routeGeneration,
    required TeacherSessionKey sessionKey,
    required TeacherBlitzCreateRequest request,
    required TeacherTopic fallbackTopic,
    required TeacherBlitzFormValue form,
  }) async {
    final refreshed = await ref
        .read(teacherTopicDetailControllerProvider(topicId).notifier)
        .refreshForMaterialReconciliation();
    if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
      return;
    }
    _activeRequest = null;
    state = TeacherBlitzCreateState.review(
      status: TeacherBlitzCreateStatus.topicNotEditable,
      topic: refreshed ?? _confirmedCurrentTopic() ?? fallbackTopic,
      form: form,
      formError:
          'This Topic is no longer editable. Review its current server state.',
    );
  }

  void _publishOutcomeReview(TeacherTopic topic, TeacherBlitzFormValue form) {
    _activeRequest = null;
    state = TeacherBlitzCreateState.review(
      status: TeacherBlitzCreateStatus.outcomeReview,
      topic: topic,
      form: form,
      formError: _outcomeReviewMessage,
    );
  }

  void _publishDefiniteFailure(
    TeacherTopic topic,
    TeacherBlitzFormValue form,
    ApiFailure failure,
  ) {
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      final errors = <TeacherBlitzFormField, String>{};
      var hasUnknown = failure.fieldErrors.isEmpty;
      for (final key in failure.fieldErrors.keys) {
        final field = TeacherBlitzFormField.fromRequestKey(key);
        if (field == null) {
          hasUnknown = true;
        } else {
          errors[field] = teacherBlitzServerValidationMessage(field);
        }
      }
      state = TeacherBlitzCreateState.editing(
        status: TeacherBlitzCreateStatus.serverValidationFailure,
        topic: topic,
        form: form,
        fieldErrors: errors,
        formError: hasUnknown ? 'The Blitz could not be created.' : null,
      );
      return;
    }
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      state = TeacherBlitzCreateState.review(
        status: TeacherBlitzCreateStatus.unavailable,
        topic: null,
        form: form,
        formError: _topicUnavailableMessage,
      );
      return;
    }
    state = TeacherBlitzCreateState.editing(
      status: TeacherBlitzCreateStatus.definiteFailure,
      topic: topic,
      form: form,
      formError: switch (failure.serverCode) {
        ApiErrorCodes.forbidden =>
          'You do not have permission to create Blitz.',
        ApiErrorCodes.rateLimited =>
          'Too many requests. Wait before trying again.',
        _ => 'The Blitz could not be created.',
      },
    );
  }

  void _update(
    TeacherBlitzFormValue form,
    Set<TeacherBlitzFormField> clearErrors,
  ) {
    final sessionKey = _activeSessionKey;
    if (_ownsRoute &&
        sessionKey != null &&
        _matchesSession(sessionKey) &&
        state.canEdit) {
      state = state.withForm(form, clearErrors: clearErrors);
    }
  }

  bool _isCreatedInTopic(TeacherBlitz created, TeacherTopic topic) {
    return created.topicId.toLowerCase() == topicId.toLowerCase() &&
        created.groupId.toLowerCase() == topic.group.id.toLowerCase() &&
        created.status == TeacherBlitzStatus.draft;
  }

  TeacherTopic? _confirmedCurrentTopic() {
    final topic = ref.read(teacherTopicDetailControllerProvider(topicId)).topic;
    if (topic == null || topic.id.toLowerCase() != topicId.toLowerCase()) {
      return null;
    }
    return topic;
  }

  void _refreshBlitzList(TeacherSessionKey sessionKey) {
    final provider = teacherBlitzListControllerProvider(topicId);
    if (ref.exists(provider)) {
      ref.read(provider.notifier).refreshAfterMutation(sessionKey);
    } else {
      ref.invalidate(provider);
    }
  }

  bool _canPublish(
    int generation,
    int routeGeneration,
    TeacherSessionKey sessionKey,
    TeacherBlitzCreateRequest request,
  ) {
    return ref.mounted &&
        _ownsRoute &&
        generation == _operationGeneration &&
        routeGeneration == _routeGeneration &&
        identical(_activeRequest, request) &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
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
    _clearSession();
    state = TeacherBlitzCreateState.loading();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _initialized = false;
    _invalidateOperation();
  }

  void _invalidateOperation() {
    _operationGeneration += 1;
    _studentPickerGeneration += 1;
    _activeRequest = null;
    _activePickerOwner = null;
  }
}

bool _allowsCreation(TeacherTopic topic) {
  return topic.status == TeacherTopicStatus.draft ||
      topic.status == TeacherTopicStatus.active;
}
