import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';

const testParentId = '11111111-1111-4111-8111-111111111111';
const testStudentId = '22222222-2222-4222-8222-222222222222';
const testRelationshipId = '33333333-3333-4333-8333-333333333333';
const testOtherRelationshipId = '44444444-4444-4444-8444-444444444444';

Map<String, Object?> relationshipResource({
  String id = testRelationshipId,
  String parentId = testParentId,
  String studentId = testStudentId,
  String startedAt = '2026-08-21T10:15:00Z',
  Object? endedAt,
  String? relatedId,
  String? relatedName,
  String? relatedLogin,
  String? email = 'related@example.com',
  String? phone,
  bool isActive = true,
  InstitutionParentStudentPerspective perspective =
      InstitutionParentStudentPerspective.byParent,
}) => <String, Object?>{
  'id': id,
  'parent_id': parentId,
  'student_id': studentId,
  'started_at': startedAt,
  'ended_at': endedAt,
  'related_user': <String, Object?>{
    'id':
        relatedId ??
        (perspective == InstitutionParentStudentPerspective.byParent
            ? studentId
            : parentId),
    'full_name':
        relatedName ??
        (perspective == InstitutionParentStudentPerspective.byParent
            ? 'Student One'
            : 'Parent One'),
    'login_name':
        relatedLogin ??
        (perspective == InstitutionParentStudentPerspective.byParent
            ? 'student.one'
            : 'parent.one'),
    'email': email,
    'phone': phone,
    'is_active': isActive,
  },
};

Map<String, Object?> relationshipListEnvelope({
  List<Object?>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) => <String, Object?>{
  'data': rows ?? [relationshipResource()],
  'meta': {
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
    },
  },
};

InstitutionParentStudentRelationship testRelationship({
  String id = testRelationshipId,
  String parentId = testParentId,
  String studentId = testStudentId,
  DateTime? startedAt,
  bool relatedActive = true,
  InstitutionParentStudentPerspective perspective =
      InstitutionParentStudentPerspective.byParent,
}) => InstitutionParentStudentRelationship(
  id: id,
  parentId: parentId,
  studentId: studentId,
  startedAt: startedAt ?? DateTime.utc(2026, 8, 21, 10, 15),
  endedAt: null,
  relatedUser: InstitutionParentStudentRelatedUser(
    id: perspective == InstitutionParentStudentPerspective.byParent
        ? studentId
        : parentId,
    fullName: perspective == InstitutionParentStudentPerspective.byParent
        ? 'Student One'
        : 'Parent One',
    loginName: perspective == InstitutionParentStudentPerspective.byParent
        ? 'student.one'
        : 'parent.one',
    email: null,
    phone: null,
    isActive: relatedActive,
  ),
);

InstitutionUser testInstitutionUser({
  String id = testParentId,
  InstitutionUserRole role = InstitutionUserRole.parent,
  String fullName = 'Parent One',
  String loginName = 'parent.one',
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

ResponseBody jsonResponse(int statusCode, Object? body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
