import 'dart:convert';
import 'dart:io';

class NativeHttpServer {
  static HttpServer? _server;
  static int _port = 8080;

  static Future<void> startServer() async {
    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );

      final ip = await _getLocalIP();
      print('服务器启动在: http://$ip:$_port');

      _server!.listen((HttpRequest request) async {
        await _handleRequest(request);
      });
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 48 || e.osError?.errorCode == 10048) {
        await _tryAlternativePorts();
      } else {
        rethrow;
      }
    }
  }

  static Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // 首先设置响应头
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    // 处理预检请求
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }

    try {
      final path = request.uri.path;

      switch (path) {
        case '/api/data':
          await _handleData(request, response);
          break;
        default:
          response.statusCode = HttpStatus.notFound;
          response.write('Not Found');
          await response.close();
      }
    } catch (e) {
      response.statusCode = HttpStatus.internalServerError;
      response.write('Error: $e');
      await response.close();
    }
  }

  static Future<void> _handleData(
      HttpRequest request,
      HttpResponse response,
      ) async {
    // 设置Content-Type头，必须在写入内容之前
    response.headers.contentType = ContentType.json;

    if (request.method == 'GET') {
      await Future.delayed(Duration(seconds: 2));
      response.write(jsonEncode({"data": "iichen"}));
    } else if (request.method == 'POST') {
      final body = await utf8.decodeStream(request);
      final jsonData = jsonDecode(body);
      await Future.delayed(Duration(seconds: 2));
      response.write(jsonEncode({"data": jsonData}));
    } else {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.write('Method not allowed');
    }

    await response.close();
  }

  static Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    print('服务器已停止');
  }

  static Future<String> _getLocalIP() async {
    for (final interface in await NetworkInterface.list()) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  static Future<void> _tryAlternativePorts() async {
    for (int port = 8081; port <= 8090; port++) {
      try {
        _port = port;
        await startServer();
        return;
      } catch (e) {
        continue;
      }
    }
    throw Exception('无法找到可用端口');
  }
}


main() async {
  await NativeHttpServer.startServer();
}