import 'student_blitz.dart';
import 'student_finished_blitz.dart';

/// Read-only Student Blitz discovery and pre-Start detail.
abstract interface class StudentBlitzRepository {
  Future<List<StudentActiveBlitzSummary>> fetchActiveBlitz();

  Future<StudentBlitzDetail> fetchBlitz(String blitzId);

  Future<StudentFinishedBlitzPage> fetchFinishedBlitz({
    required int page,
    required int perPage,
  });
}
