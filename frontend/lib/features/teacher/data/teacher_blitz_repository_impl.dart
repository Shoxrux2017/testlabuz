import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_attempt_exception.dart';
import '../domain/teacher_blitz_list.dart';
import '../domain/teacher_blitz_list_query.dart';
import '../domain/teacher_blitz_monitoring.dart';
import '../domain/teacher_blitz_mutation.dart';
import '../domain/teacher_blitz_repository.dart';
import '../domain/teacher_blitz_schedule.dart';
import '../domain/teacher_question_mutation.dart';
import 'teacher_blitz_remote_data_source.dart';

final teacherBlitzRepositoryProvider = Provider<TeacherBlitzRepository>((ref) {
  return TeacherBlitzRepositoryImpl(
    remoteDataSource: ref.watch(teacherBlitzRemoteDataSourceProvider),
  );
});

class TeacherBlitzRepositoryImpl implements TeacherBlitzRepository {
  const TeacherBlitzRepositoryImpl({required this.remoteDataSource});

  final TeacherBlitzRemoteDataSource remoteDataSource;

  @override
  Future<TeacherBlitzList> fetchBlitzList(
    String topicId,
    TeacherBlitzListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchBlitzList(topicId, query);
    return dto.toDomain();
  }

  @override
  Future<TeacherBlitz> fetchBlitz(String blitzId) async {
    final dto = await remoteDataSource.fetchBlitz(blitzId);
    final blitz = dto.blitz.toDomain();
    if (blitz.id.toLowerCase() != blitzId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Teacher Blitz detail ID does not match the request.',
        ),
      );
    }
    return blitz;
  }

  @override
  Future<TeacherBlitz> createBlitz(
    String topicId,
    TeacherBlitzCreateRequest request,
  ) async {
    final dto = await remoteDataSource.createBlitz(topicId, request);
    final blitz = dto.blitz.toDomain();
    if (blitz.topicId.toLowerCase() != topicId.toLowerCase()) {
      throw const TeacherBlitzMutationOutcomeUnknownException();
    }
    return blitz;
  }

  @override
  Future<TeacherBlitz> updateBlitz(
    String blitzId,
    TeacherBlitzEditRequest request,
  ) async {
    final dto = await remoteDataSource.updateBlitz(blitzId, request);
    final blitz = dto.blitz.toDomain();
    if (blitz.id.toLowerCase() != blitzId.toLowerCase()) {
      throw const TeacherBlitzMutationOutcomeUnknownException();
    }
    return blitz;
  }

  @override
  Future<TeacherBlitz> addQuestion(
    String blitzId,
    TeacherQuestionCreateRequest request,
  ) async {
    final dto = await remoteDataSource.addQuestion(blitzId, request);
    return _requireQuestionMutationTarget(
      dto.blitz.toDomain(),
      blitzId,
      TeacherQuestionMutationOperation.add,
    );
  }

  @override
  Future<TeacherBlitz> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  ) async {
    final dto = await remoteDataSource.updateQuestion(questionId, request);
    return dto.blitz.toDomain();
  }

  @override
  Future<TeacherBlitz> deleteQuestion(String questionId) async {
    final dto = await remoteDataSource.deleteQuestion(questionId);
    return dto.blitz.toDomain();
  }

  @override
  Future<TeacherBlitz> reorderQuestions(
    String blitzId,
    TeacherQuestionReorderRequest request,
  ) async {
    final dto = await remoteDataSource.reorderQuestions(blitzId, request);
    return _requireQuestionMutationTarget(
      dto.blitz.toDomain(),
      blitzId,
      TeacherQuestionMutationOperation.reorder,
    );
  }

  @override
  Future<TeacherBlitz> scheduleBlitz(
    String blitzId,
    TeacherBlitzScheduleRequest request,
  ) async {
    final dto = await remoteDataSource.scheduleBlitz(blitzId, request);
    return _requireLifecycleTarget(dto.blitz.toDomain(), blitzId);
  }

  @override
  Future<TeacherBlitz> activateBlitz(
    String blitzId, {
    required String idempotencyKey,
  }) async {
    final dto = await remoteDataSource.activateBlitz(
      blitzId,
      idempotencyKey: idempotencyKey,
    );
    return _requireLifecycleTarget(dto.blitz.toDomain(), blitzId);
  }

  @override
  Future<TeacherBlitz> closeBlitz(String blitzId) async {
    final dto = await remoteDataSource.closeBlitz(blitzId);
    return _requireLifecycleTarget(dto.blitz.toDomain(), blitzId);
  }

  @override
  Future<TeacherBlitz> archiveBlitz(String blitzId) async {
    final dto = await remoteDataSource.archiveBlitz(blitzId);
    return _requireLifecycleTarget(dto.blitz.toDomain(), blitzId);
  }

  @override
  Future<TeacherBlitzMonitoring> fetchMonitoring(String blitzId) async {
    final dto = await remoteDataSource.fetchMonitoring(blitzId);
    final monitoring = dto.toDomain();
    if (monitoring.blitz.id.toLowerCase() != blitzId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Teacher Blitz monitoring ID does not match the request.',
        ),
      );
    }
    return monitoring;
  }

  @override
  Future<TeacherBlitzAttemptException> grantAttemptException(
    String blitzId,
    String studentId,
    TeacherBlitzAttemptExceptionRequest request, {
    required String idempotencyKey,
  }) async {
    final dto = await remoteDataSource.grantAttemptException(
      blitzId,
      studentId,
      request,
      idempotencyKey: idempotencyKey,
    );
    return dto.toDomain();
  }
}

TeacherBlitz _requireLifecycleTarget(TeacherBlitz blitz, String blitzId) {
  if (blitz.id.toLowerCase() != blitzId.toLowerCase()) {
    throw const TeacherBlitzMutationOutcomeUnknownException();
  }
  return blitz;
}

TeacherBlitz _requireQuestionMutationTarget(
  TeacherBlitz blitz,
  String blitzId,
  TeacherQuestionMutationOperation operation,
) {
  if (blitz.id.toLowerCase() != blitzId.toLowerCase()) {
    throw TeacherQuestionMutationOutcomeUnknownException(operation);
  }
  return blitz;
}
