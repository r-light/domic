import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/jmtt.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_comic_card.dart';
import 'package:domic/widgets/components/my_grid_gesture_detector.dart';
import 'package:domic/widgets/components/my_setting_action.dart';
import 'package:domic/widgets/components/my_status.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class MyComicInfoPage extends StatefulWidget {
  const MyComicInfoPage({Key? key, required this.content}) : super(key: key);
  final dynamic content;

  @override
  State<MyComicInfoPage> createState() => _MyComicInfoPageState();
}

class _MyComicInfoPageState extends State<MyComicInfoPage> {
  static const tabs = [ConstantString.chapters, ConstantString.recommendations];
  late Decoration? dec =
      MediaQuery.of(context).platformBrightness == Brightness.dark
          ? null
          : BoxDecoration(color: Theme.of(context).colorScheme.primary);
  late Color fontColor =
      MediaQuery.of(context).platformBrightness == Brightness.dark
          ? Colors.white
          : Colors.grey.shade800;
  late Future<ComicInfo> _comicInfo =
      loadComicInfo(dur: const Duration(hours: 1));
  Future? _comicRelated;
  ComicInfo? _comicInfoRes;
  late bool _reversed = Hive.box(ConstantString.comicBox)
          .get(Global.reversedKey(widget.content["record"])) ??
      false;
  late int? _index = Hive.box(ConstantString.comicBox)
      .get(Global.indexKey(widget.content["record"]));
  int? _length;

  void saveIndex(ComicSimple record) {
    Hive.box(ConstantString.comicBox).put(Global.indexKey(record), _index);
  }

  void saveReversed(ComicSimple record) async {
    Hive.box(ConstantString.comicBox)
        .put(Global.reversedKey(record), _reversed);
  }

  int? getLength(ComicSimple record) {
    return Hive.box(ConstantString.comicBox)
        .get("${Global.indexKey(record)}_length");
  }

  void saveLength(ComicSimple record, int length) {
    Hive.box(ConstantString.comicBox)
        .put("${Global.indexKey(record)}_length", length);
  }

  Future<ComicInfo> loadComicInfo(
      {Duration dur = const Duration(hours: 12)}) async {
    ComicSimple record = widget.content["record"];
    String source = record.source;
    String id = record.id;
    var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
    var key = Global.comicInfoKey(source, id);
    ComicInfo info;
    if (MyHive().isInHive(lazyBoxName, key, dur: dur)) {
      info = await MyHive().getInHive(lazyBoxName, key);
    } else {
      var parser = comicMethod[source] ?? comic18Method[source]!;
      info = await parser.comicById(id);
      MyHive().putInHive(lazyBoxName, key, info);
    }
    Hive.box(ConstantString.comicBox).put(key, info);
    var oldLength = getLength(record);
    if (oldLength != null && info.chapters.length != oldLength) {
      if (!_reversed && _index != null) {
        _index = info.chapters.length - oldLength + _index!;
        saveIndex(record);
      }
    }
    saveLength(record, info.chapters.length);
    return info;
  }

