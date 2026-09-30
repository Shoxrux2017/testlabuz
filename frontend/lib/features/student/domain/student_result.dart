/// A Student's own result for one Attempt, hidden until the Institution releases
/// results.
class StudentAttemptResult {
  const StudentAttemptResult.hidden() : visible = false, normalizedScore = null;

  const StudentAttemptResult.visible(double this.normalizedScore)
    : visible = true;

  final bool visible;
  final double? normalizedScore;
}

/// The official score of a Homework for its Student, shown only when released.
class StudentOfficialScore {
  const StudentOfficialScore({
    required this.normalizedScore,
    required this.attemptNumber,
  });

  final double normalizedScore;
  final int attemptNumber;
}
