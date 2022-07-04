import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_comic_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class ComicManagerController {
  Future Function()? download;
  Future Function()? delete;
}

class MyDownloadPage extends StatefulWidget {
  const MyDownloadPage({Key? key, required this.content}) : super(key: key);
  final dynamic content;

  @override
  State<MyDownloadPage> createState() => _MyDownloadPageState();
}

class _MyDownloadPageState extends State<MyDownloadPage> {
  late var box = Hive.lazyBox(widget.content["lazyboxName"]);
  final List<ComicManagerController> controllers = [];
  bool reversed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.content["comicInfo"] == null) {
      return Container();
    }
    ComicInfo comicInfo = widget.content["comicInfo"]!;
    List<Chapter> chapters = widget.content["comicInfo"]!.chapters;
    if (controllers.isEmpty) {
      for (int i = 0; i < chapters.length; i++) {
        controllers.add(ComicManagerController());
      }
    }

    return Scaffold(
        appBar: AppBar(
          title: Text(comicInfo.title),
          elevation: 0.0,
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.swap_vert,
              ),
              onPressed: () => setState(() {
                reversed = !reversed;
              }),
            ),
            IconButton(
              icon: const Icon(
                Icons.done_all,
              ),
              onPressed: () async {
                for (int i = 0; i < controllers.length; i++) {
                  if (controllers[i].download != null) {
                    await controllers[i].download!();
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_sharp,
              ),
              onPressed: () async {
                for (int i = 0; i < controllers.length; i++) {
                  if (controllers[i].delete != null) {
                    await controllers[i].delete!();
                  }
                }
                setState(() {});
              },
            ),
          ],
        ),
        body: ListView.builder(
          itemBuilder: (context, index) {
            if (reversed) {
              index = comicInfo.chapters.length - 1 - index;
            }
            return MyDownloadTile(
              comicInfo: comicInfo,
              source: widget.content["source"],
              lazyBoxName: widget.content["lazyboxName"],
              index: index,
              controller: controllers[index],
            );
          },
          itemCount: chapters.length,
        ));
  }
}

class MyDownloadTile extends StatefulWidget {
  const MyDownloadTile(
      {Key? key,
      required this.comicInfo,
      required this.source,
      required this.lazyBoxName,
      required this.index,
      this.controller})
      : super(key: key);
  final ComicInfo comicInfo;
  final String source;
  final String lazyBoxName;
  final int index;
  final dynamic controller;

  @override
  State<MyDownloadTile> createState() => MyDownloadTileState();
}

class MyDownloadTileState extends State<MyDownloadTile> {
  late var box = Hive.lazyBox(widget.lazyBoxName);
  late var index = widget.index;
  late var comicInfo = widget.comicInfo;
  late var source = widget.source;

  @override
  Widget build(BuildContext context) {
    widget.controller.download ??= loadingJmttImage;
    widget.controller.delete ??= deleteChapter;
    index = widget.index;
    comicInfo = widget.comicInfo;
    return ListTile(
      title: Text(comicInfo.chapters[index].title),
      subtitle: downloadState(),
      trailing: downloadIcon(),
    );
  }

  Widget downloadState() {
    Chapter chapter = comicInfo.chapters[index];
    if (Global.downloading.containsKey(chapter.url)) {
      if (chapter.len == 0) {
        loadImageSrc().whenComplete(() => setState(() {}));
        return const Text("读取中...");
      }
      int cur = min(Global.downloading[chapter.url]!, chapter.len);
      return LinearPercentIndicator(
        percent: cur / chapter.len,
        barRadius: const Radius.circular(16),
        backgroundColor: Colors.grey[300],
        progressColor: Colors.blue,
      );
    } else {
      var downloaded = box.containsKey(chapter.url);
      return downloaded ? const Text("已下载") : const Text("未下载");
    }
  }

