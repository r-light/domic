import 'dart:math';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

class Bainian extends Parser {
  static Bainian? _instance;
  String domainBase = "https://bnman.net/";
  String searchBase = "https://bnman.net/search/";

  Bainian._internal() {
    _instance = this;
  }

  factory Bainian() => _instance ?? Bainian._internal();

  @override
  comicByChapter(ComicInfo comicInfo, {int idx = 0}) async {
    if (idx >= comicInfo.chapters.length) return;
    var chapter = comicInfo.chapters[idx];
    var resp = await MyDio().getHtml(RequestOptions(
      path: chapter.url,
      baseUrl: domainBase,
      method: "GET",
    ));

    var content = resp.value?.data.toString() ?? "";
    // parse chapterImages
    RegExp reg = RegExp(r"z_img\s*=\s*([\s\S]*?);");
    var match = reg.firstMatch(content);
    List<String> chapterImages = [];
    if (match != null) {
      var tmp = match.group(1)!;
      chapterImages = tmp.substring(2, tmp.length - 2).split(",");
      for (int i = 0; i < chapterImages.length; i++) {
        tmp = trimAllLF(chapterImages[i]);
        chapterImages[i] = tmp.substring(1, tmp.length - 1);
      }
    }
    chapter.len = chapterImages.length;
    chapter.images = [];
    for (int i = 0; i < chapterImages.length; i++) {
      if (chapterImages[i].startsWith("https")) {
        chapter.images.add(ImageInfo(chapterImages[i]));
      } else {
        chapter.images
            .add(ImageInfo('https://img.hngxgt.net/${chapterImages[i]}'));
      }
    }
  }

  @override
  Future<ComicInfo> comicById(String id) async {
    var resp = await MyDio().getHtml(RequestOptions(
      path: id,
      method: "GET",
      baseUrl: domainBase,
    ));
    var content = resp.value?.data.toString();
    var doc = parse(content);
    var detailList = doc.querySelector(".info.l>ul")?.children ?? [];
    var title = detailList.isNotEmpty ? detailList[0].text : "";
    title = trimAllLF(title);
    var state = ComicState.unknown;

    var author = "";
    if (detailList.length >= 4) {
      author = detailList[3].querySelector("p")?.text ?? "";
    }
    var thumb = doc.querySelector(".bpic.l>img")?.attributes["src"] ?? "";
    var updateDate = detailList.last.querySelector("p")?.text ?? "";
    var uploadDate = updateDate;

    var description = doc.querySelector(".box01.l>.mt10")?.text ?? "";
    List<Chapter> chapters = [];
    int idx = 0;
    // parse chapter
    doc.querySelector(".box01>.jslist01")?.querySelectorAll("li").forEach((e) {
      if (idx++ == 0) return;
      var title = e.text;
      title = trimAllLF(title);
      var url = e.children[0].attributes["href"] ?? "";
      chapters.add(Chapter(title, url, 0, []));
    });
    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var resp = await MyDio().getHtml(RequestOptions(
      path: "$searchBase$name/$page.html",
      method: "GET",
    ));
    return parsePageHelper(resp);
  }

  ComicPageData parsePageHelper(MapEntry<int, Response<dynamic>?> resp) {
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    // parse page
    var pageCount = 1;
    doc.querySelector(".pagination")?.querySelectorAll("li").forEach((element) {
      pageCount = max(pageCount, int.tryParse(trimAllLF(element.text)) ?? 1);
    });
    List<ComicSimple> list = [];
    doc.querySelector("#list_img")?.querySelectorAll("li").forEach((e) {
      var title = e.querySelector("p")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["src"] ?? "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var updateDate = e.querySelector("em")?.text ?? "";
      updateDate = trimAllLF(updateDate);

      var source = "bainian";
      var sourceName = sourcesName["bainian"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    return ComicPageData(pageCount, list);
  }

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(path: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];
    doc.querySelectorAll(".warp>ul>li").forEach((element) {
      var href = element.firstChild?.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, href));
    });

    return res.sublist(1);
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    var resp = await MyDio().getHtml(
      RequestOptions(path: path, baseUrl: domainBase, method: "GET"),
    );
    return parsePageHelper(resp);
  }
}
