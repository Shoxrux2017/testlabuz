abstract final class AppRouteNames {
  static const technicalRoot = 'technical-root';
  static const login = 'login';
  static const changePassword = 'change-password';
  static const authenticated = 'authenticated';
  static const platformOwner = 'platform-owner';
  static const platformOwnerInstitutions = 'platform-owner-institutions';
  static const platformOwnerInstitutionCreate =
      'platform-owner-institution-create';
  static const platformOwnerInstitutionDetail =
      'platform-owner-institution-detail';
  static const platformOwnerInstitutionEdit = 'platform-owner-institution-edit';
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
  static const platformOwnerInstitutionCreateSegment = 'new';
  static const platformOwnerInstitutionEditSegment = 'edit';
  static const platformOwnerInstitutionIdParameter = 'institutionId';
  static const platformOwnerInstitutions = '/platform-owner/institutions';
  static const platformOwnerInstitutionCreate =
      '/platform-owner/institutions/new';
  static const platformOwnerInstitutionDetail =
      '/platform-owner/institutions/:institutionId';
  static const platformOwnerInstitutionEdit =
      '/platform-owner/institutions/:institutionId/edit';
  static const institutionAdmin = '/institution-admin';
  static const teacher = '/teacher';
  static const student = '/student';
  static const parent = '/parent';
  static const unsupportedDevice = '/unsupported-device';

  static const auth = <String>[root, login, changePassword, authenticated];

  static const protected = <String>[
    platformOwner,
    platformOwnerInstitutions,
    platformOwnerInstitutionCreate,
    platformOwnerInstitutionEdit,
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

    return segment.isNotEmpty &&
        segment != platformOwnerInstitutionCreateSegment &&
        !segment.contains('/');
  }

  static String platformOwnerInstitutionDetailLocation(String institutionId) {
    return '$platformOwnerInstitutions/${Uri.encodeComponent(institutionId)}';
  }

  static String platformOwnerInstitutionEditLocation(String institutionId) {
    return '${platformOwnerInstitutionDetailLocation(institutionId)}/edit';
  }

  static bool isPlatformOwnerInstitutionCreatePath(String path) {
    return path == platformOwnerInstitutionCreate;
  }

  static bool isPlatformOwnerInstitutionEditPath(String path) {
    const prefix = '$platformOwnerInstitutions/';
    const suffix = '/$platformOwnerInstitutionEditSegment';
    if (!path.startsWith(prefix) || !path.endsWith(suffix)) {
      return false;
    }

    final segment = path.substring(prefix.length, path.length - suffix.length);

    return segment.isNotEmpty && !segment.contains('/');
  }
}
