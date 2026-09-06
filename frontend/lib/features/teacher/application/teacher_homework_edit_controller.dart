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
import 'teacher_homework_detail_controller.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_homework_edit_state.dart';
import 'teacher_homework_list_controller.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_homework_student_picker_target.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_controller.dart';
import 'teacher_topic_detail_state.dart';

final teacherHomeworkEditControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherHomeworkEditController,
      TeacherHomeworkEditState,
      TeacherHomeworkRouteTarget
    >(TeacherHomeworkEditController.new);

class TeacherHomeworkEditController extends Notifier<TeacherHomeworkEditState> {
  TeacherHomeworkEditController(this.target);

  final TeacherHomeworkRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  TeacherHomeworkEditRequest? _activeRequest;
  TeacherHomeworkStudentPickerOwner? _activePickerOwner;
  int _operationGeneration = 0;
  int _routeGeneration = 0;
  int _studentPickerGeneration = 0;
  var _ownsRoute = false;
  var _initialized = false;

  @override
  TeacherHomeworkEditState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final topicDetail = ref.watch(
      teacherTopicDetailControllerProvider(target.topicId),
    );
    final homeworkDetail = ref.watch(
      teacherHomeworkDetailControllerProvider(target),
    );
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return TeacherHomeworkEditState.loading();
    }
    if (_activeSessionKey != sessionKey) {
      _clearSession();
      _activeSessionKey = sessionKey;
    }
    if (_initialized) {
      return _reconcileInitializedDetails(
        sessionKey: sessionKey,
        topicDetail: topicDetail,
        homeworkDetail: homeworkDetail,
      );
    }

    if (topicDetail.status == TeacherTopicDetailStatus.notFound ||
        homeworkDetail.status == TeacherHomeworkDetailStatus.notFound) {
      _initialized = true;
      return TeacherHomeworkEditState.review(
        status: TeacherHomeworkEditStatus.unavailable,
        topic: null,
        homework: null,
        attemptedDraft: null,
        initial: null,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: const {},
        request: null,
        formError:
            'This Homework is no longer available in your current Teacher workspace.',
      );
    }
    if (topicDetail.status == TeacherTopicDetailStatus.error ||
        homeworkDetail.status == TeacherHomeworkDetailStatus.error) {
      return TeacherHomeworkEditState.initialLoadError(
        topicDetail.failure ??
            homeworkDetail.failure ??
            _unexpectedHomeworkFailure(),
      );
    }

    final topic = topicDetail.topic;
    final homework = homeworkDetail.homework;
    if (topic == null ||
        homework == null ||
        homeworkDetail.isStale ||
        homework.topicId.toLowerCase() != target.topicId.toLowerCase() ||
        homework.id.toLowerCase() != target.homeworkId.toLowerCase()) {
      return TeacherHomeworkEditState.loading();
    }

    try {
      final form = TeacherHomeworkFormValue.fromHomework(
        homework,
        sessionKey.institutionTimezone,
      );
      final initial = TeacherHomeworkEditSnapshot.fromHomework(homework);
      _initialized = true;
      if (homework.status == TeacherHomeworkStatus.closed ||
          homework.status == TeacherHomeworkStatus.archived) {
        final status = homework.status == TeacherHomeworkStatus.closed
            ? TeacherHomeworkEditStatus.taskClosed
            : TeacherHomeworkEditStatus.taskArchived;
        return TeacherHomeworkEditState.review(
          status: status,
          topic: topic,
          homework: homework,
          attemptedDraft: null,
          initial: initial,
          institutionTimezone: sessionKey.institutionTimezone,
          rememberedSelectedIds: form.selectedStudentIds,
          request: null,
          formError: 'This Homework is no longer editable.',
        );
      }
      return TeacherHomeworkEditState.editing(
        topic: topic,
        homework: homework,
        form: form,
        initial: initial,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: form.selectedStudentIds,
      );
    } catch (_) {
      _initialized = true;
      return TeacherHomeworkEditState.review(
        status: TeacherHomeworkEditStatus.unavailable,
        topic: topic,
        homework: homework,
        attemptedDraft: null,
        initial: null,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: const {},
        request: null,
        formError: 'The Institution timezone is unavailable.',
      );
    }
  }

  TeacherHomeworkEditState _reconcileInitializedDetails({
    required TeacherSessionKey sessionKey,
    required TeacherTopicDetailState topicDetail,
    required TeacherHomeworkDetailState homeworkDetail,
  }) {
    final currentTopic = topicDetail.topic;
    final preservesUnresolvedMutation =
        state.isBusy ||
        state.status == TeacherHomeworkEditStatus.outcomeUnknown ||
        state.status == TeacherHomeworkEditStatus.confirmedSuccess;
    if (preservesUnresolvedMutation) {
      return currentTopic == null ? state : state.withTopic(currentTopic);
    }

    if (topicDetail.status == TeacherTopicDetailStatus.notFound ||
        homeworkDetail.status == TeacherHomeworkDetailStatus.notFound) {
      return TeacherHomeworkEditState.review(
        status: TeacherHomeworkEditStatus.unavailable,
        topic: null,
        homework: null,
        attemptedDraft: null,
        initial: null,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: const {},
        request: null,
        formError:
            'This Homework is no longer available in your current Teacher workspace.',
      );
    }
    if (state.isReviewOnly) {
      return currentTopic == null ? state : state.withTopic(currentTopic);
    }
    if (currentTopic == null) {
      return state;
    }

    final currentHomework = homeworkDetail.homework;
    if (homeworkDetail.status != TeacherHomeworkDetailStatus.data ||
        homeworkDetail.isStale ||
        currentHomework == null) {
      return state.withTopic(currentTopic);
    }
    if (!_matchesTarget(currentHomework)) {
      return TeacherHomeworkEditState.review(
        status: TeacherHomeworkEditStatus.unavailable,
        topic: null,
        homework: null,
        attemptedDraft: null,
        initial: null,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: const {},
        request: null,
        formError:
            'This Homework is no longer available in your current Teacher workspace.',
      );
    }
    if (currentHomework.status == TeacherHomeworkStatus.closed ||
        currentHomework.status == TeacherHomeworkStatus.archived) {
      return TeacherHomeworkEditState.review(
        status: currentHomework.status == TeacherHomeworkStatus.closed
            ? TeacherHomeworkEditStatus.taskClosed
            : TeacherHomeworkEditStatus.taskArchived,
        topic: currentTopic,
        homework: currentHomework,
        attemptedDraft: null,
        initial: TeacherHomeworkEditSnapshot.fromHomework(currentHomework),
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: currentHomework.studentIds.toSet(),
        request: null,
        formError: 'This Homework is no longer editable.',
      );
    }
    if (state.isDirty) {
      return state.withAuthoritativeContext(
        topic: currentTopic,
        homework: currentHomework,
      );
    }

    try {
      final form = TeacherHomeworkFormValue.fromHomework(
        currentHomework,
        sessionKey.institutionTimezone,
      );
      return TeacherHomeworkEditState.editing(
        topic: currentTopic,
        homework: currentHomework,
        form: form,
        initial: TeacherHomeworkEditSnapshot.fromHomework(currentHomework),
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: form.selectedStudentIds,
      );
    } catch (_) {
      return TeacherHomeworkEditState.review(
        status: TeacherHomeworkEditStatus.unavailable,
        topic: currentTopic,
        homework: currentHomework,
        attemptedDraft: null,
        initial: null,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: const {},
        request: null,
        formError: 'The Institution timezone is unavailable.',
      );
    }
  }

  void enterRoute() {
    if (!_ownsRoute) {
      _ownsRoute = true;
      _routeGeneration += 1;
    }
  }

  void retryInitialLoad() {
    final sessionKey = _activeSessionKey;
    if (state.status != TeacherHomeworkEditStatus.initialLoadError ||
        sessionKey == null ||
        !_ownsRoute ||
        !_matchesSession(sessionKey)) {
      return;
    }
    final topicProvider = teacherTopicDetailControllerProvider(target.topicId);
    final homeworkProvider = teacherHomeworkDetailControllerProvider(target);
    if (ref.read(topicProvider).status == TeacherTopicDetailStatus.error) {
      ref.read(topicProvider.notifier).refresh();
    }
    if (ref.read(homeworkProvider).status ==
        TeacherHomeworkDetailStatus.error) {
      ref.read(homeworkProvider.notifier).retry();
    }
  }

  void updateTitle(String value) {
    final form = state.form;
    if (form != null) {
      _update(form.copyWith(title: value), const {
        TeacherHomeworkFormField.title,
      });
    }
  }

  void updateDescription(String value) {
    final form = state.form;
    if (form != null) {
      _update(form.copyWith(description: value), const {
        TeacherHomeworkFormField.description,
      });
    }
  }

  void updateStudentInstructions(String value) {
    final form = state.form;
    if (form != null) {
      _update(form.copyWith(studentInstructions: value), const {
        TeacherHomeworkFormField.studentInstructions,
      });
    }
  }

  void updateAssignmentMode(TeacherHomeworkAssignmentMode mode) {
    final form = state.form;
    if (!state.canEdit || form == null || form.assignmentMode == mode) {
      return;
    }
    var remembered = state.rememberedSelectedIds;
    late final Set<String> resultingSelection;
    if (mode == TeacherHomeworkAssignmentMode.group) {
      remembered = form.selectedStudentIds;
      resultingSelection = const {};
    } else {
      resultingSelection = remembered;
    }
    _update(
      form.copyWith(
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
    final form = state.form;
    if (form == null ||
        form.assignmentMode != TeacherHomeworkAssignmentMode.selectedStudents) {
      return;
    }
    try {
      final next = form.copyWith(selectedStudentIds: studentIds);
      _update(next, const {
        TeacherHomeworkFormField.studentIds,
      }, rememberedSelectedIds: next.selectedStudentIds);
    } on ArgumentError {
      return;
    }
  }

  void updateDeadlineAt(InstitutionWallClock? value) {
    final form = state.form;
    if (form != null) {
      _update(form.copyWith(deadlineWallClock: value), const {
        TeacherHomeworkFormField.deadlineAt,
      });
    }
  }

  TeacherHomeworkStudentPickerLaunch? beginStudentPicker() {
    final sessionKey = _activeSessionKey;
    final form = state.form;
    final currentTopic = _confirmedCurrentTopic();
    if (!_ownsRoute ||
        !state.canEdit ||
        form == null ||
        form.assignmentMode != TeacherHomeworkAssignmentMode.selectedStudents ||
        sessionKey == null ||
        currentTopic == null ||
        !_matchesSession(sessionKey)) {
      return null;
    }
    final owner = (
      sessionKey: sessionKey,
      groupId: currentTopic.group.id,
      routeGeneration: _routeGeneration,
      pickerGeneration: ++_studentPickerGeneration,
    );
    _activePickerOwner = owner;
    return (
      target: TeacherHomeworkStudentPickerTarget(
        groupId: currentTopic.group.id,
        initialSelectedIds: form.selectedStudentIds,
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
    if (!state.canEdit || !_ownsRoute) {
      return;
    }
    final sessionKey = _activeSessionKey;
    final topic = _confirmedCurrentTopic();
    final homework = state.homework;
    final form = state.form;
    final initial = state.initial;
    if (sessionKey == null ||
        topic == null ||
        homework == null ||
        form == null ||
        initial == null ||
        !_matchesSession(sessionKey)) {
      return;
    }

    final errors = form.validate(
      institutionTimezone: sessionKey.institutionTimezone,
    );
    if (errors.isNotEmpty) {
      state = TeacherHomeworkEditState.validation(
        status: TeacherHomeworkEditStatus.localValidationFailure,
        topic: topic,
        homework: homework,
        form: form,
        initial: initial,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: state.rememberedSelectedIds,
        fieldErrors: errors,
        formError: 'Review the highlighted fields.',
      );
      return;
    }

    final request = TeacherHomeworkEditRequest.fromForm(
      form: form,
      initial: initial,
      institutionTimezone: sessionKey.institutionTimezone,
    );
    if (request.isEmpty) {
      state = TeacherHomeworkEditState.editing(
        topic: topic,
        homework: homework,
        form: form,
        initial: initial,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: state.rememberedSelectedIds,
        formError: 'No changes to save.',
      );
      return;
    }

    final generation = ++_operationGeneration;
    final routeGeneration = _routeGeneration;
    _activeRequest = request;
    _activePickerOwner = null;
    state = TeacherHomeworkEditState.busy(
      status: TeacherHomeworkEditStatus.submitting,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: sessionKey.institutionTimezone,
      rememberedSelectedIds: state.rememberedSelectedIds,
      request: request,
    );
    try {
      final updated = await ref
          .read(teacherHomeworkRepositoryProvider)
          .updateHomework(target.homeworkId, request);
      if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
        return;
      }
      if (!_matchesTarget(updated)) {
        await _reconcile(
          generation: generation,
          routeGeneration: routeGeneration,
          sessionKey: sessionKey,
          request: request,
          topic: topic,
          homework: homework,
          form: form,
          initial: initial,
          rememberedSelectedIds: state.rememberedSelectedIds,
        );
        return;
      }
      _publishSuccess(topic, updated, sessionKey);
    } on TeacherHomeworkMutationOutcomeUnknownException {
      await _reconcile(
        generation: generation,
        routeGeneration: routeGeneration,
        sessionKey: sessionKey,
        request: request,
        topic: topic,
        homework: homework,
        form: form,
        initial: initial,
        rememberedSelectedIds: state.rememberedSelectedIds,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (_isRecognizedConflict(exception.failure)) {
        await _reconcile(
          generation: generation,
          routeGeneration: routeGeneration,
          sessionKey: sessionKey,
          request: request,
          topic: topic,
          homework: homework,
          form: form,
          initial: initial,
          rememberedSelectedIds: state.rememberedSelectedIds,
          conflictCode: exception.failure.serverCode,
        );
        return;
      }
      _activeRequest = null;
      _publishDefiniteFailure(
        topic: topic,
        homework: homework,
        form: form,
        initial: initial,
        rememberedSelectedIds: state.rememberedSelectedIds,
        sessionKey: sessionKey,
        failure: exception.failure,
      );
    } catch (_) {
      await _reconcile(
        generation: generation,
        routeGeneration: routeGeneration,
        sessionKey: sessionKey,
        request: request,
        topic: topic,
        homework: homework,
        form: form,
        initial: initial,
        rememberedSelectedIds: state.rememberedSelectedIds,
      );
    }
  }

  Future<void> checkCurrentHomework() async {
    final sessionKey = _activeSessionKey;
    final request = state.pendingRequest;
    final topic = state.topic;
    final homework = state.homework;
    final form = state.attemptedDraft;
    final initial = state.initial;
    if (state.status != TeacherHomeworkEditStatus.outcomeUnknown ||
        sessionKey == null ||
        request == null ||
        topic == null ||
        homework == null ||
        form == null ||
        initial == null ||
        !_ownsRoute ||
        !_matchesSession(sessionKey)) {
      return;
    }
    final generation = ++_operationGeneration;
    final routeGeneration = _routeGeneration;
    _activeRequest = request;
    await _reconcile(
      generation: generation,
      routeGeneration: routeGeneration,
      sessionKey: sessionKey,
      request: request,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      rememberedSelectedIds: state.rememberedSelectedIds,
      conflictCode: state.reconciliationConflictCode,
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
    required TeacherSessionKey sessionKey,
    required TeacherHomeworkEditRequest request,
    required TeacherTopic topic,
    required TeacherHomework homework,
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required Set<String> rememberedSelectedIds,
    String? conflictCode,
  }) async {
    if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
      return;
    }
    state = TeacherHomeworkEditState.busy(
      status: TeacherHomeworkEditStatus.reconciling,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: sessionKey.institutionTimezone,
      rememberedSelectedIds: rememberedSelectedIds,
      request: request,
      conflictCode: conflictCode,
    );
    try {
      final current = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.homeworkId);
      if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
        return;
      }
      if (!_matchesTarget(current)) {
        _publishUnavailableAfterMutation(
          topic: topic,
          homework: homework,
          form: form,
          initial: initial,
          rememberedSelectedIds: rememberedSelectedIds,
          request: request,
          sessionKey: sessionKey,
        );
        return;
      }
      if (conflictCode != null) {
        _acceptReconciledHomework(current, sessionKey);
        state = TeacherHomeworkEditState.review(
          status: _conflictStatus(conflictCode),
          topic: _confirmedCurrentTopic() ?? topic,
          homework: current,
          attemptedDraft: form,
          initial: initial,
          institutionTimezone: sessionKey.institutionTimezone,
          rememberedSelectedIds: rememberedSelectedIds,
          request: request,
          conflictCode: conflictCode,
          formError: _conflictMessage(conflictCode),
        );
      } else if (request.matches(current)) {
        _publishSuccess(_confirmedCurrentTopic() ?? topic, current, sessionKey);
      } else {
        _acceptReconciledHomework(current, sessionKey);
        state = TeacherHomeworkEditState.review(
          status: TeacherHomeworkEditStatus.unconfirmedCurrentState,
          topic: _confirmedCurrentTopic() ?? topic,
          homework: current,
          attemptedDraft: form,
          initial: initial,
          institutionTimezone: sessionKey.institutionTimezone,
          rememberedSelectedIds: rememberedSelectedIds,
          request: request,
          formError:
              'The update result could not be confirmed. Review the current server state before trying again.',
        );
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, routeGeneration, sessionKey, request)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _publishUnavailableAfterMutation(
          topic: topic,
          homework: homework,
          form: form,
          initial: initial,
          rememberedSelectedIds: rememberedSelectedIds,
          request: request,
          sessionKey: sessionKey,
        );
        return;
      }
      _activeRequest = null;
      state = TeacherHomeworkEditState.review(
        status: TeacherHomeworkEditStatus.outcomeUnknown,
        topic: topic,
        homework: homework,
        attemptedDraft: form,
        initial: initial,
        institutionTimezone: sessionKey.institutionTimezone,
        rememberedSelectedIds: rememberedSelectedIds,
        request: request,
        conflictCode: conflictCode,
        formError:
            'The current Homework could not be confirmed. Check the current Homework before taking another action.',
      );
    } catch (_) {
      if (_canPublish(generation, routeGeneration, sessionKey, request)) {
        _activeRequest = null;
        state = TeacherHomeworkEditState.review(
          status: TeacherHomeworkEditStatus.outcomeUnknown,
          topic: topic,
          homework: homework,
          attemptedDraft: form,
          initial: initial,
          institutionTimezone: sessionKey.institutionTimezone,
          rememberedSelectedIds: rememberedSelectedIds,
          request: request,
          conflictCode: conflictCode,
          formError:
              'The current Homework could not be confirmed. Check the current Homework before taking another action.',
        );
      }
    }
  }

  void _publishSuccess(
    TeacherTopic topic,
    TeacherHomework homework,
    TeacherSessionKey sessionKey,
  ) {
    final form = TeacherHomeworkFormValue.fromHomework(
      homework,
      sessionKey.institutionTimezone,
    );
    final initial = TeacherHomeworkEditSnapshot.fromHomework(homework);
    _activeRequest = null;
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .acceptAuthoritativeHomework(homework, sessionKey);
    _refreshHomeworkList(sessionKey);
    state = TeacherHomeworkEditState.success(
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: sessionKey.institutionTimezone,
    );
  }

  void _acceptReconciledHomework(
    TeacherHomework homework,
    TeacherSessionKey sessionKey,
  ) {
    _activeRequest = null;
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .acceptAuthoritativeHomework(homework, sessionKey);
    _refreshHomeworkList(sessionKey);
  }

  void _publishDefiniteFailure({
    required TeacherTopic topic,
    required TeacherHomework homework,
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required Set<String> rememberedSelectedIds,
    required TeacherSessionKey sessionKey,
    required ApiFailure failure,
  }) {
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      _publishUnavailableAfterMutation(
        topic: topic,
        homework: homework,
        form: form,
        initial: initial,
        rememberedSelectedIds: rememberedSelectedIds,
        request: TeacherHomeworkEditRequest.fromForm(
          form: form,
          initial: initial,
          institutionTimezone: sessionKey.institutionTimezone,
        ),
        sessionKey: sessionKey,
      );
      return;
    }
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      _publishValidation(
        topic: topic,
        homework: homework,
        form: form,
        initial: initial,
        rememberedSelectedIds: rememberedSelectedIds,
        sessionKey: sessionKey,
        serverErrors: failure.fieldErrors,
      );
      return;
    }
    final message = switch (failure.serverCode) {
      ApiErrorCodes.forbidden =>
        'You do not have permission to update this Homework.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The Homework could not be updated.',
    };
    state = TeacherHomeworkEditState.editing(
      status: TeacherHomeworkEditStatus.definiteFailure,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: sessionKey.institutionTimezone,
      rememberedSelectedIds: rememberedSelectedIds,
      formError: message,
    );
  }

  void _publishValidation({
    required TeacherTopic topic,
    required TeacherHomework homework,
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required Set<String> rememberedSelectedIds,
    required TeacherSessionKey sessionKey,
    required Map<String, List<String>> serverErrors,
  }) {
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
    state = TeacherHomeworkEditState.validation(
      status: TeacherHomeworkEditStatus.serverValidationFailure,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: sessionKey.institutionTimezone,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: errors,
      formError: hasUnknown ? 'The Homework could not be updated.' : null,
    );
  }

  void _publishUnavailableAfterMutation({
    required TeacherTopic topic,
    required TeacherHomework homework,
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required Set<String> rememberedSelectedIds,
    required TeacherHomeworkEditRequest request,
    required TeacherSessionKey sessionKey,
  }) {
    _activeRequest = null;
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .markNotFound(sessionKey);
    _refreshHomeworkList(sessionKey);
    state = TeacherHomeworkEditState.review(
      status: TeacherHomeworkEditStatus.unavailable,
      topic: topic,
      homework: null,
      attemptedDraft: form,
      initial: initial,
      institutionTimezone: sessionKey.institutionTimezone,
      rememberedSelectedIds: rememberedSelectedIds,
      request: request,
      formError:
          'This Homework is no longer available in your current Teacher workspace.',
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
    final detail = ref.read(
      teacherTopicDetailControllerProvider(target.topicId),
    );
    final topic = detail.topic;
    if (topic == null ||
        topic.id.toLowerCase() != target.topicId.toLowerCase()) {
      return null;
    }
    return topic;
  }

  void _refreshHomeworkList(TeacherSessionKey sessionKey) {
    final provider = teacherHomeworkListControllerProvider(target.topicId);
    if (ref.exists(provider)) {
      ref.read(provider.notifier).refreshAfterMutation(sessionKey);
    } else {
      ref.invalidate(provider);
    }
  }

  bool _matchesTarget(TeacherHomework homework) {
    return homework.id.toLowerCase() == target.homeworkId.toLowerCase() &&
        homework.topicId.toLowerCase() == target.topicId.toLowerCase();
  }

  bool _canPublish(
    int generation,
    int routeGeneration,
    TeacherSessionKey sessionKey,
    TeacherHomeworkEditRequest request,
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
    state = TeacherHomeworkEditState.loading();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  bool _isRecognizedConflict(ApiFailure failure) {
    if (failure.statusCode != 409) {
      return false;
    }
    return switch (failure.serverCode) {
      ApiErrorCodes.topicNotEditable ||
      ApiErrorCodes.taskClosed ||
      ApiErrorCodes.taskArchived ||
      ApiErrorCodes.businessConflict ||
      ApiErrorCodes.officialTaskRequiresGroupAssignment => true,
      _ => false,
    };
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

TeacherHomeworkEditStatus _conflictStatus(String conflictCode) {
  return switch (conflictCode) {
    ApiErrorCodes.taskClosed => TeacherHomeworkEditStatus.taskClosed,
    ApiErrorCodes.taskArchived => TeacherHomeworkEditStatus.taskArchived,
    ApiErrorCodes.topicNotEditable =>
      TeacherHomeworkEditStatus.topicNotEditable,
    ApiErrorCodes.businessConflict =>
      TeacherHomeworkEditStatus.businessConflict,
    ApiErrorCodes.officialTaskRequiresGroupAssignment =>
      TeacherHomeworkEditStatus.officialTaskRequiresGroupAssignment,
    _ => TeacherHomeworkEditStatus.definiteFailure,
  };
}

String _conflictMessage(String conflictCode) {
  return switch (conflictCode) {
    ApiErrorCodes.taskClosed => 'This Homework is closed and cannot be edited.',
    ApiErrorCodes.taskArchived =>
      'This Homework is archived and cannot be edited.',
    ApiErrorCodes.topicNotEditable => 'The Topic is no longer editable.',
    ApiErrorCodes.businessConflict =>
      'Some Homework settings are locked by current server state. Review the current Homework before making another change.',
    ApiErrorCodes.officialTaskRequiresGroupAssignment =>
      'The official Homework must remain assigned to the whole group.',
    _ => 'The Homework could not be updated.',
  };
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

ApiFailure _unexpectedHomeworkFailure() {
  return ApiFailure.local(
    kind: ApiFailureKind.unknown,
    message: 'Unexpected Teacher Homework authoring detail failure.',
  );
}