  Widget downloadIcon() {
    Chapter chapter = comicInfo.chapters[index];
    var downloaded = box.containsKey(chapter.url);

    return downloaded
        ? IconButton(
            icon: const Icon(
              Icons.delete,
            ),
            onPressed: () async {
              await deleteChapter();
              setState(() {});
            },
          )
        : IconButton(
            icon: const Icon(
              Icons.download,
            ),
            onPressed: () {
              loadingJmttImage();
              setState(() {});
            });
  }

  Future loadImageSrc() async {
    if (comicInfo.chapters[index].images.isNotEmpty) return;
    var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
    var key = Global.comicChapterKey(source, comicInfo.id, index);
    if (MyHive().isInHive(lazyBoxName, key)) {
      comicInfo.chapters[index] = await MyHive().getInHive(lazyBoxName, key);
    } else {
      var parser = comicMethod[source] ?? comic18Method[source]!;
      await parser.comicByChapter(comicInfo, idx: index);
      MyHive().putInHive(lazyBoxName, key, comicInfo.chapters[index]);
    }
  }

  Future loadingJmttImage() async {
    Global.downloading.putIfAbsent(comicInfo.chapters[index].url, () => 0);
    await loadImageSrc();
    Chapter chapter = comicInfo.chapters[index];
    List<Future> futures = [];
    if (chapter.aid! < chapter.scrambleId!) {
      for (int i = 0; i < chapter.len; i++) {
        String url = chapter.images[i].src;
        if (box.containsKey(url)) {
          continue;
        }
        futures.add(
            NetworkAssetBundle(Uri.parse(url)).load(url).then((bytes) async {
          await box.put(url, bytes.buffer.asUint8List());
          setState(() {
            Global.downloading[chapter.url] =
                Global.downloading[chapter.url]! + 1;
          });
        }));
      }
    } else {
      var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
      for (int i = 0; i < chapter.len; i++) {
        var key = chapter.images[i].src;
        if (box.containsKey(key)) {
          continue;
        }
        if (MyHive().isInHive(lazyBoxName, key)) {
          futures.add(MyHive().getInHive(lazyBoxName, key).then((res) async {
            await box.put(key, res["data"]);
            setState(() {
              Global.downloading[chapter.url] =
                  Global.downloading[chapter.url]! + 1;
            });
          }));
        } else {
          futures.add(() async {
            var resp = await MyDio().dio.get<List<int>>(key,
                options: Options(responseType: ResponseType.bytes));
            var bytes = resp.data;
            if (bytes == null) {
              await box.put(key, Uint8List(0));
              return;
            }
            Map<String, dynamic> params = {};
            params["src"] = key;
            params["bytes"] = bytes;
            params["aid"] = chapter.aid!;
            params["pid"] = chapter.images[i].pid;
            var res = await compute(convertJmttHelper, params);
            MyHive().putInHive(lazyBoxName, key, res);
            await box.put(key, res["data"]);
            setState(() {
              Global.downloading[chapter.url] =
                  Global.downloading[chapter.url]! + 1;
            });
          }());
        }
      }
    }
    await Future.wait(futures);
    var finish = await downloadCompleted();
    if (finish) {
      setState(() {});
    }
  }

  Future<bool> downloadCompleted() async {
    Chapter chapter = comicInfo.chapters[index];
    bool res = true;
    if (box.containsKey(chapter.url) ||
        Global.downloading[chapter.url] == chapter.len) {
      await box.put(chapter.url, res);
      Global.downloading.remove(chapter.url);
      return res;
    }
    for (int i = 0; i < chapter.images.length; i++) {
      if (!box.containsKey(chapter.images[i].src)) {
        res = false;
        break;
      }
    }
    if (res) {
      await box.put(chapter.url, res);
      Global.downloading.remove(chapter.url);
    }
    return res;
  }

  Future deleteChapter() async {
    Chapter chapter = comicInfo.chapters[index];
    await box.delete(chapter.url);
    await loadImageSrc();
    chapter = comicInfo.chapters[index];
    for (int i = 0; i < chapter.images.length; i++) {
      box.delete(chapter.images[i].src);
    }
  }
}
