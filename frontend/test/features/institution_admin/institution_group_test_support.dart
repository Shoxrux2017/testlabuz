import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';

const testGroupId = '550e8400-e29b-41d4-a716-446655440000';
const testGroupIdUpper = 'A0B1C2D3-E4F5-6789-ABCD-EF0123456789';
const testTeacherId = '11111111-1111-4111-8111-111111111111';
const testStudentId = '22222222-2222-4222-8222-222222222222';

Map<String, Object?> groupResource({
  String id = testGroupId,
  String name = 'Advanced Mathematics',
  String? level = 'Grade 10',
  String? subjectDirection = 'Mathematics',
  String? description = 'Olympiad preparation',
  String status = 'active',
  int teachersCount = 0,
  int studentsCount = 0,
  String? archivedAt,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'level': level,
  'subject_direction': subjectDirection,
  'description': description,
  'status': status,
  'teachers_count': teachersCount,
  'students_count': studentsCount,
  'archived_at': archivedAt,
  'created_at': '2026-08-15T08:00:00Z',
  'updated_at': '2026-08-15T09:30:00Z',
};

InstitutionGroup testGroup({
  String id = testGroupId,
  String name = 'Advanced Mathematics',
  String? level = 'Grade 10',
  String? subjectDirection = 'Mathematics',
  String? description = 'Olympiad preparation',
  InstitutionGroupStatus status = InstitutionGroupStatus.active,
  int teachersCount = 0,
  int studentsCount = 0,
  DateTime? archivedAt,
}) => InstitutionGroup(
  id: id,
  name: name,
  level: level,
  subjectDirection: subjectDirection,
  description: description,
  status: status,
  teachersCount: teachersCount,
  studentsCount: studentsCount,
  archivedAt: archivedAt,
  createdAt: DateTime.utc(2026, 8, 15, 8),
  updatedAt: DateTime.utc(2026, 8, 15, 9, 30),
);

Map<String, Object?> membershipResource({
  String id = testTeacherId,
  String fullName = 'Teacher One',
  String loginName = 'teacher.one',
  String? email = 'teacher@example.com',
  String? phone,
  bool isActive = true,
  String startedAt = '2026-08-21T10:15:00Z',
}) => <String, Object?>{
  'id': id,
  'full_name': fullName,
  'login_name': loginName,
  'email': email,
  'phone': phone,
  'is_active': isActive,
  'started_at': startedAt,
};

InstitutionGroupMembership testMembership({
  String id = testTeacherId,
  String fullName = 'Teacher One',
  String loginName = 'teacher.one',
  String? email = 'teacher@example.com',
  String? phone,
  bool isActive = true,
  DateTime? startedAt,
}) => InstitutionGroupMembership(
  id: id,
  fullName: fullName,
  loginName: loginName,
  email: email,
  phone: phone,
  isActive: isActive,
  startedAt: startedAt ?? DateTime.utc(2026, 8, 21, 10, 15),
);

InstitutionUser testCandidate({
  String id = testTeacherId,
  InstitutionUserRole role = InstitutionUserRole.teacher,
  String fullName = 'Teacher One',
  String loginName = 'teacher.one',
  bool isActive = true,
}) => InstitutionUser(
  id: id,
  role: role,
  fullName: fullName,
  loginName: loginName,
  email: null,
  phone: null,
  isActive: isActive,
  mustChangePassword: true,
  lastLoginAt: null,
  deactivatedAt: isActive ? null : DateTime.utc(2026, 8, 20),
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 21),
);

AuthUser testInstitutionAdmin({String id = 'admin-a'}) => AuthUser(
  id: id,
  institutionId: 'institution-a',
  role: UserRole.institutionAdmin,
  fullName: 'Admin User',
  loginName: 'admin',
  email: null,
  phone: null,
  isActive: true,
  mustChangePassword: false,
  institution: const AuthInstitution(
    id: 'institution-a',
    name: 'Institution A',
    status: 'active',
    timezone: 'Asia/Tashkent',
  ),
);

class TestAuthSessionController extends AuthSessionController {
  TestAuthSessionController([AuthSessionState? initialState])
    : initialState =
          initialState ??
          AuthSessionState.authenticated(testInstitutionAdmin());

  final AuthSessionState initialState;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => initialState;

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
  }

  void setSession(AuthSessionState next) {
    state = next;
  }
}

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  RequestOptions get request => requests.single;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio testDio(RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

ResponseBody jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
