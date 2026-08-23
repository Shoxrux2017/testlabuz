import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_topic_repository_impl.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_topic_mutation.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_create_state.dart';
import 'teacher_topic_group_picker_controller.dart';
import 'teacher_topic_list_controller.dart';

final teacherTopicCreateControllerProvider =
    NotifierProvider.autoDispose<
      TeacherTopicCreateController,
      TeacherTopicCreateState
    >(TeacherTopicCreateController.new);

class TeacherTopicCreateController extends Notifier<TeacherTopicCreateState> {
  TeacherSessionKey? _activeSessionKey;
  TeacherTopicCreateRequest? _activeRequest;
  int _operationGeneration = 0;
  int _routeGeneration = 0;
  var _ownsRoute = false;

  @override
  TeacherTopicCreateState build() {
    final key = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null || key.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherTopicCreateState.editing();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _invalidateOperation();
    _activeSessionKey = key;
    return const TeacherTopicCreateState.editing();
  }

  void enterRoute() {
    if (!_ownsRoute) {
      _ownsRoute = true;
      _routeGeneration += 1;
    }
  }

  void selectGroup(TeacherGroupSummary group) {
    if (group.status != TeacherGroupStatus.active) {
      return;
    }
    _update(
      state.form.copyWith(selectedGroup: group),
      TeacherTopicFormField.groupId,
    );
  }

  void updateTitle(String value) =>
      _update(state.form.copyWith(title: value), TeacherTopicFormField.title);
  void updateDescription(String value) => _update(
    state.form.copyWith(description: value),
    TeacherTopicFormField.description,
  );
  void updateSubject(String value) => _update(
    state.form.copyWith(subject: value),
    TeacherTopicFormField.subject,
  );
  void updateStudentInstructions(String value) => _update(
    state.form.copyWith(studentInstructions: value),
    TeacherTopicFormField.studentInstructions,
  );
  void updateLessonAt(InstitutionWallClock? value) => _update(
    state.form.copyWith(lessonAt: value),
    TeacherTopicFormField.lessonAt,
  );

