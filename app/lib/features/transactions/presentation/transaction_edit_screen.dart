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
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../accounts/data/account_model.dart';
import '../../accounts/state/accounts_provider.dart';
import '../../categories/data/category_model.dart';
import '../../categories/data/category_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/transaction_model.dart';
import '../data/transaction_repository.dart';
import '../state/history_controller.dart';
import 'transaction_detail_screen.dart';

/// Edit view reached from Transaction Detail. Sends only changed fields so a
/// partial update can't blank out values the user never touched.
class TransactionEditScreen extends ConsumerWidget {
  const TransactionEditScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Edit Transaction'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(transactionDetailProvider(id)),
        ),
        data: (item) => _EditForm(item: item),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.item});
  final TransactionItem item;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount =
      TextEditingController(text: widget.item.amount.toStringAsFixed(2));
  late final _note = TextEditingController(text: widget.item.note);

  late DateTime _date = widget.item.date;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.item.category?.id;
    _accountId = widget.item.account?.id;
    _toAccountId = widget.item.toAccount?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Color get _accent => widget.item.isTransfer
      ? AppColors.info
      : widget.item.isIncome
          ? AppColors.income
          : AppColors.expense;

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

  /// Only fields the user actually changed get sent.
  Map<String, dynamic> _changes() {
    final changes = <String, dynamic>{};
    final amount = double.parse(_amount.text.replaceAll(',', ''));

    if (amount != widget.item.amount) changes['amount'] = amount;
    if (_note.text.trim() != widget.item.note)
      changes['note'] = _note.text.trim();
    if (_date != widget.item.date) changes['date'] = _date.toIso8601String();
    if (_accountId != widget.item.account?.id) changes['account'] = _accountId;
    if (_categoryId != widget.item.category?.id)
      changes['category'] = _categoryId;
    if (_toAccountId != widget.item.toAccount?.id) {
      changes['toAccount'] = _toAccountId;
    }
    return changes;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final changes = _changes();
    if (changes.isEmpty) {
      showAppSnack(context, 'Nothing changed');
      context.pop();
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .update(widget.item.id, changes);

      ref.invalidate(transactionDetailProvider(widget.item.id));
      ref.invalidate(dashboardOverviewProvider);
      ref.invalidate(accountsProvider);
      ref.read(historyControllerProvider.notifier).refresh();

      if (!mounted) return;
      showAppSnack(context, 'Transaction updated');
      context.pop();
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
    final isTransfer = widget.item.isTransfer;

    return Form(
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
          if (!isTransfer)
            ref.watch(categoriesProvider(widget.item.type)).when(
                  loading: () => const SizedBox(
                      height: 70,
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Text('Could not load categories: $e',
                      style: const TextStyle(color: AppColors.expense)),
                  data: (categories) => AppDropdown<Category>(
                    label: 'Category',
                    value: categories
                        .where((c) => c.id == _categoryId)
                        .firstOrNull,
                    items: categories,
                    itemLabel: (c) => c.name,
                    itemLeading: (c) => Icon(iconFromSlug(c.icon),
                        size: 18, color: colorFromHex(c.color)),
                    onChanged: (c) => setState(() => _categoryId = c?.id),
                  ),
                ),
          if (!isTransfer) const SizedBox(height: AppSpacing.xl),
          AppDropdown<Account>(
            label: isTransfer ? 'From Account' : 'Account',
            value: accounts.where((a) => a.id == _accountId).firstOrNull,
            items: accounts,
            itemLabel: (a) => a.name,
            itemLeading: (a) => Icon(iconForAccountType(a.type),
                size: 18, color: AppColors.forest),
            onChanged: (a) => setState(() => _accountId = a?.id),
          ),
          if (isTransfer) ...[
            const SizedBox(height: AppSpacing.xl),
            AppDropdown<Account>(
              label: 'To Account',
              value: accounts.where((a) => a.id == _toAccountId).firstOrNull,
              items: accounts.where((a) => a.id != _accountId).toList(),
              itemLabel: (a) => a.name,
              itemLeading: (a) => Icon(iconForAccountType(a.type),
                  size: 18, color: AppColors.forest),
              onChanged: (a) => setState(() => _toAccountId = a?.id),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: context.cTextSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _pickDate,
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
                      Expanded(child: Text(Fmt.date(_date))),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: context.cTextSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Note (Optional)',
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          PrimaryButton(
            label: 'Save Changes',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
