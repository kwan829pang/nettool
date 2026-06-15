enum SpeedTestType { internet, internal }

enum SpeedTestDirection { read, write }

class SpeedMeasureResult {
  const SpeedMeasureResult({
    required this.type,
    required this.direction,
    required this.megabitsPerSecond,
    required this.bytesTransferred,
    required this.durationMs,
    this.target,
    this.latencyMs,
  });

  final SpeedTestType type;
  final SpeedTestDirection direction;
  final double megabitsPerSecond;
  final int bytesTransferred;
  final int durationMs;
  final String? target;
  final double? latencyMs;

  String get formattedSpeed {
    if (megabitsPerSecond >= 1000) {
      return '${(megabitsPerSecond / 1000).toStringAsFixed(2)} Gbps';
    }
    return '${megabitsPerSecond.toStringAsFixed(2)} Mbps';
  }

  String get formattedSize {
    if (bytesTransferred >= 1024 * 1024) {
      return '${(bytesTransferred / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytesTransferred >= 1024) {
      return '${(bytesTransferred / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytesTransferred B';
  }
}
