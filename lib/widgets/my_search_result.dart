import 'dart:math';

import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_comic_card.dart';
import 'package:domic/widgets/components/my_grid_gesture_detector.dart';
import 'package:domic/widgets/components/my_status.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyComicSearchResult extends StatefulWidget {
  const MyComicSearchResult({Key? key, required this.content})
      : super(key: key);

  final dynamic content;

  @override
  State<MyComicSearchResult> createState() => _MyComicSearchResultState();
}

class _MyComicSearchResultState extends State<MyComicSearchResult> {
  bool isLoading = true;
  bool hasMore = true;
  Map<String, int> maxPageMap = {};
  int maxPage = 1;
  int currentPage = 1;
  int totalNum = 0;
  List<ComicSimple> records = [];

  String comicSimplePageKey(String source, String text, int currentPage) {
    return source + text + currentPage.toString();
  }

  // load more comicSimple
  void loadMoreComicSimple() async {
    isLoading = true;
    String text = widget.content;
    var entries = Provider.of<ComicSource>(context, listen: false)
        .sourceMap
        .entries
        .toList()
      ..addAll(
          Provider.of<ComicSource>(context, listen: false).source18Map.entries);
    var futures = <Future>[];
    for (var e in entries) {
      if (e.value) {
        var source = e.key;
        maxPageMap.putIfAbsent(source, () => 1);
        if (currentPage > maxPageMap[source]!) continue;
        var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
        var key = comicSimplePageKey(source, text, currentPage);
        if (MyHive()
            .isInHive(lazyBoxName, key, dur: const Duration(hours: 12))) {
          futures.add(MyHive().getInHive(lazyBoxName, key));
        } else {
          var parser = comicMethod[source] ?? comic18Method[source]!;
          futures.add(parser.comicByName(text, currentPage).then((pager) {
            MyHive().putInHive(lazyBoxName, key, pager);
            return pager;
          }));
        }
      }
    }
    var pagers = await Future.wait(futures);
    for (var page in pagers) {
      if (page.records.isEmpty) continue;
      maxPageMap[page.records.first.source] =
          max(maxPageMap[page.records.first.source]!, page.pageCount);
      records.addAll(page.records);
      maxPage = max(maxPage, maxPageMap[page.records.first.source]!);
      if (currentPage == 1) {
        totalNum += maxPageMap[page.records.first.source]! *
            (page.records.length as int);
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
    return Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          title: Text(widget.content, textAlign: TextAlign.left),
          centerTitle: false,
          actions: [
            context.select((Configs configs) => configs.listViewInSearchResult)
                ? IconButton(
                    onPressed: () => changeView(context),
                    icon: const Icon(Icons.grid_view),
                  )
                : IconButton(
                    onPressed: () => changeView(context),
                    icon: const Icon(Icons.list),
                  )
          ],
        ),
        body: Column(
          children: [
            Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "已加载${records.length}/$totalNum项结果, ${getActiveSourceLength(context)}个图源",
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                  ),
                ]),
            Expanded(
              child: getComicWidget(context),
            )
          ],
        ));
  }

  int getActiveSourceLength(BuildContext context) {
    var map = Provider.of<ComicSource>(context, listen: false).sourceMap;
    int len = 0;
    map.forEach((key, value) {
      if (value) len++;
    });
    map = Provider.of<ComicSource>(context, listen: false).source18Map;
    map.forEach((key, value) {
      if (value) len++;
    });
    return len;
  }

  void changeView(BuildContext context) {
    Provider.of<Configs>(context, listen: false).listViewInSearchResult =
        !Provider.of<Configs>(context, listen: false).listViewInSearchResult;
  }

  Widget getComicWidget(BuildContext context) {
    if (isLoading && records.isEmpty) {
      return const MyWaiting();
    }
    if (context.select((Configs configs) => configs.listViewInSearchResult)) {
      return ListView.separated(
          padding: const EdgeInsets.all(5.0),
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
              child: SizedBox(
                  height: MediaQuery.of(context).size.height / 6,
                  child: ComicSimpleItem(
                    comicSimple: record,
                    isList: true,
                  )),
            );
          },
          separatorBuilder: (context, index) => const Divider(
                thickness: 4,
              ),
          itemCount: hasMore ? records.length + 1 : records.length);
    } else {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 5.0,
          mainAxisSpacing: 5.0,
          childAspectRatio: 4 / 5,
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
}
