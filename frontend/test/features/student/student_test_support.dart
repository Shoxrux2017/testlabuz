import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/student/domain/student_topic.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_list.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_repository.dart';

const studentTopicId = '10000000-0000-0000-0000-000000000001';
const studentMaterialId = '20000000-0000-0000-0000-000000000001';
const studentFileId = '30000000-0000-0000-0000-000000000001';

Future<void> flushStudentControllers() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AuthUser studentUser(
  String loginName, {
  String institutionId = 'institution-1',
  String nestedInstitutionId = 'institution-1',
  UserRole role = UserRole.student,
  bool isActive = true,
  bool mustChangePassword = false,
  String institutionStatus = 'active',
  String institutionTimezone = 'Asia/Tashkent',
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
      timezone: institutionTimezone,
    ),
  );
}

StudentGroupSummary studentGroup({
  String id = '00000000-0000-0000-0000-000000000001',
  String name = '9-A',
  String? level = 'Grade 9',
  String? subjectDirection = 'Informatics',
  StudentGroupStatus status = StudentGroupStatus.active,
}) {
  return StudentGroupSummary(
    id: id,
    name: name,
    level: level,
    subjectDirection: subjectDirection,
    status: status,
  );
}

StudentLearningMaterial studentMaterial({
  String id = studentMaterialId,
  String? title = 'Lesson slides',
  String fileId = studentFileId,
  String originalName = 'lesson.pptx',
  String extension = 'pptx',
  int sizeBytes = 1_250_000,
}) {
  return StudentLearningMaterial(
    id: id,
    title: title,
    file: StudentLearningMaterialFile(
      id: fileId,
      originalName: originalName,
      extension: extension,
      sizeBytes: sizeBytes,
    ),
  );
}

StudentTopicSummary studentTopicSummary({
  String id = studentTopicId,
  String title = 'Internet Basics',
  String subject = 'Informatics',
  StudentGroupSummary? group,
  DateTime? lessonAt,
  StudentTopicStatus status = StudentTopicStatus.active,
}) {
  return StudentTopicSummary(
    id: id,
    group: group ?? studentGroup(),
    title: title,
    subject: subject,
    lessonAt: lessonAt ?? DateTime.utc(2026, 8, 25, 4),
    status: status,
  );
}

StudentTopicDetail studentTopicDetail({
  String id = studentTopicId,
  String title = 'Internet Basics',
  String? description = 'Optional description',
  String subject = 'Informatics',
  String studentInstructions = 'Study the materials.',
  StudentGroupSummary? group,
  DateTime? lessonAt,
  StudentTopicStatus status = StudentTopicStatus.active,
  List<StudentLearningMaterial>? materials,
}) {
  return StudentTopicDetail(
    id: id,
    group: group ?? studentGroup(),
    title: title,
    description: description,
    subject: subject,
    studentInstructions: studentInstructions,
    lessonAt: lessonAt ?? DateTime.utc(2026, 8, 25, 4),
    status: status,
    materials: materials ?? [studentMaterial()],
  );
}

StudentTopicListPage studentTopicPage({
  List<StudentTopicSummary>? topics,
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) {
  return StudentTopicListPage(
    topics: topics ?? [studentTopicSummary()],
    pagination: StudentListPagination(
      page: page,
      perPage: StudentTopicListQuery.perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

ApiRequestException studentLocalFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Raw local failure.'),
  );
}

ApiRequestException studentServerFailure(String code, {int statusCode = 403}) {
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

class FakeStudentTopicRepository implements StudentTopicRepository {
  FakeStudentTopicRepository({this.onFetchTopics, this.onFetchTopic});

  Future<StudentTopicListPage> Function(StudentTopicListQuery query)?
  onFetchTopics;
  Future<StudentTopicDetail> Function(String topicId)? onFetchTopic;
  final listQueries = <StudentTopicListQuery>[];
  final detailIds = <String>[];

  @override
  Future<StudentTopicListPage> fetchTopics(StudentTopicListQuery query) {
    listQueries.add(query);
    return onFetchTopics?.call(query) ??
        Future.value(studentTopicPage(page: query.page));
  }

  @override
  Future<StudentTopicDetail> fetchTopic(String topicId) {
    detailIds.add(topicId);
    return onFetchTopic?.call(topicId) ??
        Future.value(studentTopicDetail(id: topicId));
  }
}

class FakeStudentAuthSessionController extends AuthSessionController {
  FakeStudentAuthSessionController(this.initialState);

  factory FakeStudentAuthSessionController.authenticated(AuthUser user) {
    return FakeStudentAuthSessionController(
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
