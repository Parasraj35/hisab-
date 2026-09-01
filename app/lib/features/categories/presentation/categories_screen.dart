import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/icon_map.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/category_model.dart';
import '../data/category_repository.dart';

/// Screen 24 — Category Management
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _type = 'expense';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(categoriesProvider(_type));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: const Text('Categories'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.cBorder),
              ),
              child: Row(
                children: ['expense', 'income'].map((type) {
                  final selected = _type == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.forest : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type == 'expense' ? 'Expense' : 'Income',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : context.cTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(categoriesProvider(_type)),
              ),
              data: (categories) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final color = colorFromHex(category.color);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: context.cBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(iconFromSlug(category.icon),
                              size: 18, color: color),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(category.name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                        if (category.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.cSurfaceAlt,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Default',
                                style: Theme.of(context).textTheme.labelSmall),
                          )
                        else
                          IconButton(
                            onPressed: () => _confirmDelete(category),
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 18, color: context.cTextTertiary),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: PrimaryButton(
              label: 'Add Category',
              icon: Icons.add,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).cardTheme.color,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _CategoryFormSheet(type: _type),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Category category) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
            'If ${category.name} is used by any transaction it will be archived '
            'instead, so your reports stay accurate.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final archived =
                    await ref.read(categoryRepositoryProvider).remove(category.id);
                ref.invalidate(categoriesProvider(_type));
                if (mounted) {
                  showAppSnack(context,
                      archived ? '${category.name} archived' : 'Category deleted');
                }
              } catch (e) {
                if (mounted) showAppSnack(context, e.toString(), isError: true);
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  const _CategoryFormSheet({required this.type});
  final String type;

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _icon = 'category';
  Color _color = AppColors.categoryPalette.first;
  bool _saving = false;

  static const _iconOptions = [
    'restaurant', 'directions_car', 'bolt', 'shopping_bag', 'favorite',
    'school', 'movie', 'laptop', 'storefront', 'card_giftcard', 'category',
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _colorHex =>
      '#${_color.value.toRadixString(16).substring(2).toUpperCase()}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(categoryRepositoryProvider).create(
            name: _name.text.trim(),
            type: widget.type,
            icon: _icon,
            color: _colorHex,
          );
      ref.invalidate(categoriesProvider(widget.type));
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'Category added');
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
            Text('New ${widget.type == 'expense' ? 'Expense' : 'Income'} Category',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Name',
              controller: _name,
              hint: 'e.g. Groceries',
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Category name'),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('Icon', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _iconOptions.map((slug) {
                final selected = _icon == slug;
                return GestureDetector(
                  onTap: () => setState(() => _icon = slug),
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? _color.withOpacity(0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected ? _color : context.cBorder),
                    ),
                    child: Icon(iconFromSlug(slug),
                        size: 18,
                        color: selected ? _color : context.cTextSecondary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('Colour', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: AppColors.categoryPalette.map((color) {
                final selected = _color == color;
                return GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: context.cTextPrimary, width: 2)
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),

            PrimaryButton(
                label: 'Add Category', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
