import 'package:flutter/material.dart';

import '../../utils/logger.dart';
import '../theme/app_theme.dart';

/// Виджет просмотра логов — Hiddify-стиль
class LogViewer extends StatefulWidget {
  final List<LogEntry> logs;
  final VoidCallback onClear;

  const LogViewer({
    super.key,
    required this.logs,
    required this.onClear,
  });

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Логи'),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.cardBorderColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _autoScroll
                          ? Icons.vertical_align_bottom
                          : Icons.vertical_align_center,
                      size: 20,
                      color: _autoScroll
                          ? AppTheme.primaryColor
                          : AppTheme.textMuted,
                    ),
                    onPressed: () {
                      setState(() => _autoScroll = !_autoScroll);
                    },
                    tooltip: 'Автоскролл',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.cardBorderColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: widget.onClear,
                    tooltip: 'Очистить',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.all(4),
            child: widget.logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.terminal,
                          size: 48,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Логов нет',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.logs.length,
                    itemBuilder: (context, index) {
                      final entry = widget.logs[index];
                      return _LogEntryWidget(entry: entry);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _LogEntryWidget extends StatelessWidget {
  final LogEntry entry;

  const _LogEntryWidget({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 14,
            margin: const EdgeInsets.only(top: 3, right: 8),
            decoration: BoxDecoration(
              color: _getColor(),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              entry.formatted,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: _getColor().withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (entry.level) {
      case LogLevel.debug:
        return AppTheme.textMuted;
      case LogLevel.info:
        return AppTheme.primaryColor;
      case LogLevel.warn:
        return AppTheme.warningColor;
      case LogLevel.error:
        return AppTheme.errorColor;
    }
  }
}