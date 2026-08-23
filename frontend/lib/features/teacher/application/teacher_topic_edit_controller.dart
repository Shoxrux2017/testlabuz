import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_topic_repository_impl.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_mutation.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_controller.dart';
import 'teacher_topic_detail_state.dart';
import 'teacher_topic_edit_state.dart';
import 'teacher_topic_list_controller.dart';

final teacherTopicEditControllerProvider = NotifierProvider.autoDispose
    .family<TeacherTopicEditController, TeacherTopicEditState, String>(
      TeacherTopicEditController.new,
    );

class TeacherTopicEditController extends Notifier<TeacherTopicEditState> {
  TeacherTopicEditController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherTopicEditRequest? _activeRequest;
  int _operationGeneration = 0;
  int _routeGeneration = 0;
  var _ownsRoute = false;
  var _initialized = false;
  var _pendingTopicNotEditable = false;

  @override
  TeacherTopicEditState build() {
    final key = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(teacherTopicDetailControllerProvider(topicId));
    if (!isCanonicalTeacherTopicId(topicId) ||
        key == null ||
        key.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherTopicEditState.loading();
    }
    if (_activeSessionKey != key) {
      _clearSession();
      _activeSessionKey = key;
    }
    if (!_initialized && detail.topic != null) {
      try {
        final form = TeacherTopicFormValue.fromTopic(
          detail.topic!,
          key.institutionTimezone,
        );
        final initial = TeacherTopicEditSnapshot.fromTopic(
          detail.topic!,
          key.institutionTimezone,
        );
        _initialized = true;
        if (!teacherTopicCanEdit(detail.topic!)) {
          return TeacherTopicEditState.review(
            status: TeacherTopicEditStatus.topicNotEditable,
            topic: detail.topic,
            attemptedDraft: form,
            initial: initial,
            request: TeacherTopicEditRequest.empty(),
            formError:
                'This Topic is no longer editable. Review its current server state.',
          );
        }
        return TeacherTopicEditState.editing(
          topic: detail.topic!,
          form: form,
          initial: initial,
        );
      } catch (_) {
        _initialized = true;
        return const TeacherTopicEditState.unavailable(
          message: 'The Institution timezone is unavailable.',
        );
      }
    }
    if (detail.status == TeacherTopicDetailStatus.notFound && !_initialized) {
      _initialized = true;
      return const TeacherTopicEditState.unavailable();
    }

    return _initialized ? state : const TeacherTopicEditState.loading();
  }

  void enterRoute() {
    if (!_ownsRoute) {
      _ownsRoute = true;
      _routeGeneration += 1;
    }
  }

  void updateTitle(String value) =>
      _update(state.form!.copyWith(title: value), TeacherTopicFormField.title);
  void updateDescription(String value) => _update(
    state.form!.copyWith(description: value),
    TeacherTopicFormField.description,
  );
  void updateSubject(String value) => _update(
    state.form!.copyWith(subject: value),
    TeacherTopicFormField.subject,
  );
  void updateStudentInstructions(String value) => _update(
    state.form!.copyWith(studentInstructions: value),
    TeacherTopicFormField.studentInstructions,
  );
  void updateLessonAt(InstitutionWallClock? value) => _update(
    state.form!.copyWith(lessonAt: value),
    TeacherTopicFormField.lessonAt,
  );

