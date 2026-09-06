import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_list.dart';
import '../domain/teacher_homework_list_query.dart';
import '../domain/teacher_homework_mutation.dart';
import '../domain/teacher_homework_repository.dart';
import '../domain/teacher_question_mutation.dart';
import 'teacher_homework_remote_data_source.dart';

final teacherHomeworkRepositoryProvider = Provider<TeacherHomeworkRepository>((
  ref,
) {
  return TeacherHomeworkRepositoryImpl(
    remoteDataSource: ref.watch(teacherHomeworkRemoteDataSourceProvider),
  );
});

class TeacherHomeworkRepositoryImpl implements TeacherHomeworkRepository {
  const TeacherHomeworkRepositoryImpl({required this.remoteDataSource});

  final TeacherHomeworkRemoteDataSource remoteDataSource;

  @override
  Future<TeacherHomework> addQuestion(
    String homeworkId,
    TeacherQuestionCreateRequest request,
  ) async {
    final dto = await remoteDataSource.addQuestion(homeworkId, request);
    final homework = dto.homework.toDomain();
    _requireQuestionMutationTarget(
      homework,
      homeworkId,
      TeacherQuestionMutationOperation.add,
    );
    return homework;
  }

  @override
  Future<TeacherHomework> createHomework(
    String topicId,
    TeacherHomeworkCreateRequest request,
  ) async {
    final dto = await remoteDataSource.createHomework(topicId, request);
    final homework = dto.homework.toDomain();
    if (homework.topicId.toLowerCase() != topicId.toLowerCase()) {
      throw const TeacherHomeworkMutationOutcomeUnknownException();
    }
    return homework;
  }

  @override
  Future<TeacherHomeworkList> fetchHomeworkList(
    String topicId,
    TeacherHomeworkListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchHomeworkList(topicId, query);
    return dto.toDomain();
  }

  @override
  Future<TeacherHomework> fetchHomework(String homeworkId) async {
    final dto = await remoteDataSource.fetchHomework(homeworkId);
    final homework = dto.homework.toDomain();
    if (homework.id.toLowerCase() != homeworkId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Teacher Homework detail ID does not match the request.',
        ),
      );
    }
    return homework;
  }

  @override
  Future<TeacherHomework> deleteQuestion(String questionId) async {
    final dto = await remoteDataSource.deleteQuestion(questionId);
    return dto.homework.toDomain();
  }

  @override
  Future<TeacherHomework> reorderQuestions(
    String homeworkId,
    TeacherQuestionReorderRequest request,
  ) async {
    final dto = await remoteDataSource.reorderQuestions(homeworkId, request);
    final homework = dto.homework.toDomain();
    _requireQuestionMutationTarget(
      homework,
      homeworkId,
      TeacherQuestionMutationOperation.reorder,
    );
    return homework;
  }

  @override
  Future<TeacherHomework> updateHomework(
    String homeworkId,
    TeacherHomeworkEditRequest request,
  ) async {
    final dto = await remoteDataSource.updateHomework(homeworkId, request);
    final homework = dto.homework.toDomain();
    if (homework.id.toLowerCase() != homeworkId.toLowerCase()) {
      throw const TeacherHomeworkMutationOutcomeUnknownException();
    }
    return homework;
  }

  @override
  Future<TeacherHomework> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  ) async {
    final dto = await remoteDataSource.updateQuestion(questionId, request);
    return dto.homework.toDomain();
  }
}

void _requireQuestionMutationTarget(
  TeacherHomework homework,
  String homeworkId,
  TeacherQuestionMutationOperation operation,
) {
  if (homework.id.toLowerCase() != homeworkId.toLowerCase()) {
    throw TeacherQuestionMutationOutcomeUnknownException(operation);
  }
}