  Future<void> submit() async {
    if (!state.canSubmit || !_ownsRoute) {
      return;
    }
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key)) {
      return;
    }
    final errors = state.form.validate(
      requireGroup: true,
      institutionTimezone: key.institutionTimezone,
    );
    if (errors.isNotEmpty) {
      state = TeacherTopicCreateState.validation(
        status: TeacherTopicCreateStatus.localValidationFailure,
        form: state.form,
        fieldErrors: errors,
        formError: 'Review the highlighted fields.',
      );
      return;
    }

    final request = TeacherTopicCreateRequest.fromForm(
      state.form,
      key.institutionTimezone,
    );
    final submittedForm = state.form.copyWith(
      title: request.title,
      description: request.description ?? '',
      subject: request.subject,
      studentInstructions: request.studentInstructions,
    );
    final generation = ++_operationGeneration;
    final routeGeneration = _routeGeneration;
    _activeRequest = request;
    state = TeacherTopicCreateState.submitting(
      form: submittedForm,
      groupId: request.groupId,
    );
    try {
      final topic = await ref
          .read(teacherTopicRepositoryProvider)
          .createTopic(request);
      if (!_canPublish(generation, routeGeneration, key, request)) {
        return;
      }
      _activeRequest = null;
      _markTopicListStale(key);
      state = TeacherTopicCreateState.success(topic.id);
    } on TeacherTopicMutationOutcomeUnknownException {
      await _publishUnknown(
        generation: generation,
        routeGeneration: routeGeneration,
        key: key,
        request: request,
        form: submittedForm,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, routeGeneration, key, request)) {
        return;
      }
      _activeRequest = null;
      _publishDefiniteFailure(submittedForm, exception.failure);
    } catch (_) {
      await _publishUnknown(
        generation: generation,
        routeGeneration: routeGeneration,
        key: key,
        request: request,
        form: submittedForm,
      );
    }
  }

  bool reviewTopics() {
    final key = _activeSessionKey;
    final groupId = state.submittedGroupId;
    if (!_ownsRoute ||
        state.status != TeacherTopicCreateStatus.unknown ||
        key == null ||
        groupId == null ||
        !_matchesSession(key)) {
      return false;
    }
    ref
        .read(teacherTopicListRetainedQueryProvider)
        .prepareUnknownCreateRecovery(key, groupId);
    if (ref.exists(teacherTopicListControllerProvider)) {
      ref.invalidate(teacherTopicListControllerProvider);
    }
    leaveRoute();
    return true;
  }

  void leaveRoute() {
    _ownsRoute = false;
    _routeGeneration += 1;
    _invalidateOperation();
    state = const TeacherTopicCreateState.editing();
  }

  Future<void> _publishUnknown({
    required int generation,
    required int routeGeneration,
    required TeacherSessionKey key,
    required TeacherTopicCreateRequest request,
    required TeacherTopicFormValue form,
  }) async {
    if (!_canPublish(generation, routeGeneration, key, request)) {
      return;
    }
    state = TeacherTopicCreateState.submitting(
      form: form,
      groupId: request.groupId,
      reconciling: true,
    );
    await Future<void>.value();
    if (!_canPublish(generation, routeGeneration, key, request)) {
      return;
    }
    _activeRequest = null;
    state = TeacherTopicCreateState.unknown(
      form: form,
      groupId: request.groupId,
    );
  }

  void _publishDefiniteFailure(TeacherTopicFormValue form, ApiFailure failure) {
    if (_clearForSessionFailure(failure)) {
      return;
    }
    final code = failure.serverCode;
    if (failure.statusCode == 422 && code == ApiErrorCodes.validationFailed) {
      _publishValidation(form, failure.fieldErrors);
      return;
    }
    if (failure.statusCode == 404 && code == ApiErrorCodes.resourceNotFound) {
      final cleared = form.copyWith(selectedGroup: null);
      if (ref.exists(teacherTopicGroupPickerControllerProvider)) {
        ref
            .read(teacherTopicGroupPickerControllerProvider.notifier)
            .clearSelection(refresh: true);
      }
      state = TeacherTopicCreateState.editing(
        form: cleared,
        formError: 'Selected group is no longer available.',
      );
      return;
    }
    final message = switch (code) {
      ApiErrorCodes.forbidden => 'You do not have permission to create Topics.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The Topic could not be created.',
    };
    state = TeacherTopicCreateState.failure(form: form, formError: message);
  }

  void _publishValidation(
    TeacherTopicFormValue form,
    Map<String, List<String>> serverErrors,
  ) {
    final errors = <TeacherTopicFormField, String>{};
    var hasUnknown = serverErrors.isEmpty;
    for (final key in serverErrors.keys) {
      final field = TeacherTopicFormField.fromRequestKey(key);
      if (field == null) {
        hasUnknown = true;
        continue;
      }
      errors[field] = switch (field) {
        TeacherTopicFormField.groupId => 'Review the selected Group.',
        TeacherTopicFormField.title => 'Review the Topic title.',
        TeacherTopicFormField.description => 'Review the description.',
        TeacherTopicFormField.subject => 'Review the subject.',
        TeacherTopicFormField.studentInstructions =>
          'Review the student instructions.',
        TeacherTopicFormField.lessonAt => 'Review the lesson date and time.',
      };
    }
    state = TeacherTopicCreateState.validation(
      status: TeacherTopicCreateStatus.serverValidationFailure,
      form: form,
      fieldErrors: errors,
      formError: hasUnknown ? 'The Topic could not be created.' : null,
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
    state = const TeacherTopicCreateState.editing();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _update(TeacherTopicFormValue form, TeacherTopicFormField field) {
    if (state.canEdit && _ownsRoute) {
      state = state.withForm(form, clearError: field);
    }
  }

  void _markTopicListStale(TeacherSessionKey key) {
    ref
        .read(teacherTopicListRetainedQueryProvider)
        .markAuthoritativeRowsStale(key);
    if (ref.exists(teacherTopicListControllerProvider)) {
      ref.invalidate(teacherTopicListControllerProvider);
    }
  }

  bool _canPublish(
    int generation,
    int routeGeneration,
    TeacherSessionKey key,
    TeacherTopicCreateRequest request,
  ) {
    return ref.mounted &&
        _ownsRoute &&
        generation == _operationGeneration &&
        routeGeneration == _routeGeneration &&
        identical(_activeRequest, request) &&
        _matchesSession(key);
  }

  bool _matchesSession(TeacherSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        key.surface == AppDeviceSurface.desktop &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _invalidateOperation();
  }

  void _invalidateOperation() {
    _operationGeneration += 1;
    _activeRequest = null;
  }
}
