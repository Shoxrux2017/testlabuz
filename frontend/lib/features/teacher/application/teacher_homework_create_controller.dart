import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_homework_repository_impl.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_form.dart';
import '../domain/teacher_homework_mutation.dart';
import '../domain/teacher_topic.dart';
import 'teacher_homework_create_state.dart';
import 'teacher_homework_list_controller.dart';
import 'teacher_homework_student_picker_target.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_controller.dart';
import 'teacher_topic_detail_state.dart';

final teacherHomeworkCreateControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherHomeworkCreateController,
      TeacherHomeworkCreateState,
      String
    >(TeacherHomeworkCreateController.new);

class TeacherHomeworkCreateController
    extends Notifier<TeacherHomeworkCreateState> {
  TeacherHomeworkCreateController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherHomeworkCreateRequest? _activeRequest;
  TeacherHomeworkStudentPickerOwner? _activePickerOwner;
  int _operationGeneration = 0;
  int _routeGeneration = 0;
  int _studentPickerGeneration = 0;
  var _ownsRoute = false;
  var _initialized = false;

  @override
  TeacherHomeworkCreateState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final topicDetail = ref.watch(
      teacherTopicDetailControllerProvider(topicId),
    );
    if (!isCanonicalTeacherTopicId(topicId) ||
        sessionKey == null ||
        sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return TeacherHomeworkCreateState.loading();
    }
    if (_activeSessionKey != sessionKey) {
      _clearSession();
      _activeSessionKey = sessionKey;
    }
    final topic = topicDetail.topic;
    if (_initialized) {
      if (topic != null) {
        if (!state.isBusy &&
            state.status != TeacherHomeworkCreateStatus.outcomeUnknown &&
            state.status != TeacherHomeworkCreateStatus.topicNotEditable &&
            state.status != TeacherHomeworkCreateStatus.confirmedSuccess &&
            (topic.status == TeacherTopicStatus.closed ||
                topic.status == TeacherTopicStatus.archived)) {
          return TeacherHomeworkCreateState.review(
            status: TeacherHomeworkCreateStatus.topicNotEditable,
            topic: topic,
            form: state.form,
            rememberedSelectedIds: state.rememberedSelectedIds,
            formError: 'Homework cannot be created for this Topic.',
          );
        }
        return state.withTopic(topic);
      }
      if (!state.isBusy &&
          state.status != TeacherHomeworkCreateStatus.outcomeUnknown &&
          state.status != TeacherHomeworkCreateStatus.confirmedSuccess &&
          topicDetail.status == TeacherTopicDetailStatus.notFound) {
        return TeacherHomeworkCreateState.review(
          status: TeacherHomeworkCreateStatus.unavailable,
          topic: null,
          form: state.form,
          rememberedSelectedIds: state.rememberedSelectedIds,
          formError:
              'This Topic is no longer available in your current Teacher workspace.',
        );
      }
      return state;
    }

    if (topic != null) {
      _initialized = true;
      if (topic.status == TeacherTopicStatus.closed ||
          topic.status == TeacherTopicStatus.archived) {
        return TeacherHomeworkCreateState.review(
          status: TeacherHomeworkCreateStatus.topicNotEditable,
          topic: topic,
          form: TeacherHomeworkFormValue(),
          rememberedSelectedIds: const {},
          formError: 'Homework cannot be created for this Topic.',
        );
      }
      return TeacherHomeworkCreateState.editing(topic: topic);
    }
    if (topicDetail.status == TeacherTopicDetailStatus.notFound) {
      _initialized = true;
      return TeacherHomeworkCreateState.review(
        status: TeacherHomeworkCreateStatus.unavailable,
        topic: null,
        form: TeacherHomeworkFormValue(),
        rememberedSelectedIds: const {},
        formError:
            'This Topic is no longer available in your current Teacher workspace.',
      );
    }
    if (topicDetail.status == TeacherTopicDetailStatus.error) {
      return TeacherHomeworkCreateState.initialLoadError(
        topicDetail.failure ?? _unexpectedTopicFailure(),
      );
    }
    return TeacherHomeworkCreateState.loading();
  }

  void enterRoute() {
    if (!_ownsRoute) {
      _ownsRoute = true;
      _routeGeneration += 1;
    }
  }

  void retryInitialLoad() {
    final sessionKey = _activeSessionKey;
    if (state.status != TeacherHomeworkCreateStatus.initialLoadError ||
        sessionKey == null ||
        !_ownsRoute ||
        !_matchesSession(sessionKey)) {
      return;
    }
    ref.read(teacherTopicDetailControllerProvider(topicId).notifier).refresh();
  }

  void updateTitle(String value) {
    _update(state.form.copyWith(title: value), const {
      TeacherHomeworkFormField.title,
    });
  }

  void updateDescription(String value) {
    _update(state.form.copyWith(description: value), const {
      TeacherHomeworkFormField.description,
    });
  }

  void updateStudentInstructions(String value) {
    _update(state.form.copyWith(studentInstructions: value), const {
      TeacherHomeworkFormField.studentInstructions,
    });
  }

  void updateAssignmentMode(TeacherHomeworkAssignmentMode mode) {
    if (!state.canEdit || state.form.assignmentMode == mode) {
      return;
    }
    var remembered = state.rememberedSelectedIds;
    late final Set<String> resultingSelection;
    if (mode == TeacherHomeworkAssignmentMode.group) {
      remembered = state.form.selectedStudentIds;
      resultingSelection = const {};
    } else {
      resultingSelection = remembered;
    }
    _update(
      state.form.copyWith(
        assignmentMode: mode,
        selectedStudentIds: resultingSelection,
      ),
      const {
        TeacherHomeworkFormField.assignmentMode,
        TeacherHomeworkFormField.studentIds,
      },
      rememberedSelectedIds: remembered,
    );
  }

  void updateSelectedStudentIds(Set<String> studentIds) {
    if (state.form.assignmentMode !=
        TeacherHomeworkAssignmentMode.selectedStudents) {
      return;
    }
    try {
      final next = state.form.copyWith(selectedStudentIds: studentIds);
      _update(next, const {
        TeacherHomeworkFormField.studentIds,
      }, rememberedSelectedIds: next.selectedStudentIds);
    } on ArgumentError {
      return;
    }
  }

  void updateDeadlineAt(InstitutionWallClock? value) {
    _update(state.form.copyWith(deadlineWallClock: value), const {
      TeacherHomeworkFormField.deadlineAt,
    });
  }

  TeacherHomeworkStudentPickerLaunch? beginStudentPicker() {
    final sessionKey = _activeSessionKey;
    final topic = _confirmedCurrentTopic();
    if (!_ownsRoute ||
        !state.canEdit ||
        state.form.assignmentMode !=
            TeacherHomeworkAssignmentMode.selectedStudents ||
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
    final currentTopic = _confirmedCurrentTopic();
    if (_activePickerOwner != owner ||
        owner.routeGeneration != _routeGeneration ||
        owner.pickerGeneration != _studentPickerGeneration ||
        currentTopic == null ||
        currentTopic.group.id.toLowerCase() != owner.groupId.toLowerCase() ||
        !_matchesSession(owner.sessionKey)) {
      return;
    }
    _activePickerOwner = null;
    updateSelectedStudentIds(studentIds);
  }

  Future<void> submit() async {
    if (!state.canSubmit || !_ownsRoute) {
      return;
    }
    final sessionKey = _activeSessionKey;
    final topic = _confirmedCurrentTopic();
    if (sessionKey == null || topic == null || !_matchesSession(sessionKey)) {
      return;
    }
    if (topic.status == TeacherTopicStatus.closed ||
        topic.status == TeacherTopicStatus.archived) {
      state = TeacherHomeworkCreateState.review(
        status: TeacherHomeworkCreateStatus.topicNotEditable,
        topic: topic,
        form: state.form,
        rememberedSelectedIds: state.rememberedSelectedIds,
        formError: 'Homework cannot be created for this Topic.',
      );
      return;
    }

    final errors = state.form.validate(
      institutionTimezone: sessionKey.institutionTimezone,
    );
    if (errors.isNotEmpty) {
      state = TeacherHomeworkCreateState.validation(
        status: TeacherHomeworkCreateStatus.localValidationFailure,
        topic: topic,
        form: state.form,
        rememberedSelectedIds: state.rememberedSelectedIds,
        fieldErrors: errors,
        formError: 'Review the highlighted fields.',
      );
      return;
    }

    final request = TeacherHomeworkCreateRequest.fromForm(
      state.form,
      sessionKey.institutionTimezone,
    );
    final submittedForm = state.form.copyWith(
      title: request.title,
      description: request.description ?? '',
      studentInstructions: request.studentInstructions,
      selectedStudentIds: request.studentIds.toSet(),
    );
    final generation = ++_operationGeneration;
    final routeGeneration = _routeGeneration;
    _activeRequest = request;
    _activePickerOwner = null;
    state = TeacherHomeworkCreateState.submitting(
      topic: topic,
      form: submittedForm,
      rememberedSelectedIds: state.rememberedSelectedIds,
    );
    try {
      final created = await ref
          .read(teacherHomeworkRepositoryProvider)
          .createHomework(topicId, request);
      if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
        return;
      }
      if (created.topicId.toLowerCase() != topicId.toLowerCase()) {
        _publishUnknown(topic, submittedForm, state.rememberedSelectedIds);
        return;
      }
      _activeRequest = null;
      _refreshHomeworkList(sessionKey);
      state = TeacherHomeworkCreateState.success(
        topic: topic,
        homeworkId: created.id,
      );
    } on TeacherHomeworkMutationOutcomeUnknownException {
      if (_canPublish(generation, routeGeneration, sessionKey, request)) {
        _publishUnknown(topic, submittedForm, state.rememberedSelectedIds);
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
          form: submittedForm,
          rememberedSelectedIds: state.rememberedSelectedIds,
        );
        return;
      }
      _activeRequest = null;
      _publishDefiniteFailure(
        topic,
        submittedForm,
        state.rememberedSelectedIds,
        exception.failure,
      );
    } catch (_) {
      if (_canPublish(generation, routeGeneration, sessionKey, request)) {
        _publishUnknown(topic, submittedForm, state.rememberedSelectedIds);
      }
    }
  }

  bool reviewHomework() {
    final sessionKey = _activeSessionKey;
    if (!_ownsRoute ||
        state.status != TeacherHomeworkCreateStatus.outcomeUnknown ||
        sessionKey == null ||
        !_matchesSession(sessionKey)) {
      return false;
    }
    _refreshHomeworkList(sessionKey);
    leaveRoute();
    return true;
  }

  void leaveRoute() {
    _ownsRoute = false;
    _routeGeneration += 1;
    _invalidateOperation();
  }

  Future<void> _reconcileTopicNotEditable({
    required int generation,
    required int routeGeneration,
    required TeacherSessionKey sessionKey,
    required TeacherHomeworkCreateRequest request,
    required TeacherTopic fallbackTopic,
    required TeacherHomeworkFormValue form,
    required Set<String> rememberedSelectedIds,
  }) async {
    final refreshed = await ref
        .read(teacherTopicDetailControllerProvider(topicId).notifier)
        .refreshForMaterialReconciliation();
    if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
      return;
    }
    _activeRequest = null;
    state = TeacherHomeworkCreateState.review(
      status: TeacherHomeworkCreateStatus.topicNotEditable,
      topic: refreshed ?? _confirmedCurrentTopic() ?? fallbackTopic,
      form: form,
      rememberedSelectedIds: rememberedSelectedIds,
      formError:
          'This Topic is no longer editable. Review its current server state.',
    );
  }

  void _publishUnknown(
    TeacherTopic topic,
    TeacherHomeworkFormValue form,
    Set<String> rememberedSelectedIds,
  ) {
    _activeRequest = null;
    state = TeacherHomeworkCreateState.review(
      status: TeacherHomeworkCreateStatus.outcomeUnknown,
      topic: topic,
      form: form,
      rememberedSelectedIds: rememberedSelectedIds,
      formError:
          'The Homework creation request may have succeeded. Review this Topic\'s Homework before creating another Homework.',
    );
  }

  void _publishDefiniteFailure(
    TeacherTopic topic,
    TeacherHomeworkFormValue form,
    Set<String> rememberedSelectedIds,
    ApiFailure failure,
  ) {
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      _publishValidation(
        topic,
        form,
        rememberedSelectedIds,
        failure.fieldErrors,
      );
      return;
    }
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      state = TeacherHomeworkCreateState.review(
        status: TeacherHomeworkCreateStatus.unavailable,
        topic: null,
        form: form,
        rememberedSelectedIds: rememberedSelectedIds,
        formError:
            'This Topic is no longer available in your current Teacher workspace.',
      );
      return;
    }
    final message = switch (failure.serverCode) {
      ApiErrorCodes.forbidden =>
        'You do not have permission to create Homework.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The Homework could not be created.',
    };
    state = TeacherHomeworkCreateState.editing(
      status: TeacherHomeworkCreateStatus.definiteFailure,
      topic: topic,
      form: form,
      rememberedSelectedIds: rememberedSelectedIds,
      formError: message,
    );
  }

  void _publishValidation(
    TeacherTopic topic,
    TeacherHomeworkFormValue form,
    Set<String> rememberedSelectedIds,
    Map<String, List<String>> serverErrors,
  ) {
    final errors = <TeacherHomeworkFormField, String>{};
    var hasUnknown = serverErrors.isEmpty;
    for (final key in serverErrors.keys) {
      final field = TeacherHomeworkFormField.fromRequestKey(key);
      if (field == null) {
        hasUnknown = true;
        continue;
      }
      errors[field] = _serverValidationMessage(field);
    }
    state = TeacherHomeworkCreateState.validation(
      status: TeacherHomeworkCreateStatus.serverValidationFailure,
      topic: topic,
      form: form,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: errors,
      formError: hasUnknown ? 'The Homework could not be created.' : null,
    );
  }

  void _update(
    TeacherHomeworkFormValue form,
    Set<TeacherHomeworkFormField> clearErrors, {
    Set<String>? rememberedSelectedIds,
  }) {
    final sessionKey = _activeSessionKey;
    if (_ownsRoute &&
        sessionKey != null &&
        _matchesSession(sessionKey) &&
        state.canEdit) {
      state = state.withForm(
        form,
        clearErrors: clearErrors,
        rememberedSelectedIds: rememberedSelectedIds,
      );
    }
  }

  TeacherTopic? _confirmedCurrentTopic() {
    final detail = ref.read(teacherTopicDetailControllerProvider(topicId));
    final topic = detail.topic;
    if (topic == null || topic.id.toLowerCase() != topicId.toLowerCase()) {
      return null;
    }
    return topic;
  }

  void _refreshHomeworkList(TeacherSessionKey sessionKey) {
    final provider = teacherHomeworkListControllerProvider(topicId);
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
    TeacherHomeworkCreateRequest request,
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
    state = TeacherHomeworkCreateState.loading();
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

String _serverValidationMessage(TeacherHomeworkFormField field) {
  return switch (field) {
    TeacherHomeworkFormField.title => 'Review the Homework title.',
    TeacherHomeworkFormField.description => 'Review the description.',
    TeacherHomeworkFormField.studentInstructions =>
      'Review the student instructions.',
    TeacherHomeworkFormField.assignmentMode => 'Review the assignment mode.',
    TeacherHomeworkFormField.studentIds =>
      'Review the selected Students. One or more selections may no longer be eligible.',
    TeacherHomeworkFormField.deadlineAt =>
      'Review the Homework deadline and Institution timezone.',
  };
}

ApiFailure _unexpectedTopicFailure() {
  return ApiFailure.local(
    kind: ApiFailureKind.unknown,
    message: 'Unexpected Teacher Topic detail failure.',
  );
}
