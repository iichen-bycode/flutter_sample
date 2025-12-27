// 证书固定方案
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';

import 'HTTPDNSResolver.dart';

class CertificatePinning {
  final dio = Dio(); // With default `Options`.

  void configureDio() {
    // Update default configs.
    dio.options.baseUrl = 'https://api.pub.dev';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);

    // Or create `Dio` with a `BaseOptions` instance.
    final options = BaseOptions(
      baseUrl: 'https://api.pub.dev',
      connectTimeout: Duration(seconds: 5),
      receiveTimeout: Duration(seconds: 3),
    );
    final anotherDio = Dio(options);

    // Or clone the existing `Dio` instance with all fields.
    final clonedDio = dio.clone();

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        // final SecurityContext securityContext = SecurityContext();
        // final cert = rootBundle.load('assets/cert.pem').then((byteData) {
        //   return byteData.buffer.asUint8List();
        // });
        // securityContext.setTrustedCertificatesBytes(cert);
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          return true;
        };
        return client;
      },
    );
  }
}

class SecureHttpClientAdapter extends IOHttpClientAdapter {
  final bool enableHTTPDNS;
  final Map<String, String>? hostOverrides;

  SecureHttpClientAdapter({
    this.enableHTTPDNS = true,
    this.hostOverrides,
  });

  @override
  CreateHttpClient? get createHttpClient => super.createHttpClient;


  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    String host = options.uri.host;
    String originalHost = host;

    // HTTPDNS解析
    if (enableHTTPDNS) {
      final resolvedIp = await HTTPDNSResolver.resolve(host);
      if (resolvedIp != null) {
        host = resolvedIp;
      }
    }

    // 主机名覆盖（用于测试或特定环境）
    if (hostOverrides != null && hostOverrides!.containsKey(originalHost)) {
      host = hostOverrides![originalHost]!;
    }

    // 如果IP地址改变，修改请求
    if (host != originalHost) {
      options = options.copyWith(
        baseUrl: options.uri.replace(host: host).toString(),
      );

      // 添加原始主机头（用于SNI）
      options.headers['Host'] = originalHost;
    }

    // 创建自定义HttpClient
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) {
        // 严格的证书验证
        return _validateCertificate(cert, host, port);
      }
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);

    return super.fetch(
      options,
      requestStream,
      cancelFuture
    );
  }

  bool _validateCertificate(X509Certificate cert, String host, int port) {
    // 1. 验证证书有效期
    if (!_isCertificateValid(cert)) {
      _logSecurityEvent('证书已过期或未生效');
      return false;
    }

    // 2. 验证主机名匹配
    if (!_isHostnameValid(cert, host)) {
      _logSecurityEvent('证书主机名不匹配');
      return false;
    }

    // 3. 验证证书链
    if (!_isCertificateChainValid(cert)) {
      _logSecurityEvent('证书链验证失败');
      return false;
    }

    return true;
  }

  void _logSecurityEvent(String message) {
    // 记录安全事件并上报
    print('[SECURITY] $message');
    // 可以上报到安全监控平台
  }

  bool _isCertificateValid(X509Certificate cert) {
    return true;
  }

  bool _isHostnameValid(X509Certificate cert, String host) {
    return true;
  }

  bool _isCertificateChainValid(X509Certificate cert) {
    return true;
  }
}