class HostDevice {
  const HostDevice({
    required this.ipAddress,
    required this.isReachable,
    this.hostname,
    this.responseTimeMs,
  });

  final String ipAddress;
  final bool isReachable;
  final String? hostname;
  final int? responseTimeMs;

  String get displayName => hostname ?? ipAddress;
}
