import 'institution_parent_student_relationship.dart';

class InstitutionParentStudentRelationshipListPage {
  const InstitutionParentStudentRelationshipListPage({
    required this.relationships,
    required this.pagination,
  });

  final List<InstitutionParentStudentRelationship> relationships;
  final InstitutionParentStudentRelationshipListPagination pagination;

  int get rangeStart => relationships.isEmpty
      ? 0
      : (pagination.page - 1) * pagination.perPage + 1;

  int get rangeEnd =>
      relationships.isEmpty ? 0 : rangeStart + relationships.length - 1;
}

class InstitutionParentStudentRelationshipListPagination {
  const InstitutionParentStudentRelationshipListPagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final int page;
  final int perPage;
  final int total;
  final int lastPage;
}
