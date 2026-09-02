import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/clay.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/report_repository.dart';

/// Screen 18 — PDF / Export
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _type = 'summary';
  String _format = 'pdf';
  ReportPeriod _period = ReportPeriod.thisMonth;

  bool _generating = false;
  double _progress = 0;
  File? _file;
  DateTime? _generatedAt;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _progress = 0;
      _file = null;
    });

    try {
      final file = await ref.read(reportRepositoryProvider).downloadReport(
            period: _period,
            format: _format,
            type: _type,
            onProgress: (received, total) {
              // Content-Length is absent on streamed responses, so guard it.
              if (total > 0 && mounted) {
                setState(() => _progress = received / total);
              }
            },
          );

      if (!mounted) return;
      setState(() {
        _file = file;
        _generatedAt = DateTime.now();
      });
      showAppSnack(context, 'Report ready');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _share() async {
    if (_file == null) return;
    await Share.shareXFiles(
      [XFile(_file!.path)],
      subject: 'HISAB Report',
      text: 'My HISAB report for ${_period.label.toLowerCase()}',
    );
  }

  Future<void> _open() async {
    if (_file == null) return;
    final result = await OpenFilex.open(_file!.path);
    if (result.type != ResultType.done && mounted) {
      showAppSnack(context, 'No app available to open this file',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/reports'),
        ),
        title: const Text('Export Report'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
          children: [
            AppDropdown<String>(
              label: 'Select Type',
              value: _type,
              items: const ['summary', 'detailed'],
              itemLabel: (t) =>
                  t == 'summary' ? 'Summary Report' : 'Detailed Report',
              itemLeading: (t) => Icon(
                t == 'summary'
                    ? Icons.donut_small_outlined
                    : Icons.list_alt_outlined,
                size: 18,
                color: AppColors.forest,
              ),
              onChanged: (v) => setState(() {
                _type = v ?? 'summary';
                _file = null;
              }),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppDropdown<String>(
              label: 'Select Format',
              value: _format,
              items: const ['pdf', 'csv'],
              itemLabel: (f) => f.toUpperCase(),
              itemLeading: (f) => Icon(
                f == 'pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.table_chart_outlined,
                size: 18,
                color: f == 'pdf' ? AppColors.expense : AppColors.income,
              ),
              onChanged: (v) => setState(() {
                _format = v ?? 'pdf';
                _file = null;
              }),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppDropdown<ReportPeriod>(
              label: 'Date Range',
              value: _period,
              items: ReportPeriod.values,
              itemLabel: (p) => p.label,
              itemLeading: (_) => const Icon(Icons.calendar_month_outlined,
                  size: 18, color: AppColors.forest),
              onChanged: (v) => setState(() {
                _period = v ?? ReportPeriod.thisMonth;
                _file = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _type == 'summary'
                  ? 'Totals and a category breakdown.'
                  : 'Everything in the summary, plus every transaction in the period.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'Generate ${_format.toUpperCase()}',
              loading: _generating,
              onPressed: _generate,
            ),
            if (_generating && _progress > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 5,
                  backgroundColor: context.cBorder,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
            ],
            if (_file != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              _FileCard(
                file: _file!,
                generatedAt: _generatedAt!,
                format: _format,
                onOpen: _open,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Share Report',
                icon: Icons.ios_share_rounded,
                onPressed: _share,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.generatedAt,
    required this.format,
    required this.onOpen,
  });

  final File file;
  final DateTime generatedAt;
  final String format;
  final VoidCallback onOpen;

  String get _fileName => file.path.split('/').last;

  String get _fileSize {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = format == 'pdf';

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: Clay.shadows(AppColors.accent, small: true),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: (isPdf ? AppColors.expense : AppColors.income)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.table_chart_rounded,
                color: isPdf ? AppColors.expense : AppColors.income,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    'Generated on ${Fmt.date(generatedAt)}  ·  $_fileSize',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                size: 18, color: context.cTextTertiary),
          ],
        ),
      ),
    );
  }
}
