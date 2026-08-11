abstract final class AppRouteNames {
  static const technicalRoot = 'technical-root';
  static const login = 'login';
  static const changePassword = 'change-password';
  static const authenticated = 'authenticated';
  static const platformOwner = 'platform-owner';
  static const platformOwnerInstitutions = 'platform-owner-institutions';
  static const platformOwnerInstitutionDetail =
      'platform-owner-institution-detail';
  static const institutionAdmin = 'institution-admin';
  static const teacher = 'teacher';
  static const student = 'student';
  static const parent = 'parent';
  static const unsupportedDevice = 'unsupported-device';
}

abstract final class AppRoutePaths {
  static const root = '/';
  static const login = '/login';
  static const changePassword = '/change-password';
  static const authenticated = '/authenticated';
  static const platformOwner = '/platform-owner';
  static const platformOwnerInstitutionsSegment = 'institutions';
  static const platformOwnerInstitutionIdParameter = 'institutionId';
  static const platformOwnerInstitutions = '/platform-owner/institutions';
  static const platformOwnerInstitutionDetail =
      '/platform-owner/institutions/:institutionId';
  static const institutionAdmin = '/institution-admin';
  static const teacher = '/teacher';
  static const student = '/student';
  static const parent = '/parent';
  static const unsupportedDevice = '/unsupported-device';

  static const auth = <String>[root, login, changePassword, authenticated];

  static const protected = <String>[
    platformOwner,
    platformOwnerInstitutions,
    institutionAdmin,
    teacher,
    student,
    parent,
    unsupportedDevice,
  ];

  static const all = <String>[...auth, ...protected];

  static const platformOwnerDestinations = <String>[
    platformOwner,
    platformOwnerInstitutions,
  ];

  static bool isPlatformOwnerDestination(String path) {
    return platformOwnerDestinations.contains(path);
  }

  static bool isPlatformOwnerSegment(String path) {
    return path == platformOwner || path.startsWith('$platformOwner/');
  }

  static bool isPlatformOwnerInstitutionDetailPath(String path) {
    const prefix = '$platformOwnerInstitutions/';
    if (!path.startsWith(prefix)) {
      return false;
    }

    final segment = path.substring(prefix.length);

    return segment.isNotEmpty && !segment.contains('/');
  }

  static String platformOwnerInstitutionDetailLocation(String institutionId) {
    return '$platformOwnerInstitutions/${Uri.encodeComponent(institutionId)}';
  }
}
