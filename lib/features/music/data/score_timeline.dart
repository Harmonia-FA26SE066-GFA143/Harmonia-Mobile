import 'dart:convert';

typedef ScoreNote = ({int pitch, double start, double end});

List<ScoreNote> parseScoreNotes(List<int> bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, dynamic> ||
      decoded['schemaVersion'] != 1 ||
      decoded['timeUnit'] != 'seconds') {
    throw const FormatException('Unsupported note timeline.');
  }
  final rows = decoded['notes'];
  if (rows is! List || rows.isEmpty || rows.length > 100000) {
    throw const FormatException('Invalid note count.');
  }
  final notes = <ScoreNote>[];
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
    notes.add((
      pitch: pitch,
      start: start.toDouble(),
      end: (start + duration).toDouble(),
    ));
  }
  return notes;
}
