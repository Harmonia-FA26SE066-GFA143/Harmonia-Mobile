class ApiEndpoints {
  ApiEndpoints._();

  // Auth endpoints (Harmonia-BE origin/main)
  static const String login = '/api/auth/login';
  static const String google = '/api/auth/google';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String logoutAll = '/api/auth/logout-all';
  static const String changePassword = '/api/auth/change-password';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';

  // Member profile endpoints (ChoirMember /me)
  static const String memberProfileMe = '/api/member-profiles/me';

  // Song library endpoints
  static const String songs = '/api/songs';
  static String songById(String id) => '/api/songs/$id';
  static String songClassification(String id) =>
      '/api/songs/$id/classification';

  // Music materials endpoints
  static const String musicMaterials = '/api/music-materials';
  static const String musicMaterialsMine = '/api/music-materials/mine';
  static String materialLearningProgress(String id) =>
      '/api/music-materials/$id/learning-progress';

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
  static String markNotificationAsRead(String id) =>
      '/api/notifications/$id/read';

  // SignalR Hubs
  static const String notificationHub = '/hubs/notifications';
}
