class InstitutionDashboard {
  const InstitutionDashboard({
    required this.teachers,
    required this.students,
    required this.parents,
  });

  final int teachers;
  final int students;
  final int parents;

  bool get hasNoUsers => teachers == 0 && students == 0 && parents == 0;
}
