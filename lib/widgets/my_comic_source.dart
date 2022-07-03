import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/global.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';

class MyComicSource extends StatefulWidget {
  const MyComicSource({Key? key}) : super(key: key);

  @override
  State<MyComicSource> createState() => _MyComicSourceState();
}

class _MyComicSourceState extends State<MyComicSource> {
  int _currentIndex = 0;
  final tabs = ["常规", "18+"];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: DefaultTabController(
            initialIndex: 0,
            length: tabs.length,
            child: Scaffold(
              appBar: AppBar(
                title: const Text(
                  "图源",
                ),
                centerTitle: false,
                actions: [
                  // select all sources
                  IconButton(
                    onPressed: () => tabs[_currentIndex] == "常规"
                        ? Provider.of<ComicSource>(context, listen: false)
                            .sourceMap
                            .keys
                            .forEach((source) {
                            Provider.of<ComicSource>(context, listen: false)
                                .reverseSourceOrDefault(source, active: true);
                          })
                        : Provider.of<ComicSource>(context, listen: false)
                            .source18Map
                            .keys
                            .forEach((source) {
                            Provider.of<ComicSource>(context, listen: false)
                                .reverseSource18OrDefault(source, active: true);
                          }),
                    icon: const Icon(
                      Icons.done_all,
                    ),
                  ),
                  IconButton(
                    onPressed: () => tabs[_currentIndex] == "常规"
                        ? Provider.of<ComicSource>(context, listen: false)
                            .sourceMap
                            .keys
                            .forEach((source) {
                            Provider.of<ComicSource>(context, listen: false)
                                .reverseSourceOrDefault(source, active: false);
                          })
                        : Provider.of<ComicSource>(context, listen: false)
                            .source18Map
                            .keys
                            .forEach((source) {
                            Provider.of<ComicSource>(context, listen: false)
                                .reverseSource18OrDefault(source,
                                    active: false);
                          }),
                    icon: const Icon(
                      Icons.remove_done,
                    ),
                  ),
                  // save sources
                  IconButton(
                    onPressed: () =>
                        Provider.of<ComicSource>(context, listen: false).save(),
                    icon: const Icon(
                      Icons.save,
                    ),
                  ),
                  // test all sources
                  IconButton(
                      onPressed: () => checkSource(context),
                      icon: const Icon(Icons.checklist)),
                ],
                bottom: TabBar(
                  isScrollable: false,
                  tabs: tabs.map<Widget>((e) => Tab(text: e)).toList(),
                ),
              ),
              body: TabBarView(
                children: tabs
                    .asMap()
                    .map((k, v) => MapEntry(
                        k,
                        MySourceLayout(
                          name: v,
                          setter: setCurrentIndex,
                          tabIndex: k,
                        )))
                    .values
                    .toList(),
              ),
            )),
        onWillPop: () async {
          Provider.of<ComicSource>(context, listen: false).save();
          return true;
        });
  }

  void setCurrentIndex(int idx) {
    _currentIndex = idx;
  }

  void checkSource(BuildContext context) async {
    var map = tabs[_currentIndex] == "常规"
        ? Provider.of<ComicSource>(context, listen: false).sourceMap
        : Provider.of<ComicSource>(context, listen: false).source18Map;
    var setter = tabs[_currentIndex] == "常规"
        ? Provider.of<ComicSource>(context, listen: false)
            .reverseSourceOrDefault
        : Provider.of<ComicSource>(context, listen: false)
            .reverseSource18OrDefault;

    EasyLoading.showInfo("测试中");
    List<Future<bool>> futures = [];
    for (var source in map.keys) {
      futures.add(checkSourceHelper(source));
    }
    var active = await Future.wait(futures);
    EasyLoading.showSuccess("测试完成", dismissOnTap: true);
    int idx = 0;
    map.keys.forEach(((e) {
      setter(e, active: active[idx]);
      idx++;
    }));
  }

  Future<bool> checkSourceHelper(String source) async {
    var parser = comicMethod[source] ?? comic18Method[source]!;
    String name = comicMethod.containsKey(source) ? "一人之下" : "继母的朋友们";
    try {
      var pageData = await parser.comicByName(name, 1);
      if (pageData.records.isEmpty) {
        return false;
      }
      var comicInfo = await parser.comicById(pageData.records.first.id);
      if (comicInfo.chapters.isEmpty) {
        return false;
      }
      await parser.comicByChapter(comicInfo, idx: 0);
      if (comicInfo.chapters[0].len == 0) {
        return false;
      }
      var resp = await MyDio().dio.get(comicInfo.chapters[0].images[0].src);
      if (resp.statusCode != 200) {
        return false;
      }
    } catch (e) {
      return false;
    }
    return true;
  }
}

class MySourceLayout extends StatefulWidget {
  const MySourceLayout(
      {Key? key,
      required this.name,
      required this.setter,
      required this.tabIndex})
      : super(key: key);
  final String name;
  final int tabIndex;
  final ValueSetter<int> setter;
  @override
  State<StatefulWidget> createState() => MySourceLayoutState();
}

class MySourceLayoutState extends State<MySourceLayout> {
  final double crossAxisSpacing = 8;
  final double childAspectRatio = 4.0;
  final int crossAxisCount = 2;
  final double edgeInsets = 5;

  @override
  Widget build(BuildContext context) {
    var idx = widget.tabIndex;
    widget.setter(idx);
    Map<String, bool> sourceMap = idx == 0
        ? Provider.of<ComicSource>(context, listen: true).sourceMap
        : Provider.of<ComicSource>(context, listen: true).source18Map;
    var func = idx == 0
        ? Provider.of<ComicSource>(context, listen: false)
            .reverseSourceOrDefault
        : Provider.of<ComicSource>(context, listen: false)
            .reverseSource18OrDefault;
    // select compares it with previous value, but previous object always equals to `new` object.
    // Map<String, bool> sourceMap = context.select((ComicSource s) => s.sourceMap);

    var sources = sourceMap.keys.toList();
    return GridView.builder(
      padding: EdgeInsets.all(edgeInsets),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: edgeInsets),
      itemBuilder: (context, index) {
        String source = sources[index];
        return ListTile(
          title: Text(sourcesName[source]!),
          trailing: IconButton(
            icon: getCurrentIcon(sourceMap[source]!),
            onPressed: () {
              func(source);
            },
          ),
        );
      },
      itemCount: sources.length,
    );
  }

  Widget getCurrentIcon(bool active) {
    return active
        ? const Icon(
            Icons.toggle_on,
            color: Colors.blue,
          )
        : const Icon(
            Icons.toggle_off,
          );
  }
}
