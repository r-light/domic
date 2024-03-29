import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_comic_card.dart';
import 'package:domic/widgets/components/my_drawer.dart';
import 'package:domic/widgets/components/my_grid_gesture_detector.dart';
import 'package:domic/widgets/components/my_setting_action.dart';
import 'package:domic/widgets/components/my_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class MyComicPage extends StatelessWidget {
  const MyComicPage({Key? key}) : super(key: key);
  static const tabs = [
    ConstantString.history,
    ConstantString.favorite,
    ConstantString.favorite18
  ];

  @override
  Widget build(BuildContext context) {
    EasyLoading.instance.infoWidget = const Icon(
      Icons.refresh,
      color: Colors.white,
      size: 40,
    );
    return DefaultTabController(
      initialIndex: 1,
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            ConstantString.comicPageTitle,
          ),
          centerTitle: false,
          actions: [
            // search
            IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.myComicSearchPageRoute),
              icon: const Icon(Icons.search),
            ),
            // setting
            ...alwaysInActions()
          ],
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.list, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
          bottom: TabBar(
            isScrollable: false,
            tabs: tabs.map<Widget>((name) => Tab(text: name)).toList(),
          ),
        ),
        drawer: const MyDrawer(),
        body: TabBarView(
          children: tabs
              .asMap()
              .map((k, v) => MapEntry(k, MyComicLayout(tabIndex: k, name: v)))
              .values
              .toList(),
        ),
      ),
    );
  }
}

class MyComicLayout extends StatefulWidget {
  const MyComicLayout({Key? key, required this.tabIndex, required this.name})
      : super(key: key);
  final int tabIndex;
  final String name;

  @override
  State<StatefulWidget> createState() => MyComicLayoutState();
}

