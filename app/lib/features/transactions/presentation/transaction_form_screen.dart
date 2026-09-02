import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/clay.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_map.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../accounts/data/account_model.dart';
import '../../accounts/state/accounts_provider.dart';
import '../../categories/data/category_model.dart';
import '../../categories/data/category_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/transaction_repository.dart';

/// Screens 10 and 11 share one form. Only the accent colour, copy and the
/// category type differ, so they stay pixel-identical by construction.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, required this.type});

  final String type; // 'expense' | 'income'

  bool get isExpense => type == 'expense';

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  Category? _category;
  Account? _account;
  DateTime _date = DateTime.now();
  bool _saving = false;

  Color get _accent => widget.isExpense ? AppColors.expense : AppColors.income;
  String get _title => widget.isExpense ? 'Add Expense' : 'Add Income';

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // Calendar-only — the keyboard entry mode has no format hint and
      // rejects anything not typed exactly as MM/DD/YYYY.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppColors.forest),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
            picked.year,
            picked.month,
            picked.day,
            DateTime.now().hour,
            DateTime.now().minute,
          ));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      showAppSnack(context, 'Pick a category first', isError: true);
      return;
    }
    if (_account == null) {
      showAppSnack(context, 'Pick an account first', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(transactionRepositoryProvider).create(
            type: widget.type,
            amount: double.parse(_amount.text.replaceAll(',', '')),
            accountId: _account!.id,
            categoryId: _category!.id,
            date: _date,
            note: _note.text.trim(),
          );

      // Balances and recent activity both shift — refresh them together.
      ref.invalidate(dashboardOverviewProvider);
      ref.invalidate(accountsProvider);

      if (!mounted) return;
      showAppSnack(
          context, widget.isExpense ? 'Expense saved' : 'Income saved');
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
    final categoriesAsync = ref.watch(categoriesProvider(widget.type));
    final currency = accountsAsync.valueOrNull?.currency ?? 'PKR';

    // Default to the user's default account once accounts land.
    final accounts = accountsAsync.valueOrNull?.accounts ?? const <Account>[];
    if (_account == null && accounts.isNotEmpty) {
      _account =
          accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () =>
                showAppSnack(context, 'Recurring options arrive in batch 6'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
            children: [
              AmountField(
                controller: _amount,
                currency: currency,
                accentColor: _accent,
                validator: Validators.amount,
              ),
              const SizedBox(height: AppSpacing.xl),
              categoriesAsync.when(
                loading: () => const _FieldSkeleton(label: 'Category'),
                error: (e, _) => _FieldError(
                  label: 'Category',
                  onRetry: () =>
                      ref.invalidate(categoriesProvider(widget.type)),
                ),
                data: (categories) => AppDropdown<Category>(
                  label: 'Category',
                  value: _category,
                  hint: 'Select a category',
                  items: categories,
                  itemLabel: (c) => c.name,
                  itemLeading: (c) => Icon(
                    iconFromSlug(c.icon),
                    size: 18,
                    color: colorFromHex(c.color),
                  ),
                  validator: (c) => c == null ? 'Category is required' : null,
                  onChanged: (c) => setState(() => _category = c),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              accountsAsync.when(
                loading: () => const _FieldSkeleton(label: 'Account'),
                error: (e, _) => _FieldError(
                  label: 'Account',
                  onRetry: () => ref.invalidate(accountsProvider),
                ),
                data: (payload) => AppDropdown<Account>(
                  label: 'Account',
                  value: _account,
                  hint: 'Select an account',
                  items: payload.accounts,
                  itemLabel: (a) =>
                      '${a.name}  ·  ${Fmt.currency(a.currentBalance, code: a.currency, decimals: false)}',
                  itemLeading: (a) => Icon(
                    iconForAccountType(a.type),
                    size: 18,
                    color: AppColors.forest,
                  ),
                  validator: (a) => a == null ? 'Account is required' : null,
                  onChanged: (a) => setState(() => _account = a),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _DateField(date: _date, onTap: _pickDate),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'Note (Optional)',
                controller: _note,
                hint: widget.isExpense ? 'Lunch with friend' : 'Monthly salary',
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              PrimaryButton(
                label: widget.isExpense ? 'Save Expense' : 'Save Income',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

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
              boxShadow: Clay.shadows(context.cBackground, small: true),
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

class _FieldSkeleton extends StatelessWidget {
  const _FieldSkeleton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: AppSpacing.fieldHeight,
          decoration: BoxDecoration(
            color: context.cSurfaceAlt,
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            border: Border.all(color: context.cBorder),
          ),
          child: const Center(
            child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.label, required this.onRetry});
  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: AppSpacing.fieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.expenseSoft,
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            border: Border.all(color: AppColors.expense),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text("Couldn't load",
                    style: TextStyle(fontSize: 13, color: AppColors.expense)),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}

/// Screen 10
class AddExpenseScreen extends StatelessWidget {
  const AddExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TransactionFormScreen(type: 'expense');
}

/// Screen 11
class AddIncomeScreen extends StatelessWidget {
  const AddIncomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TransactionFormScreen(type: 'income');
}
