import 'package:flutter/material.dart';

import '../models/speed_test_result.dart';
import '../theme/app_theme.dart';

class SpeedResultCard extends StatelessWidget {
  const SpeedResultCard({
    super.key,
    required this.label,
    required this.icon,
    this.result,
    this.latencyMs,
    this.accentColor = AppTheme.accentBlue,
  });

  final String label;
  final IconData icon;
  final SpeedMeasureResult? result;
  final double? latencyMs;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final value = result?.formattedSpeed ??
        (latencyMs != null ? '${latencyMs!.toStringAsFixed(0)} ms' : '—');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
            ),
            if (result != null) ...[
              const SizedBox(height: 4),
              Text(
                '${result!.formattedSize} in ${(result!.durationMs / 1000).toStringAsFixed(1)}s',
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
