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
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_list_pagination.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_repository.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

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

TeacherLearningMaterial teacherMaterial({
  String id = '20000000-0000-0000-0000-000000000001',
  String topicId = '10000000-0000-0000-0000-000000000001',
  String? title = 'Lesson slides',
  String fileId = '30000000-0000-0000-0000-000000000001',
  String originalName = 'lesson.pptx',
  String extension = 'pptx',
  String mimeType =
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  int sizeBytes = 1_250_000,
}) {
  return TeacherLearningMaterial(
    id: id,
    topicId: topicId,
    title: title,
    file: TeacherLearningMaterialFile(
      id: fileId,
      originalName: originalName,
      mimeType: mimeType,
      extension: extension,
      sizeBytes: sizeBytes,
    ),
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 15),
  );
}

TeacherLearningMaterialCollection teacherMaterialCollection({
  List<TeacherLearningMaterial>? materials,
  int maxSizeBytes = 20_971_520,
}) {
  return TeacherLearningMaterialCollection(
    materials: materials ?? [teacherMaterial()],
    uploadCapability: TeacherMaterialUploadCapability(
      maxSizeBytes: maxSizeBytes,
      platformMaxSizeBytes: 26_214_400,
      allowedExtensions: const ['pdf', 'docx', 'ppt', 'pptx'],
    ),
  );
}

TeacherHomeworkSummary teacherHomeworkSummary({
  String id = '50000000-0000-0000-0000-000000000001',
  String topicId = '10000000-0000-0000-0000-000000000001',
  String title = 'Equation practice',
  TeacherHomeworkAssignmentMode assignmentMode =
      TeacherHomeworkAssignmentMode.group,
  double totalPossiblePoints = 10,
  int questionCount = 2,
  DateTime? deadlineAt,
  bool hasDeadline = true,
  String institutionTimezone = 'Asia/Tashkent',
  TeacherHomeworkStatus status = TeacherHomeworkStatus.draft,
}) {
  return TeacherHomeworkSummary(
    id: id,
    topicId: topicId,
    title: title,
    assignmentMode: assignmentMode,
    totalPossiblePoints: totalPossiblePoints,
    questionCount: questionCount,
    deadlineAt: hasDeadline
        ? deadlineAt ?? DateTime.utc(2026, 9, 10, 12)
        : null,
    institutionTimezone: institutionTimezone,
    status: status,
    createdAt: DateTime.utc(2026, 9, 1, 8),
    updatedAt: DateTime.utc(2026, 9, 2, 9),
  );
}

