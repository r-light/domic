import 'package:domic/widgets/components/my_version.dart';
import 'package:flutter/material.dart';

class MyAboutMe extends StatelessWidget {
  const MyAboutMe({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("关于"),
        ),
        body: const SafeArea(
            child: Column(
          children: [
            // version
            MyVersionInfo(),
            Divider(),
            MyProjectInfo(),
            Divider(),
          ],
        )));
  }
}
