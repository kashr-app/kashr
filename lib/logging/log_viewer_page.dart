import 'dart:convert';

import 'package:kashr/home/home_page.dart';
import 'package:kashr/logging/cubit/log_viewer_cubit.dart';
import 'package:kashr/logging/log_viewer_state.dart';
import 'package:kashr/logging/model/log_entry.dart';
import 'package:kashr/logging/model/log_level_setting.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class LogViewerRoute extends GoRouteData with $LogViewerRoute {
  const LogViewerRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return BlocProvider(
      create: (_) => LogViewerCubit(
        context.read<LogService>(),
        context.read<LogService>().log,
      ),
      child: LogViewerPage(context.read<LogService>().log),
    );
  }
}

class LogViewerPage extends StatelessWidget {
  const LogViewerPage(this._log, {super.key});
  final Logger _log;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _log.e('Test'),
            tooltip: 'Create a test error',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _confirmClearLogs(context),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<LogViewerCubit, LogViewerState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
        
            if (state.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    SizedBox(height: 16),
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.read<LogViewerCubit>().loadLogs(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
        
            if (state.logs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green,
                    ),
                    SizedBox(height: 16),
                    Text('No logs to display'),
                  ],
                ),
              );
            }
        
            return RefreshIndicator(
              onRefresh: () => context.read<LogViewerCubit>().loadLogs(),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: state.logs.length,
                itemBuilder: (context, index) {
                  final log = state.logs[index];
                  return _LogEntryCard(
                    entry: log,
                    onTap: () => _showLogDetails(context, log),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmClearLogs(BuildContext context) {
    final cubit = context.read<LogViewerCubit>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              cubit.clearLogs();
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(BuildContext context, LogEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LogDetailsSheet(entry: entry),
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  final LogEntry entry;
  final VoidCallback onTap;

  const _LogEntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, HH:mm:ss');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          entry.level.icon,
          color: entry.level.color(Theme.of(context)),
          size: 24,
        ),
        title: Text(
          entry.message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${dateFormat.format(entry.timestamp.toLocal())}${entry.loggerName != null ? ' • ${entry.loggerName}' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: entry.level.threshold >= LogLevelSetting.error.threshold
            ? const Icon(Icons.bug_report, size: 16)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _LogDetailsSheet extends StatelessWidget {
  final LogEntry entry;

  const _LogDetailsSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Log Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: const JsonEncoder.withIndent(
                                '  ',
                              ).convert(entry.toJson()),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow('Level', entry.level.displayName),
              _buildDetailRow('Time', entry.timestamp.toLocal().toString()),
              if (entry.loggerName != null)
                _buildDetailRow('Logger', entry.loggerName!),
              _buildDetailRow('Message', entry.message),
              if (entry.error != null) ...[
                const SizedBox(height: 16),
                Text('Error:', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SelectableText(
                  entry.error!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
              if (entry.stackTrace != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Stack Trace:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  entry.stackTrace!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ],
              if (entry.context != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Context:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  entry.context.toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
