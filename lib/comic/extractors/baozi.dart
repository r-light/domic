import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

class Baozi extends Parser {
  static Baozi? _instance;
  String domainBase = "https://baozimh.org/";
  String searchBase = "https://baozimh.org/";
  String chapterListBase = "https://api-get.mgsearcher.com/api/manga/get";
  String chapterImageBase =
      "https://api-get.mgsearcher.com/api/chapter/getinfo";

  Baozi._internal() {
    _instance = this;
  }

  factory Baozi() => _instance ?? Baozi._internal();

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
    var doc = parse(content);
    var chapterContent = doc.querySelector("#chapterContent");
    var dataMs = chapterContent?.attributes["data-ms"] ?? "";
    var dataCs = chapterContent?.attributes["data-cs"] ?? "";

    resp = await MyDio().getHtml(RequestOptions(
        path: chapterImageBase,
        method: "GET",
        queryParameters: {"m": dataMs, "c": dataCs},
        headers: {"Referer": "https://m.baozimh.one/"}));

    chapter.images = [];
    try {
      var list = resp.value?.data["data"]["info"]["images"] as List;
      for (var image in list) {
        chapter.images.add(ImageInfo(image["url"])
          ..headers = {"Referer": "https://m.baozimh.one/"});
      }
      // ignore: empty_catches
    } catch (e) {}

    chapter.len = chapter.images.length;
  }

  @override
  Future<ComicInfo> comicById(String id) async {
    var resp = await MyDio().getHtml(RequestOptions(
      baseUrl: domainBase,
      path: id,
      method: "GET",
    ));
    var content = resp.value?.data.toString();
    var doc = parse(content);

    // parse chapter
    var mid = doc.querySelector("#firstchap")?.attributes["data-mid"] ?? "";
    List<Chapter> chapters = [];
    var chapterInfoResp = MyDio()
        .getHtml(
      RequestOptions(
          path: chapterListBase,
          method: "GET",
          queryParameters: {"mid": mid, "mode": "all"},
          headers: {"Referer": "https://m.baozimh.one/"}),
    )
        .then((r) {
      var map = r.value?.data as Map;
      var list = map["data"]["chapters"] as List;
      for (var chapter in list) {
        var title = "", url = "";
        try {
          title = trimAllLF(chapter["attributes"]["title"] ?? "");
          url = "$id/${chapter["attributes"]["slug"]}";
          // ignore: empty_catches
        } catch (e) {}
        chapters.add(Chapter(title, url, 0, []));
        chapters = chapters.reversed.toList();
      }
    });

    var thumb = doc
            .querySelector("#MangaCard")
            ?.querySelector("img")
            ?.attributes["src"] ??
        "";
    if (!thumb.startsWith("http")) {
      thumb = domainBase + thumb;
    }

    var detailList = doc.querySelector("div.block.text-left.mx-auto");

    var title = detailList?.querySelector(".gap-unit-xs>h1")?.text ?? "";
    title = trimAllLF(title);

    var state = ComicState.unknown;

    var author = detailList?.querySelector("a")?.text ?? "";

    var updateDate = "";
    var uploadDate = updateDate;

    var description =
        doc.querySelector("p.text-medium.line-clamp-4.my-unit-md")?.text ?? "";
    description = trimAllLF(description);

    await chapterInfoResp;
    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var resp = await MyDio().getHtml(RequestOptions(
      baseUrl: searchBase,
      path: "/s/$name",
      method: "GET",
    ));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);

    // var respp = await MyDio().getHtml(RequestOptions(
    //   path: "https://go.mgsearcher.com/indexes/mangaStrapiPro/search",
    //   method: "POST",
    //   data: {"q": name, "hitsPerPage": 30, "page": page},
    // ));

    List<ComicSimple> list = [];
    doc
        .querySelector("div.grid-cols-3.cardlist")
        ?.querySelectorAll("div.pb-2")
        .forEach((e) {
      var title = e.querySelector("h3")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["src"] ??
          e.querySelector("img")?.attributes["srcset"] ??
          "";
      if (!thumb.startsWith("http")) {
        thumb = domainBase + thumb;
      }

      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var updateDate = "";
      var source = "baozi";
      var sourceName = sourcesName["baozi"] ?? "";
      var author = "";

      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    var maxPage = doc
            .querySelector(
                "div.flex.justify-between.items-center.mt-5.mb-10>div")
            ?.querySelectorAll("a")
            .last
            .text ??
        "";
    return ComicPageData(int.tryParse(maxPage) ?? 1, list);
  }

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(path: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];

    doc.querySelector("#dropdown")?.querySelectorAll("li").forEach((element) {
      var href = element.firstChild?.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, href));
    });
    return res;
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    var resp = await MyDio().getHtml(
      RequestOptions(
          path: "$path/page/$page", baseUrl: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    List<ComicSimple> list = [];
    doc
        .querySelector("div.grid-cols-3.cardlist")
        ?.querySelectorAll("div.pb-2")
        .forEach((e) {
      var title = e.querySelector("h3")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["src"] ??
          e.querySelector("img")?.attributes["srcset"] ??
          "";
      if (!thumb.startsWith("http")) {
        thumb = domainBase + thumb;
      }

      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var updateDate = "";
      var source = "baozi";
      var sourceName = sourcesName["baozi"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    var maxPage = doc
            .querySelector(
                "div.flex.justify-between.items-center.mt-5.mb-10>div")
            ?.querySelectorAll("a")
            .last
            .text ??
        "";
    return ComicPageData(int.tryParse(maxPage) ?? 1, list);
  }
}
