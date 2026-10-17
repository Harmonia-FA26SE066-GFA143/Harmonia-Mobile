import 'liturgical_models.dart';

class ParticipationReply {
  final String eventId;
  final ParticipationStatus status;
  const ParticipationReply({required this.eventId, required this.status});
  factory ParticipationReply.fromJson(Map<String, dynamic> json) =>
      ParticipationReply(
        eventId: json['eventId'] as String,
        status: ParticipationStatus.fromWire(json['status']),
      );
}

class RehearsalSong {
  final String songId;
  final String title;
  final int displayOrder;
  final String? note;
  const RehearsalSong({
    required this.songId,
    required this.title,
    required this.displayOrder,
    this.note,
  });
  factory RehearsalSong.fromJson(Map<String, dynamic> json) => RehearsalSong(
    songId: json['songId'] as String,
    title: json['songTitle'] as String,
    displayOrder: (json['displayOrder'] as num).toInt(),
    note: json['note'] as String?,
  );
}

class LiturgicalDay {
  final DateTime date;
  final String celebrationName;
  final String? rank;
  final String? seasonName;
  const LiturgicalDay({
    required this.date,
    required this.celebrationName,
    this.rank,
    this.seasonName,
  });
  factory LiturgicalDay.fromJson(Map<String, dynamic> json) => LiturgicalDay(
    date: DateTime.parse(json['date'] as String),
    celebrationName: json['celebrationName'] as String,
    rank: json['rank'] as String?,
    seasonName: json['seasonName'] as String?,
  );
}

class PublicAppSettings {
  final String choirName;
  final String parishName;
  final String announcement;
  const PublicAppSettings({
    this.choirName = '',
    this.parishName = '',
    this.announcement = '',
  });
  factory PublicAppSettings.fromList(List<Map<String, dynamic>> rows) {
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return PublicAppSettings(
      choirName: values['Choir.Name'] ?? '',
      parishName: values['Parish.Name'] ?? '',
      announcement: values['System.Announcement'] ?? '',
    );
  }
}
