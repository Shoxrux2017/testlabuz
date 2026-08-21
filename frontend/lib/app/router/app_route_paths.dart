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
  static const institutionAdminUsers = 'institution-admin-users';
  static const institutionAdminGroups = 'institution-admin-groups';
  static const institutionAdminUserCreate = 'institution-admin-user-create';
  static const institutionAdminUserDetail = 'institution-admin-user-detail';
  static const institutionAdminInstitution = 'institution-admin-institution';
  static const institutionAdminSettings = 'institution-admin-settings';
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
  static const institutionAdminUsersSegment = 'users';
  static const institutionAdminGroupsSegment = 'groups';
  static const institutionAdminUserCreateSegment = 'new';
  static const institutionAdminUserIdParameter = 'userId';
  static const institutionAdminInstitutionSegment = 'institution';
  static const institutionAdminSettingsSegment = 'settings';
  static const institutionAdminUsers =
      '$institutionAdmin/$institutionAdminUsersSegment';
  static const institutionAdminGroups =
      '$institutionAdmin/$institutionAdminGroupsSegment';
  static const institutionAdminUserCreate =
      '$institutionAdminUsers/$institutionAdminUserCreateSegment';
  static const institutionAdminUserDetail =
      '$institutionAdminUsers/:$institutionAdminUserIdParameter';
  static const institutionAdminInstitution =
      '$institutionAdmin/$institutionAdminInstitutionSegment';
  static const institutionAdminSettings =
      '$institutionAdmin/$institutionAdminSettingsSegment';
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
    institutionAdminUsers,
    institutionAdminGroups,
    institutionAdminUserCreate,
    institutionAdminUserDetail,
    institutionAdminInstitution,
    institutionAdminSettings,
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

  static const institutionAdminPrimaryDestinations = <String>[
    institutionAdmin,
    institutionAdminUsers,
    institutionAdminGroups,
    institutionAdminInstitution,
    institutionAdminSettings,
  ];

  static const _institutionAdminStaticLocations = <String>[
    ...institutionAdminPrimaryDestinations,
    institutionAdminUserCreate,
  ];

  static final RegExp _institutionAdminUserIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

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

  static bool isInstitutionAdminPrimaryDestination(String path) {
    return institutionAdminPrimaryDestinations.contains(path);
  }

  static bool isInstitutionAdminUserCreatePath(String path) {
    return path == institutionAdminUserCreate;
  }

  static bool isInstitutionAdminUserDetailPath(String path) {
    const prefix = '$institutionAdminUsers/';
    if (!path.startsWith(prefix)) {
      return false;
    }

    final userId = path.substring(prefix.length);

    return _institutionAdminUserIdPattern.hasMatch(userId);
  }

  static bool isInstitutionAdminApprovedLocation(String path) {
    return _institutionAdminStaticLocations.contains(path) ||
        isInstitutionAdminUserDetailPath(path);
  }

  static bool isInstitutionAdminSegment(String path) {
    return path == institutionAdmin || path.startsWith('$institutionAdmin/');
  }

  static String institutionAdminUserDetailLocation(String userId) {
    if (!_institutionAdminUserIdPattern.hasMatch(userId)) {
      throw ArgumentError.value(
        userId,
        'userId',
        'Must be an untrimmed canonical hyphenated UUID.',
      );
    }

    return '$institutionAdminUsers/${Uri.encodeComponent(userId)}';
  }
}
