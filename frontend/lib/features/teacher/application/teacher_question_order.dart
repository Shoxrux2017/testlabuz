import '../domain/teacher_question.dart';

/// Canonical lowercase Question IDs in authoritative position order.
List<String> teacherQuestionOrder(Iterable<TeacherQuestion> questions) {
  final ordered = questions.toList()
    ..sort((left, right) => left.position.compareTo(right.position));
  return List<String>.unmodifiable(
    ordered.map((question) => question.id.toLowerCase()),
  );
}

bool sameTeacherQuestionOrder(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].toLowerCase() != right[index].toLowerCase()) {
      return false;
    }
  }
  return true;
}

bool sameTeacherQuestionIdSet(List<String> left, List<String> right) {
  final leftSet = left.map((id) => id.toLowerCase()).toSet();
  final rightSet = right.map((id) => id.toLowerCase()).toSet();
  return leftSet.length == left.length &&
      rightSet.length == right.length &&
      leftSet.length == rightSet.length &&
      leftSet.containsAll(rightSet);
}
