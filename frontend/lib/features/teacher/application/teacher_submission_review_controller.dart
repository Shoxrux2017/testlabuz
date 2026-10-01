import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_submission_repository_impl.dart';
import '../domain/teacher_official_score.dart';
import '../domain/teacher_submission.dart';
import '../domain/teacher_submission_detail.dart';
import '../domain/teacher_submission_review.dart';
import 'teacher_blitz_detail_controller.dart';
import 'teacher_blitz_route_target.dart';
import 'teacher_homework_detail_controller.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_official_score_controller.dart';
import 'teacher_review_queue_controller.dart';
import 'teacher_review_queue_scope.dart';
import 'teacher_session_key.dart';
import 'teacher_submission_detail_controller.dart';
import 'teacher_submission_detail_state.dart';
import 'teacher_submission_review_state.dart';

final teacherSubmissionReviewControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherSubmissionReviewController,
      TeacherSubmissionReviewState,
      String
    >(TeacherSubmissionReviewController.new);

const _savedFeedback = 'Review saved.';
const _notMatchingMessage =
    'The review could not be confirmed. Check the answers and save again.';
const _unconfirmedMessage =
    'The review could not be confirmed. Save again or refresh the submission.';

final _itemErrorKey = RegExp(
  r'^answers\.(\d+)\.(answer_id|awarded_points|feedback)$',
);

