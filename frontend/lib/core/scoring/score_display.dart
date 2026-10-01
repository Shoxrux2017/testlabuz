/// Formats a 0-100 score with one decimal place, rounding half-up on its
/// decimal value (`S09-DOC-001` §6).
///
/// API scores carry at most 8 decimal places, so their 8-place decimal string
/// is exact; rounding that string avoids binary errors such as 1.45 → 1.4.
String formatScoreOneDecimal(double score) {
  if (!score.isFinite || score < 0) {
    throw ArgumentError.value(score, 'score', 'Must be a finite score >= 0.');
  }
  final scaled = BigInt.parse(score.toStringAsFixed(8).replaceFirst('.', ''));
  final tenths = (scaled + BigInt.from(5000000)) ~/ BigInt.from(10000000);
  final whole = tenths ~/ BigInt.from(10);
  final fraction = tenths.remainder(BigInt.from(10));
  return '$whole.$fraction';
}
