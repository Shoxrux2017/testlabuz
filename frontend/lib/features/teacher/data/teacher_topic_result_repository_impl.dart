import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/teacher_topic_result.dart';
import '../domain/teacher_topic_result_list.dart';
import '../domain/teacher_topic_result_mutation.dart';
import '../domain/teacher_topic_result_repository.dart';
import 'teacher_topic_result_remote_data_source.dart';

final teacherTopicResultRepositoryProvider =
    Provider<TeacherTopicResultRepository>((ref) {
      return TeacherTopicResultRepositoryImpl(
        remoteDataSource: ref.watch(teacherTopicResultRemoteDataSourceProvider),
      );
    });

class TeacherTopicResultRepositoryImpl implements TeacherTopicResultRepository {
  const TeacherTopicResultRepositoryImpl({required this.remoteDataSource});

  final TeacherTopicResultRemoteDataSource remoteDataSource;

  @override
  Future<TeacherTopicResultList> fetchResults(
    String topicId,
    TeacherTopicResultListQuery query,
  ) {
    return remoteDataSource.fetchResults(topicId, query);
  }

  @override
  Future<TeacherTopicResultDetail> fetchResult(
    String topicId,
    String studentId,
  ) async {
    final detail = await remoteDataSource.fetchResult(topicId, studentId);
    if (detail.result.studentId.toLowerCase() != studentId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Teacher Topic result Student does not match the request.',
        ),
      );
    }
    return detail;
  }

  @override
  Future<TeacherTopicResultDetail> updateComment(
    String topicId,
    String studentId,
    String comment,
  ) async {
    final trimmed = comment.trim();
    final saved = trimmed.isEmpty ? null : trimmed;
    final detail = await remoteDataSource.updateComment(
      topicId,
      studentId,
      saved,
    );
    _requireConfirmed(
      detail,
      studentId,
      confirmed: detail.result.teacherComment == saved,
    );
    return detail;
  }

  @override
  Future<TeacherTopicResultDetail> release(
    String topicId,
    String studentId,
    TeacherTopicResultAudience audience,
  ) async {
    final detail = await remoteDataSource.release(topicId, studentId, audience);
    final visibility = detail.result.visibility;
    _requireConfirmed(
      detail,
      studentId,
      confirmed: switch (audience) {
        TeacherTopicResultAudience.student =>
          visibility.studentReleasedAt != null,
        TeacherTopicResultAudience.parent =>
          visibility.parentReleasedAt != null,
      },
    );
    return detail;
  }

  @override
  Future<TeacherTopicResultDetail> close(
    String topicId,
    String studentId,
  ) async {
    final detail = await remoteDataSource.close(topicId, studentId);
    _requireConfirmed(
      detail,
      studentId,
      confirmed: detail.result.status == TeacherTopicResultStatus.closed,
    );
    return detail;
  }

  @override
  Future<TeacherTopicResultBulkOutcome> releaseAll(
    String topicId,
    TeacherTopicResultAudience audience,
  ) {
    return remoteDataSource.releaseAll(topicId, audience);
  }

  @override
  Future<TeacherTopicResultBulkOutcome> closeAll(String topicId) {
    return remoteDataSource.closeAll(topicId);
  }
}

/// An action answer for another Student, or one that does not show the
/// action's effect, leaves the outcome unknown.
void _requireConfirmed(
  TeacherTopicResultDetail detail,
  String studentId, {
  required bool confirmed,
}) {
  if (!confirmed ||
      detail.result.studentId.toLowerCase() != studentId.toLowerCase()) {
    throw const TeacherTopicResultMutationOutcomeUnknownException();
  }
}