/// Saves the Teacher's points and feedback for the changed answers of one
/// submission, and corrects reviewed ones (`S09-FE-003B`); desktop only.
///
/// The request holds absolute values, so an unconfirmed save may be sent
/// again safely.
class TeacherSubmissionReviewController
    extends Notifier<TeacherSubmissionReviewState> {
  TeacherSubmissionReviewController(this.submissionId);

  final String submissionId;
  TeacherSessionKey? _activeSessionKey;
  var _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherSubmissionReviewState build() {
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
      return const TeacherSubmissionReviewState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }
    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherSubmissionReviewState();
  }

  void editPoints(String answerId, String text) {
    final draft = state.drafts[answerId] ?? const TeacherAnswerReviewDraft();
    _edit(answerId, draft.withPoints(text));
  }

  void editFeedback(String answerId, String text) {
    final draft = state.drafts[answerId] ?? const TeacherAnswerReviewDraft();
    _edit(answerId, draft.withFeedback(text));
  }

  void discardChanges() {
    if (state.isBusy || _activeSessionKey == null) {
      return;
    }
    state = const TeacherSubmissionReviewState();
  }

  void consumeFeedback() {
    if (state.successFeedback != null) {
      state = TeacherSubmissionReviewState(
        status: state.status,
        drafts: state.drafts,
        errors: state.errors,
        failureMessage: state.failureMessage,
      );
    }
  }

  Future<void> save() async {
    final sessionKey = _activeSessionKey;
    final detailState = ref.read(
      teacherSubmissionDetailControllerProvider(submissionId),
    );
    final detail = detailState.detail;
    if (state.isBusy ||
        sessionKey == null ||
        !_matchesSession(sessionKey) ||
        detailState.status != TeacherSubmissionDetailStatus.data ||
        detail == null) {
      return;
    }

    final review = buildTeacherSubmissionReview(detail, state.drafts);
    if (review.changedCount == 0) {
      return;
    }
    if (review.errors.isNotEmpty) {
      state = TeacherSubmissionReviewState(
        drafts: state.drafts,
        errors: review.errors,
      );
      return;
    }

    final request = TeacherSubmissionReviewRequest(review.items);
    final submission = detail.submission;
    final generation = ++_generation;
    state = TeacherSubmissionReviewState(
      status: TeacherSubmissionReviewStatus.saving,
      drafts: state.drafts,
    );
    // The outcome is decided first, so a failure while publishing a
    // confirmed save can never turn it into a reconcile.
    TeacherSubmissionDetail? confirmed;
    try {
      final returned = await ref
          .read(teacherSubmissionRepositoryProvider)
          .saveReview(submissionId, request);
      if (_isRequested(returned) && request.matches(returned)) {
        confirmed = returned;
      }
    } on TeacherSubmissionReviewOutcomeUnknownException {
      // Reconciled below.
    } on ApiRequestException catch (exception) {
      if (_canPublish(generation, sessionKey)) {
        _publishDefiniteFailure(
          sessionKey,
          request,
          submission,
          exception.failure,
        );
      }
      return;
    } catch (_) {
      // Reconciled below.
    }
    if (!_canPublish(generation, sessionKey)) {
      return;
    }
    if (confirmed != null) {
      _publishSuccess(confirmed, sessionKey);
      return;
    }
    await _reconcile(generation, sessionKey, request, submission);
  }

  void _edit(String answerId, TeacherAnswerReviewDraft draft) {
    if (state.isBusy || _activeSessionKey == null) {
      return;
    }
    state = TeacherSubmissionReviewState(
      drafts: {...state.drafts, answerId: draft},
      errors: {...state.errors}..remove(answerId),
      successFeedback: state.successFeedback,
    );
  }

  Future<void> _reconcile(
    int generation,
    TeacherSessionKey sessionKey,
    TeacherSubmissionReviewRequest request,
    TeacherSubmission submission,
  ) async {
    if (!_canPublish(generation, sessionKey)) {
      return;
    }
    state = TeacherSubmissionReviewState(
      status: TeacherSubmissionReviewStatus.reconciling,
      drafts: state.drafts,
    );
    TeacherSubmissionDetail? current;
    try {
      current = await ref
          .read(teacherSubmissionRepositoryProvider)
          .fetchSubmission(submissionId);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      if (_isNotFound(exception.failure)) {
        _publishNotFound(sessionKey, submission);
        return;
      }
    } catch (_) {
      // Unconfirmed below.
    }
    if (!_canPublish(generation, sessionKey)) {
      return;
    }
    if (current != null && request.matches(current)) {
      _publishSuccess(current, sessionKey);
      return;
    }
    if (current != null) {
      _detailController.acceptAuthoritativeDetail(current, sessionKey);
    }
    _publishFailure(
      current == null ? _unconfirmedMessage : _notMatchingMessage,
    );
    // The save may still have committed.
    _refreshRelatedViews(submission);
  }

  void _publishSuccess(
    TeacherSubmissionDetail detail,
    TeacherSessionKey sessionKey,
  ) {
    _detailController.acceptAuthoritativeDetail(detail, sessionKey);
    state = const TeacherSubmissionReviewState(successFeedback: _savedFeedback);
    _refreshRelatedViews(detail.submission);
  }

  void _publishDefiniteFailure(
    TeacherSessionKey sessionKey,
    TeacherSubmissionReviewRequest request,
    TeacherSubmission submission,
    ApiFailure failure,
  ) {
    if (_clearForSessionFailure(failure)) {
      return;
    }
    if (_isNotFound(failure)) {
      _publishNotFound(sessionKey, submission);
      return;
    }
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      final errors = _itemErrors(request, failure.fieldErrors);
      state = TeacherSubmissionReviewState(
        drafts: state.drafts,
        errors: errors,
        failureMessage: errors.isEmpty
            ? 'The review could not be validated. Refresh and try again.'
            : 'Some answers were not saved. Check the marked fields.',
      );
      return;
    }
    _publishFailure(switch (failure.serverCode) {
      ApiErrorCodes.automaticCheckingPending =>
        'This submission is still waiting for automatic checking. Try again later.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to review this submission.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The review could not be saved. Try again.',
    });
  }

  void _publishFailure(String message) {
    state = TeacherSubmissionReviewState(
      drafts: state.drafts,
      failureMessage: message,
    );
  }

  void _publishNotFound(
    TeacherSessionKey sessionKey,
    TeacherSubmission submission,
  ) {
    _detailController.markNotFound(sessionKey);
    state = const TeacherSubmissionReviewState();
    _refreshRelatedViews(submission);
  }

  /// Maps `answers.N.<field>` errors to the answer of sent item N.
  Map<String, TeacherAnswerReviewErrors> _itemErrors(
    TeacherSubmissionReviewRequest request,
    Map<String, List<String>> fieldErrors,
  ) {
    final errors = <String, TeacherAnswerReviewErrors>{};
    for (final key in fieldErrors.keys) {
      final match = _itemErrorKey.firstMatch(key);
      final index = match == null ? null : int.tryParse(match.group(1)!);
      if (match == null || index == null || index >= request.items.length) {
        continue;
      }
      final answerId = request.items[index].answerId;
      final current = errors[answerId] ?? const TeacherAnswerReviewErrors();
      errors[answerId] = switch (match.group(2)) {
        'awarded_points' => TeacherAnswerReviewErrors(
          points: TeacherReviewPointsError.invalid,
          feedbackTooLong: current.feedbackTooLong,
          notReviewable: current.notReviewable,
        ),
        'feedback' => TeacherAnswerReviewErrors(
          points: current.points,
          feedbackTooLong: true,
          notReviewable: current.notReviewable,
        ),
        _ => TeacherAnswerReviewErrors(
          points: current.points,
          feedbackTooLong: current.feedbackTooLong,
          notReviewable: true,
        ),
      };
    }
    return errors;
  }

  /// Views below the detail in the route stack keep their filters and page.
  void _refreshRelatedViews(TeacherSubmission submission) {
    final queues = [
      TeacherReviewQueueScope.all,
      TeacherReviewQueueScope.task(
        topicId: submission.topicId,
        assessmentId: submission.assessmentId,
        type: submission.taskType,
      ),
    ];
    for (final scope in queues) {
      final provider = teacherReviewQueueControllerProvider(scope);
      if (ref.exists(provider)) {
        ref.read(provider.notifier).refresh();
      }
    }
    final officialScore = teacherOfficialScoreControllerProvider(
      TeacherOfficialScoreTarget.ofSubmission(submission),
    );
    if (ref.exists(officialScore)) {
      ref.read(officialScore.notifier).refresh();
    }
    switch (submission.taskType) {
      case TeacherSubmissionTaskType.homework:
        final provider = teacherHomeworkDetailControllerProvider(
          TeacherHomeworkRouteTarget(
            topicId: submission.topicId,
            homeworkId: submission.assessmentId,
          ),
        );
        if (ref.exists(provider)) {
          ref.read(provider.notifier).refresh();
        }
      case TeacherSubmissionTaskType.blitz:
        final provider = teacherBlitzDetailControllerProvider(
          TeacherBlitzRouteTarget(
            topicId: submission.topicId,
            blitzId: submission.assessmentId,
          ),
        );
        if (ref.exists(provider)) {
          ref.read(provider.notifier).refresh();
        }
    }
  }

  TeacherSubmissionDetailController get _detailController => ref.read(
    teacherSubmissionDetailControllerProvider(submissionId).notifier,
  );

  bool _isRequested(TeacherSubmissionDetail detail) =>
      detail.submission.id.toLowerCase() == submissionId.toLowerCase();

  bool _isNotFound(ApiFailure failure) =>
      failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound;

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

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearSession();
    state = const TeacherSubmissionReviewState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearSession() {
    _generation += 1;
    _activeSessionKey = null;
  }
}
