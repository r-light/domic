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

class MyComicTag extends StatefulWidget {
  const MyComicTag({Key? key, required this.content}) : super(key: key);

  final dynamic content;

  @override
  State<MyComicTag> createState() => _MyComicTagState();
}

class _MyComicTagState extends State<MyComicTag> {
  bool isLoading = true;
  bool hasMore = true;
  int maxPage = 1;
  int currentPage = 1;
  int totalNum = 0;
  List<ComicSimple> records = [];
  int type = 0;

  String comicTagKey(String source, String tag, int currentPage, int type) {
    return "$source${tag}_&tpye_$currentPage";
  }

  // load more comicSimple
  void loadMoreComicSimple() async {
    isLoading = true;
    String source = widget.content["source"];
    String path = widget.content["path"];
    Future future;
    var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
    var key = comicTagKey(source, path, type, currentPage);
    if (MyHive().isInHive(lazyBoxName, key, dur: const Duration(hours: 1))) {
      future = MyHive().getInHive(lazyBoxName, key);
    } else {
      var parser = (comicMethod[source] ?? comic18Method[source]!) as dynamic;
      future = parser.comicByTag(path, currentPage, type: type).then((pager) {
        MyHive().putInHive(lazyBoxName, key, pager);
        return pager;
      });
    }

    var page = (await future) as ComicPageData;
    records.addAll(page.records);
    maxPage = max(maxPage, page.pageCount);
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
    return Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          title: Text(widget.content["name"], textAlign: TextAlign.left),
          centerTitle: false,
          actions: [
            context.select((Configs configs) => configs.listViewInTagResult)
                ? IconButton(
                    onPressed: () => changeView(context),
                    icon: const Icon(Icons.grid_view),
                  )
                : IconButton(
                    onPressed: () => changeView(context),
                    icon: const Icon(Icons.list),
                  ),
            viewTypeWidget(),
          ],
        ),
        body: Column(
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
              child: getComicWidget(context),
            )
          ],
        ));
  }

  void changeView(BuildContext context) {
    Provider.of<Configs>(context, listen: false).listViewInTagResult =
        !Provider.of<Configs>(context, listen: false).listViewInTagResult;
  }

  Widget getComicWidget(BuildContext context) {
    if (isLoading && records.isEmpty) {
      return const MyWaiting();
    }
    if (context.select((Configs configs) => configs.listViewInTagResult)) {
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

  Widget viewTypeWidget() {
    return PopupMenuButton<int>(
        onSelected: (int index) {
          setState(() {
            type = index;
            isLoading = true;
            hasMore = true;
            maxPage = 1;
            currentPage = 1;
            totalNum = 0;
            records.clear();
            loadMoreComicSimple();
          });
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              const PopupMenuItem<int>(
                value: 0,
                child: Text("最新"),
              ),
              const PopupMenuItem<int>(
                value: 1,
                child: Text("最多浏览"),
              ),
              const PopupMenuItem<int>(
                value: 2,
                child: Text("最多图片"),
              ),
              const PopupMenuItem<int>(
                value: 3,
                child: Text("最多爱心"),
              ),
            ]);
    return DropdownButton<int>(
      underline: const SizedBox(),
      // Initial Value
      value: 0,
      // Down Arrow Icon
      icon: const Icon(Icons.more),
      // Array list of items
      items: const [
        DropdownMenuItem(
          value: 0,
          child: Text("最新"),
        ),
        DropdownMenuItem(
          value: 1,
          child: Text("最多浏览"),
        ),
        DropdownMenuItem(
          value: 2,
          child: Text("最多图片"),
        ),
        DropdownMenuItem(
          value: 3,
          child: Text("最多爱心"),
        )
      ],
      // After selecting the desired option,it will
      // change button value to selected value
      onChanged: (int? value) {
        if (value != null) {
          setState(() {
            type = value;
          });
        }
      },
    );
  }
}
