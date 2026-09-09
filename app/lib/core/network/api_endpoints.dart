class ApiEndpoints {
  ApiEndpoints._();

  /// Defaults to the Android emulator's host-loopback alias for local dev
  /// (iOS simulator / desktop can use localhost instead). Production builds
  /// MUST override this with the real deployed API, e.g.:
  ///   flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
  /// Left unset, a real device can never reach 10.0.2.2 — every request
  /// hangs until it times out instead of failing fast.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String verifyOtp = '/auth/otp/verify';
  static const String resendOtp = '/auth/otp/resend';
  static const String profileSetup = '/auth/profile-setup';
  static const String accountSetup = '/auth/account-setup';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Dashboard
  static const String dashboardOverview = '/dashboard/overview';

  // Accounts
  static const String accounts = '/accounts';
  static String account(String id) => '/accounts/$id';
  static String accountDefault(String id) => '/accounts/$id/set-default';

  // Categories
  static const String categories = '/categories';
  static String category(String id) => '/categories/$id';

  // Transactions
  static const String transactions = '/transactions';
  static const String transactionSummary = '/transactions/summary';
  static String transaction(String id) => '/transactions/$id';

  // Debts / Lending
  static const String debts = '/debts';
  static String debt(String id) => '/debts/$id';
  static String debtSettle(String id) => '/debts/$id/settle';

  // Savings
  static const String savings = '/savings';
  static String savingsGoal(String id) => '/savings/$id';
  static String savingsContribute(String id) => '/savings/$id/contribute';
  static String savingsWithdraw(String id) => '/savings/$id/withdraw';

  // Reports
  static const String reportOverview = '/reports/overview';
  static const String reportTrend = '/reports/trend';
  static const String reportExport = '/reports/export';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnread = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';
  static String notification(String id) => '/notifications/$id';

  // Backups
  static const String backups = '/backups';
  static String backup(String id) => '/backups/$id';
  static String backupRestore(String id) => '/backups/$id/restore';

  // User / security
  static const String updateProfile = '/users/me';
  static const String uploadAvatar = '/users/me/avatar';
  static const String updateSettings = '/users/me/settings';
  static const String changePassword = '/users/me/password';
  static const String securityStatus = '/users/me/security';
  static const String pin = '/users/me/pin';
  static const String verifyPin = '/users/me/pin/verify';
}
