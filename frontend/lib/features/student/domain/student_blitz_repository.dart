import 'student_blitz.dart';

/// Read-only Student Blitz discovery and pre-Start detail.
abstract interface class StudentBlitzRepository {
  Future<List<StudentActiveBlitzSummary>> fetchActiveBlitz();

  Future<StudentBlitzDetail> fetchBlitz(String blitzId);
}
