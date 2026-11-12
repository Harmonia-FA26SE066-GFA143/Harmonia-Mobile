import 'dart:convert';

typedef ScoreNote = ({int pitch, double start, double end});

typedef ScoreLocator = ({String id, double start, double end});
typedef ScoreTimeline = ({List<ScoreNote> notes, List<ScoreLocator> locators});

List<ScoreNote> parseScoreNotes(List<int> bytes) =>
    parseScoreTimeline(bytes).notes;

ScoreTimeline parseScoreTimeline(List<int> bytes, {int? expectedVersion}) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, dynamic> ||
      !const [1, 2].contains(decoded['schemaVersion']) ||
      (expectedVersion != null &&
          decoded['schemaVersion'] != expectedVersion) ||
      decoded['timeUnit'] != 'seconds' ||
      (decoded['schemaVersion'] == 2 && decoded['readingOrder'] != 'written')) {
    throw const FormatException('Unsupported note timeline.');
  }
  final rows = decoded['notes'];
  if (rows is! List || rows.isEmpty || rows.length > 100000) {
    throw const FormatException('Invalid note count.');
  }
  final notes = <ScoreNote>[];
  final locators = <ScoreLocator>[];
  for (final row in rows) {
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid note.');
    }
    final pitch = row['pitch'];
    final start = row['start'];
    final duration = row['duration'];
    if (pitch is! int ||
        pitch < 0 ||
        pitch > 127 ||
        start is! num ||
        !start.isFinite ||
        start < 0 ||
        duration is! num ||
        !duration.isFinite ||
        duration < 0 ||
        !(start + duration).isFinite) {
      throw const FormatException('Invalid note timing or pitch.');
    }
    final end = (start + duration).toDouble();
    notes.add((pitch: pitch, start: start.toDouble(), end: end));
    if (decoded['schemaVersion'] == 2) {
      final part = row['partId'];
      final measure = row['measureIndex'];
      final index = row['noteIndex'];
      if (part is! String ||
          part.isEmpty ||
          measure is! int ||
          measure < 0 ||
          index is! int ||
          index < 0) {
        throw const FormatException('Invalid score locator.');
      }
      locators.add((
        id: '$part:$measure:$index',
        start: start.toDouble(),
        end: end,
      ));
    }
  }
  return (notes: notes, locators: locators);
}
