import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_map.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/savings_model.dart';
import '../data/savings_repository.dart';

/// Screen 16 — Savings
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Savings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(savingsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(savingsProvider),
        ),
        data: (payload) => RefreshIndicator(
          color: AppColors.forest,
          onRefresh: () async {
            ref.invalidate(savingsProvider);
            await ref.read(savingsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
            children: [
              _SavingsHeader(payload: payload),
              const SizedBox(height: AppSpacing.xl),

              if (payload.goals.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyState(
                    icon: Icons.savings_outlined,
                    title: 'No goals yet',
                    message:
                        'Set a target and watch it fill up as you put money aside.',
                    actionLabel: 'Add New Goal',
                    onAction: () => _showGoalSheet(context),
                  ),
                )
              else
                ...payload.goals.map((goal) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _GoalCard(
                        goal: goal,
                        currency: payload.currency,
                        onContribute: () =>
                            _showContributeSheet(context, goal, payload.currency, false),
                        onWithdraw: () =>
                            _showContributeSheet(context, goal, payload.currency, true),
                        onDelete: () => _confirmDelete(context, ref, goal),
                      ),
                    )),

              if (payload.goals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Add New Goal',
                  icon: Icons.add,
                  onPressed: () => _showGoalSheet(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _GoalFormSheet(),
    );
  }

  void _showContributeSheet(
      BuildContext context, SavingsGoal goal, String currency, bool isWithdrawal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ContributeSheet(
        goal: goal,
        currency: currency,
        isWithdrawal: isWithdrawal,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text('This removes ${goal.name} and its contribution history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(savingsRepositoryProvider).remove(goal.id);
                ref.invalidate(savingsProvider);
                if (context.mounted) showAppSnack(context, 'Goal deleted');
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

class _SavingsHeader extends StatelessWidget {
  const _SavingsHeader({required this.payload});
  final SavingsPayload payload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Savings',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.currency(payload.totalSaved, code: payload.currency),
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Goal: ${Fmt.currency(payload.totalTarget, code: payload.currency)}',
            style: TextStyle(
                color: Colors.white.withOpacity(0.65), fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: payload.progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('${payload.progressPercent}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.currency,
    required this.onContribute,
    required this.onWithdraw,
    required this.onDelete,
  });

  final SavingsGoal goal;
  final String currency;
  final VoidCallback onContribute;
  final VoidCallback onWithdraw;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(goal.color, fallback: AppColors.accent);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
            color: goal.isCompleted ? AppColors.accent : context.cBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconFromSlug(goal.icon), size: 19, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(goal.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(fontSize: 14)),
                        ),
                        if (goal.isCompleted) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle,
                              size: 14, color: AppColors.income),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Goal: ${Fmt.currency(goal.targetAmount, code: '', decimals: false).trim()}'
                      '${goal.deadline != null ? '  ·  by ${Fmt.date(goal.deadline!, pattern: 'MMM yyyy')}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.currency(goal.savedAmount, code: '', decimals: false).trim(),
                    style: Theme.of(context).textTheme.titleMedium!
                        .copyWith(fontSize: 14),
                  ),
                  Text('${goal.progressPercent}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 6,
              backgroundColor: context.cBorder,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              goal.isCompleted
                  ? 'Target reached'
                  : '${Fmt.plain(goal.remaining)} to go',
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: goal.isCompleted
                      ? AppColors.income
                      : context.cTextSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: context.cDivider),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onContribute,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Money',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: goal.savedAmount > 0 ? onWithdraw : null,
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Withdraw',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                      foregroundColor: context.cTextSecondary),
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

class _GoalFormSheet extends ConsumerStatefulWidget {
  const _GoalFormSheet();

  @override
  ConsumerState<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _starting = TextEditingController(text: '0');
  DateTime? _deadline;
  String _icon = 'target';
  bool _saving = false;

  static const _icons = [
    ('target', 'Goal'),
    ('favorite', 'Health'),
    ('directions_car', 'Vehicle'),
    ('school', 'Education'),
    ('shopping_bag', 'Purchase'),
    ('card_giftcard', 'Gift'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _starting.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(savingsRepositoryProvider).create(
            name: _name.text.trim(),
            targetAmount: double.parse(_target.text.replaceAll(',', '')),
            savedAmount:
                double.tryParse(_starting.text.replaceAll(',', '')) ?? 0,
            deadline: _deadline,
            icon: _icon,
          );
      ref.invalidate(savingsProvider);
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'Goal created');
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
            Text('New Savings Goal',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Goal Name',
              controller: _name,
              hint: 'Emergency Fund',
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Goal name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Target Amount',
              controller: _target,
              hint: '60,000',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: Validators.amount,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Already Saved (Optional)',
              controller: _starting,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final value = double.tryParse(v.replaceAll(',', ''));
                if (value == null) return 'Enter a valid amount';
                if (value < 0) return 'Cannot be negative';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Icon',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: context.cTextSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: _icons.map((entry) {
                final selected = _icon == entry.$1;
                return GestureDetector(
                  onTap: () => setState(() => _icon = entry.$1),
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withOpacity(0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected ? AppColors.accent : context.cBorder),
                    ),
                    child: Icon(iconFromSlug(entry.$1),
                        size: 19,
                        color: selected
                            ? AppColors.forest
                            : context.cTextSecondary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(label: 'Create Goal', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _ContributeSheet extends ConsumerStatefulWidget {
  const _ContributeSheet({
    required this.goal,
    required this.currency,
    required this.isWithdrawal,
  });

  final SavingsGoal goal;
  final String currency;
  final bool isWithdrawal;

  @override
  ConsumerState<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends ConsumerState<_ContributeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(savingsRepositoryProvider);
    final value = double.parse(_amount.text.replaceAll(',', ''));

    try {
      if (widget.isWithdrawal) {
        await repo.withdraw(widget.goal.id, value);
      } else {
        await repo.contribute(widget.goal.id, value);
      }
      ref.invalidate(savingsProvider);
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context,
            widget.isWithdrawal ? 'Withdrawal recorded' : 'Contribution added');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;

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
            Text(widget.isWithdrawal ? 'Withdraw from Goal' : 'Add to Goal',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${goal.name} · '
              '${Fmt.currency(goal.savedAmount, code: widget.currency)} saved',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Amount',
              controller: _amount,
              hint: '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final base = Validators.amount(v);
                if (base != null) return base;
                final value = double.parse(v!.replaceAll(',', ''));
                if (widget.isWithdrawal && value > goal.savedAmount) {
                  return 'Only ${Fmt.plain(goal.savedAmount)} is saved';
                }
                return null;
              },
            ),
            if (!widget.isWithdrawal && goal.remaining > 0) ...[
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () => _amount.text = goal.remaining.toStringAsFixed(2),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.incomeSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: Text('Complete goal (${Fmt.plain(goal.remaining)})',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest)),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: widget.isWithdrawal ? 'Withdraw' : 'Add Money',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
