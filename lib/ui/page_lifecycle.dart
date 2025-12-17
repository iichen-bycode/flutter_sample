import 'package:flutter/material.dart';

class PageLifecycleDemo extends StatefulWidget {
  const PageLifecycleDemo({super.key});

  @override
  State<PageLifecycleDemo> createState() => _PageLifecycleDemoState();
}

/*
  3.13
 */
class _PageLifecycleDemoState extends State<PageLifecycleDemo> with WidgetsBindingObserver{
  late AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _lifecycleListener = AppLifecycleListener(
        onShow: () {
          print('show');
        },
        onHide: () {
          print('hide');
        },
        onResume: () {
          print('resume');
        },
        onPause: () {
          print('pause');
        },
        onDetach: () {
          print('detach');
        },
        onInactive: () {
          print('inactive');
        },
        onRestart: () {
          print('restart');
        },
        onStateChange: (state) {
          print('state: $state');
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Page Lifecycle Demo'),
        ),
        body: Container(
          width: 200,
          height: 200,
          color: Color.from(alpha: 0.1, red: 0.6, green: 0.4, blue: 0.8),
          child: Column(
            children: [
              Text("coclor")
            ],
          ),
        )
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    super.didChangeAppLifecycleState(state);
    switch(state){
      case AppLifecycleState.resumed:
        print('resumed');
        break;
      case AppLifecycleState.inactive:
        print('inactive');
        break;
      case AppLifecycleState.paused:
        print('paused');
        break;
      case AppLifecycleState.detached:
        print('detached');
        break;
      case AppLifecycleState.hidden:
        print('hidden');
    }
  }
}