TeacherHomeworkList teacherHomeworkList({
  List<TeacherHomeworkSummary>? items,
  int page = 1,
  int perPage = TeacherHomeworkListQuery.defaultPerPage,
  int total = 0,
  int lastPage = 1,
}) {
  return TeacherHomeworkList(
    items: items ?? const [],
    pagination: TeacherListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

TeacherGroupStudentList teacherGroupStudentList({
  int page = 1,
  int perPage = TeacherGroupStudentListQuery.defaultPerPage,
  int total = 0,
  int lastPage = 1,
}) {
  return TeacherGroupStudentList(
    items: const [],
    pagination: TeacherListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

TeacherHomework teacherHomework({
  String id = '50000000-0000-0000-0000-000000000001',
  String topicId = '10000000-0000-0000-0000-000000000001',
  String title = 'Equation practice',
  String? description = 'Practice the lesson concepts.',
  String studentInstructions = 'Answer every question.',
  TeacherHomeworkAssignmentMode assignmentMode =
      TeacherHomeworkAssignmentMode.group,
  List<String>? studentIds,
  double totalPossiblePoints = 10,
  DateTime? deadlineAt,
  bool hasDeadline = true,
  String institutionTimezone = 'Asia/Tashkent',
  TeacherHomeworkStatus status = TeacherHomeworkStatus.draft,
  List<TeacherQuestion>? questions,
}) {
  final activatedAt = switch (status) {
    TeacherHomeworkStatus.draft => null,
    TeacherHomeworkStatus.active ||
    TeacherHomeworkStatus.closed ||
    TeacherHomeworkStatus.archived => DateTime.utc(2026, 9, 3, 8),
  };
  final closedAt = switch (status) {
    TeacherHomeworkStatus.draft || TeacherHomeworkStatus.active => null,
    TeacherHomeworkStatus.closed ||
    TeacherHomeworkStatus.archived => DateTime.utc(2026, 9, 4, 8),
  };
  final recipients = switch (assignmentMode) {
    TeacherHomeworkAssignmentMode.group => const <String>[],
    TeacherHomeworkAssignmentMode.selectedStudents =>
      studentIds ?? const ['60000000-0000-0000-0000-000000000001'],
  };

  return TeacherHomework(
    id: id,
    topicId: topicId,
    title: title,
    description: description,
    studentInstructions: studentInstructions,
    assignmentMode: assignmentMode,
    studentIds: recipients,
    totalPossiblePoints: totalPossiblePoints,
    deadlineAt: hasDeadline
        ? deadlineAt ?? DateTime.utc(2026, 9, 10, 12)
        : null,
    institutionTimezone: institutionTimezone,
    status: status,
    attemptPolicy: const TeacherHomeworkAttemptPolicy(
      normalAttempts: 3,
      officialScorePolicy: 'highest_valid_completed',
    ),
    activatedAt: activatedAt,
    closedAt: closedAt,
    archivedAt: status == TeacherHomeworkStatus.archived
        ? DateTime.utc(2026, 9, 5, 8)
        : null,
    createdAt: DateTime.utc(2026, 9, 1, 8),
    updatedAt: DateTime.utc(2026, 9, 2, 9),
    questions: questions ?? const [],
  );
}

List<TeacherQuestion> teacherHomeworkQuestions() {
  return [
    TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000001',
      type: TeacherQuestionType.singleChoice,
      prompt: 'Choose one answer.',
      instructions: null,
      points: 1,
      position: 1,
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configuration: TeacherChoiceQuestionConfiguration(
        options: const [
          TeacherChoiceOption(text: 'Four', isCorrect: true, position: 1),
          TeacherChoiceOption(text: 'Five', isCorrect: false, position: 2),
        ],
      ),
    ),
    TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000002',
      type: TeacherQuestionType.multipleChoice,
      prompt: 'Choose all correct answers.',
      instructions: 'There may be more than one.',
      points: 2,
      position: 2,
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configuration: TeacherChoiceQuestionConfiguration(
        options: const [
          TeacherChoiceOption(text: 'Two', isCorrect: true, position: 1),
          TeacherChoiceOption(text: 'Three', isCorrect: true, position: 2),
          TeacherChoiceOption(text: 'Four', isCorrect: false, position: 3),
        ],
      ),
    ),
    const TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000003',
      type: TeacherQuestionType.trueFalse,
      prompt: 'Zero is an even number.',
      instructions: null,
      points: 1,
      position: 3,
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configuration: TeacherTrueFalseQuestionConfiguration(correctValue: true),
    ),
    TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000004',
      type: TeacherQuestionType.shortWritten,
      prompt: 'Name the operation.',
      instructions: null,
      points: 1,
      position: 4,
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configuration: TeacherShortWrittenAutomaticConfiguration(
        acceptedAnswers: const ['Addition', 'Add'],
      ),
    ),
    const TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000005',
      type: TeacherQuestionType.shortWritten,
      prompt: 'Explain your first step.',
      instructions: null,
      points: 1,
      position: 5,
      checkingMode: TeacherQuestionCheckingMode.manual,
      configuration: TeacherEmptyQuestionConfiguration(),
    ),
    const TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000006',
      type: TeacherQuestionType.openWritten,
      prompt: 'Explain the complete solution.',
      instructions: null,
      points: 2,
      position: 6,
      checkingMode: TeacherQuestionCheckingMode.manual,
      configuration: TeacherEmptyQuestionConfiguration(),
    ),
    TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000007',
      type: TeacherQuestionType.fileBased,
      prompt: 'Upload your presentation.',
      instructions: null,
      points: 1,
      position: 7,
      checkingMode: TeacherQuestionCheckingMode.manual,
      configuration: TeacherFileBasedQuestionConfiguration(
        allowedExtensions: const ['pdf', 'docx', 'ppt', 'pptx'],
      ),
    ),
    TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000008',
      type: TeacherQuestionType.matching,
      prompt: 'Match each expression.',
      instructions: null,
      points: 1,
      position: 8,
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configuration: TeacherMatchingQuestionConfiguration(
        pairs: const [
          TeacherMatchingPair(
            clientKey: '80000000-0000-0000-0000-000000000001',
            left: '2 + 2',
            right: '4',
          ),
        ],
      ),
    ),
    TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000009',
      type: TeacherQuestionType.ordering,
      prompt: 'Put the steps in order.',
      instructions: null,
      points: 1,
      position: 9,
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configuration: TeacherOrderingQuestionConfiguration(
        items: const [
          TeacherOrderingItem(text: 'Simplify', correctPosition: 1),
          TeacherOrderingItem(text: 'Solve', correctPosition: 2),
        ],
      ),
    ),
    TeacherQuestion(
      id: '70000000-0000-0000-0000-000000000010',
      type: TeacherQuestionType.fillInBlank,
      prompt: '{{sum}} is the result.',
      instructions: null,
      points: 1,
      position: 10,
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configuration: TeacherFillInBlankQuestionConfiguration(
        blanks: [
          TeacherFillBlank(
            key: 'sum',
            position: 1,
            acceptedAnswers: const ['Four', '4'],
          ),
        ],
      ),
    ),
  ];
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

