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

@Equatable()
class Person {
  String? name;

  Person(String s) {
    name = s;
  }
}
