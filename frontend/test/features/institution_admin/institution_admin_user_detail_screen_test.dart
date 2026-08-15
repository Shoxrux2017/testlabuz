import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_user_detail_screen.dart';

void main() {
  testWidgets('renders all four read-only sections and twelve fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
          authSessionControllerProvider.overrideWith(
            () => _FakeAuthSessionController(_admin()),
          ),
          institutionUserDetailRepositoryProvider.overrideWithValue(
            _FakeDetailRepository(),
          ),
        ],
        child: const MaterialApp(
          home: InstitutionAdminUserDetailScreen(userId: _userId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final text in const [
      'User details',
      'Identity',
      'Contact',
      'Account state',
      'Activity and lifecycle',
      'Full name',
      'Login name',
      'Role',
      'User ID',
      'Email',
      'Phone',
      'Status',
      'First login',
      'Last login',
      'Deactivated',
      'Created',
      'Updated',
      'Teacher Name',
      'teacher01',
      'Teacher',
      'Active',
      'Completed',
      'Never',
      'Not deactivated',
      '2026-08-07 15:00 UTC',
      '2026-08-07 16:00 UTC',
      'Back to Users',
      'Refresh',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.byType(SelectableText), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

const _userId = '00000000-0000-0000-0000-000000000001';

AuthSessionState _admin() => AuthSessionState.authenticated(
  const AuthUser(
    id: 'admin-a',
    institutionId: 'institution-a',
    role: UserRole.institutionAdmin,
    fullName: 'Admin User',
    loginName: 'admin',
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: AuthInstitution(
      id: 'institution-a',
      name: 'Institution A',
      status: 'active',
      timezone: 'Asia/Tashkent',
    ),
  ),
);

class _FakeDetailRepository implements InstitutionUserDetailRepository {
  @override
  Future<InstitutionUser> fetchUser(String userId) async => InstitutionUser(
    id: userId,
    role: InstitutionUserRole.teacher,
    fullName: 'Teacher Name',
    loginName: 'teacher01',
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    lastLoginAt: null,
    deactivatedAt: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
  );
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.session);

  final AuthSessionState session;

  @override
  AuthSessionState build() => session;
}
