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
  Future checkUpdate() async {
    var resp = await MyDio().dio.get(ConstantString.versionUrl);
    if (resp.statusCode != 200) return false;
    _latestVersionInfo =
        MapEntry(resp.data["name"] ?? "", resp.data["body"] ?? "");
    if (_latestVersionInfo.key.isNotEmpty) {
      var latest = _latestVersionInfo.key;
      if (latest[0].codeUnitAt(0) < '0'.codeUnitAt(0) ||
          latest[0].codeUnitAt(0) > '9'.codeUnitAt(0)) {
        _latestVersionInfo =
            MapEntry(latest.substring(1), _latestVersionInfo.value);
      }
      if (latest != _version) {
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    checkUpdate();
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
                        Global.showSnackBar(context, "正在检查最新版本");
                        checkUpdate();
                        Global.showSnackBar(context, "检查完成");
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
