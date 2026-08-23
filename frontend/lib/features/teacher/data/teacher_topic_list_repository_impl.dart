import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/teacher_topic_list.dart';
import '../domain/teacher_topic_list_query.dart';
import '../domain/teacher_topic_list_repository.dart';
import 'teacher_topic_list_remote_data_source.dart';

final teacherTopicListRepositoryProvider = Provider<TeacherTopicListRepository>(
  (ref) {
    return TeacherTopicListRepositoryImpl(
      remoteDataSource: ref.watch(teacherTopicListRemoteDataSourceProvider),
    );
  },
);

class TeacherTopicListRepositoryImpl implements TeacherTopicListRepository {
  const TeacherTopicListRepositoryImpl({required this.remoteDataSource});

  final TeacherTopicListRemoteDataSource remoteDataSource;

  @override
  Future<TeacherTopicListPage> fetchTopics(TeacherTopicListQuery query) async {
    final dto = await remoteDataSource.fetchTopics(query);

    return dto.toDomain();
  }
}
