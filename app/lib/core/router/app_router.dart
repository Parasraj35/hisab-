import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/account_setup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/accounts/presentation/account_detail_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/debts/presentation/debts_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/backup_screen.dart';
import '../../features/settings/presentation/help_screen.dart';
import '../../features/settings/presentation/profile_screen.dart';
import '../../features/settings/presentation/security_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/reports/presentation/export_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/savings/presentation/savings_screen.dart';
import '../../features/transactions/presentation/history_screen.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import '../../features/transactions/presentation/transaction_edit_screen.dart';
import '../../features/transactions/presentation/transaction_form_screen.dart';
import '../../features/transactions/presentation/transfer_screen.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/state/auth_controller.dart';
import '../network/api_client.dart';

/// Rebuilds GoRouter's redirect whenever auth status changes, or once the
/// async "has seen onboarding" read resolves (it starts unresolved, so the
/// first redirect pass has to guess — this re-runs it with the real value).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
    ref.listen(onboardingSeenProvider, (_, __) => notifyListeners());
  }
}

final onboardingSeenProvider = FutureProvider<bool>(
  (ref) => ref.read(tokenStorageProvider).hasSeenOnboarding(),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-otp', builder: (_, __) => const OtpScreen()),
      GoRoute(
          path: '/profile-setup',
          builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(
          path: '/account-setup',
          builder: (_, __) => const AccountSetupScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/accounts', builder: (_, __) => const AccountsScreen()),
      GoRoute(
          path: '/add-expense', builder: (_, __) => const AddExpenseScreen()),
      GoRoute(path: '/add-income', builder: (_, __) => const AddIncomeScreen()),

      // Registered ahead of their batch so every link on a built screen works.
      GoRoute(path: '/transfer', builder: (_, __) => const TransferScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/debts', builder: (_, __) => const DebtsScreen()),
      GoRoute(path: '/savings', builder: (_, __) => const SavingsScreen()),
      GoRoute(
        path: '/transactions/:id',
        builder: (_, state) =>
            TransactionDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) =>
                TransactionEditScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (_, state) =>
            AccountDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/export', builder: (_, __) => const ExportScreen()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/backup', builder: (_, __) => const BackupScreen()),
      GoRoute(path: '/security', builder: (_, __) => const SecurityScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: '/categories', builder: (_, __) => const CategoriesScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
    ],
    errorBuilder: (_, state) =>
        ComingSoonScreen(title: 'Not found', batch: 'a later batch'),
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;

      // Splash owns the "unknown" state until restoreSession() resolves.
      if (status == AuthStatus.unknown) return loc == '/' ? null : '/';

      // Default to "not seen" while the read is still resolving — the
      // _AuthRefresh listener above re-runs this redirect once it settles,
      // so a wrong guess here self-corrects instead of getting stuck.
      final seenOnboarding = ref.read(onboardingSeenProvider).value ?? false;

      switch (status) {
        case AuthStatus.unauthenticated:
          if (!seenOnboarding && loc != '/onboarding') return '/onboarding';
          const publicRoutes = {
            '/login',
            '/signup',
            '/forgot-password',
            '/onboarding'
          };
          return publicRoutes.contains(loc) ? null : '/login';
        case AuthStatus.needsOtp:
          return loc == '/verify-otp' ? null : '/verify-otp';
        case AuthStatus.needsProfile:
          return loc == '/profile-setup' ? null : '/profile-setup';
        case AuthStatus.needsAccount:
          return loc == '/account-setup' ? null : '/account-setup';
        case AuthStatus.authenticated:
          const gatedRoutes = {
            '/',
            '/login',
            '/signup',
            '/onboarding',
            '/verify-otp',
            '/profile-setup',
            '/account-setup',
          };
          return gatedRoutes.contains(loc) ? '/dashboard' : null;
        case AuthStatus.unknown:
          return null;
      }
    },
  );
});
