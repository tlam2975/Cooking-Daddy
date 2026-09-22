import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_log_service.dart';
import '../theme/app_theme.dart';

enum _LogFilter { all, errors }

class AppLogsScreen extends StatefulWidget {
  const AppLogsScreen({super.key});

  @override
  State<AppLogsScreen> createState() => _AppLogsScreenState();
}

class _AppLogsScreenState extends State<AppLogsScreen> {
  _LogFilter _filter = _LogFilter.all;

  List<AppLogEntry> get _visibleEntries {
    final entries = AppLogService.instance.entries;
    if (_filter == _LogFilter.errors) {
      return entries
          .where((entry) => entry.level == AppLogLevel.error)
          .toList();
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('app_logs'.tr()),
        actions: [
          IconButton(
            tooltip: 'copy_logs'.tr(),
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'clear_logs'.tr(),
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: AppLogService.instance,
          builder: (context, _) {
            final entries = _visibleEntries;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_LogFilter>(
                      segments: [
                        ButtonSegment(
                          value: _LogFilter.all,
                          label: Text('all_logs'.tr()),
                        ),
                        ButtonSegment(
                          value: _LogFilter.errors,
                          label: Text('errors_only'.tr()),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (selection) {
                        setState(() => _filter = selection.first);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            'no_logs'.tr(),
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _LogEntryView(entry: entries[index]);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _copyLogs() async {
    final text = _visibleEntries.map((entry) => entry.formatted).join('\n\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('logs_copied'.tr())));
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('clear_logs'.tr()),
        content: Text('clear_logs_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('clear'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) await AppLogService.instance.clear();
  }
}

class _LogEntryView extends StatelessWidget {
  final AppLogEntry entry;

  const _LogEntryView({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isError = entry.level == AppLogLevel.error;
    final color = isError ? Colors.red.shade700 : AppColors.textSecondary;
    final timestamp = DateFormat(
      'yyyy-MM-dd HH:mm:ss.SSS',
      context.locale.toString(),
    ).format(entry.timestamp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade200 : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.level.name.toUpperCase()}  $timestamp',
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            entry.message,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          if (entry.stackTrace != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              entry.stackTrace!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
