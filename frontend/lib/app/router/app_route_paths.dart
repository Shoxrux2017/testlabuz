abstract final class AppRouteNames {
  static const technicalRoot = 'technical-root';
  static const login = 'login';
  static const changePassword = 'change-password';
  static const authenticated = 'authenticated';
  static const platformOwner = 'platform-owner';
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
  static const institutionAdmin = '/institution-admin';
  static const teacher = '/teacher';
  static const student = '/student';
  static const parent = '/parent';
  static const unsupportedDevice = '/unsupported-device';

  static const auth = <String>[root, login, changePassword, authenticated];

  static const protected = <String>[
    platformOwner,
    institutionAdmin,
    teacher,
    student,
    parent,
    unsupportedDevice,
  ];

  static const all = <String>[...auth, ...protected];
}
