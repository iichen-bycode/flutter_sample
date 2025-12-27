# flutter_sample

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



- [Getx使用文档](https://github.com/jonataslaw/getx/blob/master/README.zh-cn.md)
 ## 状态管理 (与Provider之间的对比)   [](https://github.com/jonataslaw/getx/blob/master/documentation/zh_CN/state_management.md)
    1. -----------------------------------------------------------
    final name = ''.obs;
    final isLogged = false.obs;
    final count = 0.obs;
    final balance = 0.0.obs;
    final number = 0.obs;
    final items = <String>[].obs;
    final myMap = <String, int>{}.obs;
    
    // 自定义类 - 可以是任何类
    final user = User().obs;

    2. -----------------------------------------------------------
     ChangeNotifierProvider  类同于
    GetX<Controller>(
        builder: (controller) {
            print("count 1 rebuild");
            return Text('${controller.count1.value}');
        },
    ),

    3. -----------------------------------------------------------
    // controller.count.firstRebuild = true;   不管当前变量是否与初始值相同(变化与否)第一次都会重建布局,
    如某些根据字段判断跳转不同页面，isLogin = await(xxxx), 若isLogin初始值false.请求后任然是false将不会触发对应刷新监听,所以默认为true


    4. -----------------------------------------------------------
    // model
    // 我们将使整个类成为可观察的，而不是每个属性。
    class User{
        User({this.name = '', this.age = 0});
        String name;
        int age;
    }
    
    // controller
    final user = User().obs;
    //当你需要更新user变量时。
    user.update( (user) { // 这个参数是你要更新的类本身。
        user.name = 'Jonny';
        user.age = 18;
    });
    // 更新user变量的另一种方式。
    user(User(name: 'João', age: 35));
    
    // view
    Obx(()=> Text("Name ${user.value.name}: Age: ${user.value.age}"));
    // 你也可以不使用.value来访问模型值。
    user().name; // 注意是user变量，而不是类变量（首字母是小写的）。

    5. -----------------------------------------------------------
    事件发生时触发特定的回调
    ///每次`count1`变化时调用。
    ever(count1, (_) => print("$_ has been changed"));
    
    ///只有在变量$_第一次被改变时才会被调用。
    once(count1, (_) => print("$_ was changed once"));
    
    ///防DDos - 每当用户停止输入1秒时调用，例如。
    debounce(count1, (_) => print("debouce$_"), time: Duration(seconds: 1));
    
    ///忽略1秒内的所有变化。
    interval(count1, (_) => print("interval $_"), time: Duration(seconds: 1));

    6. -----------------------------------------------------------
    Class a => Class B (has controller X) => Class C (has controller X)
    如果你意外地从路由中删除了B，并试图使用C中的控制器，在这种情况下，B中的控制器的创建者ID被删除了，Get被设计为从内存中删除每一个没有创建者ID的控制器。如果你打算这样做，
    在B类的GetBuilder中添加 "autoRemove: false "标志，并在C类的GetBuilder中使用adopID = true；

    // Multi Child Setstate
    ==> GetBuilder<Controller>( //使用onInit()和onClose()方法
        initState: (_) => Controller.to.fetchApi(),
        dispose: (_) => Controller.to.closeStreams(),
        builder: (s) => Text('${s.username}'),
    ),
    // Single Child Setstate
    ==> GetX( 

    )
    ==> Obx()

 ## [路由管理](https://github.com/jonataslaw/getx/blob/master/documentation/zh_CN/route_management.md#navigation-with-named-routes)
    var data = await Get.to(Payment());
    Get.back(result: 'success');
    Get.off(NextScreen());  ==> replace
    Get.offAll(NextScreen()); ==> popUntil

    1. 别名路由导航 (在上述后添加Named即可)
        Get.toNamed("/NextScreen", arguments: 'Get is the best');   =>  Get.arguments 获取参数
        动态URL:  Get.offAllNamed("/NextScreen?device=phone&id=354&name=Enzo");  =>  Get.parameters['id']


        GetMaterialApp(
          unknownRoute: GetPage(name: '/notfound', page: () => UnknownRoutePage()),
          initialRoute: '/',
          getPages: [
            GetPage(name: '/', page: () => MyHomePage()),
            GetPage(name: '/second', page: () => Second()),
            GetPage(
              name: '/third',
              page: () => Third(),
              transition: Transition.zoom  
            ),
            GetPage(        ==>     Get.toNamed("/second/34954?flag=true");   <==     Get.parameters['user']
                name: '/profile/:user',
                page: () => UserProfile(),
            ),
          ],
        )

        Get.snackbar('Hi', 'i am a modern snackbar');
        Get.defaultDialog(
            onConfirm: () => print("Ok"),
            middleText: "Dialog made in 3 lines of code"
        );
        Get.bottomSheet(
            Container(
                child: Wrap(
                    children: <Widget>[
                        ListTile(
                            leading: Icon(Icons.music_note),
                            title: Text('Music'),
                            onTap: () {}
                        ,
                        ListTile(
                            leading: Icon(Icons.videocam),
                            title: Text('Video'),
                            onTap: () {},
                        ),
                    ],
                ),
            )
        );

 ##  依赖管理 [](https://github.com/jonataslaw/getx/blob/master/documentation/zh_CN/dependency_management.md)
    Get.put()
    Get.lazyPut<ApiMock>(() => ApiMock());  懒加载
    Get.putAsync<YourAsyncClass>( () async => await YourAsyncClass() )  异步实例

    Get.lazyPut的 "fenix "和其他方法的 "permanent":
        permanent   就是持久化
        fenix       针对那些你不担心在页面变化之间丢失的服务，但当你需要该服务时，你希望它还活着
    
    Get.create 的permanent 默认为true,但不是单例

    Custom Bindings 实现依赖关系:
        way One :
            #   class HomeBinding implements Bindings {
                @override
                    void dependencies() {
                        Get.lazyPut<HomeController>(() => HomeController());
                        Get.put<Service>(()=> Api());
                    }
                }
                
                class DetailsBinding implements Bindings {
                    @override
                        void dependencies() {
                        Get.lazyPut<DetailsController>(() => DetailsController());
                    }
                }
            # 在路由或路由别名中设置binding

        way Second :    (BindingsBuilder)
            binding: BindingsBuilder(() {
              Get.lazyPut<ControllerX>(() => ControllerX());
              Get.put<Service>(()=> Api());
            }),

# web服务器
    dart:io 内置 HTTP 服务器
    shelf 插件
    原生实现 channel 通信

# webView js交互
    webview_flutter 插件
# DNS劫持处理
    自定义httpClientAdapter
    response.header 解密异常字段、证书变化等    

# 请求加密
    证书相关 dio设置 httpClientAdapter
    定义拦截器 去处理 请求加密和响应解密


# ios、Android底部小白条
    SafeArea
    SystemChrome
```dart
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // 边缘到边缘模式
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent, // 导航栏透明
      systemNavigationBarIconBrightness: Brightness.light, // 导航栏图标亮度
      statusBarColor: Colors.transparent, // 状态栏透明
      statusBarIconBrightness: Brightness.light, // 状态栏图标亮度
    ),
  );
```
    MediaQuery

# flutter 图表手势处理

# flutter 本地存储
    shared_preferences 插件
    path_provider + dart:io 存储到本地
    sqflite 数据库存储

# flutter 项目过程中的难点

# flutter 响应式文字大小
    类似多语言 封装全局刷新
    MediaQurty
    flutter_screenutil 插件

# flutter 缓存

> flutter xxx方案。面试遇到提问该问题 该如何回答 想考察的是哪一方面


























