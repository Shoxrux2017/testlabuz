import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';

class TeacherSessionSnapshot {
  const TeacherSessionSnapshot({
    required this.status,
    required this.userId,
    required this.userInstance,
    required this.userInstitutionId,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.institutionId,
    required this.institutionStatus,
    required this.institutionTimezone,
    required this.surface,
  });

  factory TeacherSessionSnapshot.fromSession(
    AuthSessionState session,
    AppDeviceSurface surface,
  ) {
    final user = session.user;
    final institution = user?.institution;

    return TeacherSessionSnapshot(
      status: session.status,
      userId: user?.id,
      userInstance: user,
      userInstitutionId: user?.institutionId,
      role: user?.role,
      isActive: user?.isActive,
      mustChangePassword: user?.mustChangePassword,
      institutionId: institution?.id,
      institutionStatus: institution?.status,
      institutionTimezone: institution?.timezone,
      surface: surface,
    );
  }

  final AuthSessionStatus status;
  final String? userId;
  final Object? userInstance;
  final String? userInstitutionId;
  final UserRole? role;
  final bool? isActive;
  final bool? mustChangePassword;
  final String? institutionId;
  final String? institutionStatus;
  final String? institutionTimezone;
  final AppDeviceSurface surface;

  TeacherSessionKey? get eligibleKey {
    final currentUserId = userId;
    final currentUserInstance = userInstance;
    final currentInstitutionId = userInstitutionId;
    final currentInstitutionTimezone = institutionTimezone;
    if (status != AuthSessionStatus.authenticated ||
        currentUserId == null ||
        currentUserInstance == null ||
        role != UserRole.teacher ||
        isActive != true ||
        mustChangePassword != false ||
        currentInstitutionId == null ||
        currentInstitutionId.trim().isEmpty ||
        institutionId != currentInstitutionId ||
        institutionStatus != 'active' ||
        currentInstitutionTimezone == null ||
        currentInstitutionTimezone.trim().isEmpty ||
        (surface != AppDeviceSurface.desktop &&
            surface != AppDeviceSurface.mobile)) {
      return null;
    }

    return TeacherSessionKey(
      userId: currentUserId,
      userInstance: currentUserInstance,
      institutionId: currentInstitutionId,
      institutionTimezone: currentInstitutionTimezone,
      surface: surface,
    );
  }
}

class TeacherSessionKey {
  const TeacherSessionKey({
    required this.userId,
    required this.userInstance,
    required this.institutionId,
    required this.institutionTimezone,
    required this.surface,
  });

  final String userId;
  final Object userInstance;
  final String institutionId;
  final String institutionTimezone;
  final AppDeviceSurface surface;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherSessionKey &&
            other.userId == userId &&
            identical(other.userInstance, userInstance) &&
            other.institutionId == institutionId &&
            other.institutionTimezone == institutionTimezone &&
            other.surface == surface;
  }

  @override
  int get hashCode => Object.hash(
    userId,
    identityHashCode(userInstance),
    institutionId,
    institutionTimezone,
    surface,
  );
}
