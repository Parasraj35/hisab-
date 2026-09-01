import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/notification_repository.dart';

/// Screen 19 — Notifications
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static (IconData, Color) _visual(String type) => switch (type) {
        'expense' => (Icons.arrow_upward_rounded, AppColors.expense),
        'income' => (Icons.arrow_downward_rounded, AppColors.income),
        'debt_reminder' => (Icons.handshake_outlined, AppColors.warning),
        'backup' => (Icons.cloud_done_outlined, AppColors.info),
        'report' => (Icons.bar_chart_rounded, AppColors.forest),
        _ => (Icons.notifications_none_rounded, AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final repo = ref.read(notificationRepositoryProvider);

    Future<void> refresh() async {
      ref.invalidate(notificationsProvider);
      ref.invalidate(dashboardOverviewProvider);
      await ref.read(notificationsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Notifications'),
        actions: [
          if ((async.valueOrNull ?? []).any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                await repo.markAllRead();
                await refresh();
                if (context.mounted) showAppSnack(context, 'All marked as read');
              },
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(message: err.toString(), onRetry: refresh),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing here yet',
              message: 'Alerts about your money will show up on this screen.',
            );
          }

          return RefreshIndicator(
            color: AppColors.forest,
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.cDivider),
              itemBuilder: (context, index) {
                final item = items[index];
                final (icon, color) = _visual(item.type);

                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.expense,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.xl),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await repo.remove(item.id);
                    ref.invalidate(notificationsProvider);
                  },
                  child: Container(
                    color: item.isRead
                        ? Colors.transparent
                        : AppColors.accent.withOpacity(0.06),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                      leading: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 19, color: color),
                      ),
                      title: Text(item.title,
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(fontSize: 14)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(item.body,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Fmt.dayHeader(item.createdAt),
                              style: Theme.of(context).textTheme.labelSmall),
                          if (!item.isRead) ...[
                            const SizedBox(height: 5),
                            const CircleAvatar(
                                radius: 3.5, backgroundColor: AppColors.accent),
                          ],
                        ],
                      ),
                      onTap: item.isRead
                          ? null
                          : () async {
                              await repo.markRead(item.id);
                              ref.invalidate(notificationsProvider);
                              ref.invalidate(dashboardOverviewProvider);
                            },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
