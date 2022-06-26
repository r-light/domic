import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/global.dart';
import 'package:flutter/material.dart';
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
                  IconButton(
                    onPressed: () =>
                        Provider.of<ComicSource>(context, listen: false).save(),
                    icon: const Icon(
                      Icons.save,
                    ),
                  )
                ],
                bottom: TabBar(
                  isScrollable: false,
                  tabs: tabs.map<Widget>((e) => Tab(text: e)).toList(),
                ),
              ),
              body: TabBarView(
                children: tabs.map((e) {
                  return MySourceLayout(
                    name: e,
                    setter: setCurrentIndex,
                  );
                }).toList(),
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
}

class MySourceLayout extends StatefulWidget {
  const MySourceLayout({Key? key, required this.name, required this.setter})
      : super(key: key);
  final String name;
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
    var idx = DefaultTabController.of(context)?.index ?? 0;
    widget.setter(idx);
    Map<String, bool> sourceMap = idx == 0
        ? context.watch<ComicSource>().sourceMap
        : context.watch<ComicSource>().source18Map;
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