class MyComicLayoutState extends State<MyComicLayout>
    with AutomaticKeepAliveClientMixin {
  static const updateSize = Size(10, 10);
  bool isLoading = false;
  late Box box = Hive.box(ConstantString.comicBox);
  // final double padding = 5;
  // final int crossAxisCount = 3;
  // final double titleFontSize = 12;
  // final double sourceFontSize = 12;
  
  void checkVersionHelper() {
    checkVersion().then((shouldUpdate) {
      if (shouldUpdate) {
        Global.showSnackBar("检测到新版本");
      } else {
        Global.showSnackBar("当前版本已是最新");
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.tabIndex == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (widget.tabIndex == 1) {
        if (Provider.of<Configs>(context, listen: false).autoRefresh) {
          checkUpdate(Provider.of<ComicLocal>(context, listen: false).favorite)
              .then((shouldUpdate) {
            checkVersionHelper();
            Provider.of<ComicLocal>(context, listen: false)
                .moveToFirstFromFavorite(shouldUpdate);
          });
        } else {
          checkVersionHelper();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    switch (widget.tabIndex) {
      case 0:
        {
          return getGridView(Provider.of<ComicLocal>(context, listen: true)
              .history
              .values
              .toList()
              .reversed
              .toList());
        }
      case 1:
        {
          return Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              reorderableWidget(
                  Provider.of<ComicLocal>(context, listen: true)
                      .favorite
                      .values
                      .toList(),
                  1),
              GestureDetector(
                onTap: () {
                  if (isLoading) return;
                  checkUpdate(Provider.of<ComicLocal>(context, listen: false)
                          .favorite)
                      .then((shouldUpdate) {
                    Provider.of<ComicLocal>(context, listen: false)
                        .moveToFirstFromFavorite(shouldUpdate);
                  });
                },
                child: AbsorbPointer(
                    child: Container(
                  padding: const EdgeInsets.only(right: 20, bottom: 20),
                  child: FloatingActionButton(
                    onPressed: () {},
                    heroTag: null,
                    child: const Icon(Icons.refresh),
                  ),
                )),
              )
            ],
          );
        }
      case 2:
        {
          return Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              reorderableWidget(
                  Provider.of<ComicLocal>(context, listen: true)
                      .favorite18
                      .values
                      .toList(),
                  2),
              GestureDetector(
                onTap: () {
                  if (isLoading) return;
                  checkUpdate(Provider.of<ComicLocal>(context, listen: false)
                          .favorite18)
                      .then((shouldUpdate) {
                    Provider.of<ComicLocal>(context, listen: false)
                        .moveToFirstFromFavorite18(shouldUpdate);
                  });
                },
                child: AbsorbPointer(
                    child: Container(
                  padding: const EdgeInsets.only(right: 20, bottom: 20),
                  child: FloatingActionButton(
                    onPressed: () {},
                    heroTag: null,
                    child: const Icon(Icons.refresh),
                  ),
                )),
              )
            ],
          );
        }
      default:
        {
          return Container();
        }
    }
  }

  void onTap(ComicSimple item, {bool value = false}) {
    box.put(Global.latestKey(item), value);
  }

  Widget getGridView(List<ComicSimple> records) {
    return GridView.builder(
      padding: const EdgeInsets.all(5.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 4 / 5,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
      ),
      itemCount: records.length,
      itemBuilder: (context, index) {
        ComicSimple record = records[index];
        return Stack(alignment: AlignmentDirectional.bottomEnd, children: [
          MyGridGestureDetector(
            record: record,
            setterLatest: onTap,
            child: ComicSimpleItem(
              comicSimple: record,
              isList: false,
            ),
          ),
          getUpdateBox(records, index),
        ]);
      },
    );
  }

  Widget reorderableWidget(List<ComicSimple> records, int index) {
    return ReorderableGridView.builder(
        padding: const EdgeInsets.all(5.0),
        itemCount: records.length,
        onReorder: (oldIndex, newIndex) {
          if (index == 1) {
            Provider.of<ComicLocal>(context, listen: false)
                .insertFavoriteIndex(oldIndex, newIndex);
          }
          if (index == 2) {
            Provider.of<ComicLocal>(context, listen: false)
                .insertFavorite18Index(oldIndex, newIndex);
          }
        },
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 4 / 5,
          crossAxisSpacing: 5.0,
          mainAxisSpacing: 5.0,
        ),
        itemBuilder: (context, index) {
          ComicSimple record = records[index];
          return Stack(
              key: ValueKey(Global.comicSimpleKey(record)),
              alignment: AlignmentDirectional.bottomEnd,
              children: [
                MyGridGestureDetector(
                  record: record,
                  setterLatest: onTap,
                  child: ComicSimpleItem(
                    comicSimple: record,
                    isList: false,
                  ),
                ),
                getUpdateBox(records, index),
              ]);
        });
  }

  Future<List<ComicSimple>> checkUpdate(Map<String, ComicSimple> favorite) {
    _onLoading();
    isLoading = true;
    List<ComicSimple> shouldUpdate = [];
    var futures = <Future<ComicInfo>>[];
    List<ComicInfo?> before = [];
    for (var entry in favorite.entries) {
      var record = entry.value;
      String source = record.source;
      String id = record.id;
      var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
      var key = Global.comicInfoKey(source, id);
      before.add(Hive.box(ConstantString.comicBox).get(key));
      var parser = comicMethod[source] ?? comic18Method[source]!;
      futures.add(parser.comicById(id).then((comicInfo) {
        MyHive().putInHive(lazyBoxName, key, comicInfo);
        Hive.box(ConstantString.comicBox).put(key, comicInfo);
        return comicInfo;
      }));
    }
    return Future.wait(futures).then((comicInfos) {
      int i = 0;
      for (var entry in favorite.entries) {
        var record = entry.value;
        if (before[i] != null &&
            before[i]!.chapters.length != comicInfos[i].chapters.length) {
          shouldUpdate.add(record);
        }
        i++;
      }
      isLoading = false;
      EasyLoading.showSuccess("更新成功", dismissOnTap: true);
      return shouldUpdate;
    });
  }

  Widget getUpdateBox(List<ComicSimple> records, int index) {
    if (widget.tabIndex == 0) return Container();
    return box.get(Global.latestKey(records[index])) == false
        ? Container(
            height: updateSize.height,
            width: updateSize.width,
            color: Colors.blue.shade400,
          )
        : Container();
  }

  @override
  bool get wantKeepAlive => true;

  void _onLoading() {
    EasyLoading.showInfo(
      '正在查询漫画更新',
      duration: const Duration(seconds: 20),
      dismissOnTap: false,
    );
  }
}
