class ApiEndpoints {
  ApiEndpoints._();

  // Auth endpoints (Harmonia-BE origin/main)
  static const String login = '/api/auth/login';
  static const String google = '/api/auth/google';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String logoutAll = '/api/auth/logout-all';
  static const String changePassword = '/api/auth/change-password';
  static const String authMe = '/api/auth/me';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';

  // Member profile endpoints (ChoirMember /me)
  static const String memberProfileMe = '/api/member-profiles/me';
  static const String memberProfileHistory = '/api/member-profiles/me/history';

  // Member skills endpoints (ChoirMember)
  static const String memberSkills = '/api/member-skills';
  static const String memberSkillsMine = '/api/member-skills/mine';
  static String memberSkillById(String id) => '/api/member-skills/$id';

  // Schedule endpoints (Upcoming events & rehearsals)
  static const String scheduleEvents = '/api/schedule/events';
  static const String myParticipations = '/api/event-participations/mine';
  static const String scheduleAssignments = '/api/schedule/assignments';
  static String scheduleEvent(String id) => '/api/schedule/events/$id';
  static String scheduleRehearsal(String id) => '/api/schedule/rehearsals/$id';
  static String respondParticipation(String eventId) =>
      '/api/event-participations/mine/$eventId';
  static const String liturgicalDays = '/api/liturgical-days';
  static String liturgicalDay(String date) => '/api/liturgical-days/$date';
  static const String publicSystemSettings = '/api/system-settings/public';
  static String rehearsalSongs(String id) => '/api/rehearsals/$id/songs';
  static const String scheduleRehearsals = '/api/schedule/rehearsals';

  // Song library endpoints
  static const String songs = '/api/songs';
  static String songById(String id) => '/api/songs/$id';
  static String songClassification(String id) =>
      '/api/songs/$id/classification';
  static String approvedSongList(String eventId) =>
      '/api/song-lists/event/$eventId/approved';

  // Music materials endpoints
  static const String musicMaterials = '/api/music-materials';
  static const String musicMaterialsMine = '/api/music-materials/mine';
  static String materialLearningProgress(String id) =>
      '/api/music-materials/$id/learning-progress';

  // Practice assignments & submissions (ChoirMember)
  static const String practiceAssignmentsMine =
      '/api/practice-assignments/mine';
  static const String practiceAssignmentsMineCounts =
      '/api/practice-assignments/mine/counts';
  static String practiceAssignmentMineById(String id) =>
      '/api/practice-assignments/mine/$id';
  static String practiceAssignmentSubmissions(String id) =>
      '/api/practice-assignments/$id/submissions';
  static const String practiceSubmissionsMine =
      '/api/practice-submissions/mine';
  static String practiceSubmissionMineById(String id) =>
      '/api/practice-submissions/mine/$id';

  // Lookups endpoints (Catalogs)
  static const String lookupMassTypes = '/api/lookups/mass-types';
  static const String lookupCeremonyTypes = '/api/lookups/ceremony-types';
  static const String lookupEventCategories = '/api/lookups/event-categories';
  static const String lookupSongThemes = '/api/lookups/song-themes';
  static const String lookupSkillCategories = '/api/lookups/skill-categories';
  static const String lookupLiturgicalSeasons =
      '/api/lookups/liturgical-seasons';
  static const String lookupLiturgicalSlots = '/api/lookups/liturgical-slots';
  static const String lookupWorshipLocations = '/api/lookups/worship-locations';
  static const String lookupSkills = '/api/lookups/skills';

  // Notifications endpoints
  static const String notifications = '/api/notifications';
  static const String notificationsUnreadCount =
      '/api/notifications/unread-count';
  static const String markAllNotificationsAsRead =
      '/api/notifications/read-all';
  static String markNotificationAsRead(String id) =>
      '/api/notifications/$id/read';

  // SignalR Hubs
  static const String notificationHub = '/hubs/notifications';
}