  Future<void> submit() async {
    if (!state.canSave || !_ownsRoute) {
      return;
    }
    final key = _activeSessionKey;
    final topic = state.topic;
    final form = state.form;
    final initial = state.initial;
    if (key == null ||
        topic == null ||
        form == null ||
        initial == null ||
        !_matchesSession(key)) {
      return;
    }
    final errors = <TeacherTopicFormField, String>{
      ...form.validate(
        requireGroup: false,
        institutionTimezone: key.institutionTimezone,
      ),
    }..remove(TeacherTopicFormField.groupId);
    if (errors.isNotEmpty) {
      state = TeacherTopicEditState.validation(
        status: TeacherTopicEditStatus.localValidationFailure,
        topic: topic,
        form: form,
        initial: initial,
        fieldErrors: errors,
        formError: 'Review the highlighted fields.',
      );
      return;
    }
    final request = TeacherTopicEditRequest.fromForm(
      form: form,
      initial: initial,
      institutionTimezone: key.institutionTimezone,
    );
    if (request.isEmpty) {
      state = TeacherTopicEditState.editing(
        topic: topic,
        form: form,
        initial: initial,
        formError: 'No changes to save.',
      );
      return;
    }

    final generation = ++_operationGeneration;
    final routeGeneration = _routeGeneration;
    _activeRequest = request;
    _pendingTopicNotEditable = false;
    state = TeacherTopicEditState.busy(
      status: TeacherTopicEditStatus.submitting,
      topic: topic,
      form: form,
      initial: initial,
      request: request,
    );
    try {
      final updated = await ref
          .read(teacherTopicRepositoryProvider)
          .updateTopic(topicId, request);
      if (!_canPublish(generation, routeGeneration, key, request)) {
        return;
      }
      _publishSuccess(updated, key);
    } on TeacherTopicMutationOutcomeUnknownException {
      await _reconcile(
        generation: generation,
        routeGeneration: routeGeneration,
        key: key,
        request: request,
        topic: topic,
        form: form,
        initial: initial,
        topicNotEditable: false,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, routeGeneration, key, request)) {
        return;
      }
      if (exception.failure.statusCode == 409 &&
          exception.failure.serverCode == ApiErrorCodes.topicNotEditable) {
        _pendingTopicNotEditable = true;
        await _reconcile(
          generation: generation,
          routeGeneration: routeGeneration,
          key: key,
          request: request,
          topic: topic,
          form: form,
          initial: initial,
          topicNotEditable: _pendingTopicNotEditable,
        );
      } else {
        _activeRequest = null;
        _publishDefiniteFailure(topic, form, initial, exception.failure);
      }
    } catch (_) {
      await _reconcile(
        generation: generation,
        routeGeneration: routeGeneration,
        key: key,
        request: request,
        topic: topic,
        form: form,
        initial: initial,
        topicNotEditable: false,
      );
    }
  }

  Future<void> checkCurrentTopic() async {
    final key = _activeSessionKey;
    final request = state.pendingRequest;
    final topic = state.topic;
    final form = state.attemptedDraft;
    final initial = state.initial;
    if (state.status != TeacherTopicEditStatus.outcomeUnknown ||
        key == null ||
        request == null ||
        topic == null ||
        form == null ||
        initial == null ||
        !_ownsRoute ||
        !_matchesSession(key)) {
      return;
    }
    final generation = ++_operationGeneration;
    final routeGeneration = _routeGeneration;
    _activeRequest = request;
    await _reconcile(
      generation: generation,
      routeGeneration: routeGeneration,
      key: key,
      request: request,
      topic: topic,
      form: form,
      initial: initial,
      topicNotEditable: _pendingTopicNotEditable,
    );
  }

  void leaveRoute() {
    _ownsRoute = false;
    _routeGeneration += 1;
    _invalidateOperation();
  }

  Future<void> _reconcile({
    required int generation,
    required int routeGeneration,
    required TeacherSessionKey key,
    required TeacherTopicEditRequest request,
    required TeacherTopic topic,
    required TeacherTopicFormValue form,
    required TeacherTopicEditSnapshot initial,
    required bool topicNotEditable,
  }) async {
    if (!_canPublish(generation, routeGeneration, key, request)) {
      return;
    }
    state = TeacherTopicEditState.busy(
      status: TeacherTopicEditStatus.reconciling,
      topic: topic,
      form: form,
      initial: initial,
      request: request,
    );
    try {
      final current = await ref
          .read(teacherTopicRepositoryProvider)
          .fetchTopic(topicId);
      if (!_canPublish(generation, routeGeneration, key, request)) {
        return;
      }
      ref
          .read(teacherTopicDetailControllerProvider(topicId).notifier)
          .acceptAuthoritativeTopic(current);
      _activeRequest = null;
      if (topicNotEditable) {
        _pendingTopicNotEditable = false;
        state = TeacherTopicEditState.review(
          status: TeacherTopicEditStatus.topicNotEditable,
          topic: current,
          attemptedDraft: form,
          initial: initial,
          request: request,
          formError:
              'This Topic is no longer editable. Review its current server state.',
        );
      } else if (request.matches(current)) {
        _publishSuccess(current, key);
      } else {
        _pendingTopicNotEditable = false;
        state = TeacherTopicEditState.review(
          status: TeacherTopicEditStatus.unconfirmedCurrentState,
          topic: current,
          attemptedDraft: form,
          initial: initial,
          request: request,
          formError:
              'The update result could not be confirmed. Review the current server state.',
        );
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, routeGeneration, key, request)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _activeRequest = null;
        _pendingTopicNotEditable = false;
        ref
            .read(teacherTopicDetailControllerProvider(topicId).notifier)
            .markNotFound();
        state = TeacherTopicEditState.review(
          status: TeacherTopicEditStatus.unavailable,
          topic: null,
          attemptedDraft: form,
          initial: initial,
          request: request,
          formError: 'This Topic is unavailable.',
        );
        return;
      }
      state = TeacherTopicEditState.review(
        status: TeacherTopicEditStatus.outcomeUnknown,
        topic: topic,
        attemptedDraft: form,
        initial: initial,
        request: request,
        formError:
            'The update outcome is unknown. Check the current Topic before taking another action.',
      );
    } catch (_) {
      if (_canPublish(generation, routeGeneration, key, request)) {
        state = TeacherTopicEditState.review(
          status: TeacherTopicEditStatus.outcomeUnknown,
          topic: topic,
          attemptedDraft: form,
          initial: initial,
          request: request,
          formError:
              'The update outcome is unknown. Check the current Topic before taking another action.',
        );
      }
    }
  }

  void _publishSuccess(TeacherTopic topic, TeacherSessionKey key) {
    _activeRequest = null;
    _pendingTopicNotEditable = false;
    ref
        .read(teacherTopicDetailControllerProvider(topicId).notifier)
        .acceptAuthoritativeTopic(topic);
    _markTopicListStale(key);
    state = TeacherTopicEditState.success(topic: topic);
  }

  void _publishDefiniteFailure(
    TeacherTopic topic,
    TeacherTopicFormValue form,
    TeacherTopicEditSnapshot initial,
    ApiFailure failure,
  ) {
    _pendingTopicNotEditable = false;
    if (_clearForSessionFailure(failure)) {
      return;
    }
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      ref
          .read(teacherTopicDetailControllerProvider(topicId).notifier)
          .markNotFound();
      state = TeacherTopicEditState.review(
        status: TeacherTopicEditStatus.unavailable,
        topic: null,
        attemptedDraft: form,
        initial: initial,
        request: TeacherTopicEditRequest.fromForm(
          form: form,
          initial: initial,
          institutionTimezone: _activeSessionKey!.institutionTimezone,
        ),
        formError: 'This Topic is unavailable.',
      );
      return;
    }
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      final errors = <TeacherTopicFormField, String>{};
      var hasUnknown = failure.fieldErrors.isEmpty;
      for (final key in failure.fieldErrors.keys) {
        final field = TeacherTopicFormField.fromRequestKey(key);
        if (field == null || field == TeacherTopicFormField.groupId) {
          hasUnknown = true;
          continue;
        }
        errors[field] = switch (field) {
          TeacherTopicFormField.title => 'Review the Topic title.',
          TeacherTopicFormField.description => 'Review the description.',
          TeacherTopicFormField.subject => 'Review the subject.',
          TeacherTopicFormField.studentInstructions =>
            'Review the student instructions.',
          TeacherTopicFormField.lessonAt => 'Review the lesson date and time.',
          TeacherTopicFormField.groupId => throw StateError('unreachable'),
        };
      }
      state = TeacherTopicEditState.validation(
        status: TeacherTopicEditStatus.serverValidationFailure,
        topic: topic,
        form: form,
        initial: initial,
        fieldErrors: errors,
        formError: hasUnknown ? 'The Topic could not be updated.' : null,
      );
      return;
    }
    final message = switch (failure.serverCode) {
      ApiErrorCodes.forbidden =>
        'You do not have permission to update this Topic.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The Topic could not be updated.',
    };
    state = TeacherTopicEditState.editing(
      topic: topic,
      form: form,
      initial: initial,
      formError: message,
      status: TeacherTopicEditStatus.definiteFailure,
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
    state = const TeacherTopicEditState.loading();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _update(TeacherTopicFormValue form, TeacherTopicFormField field) {
    if (_ownsRoute && state.canEdit) {
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
    TeacherTopicEditRequest request,
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
    _initialized = false;
    _invalidateOperation();
  }

  void _invalidateOperation() {
    _operationGeneration += 1;
    _activeRequest = null;
    _pendingTopicNotEditable = false;
  }
}
