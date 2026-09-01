import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/debt_model.dart';
import '../data/debt_repository.dart';

/// Screen 15 — Debt / Lending
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String _direction = 'lent';

  bool get _isLent => _direction == 'lent';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(debtsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Debt / Lending'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(debtsProvider),
        ),
        data: (payload) {
          final visible =
              payload.debts.where((d) => d.direction == _direction).toList();
          final summary = payload.summary;

          return RefreshIndicator(
            color: AppColors.forest,
            onRefresh: () async {
              ref.invalidate(debtsProvider);
              await ref.read(debtsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
              children: [
                _DirectionToggle(
                  direction: _direction,
                  onChanged: (d) => setState(() => _direction = d),
                ),
                const SizedBox(height: AppSpacing.xl),

                Row(
                  children: [
                    Expanded(
                      child: _TotalCard(
                        label: _isLent ? 'Total Lent' : 'Total Borrowed',
                        amount: _isLent ? summary.lentTotal : summary.borrowedTotal,
                        currency: payload.currency,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TotalCard(
                        label: _isLent ? 'Total Received' : 'Total Repaid',
                        amount:
                            _isLent ? summary.lentReceived : summary.borrowedRepaid,
                        currency: payload.currency,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                    child: EmptyState(
                      icon: Icons.handshake_outlined,
                      title: _isLent ? 'Nothing lent out' : 'Nothing borrowed',
                      message: _isLent
                          ? "Track money you've lent so you remember who owes you."
                          : "Track money you've borrowed so nothing slips.",
                      actionLabel: 'Add New',
                      onAction: () => _showAddSheet(context),
                    ),
                  )
                else
                  ...visible.map((debt) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _DebtCard(
                          debt: debt,
                          currency: payload.currency,
                          onSettle: () => _showSettleSheet(context, debt, payload.currency),
                          onDelete: () => _confirmDelete(context, debt),
                        ),
                      )),

                if (visible.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Add New',
                    icon: Icons.add,
                    onPressed: () => _showAddSheet(context),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddDebtSheet(direction: _direction),
    );
  }

  void _showSettleSheet(BuildContext context, Debt debt, String currency) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettleSheet(debt: debt, currency: currency),
    );
  }

  void _confirmDelete(BuildContext context, Debt debt) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('This removes the ${debt.personName} record and its payment history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(debtRepositoryProvider).remove(debt.id);
                ref.invalidate(debtsProvider);
                if (context.mounted) showAppSnack(context, 'Record deleted');
              } catch (e) {
                if (context.mounted) {
                  showAppSnack(context, e.toString(), isError: true);
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}

class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({required this.direction, required this.onChanged});

  final String direction;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String value, String label) {
      final selected = direction == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.forest : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : context.cTextSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [tab('lent', 'I Lent'), tab('borrowed', 'I Borrowed')]),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.currency(amount, code: currency, decimals: false),
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.currency,
    required this.onSettle,
    required this.onDelete,
  });

  final Debt debt;
  final String currency;
  final VoidCallback onSettle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = debt.isPaid
        ? AppColors.income
        : debt.isOverdue
            ? AppColors.expense
            : AppColors.warning;
    final statusLabel = debt.isPaid
        ? 'Paid'
        : debt.isOverdue
            ? 'Overdue'
            : 'Pending';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.forest.withOpacity(0.10),
                child: Text(
                  Fmt.initials(debt.personName),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.personName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      debt.dueDate == null
                          ? 'No due date'
                          : 'Due: ${Fmt.date(debt.dueDate!)}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: debt.isOverdue
                              ? AppColors.expense
                              : context.cTextSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.currency(debt.amount, code: '', decimals: false).trim(),
                      style: Theme.of(context).textTheme.titleMedium!
                          .copyWith(fontSize: 14)),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ),
                ],
              ),
            ],
          ),

          // Partial payments get a progress bar so the remainder is obvious.
          if (debt.settledAmount > 0 && !debt.isPaid) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: debt.progress,
                minHeight: 5,
                backgroundColor: context.cBorder,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${Fmt.plain(debt.settledAmount)} received',
                    style: Theme.of(context).textTheme.labelSmall),
                Text('${Fmt.plain(debt.outstanding)} left',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: context.cDivider),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (!debt.isPaid)
                Expanded(
                  child: TextButton.icon(
                    onPressed: onSettle,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Record Payment',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (debt.isPaid)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Fully settled',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.income)),
                    ),
                  ),
                ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: context.cTextTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddDebtSheet extends ConsumerStatefulWidget {
  const _AddDebtSheet({required this.direction});
  final String direction;

  @override
  ConsumerState<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<_AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(debtRepositoryProvider).create(
            direction: widget.direction,
            personName: _name.text.trim(),
            amount: double.parse(_amount.text.replaceAll(',', '')),
            dueDate: _dueDate,
            note: _note.text.trim(),
          );
      ref.invalidate(debtsProvider);
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'Record saved');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLent = widget.direction == 'lent';

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
            Text(isLent ? 'Money I Lent' : 'Money I Borrowed',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: isLent ? 'Lent To' : 'Borrowed From',
              controller: _name,
              hint: 'Ahmad Raza',
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Amount',
              controller: _amount,
              hint: '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: Validators.amount,
            ),
            const SizedBox(height: AppSpacing.lg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Due Date (Optional)',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: context.cTextSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                  child: Container(
                    height: AppSpacing.fieldHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                      border: Border.all(color: context.cBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 17, color: context.cTextSecondary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _dueDate == null ? 'No due date' : Fmt.date(_dueDate!),
                            style: TextStyle(
                                color: _dueDate == null
                                    ? context.cTextTertiary
                                    : context.cTextPrimary),
                          ),
                        ),
                        if (_dueDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _dueDate = null),
                            child: Icon(Icons.close,
                                size: 17, color: context.cTextTertiary),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Note (Optional)',
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(label: 'Save Record', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _SettleSheet extends ConsumerStatefulWidget {
  const _SettleSheet({required this.debt, required this.currency});
  final Debt debt;
  final String currency;

  @override
  ConsumerState<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends ConsumerState<_SettleSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount =
      TextEditingController(text: widget.debt.outstanding.toStringAsFixed(2));
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(debtRepositoryProvider).settle(
            widget.debt.id,
            double.parse(_amount.text.replaceAll(',', '')),
          );
      ref.invalidate(debtsProvider);
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'Payment recorded');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.debt.outstanding;

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
            Text('Record Payment',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${widget.debt.personName} · '
              '${Fmt.currency(outstanding, code: widget.currency)} outstanding',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Amount Received',
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final base = Validators.amount(v);
                if (base != null) return base;
                final value = double.parse(v!.replaceAll(',', ''));
                if (value > outstanding) {
                  return 'Only ${Fmt.plain(outstanding)} is outstanding';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _QuickAmount(
                  label: 'Half',
                  onTap: () =>
                      _amount.text = (outstanding / 2).toStringAsFixed(2),
                ),
                const SizedBox(width: AppSpacing.sm),
                _QuickAmount(
                  label: 'Full',
                  onTap: () => _amount.text = outstanding.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
                label: 'Record Payment', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _QuickAmount extends StatelessWidget {
  const _QuickAmount({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.incomeSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.forest)),
      ),
    );
  }
}
