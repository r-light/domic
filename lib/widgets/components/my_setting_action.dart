import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/jmtt.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

List<Widget> alwaysInActions() {
  return [
    const MySettingsAction(),
  ];
}

class MySettingsAction extends StatefulWidget {
  const MySettingsAction({Key? key}) : super(key: key);

  @override
  State<MySettingsAction> createState() => _SettingsActionState();
}

class _SettingsActionState extends State<MySettingsAction> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        Navigator.pushNamed(context, Routes.mySettingRoute);
      },
      icon: const Icon(Icons.settings),
    );
  }
}

class MySetting extends StatelessWidget {
  const MySetting({Key? key}) : super(key: key);

  static List<String> tabs = ["通用", "阅读", "禁漫天堂"];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(ConstantString.setting),
          centerTitle: false,
          bottom: TabBar(
            isScrollable: false,
            tabs: tabs.map<Widget>((e) => Tab(text: e)).toList(),
          ),
        ),
        body: const TabBarView(
            children: [MyGeneralSetting(), MyReadSetting(), MyJmttSetting()]),
      ),
    );
  }
}

class MyGeneralSetting extends StatefulWidget {
  const MyGeneralSetting({Key? key}) : super(key: key);

  @override
  State<MyGeneralSetting> createState() => _MyGeneralSettingState();
}

class _MyGeneralSettingState extends State<MyGeneralSetting> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(5.0),
      children: <Widget>[
        // 删除缓存
        ListTile(
          title: const Text('删除缓存'),
          onTap: () async {
            Global.showSnackBar("正在清除");
            await DefaultCacheManager().emptyCache();
            for (var boxName in ConstantString.boxName) {
              if (boxName == ConstantString.timeBox) {
                var box = Hive.box(boxName);
                await box.deleteAll(box.keys);
              }
            }
            for (var boxName in ConstantString.lazyBoxName) {
              var box = Hive.lazyBox(boxName);
              await box.deleteAll(box.keys);
            }
            clearDiskCachedImages();
            if (!mounted) return;
            Global.showSnackBar("清除成功");
          },
        ),
        // 删除历史记录
        ListTile(
          title: const Text('删除历史'),
          onTap: () async {
            Global.showSnackBar("正在清除");
            await Provider.of<ComicLocal>(context, listen: false)
                .removeAllHistory();
            if (!mounted) return;
            Global.showSnackBar("清除成功");
          },
        ),
        // 清除收藏
        ListTile(
          title: const Text('清除收藏'),
          onTap: () async {
            bool? delete = await showDeleteConfirmDialog(context, "是否删除收藏");
            if (delete == null) return;
            if (!mounted) return;
            Global.showSnackBar("正在清除");
            await Provider.of<ComicLocal>(context, listen: false)
                .removeAllFavorite();
            if (!mounted) return;
            Global.showSnackBar("清除成功");
          },
        ),
        // 删除下载及当前任务
        ListTile(
          title: const Text('删除当前任务及已下载'),
          onTap: () async {
            Global.showSnackBar("正在清除");
            Global.downloading.clear();
            for (var boxName in ConstantString.downloadBox) {
              var box = Hive.lazyBox(boxName);
              box.deleteAll(box.keys);
            }
            Global.showSnackBar("清除成功");
          },
        ),
        // 限制历史数目
        ListTile(
          title: const Text('限制历史数目'),
          subtitle: Text(
              "当前最大历史数目: ${context.select((ComicLocal comicLocal) => comicLocal.historyLimit)}"),
          onTap: () async {
            int? count = await showListDialog(context, "保留的历史数目");
            if (count == null) return;
            if (!mounted) return;
            Provider.of<ComicLocal>(context, listen: false).historyLimit =
                count;
            if (!mounted) return;
            Global.showSnackBar("设置成功");
          },
        ),
        // 启动app自动检查最新漫画
        ListTile(
          minVerticalPadding: 4,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text("启动时检查最新漫画"), autoRefreshWidget()],
          ),
        ),
      ],
    );
  }

  Widget autoRefreshWidget() {
    return DropdownButton<bool>(
      underline: const SizedBox(),
      // Initial Value
      value: context.select((Configs config) => config.autoRefresh),
      // Down Arrow Icon
      icon: const Icon(Icons.keyboard_arrow_down),
      // Array list of items
      items: const [
        DropdownMenuItem(
          value: true,
          child: Text("是"),
        ),
        DropdownMenuItem(
          value: false,
          child: Text("否"),
        )
      ],
      // After selecting the desired option,it will
      // change button value to selected value
      onChanged: (bool? value) {
        if (value != null) {
          Provider.of<Configs>(context, listen: false).autoRefresh = value;
        }
      },
    );
  }

  // 弹出对话框
  Future<bool?> showDeleteConfirmDialog(BuildContext context, String text) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("提示"),
          content: Text(text),
          actions: <Widget>[
            TextButton(
              child: const Text("取消"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("确认"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<int?> showListDialog(BuildContext context, String text) async {
    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ListView.builder(
            itemCount: 21,
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              int number = index * 5;
              return ListTile(
                title: Text("$number"),
                onTap: () => Navigator.of(context).pop(number),
              );
            },
          ),
        );
      },
    );
  }
}