class FakeTeacherHomeworkRepository implements TeacherHomeworkRepository {
  FakeTeacherHomeworkRepository({
    this.onFetchList,
    this.onFetch,
    this.onCreate,
    this.onUpdate,
    this.onAddQuestion,
    this.onUpdateQuestion,
    this.onDeleteQuestion,
    this.onReorderQuestions,
  });

  Future<TeacherHomeworkList> Function(
    String topicId,
    TeacherHomeworkListQuery query,
  )?
  onFetchList;
  Future<TeacherHomework> Function(String homeworkId)? onFetch;
  Future<TeacherHomework> Function(
    String topicId,
    TeacherHomeworkCreateRequest request,
  )?
  onCreate;
  Future<TeacherHomework> Function(
    String homeworkId,
    TeacherHomeworkEditRequest request,
  )?
  onUpdate;
  Future<TeacherHomework> Function(
    String homeworkId,
    TeacherQuestionCreateRequest request,
  )?
  onAddQuestion;
  Future<TeacherHomework> Function(
    String questionId,
    TeacherQuestionEditRequest request,
  )?
  onUpdateQuestion;
  Future<TeacherHomework> Function(String questionId)? onDeleteQuestion;
  Future<TeacherHomework> Function(
    String homeworkId,
    TeacherQuestionReorderRequest request,
  )?
  onReorderQuestions;

  final listRequests = <({String topicId, TeacherHomeworkListQuery query})>[];
  final fetchIds = <String>[];
  final createRequests =
      <({String topicId, TeacherHomeworkCreateRequest request})>[];
  final updateRequests =
      <({String homeworkId, TeacherHomeworkEditRequest request})>[];
  final addQuestionRequests =
      <({String homeworkId, TeacherQuestionCreateRequest request})>[];
  final updateQuestionRequests =
      <({String questionId, TeacherQuestionEditRequest request})>[];
  final deleteQuestionIds = <String>[];
  final reorderQuestionRequests =
      <({String homeworkId, TeacherQuestionReorderRequest request})>[];

  @override
  Future<TeacherHomework> addQuestion(
    String homeworkId,
    TeacherQuestionCreateRequest request,
  ) {
    addQuestionRequests.add((homeworkId: homeworkId, request: request));
    return onAddQuestion?.call(homeworkId, request) ??
        Future.value(teacherHomework(id: homeworkId));
  }

  @override
  Future<TeacherHomework> createHomework(
    String topicId,
    TeacherHomeworkCreateRequest request,
  ) {
    createRequests.add((topicId: topicId, request: request));
    return onCreate?.call(topicId, request) ??
        Future.value(teacherHomework(topicId: topicId));
  }

  @override
  Future<TeacherHomeworkList> fetchHomeworkList(
    String topicId,
    TeacherHomeworkListQuery query,
  ) {
    listRequests.add((topicId: topicId, query: query));
    return onFetchList?.call(topicId, query) ??
        Future.value(
          teacherHomeworkList(page: query.page, perPage: query.perPage),
        );
  }

  @override
  Future<TeacherHomework> fetchHomework(String homeworkId) {
    fetchIds.add(homeworkId);
    return onFetch?.call(homeworkId) ??
        Future.value(teacherHomework(id: homeworkId));
  }

  @override
  Future<TeacherHomework> deleteQuestion(String questionId) {
    deleteQuestionIds.add(questionId);
    return onDeleteQuestion?.call(questionId) ??
        Future.value(teacherHomework());
  }

  @override
  Future<TeacherHomework> reorderQuestions(
    String homeworkId,
    TeacherQuestionReorderRequest request,
  ) {
    reorderQuestionRequests.add((homeworkId: homeworkId, request: request));
    return onReorderQuestions?.call(homeworkId, request) ??
        Future.value(teacherHomework(id: homeworkId));
  }

