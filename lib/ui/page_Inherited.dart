import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InheritedWidgetDemoPage extends StatefulWidget {
  const InheritedWidgetDemoPage({super.key});

  @override
  State<InheritedWidgetDemoPage> createState() => _InheritedWidgetDemoPageState();
}

class _InheritedWidgetDemoPageState extends State<InheritedWidgetDemoPage> {
  static final platform = MethodChannel('samples.flutter.dev/battery');
  static final BasicMessageChannel<String> imgBasicMessageChannel = BasicMessageChannel<String>(
    'battery_channel',
    const StringCodec(),
  );
  static final EventChannel _eventChannel = const EventChannel(
    'samples.flutter.dev/battery',
  );

  // @override
  void initState() {
    // TODO: implement initState
    super.initState();
    platform.invokeMethod('getBatteryLevel').then((value) {
      print("getBatteryLevel: $value");
    });

    imgBasicMessageChannel.setMessageHandler((message) async {
      print("imgBasicMessageChannel: $message");
      return "imgBasicMessageChannel: $message";
    });
    imgBasicMessageChannel.send("icon");

    _eventChannel.receiveBroadcastStream().listen((event) {
      print("_eventChannel: $event");
    });

    // enterFullScreenMode();
    // setImmersiveMode();
  }

  WrapData _data = WrapData();

  @override
  void reassemble() {
    // TODO: implement reassemble
    super.reassemble();
    // setImmersiveMode();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // 边缘到边缘模式
    // SystemChrome.setSystemUIOverlayStyle(
    //   SystemUiOverlayStyle(
    //     systemNavigationBarColor: Colors.transparent, // 导航栏透明
    //     systemNavigationBarIconBrightness: Brightness.light, // 导航栏图标亮度
    //     statusBarColor: Colors.transparent, // 状态栏透明
    //     statusBarIconBrightness: Brightness.light, // 状态栏图标亮度
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 避免下部分的输入框被键盘遮挡
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('InheritedWidgetDemoPage'),
      ),
      body: SafeArea(
        // top: true,
        // bottom: true,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: Column(
            children: [
              WrapInherite(
                data: _data,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _data.count++;
                        });
                      },
                      child: Text("Count: ${_data.count}"),
                    ),
                  ],
                ),
              ),
              const NormalWidget(type: 1),
              Spacer(),
              // Text("padding: ${MediaQuery.of(context).padding.bottom}"),
              Builder(
                builder: (context) {
                  return MyTextField();
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class MyTextField extends StatefulWidget {
  const MyTextField({super.key});

  @override
  State<MyTextField> createState() => _MyTextFieldState();
}

class _MyTextFieldState extends State<MyTextField> {
  final GlobalKey _textFieldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: _textFieldKey,
      decoration: InputDecoration(
        // 提示文本
        hintText: '请输入内容',
        hintStyle: TextStyle(color: Colors.grey),

        // 标签文本
        labelText: '用户名',
        labelStyle: TextStyle(color: Colors.blue),

        // 边框
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(10),
        ),

        // 填充色
        filled: true,
        fillColor: Colors.grey[200],

        // 前缀图标
        prefixIcon: Icon(Icons.person),

        // 内容内边距
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),

        // 其他样式设置
        // errorText: '错误提示',
        // errorStyle: TextStyle(color: Colors.red),
      ),
    );
  }
}


class NormalWidget extends StatefulWidget {
  final int type;
  const NormalWidget({super.key, required this.type});

  @override
  State<NormalWidget> createState() => _NormalWidgetState();
}

class _NormalWidgetState extends State<NormalWidget> {

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.accents[Random().nextInt(Colors.accents.length)],
      width: 100,
      height: 100,
    );
  }

  @override
  void didUpdateWidget(covariant NormalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("NormalWidget  didUpdateWidget ${widget.type}");
  }
}



class WrapData {
  int count = 0;
}

class WrapInherite extends InheritedWidget {
  const WrapInherite({
    super.key,
    required super.child,
    required this.data,
  });

  final WrapData data;

  @override
  bool updateShouldNotify(covariant WrapInherite oldWidget) {
    return true;
  }
}

class ImmersiveMode {
  // 设置全屏模式（隐藏状态栏和导航栏）
  static void setFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  // 设置全屏模式，但有手势操作时显示
  static void setFullScreenWithGesture() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  // 设置底部导航栏颜色（Android）
  static void setNavigationBarColor(Color color, {bool darkIcons = false}) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: color,
        systemNavigationBarIconBrightness:
        darkIcons ? Brightness.dark : Brightness.light,
      ),
    );
  }

  // 设置透明导航栏（Android）
  static void setTransparentNavigationBar() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  // 恢复默认
  static void restoreDefault() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

// 使用示例
void enterFullScreenMode() {
  ImmersiveMode.setFullScreenWithGesture();
}

void setImmersiveMode() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // 边缘到边缘模式
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent, // 导航栏透明
      systemNavigationBarIconBrightness: Brightness.light, // 导航栏图标亮度
      statusBarColor: Colors.transparent, // 状态栏透明
      statusBarIconBrightness: Brightness.light, // 状态栏图标亮度
    ),
  );
}

void setCustomNavigationBar() {
  ImmersiveMode.setNavigationBarColor(Colors.black, darkIcons: false);
}