// local_server_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

/// 本地服务器状态
enum LocalServerState {
  stopped,
  starting,
  running,
  stopping,
  error,
}

/// 服务器绑定模式
enum ServerBindMode {
  localhost,    // 仅本地访问
  localNetwork, // 局域网访问
}

/// 本地服务器配置
class LocalServerConfig {
  final ServerBindMode bindMode;
  final String host;
  final int port;
  final bool enableLogging;
  final String? staticAssetsPath;
  final bool autoStart;
  final bool allowExternalAccess;

  LocalServerConfig({
    this.bindMode = ServerBindMode.localNetwork, // 默认改为局域网模式
    String? host,
    this.port = 8080,
    this.enableLogging = !kReleaseMode,
    this.staticAssetsPath,
    this.autoStart = true,
    this.allowExternalAccess = true, // 默认允许外部访问
  }) : host = host ?? (bindMode == ServerBindMode.localhost ? '127.0.0.1' : '0.0.0.0');

  /// 获取服务器URL
  String get url => 'http://$host:$port';

  /// 获取WebSocket URL
  String get wsUrl => 'ws://$host:$port';
}

/// 本地服务器服务 - 支持局域网访问
class LocalServerService {
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();

  late LocalServerConfig _config;
  HttpServer? _server;
  Router? _router;
  LocalServerState _state = LocalServerState.stopped;

  // 网络接口信息
  List<NetworkInterface> _networkInterfaces = [];
  String? _localNetworkIp;
  List<int> _availablePorts = [8080, 8081, 8082, 8888, 3000, 3001, 8083, 8084];

  // 监听器列表
  final List<Function(LocalServerState)> _stateListeners = [];
  final List<Function(String)> _logListeners = [];

  // 路由表
  final Map<String, Map<String, Handler>> _routes = {};

  // 数据存储（用于演示）
  final Map<String, dynamic> _dataStore = {};

  /// 获取当前状态
  LocalServerState get state => _state;

  /// 获取服务器URL
  String? get serverUrl => _state == LocalServerState.running ? _config.url : null;

  /// 获取局域网访问地址
  String? get networkUrl {
    if (_state != LocalServerState.running || _localNetworkIp == null) {
      return null;
    }
    return 'http://$_localNetworkIp:${_config.port}';
  }

  /// 获取本地访问地址
  String? get localUrl => _state == LocalServerState.running
      ? 'http://localhost:${_config.port}'
      : null;

  /// 获取所有可用网络接口
  List<NetworkInterface> get networkInterfaces => _networkInterfaces;

  /// 初始化服务器
  Future<void> initialize({LocalServerConfig? config}) async {
    _config = config ?? LocalServerConfig();

    if (_state != LocalServerState.stopped) {
      _log('服务器已初始化');
      return;
    }

    _log('正在初始化本地服务器...');

    try {
      // 扫描网络接口
      await _scanNetworkInterfaces();

      // 创建路由器
      _router = Router();
      _setupDefaultRoutes();

      // 如果需要自动启动
      if (_config.autoStart) {
        await start();
      }
    } catch (e) {
      _state = LocalServerState.error;
      _notifyStateChange();
      _log('初始化失败: $e');
      rethrow;
    }
  }

  /// 扫描网络接口
  Future<void> _scanNetworkInterfaces() async {
    try {
      _networkInterfaces = await NetworkInterface.list(
        includeLoopback: true,
        includeLinkLocal: true,
      );

      _log('找到 ${_networkInterfaces.length} 个网络接口');

      // 显示所有接口信息
      for (final interface in _networkInterfaces) {
        _log('接口: ${interface.name}');
        for (final address in interface.addresses) {
          _log('  ${address.type.name}: ${address.address} (loopback: ${address.isLoopback})');
        }
      }

      // 尝试获取局域网IP - 优先选择Wi-Fi或以太网
      String? wifiIp;
      String? ethernetIp;
      String? anyIp;

      for (final interface in _networkInterfaces) {
        final name = interface.name.toLowerCase();
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 &&
              !address.isLoopback) {

            final ip = address.address;

            // 跳过链路本地地址
            if (ip.startsWith('169.254.')) continue;

            // 记录找到的IP
            anyIp = ip;

            // 根据接口类型分类
            if (name.contains('wlan') || name.contains('wifi') ||
                name.contains('无线') || name.contains('wl')) {
              wifiIp = ip;
            } else if (name.contains('eth') || name.contains('以太') ||
                name.contains('en') || name.contains('ethernet')) {
              ethernetIp = ip;
            }
          }
        }
      }

