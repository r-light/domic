import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

String _version = "";
MapEntry<String, String> _latestVersionInfo = const MapEntry("", "");

Future initVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  _version = packageInfo.version;
}

Future<bool> checkVersion() async {
  var resp = await MyDio().dio.get(ConstantString.versionUrl);
  if (resp.statusCode != 200) return false;
  _latestVersionInfo =
      MapEntry(resp.data["name"] ?? "", resp.data["body"] ?? "");
  if (_latestVersionInfo.key.isNotEmpty) {
    var latest = _latestVersionInfo.key;
    int i = 0, j = latest.length - 1;
    while (latest[i].codeUnitAt(0) < '0'.codeUnitAt(0) ||
        latest[i].codeUnitAt(0) > '9'.codeUnitAt(0)) {
      i++;
    }
    while (latest[j].codeUnitAt(0) < '0'.codeUnitAt(0) ||
        latest[j].codeUnitAt(0) > '9'.codeUnitAt(0)) {
      j--;
    }
    _latestVersionInfo =
        MapEntry(latest.substring(i), _latestVersionInfo.value);
    return latest.substring(i, j + 1) != _version;
  }
  return false;
}

class MyVersionInfo extends StatelessWidget {
  const MyVersionInfo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              '软件版本 : $_version',
            ),
          ),
        ],
      ),
    );
  }
}

class MyProjectInfo extends StatefulWidget {
  const MyProjectInfo({Key? key}) : super(key: key);

  @override
  State<MyProjectInfo> createState() => _MyProjectInfoState();
}

class _MyProjectInfoState extends State<MyProjectInfo> {
  @override
  void initState() {
    super.initState();
    checkVersion().then((shouldUpdate) {
      if (shouldUpdate) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: GestureDetector(
              child: const Text(
                "项目地址",
                style: TextStyle(color: Colors.blue),
              ),
              onTap: () {
                Global.openUrl(ConstantString.releaseUrl);
              },
            ),
            subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("最新版本: ${_latestVersionInfo.key}"),
                  GestureDetector(
                      child: const Text(
                        "检查更新",
                        style: TextStyle(color: Colors.blue),
                      ),
                      onTap: () {
                        Global.showSnackBar("正在检查最新版本");
                        checkVersion().then((shouldUpdate) {
                          if (shouldUpdate) setState(() {});
                        });
                        Global.showSnackBar("检查完成");
                      })
                ]),
          ),
          ListTile(
            title: const Text("更新内容"),
            subtitle: Text(_latestVersionInfo.value),
          ),
        ],
      ),
    );
  }
}
