/// The review-queue filters a row can set (`CL9-5`).
enum TeacherReviewQueueFilterKind { topic, group, student }

/// Filter the queue to one row's Topic, group or Student; [label] names it
/// on its chip.
class TeacherReviewQueueRowFilter {
  const TeacherReviewQueueRowFilter({
    required this.kind,
    required this.id,
    required this.label,
  });

  final TeacherReviewQueueFilterKind kind;
  final String id;
  final String label;
}
