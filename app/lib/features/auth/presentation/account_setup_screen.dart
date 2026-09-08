import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import '../state/auth_controller.dart';

class _Currency {
  const _Currency(this.code, this.label);
  final String code;
  final String label;
}

/// Screen 6 — Account Setup
class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  static const _currencies = [
    _Currency('PKR', 'PKR - Pakistani Rupee'),
    _Currency('USD', 'USD - US Dollar'),
    _Currency('GBP', 'GBP - British Pound'),
    _Currency('EUR', 'EUR - Euro'),
    _Currency('AED', 'AED - UAE Dirham'),
    _Currency('SAR', 'SAR - Saudi Riyal'),
  ];
  static const _quickAmounts = [10000.0, 25000.0, 50000.0];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Cash in Hand');
  final _balance = TextEditingController(text: '10000');
  _Currency _currency = _currencies.first;
  String _type = 'cash';
  bool _addingAnother = false;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  double get _parsedBalance =>
      double.tryParse(_balance.text.replaceAll(',', '').trim()) ?? 0;

  Future<void> _saveAndFinish() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await ref.read(authControllerProvider.notifier).saveFirstAccount(
          name: _name.text.trim(),
          currency: _currency.code,
          initialBalance: _parsedBalance,
          type: _type,
        );

    if (!mounted) return;
    if (!ok) {
      showAppSnack(context,
          ref.read(authControllerProvider).error ?? 'Could not create account',
          isError: true);
    }
  }

  /// Creates the account but keeps the user on this screen with a clean form.
  Future<void> _saveAndAddAnother() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _addingAnother = true);
    try {
      await ref.read(authRepositoryProvider).accountSetup(
            name: _name.text.trim(),
            currency: _currency.code,
            initialBalance: _parsedBalance,
            type: _type,
          );
      if (!mounted) return;
      showAppSnack(context, '${_name.text.trim()} added');
      _name.clear();
      _balance.text = '0';
      setState(() => _type = 'bank');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _addingAnother = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: context.cSurface,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        foregroundColor: context.cTextPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account Setup', style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text('Add your default cash account',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  label: 'Account Name',
                  controller: _name,
                  hint: 'Cash in Hand',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => Validators.required(v, 'Account name'),
                ),
                const SizedBox(height: AppSpacing.xl),
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
                  itemLeading: (t) => Icon(
                    {
                      'cash': Icons.payments_outlined,
                      'bank': Icons.account_balance_outlined,
                      'wallet': Icons.account_balance_wallet_outlined,
                      'card': Icons.credit_card,
                      'other': Icons.more_horiz,
                    }[t],
                    size: 18,
                    color: AppColors.forest,
                  ),
                  onChanged: (v) => setState(() => _type = v ?? 'cash'),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppDropdown<_Currency>(
                  label: 'Currency',
                  value: _currency,
                  items: _currencies,
                  itemLabel: (c) => c.label,
                  onChanged: (v) =>
                      setState(() => _currency = v ?? _currencies.first),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'Initial Balance',
                  controller: _balance,
                  hint: '0.00',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Enter an initial balance';
                    final parsed = double.tryParse(v.replaceAll(',', ''));
                    if (parsed == null) return 'Enter a valid amount';
                    if (parsed < 0) return 'Balance cannot be negative';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: _quickAmounts.map((amount) {
                    final selected = _parsedBalance == amount;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(
                            Fmt.currency(amount, code: '', decimals: false)
                                .trim()),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _balance.text = amount.toStringAsFixed(0);
                        }),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.forest
                              : context.cTextSecondary,
                        ),
                        backgroundColor: context.cSurfaceAlt,
                        selectedColor: AppColors.incomeSoft,
                        side: BorderSide(
                            color:
                                selected ? AppColors.accent : context.cBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  label: 'Save Account',
                  loading: auth.loading,
                  onPressed: _saveAndFinish,
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton.icon(
                    onPressed: _addingAnother ? null : _saveAndAddAnother,
                    icon: _addingAnother
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add, size: 18),
                    label: const Text('Add Another Account',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
