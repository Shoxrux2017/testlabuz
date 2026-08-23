import 'teacher_group_list.dart';
import 'teacher_group_list_query.dart';

abstract interface class TeacherGroupListRepository {
  Future<TeacherGroupListPage> fetchGroups(TeacherGroupListQuery query);
}
