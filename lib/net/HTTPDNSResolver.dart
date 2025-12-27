// HTTPDNS实现
import 'dart:io';

import 'package:dio/dio.dart';

class HTTPDNSResolver {
  static final Map<String, String> _dnsCache = {};
  static final List<String> _dnsServers = [
    'https://doh.example.com/dns-query',
    'https://1.1.1.1/dns-query', // Cloudflare
    'https://dns.google/dns-query', // Google DNS
  ];
  
  static Future<String?> resolve(String host) async {
    // 检查缓存
    if (_dnsCache.containsKey(host)) {
      final cached = _dnsCache[host];
      if (cached != null && await _isIpReachable(cached)) {
        return cached;
      }
    }
    
    // 尝试多个DNS服务器
    for (final server in _dnsServers) {
      try {
        final ip = await _queryHTTPDNS(server, host);
        if (ip != null && await _isIpReachable(ip)) {
          _dnsCache[host] = ip;
          return ip;
        }
      } catch (e) {
        // 继续尝试下一个服务器
        continue;
      }
    }
    
    // 回退到系统DNS
    return null;
  }
  
  static Future<String?> _queryHTTPDNS(String server, String host) async {
    final response = await Dio().get(
      server,
      queryParameters: {
        'name': host,
        'type': 'A',
      },
      options: Options(
        headers: {
          'Accept': 'application/dns-json',
        },
      ),
    );
    
    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final answers = data['Answer'] as List?;
      if (answers != null && answers.isNotEmpty) {
        return answers.first['data'] as String?;
      }
    }
    
    return null;
  }
  
  static Future<bool> _isIpReachable(String ip) async {
    try {
      final socket = await Socket.connect(ip, 443, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }
}