  @override
  Future<TeacherHomework> updateHomework(
    String homeworkId,
    TeacherHomeworkEditRequest request,
  ) {
    updateRequests.add((homeworkId: homeworkId, request: request));
    return onUpdate?.call(homeworkId, request) ??
        Future.value(teacherHomework(id: homeworkId));
  }

  @override
  Future<TeacherHomework> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  ) {
    updateQuestionRequests.add((questionId: questionId, request: request));
    return onUpdateQuestion?.call(questionId, request) ??
        Future.value(teacherHomework());
  }
}

class FakeTeacherGroupStudentRepository
    implements TeacherGroupStudentRepository {
  FakeTeacherGroupStudentRepository({this.onFetch});

  Future<TeacherGroupStudentList> Function(
    String groupId,
    TeacherGroupStudentListQuery query,
  )?
  onFetch;

  final requests = <({String groupId, TeacherGroupStudentListQuery query})>[];

  @override
  Future<TeacherGroupStudentList> fetchGroupStudents(
    String groupId,
    TeacherGroupStudentListQuery query,
  ) {
    requests.add((groupId: groupId, query: query));
    return onFetch?.call(groupId, query) ??
        Future.value(
          teacherGroupStudentList(page: query.page, perPage: query.perPage),
        );
  }
}

class FakeTeacherLearningMaterialRepository
    implements TeacherLearningMaterialRepository {
  FakeTeacherLearningMaterialRepository({
    this.onFetch,
    this.onUpload,
    this.onReplace,
    this.onUpdateTitle,
    this.onRemove,
  });

  Future<TeacherLearningMaterialCollection> Function(String topicId)? onFetch;
  Future<TeacherLearningMaterial> Function(
    String topicId,
    TeacherMaterialUploadFile file,
    String? title,
    TeacherMaterialUploadProgress? onProgress,
  )?
  onUpload;
  Future<TeacherLearningMaterial> Function(
    String topicId,
    TeacherLearningMaterial current,
    TeacherMaterialUploadFile file,
    TeacherMaterialUploadProgress? onProgress,
  )?
  onReplace;
  Future<TeacherLearningMaterial> Function(
    String topicId,
    TeacherLearningMaterial current,
    String? title,
  )?
  onUpdateTitle;
  Future<void> Function(String topicId, TeacherLearningMaterial current)?
  onRemove;

  final fetchIds = <String>[];
  final uploadRequests =
      <({String topicId, TeacherMaterialUploadFile file, String? title})>[];
  final replaceRequests =
      <
        ({
          String topicId,
          TeacherLearningMaterial current,
          TeacherMaterialUploadFile file,
        })
      >[];
  final titleRequests =
      <({String topicId, TeacherLearningMaterial current, String? title})>[];
  final removeRequests =
      <({String topicId, TeacherLearningMaterial current})>[];

  @override
  Future<TeacherLearningMaterialCollection> fetchMaterials(String topicId) {
    fetchIds.add(topicId);
    return onFetch?.call(topicId) ?? Future.value(teacherMaterialCollection());
  }

  @override
  Future<TeacherLearningMaterial> uploadMaterial({
    required String topicId,
    required TeacherMaterialUploadFile file,
    required String? title,
    TeacherMaterialUploadProgress? onProgress,
  }) {
    uploadRequests.add((topicId: topicId, file: file, title: title));
    return onUpload?.call(topicId, file, title, onProgress) ??
        Future.value(teacherMaterial(title: title));
  }

  @override
  Future<TeacherLearningMaterial> replaceMaterialFile({
    required String topicId,
    required TeacherLearningMaterial current,
    required TeacherMaterialUploadFile file,
    TeacherMaterialUploadProgress? onProgress,
  }) {
    replaceRequests.add((topicId: topicId, current: current, file: file));
    return onReplace?.call(topicId, current, file, onProgress) ??
        Future.value(current);
  }

  @override
  Future<TeacherLearningMaterial> updateMaterialTitle({
    required String topicId,
    required TeacherLearningMaterial current,
    required String? title,
  }) {
    titleRequests.add((topicId: topicId, current: current, title: title));
    return onUpdateTitle?.call(topicId, current, title) ??
        Future.value(
          TeacherLearningMaterial(
            id: current.id,
            topicId: current.topicId,
            title: title,
            file: current.file,
            createdAt: current.createdAt,
            updatedAt: current.updatedAt,
          ),
        );
  }

  @override
  Future<void> removeMaterial({
    required String topicId,
    required TeacherLearningMaterial current,
  }) {
    removeRequests.add((topicId: topicId, current: current));
    return onRemove?.call(topicId, current) ?? Future.value();
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