  @override
  Widget build(BuildContext context) {
    _index = Hive.box(ConstantString.comicBox)
        .get(Global.indexKey(widget.content["record"]));
    _reversed = Hive.box(ConstantString.comicBox)
            .get(Global.reversedKey(widget.content["record"])) ??
        false;
    ComicSimple record = widget.content["record"];
    var actions = [
      IconButton(
        icon: const Icon(
          Icons.source,
        ),
        onPressed: () =>
            Navigator.pushNamed(context, Routes.myComicSourceRoute),
      ),
      IconButton(
        icon: const Icon(
          Icons.search,
          color: Colors.white,
        ),
        onPressed: () {
          Navigator.of(context).pushNamed(Routes.myComicSearchResultRoute,
              arguments: {"title": record.title});
        },
      ),
      ...alwaysInActions()
    ];
    if (comic18Method.containsKey(record.source)) {
      actions.insert(
          0,
          IconButton(
              icon: const Icon(
                Icons.download,
              ),
              onPressed: () {
                var cloned =
                    ComicInfo.fromJson(jsonDecode(jsonEncode(_comicInfoRes)));
                cloned.chapters = cloned.chapters.reversed.toList();
                Navigator.pushNamed(context, Routes.myDownloadRoute,
                    arguments: {
                      "comicInfo": cloned,
                      "source": record.source,
                      "lazyboxName": ConstantString.comic18DownloadBox,
                    });
              }));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(record.title),
        elevation: 0.0,
        centerTitle: false,
        actions: actions,
      ),
      body: FutureBuilder<ComicInfo>(
        initialData: Hive.box(ConstantString.comicBox)
            .get(Global.comicInfoKey(record.source, record.id)),
        future: _comicInfo,
        builder: (
          BuildContext context,
          AsyncSnapshot<ComicInfo> snapshot,
        ) {
          return Column(children: [
            comicSimpleCard(context, snapshot),
            !comic18Method.containsKey(record.source)
                ? Expanded(child: comicChapterGrid(context, snapshot))
                : Expanded(child: comic18ChapterGrid(context, snapshot)),
          ]);
        },
      ),
      // floatingActionButton: floatingButtonWidget(context),
      // floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  Widget floatingButtonWidget(BuildContext context) {
    ComicSimple record = widget.content["record"];
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      // refresh
      FloatingActionButton(
        onPressed: () {
          refresh(context);
        },
        heroTag: null,
        child: const Icon(
          Icons.refresh,
        ),
      ),
      const SizedBox(
        height: 10,
      ),
      // history
      FloatingActionButton(
        onPressed: () {
          if (_index == null || _comicInfoRes == null) return;
          var cloned =
              ComicInfo.fromJson(jsonDecode(jsonEncode(_comicInfoRes)));
          var seqList = _comicInfoRes!.chapters.reversed.toList();
          cloned.chapters = seqList;
          Navigator.of(context)
              .pushNamed(Routes.myComicReaderRoute, arguments: {
            "chapters": seqList,
            "index": !_reversed ? _length! - 1 - _index! : _index!,
            "source": record.source,
            "comicInfo": cloned,
            "comicSimple": widget.content["record"],
            "reversed": _reversed,
            "reversedIndex": _reversed ? _length! - 1 - _index! : _index!,
          }).whenComplete(() => setState(() {}));
        },
        heroTag: null,
        child: const Icon(Icons.history),
      ),
      const SizedBox(
        height: 10,
      ),
      // favorite
      FloatingActionButton(
        onPressed: () {
          var isFavorite = Provider.of<ComicLocal>(context, listen: false)
              .isFavorite(record);
          isFavorite
              ? Provider.of<ComicLocal>(context, listen: false)
                  .removeFavorite(record)
              : Provider.of<ComicLocal>(context, listen: false)
                  .saveFavorite(record);
        },
        heroTag: null,
        child: Provider.of<ComicLocal>(context, listen: true).isFavorite(record)
            ? const Icon(Icons.favorite)
            : const Icon(Icons.favorite_border),
      ),
      const SizedBox(
        height: 10,
      ),
      // reversed
      FloatingActionButton(
        onPressed: () {
          setState(() {
            _reversed = !_reversed;
            saveReversed(record);
            if (_index != null && _length != null) {
              _index = _length! - 1 - _index!;
              saveIndex(record);
            }
          });
        },
        heroTag: null,
        child: const Icon(
          Icons.swap_vert,
        ),
      ),
      const SizedBox(
        height: 5,
      ),
    ]);
  }

  Widget cacheImg(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      errorWidget: (context, url, error) => const Center(
        child: Icon(
          Icons.error,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget comicSimpleCard(
      BuildContext context, AsyncSnapshot<ComicInfo> snapshot) {
    ComicSimple record = widget.content["record"];
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 5, top: 5),
      decoration: dec,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: cacheImg(record.thumb),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Column(
                // mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    child: Text(
                      record.title,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    onTap: () => Navigator.of(context)
                        .pushNamed(Routes.myComicSearchResultRoute, arguments: {
                      "title": record.title,
                      "source": record.source
                    }),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            child: Text(
                              snapshot.data?.author ?? record.author,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.of(context).pushNamed(
                                Routes.myComicSearchResultRoute,
                                arguments: {
                                  "title":
                                      snapshot.data?.author ?? record.author,
                                  "source": record.source
                                }),
                          ),
                        ),
                        GestureDetector(
                          child: Text(
                            record.sourceName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            if (Routes.routes
                                .containsKey(widget.content["record"].source)) {
                              Navigator.pushNamed(
                                  context, Routes.myComicHomeRoute,
                                  arguments: {
                                    "source": widget.content["record"].source,
                                  });
                            }
                          },
                        )
                      ]),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
                  LimitedBox(
                    maxHeight: 90,
                    child: SingleChildScrollView(
                      child: Text(
                        snapshot.data?.description ?? "",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget comicChapterGrid(
      BuildContext context, AsyncSnapshot<ComicInfo> snapshot) {
    if (snapshot.hasError || !snapshot.hasData) {
      return const MyWaiting();
    }
    _comicInfoRes = snapshot.requireData;
    ComicSimple record = widget.content["record"];
    _length = snapshot.requireData.chapters.length;
    var seqList = snapshot.requireData.chapters.reversed.toList();
    var reversed = _reversed
        ? snapshot.requireData.chapters.reversed.toList()
        : snapshot.requireData.chapters.toList();
    List<Widget> chapters = [];
    for (int index = 0; index < reversed.length; index++) {
      Chapter chapter = reversed[index];
      bool highlight = _index == index;
      chapters.add(OutlinedButton(
          onPressed: () {
            _index = index;
            saveIndex(record);
            var cloned = ComicInfo.fromJson(
                jsonDecode(jsonEncode(snapshot.requireData)));
            cloned.chapters = seqList;
            Navigator.of(context)
                .pushNamed(Routes.myComicReaderRoute, arguments: {
              "chapters": seqList,
              "index": !_reversed ? _length! - 1 - _index! : _index!,
              "source": record.source,
              "comicInfo": cloned,
              "comicSimple": widget.content["record"],
              "reversed": _reversed,
              "reversedIndex": _reversed ? _length! - 1 - _index! : _index!,
            }).whenComplete(() => setState(() {}));
          },
          style: ButtonStyle(
            minimumSize: MaterialStateProperty.all(Size.infinite),
            maximumSize: MaterialStateProperty.all(Size.infinite),
            backgroundColor:
                highlight ? MaterialStateProperty.all(Colors.blue) : null,
            shape: MaterialStateProperty.all(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0))),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Center(
            child: Text(
              chapter.title,
              style: TextStyle(fontSize: 13, color: fontColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          )));
    }

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(10),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 3.5,
              crossAxisSpacing: 15.0,
              mainAxisSpacing: 10.0,
            ),
            delegate: SliverChildListDelegate(chapters),
          ),
        ),
      ]),
      floatingActionButton: floatingButtonWidget(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  Widget comic18ChapterGrid(
      BuildContext context, AsyncSnapshot<ComicInfo> snapshot) {
    if (snapshot.hasError || !snapshot.hasData) {
      return const MyWaiting();
    }
    _comicInfoRes = snapshot.requireData;
    ComicSimple record = widget.content["record"];
    _length = snapshot.requireData.chapters.length;
    var seqList = snapshot.requireData.chapters.reversed.toList();
    var reversed = _reversed
        ? snapshot.requireData.chapters.reversed.toList()
        : snapshot.requireData.chapters.toList();
    List<Widget> chapters = [];
    for (int index = 0; index < reversed.length; index++) {
      Chapter chapter = reversed[index];
      bool highlight = _index == index;
      chapters.add(OutlinedButton(
          onPressed: () {
            _index = index;
            saveIndex(record);
            var cloned = ComicInfo.fromJson(
                jsonDecode(jsonEncode(snapshot.requireData)));
            cloned.chapters = seqList;
            Navigator.of(context)
                .pushNamed(Routes.myComicReaderRoute, arguments: {
              "chapters": seqList,
              "index": !_reversed ? _length! - 1 - _index! : _index!,
              "source": record.source,
              "comicInfo": cloned,
              "comicSimple": widget.content["record"],
              "reversed": _reversed,
              "reversedIndex": _reversed ? _length! - 1 - _index! : _index!,
            }).whenComplete(() => setState(() {}));
          },
          style: ButtonStyle(
            minimumSize: MaterialStateProperty.all(Size.infinite),
            maximumSize: MaterialStateProperty.all(Size.infinite),
            backgroundColor:
                highlight ? MaterialStateProperty.all(Colors.blue) : null,
            shape: MaterialStateProperty.all(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0))),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Center(
            child: Text(
              chapter.title,
              style: TextStyle(fontSize: 13, color: fontColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          )));
    }

    var chaptersWidget = Scaffold(
      body: CustomScrollView(slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              comicMethod.containsKey(widget.content["record"].source)
                  ? Container()
                  : comicTags(context, snapshot),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(5),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 3.5,
              crossAxisSpacing: 15.0,
              mainAxisSpacing: 10.0,
            ),
            delegate: SliverChildListDelegate(chapters),
          ),
        ),
      ]),
      floatingActionButton: floatingButtonWidget(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );

    return DefaultTabController(
      length: tabs.length,
      initialIndex: 0,
      child: Column(children: [
        TabBar(
          labelColor: Colors.black,
          isScrollable: false,
          tabs: tabs.map<Widget>((name) => Tab(text: name)).toList(),
        ),
        Expanded(
          child: TabBarView(
            children: [chaptersWidget, relatedWidget(record.id)],
          ),
        ),
      ]),
    );
  }

  Widget relatedWidget(String id) {
    _comicRelated ??= getRelated(id);
    return FutureBuilder(
        future: _comicRelated,
        builder: (
          BuildContext context,
          AsyncSnapshot snapshot,
        ) {
          if (snapshot.hasError || !snapshot.hasData) {
            return const MyWaiting();
          }
          var data = snapshot.data;
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(top: 5),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5.0,
                  mainAxisSpacing: 5.0,
                  childAspectRatio: 4 / 5,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return MyGridGestureDetector(
                      record: data![index],
                      // setterLatest: onTap,
                      child: ComicSimpleItem(
                        comicSimple: data[index],
                        isList: false,
                      ),
                    );
                  },
                  childCount: data?.length ?? 0,
                ),
              ),
            )
          ]);
        });
  }

  Widget comicTags(BuildContext context, AsyncSnapshot<ComicInfo> snapshot) {
    if (snapshot.hasError || !snapshot.hasData) {
      return Container();
    }
    ComicInfo comicInfo = snapshot.requireData;
    List<Widget> widgets = [];
    for (int i = 0; i < comicInfo.tags!.length; i++) {
      widgets.add(GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, Routes.myComicTagRoute, arguments: {
                "source": widget.content["record"].source,
                "name": comicInfo.tags![i],
                "path": comicInfo.tagsUrl![i],
              }),
          child: Container(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: 3,
              bottom: 3,
            ),
            margin: const EdgeInsets.only(
              top: 3,
              bottom: 3,
            ),
            decoration: BoxDecoration(
              color: Colors.pink.shade100,
              border: Border.all(
                style: BorderStyle.solid,
                color: Colors.pink.shade400,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(30)),
            ),
            child: Text(
              comicInfo.tags![i],
              style: TextStyle(
                color: Colors.pink.shade500,
                height: 1.4,
              ),
              strutStyle: const StrutStyle(
                height: 1.4,
              ),
            ),
          )));
    }
    return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(10),
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 10,
          // runSpacing: 1.0, // gap between lines
          children: widgets,
        ));
  }

  void refresh(BuildContext context) {
    Global.showSnackBar("正在查询最近更新", const Duration(seconds: 1));
    setState(() {
      _comicInfo = loadComicInfo(dur: Duration.zero);
    });
  }

  Future getRelated(String id,
      {Duration dur = const Duration(hours: 12)}) async {
    String source = ConstantString.jmtt;
    var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
    var key = "${id}_related";
    if (MyHive().isInHive(lazyBoxName, key, dur: dur)) {
      return MyHive().getInHive(lazyBoxName, key);
    } else {
      var res = await Jmtt().comicByRelated(id);
      MyHive().putInHive(lazyBoxName, key, res);
      return res;
    }
  }
}
