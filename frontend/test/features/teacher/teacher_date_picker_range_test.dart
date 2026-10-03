import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_date_picker_range.dart';

void main() {
  test('the range is 2000 to 2100 for an ordinary date', () {
    final range = teacherDatePickerRange(DateTime(2026, 9, 21));

    expect(range.first, DateTime(2000));
    expect(range.last, DateTime(2100, 12, 31));
  });

  test('the range widens to include an earlier or later stored date', () {
    final early = teacherDatePickerRange(DateTime(1999, 3, 4, 10, 30));
    expect(early.first, DateTime(1999, 3, 4));
    expect(early.last, DateTime(2100, 12, 31));

    final late = teacherDatePickerRange(DateTime(2150, 1, 2, 23, 59));
    expect(late.first, DateTime(2000));
    expect(late.last, DateTime(2150, 1, 2));
  });
}
