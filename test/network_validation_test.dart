import 'package:flutter_test/flutter_test.dart';
import 'package:net_tool/utils/network_validation.dart';

void main() {
  group('NetworkValidation', () {
    test('rejects invalid octets in subnet', () {
      expect(NetworkValidation.isValidSubnet('999.999.999.0/24'), isFalse);
    });

    test('accepts valid /24 subnet', () {
      expect(NetworkValidation.isValidSubnet('192.168.1.0/24'), isTrue);
      expect(NetworkValidation.hostsInSubnet('192.168.1.0/24').length, 254);
    });

    test('rejects non-/24 subnet', () {
      expect(NetworkValidation.isValidSubnet('192.168.1.0/16'), isFalse);
    });

    test('identifies private and public IPs', () {
      expect(NetworkValidation.isPrivateOrReservedIp('192.168.1.1'), isTrue);
      expect(NetworkValidation.isPrivateOrReservedIp('10.0.0.1'), isTrue);
      expect(NetworkValidation.isValidPublicIp('8.8.8.8'), isTrue);
      expect(NetworkValidation.isValidPublicIp('192.168.1.1'), isFalse);
    });

    test('parses valid ports', () {
      expect(NetworkValidation.parsePort('8765'), 8765);
      expect(NetworkValidation.parsePort('0'), isNull);
      expect(NetworkValidation.parsePort('70000'), isNull);
    });

    test('validates hostnames', () {
      expect(NetworkValidation.isValidTarget('router.local'), isTrue);
      expect(NetworkValidation.isValidTarget('not a host'), isFalse);
    });
  });
}
