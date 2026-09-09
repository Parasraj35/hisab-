import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/account_tile.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/clay_fab.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/account_model.dart';
import '../data/account_repository.dart';
import '../state/accounts_provider.dart';

/// Screen 8 — Accounts
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(accountsProvider);
    ref.invalidate(dashboardOverviewProvider);
    await ref.read(accountsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      floatingActionButton:
          ClayFab(onTap: () => showAccountSheet(context, ref)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            ErrorView(message: err.toString(), onRetry: () => _refresh(ref)),
        data: (payload) {
          if (payload.accounts.isEmpty) {
            return EmptyState(
              title: 'No accounts yet',
              message:
                  'Add a cash, bank or wallet account to start tracking money.',
              actionLabel: 'Add Account',
              onAction: () => showAccountSheet(context, ref),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            color: context.cPrimary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 100),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Balance',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Fmt.currency(payload.totalBalance,
                              code: payload.currency),
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: context.cTextPrimary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                          'Across ${payload.accounts.length} account'
                          '${payload.accounts.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  child: Column(
                    children: payload.accounts.asMap().entries.map((entry) {
                      final account = entry.value;
                      return AccountTile(
                        account: account,
                        showDivider: entry.key < payload.accounts.length - 1,
                        onTap: () => _showAccountActions(context, ref, account),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Add Account',
                  icon: Icons.add,
                  onPressed: () => showAccountSheet(context, ref),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAccountActions(
      BuildContext context, WidgetRef ref, Account account) {
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
            const SizedBox(height: AppSpacing.lg),
            Text(account.name, style: Theme.of(context).textTheme.titleLarge),
            Text(Fmt.currency(account.currentBalance, code: account.currency),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: const Text('Edit account'),
              onTap: () {
                Navigator.pop(sheetContext);
                showAccountSheet(context, ref, existing: account);
              },
            ),
            if (!account.isDefault)
              ListTile(
                leading: const Icon(Icons.star_outline_rounded, size: 20),
                title: const Text('Set as default'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref
                      .read(accountRepositoryProvider)
                      .setDefault(account.id);
                  ref.invalidate(accountsProvider);
                  ref.invalidate(dashboardOverviewProvider);
                  if (context.mounted) {
                    showAppSnack(
                        context, '${account.name} is now your default');
                  }
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  size: 20, color: context.cExpense),
              title: Text('Delete account',
                  style: TextStyle(color: context.cExpense)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context, ref, account);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Account account) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
            'If ${account.name} has transactions it will be archived instead, '
            'so your history and reports stay accurate.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final archived = await ref
                    .read(accountRepositoryProvider)
                    .remove(account.id);
                ref.invalidate(accountsProvider);
                ref.invalidate(dashboardOverviewProvider);
                if (context.mounted) {
                  showAppSnack(
                      context,
                      archived
                          ? '${account.name} archived'
                          : '${account.name} deleted');
                }
              } catch (e) {
                if (context.mounted) {
                  showAppSnack(context, e.toString(), isError: true);
                }
              }
            },
            child:
                Text('Delete', style: TextStyle(color: dialogContext.cExpense)),
          ),
        ],
      ),
    );
  }
}

/// Add / edit account sheet — shared by the Accounts screen and the FAB.
void showAccountSheet(BuildContext context, WidgetRef ref,
    {Account? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AccountFormSheet(existing: existing),
  );
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  const _AccountFormSheet({this.existing});
  final Account? existing;

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _balance = TextEditingController(
      text: (widget.existing?.initialBalance ?? 0).toStringAsFixed(0));
  late String _type = widget.existing?.type ?? 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(accountRepositoryProvider);
    final balance = double.parse(_balance.text.replaceAll(',', ''));

    try {
      if (widget.existing == null) {
        await repo.create(
          name: _name.text.trim(),
          type: _type,
          currency: 'PKR',
          initialBalance: balance,
        );
      } else {
        await repo.update(widget.existing!.id, {
          'name': _name.text.trim(),
          'type': _type,
          'initialBalance': balance,
        });
      }
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardOverviewProvider);
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context,
            widget.existing == null ? 'Account added' : 'Account updated');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add Account' : 'Edit Account',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Account Name',
              controller: _name,
              hint: 'e.g. JazzCash',
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Account name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppDropdown<String>(
              label: 'Account Type',
              value: _type,
              items: const ['cash', 'bank', 'wallet', 'card', 'other'],
              itemLabel: (t) => {
                'cash': 'Cash',
                'bank': 'Bank Account',
                'wallet': 'Mobile Wallet',
                'card': 'Card',
                'other': 'Other',
              }[t]!,
              onChanged: (v) => setState(() => _type = v ?? 'cash'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Opening Balance',
              controller: _balance,
              hint: '0.00',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter an opening balance';
                }
                if (double.tryParse(v.replaceAll(',', '')) == null) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: widget.existing == null ? 'Add Account' : 'Save Changes',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
