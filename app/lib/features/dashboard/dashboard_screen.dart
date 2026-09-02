import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_map.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/summary_chip.dart';
import '../../shared/widgets/transaction_tile.dart';
import '../accounts/data/account_model.dart';
import '../auth/state/auth_controller.dart';
import '../notifications/data/notification_repository.dart';
import 'data/dashboard_repository.dart';

/// Short, honest read on how the month is going — shown under the balance.
/// Zero-activity gets its own line rather than claiming "you're even" when
/// nothing has actually happened yet.
String _monthInsight(double income, double expense, String currency) {
  if (income == 0 && expense == 0) return 'No activity yet this month';
  final net = income - expense;
  if (net > 0) return "You're ${Fmt.currency(net, code: currency)} ahead this month";
  if (net < 0) {
    return "You've spent ${Fmt.currency(net.abs(), code: currency)} more than you earned";
  }
  return "You've broken even this month";
}

/// Screen 7 — Dashboard
///
/// Design pass 2: the previous version boxed every section in an identically
/// bordered, identically radiused card — the generic "SaaS-card kit" look.
/// This version has one hero (the balance, which counts up on load) and lets
/// everything else sit quietly as flat list rows separated by whitespace and
/// hairlines, the way a feed or a bank app actually reads.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _balanceHidden = false;

  Future<void> _refresh() async {
    ref.invalidate(dashboardOverviewProvider);
    await ref.read(dashboardOverviewProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(dashboardOverviewProvider);
    final unread = ref
            .watch(notificationsProvider)
            .valueOrNull
            ?.where((n) => !n.isRead)
            .length ??
        0;

    // "HISAB" only needs saying once — on a screen someone opens every day,
    // their own name does more work than the brand name repeated back to them.
    final fullName = ref.watch(authControllerProvider).user?.fullName ?? '';
    final firstName =
        fullName.trim().isEmpty ? null : fullName.trim().split(RegExp(r'\s+')).first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: context.cSurface,
      appBar: AppBar(
        backgroundColor: context.cHeader,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => context.push('/settings'),
        ),
        title: Text(firstName != null ? '$greeting, $firstName' : greeting),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
              if (unread > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    height: 9,
                    width: 9,
                    decoration: BoxDecoration(
                      color: context.cWarning,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.cHeader, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: _Pressable(
        onTap: () => _showQuickAdd(context),
        child: Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: context.cAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.cAccent.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 28, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(message: err.toString(), onRetry: _refresh),
        data: (data) => RefreshIndicator(
          onRefresh: _refresh,
          color: context.cPrimary,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _BalanceHeader(
                total: data.totalBalance,
                currency: data.currency,
                hidden: _balanceHidden,
                insight: _monthInsight(
                    data.thisMonth.income, data.thisMonth.expense, data.currency),
                onToggleHidden: () =>
                    setState(() => _balanceHidden = !_balanceHidden),
              ),

              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: 'Accounts',
                        action: 'See all',
                        onAction: () => context.go('/accounts'),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      if (data.accounts.isEmpty)
                        _EmptyLine(
                          icon: Icons.account_balance_wallet_outlined,
                          message:
                              'Add an account to start tracking your money.',
                          actionLabel: 'Add account',
                          onAction: () => context.go('/accounts'),
                        )
                      else
                        ...data.accounts.take(3).toList().asMap().entries.map(
                              (entry) => _AccountRow(
                                account: entry.value,
                                showDivider: entry.key <
                                    data.accounts.take(3).length - 1,
                                onTap: () =>
                                    context.push('/accounts/${entry.value.id}'),
                              ),
                            ),

                      const SizedBox(height: AppSpacing.xxl),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SummaryChip(
                                label: 'Income this month',
                                amount: data.thisMonth.income,
                                currency: data.currency,
                                isIncome: true,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: SummaryChip(
                                label: 'Expense this month',
                                amount: data.thisMonth.expense,
                                currency: data.currency,
                                isIncome: false,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _QuickAction(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Expense',
                            color: context.cExpense,
                            soft: context.isDark
                                ? context.cExpense.withOpacity(0.16)
                                : AppColors.expenseSoft,
                            onTap: () => context.push('/add-expense'),
                          ),
                          _QuickAction(
                            icon: Icons.arrow_downward_rounded,
                            label: 'Income',
                            color: context.cIncome,
                            soft: context.isDark
                                ? context.cIncome.withOpacity(0.16)
                                : AppColors.incomeSoft,
                            onTap: () => context.push('/add-income'),
                          ),
                          _QuickAction(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Transfer',
                            color: AppColors.quickNeutral,
                            soft: context.quickTint(
                                AppColors.quickNeutral, AppColors.quickNeutralSoft),
                            onTap: () => context.push('/transfer'),
                          ),
                          _QuickAction(
                            icon: Icons.more_horiz_rounded,
                            label: 'More',
                            color: AppColors.quickNeutral,
                            soft: context.quickTint(
                                AppColors.quickNeutral, AppColors.quickNeutralSoft),
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xxl),
                      _SectionTitle(
                        title: 'Recent Activity',
                        action: 'View all',
                        onAction: () => context.push('/history'),
                      ),

                      if (data.recentTransactions.isEmpty)
                        _EmptyLine(
                          icon: Icons.receipt_long_outlined,
                          message:
                              'Your transactions will show up here once you add one.',
                          actionLabel: 'Add expense',
                          onAction: () => context.push('/add-expense'),
                        )
                      else
                        ...data.recentTransactions.asMap().entries.map(
                              (entry) => TransactionTile(
                                item: entry.value,
                                currency: data.currency,
                                showDivider: entry.key <
                                    data.recentTransactions.length - 1,
                                onTap: () => context
                                    .push('/transactions/${entry.value.id}'),
                              ),
                            ),

                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 4,
              width: 38,
              decoration: BoxDecoration(
                color: context.cBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: context.isDark
                    ? context.cExpense.withOpacity(0.14)
                    : AppColors.expenseSoft,
                child: Icon(Icons.arrow_upward_rounded,
                    color: context.cExpense, size: 20),
              ),
              title: const Text('Add Expense'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/add-expense');
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: context.isDark
                    ? context.cIncome.withOpacity(0.14)
                    : AppColors.incomeSoft,
                child: Icon(Icons.arrow_downward_rounded,
                    color: context.cIncome, size: 20),
              ),
              title: const Text('Add Income'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/add-income');
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.info.withOpacity(0.12),
                child: const Icon(Icons.swap_horiz_rounded,
                    color: AppColors.info, size: 20),
              ),
              title: const Text('Transfer'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/transfer');
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: context.cWarning.withOpacity(0.12),
                child: Icon(Icons.handshake_outlined,
                    color: context.cWarning, size: 20),
              ),
              title: const Text('Debt / Lending'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/debts');
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: context.cAccent.withOpacity(0.18),
                child: Icon(Icons.savings_outlined,
                    color: context.cPrimary, size: 20),
              ),
              title: const Text('Savings Goals'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/savings');
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// Wraps a tap target with a small press-down scale. This is the only motion
/// on the screen besides the balance count-up — deliberately, rather than
/// animating every card on entrance.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.cTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.cTextSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// An empty section is an invitation, not a dead end — so it gets an icon
/// and a real next step, not just "No data" in grey.
class _EmptyLine extends StatelessWidget {
  const _EmptyLine({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration:
                BoxDecoration(color: context.cLightGreen, shape: BoxShape.circle),
            child: Icon(
              icon,
              size: 17,
              color: context.isDark ? AppColors.darkHeader : AppColors.forest,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    message,
                    style: TextStyle(
                        fontSize: 13, color: context.cTextSecondary, height: 1.35),
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.cPrimary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat list row — no card, no border, no shadow. Separation comes from a
/// single hairline divider and generous vertical padding, the way Instagram's
/// own lists are built. This replaces the previous per-account bordered card.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.onTap,
    required this.showDivider,
  });

  final Account account;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: context.cLightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconForAccountType(account.type),
                    size: 19,
                    color: context.isDark
                        ? AppColors.darkHeader
                        : AppColors.forest,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.cTextPrimary,
                          ),
                        ),
                      ),
                      if (account.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.cLightGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: context.isDark
                                  ? AppColors.darkHeader
                                  : AppColors.forest,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  Fmt.currency(account.currentBalance, code: account.currency),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.cTextPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 19, color: context.cTextTertiary),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: context.cDivider),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.soft,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
              child: Icon(icon, size: 23, color: color),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.cTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.total,
    required this.currency,
    required this.hidden,
    required this.insight,
    required this.onToggleHidden,
  });

  final double total;
  final String currency;
  final bool hidden;
  final String insight;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.cHeader,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 58),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Balance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // The one deliberate motion moment on this screen: the number
                // counts up from zero on load rather than the whole layout
                // fading and sliding in piece by piece.
                hidden
                    ? const Text(
                        '••••••',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      )
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: total),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Fmt.currency(value, code: currency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      ),
                // Hidden along with the balance — a status line under a
                // masked number would leak the amount it's describing.
                if (!hidden) ...[
                  const SizedBox(height: 7),
                  Text(
                    insight,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.68),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _Pressable(
            onTap: onToggleHidden,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
