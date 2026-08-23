import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_list_pagination.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_repository.dart';

Future<void> flushTeacherControllers() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AuthUser teacherUser(
  String loginName, {
  String institutionId = 'institution-1',
  String nestedInstitutionId = 'institution-1',
  UserRole role = UserRole.teacher,
  bool isActive = true,
  bool mustChangePassword = false,
  String institutionStatus = 'active',
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: institutionId,
    role: role,
    fullName: '$loginName User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    institution: AuthInstitution(
      id: nestedInstitutionId,
      name: 'Example School',
      status: institutionStatus,
      timezone: 'Asia/Tashkent',
    ),
  );
}

TeacherGroupSummary teacherGroup({
  String id = '00000000-0000-0000-0000-000000000001',
  String name = 'Group A',
  String? level = '7',
  String? subjectDirection = 'Mathematics',
  TeacherGroupStatus status = TeacherGroupStatus.active,
}) {
  return TeacherGroupSummary(
    id: id,
    name: name,
    level: level,
    subjectDirection: subjectDirection,
    status: status,
  );
}

TeacherTopic teacherTopic({
  String id = '10000000-0000-0000-0000-000000000001',
  String title = 'Linear equations',
  TeacherGroupSummary? group,
  TeacherTopicStatus status = TeacherTopicStatus.draft,
  String? description,
  String subject = 'Algebra',
  String studentInstructions = 'Read the examples.',
  DateTime? lessonAt,
}) {
  final activatedAt = switch (status) {
    TeacherTopicStatus.draft => null,
    TeacherTopicStatus.active ||
    TeacherTopicStatus.closed ||
    TeacherTopicStatus.archived => DateTime.utc(2026, 8, 20, 10),
  };
  final closedAt = switch (status) {
    TeacherTopicStatus.draft || TeacherTopicStatus.active => null,
    TeacherTopicStatus.closed ||
    TeacherTopicStatus.archived => DateTime.utc(2026, 8, 21, 10),
  };

  return TeacherTopic(
    id: id,
    group: group ?? teacherGroup(),
    title: title,
    description: description,
    subject: subject,
    studentInstructions: studentInstructions,
    lessonAt: lessonAt ?? DateTime.utc(2026, 8, 25, 8),
    status: status,
    activatedAt: activatedAt,
    closedAt: closedAt,
    archivedAt: status == TeacherTopicStatus.archived
        ? DateTime.utc(2026, 8, 22, 10)
        : null,
    createdAt: DateTime.utc(2026, 8, 19, 10),
    updatedAt: DateTime.utc(2026, 8, 22, 10),
  );
}

TeacherGroupListPage teacherGroupPage({
  List<TeacherGroupSummary>? groups,
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) {
  return TeacherGroupListPage(
    groups: groups ?? [teacherGroup()],
    pagination: TeacherListPagination(
      page: page,
      perPage: TeacherGroupListQuery.perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

TeacherTopicListPage teacherTopicPage({
  List<TeacherTopic>? topics,
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) {
  return TeacherTopicListPage(
    topics: topics ?? [teacherTopic()],
    pagination: TeacherListPagination(
      page: page,
      perPage: TeacherTopicListQuery.perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

ApiRequestException teacherLocalFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Raw local failure.'),
  );
}

ApiRequestException teacherServerFailure(String code, {int statusCode = 403}) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: statusCode,
      error: ApiErrorResponse(
        message: 'Raw server failure.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

class FakeTeacherGroupListRepository implements TeacherGroupListRepository {
  FakeTeacherGroupListRepository({this.onFetch});

  Future<TeacherGroupListPage> Function(TeacherGroupListQuery query)? onFetch;
  final queries = <TeacherGroupListQuery>[];

  @override
  Future<TeacherGroupListPage> fetchGroups(TeacherGroupListQuery query) {
    queries.add(query);

    return onFetch?.call(query) ??
        Future.value(teacherGroupPage(page: query.page));
  }
}

class FakeTeacherTopicListRepository implements TeacherTopicListRepository {
  FakeTeacherTopicListRepository({this.onFetch});

  Future<TeacherTopicListPage> Function(TeacherTopicListQuery query)? onFetch;
  final queries = <TeacherTopicListQuery>[];

  @override
  Future<TeacherTopicListPage> fetchTopics(TeacherTopicListQuery query) {
    queries.add(query);

    return onFetch?.call(query) ??
        Future.value(teacherTopicPage(page: query.page));
  }
}

class FakeTeacherTopicRepository implements TeacherTopicRepository {
  FakeTeacherTopicRepository({
    this.onCreate,
    this.onFetch,
    this.onUpdate,
    this.onLifecycle,
  });

  Future<TeacherTopic> Function(TeacherTopicCreateRequest request)? onCreate;
  Future<TeacherTopic> Function(String topicId)? onFetch;
  Future<TeacherTopic> Function(
    String topicId,
    TeacherTopicEditRequest request,
  )?
  onUpdate;
  Future<TeacherTopic> Function(
    String topicId,
    TeacherTopicLifecycleAction action,
  )?
  onLifecycle;

  final createRequests = <TeacherTopicCreateRequest>[];
  final fetchIds = <String>[];
  final updateRequests =
      <({String topicId, TeacherTopicEditRequest request})>[];
  final lifecycleRequests =
      <({String topicId, TeacherTopicLifecycleAction action})>[];

  @override
  Future<TeacherTopic> createTopic(TeacherTopicCreateRequest request) {
    createRequests.add(request);
    return onCreate?.call(request) ?? Future.value(teacherTopic());
  }

  @override
  Future<TeacherTopic> fetchTopic(String topicId) {
    fetchIds.add(topicId);
    return onFetch?.call(topicId) ?? Future.value(teacherTopic(id: topicId));
  }

  @override
  Future<TeacherTopic> updateTopic(
    String topicId,
    TeacherTopicEditRequest request,
  ) {
    updateRequests.add((topicId: topicId, request: request));
    return onUpdate?.call(topicId, request) ??
        Future.value(teacherTopic(id: topicId));
  }

  @override
  Future<TeacherTopic> performLifecycleAction(
    String topicId,
    TeacherTopicLifecycleAction action,
  ) {
    lifecycleRequests.add((topicId: topicId, action: action));
    return onLifecycle?.call(topicId, action) ??
        Future.value(teacherTopic(id: topicId, status: action.expectedStatus));
  }
}

class FakeTeacherAuthSessionController extends AuthSessionController {
  FakeTeacherAuthSessionController(this.initialState);

  factory FakeTeacherAuthSessionController.authenticated(AuthUser user) {
    return FakeTeacherAuthSessionController(
      AuthSessionState.authenticated(user),
    );
  }

  final AuthSessionState initialState;
  AuthSessionState Function()? onBootstrap;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => initialState;

  void replaceUser(AuthUser user) {
    state = AuthSessionState.authenticated(user);
  }

  void logOut() {
    state = const AuthSessionState.unauthenticated();
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
    final next = onBootstrap?.call();
    if (next != null) {
      state = next;
    }
  }

  @override
  Future<void> signOut() async {
    state = const AuthSessionState.unauthenticated();
  }
}
