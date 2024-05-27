import 'dart:core';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';
import 'package:html_unescape/html_unescape.dart';

class Baozi extends Parser implements ParserWebview {
  static Baozi? _instance;
  String domainBase = "https://m.baozimh.one/";
  String searchBase = "https://m.baozimh.one/";
  String chapterListBase = "https://m.baozimh.one/chapterlist/";
  var unescape = HtmlUnescape();
  final Pattern unicodePattern = RegExp(r'\\u([0-9A-Fa-f]{4})');

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
    chapter.images = [];
    doc
        .querySelector("div.touch-manipulation")
        ?.querySelectorAll("img")
        .forEach((e) {
      chapter.images.add(
          ImageInfo(e.attributes['data-src'] ?? e.attributes["src"] ?? ""));
    });
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
    List<Chapter> chapters = [];

    resp = await MyDio().getHtml(RequestOptions(
      baseUrl: chapterListBase,
      path: id.split("/").last,
      method: "GET",
    ));

    content = resp.value?.data.toString();
    doc = parse(content);
    // parse chapter
    doc
        .querySelector("#chapterlists")
        ?.querySelectorAll("div.chapteritem")
        .forEach((e) {
      var title = e.querySelector("span.chaptertitle")?.text ?? "";
      title = trimAllLF(title);
      var url = e.querySelector("a")?.attributes["href"] ?? "";
      chapters.add(Chapter(title, url, 0, []));
    });
    chapters = chapters.reversed.toList();
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

  @override
  comicByChapterWebview(ComicInfo comicInfo, Map<String, dynamic> map,
      {int idx = 0}) {
    String content = map["content"];
    var html = content
        .replaceAllMapped(unicodePattern, (Match unicodeMatch) {
          final int hexCode = int.parse(unicodeMatch.group(1)!, radix: 16);
          final unicode = String.fromCharCode(hexCode);
          return unicode;
        })
        .replaceAll("\\n", "")
        .replaceAll("\\", "");
    var doc = parse(html);
    var chapter = comicInfo.chapters[idx];
    chapter.images = [];
    doc.querySelector("#chapcontent")?.querySelectorAll("img").forEach((e) {
      if (e.attributes["alt"] != null) {
        chapter.images.add(
            ImageInfo(e.attributes['data-src'] ?? e.attributes["src"] ?? ""));
      }
    });
    chapter.len = chapter.images.length;
  }

  @override
  Future<ComicInfo> comicByIdWebview(Map<String, dynamic> map) async {
    String content = map["content"];
    ComicSimple comicSimple = map["record"];
    String id = map["url"];

    var html = content
        .replaceAllMapped(unicodePattern, (Match unicodeMatch) {
          final int hexCode = int.parse(unicodeMatch.group(1)!, radix: 16);
          final unicode = String.fromCharCode(hexCode);
          return unicode;
        })
        .replaceAll("\\n", "")
        .replaceAll("\\", "");
    var doc = parse(html);

    var thumb = comicSimple.thumb;
    if (!thumb.startsWith("http")) {
      thumb = domainBase + thumb;
    }

    var title = comicSimple.title;
    title = trimAllLF(title);

    var state = ComicState.unknown;

    var author = comicSimple.author;

    var updateDate = "";
    var uploadDate = updateDate;

    var description = "";
    description = trimAllLF(description);
    List<Chapter> chapters = [];
    // parse chapter
    doc
        .querySelector("#sortchapters")
        ?.querySelectorAll("div.chapteritem")
        .forEach((e) {
      var title = e.querySelector("span.chaptertitle")?.text ?? "";
      title = trimAllLF(title);
      var url = e.querySelector("a")?.attributes["href"] ?? "";
      chapters.add(Chapter(title, url, 0, []));
    });
    chapters = chapters.toList();
    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByNameWebview(String name, int page) {
    // TODO: implement comicByNameWebview
    throw UnimplementedError();
  }

  @override
  String parseChapterUrl(String id) {
    if (domainBase.endsWith("/") && id.startsWith("/")) {
      return domainBase + id.substring(1);
    } else {
      return domainBase + id;
    }
  }

  @override
  String parseComicInfoUrl(String id) {
    return Baozi().chapterListBase + id.split("/").last;
  }

  @override
  Map<String, String>? getHeader() {
    return const {"Referer": "https://m.baozimh.one/"};
  }
}
