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
  static const institutionAdminGroupCreate = 'institution-admin-group-create';
  static const institutionAdminGroupDetail = 'institution-admin-group-detail';
  static const institutionAdminUserCreate = 'institution-admin-user-create';
  static const institutionAdminParentStudentConnections =
      'institution-admin-parent-student-connections';
  static const institutionAdminUserDetail = 'institution-admin-user-detail';
  static const institutionAdminInstitution = 'institution-admin-institution';
  static const institutionAdminSettings = 'institution-admin-settings';
  static const teacher = 'teacher';
  static const teacherTopicCreate = 'teacher-topic-create';
  static const teacherTopicDetail = 'teacher-topic-detail';
  static const teacherTopicEdit = 'teacher-topic-edit';
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
  static const institutionAdminGroupCreateSegment = 'new';
  static const institutionAdminGroupIdParameter = 'groupId';
  static const institutionAdminUserCreateSegment = 'new';
  static const institutionAdminParentStudentConnectionsSegment =
      'parent-student-connections';
  static const institutionAdminUserIdParameter = 'userId';
  static const institutionAdminInstitutionSegment = 'institution';
  static const institutionAdminSettingsSegment = 'settings';
  static const institutionAdminUsers =
      '$institutionAdmin/$institutionAdminUsersSegment';
  static const institutionAdminGroups =
      '$institutionAdmin/$institutionAdminGroupsSegment';
  static const institutionAdminGroupCreate =
      '$institutionAdminGroups/$institutionAdminGroupCreateSegment';
  static const institutionAdminGroupDetail =
      '$institutionAdminGroups/:$institutionAdminGroupIdParameter';
  static const institutionAdminUserCreate =
      '$institutionAdminUsers/$institutionAdminUserCreateSegment';
  static const institutionAdminParentStudentConnections =
      '$institutionAdminUsers/'
      '$institutionAdminParentStudentConnectionsSegment';
  static const institutionAdminUserDetail =
      '$institutionAdminUsers/:$institutionAdminUserIdParameter';
  static const institutionAdminInstitution =
      '$institutionAdmin/$institutionAdminInstitutionSegment';
  static const institutionAdminSettings =
      '$institutionAdmin/$institutionAdminSettingsSegment';
  static const teacher = '/teacher';
  static const teacherTopicsSegment = 'topics';
  static const teacherTopicCreateSegment = 'new';
  static const teacherTopicEditSegment = 'edit';
  static const teacherTopicIdParameter = 'topicId';
  static const teacherTopicCreate =
      '$teacher/$teacherTopicsSegment/$teacherTopicCreateSegment';
  static const teacherTopicDetail =
      '$teacher/$teacherTopicsSegment/:$teacherTopicIdParameter';
  static const teacherTopicEdit =
      '$teacherTopicDetail/$teacherTopicEditSegment';
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
    institutionAdminGroupCreate,
    institutionAdminGroupDetail,
    institutionAdminUserCreate,
    institutionAdminParentStudentConnections,
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
    institutionAdminParentStudentConnections,
    institutionAdminGroupCreate,
  ];

  static final RegExp _institutionAdminUserIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _institutionAdminGroupIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _teacherTopicIdPattern = RegExp(
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

  static bool isInstitutionAdminParentStudentConnectionsPath(String path) {
    return path == institutionAdminParentStudentConnections;
  }

  static bool isInstitutionAdminUserDetailPath(String path) {
    const prefix = '$institutionAdminUsers/';
    if (!path.startsWith(prefix)) {
      return false;
    }

    final userId = path.substring(prefix.length);

    return _institutionAdminUserIdPattern.hasMatch(userId);
  }

  static bool isInstitutionAdminGroupCreatePath(String path) {
    return path == institutionAdminGroupCreate;
  }

  static bool isInstitutionAdminGroupDetailPath(String path) {
    const prefix = '$institutionAdminGroups/';
    if (!path.startsWith(prefix)) {
      return false;
    }

    final groupId = path.substring(prefix.length);

    return groupId != institutionAdminGroupCreateSegment &&
        _institutionAdminGroupIdPattern.hasMatch(groupId);
  }

  static bool isInstitutionAdminApprovedLocation(String path) {
    return _institutionAdminStaticLocations.contains(path) ||
        isInstitutionAdminUserDetailPath(path) ||
        isInstitutionAdminGroupDetailPath(path);
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

  static String institutionAdminGroupDetailLocation(String groupId) {
    if (!_institutionAdminGroupIdPattern.hasMatch(groupId) ||
        groupId == institutionAdminGroupCreateSegment) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Must be an untrimmed canonical hyphenated UUID.',
      );
    }

    return '$institutionAdminGroups/${Uri.encodeComponent(groupId)}';
  }

  static bool isTeacherSegment(String path) {
    return path == teacher || path.startsWith('$teacher/');
  }

  static bool isTeacherTopicCreatePath(String path) {
    return path == teacherTopicCreate;
  }

  static bool isTeacherTopicDetailPath(String path) {
    final topicId = teacherTopicIdFromPath(path);
    return topicId != null && !path.endsWith('/$teacherTopicEditSegment');
  }

  static bool isTeacherTopicEditPath(String path) {
    const suffix = '/$teacherTopicEditSegment';
    if (!path.endsWith(suffix)) {
      return false;
    }

    return teacherTopicIdFromPath(path) != null;
  }

  static bool isTeacherApprovedLocation(String path) {
    return path == teacher ||
        isTeacherTopicCreatePath(path) ||
        isTeacherTopicDetailPath(path) ||
        isTeacherTopicEditPath(path);
  }

  static String? teacherTopicIdFromPath(String path) {
    const prefix = '$teacher/$teacherTopicsSegment/';
    if (!path.startsWith(prefix)) {
      return null;
    }
    var remainder = path.substring(prefix.length);
    const editSuffix = '/$teacherTopicEditSegment';
    if (remainder.endsWith(editSuffix)) {
      remainder = remainder.substring(0, remainder.length - editSuffix.length);
    }
    if (remainder == teacherTopicCreateSegment ||
        !_teacherTopicIdPattern.hasMatch(remainder)) {
      return null;
    }

    return remainder;
  }

  static String teacherTopicDetailLocation(String topicId) {
    if (!_teacherTopicIdPattern.hasMatch(topicId)) {
      throw ArgumentError.value(
        topicId,
        'topicId',
        'Must be an untrimmed canonical hyphenated UUID.',
      );
    }

    return '$teacher/$teacherTopicsSegment/${Uri.encodeComponent(topicId)}';
  }

  static String teacherTopicEditLocation(String topicId) {
    return '${teacherTopicDetailLocation(topicId)}/$teacherTopicEditSegment';
  }
}
