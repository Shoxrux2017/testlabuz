import 'package:flutter/material.dart';

/// The range of a Teacher date picker: 2000-01-01 to 2100-12-31, widened to
/// include [initial], since a stored date may lie outside it (the server
/// accepts any four-digit year).
({DateTime first, DateTime last}) teacherDatePickerRange(DateTime initial) {
  final day = DateUtils.dateOnly(initial);
  final first = DateTime(2000);
  final last = DateTime(2100, 12, 31);
  return (
    first: day.isBefore(first) ? day : first,
    last: day.isAfter(last) ? day : last,
  );
}
