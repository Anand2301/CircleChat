class ApiConstants {
  // By default, for Android Emulator use 10.0.2.2. Can be updated dynamically in Settings.
  static String baseUrl = 'http://10.0.2.2:5000';

  static String get authRegister => '$baseUrl/api/auth/register';
  static String get authLogin => '$baseUrl/api/auth/login';
  static String get authRefresh => '$baseUrl/api/auth/refresh';
  static String get authLogout => '$baseUrl/api/auth/logout';
  static String get authChangePassword => '$baseUrl/api/auth/change-password';

  static String get usersMe => '$baseUrl/api/users/me';
  static String get usersSearch => '$baseUrl/api/users/search';

  static String get conversations => '$baseUrl/api/conversations';
  static String get conversationsDirect => '$baseUrl/api/conversations/direct';
  static String get conversationsGroup => '$baseUrl/api/conversations/group';

  static String conversationDetails(String id) => '$baseUrl/api/conversations/$id';
  static String conversationMessages(String id) => '$baseUrl/api/conversations/$id/messages';
  static String conversationMembers(String id) => '$baseUrl/api/conversations/$id/members';
  static String conversationLeave(String id) => '$baseUrl/api/conversations/$id/leave';

  static String messageDetails(String id) => '$baseUrl/api/messages/$id';
  static String messageReactions(String id) => '$baseUrl/api/messages/$id/reactions';
  static String messageRead(String id) => '$baseUrl/api/messages/$id/read';

  static String get attachmentsUpload => '$baseUrl/api/attachments/upload';
  static String get devices => '$baseUrl/api/devices';

  static String get signalRHubUrl => '$baseUrl/hubs/chat';
}
