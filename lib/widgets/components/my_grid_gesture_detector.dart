import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyGridGestureDetector extends StatelessWidget {
  const MyGridGestureDetector(
      {Key? key, required this.child, required this.record})
      : super(key: key);
  final Widget? child;
  final ComicSimple record;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pushNamed(context, Routes.myComicInfoRoute, arguments: {
          "record": record,
        });
        Provider.of<ComicLocal>(context, listen: false)
            .saveHistory(record)
            .whenComplete(() => Provider.of<ComicLocal>(context, listen: false)
                .removeHistory());
      },
      child: child,
    );
  }
}
