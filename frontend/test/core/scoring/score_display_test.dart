import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/scoring/score_display.dart';

void main() {
  test('scores show one decimal with standard half-up rounding', () {
    final cases = <double, String>{
      0: '0.0',
      75: '75.0',
      100: '100.0',
      66.66666667: '66.7',
      33.33333333: '33.3',
      // The binary double for 1.45 is just below it; the decimal value rounds up.
      1.45: '1.5',
      12.25: '12.3',
      0.05: '0.1',
      0.04999999: '0.0',
      99.95: '100.0',
      0.00000001: '0.0',
    };

    for (final MapEntry(key: score, value: expected) in cases.entries) {
      expect(formatScoreOneDecimal(score), expected, reason: '$score');
    }
  });

  test('a negative or non-finite score is rejected', () {
    for (final invalid in [-0.1, double.nan, double.infinity]) {
      expect(() => formatScoreOneDecimal(invalid), throwsArgumentError);
    }
  });
}
