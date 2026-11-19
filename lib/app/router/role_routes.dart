import '../../core/session/session_manager.dart';

String workspacePath(MobileRole role) => switch (role) {
  MobileRole.choirMember => '/practice',
  MobileRole.choirDirector => '/manage',
  MobileRole.parishPriest => '/approvals',
};

bool roleAllowsRoute(MobileRole? role, Uri uri) {
  return switch (uri.pathSegments.firstOrNull?.toLowerCase()) {
    'manage' ||
    'staff-library' ||
    'staff-members' ||
    'staff-member' ||
    'staff-choir' ||
    'staff-choir-requests' ||
    'staff-skill-approval' ||
    'staff-rehearsals' ||
    'staff-attendance' ||
    'staff-roster' ||
    'staff-practice' ||
    'staff-submissions' ||
    'staff-submission' => role == MobileRole.choirDirector,
    'staff-demo' => false,
    'director-nominations' when uri.pathSegments.elementAtOrNull(1) == 'new' =>
      role == MobileRole.choirDirector || role == MobileRole.parishPriest,
    'interactive-score' || 'director-nominations' => role != null,
    'approvals' || 'program-new' => role == MobileRole.parishPriest,
    'song-list' ||
    'director-note' ||
    'staff-chat' ||
    'staff-chat-new' ||
    'staff-reports' ||
    'staff-scores' ||
    'staff-participation' =>
      role == MobileRole.choirDirector || role == MobileRole.parishPriest,
    'rehearsal' => role != MobileRole.parishPriest,
    'practice' ||
    'practice-detail' ||
    'practice-history' ||
    'practice-submission' ||
    'music-library' ||
    'choir-membership' ||
    'music-material' => role == MobileRole.choirMember,
    'profile' when uri.pathSegments.length > 1 =>
      role == MobileRole.choirMember,
    _ => true,
  };
}

String? notificationRoute({
  required MobileRole? role,
  required String? referenceType,
  required String? referenceId,
}) {
  final type = referenceType?.trim();
  if (type == 'MemberSkill') {
    return role == MobileRole.choirMember ? '/profile' : null;
  }
  final id = referenceId?.trim();
  if (id == null || id.isEmpty) return null;
  if (type == 'Choir') {
    return switch (role) {
      MobileRole.choirDirector => '/manage',
      MobileRole.choirMember => '/choir-membership',
      _ => null,
    };
  }
  if (type == 'ChoirJoinRequest') {
    return switch (role) {
      MobileRole.choirDirector => '/staff-choir-requests',
      MobileRole.choirMember => '/choir-membership',
      _ => null,
    };
  }
  final segment = switch (type) {
    'DirectorNomination' => 'director-nominations',
    'LiturgicalEvent' => 'event-detail',
    'Rehearsal' => 'rehearsal',
    'PracticeAssignment' => 'practice-detail',
    'PracticeSubmission' =>
      role == MobileRole.choirDirector
          ? 'staff-submission'
          : 'practice-submission',
    'Song' => 'song-detail',
    'SongList' => 'song-list',
    'DirectorNote' => 'director-note',
    _ => null,
  };
  if (segment == null) return null;
  final target = Uri(pathSegments: ['', segment, id]);
  return roleAllowsRoute(role, target) ? target.toString() : null;
}
