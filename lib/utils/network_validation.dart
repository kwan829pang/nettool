import 'dart:io';

/// Shared validation for IPs, hostnames, ports, and subnets.
class NetworkValidation {
  NetworkValidation._();

  static const int minPort = 1;
  static const int maxPort = 65535;
  static const int maxPortScanRange = 10240;
  static const int maxPortScanConcurrency = 32;
  static const int defaultSubnetPrefix = 24;

  static bool isValidIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    return parts.every((part) {
      final octet = int.tryParse(part);
      return octet != null && octet >= 0 && octet <= 255;
    });
  }

  static bool isPrivateOrReservedIp(String ip) {
    if (!isValidIpv4(ip)) return true;

    final octets = ip.split('.').map(int.parse).toList();
    final a = octets[0];
    final b = octets[1];

    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    if (a == 127) return true;
    if (a == 0) return true;
    if (a == 169 && b == 254) return true;
    if (a == 100 && b >= 64 && b <= 127) return true; // CGNAT
    if (a >= 224) return true; // multicast / reserved

    return false;
  }

  static bool isValidPublicIp(String ip) {
    return isValidIpv4(ip) && !isPrivateOrReservedIp(ip);
  }

  static bool isValidHostname(String host) {
    if (host.isEmpty || host.length > 253) return false;
    if (host.startsWith('.') || host.endsWith('.')) return false;

    final labelPattern = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$');
    return host.split('.').every(labelPattern.hasMatch);
  }

  static bool isValidTarget(String target) {
    return isValidIpv4(target) || isValidHostname(target);
  }

  static bool isPrivateOrLocalTarget(String target) {
    if (isValidIpv4(target)) {
      return isPrivateOrReservedIp(target);
    }
    final lower = target.toLowerCase();
    return lower == 'localhost' || lower.endsWith('.local');
  }

  static int? parsePort(String text) {
    final port = int.tryParse(text.trim());
    if (port == null || port < minPort || port > maxPort) return null;
    return port;
  }

  static bool isValidSubnet(String subnet) {
    final match = RegExp(
      r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})$',
    ).firstMatch(subnet.trim());
    if (match == null) return false;

    final octets = [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
    ];
    if (octets.any((o) => o < 0 || o > 255)) return false;

    final prefix = int.parse(match.group(5)!);
    return prefix == defaultSubnetPrefix;
  }

  static List<String> hostsInSubnet(String subnet) {
    if (!isValidSubnet(subnet)) return [];

    final base = subnet.split('/').first;
    final parts = base.split('.');
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    return List.generate(254, (index) => '$prefix.${index + 1}');
  }

  static String? subnetFromIp(String ip, {int prefixLength = defaultSubnetPrefix}) {
    if (!isValidIpv4(ip) || prefixLength != defaultSubnetPrefix) return null;
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}.0/$prefixLength';
  }

  static bool isDesktopPlatform() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }
}
