import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/providers/displays_provider.dart';

/// Main screen showing display detection using Riverpod
/// 
/// This demonstrates our canonical Riverpod patterns:
/// - ConsumerWidget for watching providers
/// - AsyncValue.when() for handling all states
/// - No direct service instantiation
class DisplaysScreen extends ConsumerWidget {
  const DisplaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the displays provider - this triggers the initial load
    final displaysAsync = ref.watch(displaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Detection - Riverpod'),
        actions: [
          // Refresh button to manually reload
          IconButton(
            key: const Key('refresh_button'),
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(displaysProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: displaysAsync.when(
        loading: () => const Center(
          key: Key('displays_loading'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading displays...'),
            ],
          ),
        ),
        error: (error, stackTrace) => Center(
          key: const Key('displays_error'),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading displays',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('retry_button'),
                  onPressed: () {
                    ref.read(displaysProvider.notifier).refresh();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (displays) => displays.isEmpty
            ? const Center(
                key: Key('displays_empty'),
                child: Text('No displays detected'),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final display in displays)
                      Card(
                        key: Key('display_card_${display.id}'),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.monitor,
                                    color: display.isPrimary
                                        ? Theme.of(context).primaryColor
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Display ${display.id}',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  if (display.isPrimary) ...[
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: const Text('Primary'),
                                      backgroundColor: Theme.of(context)
                                          .primaryColor
                                          .withValues(alpha: 0.2),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow('Position',
                                  '(${display.bounds.x.toInt()}, ${display.bounds.y.toInt()})'),
                              _buildInfoRow('Size',
                                  '${display.bounds.width.toInt()} × ${display.bounds.height.toInt()}'),
                              _buildInfoRow('Work Area',
                                  '${display.workArea.width.toInt()} × ${display.workArea.height.toInt()}'),
                              _buildInfoRow('Scale Factor', '${display.scaleFactor}×'),
                              _buildInfoRow('Menu Bar Height',
                                  '${display.menuBarHeight.toInt()}px'),
                              _buildInfoRow('Dock Height',
                                  '${display.dockHeight.toInt()}px'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
