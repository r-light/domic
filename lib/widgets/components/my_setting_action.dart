import 'package:domic/comic/extractors/dto.dart';
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

  static List<String> tabs = ["通用", "阅读"];

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
        body: const TabBarView(children: [MyGeneralSetting(), MyReadSetting()]),
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
          title: const Text('删除历史记录'),
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
        // 修改阅读方向
        ListTile(
          minVerticalPadding: 4,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text("修改阅读方向"), readerDirWidget()],
          ),
        ),
        // 缓存大小
        ListTile(
          title: const Text('常规图源缓存'),
          subtitle: Text(
              "当前缓存: ${context.select((Configs configs) => configs.cacheImageNum)}"),
          onTap: () async {
            int? count = await showListDialog(context, "缓存数目");
            if (count == null) return;
            if (!mounted) return;
            Provider.of<Configs>(context, listen: false).cacheImageNum = count;
            if (!mounted) return;
            Global.showSnackBar("设置成功");
          },
        ),
        // 限制历史数目
        ListTile(
          title: const Text('18+图源缓存'),
          subtitle: Text(
              "当前缓存: ${context.select((Configs configs) => configs.cacheImage18Num)}"),
          onTap: () async {
            int? count = await showListDialog(context, "缓存数目");
            if (count == null) return;
            if (!mounted) return;
            Provider.of<Configs>(context, listen: false).cacheImage18Num =
                count;
            if (!mounted) return;
            Global.showSnackBar("设置成功");
          },
        ),
      ],
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

  Future<int?> showListDialog(BuildContext context, String text) async {
    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ListView.builder(
            itemCount: 10,
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              int number = (index + 1) * 1;
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
