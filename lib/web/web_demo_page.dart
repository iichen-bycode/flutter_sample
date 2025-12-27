// main.dart - Flutter应用入口
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sample/web/shelf_web.dart';
import 'package:shelf/shelf.dart';


// 本地服务器页面
class LocalServerPage extends StatefulWidget {
  @override
  _LocalServerPageState createState() => _LocalServerPageState();
}

class _LocalServerPageState extends State<LocalServerPage> {
  final LocalServerService _server = LocalServerService();
  LocalServerState _serverState = LocalServerState.stopped;
  String _serverUrl = '';
  List<String> _logs = [];
  List<Map<String, dynamic>> _apiResponses = [];

  @override
  void initState() {
    super.initState();
    _serverState = LocalServerService().state;

    // 添加状态监听
    _server.addStateListener((state) {
      setState(() {
        _serverState = state;
        _serverUrl = _server.serverUrl ?? '';
      });
    });

    // 添加日志监听
    _server.addLogListener((log) {
      setState(() {
        _logs.add(log);
        if (_logs.length > 50) _logs.removeAt(0);
      });
    });

    // 添加示例API路由
    _addExampleRoutes();
  }

  void _startServer() async {
    try {
      await _server.start();
      _showSnackBar('服务器已启动');
    } catch (e) {
      _showSnackBar('启动失败: $e');
    }
  }

  void _addExampleRoutes() {
    // 用户API
    _server.addJsonApi(
      method: 'GET',
      path: '/api/users',
      handler: (Request request) async {
        return Response.ok(
          jsonEncode({
            'success': true,
            'data': [
              {'id': 1, 'name': '张三', 'age': 25},
              {'id': 2, 'name': '李四', 'age': 30},
            ],
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      },
    );

    // 计算API
    _server.addJsonApi(
      method: 'POST',
      path: '/api/calculate',
      handler: (Request request) async {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body) as Map<String, dynamic>;

          final a = (data['a'] as num?)?.toDouble() ?? 0;
          final b = (data['b'] as num?)?.toDouble() ?? 0;
          final operation = data['operation'] as String? ?? 'add';

          double result;
          switch (operation) {
            case 'add':
              result = a + b;
              break;
            case 'subtract':
              result = a - b;
              break;
            case 'multiply':
              result = a * b;
              break;
            case 'divide':
              result = b != 0 ? a / b : double.infinity;
              break;
            default:
              throw ArgumentError('不支持的操作: $operation');
          }

          return Response.ok(
            jsonEncode({
              'success': true,
              'result': result,
              'operation': operation,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
        } catch (e) {
          return Response.badRequest(
            body: jsonEncode({
              'error': e.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
        }
      },
    );
  }

  void _stopServer() async {
    await _server.stop();
    _showSnackBar('服务器已停止');
  }

  void _restartServer() async {
    await _server.restart();
    _showSnackBar('服务器已重启');
  }

  void _copyServerUrl() {
    if (_serverUrl.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _serverUrl));
      _showSnackBar('服务器地址已复制到剪贴板');
    }
  }

  Future<void> _testApi() async {
    if (_serverState != LocalServerState.running) {
      _showSnackBar('请先启动服务器');
      return;
    }

    try {
      // 测试GET请求
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('$_serverUrl/api/data'),
      );
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      setState(() {
        _apiResponses.add({
          'method': 'GET',
          'url': '/api/data',
          'status': response.statusCode,
          'body': jsonDecode(responseBody),
          'time': DateTime.now(),
        });
      });

      _showSnackBar('API测试成功');
    } catch (e) {
      _showSnackBar('API测试失败: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getStateText(LocalServerState state) {
    switch (state) {
      case LocalServerState.stopped:
        return '已停止';
      case LocalServerState.starting:
        return '启动中...';
      case LocalServerState.running:
        return '运行中';
      case LocalServerState.stopping:
        return '停止中...';
      case LocalServerState.error:
        return '错误';
    }
  }

  Color _getStateColor(LocalServerState state) {
    switch (state) {
      case LocalServerState.running:
        return Colors.green;
      case LocalServerState.stopped:
        return Colors.grey;
      case LocalServerState.error:
        return Colors.red;
      case LocalServerState.starting:
      case LocalServerState.stopping:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter 本地服务器'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _restartServer,
            tooltip: '重启服务器',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 服务器状态卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStateColor(_serverState),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '服务器状态: ${_getStateText(_serverState)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (_serverUrl.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '服务器地址: $_serverUrl',
                              style: TextStyle(
                                fontFamily: 'Monospace',
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.content_copy, size: 18),
                            onPressed: _copyServerUrl,
                            tooltip: '复制地址',
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.play_arrow),
                            label: Text('启动服务器'),
                            onPressed: _serverState == LocalServerState.stopped
                                ? _startServer
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.stop),
                            label: Text('停止服务器'),
                            onPressed: _serverState == LocalServerState.running
                                ? _stopServer
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // 测试按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.api),
                    label: Text('测试API'),
                    onPressed: _serverState == LocalServerState.running
                        ? _testApi
                        : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.storage),
                    label: Text('存储数据'),
                    onPressed: _serverState == LocalServerState.running
                        ? () {
                      _server.storeData('test_${DateTime.now().millisecondsSinceEpoch}', {
                        'value': '测试数据',
                        'time': DateTime.now().toIso8601String(),
                      });
                      _showSnackBar('数据已存储');
                    }
                        : null,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // 日志面板
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        '服务器日志',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Divider(height: 1),
                    Expanded(
                      child: _logs.isEmpty
                          ? Center(
                        child: Text(
                          '暂无日志',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                          : ListView.builder(
                        reverse: true,
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[_logs.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'Monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // API响应面板
            if (_apiResponses.isNotEmpty) ...[
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'API响应记录',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Divider(height: 1),
                    Container(
                      height: 150,
                      child: ListView.builder(
                        reverse: true,
                        itemCount: _apiResponses.length,
                        itemBuilder: (context, index) {
                          final response = _apiResponses[_apiResponses.length - 1 - index];
                          return ListTile(
                            title: Text(
                              '${response['method']} ${response['url']}',
                              style: TextStyle(fontFamily: 'Monospace'),
                            ),
                            subtitle: Text(
                              '状态码: ${response['status']}',
                              style: TextStyle(
                                color: (response['status'] as int) >= 400
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('响应详情'),
                                  content: SingleChildScrollView(
                                    child: Text(
                                      jsonEncode(response['body']),
                                      style: TextStyle(fontFamily: 'Monospace'),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('关闭'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