class MyReadSetting extends StatefulWidget {
  const MyReadSetting({Key? key}) : super(key: key);

  @override
  State<MyReadSetting> createState() => _MyReadSettingState();
}

class _MyReadSettingState extends State<MyReadSetting> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(5.0),
      children: <Widget>[
        // 修改阅读方式
        ListTile(
          minVerticalPadding: 4,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text("修改阅读方式"), readerTypeWidget()],
          ),
        ),
        // 修改阅读方向
        ListTile(
          minVerticalPadding: 4,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text("修改阅读方向"), readerDirWidget()],
          ),
        ),
        // 网格模式显示漫画信息
        ListTile(
          minVerticalPadding: 4,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text("网格模式显示漫画信息"), showFooter()],
          ),
        ),
        // 显示滑动条
        ListTile(
          minVerticalPadding: 4,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text("显示滑动条"), showSlider()],
          ),
        ),
        // 常规图源缓存
        ListTile(
          title: const Text('常规图源缓存'),
          subtitle: Text(
              "当前缓存: ${context.select((Configs configs) => configs.cacheImageNum)}"),
          onTap: () async {
            int? count = await showListDialog(
                context, "缓存数目", List.generate(10, (index) => (index + 1)));
            if (count == null) return;
            if (!mounted) return;
            Provider.of<Configs>(context, listen: false).cacheImageNum = count;
            if (!mounted) return;
            Global.showSnackBar("设置成功");
          },
        ),
        // 18+图源缓存
        ListTile(
          title: const Text('18+图源缓存'),
          subtitle: Text(
              "当前缓存: ${context.select((Configs configs) => configs.cacheImage18Num)}"),
          onTap: () async {
            int? count = await showListDialog(
                context, "缓存数目", List.generate(10, (index) => index + 1));
            if (count == null) return;
            if (!mounted) return;
            Provider.of<Configs>(context, listen: false).cacheImage18Num =
                count;
            if (!mounted) return;
            Global.showSnackBar("设置成功");
          },
        ),
        // 设置crossAxisCountInSearchAndTag
        ListTile(
          title: const Text('搜索每行展示漫画数目(网格模式)'),
          subtitle: Text(
              "当前数目: ${context.select((Configs configs) => configs.crossAxisCountInSearchAndTag)}"),
          onTap: () async {
            int? count = await showListDialog(
                context, "当前数目", List.generate(5, (index) => index + 1));
            if (count == null) return;
            if (!mounted) return;
            Provider.of<Configs>(context, listen: false)
                .crossAxisCountInSearchAndTag = count;
            if (!mounted) return;
            Global.showSnackBar("设置成功");
          },
        ),
      ],
    );
  }

  Widget showFooter() {
    return DropdownButton<bool>(
      underline: const SizedBox(),
      // Initial Value
      value: context.select((Configs config) => config.showFooterInGridView),
      // Down Arrow Icon
      icon: const Icon(Icons.keyboard_arrow_down),
      // Array list of items
      items: const [
        DropdownMenuItem(
          value: true,
          child: Text("是"),
        ),
        DropdownMenuItem(
          value: false,
          child: Text("否"),
        )
      ],
      // After selecting the desired option,it will
      // change button value to selected value
      onChanged: (bool? value) {
        if (value != null) {
          Provider.of<Configs>(context, listen: false).showFooterInGridView =
              value;
        }
      },
    );
  }

  Widget showSlider() {
    return DropdownButton<bool>(
      underline: const SizedBox(),
      // Initial Value
      value: context.select((Configs config) => config.showBottomSlider),
      // Down Arrow Icon
      icon: const Icon(Icons.keyboard_arrow_down),
      // Array list of items
      items: const [
        DropdownMenuItem(
          value: true,
          child: Text("是"),
        ),
        DropdownMenuItem(
          value: false,
          child: Text("否"),
        )
      ],
      // After selecting the desired option,it will
      // change button value to selected value
      onChanged: (bool? value) {
        if (value != null) {
          Provider.of<Configs>(context, listen: false).showBottomSlider = value;
        }
      },
    );
  }

  Widget readerTypeWidget() {
    return DropdownButton<ReaderType>(
      underline: const SizedBox(),
      // Initial Value
      value: context.select((Configs config) => config.readerType),
      // Down Arrow Icon
      icon: const Icon(Icons.keyboard_arrow_down),
      // Array list of items
      items: ReaderType.values.map((ReaderType item) {
        return DropdownMenuItem(
          value: item,
          child: Text(ConstantString.readerTypeName[item.index]),
        );
      }).toList(),
      // After selecting the desired option,it will
      // change button value to selected value
      onChanged: (ReaderType? value) {
        if (value != null) {
          Provider.of<Configs>(context, listen: false).readerType = value;
        }
      },
    );
  }

  Widget readerDirWidget() {
    return DropdownButton<ReaderDirection>(
      underline: const SizedBox(),
      // Initial Value
      value: context.select((Configs config) => config.readerDirection),
      // Down Arrow Icon
      icon: const Icon(Icons.keyboard_arrow_down),
      // Array list of items
      items: ReaderDirection.values.map((ReaderDirection item) {
        return DropdownMenuItem(
          value: item,
          child: Text(ConstantString.readerDirectionName[item.index]),
        );
      }).toList(),
      // After selecting the desired option,it will
      // change button value to selected value
      onChanged: (ReaderDirection? value) {
        if (value != null) {
          Provider.of<Configs>(context, listen: false).readerDirection = value;
        }
      },
    );
  }

  Widget readerTimeWidget() {
    return DropdownButton<bool>(
      underline: const SizedBox(),
      // Initial Value
      value: context.select((Configs config) => config.showTimeInReader),
      // Down Arrow Icon
      icon: const Icon(Icons.keyboard_arrow_down),
      // Array list of items
      items: const [
        DropdownMenuItem(
          value: true,
          child: Text("是"),
        ),
        DropdownMenuItem(
          value: false,
          child: Text("否"),
        ),
      ],
      // After selecting the desired option,it will
      // change button value to selected value
      onChanged: (bool? value) {
        if (value != null) {
          Provider.of<Configs>(context, listen: false).showTimeInReader = value;
        }
      },
    );
  }

  // 弹出对话框
  Future<bool?> showDeleteConfirmDialog(BuildContext context, String text) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("提示"),
          content: Text(text),
          actions: <Widget>[
            TextButton(
              child: const Text("取消"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("确认"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future showListDialog(
      BuildContext context, String text, List<int> list) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ListView.builder(
            itemCount: list.length,
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              var content = list[index];
              return ListTile(
                title: Text("$content"),
                onTap: () => Navigator.of(context).pop(content),
              );
            },
          ),
        );
      },
    );
  }
}

