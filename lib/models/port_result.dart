enum PortState { open, closed, filtered }

class PortResult {
  const PortResult({
    required this.port,
    required this.state,
    this.service,
  });

  final int port;
  final PortState state;
  final String? service;

  bool get isOpen => state == PortState.open;
}
