import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../utils/network_validation.dart';

class NetworkInfoService {
  NetworkInfoService({
    NetworkInfo? networkInfo,
    Connectivity? connectivity,
  })  : _networkInfo = networkInfo ?? NetworkInfo(),
        _connectivity = connectivity ?? Connectivity();

  final NetworkInfo _networkInfo;
  final Connectivity _connectivity;

  Future<String?> getLocalIp() async {
    final wifiIp = await _networkInfo.getWifiIP();
    if (wifiIp != null && wifiIp.isNotEmpty) {
      return wifiIp;
    }
    return await _firstNonLoopbackIpv4();
  }

  Future<String?> getGatewayIp() => _networkInfo.getWifiGatewayIP();

  Future<bool> hasNetworkConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<bool> isMeteredConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.mobile;
  }

  Future<String?> getPublicIp() async {
    const endpoints = [
      'https://api.ipify.org',
      'https://icanhazip.com',
    ];

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      for (final endpoint in endpoints) {
        try {
          final request = await client.getUrl(Uri.parse(endpoint));
          final response = await request.close();
          if (response.statusCode != HttpStatus.ok) continue;

          final body = await response.transform(utf8.decoder).join();
          final ip = body.trim();
          if (NetworkValidation.isValidPublicIp(ip)) return ip;
        } catch (_) {
          continue;
        }
      }
    } finally {
      client.close(force: true);
    }
    return null;
  }

  String? subnetFromIp(String ip, {int prefixLength = 24}) {
    return NetworkValidation.subnetFromIp(ip, prefixLength: prefixLength);
  }

  List<String> hostsInSubnet(String subnet) {
    return NetworkValidation.hostsInSubnet(subnet);
  }

  Future<String?> _firstNonLoopbackIpv4() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 &&
              !address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
