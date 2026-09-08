import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/clay.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_map.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../accounts/data/account_model.dart';
import '../../accounts/state/accounts_provider.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/transaction_repository.dart';
import '../state/history_controller.dart';

/// Screen 12 — Transfer
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  Account? _from;
  Account? _to;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _parsedAmount =>
      double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;

  /// Warns before the API rejects it, and before the user taps save.
  String? get _balanceWarning {
    if (_from == null || _parsedAmount <= 0) return null;
    if (_parsedAmount > _from!.currentBalance) {
      return '${_from!.name} only has '
          '${Fmt.currency(_from!.currentBalance, code: _from!.currency)}. '
          'This transfer will take it negative.';
    }
    return null;
  }

  void _swap() {
    setState(() {
      final temp = _from;
      _from = _to;
      _to = temp;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_from == null || _to == null) {
      showAppSnack(context, 'Pick both accounts first', isError: true);
      return;
    }
    if (_from!.id == _to!.id) {
      showAppSnack(context, 'Choose two different accounts', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(transactionRepositoryProvider).create(
            type: 'transfer',
            amount: _parsedAmount,
            accountId: _from!.id,
            toAccountId: _to!.id,
            date: _date,
            note: _note.text.trim(),
          );

      ref.invalidate(dashboardOverviewProvider);
      ref.invalidate(accountsProvider);
      ref.read(historyControllerProvider.notifier).refresh();

      if (!mounted) return;
      showAppSnack(context, 'Transfer complete');
      context.pop(true);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.valueOrNull?.accounts ?? const <Account>[];
    final currency = accountsAsync.valueOrNull?.currency ?? 'PKR';

    if (_from == null && accounts.isNotEmpty) {
      _from =
          accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
    }
    if (_to == null && accounts.length > 1) {
      _to = accounts.firstWhere((a) => a.id != _from?.id,
          orElse: () => accounts.last);
    }

    final warning = _balanceWarning;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Transfer'),
      ),
      body: SafeArea(
        child: accounts.length < 2 && !accountsAsync.isLoading
            ? _NeedsTwoAccounts(onAdd: () => context.go('/accounts'))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                      AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
                  children: [
                    _AccountSlot(
                      label: 'From',
                      account: _from,
                      accounts: accounts,
                      onChanged: (a) => setState(() => _from = a),
                    ),
                    _SwapDivider(onSwap: _swap),
                    _AccountSlot(
                      label: 'To',
                      account: _to,
                      accounts: accounts,
                      excludeId: _from?.id,
                      onChanged: (a) => setState(() => _to = a),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AmountField(
                      controller: _amount,
                      currency: currency,
                      accentColor: AppColors.forest,
                      validator: Validators.amount,
                    ),
                    if (warning != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 17, color: AppColors.warning),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(warning,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.cTextPrimary)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _DateRow(date: _date, onTap: _pickDate),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      label: 'Note (Optional)',
                      controller: _note,
                      hint: 'Cash withdraw',
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    PrimaryButton(
                      label: 'Transfer Now',
                      loading: _saving,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AccountSlot extends StatelessWidget {
  const _AccountSlot({
    required this.label,
    required this.account,
    required this.accounts,
    required this.onChanged,
    this.excludeId,
  });

  final String label;
  final Account? account;
  final List<Account> accounts;
  final ValueChanged<Account> onChanged;
  final String? excludeId;

  @override
  Widget build(BuildContext context) {
    final options = accounts.where((a) => a.id != excludeId).toList();

    return InkWell(
      onTap: options.isEmpty
          ? null
          : () => showModalBottomSheet<void>(
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
                      Text('Select $label account',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      ...options.map((a) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.forest.withOpacity(0.10),
                              child: Icon(iconForAccountType(a.type),
                                  size: 19, color: AppColors.forest),
                            ),
                            title: Text(a.name),
                            subtitle: Text(Fmt.currency(a.currentBalance,
                                code: a.currency)),
                            trailing: a.id == account?.id
                                ? const Icon(Icons.check_circle,
                                    color: AppColors.accent, size: 20)
                                : null,
                            onTap: () {
                              onChanged(a);
                              Navigator.pop(sheetContext);
                            },
                          )),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: Clay.shadows(context, context.cBackground, small: true),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.forest.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                account == null
                    ? Icons.help_outline_rounded
                    : iconForAccountType(account!.type),
                size: 19,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(account?.name ?? 'Select account',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(fontSize: 14)),
                  if (account != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      Fmt.currency(account!.currentBalance,
                          code: account!.currency),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_right_rounded,
                color: context.cTextTertiary),
          ],
        ),
      ),
    );
  }
}

class _SwapDivider extends StatelessWidget {
  const _SwapDivider({required this.onSwap});
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(color: context.cBorder),
          Material(
            color: AppColors.forest,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSwap,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.swap_vert_rounded,
                    size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: context.cTextSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          child: Container(
            height: AppSpacing.fieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              boxShadow:
                  Clay.shadows(context, context.cBackground, small: true),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 17, color: context.cTextSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(Fmt.date(date))),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: context.cTextSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NeedsTwoAccounts extends StatelessWidget {
  const _NeedsTwoAccounts({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded,
                size: 48, color: context.cTextTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text('You need two accounts',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
                'Transfers move money between your own accounts, so add one more first.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
                label: 'Go to Accounts', onPressed: onAdd, expanded: false),
          ],
        ),
      ),
    );
  }
}
