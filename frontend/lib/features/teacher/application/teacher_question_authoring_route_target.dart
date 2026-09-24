/// Route identity of an assessment whose Questions a Teacher authors.
///
/// Implementations keep their own equality, so a Homework target and a Blitz
/// target never share Question-authoring state.
abstract interface class TeacherQuestionAuthoringRouteTarget {
  String get topicId;
  String get assessmentId;
}
