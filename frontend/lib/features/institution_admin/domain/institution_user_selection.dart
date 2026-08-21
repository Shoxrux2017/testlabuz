import 'institution_user.dart';
import 'institution_user_list_query.dart';

enum InstitutionUserSelectionPurpose {
  parentAnchor(
    role: InstitutionUserRole.parent,
    activeOnly: false,
    title: 'Select Parent',
  ),
  studentAnchor(
    role: InstitutionUserRole.student,
    activeOnly: false,
    title: 'Select Student',
  ),
  activeParent(
    role: InstitutionUserRole.parent,
    activeOnly: true,
    title: 'Parent',
  ),
  activeStudent(
    role: InstitutionUserRole.student,
    activeOnly: true,
    title: 'Student',
  );

  const InstitutionUserSelectionPurpose({
    required this.role,
    required this.activeOnly,
    required this.title,
  });

  final InstitutionUserRole role;
  final bool activeOnly;
  final String title;

  InstitutionUserListQuery fixedQuery() =>
      const InstitutionUserListQuery.initial().copyWith(
        role: role,
        status: activeOnly ? InstitutionUserStatusFilter.active : null,
        page: 1,
        perPage: 20,
        sort: InstitutionUserListSort.fullName,
        direction: InstitutionUserSortDirection.asc,
      );
}