      // 优先级：Wi-Fi > 以太网 > 任意IP
      _localNetworkIp = wifiIp ?? ethernetIp ?? anyIp;

      if (_localNetworkIp != null) {
        _log('选择局域网IP: $_localNetworkIp');
      } else {
        _log('警告: 未发现可用的局域网IP地址');
      }

    } catch (e) {
      _log('扫描网络接口失败: $e');
    }
  }

  /// 启动服务器
  Future<void> start({LocalServerConfig? config}) async {
    if (_state == LocalServerState.running) {
      _log('服务器已在运行中');
      return;
    }

    if (_state == LocalServerState.starting) {
      _log('服务器正在启动中...');
      return;
    }

    try {
      _state = LocalServerState.starting;
      _notifyStateChange();

      _log('正在启动服务器...');
      _log('绑定模式: ${_config.bindMode}');
      _log('绑定地址: ${_config.host}');
      _log('端口: ${_config.port}');

      // 创建中间件管道
      final pipeline = const Pipeline()
          .addMiddleware(_errorHandlerMiddleware())
          .addMiddleware(_loggingMiddleware())
          .addMiddleware(_jsonMiddleware())
          .addMiddleware(_corsMiddleware()); // 添加CORS支持

      final handler = pipeline.addHandler(_router!);

      // 尝试启动服务器，如果端口被占用则尝试其他端口
      HttpServer? server;
      int actualPort = _config.port;
      String actualHost = _config.host;
      Exception? lastError;

      for (final port in _availablePorts) {
        try {
          _log('尝试启动在 $actualHost:$port');
          server = await io.serve(
            handler,
            actualHost,
            port,
            shared: true,
          );
          actualPort = port;
          break;
        } catch (e) {
          lastError = e as Exception?;
          if (e is SocketException && (e.osError?.errorCode == 48 || e.osError?.errorCode == 10048)) {
            _log('端口 $port 被占用，尝试其他端口...');
            continue;
          } else {
            _log('端口 $port 启动失败: $e');
            continue;
          }
        }
      }

      if (server == null) {
        throw Exception('所有端口都已被占用或无法绑定: $lastError');
      }

      _server = server;

      // 如果端口与配置不同，更新配置
      if (actualPort != _config.port) {
        _log('端口 ${_config.port} 被占用，使用端口 $actualPort');
      }

      // 创建新的配置
      _config = LocalServerConfig(
        bindMode: _config.bindMode,
        host: actualHost,
        port: actualPort,
        enableLogging: _config.enableLogging,
        staticAssetsPath: _config.staticAssetsPath,
        autoStart: _config.autoStart,
        allowExternalAccess: _config.allowExternalAccess,
      );

      _state = LocalServerState.running;
      _notifyStateChange();

      _printServerInfo(actualPort);

      // 启动后测试
      await _testAfterStart();

    } catch (e, stackTrace) {
      _state = LocalServerState.error;
      _notifyStateChange();
      _log('❌ 服务器启动失败: $e');
      if (kDebugMode) {
        _log('📋 Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// 打印服务器信息
  void _printServerInfo(int port) {
    _log('');
    _log('✅ 本地服务器已启动');
    _log('=' * 50);
    _log('📱 手机浏览器访问:');
    _log('   http://localhost:$port');
    _log('');

    if (_localNetworkIp != null && _config.bindMode == ServerBindMode.localNetwork) {
      _log('💻 电脑浏览器访问 (同一Wi-Fi下):');
      _log('   http://$_localNetworkIp:$port');
      _log('');
    }

    _log('📊 测试接口:');
    _log('   http://localhost:$port/status      - 服务器状态');
    _log('   http://localhost:$port/health      - 健康检查');
    _log('   http://localhost:$port/api/hello   - Hello API');
    _log('   http://localhost:$port/api/test    - 连接测试');
    _log('');

    // 显示所有可用的IP地址
    final addresses = _getAllAvailableAddresses(port);
    if (addresses.isNotEmpty) {
      _log('🌐 所有可用地址:');
      for (final address in addresses) {
        _log('   $address');
      }
    }

    _log('=' * 50);
  }

  /// 获取所有可用地址
  List<String> _getAllAvailableAddresses(int port) {
    final addresses = <String>[];

    // 添加本地地址
    addresses.add('http://localhost:$port');

    // 添加所有非回环的IPv4地址
    for (final interface in _networkInterfaces) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 &&
            !address.isLoopback &&
            !address.address.startsWith('169.254.')) {
          final url = 'http://${address.address}:$port';
          if (!addresses.contains(url)) {
            addresses.add(url);
          }
        }
      }
    }

    return addresses;
  }

  /// 启动后测试
  Future<void> _testAfterStart() async {
    try {
      // 等待一小段时间让服务器稳定
      await Future.delayed(Duration(milliseconds: 500));

      // 测试本地连接
      _log('测试本地连接...');
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://localhost:${_config.port}/health'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        _log('✅ 本地连接测试通过');
      } else {
        _log('⚠️  本地连接测试失败: ${response.statusCode}');
      }

      client.close();
    } catch (e) {
      _log('⚠️  本地连接测试失败: $e');
    }
  }

  /// 停止服务器
  Future<void> stop() async {
    if (_state != LocalServerState.running) {
      return;
    }

    try {
      _state = LocalServerState.stopping;
      _notifyStateChange();

      _log('正在停止服务器...');

      await _server?.close(force: true);
      _server = null;

      _state = LocalServerState.stopped;
      _notifyStateChange();

      _log('✅ 服务器已停止');
    } catch (e) {
      _state = LocalServerState.error;
      _notifyStateChange();
      _log('❌ 停止服务器失败: $e');
      rethrow;
    }
  }

  /// 重启服务器
  Future<void> restart() async {
    await stop();
    await start();
  }

  /// 添加路由
  void addRoute({
    required String method,
    required String path,
    required Handler handler,
  }) {
    _log('正在添加路由: $method $path');
    if (_router == null) {
      throw StateError('服务器未初始化');
    }

    _routes[path] ??= {};
    _routes[path]![method.toUpperCase()] = handler;

    switch (method.toUpperCase()) {
      case 'GET':
        _router!.get(path, handler);
        break;
      case 'POST':
        _router!.post(path, handler);
        break;
      case 'PUT':
        _router!.put(path, handler);
        break;
      case 'DELETE':
        _router!.delete(path, handler);
        break;
      case 'PATCH':
        _router!.patch(path, handler);
        break;
      default:
        throw ArgumentError('不支持的HTTP方法: $method');
    }

    _log('路由已添加: $method $path');
  }

  /// 添加JSON API路由
  void addJsonApi({
    required String method,
    required String path,
    required FutureOr<Response> Function(Request request) handler,
  }) {
    addRoute(
      method: method,
      path: path,
      handler: (Request request) async {
        try {
          final response = await handler(request);
          return response.change(
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              ...response.headers,
            },
          );
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({
              'error': e.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            }),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          );
        }
      },
    );
  }

  /// 存储数据
  void storeData(String key, dynamic value) {
    _dataStore[key] = value;
    _log('数据已存储: $key = $value');
  }

  /// 获取数据
  dynamic getData(String key) => _dataStore[key];

  /// 获取所有访问地址
  List<Map<String, String>> getAccessAddresses() {
    final addresses = <Map<String, String>>[];

    if (_state != LocalServerState.running) {
      return addresses;
    }

    // 本地地址
    addresses.add({
      'type': 'local',
      'name': '手机本地访问',
      'url': 'http://localhost:${_config.port}',
      'description': '在手机浏览器中访问',
    });

    // 局域网地址
    if (_localNetworkIp != null && _config.bindMode == ServerBindMode.localNetwork) {
      addresses.add({
        'type': 'network',
        'name': '电脑访问 (推荐)',
        'url': 'http://$_localNetworkIp:${_config.port}',
        'description': '同一Wi-Fi下的电脑浏览器访问',
      });
    }

    // 其他网络接口地址
    for (final interface in _networkInterfaces) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 &&
            !address.isLoopback &&
            !address.address.startsWith('169.254.') &&
            address.address != _localNetworkIp) {
          addresses.add({
            'type': 'interface',
            'name': '其他地址 (${interface.name})',
            'url': 'http://${address.address}:${_config.port}',
            'description': '网络接口地址',
          });
        }
      }
    }

    return addresses;
  }

  /// 添加状态监听器
  void addStateListener(Function(LocalServerState) listener) {
    _stateListeners.add(listener);
  }

  /// 移除状态监听器
  void removeStateListener(Function(LocalServerState) listener) {
    _stateListeners.remove(listener);
  }

  /// 添加日志监听器
  void addLogListener(Function(String) listener) {
    _logListeners.add(listener);
  }

  /// 移除日志监听器
  void removeLogListener(Function(String) listener) {
    _logListeners.remove(listener);
  }

  /// 设置默认路由
  void _setupDefaultRoutes() {
    // 服务器状态
    _router!.get('/status', (Request request) {
      return Response.ok(
        jsonEncode({
          'status': _state.name,
          'server': 'Flutter Local Server',
          'version': '1.0.0',
          'timestamp': DateTime.now().toIso8601String(),
          'config': {
            'bindMode': _config.bindMode.name,
            'host': _config.host,
            'port': _config.port,
          },
          'network': {
            'localIp': _localNetworkIp,
            'interfaces': _networkInterfaces.map((i) => {
              'name': i.name,
              'addresses': i.addresses.map((a) => {
                'address': a.address,
                'type': a.type.name,
                'loopback': a.isLoopback,
              }).toList(),
            }).toList(),
          },
          'accessAddresses': getAccessAddresses(),
          'routes': _routes.keys.toList(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    });

    // 健康检查
    _router!.get('/health', (Request request) {
      return Response.ok(
        jsonEncode({
          'healthy': _state == LocalServerState.running,
          'timestamp': DateTime.now().toIso8601String(),
          'server': 'Flutter Local Server',
          'version': '1.0.0',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    });

    // 数据API
    _router!.get('/api/data', (Request request) {
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': _dataStore,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    });

    _router!.post('/api/data', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;

        _dataStore.addAll(data);

        return Response.ok(
          jsonEncode({
            'success': true,
            'message': '数据已保存',
            'timestamp': DateTime.now().toIso8601String(),
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({
            'error': '无效的JSON数据',
            'timestamp': DateTime.now().toIso8601String(),
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
    });

    // 清除数据
    _router!.delete('/api/data', (Request request) {
      _dataStore.clear();
      return Response.ok(
        jsonEncode({
          'success': true,
          'message': '数据已清除',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    });

    // 示例API
    _router!.get('/api/hello', (Request request) {
      final name = request.requestedUri.queryParameters['name'] ?? 'Flutter';
      return Response.ok(
        jsonEncode({
          'message': 'Hello, $name!',
          'server': 'Flutter Local Server',
          'timestamp': DateTime.now().toIso8601String(),
          'tip': '同一网络下的电脑可以访问此接口',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    });

    // 连接测试API
    _router!.get('/api/test', (Request request) {
      // 尝试获取客户端IP（从各种可能的头部）
      final clientIp = _getClientIpFromRequest(request);

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': '连接测试成功',
          'server_info': {
            'bind_mode': _config.bindMode.name,
            'host': _config.host,
            'port': _config.port,
            'local_ip': _localNetworkIp,
            'server_urls': getAccessAddresses().map((a) => a['url']).toList(),
          },
          'client_info': {
            'ip': clientIp,
            'user_agent': request.headers['user-agent'],
            'headers': request.headers,
          },
          'timestamp': DateTime.now().toIso8601String(),
          'instructions': {
            'mobile': '手机浏览器访问 http://localhost:${_config.port}',
            'computer': '电脑浏览器访问 http://$_localNetworkIp:${_config.port} (需同一Wi-Fi)',
          },
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    });

    // 404处理 - 提供有用的错误信息
    _router!.all('/<ignored|.*>', (Request request) {
      final path = request.requestedUri.path;

      return Response.notFound(
        jsonEncode({
          'error': '路由不存在: $path',
          'available_routes': [
            '/status',
            '/health',
            '/api/hello',
            '/api/test',
            '/api/data',
          ],
          'timestamp': DateTime.now().toIso8601String(),
          'help': '请访问 /status 查看所有可用接口',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    });
  }

  /// 获取客户端IP（兼容性方法）
  String _getClientIpFromRequest(Request request) {
    // 尝试从各种头部获取IP
    final headers = request.headers;

    // 常见的代理头部
    final proxyHeaders = [
      'x-forwarded-for',
      'x-real-ip',
      'x-client-ip',
      'cf-connecting-ip',
      'true-client-ip',
    ];

    for (final header in proxyHeaders) {
      final ip = headers[header];
      if (ip != null && ip.isNotEmpty) {
        // 处理多个IP的情况（如x-forwarded-for: client, proxy1, proxy2）
        final ips = ip.split(',').map((s) => s.trim()).toList();
        if (ips.isNotEmpty) {
          return ips.first;
        }
      }
    }

    // 如果无法获取，返回unknown
    return 'unknown';
  }

  /// CORS中间件 - 允许跨域访问
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        // 处理OPTIONS预检请求
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await handler(request);

        return response.change(headers: {
          ...response.headers,
          ..._corsHeaders,
        });
      };
    };
  }

  /// CORS头
  Map<String, String> get _corsHeaders {
    return {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Credentials': 'true',
      'Access-Control-Max-Age': '86400',
    };
  }

  /// 错误处理中间件
  Middleware _errorHandlerMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        try {
          return await handler(request);
        } catch (e, stackTrace) {
          _log('❌ 请求处理错误: $e');
          if (kDebugMode) {
            _log('📋 Stack trace: $stackTrace');
          }

          return Response.internalServerError(
            body: jsonEncode({
              'error': '内部服务器错误',
              'message': kDebugMode ? e.toString() : '请稍后重试',
              'timestamp': DateTime.now().toIso8601String(),
            }),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          );
        }
      };
    };
  }

  /// 日志中间件
  Middleware _loggingMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (!_config.enableLogging) {
          return await handler(request);
        }

        final startTime = DateTime.now();
        final stopwatch = Stopwatch()..start();

        try {
          final response = await handler(request);
          stopwatch.stop();

          // 尝试获取客户端IP
          final clientIp = _getClientIpFromRequest(request);

          _log(
            '📡 $clientIp - ${request.method} ${request.requestedUri.path} '
                '→ ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
          );

          return response;
        } catch (e) {
          stopwatch.stop();
          _log(
            '❌ ${request.method} ${request.requestedUri.path} '
                '→ ERROR (${stopwatch.elapsedMilliseconds}ms): $e',
          );
          rethrow;
        }
      };
    };
  }

  /// JSON中间件
  Middleware _jsonMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final response = await handler(request);

        // 如果没有设置Content-Type，默认为JSON
        if (response.headers['content-type'] == null &&
            response.headers['Content-Type'] == null) {
          try {
            final body = await response.readAsString();
            jsonDecode(body); // 验证是否为有效JSON

            return response.change(
              headers: {
                ...response.headers,
                'Content-Type': 'application/json; charset=utf-8',
              },
            );
          } catch (_) {
            // 不是JSON，保持原样
          }
        }

        return response;
      };
    };
  }

  /// 记录日志
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logMessage = '[$timestamp] $message';

    if (kDebugMode) {
      debugPrint(logMessage);
    }

    for (final listener in _logListeners) {
      listener(logMessage);
    }
  }

  /// 通知状态变化
  void _notifyStateChange() {
    for (final listener in _stateListeners) {
      listener(_state);
    }
  }
}