class MyJmttSetting extends StatefulWidget {
  const MyJmttSetting({Key? key}) : super(key: key);

  @override
  State<MyJmttSetting> createState() => _MyJmttSettingState();
}

class _MyJmttSettingState extends State<MyJmttSetting> {
  Future<List<String>> urls = Jmtt().parseCandidateDomain();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(5.0),
      children: <Widget>[
        ListTile(
          title: const Text("设置域名"),
          subtitle: Text("当前域名: ${Jmtt().domainBase}"),
          onTap: () async {
            String? url = await showListDialog(context, "设置域名");
            if (url == null) return;
            if (!mounted) return;
            setState(() {
              Provider.of<Configs>(context, listen: false).jmttDomain = url;
              Jmtt().domainBase = url;
              MyDio()
                  .getHtml(RequestOptions(
                method: "GET",
                path: url,
              ))
                  .then((res) {
                if (res.key == 200) {
                  Global.showSnackBar("$url 测试成功\n已经阅读过的漫画在章节目录\n点击刷新按钮更换域名",
                      const Duration(seconds: 5));
                } else {
                  Global.showSnackBar("$url 测试失败");
                }
              });
            });
          },
        ),
      ],
    );
  }

  Future<String?> showListDialog(BuildContext context, String text) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        var child = FutureBuilder<List<String>>(
          future: urls,
          builder: ((context, snapshot) {
            if (snapshot.hasError || !snapshot.hasData) {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: 1,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    title: Text(Jmtt().permanentDomain),
                    subtitle: const Text("需要科学上网，可能不支持韩国、日本节点"),
                    onTap: () =>
                        Navigator.of(context).pop(Jmtt().permanentDomain),
                  );
                },
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: snapshot.requireData.length,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return ListTile(
                    title: Text(snapshot.requireData[index]),
                    subtitle: const Text("需要科学上网，可能不支持韩国、日本节点"),
                    onTap: () =>
                        Navigator.of(context).pop(snapshot.requireData[index]),
                  );
                }
                return ListTile(
                  title: Text(snapshot.requireData[index]),
                  onTap: () =>
                      Navigator.of(context).pop(snapshot.requireData[index]),
                );
              },
            );
          }),
        );
        return Dialog(child: child);
      },
    );
  }
}
