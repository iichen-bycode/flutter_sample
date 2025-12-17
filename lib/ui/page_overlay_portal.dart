import 'package:flutter/material.dart';

class OverlayPortalDemoPage extends StatefulWidget {
  const OverlayPortalDemoPage({super.key});

  @override
  State<OverlayPortalDemoPage> createState() => _OverlayPortalDemoPageState();
}

class _OverlayPortalDemoPageState extends State<OverlayPortalDemoPage>
    with SingleTickerProviderStateMixin {
  OverlayPortalController _overlayPortalController = OverlayPortalController();

  late AnimationController _animationController;
  late Animation<double> _animation;

  initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Overlay Portal Demo'),
        ),
        body: Container(
          child: Column(
            children: [
              ElevatedButton(
                child: OverlayPortal(
                    controller: _overlayPortalController,
                    overlayChildBuilder: (BuildContext context) {
                      return Positioned(
                        left: 100,
                        top: 200,
                        child: const ColoredBox(
                          color: Colors.amberAccent,
                          child: Text('Text Everyone Wants to See'),
                        ),
                      );
                    },
                    child: Text('Overlay Portal')),
                onPressed: () {
                  _overlayPortalController.toggle();
                },
              ),
              ElevatedButton(
                child: Text('Expand Animation'),
                onPressed: () {
                  if (_animationController.isCompleted) {
                    _animationController.reverse();
                  } else {
                    _animationController.forward();
                  }
                },
              ),
              ClipRect(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (BuildContext context, Widget? child) {
                    return Align(
                      heightFactor: _animation.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.red,
                      ),
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                  animation: _animationController,
                  builder: (BuildContext context, Widget? child) {
                    // return Flexible(
                    return Container(
                      height: 50,
                      child: FractionallySizedBox(
                        // widthFactor: _animation.value,
                        heightFactor: _animation.value,
                        child: Container(
                          width: 20,
                          height: 20,
                          color: Colors.red,
                        ),
                      ),
                    );
                  })
            ],
          ),
        ));
  }
}

class MyRectClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    // 返回一个矩形，这里我们裁剪一个居中的矩形，大小为原来的一半
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width / 2,
      height: size.height / 2,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    // 如果裁剪区域需要改变，则返回 true，否则返回 false
    return false;
  }
}
