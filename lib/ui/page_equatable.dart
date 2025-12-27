import 'dart:async';

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';


class PageEquatable extends StatefulWidget {
  const PageEquatable({super.key});

  @override
  State<PageEquatable> createState() => _PageEquatableState();
}

class _PageEquatableState extends State<PageEquatable> {
  @override
  void initState() {
    super.initState();

  }

  @override
  void reassemble() {
    super.reassemble();
    Person p = Person("iichen");
    print(p == Person("iichen"));

    Man m = Man("iichen");
    print(m == Man("iichen"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equatable'),
      ),
      body: const Center(
        child: Text('Equatable'),
      ),
    );
  }
}

class Man extends Equatable {
  // 必须是final
  final String? name;

  const Man(this.name);

  @override
  List<Object?> get props => [name];
}

class Person {
  String? name;

  Person(String s) {
    name = s;
  }
}


main() {
  asyncWork();
}
asyncWork() async {
  print('main #1 of 2');
  scheduleMicrotask(() => print('microtask #1 of 3'));

  Future.delayed(Duration(seconds: 1), () => print('future #1 (delayed)'));

  Future(() => print('future #2 of 4'))
      .then((_) => print('future #2a'))
      .then((_) {
    print('future #2b');
    scheduleMicrotask(() => print('microtask #0 (from future #2b)'));
  }).then((_) => print('future #2c'));

  scheduleMicrotask(() => print('microtask #2 of 3'));

  Future(() => print('future #3 of 4'))
      .then((_) => Future(() => print('future #3a (a  future)')))
      .then((_) => print('future #3b'));

  Future(() => print('future #4 of 4'));
  scheduleMicrotask(() => print('microtask #3 of 3'));
  print('main #2 of 2');
}