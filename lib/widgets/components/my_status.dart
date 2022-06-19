import 'package:flutter/material.dart';

class MyWaiting extends StatelessWidget {
  const MyWaiting({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
