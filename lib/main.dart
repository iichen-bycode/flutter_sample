import 'package:flutter/material.dart';
import 'package:flutter_sample/ui/page_equatable.dart';
import 'package:flutter_sample/ui/page_lifecycle.dart';
import 'package:flutter_sample/ui/page_overlay_portal.dart';
import 'package:flutter_sample/web/shelf_web.dart';
import 'package:flutter_sample/web/web_demo_page.dart';
import 'package:get/get.dart';

void main() async {
  // 状态管理/依赖管理/路由管理
  /*
      只用Get来进行状态管理或依赖管理，就没有必要使用GetMaterialApp。
      GetMaterialApp对于路由、snackbar、国际化、bottomSheet、对话框以及与路由相关的高级apis和没有上下文（context）的情况下是必要的
   */
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化本地服务器
  await LocalServerService().initialize(config: LocalServerConfig(
    bindMode: ServerBindMode.localNetwork
  ));
  runApp(GetMaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      // home: MyHomePage(title: 'Flutter Demo Home Page'),
      home: LocalServerPage(),
      // home: PageLifecycleDemo(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Get.to(OverlayPortalDemoPage());
              },
              child: Text('OverlayPortalDemoPage'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.to(PageLifecycleDemo());
              },
              child: Text('PageLifecycleDemo'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.to(PageEquatable());
              },
              child: Text('PageEquatable'),
            ),
          ],
        ),
      ),
    );
  }
}

