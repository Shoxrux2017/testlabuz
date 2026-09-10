abstract final class ApiErrorCodes {
  static const authenticationRequired = 'authentication_required';
  static const invalidCredentials = 'invalid_credentials';
  static const userInactive = 'user_inactive';
  static const institutionInactive = 'institution_inactive';
  static const passwordChangeRequired = 'password_change_required';
  static const forbidden = 'forbidden';
  static const resourceNotFound = 'resource_not_found';
  static const businessConflict = 'business_conflict';
  static const validationFailed = 'validation_failed';
  static const serverError = 'server_error';
  static const currentPasswordInvalid = 'current_password_invalid';
  static const rateLimited = 'rate_limited';
  static const topicNotEditable = 'topic_not_editable';
  static const topicHasOpenAssessments = 'topic_has_open_assessments';
  static const taskNotActive = 'task_not_active';
  static const taskClosed = 'task_closed';
  static const taskArchived = 'task_archived';
  static const assessmentNotAssigned = 'assessment_not_assigned';
  static const deadlinePassed = 'deadline_passed';
  static const attemptsExhausted = 'attempts_exhausted';
  static const idempotencyKeyReused = 'idempotency_key_reused';
  static const resultPairLocked = 'result_pair_locked';
  static const assessmentHasNoScoreablePoints =
      'assessment_has_no_scoreable_points';
  static const officialTaskRequiresGroupAssignment =
      'official_task_requires_group_assignment';
  static const unsupportedFileType = 'unsupported_file_type';
  static const fileTooLarge = 'file_too_large';
  static const fileUploadFailed = 'file_upload_failed';
  static const fileNotAvailable = 'file_not_available';
}
