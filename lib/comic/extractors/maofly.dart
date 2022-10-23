import 'dart:math';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';
import 'package:lzstring/lzstring.dart';

class MaoFly extends Parser {
  static MaoFly? _instance;
  String domainBase = "https://www.maofly.com/";
  String searchBase = "https://www.maofly.com/search.html";
  String imgBase = "https://mao.mhtupian.com/uploads/";

  MaoFly._internal() {
    _instance = this;
  }

  factory MaoFly() => _instance ?? MaoFly._internal();

  @override
  comicByChapter(ComicInfo comicInfo, {int idx = 0}) async {
    if (idx >= comicInfo.chapters.length) return;
    var chapter = comicInfo.chapters[idx];
    var resp = await MyDio().getHtml(RequestOptions(
      path: chapter.url,
      method: "GET",
    ));

    var content = resp.value?.data.toString() ?? "";
    // parse chapterImages
    RegExp reg = RegExp(r'let img_data = "(.*?)"');
    var match = reg.firstMatch(content);
    if (match != null) {
      var tmp = match.group(1)!;
      LZString.decompressFromBase64Sync(tmp)?.split(",").forEach((element) {
        chapter.images.add(ImageInfo(imgBase + element));
      });
    }
    chapter.len = chapter.images.length;
  }

  @override
  Future<ComicInfo> comicById(String id) async {
    var resp = await MyDio().getHtml(RequestOptions(
      path: id,
      method: "GET",
    ));
    var content = resp.value?.data.toString();
    var doc = parse(content);

    var detailList =
        doc.querySelector(".comic-meta-data-table")?.querySelectorAll("tr") ??
            [];
    var state = ComicState.unknown;
    var title = "", author = "", thumb = "", updateDate = "";

    if (detailList.isNotEmpty) {
      title = detailList[0].querySelector(".comic-titles")?.text ?? "";
      title = trimAllLF(title);
      state = ComicState.unknown;
      if (detailList[3].children.last.text.contains("连载")) {
        state = ComicState.ongoing;
      }
      if (detailList[3].children.last.text.contains("完结")) {
        state = ComicState.completed;
      }

      author = trimAllLF(detailList[detailList.length - 2].children.last.text);
      thumb = detailList[2].querySelector("img")?.attributes["src"] ?? "";
      updateDate = detailList.last.children.last.text;
      var list = updateDate.split(" ");
      if (list.length > 2) {
        updateDate = list[1];
      } else {
        updateDate = list[0];
      }
    }
    var uploadDate = updateDate;

    var description = doc.querySelector(".comic_story")?.text ?? "";
    description = trimAllLF(description);

    List<Chapter> chapters = [];
    // parse chapter
    doc.querySelector("#comic-book-list")?.children.forEach((panel) {
      panel.querySelectorAll("li").forEach((chapter) {
        var title = chapter.text;
        title = trimAllLF(title);
        var url = chapter.querySelector("a")?.attributes["href"] ?? "";
        chapters.add(Chapter(title, url, 0, []));
      });
    });
    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var resp = await MyDio().getHtml(RequestOptions(
        path: searchBase,
        method: "GET",
        queryParameters: {"q": name, "page": page}));
    return parsePageHelper(resp);
  }

  ComicPageData parsePageHelper(MapEntry<int, Response<dynamic>?> resp) {
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    // parse page
    var pageCount = 1;
    doc.querySelector(".pagination")?.querySelectorAll("a").forEach((element) {
      pageCount = max(pageCount, int.tryParse(trimAllLF(element.text)) ?? 1);
    });

    List<ComicSimple> list = [];
    doc.querySelectorAll(".comicbook-index").forEach((e) {
      var title = e.querySelector(".one-line")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["data-original"] ??
          e.querySelector("img")?.attributes["src"] ??
          "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var updateDate = "";
      var source = "maofly";
      var sourceName = sourcesName["maofly"] ?? "";
      var author = trimAllLF(e.querySelector(".comic-author")?.text ?? "");

      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    int? maxNum;
    doc.querySelector(".text-muted")?.text.split(" ").forEach(
      (element) {
        maxNum ??= int.tryParse(element);
      },
    );
    return ComicPageData(pageCount, list, maxNum: maxNum);
  }
}
