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

class MyDownloadPage extends StatefulWidget {
  const MyDownloadPage({Key? key, required this.content}) : super(key: key);
  final dynamic content;

  @override
  State<MyDownloadPage> createState() => _MyDownloadPageState();
}

class _MyDownloadPageState extends State<MyDownloadPage> {
  late var box = Hive.lazyBox(widget.content["lazyboxName"]);
  bool reversed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.content["comicInfo"] == null) {
      return Container();
    }
    ComicInfo comicInfo = widget.content["comicInfo"]!;
    List<Chapter> chapters = widget.content["comicInfo"]!.chapters;

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
                comicInfo.chapters = comicInfo.chapters.reversed.toList();
              }),
            ),
            IconButton(
              icon: const Icon(
                Icons.done_all,
              ),
              onPressed: () {
                for (int i = 0; i < chapters.length; i++) {
                  var chapter = chapters[i];
                  var downloaded = box.containsKey(chapter.url);
                  if (downloaded) continue;
                  if (Global.downloading.containsKey(chapter.url)) continue;
                  Global.downloading.putIfAbsent(chapter.url, () => 0);
                  loadEpisode(i).whenComplete(
                      () => loadingJmttImage(comicInfo.chapters[i]));
                }
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_sharp,
              ),
              onPressed: () {
                for (int i = 0; i < chapters.length; i++) {
                  Global.downloading.remove(chapters[i].url);
                  box.delete(chapters[i].url);
                  loadEpisode(i).whenComplete(() {
                    for (int j = 0; j < chapters[i].len; j++) {
                      box.delete(chapters[i].images[j].src);
                    }
                  });
                }
                setState(() {});
              },
            ),
          ],
        ),
        body: ListView.builder(
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(chapters[index].title),
              subtitle: downloadState(chapters[index], index),
              trailing: downloadIcon(chapters[index], index),
            );
          },
          itemCount: chapters.length,
        ));
  }

  Widget downloadState(Chapter chapter, int index) {
    if (Global.downloading.containsKey(chapter.url)) {
      if (chapter.len == 0) {
        loadEpisode(index).whenComplete(() => setState(() {}));
        return const Text("读取中...");
      }
      return LinearPercentIndicator(
        percent: Global.downloading[chapter.url]! / chapter.len,
        barRadius: const Radius.circular(16),
        backgroundColor: Colors.grey[300],
        progressColor: Colors.blue,
      );
    } else {
      var downloaded = box.containsKey(chapter.url);
      return downloaded ? const Text("已下载") : const Text("未下载");
    }
  }

  Widget downloadIcon(Chapter chapter, int index) {
    var downloaded = box.containsKey(chapter.url);
    ComicInfo comicInfo = widget.content["comicInfo"]!;

    return downloaded
        ? IconButton(
            icon: const Icon(
              Icons.delete,
            ),
            onPressed: () => setState(() {
              box.delete(chapter.url);
              loadEpisode(index).whenComplete(() {
                for (int i = 0; i < chapter.len; i++) {
                  box.delete(chapter.images[i].src);
                }
              });
            }),
          )
        : IconButton(
            icon: const Icon(
              Icons.download,
            ),
            onPressed: () {
              setState(() {
                Global.downloading.putIfAbsent(chapter.url, () => 0);
                loadEpisode(index).whenComplete(
                    () => loadingJmttImage(comicInfo.chapters[index]));
              });
            });
  }

  Future loadEpisode(int idx) async {
    ComicInfo comicInfo = widget.content["comicInfo"]!;
    String source = widget.content["source"];
    var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
    if (reversed) {
      idx = comicInfo.chapters.length - 1 - idx;
    }
    var key = Global.comicChapterKey(source, comicInfo.id, idx);
    if (MyHive().isInHive(lazyBoxName, key)) {
      comicInfo.chapters[idx] = await MyHive().getInHive(lazyBoxName, key);
    } else {
      var parser = comicMethod[source] ?? comic18Method[source]!;
      await parser.comicByChapter(comicInfo, idx: idx);
      MyHive().putInHive(lazyBoxName, key, comicInfo.chapters[idx]);
    }
  }

  void loadingJmttImage(Chapter chapter) async {
    if (chapter.aid! < chapter.scrambleId!) {
      for (int i = 0; i < chapter.len; i++) {
        String url = chapter.images[i].src;
        if (box.containsKey(url)) {
          continue;
        }
        NetworkAssetBundle(Uri.parse(url)).load(url).then((bytes) {
          setState(() {
            box.put(url, bytes.buffer.asUint8List());
            Global.downloading[chapter.url] =
                Global.downloading[chapter.url]! + 1;
            downloadCompleted(chapter);
          });
        });
      }
    } else {
      String source = widget.content["source"];
      var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
      for (int i = 0; i < chapter.len; i++) {
        var key = chapter.images[i].src;
        if (box.containsKey(key)) {
          continue;
        }
        if (MyHive().isInHive(lazyBoxName, key)) {
          MyHive().getInHive(lazyBoxName, key).then((res) => setState(() {
                box.put(key, res["data"]);
                Global.downloading[chapter.url] =
                    Global.downloading[chapter.url]! + 1;
              }));
        } else {
          var resp = await MyDio().dio.get<List<int>>(key,
              options: Options(responseType: ResponseType.bytes));
          var bytes = resp.data;
          if (bytes == null) {
            box.put(key, Uint8List(0));
          }
          Map<String, dynamic> params = {};
          params["src"] = key;
          params["bytes"] = bytes;
          params["aid"] = chapter.aid!;
          params["pid"] = chapter.images[i].pid;
          compute(convertJmttHelper, params).then(
            (res) {
              MyHive().putInHive(lazyBoxName, key, res);
              setState(() {
                box.put(key, res["data"]);
                Global.downloading[chapter.url] =
                    Global.downloading[chapter.url]! + 1;
                downloadCompleted(chapter);
              });
            },
          );
        }
      }
    }
    downloadCompleted(chapter);
  }

  bool downloadCompleted(Chapter chapter) {
    if (box.containsKey(chapter.url) ||
        Global.downloading[chapter.url] == chapter.len) {
      box.put(chapter.url, true);
      Global.downloading.remove(chapter.url);
      return true;
    }
    return false;
  }
}
