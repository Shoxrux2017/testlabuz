import '../../domain/teacher_topic_result.dart';
import '../../domain/teacher_topic_result_mutation.dart';
import 'teacher_dto_parse.dart';
import 'teacher_topic_result_dto.dart';

/// The success body of a single result action: the §25.6 detail and a server
/// message that the client never shows.
TeacherTopicResultDetail readTeacherTopicResultActionResponse(Object? json) {
  final envelope = _readActionEnvelope(json, 'Topic result action');
  return TeacherTopicResultDetailDto.fromJson(envelope['data']).toDomain();
}

/// The success body of a bulk release or close (docs/09 §25.9).
TeacherTopicResultBulkOutcome readTeacherTopicResultBulkResponse(Object? json) {
  final envelope = _readActionEnvelope(json, 'Topic result bulk action');
  final data = readExactTeacherMap(
    envelope['data'],
    context: 'Topic result bulk action data',
    keys: const {'processed', 'skipped'},
  );
  final skipped = readExactTeacherMap(
    data['skipped'],
    context: 'Topic result bulk action skipped',
    keys: const {'already_done', 'not_ready'},
  );
  return TeacherTopicResultBulkOutcome(
    processed: _readCount(data, 'processed'),
    alreadyDone: _readCount(skipped, 'already_done'),
    notReady: _readCount(skipped, 'not_ready'),
  );
}

Map<String, Object?> _readActionEnvelope(Object? json, String context) {
  final envelope = readExactTeacherMap(
    json,
    context: context,
    keys: const {'data', 'message'},
  );
  readTeacherNonBlankString(envelope, 'message');
  return envelope;
}

int _readCount(Map<String, Object?> map, String key) {
  final count = readTeacherInt(map, key);
  if (count < 0) {
    throw FormatException('$key cannot be negative.');
  }
  return count;
}
