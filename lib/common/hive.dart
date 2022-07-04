import 'package:domic/common/common.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MyHive {
  static final MyHive _myHive = MyHive._internal();

  factory MyHive() {
    return _myHive;
  }

  MyHive._internal();

  init() async {
    await Hive.initFlutter();
    for (var name in ConstantString.boxName) {
      await Hive.openBox(name);
    }
    for (var name in ConstantString.lazyBoxName) {
      await Hive.openLazyBox(name);
    }
    for (var name in ConstantString.downloadBox) {
      await Hive.openLazyBox(name);
    }
  }

  bool isInHive(String lazyBoxName, String key,
      {Duration dur = const Duration(days: 1)}) {
    var box = Hive.lazyBox(lazyBoxName);
    var timeBox = Hive.box(ConstantString.timeBox);
    var timeKey = timeStampKey(key);
    if (timeBox.containsKey(timeKey)) {
      var before = timeBox.get(timeKey);
      var diff = DateTime.now().difference(before).inSeconds;
      if (diff <= dur.inSeconds) {
        return box.containsKey(key);
      }
    }
    return false;
  }

  Future<dynamic> getInHive(String lazyBoxName, String key) {
    return Hive.lazyBox(lazyBoxName).get(key);
  }

  void putInHive(String lazyBoxName, String key, dynamic value) async {
    await Hive.lazyBox(lazyBoxName).put(key, value);
    Hive.box(ConstantString.timeBox).put(timeStampKey(key), DateTime.now());
  }

  String timeStampKey(String key) {
    return "${key}DateTime";
  }
}
