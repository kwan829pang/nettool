import 'package:flutter/material.dart';

class ScanProgressPanel extends StatelessWidget {
  const ScanProgressPanel({
    super.key,
    required this.isScanning,
    required this.completed,
    required this.total,
    this.currentItem,
    this.statusMessage,
  });

  final bool isScanning;
  final int completed;
  final int total;
  final String? currentItem;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isScanning)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Text(
                  isScanning ? 'Scanning…' : 'Ready',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  total > 0 ? '$completed / $total' : '—',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isScanning
                    ? (total > 0 ? progress : null)
                    : (completed > 0 ? progress : 0),
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            if (currentItem != null || statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                statusMessage ?? 'Checking $currentItem',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
