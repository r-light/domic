import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_comic_card.dart';
import 'package:domic/widgets/components/my_drawer.dart';
import 'package:domic/widgets/components/my_grid_gesture_detector.dart';
import 'package:domic/widgets/components/my_setting_action.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

class MyComicPage extends StatelessWidget {
  const MyComicPage({Key? key}) : super(key: key);
  static const tabs = [ConstantString.history, ConstantString.favorite];

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                Navigator.pushNamed(context, Routes.myComicSearchPageRoute);
              },
              icon: const Icon(Icons.search),
            ),
            // setting
            ...alwaysInActions()
          ],
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.list, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
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
  late List<bool> isUpdated;
  bool isLoading = true;
  // final double padding = 5;
  // final int crossAxisCount = 3;
  // final double titleFontSize = 12;
  // final double sourceFontSize = 12;

  @override
  void initState() {
    super.initState();
    if (widget.tabIndex == 0) return;
    checkUpdate().then((shouldUpdate) {
      Provider.of<ComicLocal>(context, listen: false)
          .moveToFirstFromFavorite(shouldUpdate);
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
          isUpdated = List.filled(
              Provider.of<ComicLocal>(context, listen: true).favorite.length,
              false);
          return Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              getGridView(Provider.of<ComicLocal>(context, listen: true)
                  .favorite
                  .values
                  .toList()),
              GestureDetector(
                onTap: () {
                  Global.showSnackBar(context, "正在检查更新");
                  if (isLoading) return;
                  checkUpdate().then((shouldUpdate) {
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
      default:
        {
          return Container();
        }
    }
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
            child: ComicSimpleItem(
              comicSimple: record,
              isList: false,
            ),
          ),
          getUpdateBox(index),
        ]);
      },
    );
  }

  Future<List<ComicSimple>> checkUpdate() async {
    isLoading = true;
    List<ComicSimple> shouldUpdate = [];
    var favorite = Provider.of<ComicLocal>(context, listen: false).favorite;
    int i = 0;
    for (var entry in favorite.entries) {
      var record = entry.value;
      String source = record.source;
      String id = record.id;
      var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
      var key = Global.comicInfoKey(source, id);
      ComicInfo? before = Hive.box(ConstantString.comicBox).get(key);
      var parser = comicMethod[source] ?? comic18Method[source]!;
      var info = await parser.comicById(id);
      MyHive().putInHive(lazyBoxName, key, info);
      if (before == null || before.chapters.length != info.chapters.length) {
        isUpdated[i] = true;
        shouldUpdate.add(record);
      }
      Hive.box(ConstantString.comicBox).put(key, info);
      i++;
    }
    isLoading = false;
    return shouldUpdate;
  }

  Widget getUpdateBox(int index) {
    if (widget.tabIndex == 0) return Container();
    return isUpdated[index]
        ? Container(
            height: updateSize.height,
            width: updateSize.width,
            color: Colors.blue.shade400,
          )
        : Container();
  }

  @override
  bool get wantKeepAlive => true;
}
