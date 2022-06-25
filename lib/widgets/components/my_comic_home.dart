import 'dart:math';

import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_comic_card.dart';
import 'package:domic/widgets/components/my_grid_gesture_detector.dart';
import 'package:domic/widgets/components/my_setting_action.dart';
import 'package:domic/widgets/components/my_status.dart';
import 'package:flutter/material.dart';

/* 
"source"
*/
class MyComicHome extends StatefulWidget {
  const MyComicHome({Key? key, this.content}) : super(key: key);
  final dynamic content;

  @override
  createState() => _MyComicHomeState();
}

class _MyComicHomeState extends State<MyComicHome> {
  late Future tabsUrlFuture;
  List<String> tabs = [];

  Widget comicPage(BuildContext context, Widget body) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          centerTitle: false,
          title: Text(sourcesName["pufei"]!),
          actions: [
            IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.myComicSearchPageRoute),
              icon: const Icon(Icons.search),
            ),
            ...alwaysInActions(),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs.map<Widget>((name) => Tab(text: name)).toList(),
          ),
        ),
        body: body,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    var lazyBoxName = ConstantString.sourceToLazyBox[widget.content["source"]]!;
    var key = widget.content["source"] + "homeTabs";
    if (MyHive().isInHive(lazyBoxName, key, dur: const Duration(hours: 1))) {
      tabsUrlFuture = MyHive().getInHive(lazyBoxName, key);
    } else {
      var parser = (comicMethod[widget.content["source"]] ??
          comic18Method[widget.content["source"]]!) as dynamic;
      tabsUrlFuture = parser.getComicTabs().then((res) {
        var map = {for (var v in res) v.key: v.value};
        MyHive().putInHive(lazyBoxName, key, map);
        return map;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: tabsUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return comicPage(
              context,
              const Center(
                child: Text("失败了呜呜呜..."),
              ));
        }
        if (!snapshot.hasData) {
          return comicPage(context, const MyWaiting());
        }
        var tabsUrl = [];
        var map = snapshot.requireData as Map;
        map.forEach((k, v) => tabsUrl.add(MapEntry(k, v)));
        if (tabs.isEmpty) {
          for (var e in tabsUrl) {
            tabs.add(e.key);
          }
        }
        return comicPage(
            context,
            TabBarView(
                children: tabs
                    .asMap()
                    .map((index, key) {
                      return MapEntry(
                        index,
                        MyComicHomeLayout(index, key, tabsUrl[index].value,
                            widget.content["source"]!),
                      );
                    })
                    .values
                    .toList()));
      },
    );
  }
}

class MyComicHomeLayout extends StatefulWidget {
  final int index;
  final String tab;
  final String path;
  final String source;

  const MyComicHomeLayout(
    this.index,
    this.tab,
    this.path,
    this.source, {
    Key? key,
  }) : super(key: key);

  @override
  State<MyComicHomeLayout> createState() => _MyComicHomeLayoutState();
}

class _MyComicHomeLayoutState extends State<MyComicHomeLayout> {
  bool isLoading = true;
  bool hasMore = true;
  int maxPage = 1;
  int currentPage = 1;
  int totalNum = 0;
  List<ComicSimple> records = [];

  void loadMoreComicSimple() async {
    isLoading = true;
    String path = widget.path;

    Future future;
    var lazyBoxName = ConstantString.sourceToLazyBox[widget.source]!;
    var key = widget.source + path + currentPage.toString();
    if (MyHive().isInHive(lazyBoxName, key, dur: const Duration(hours: 1))) {
      future = MyHive().getInHive(lazyBoxName, key);
    } else {
      var parser = (comicMethod[widget.source] ?? comic18Method[widget.source]!)
          as dynamic;
      future = parser.comicByTab(widget.path, currentPage).then((pager) {
        MyHive().putInHive(lazyBoxName, key, pager);
        return pager;
      });
    }

    var page = (await future) as ComicPageData;
    maxPage = max(page.pageCount, maxPage);
    records.addAll(page.records);
    if (currentPage == 1) {
      if (page.maxNum == null) {
        totalNum += maxPage * page.records.length;
      } else {
        totalNum += page.maxNum!;
      }
    }
    setState(() {
      isLoading = false;
      currentPage++;
      if (currentPage > maxPage) {
        hasMore = false;
        totalNum = records.length;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    loadMoreComicSimple();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "已加载${records.length}/$totalNum项结果",
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
              ),
            ]),
        Expanded(
          child: getComicCard(context),
        ),
      ],
    );
  }

  Widget getComicCard(BuildContext context) {
    if (records.isEmpty) {
      return const MyWaiting();
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 4 / 5,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
      ),
      padding: const EdgeInsets.all(5.0),
      itemCount: hasMore ? records.length + 1 : records.length,
      itemBuilder: (context, index) {
        if (index >= records.length) {
          if (!isLoading) {
            loadMoreComicSimple();
          }
          return const MyWaiting();
        }
        ComicSimple record = records[index];
        return MyGridGestureDetector(
          record: record,
          child: ComicSimpleItem(
            comicSimple: record,
            isList: false,
          ),
        );
      },
    );
  }
}
