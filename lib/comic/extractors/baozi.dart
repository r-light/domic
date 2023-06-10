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
        .querySelector(".entry-content")
        ?.firstChild
        ?.firstChild
        ?.children[3]
        .querySelectorAll("img")
        .forEach((e) {
      chapter.images.add(
          ImageInfo(e.attributes['data-src'] ?? e.attributes["src"] ?? ""));
    });
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

    var thumb = doc
            .querySelector(".gb-grid-wrapper")
            ?.children
            .first
            .querySelector("img")
            ?.attributes["src"] ??
        "";

    var detailList = doc
        .querySelector(".gb-grid-wrapper")
        ?.children
        .last
        .querySelector("div.gb-inside-container");

    var title = detailList?.querySelector("h1")?.text ?? "";
    title = trimAllLF(title);

    var state = ComicState.unknown;
    var stateText =
        detailList?.querySelectorAll(".author-content").last.text ?? "";
    if (stateText.isNotEmpty) {
      if (stateText.contains("连载中")) {
        state = ComicState.ongoing;
      } else if (stateText.contains("已完结")) {
        state = ComicState.completed;
      }
    }

    var author = "";
    detailList
        ?.querySelectorAll(".author-content")
        .first
        .querySelectorAll("a")
        .forEach((element) {
      author += element.text;
      author += ",";
    });

    if (author.isNotEmpty) {
      author = author.substring(0, author.length - 1);
    }

    var updateDate = "";
    var uploadDate = updateDate;

    var description = doc.querySelector(".dynamic-entry-content")?.text ?? "";
    description = trimAllLF(description);
    List<Chapter> chapters = [];

    var chapterListUrl = doc
        .querySelector(".listing-chapters_wrap")
        ?.querySelectorAll("a")
        .last
        .attributes["href"];

    resp = await MyDio().getHtml(RequestOptions(
      path: chapterListUrl!,
      method: "GET",
    ));

    content = resp.value?.data.toString();
    doc = parse(content);
    // parse chapter
    doc
        .querySelector(".main.version-chaps")
        ?.querySelectorAll("a")
        .forEach((e) {
      var title = e.text;
      updateDate = e.querySelector("span")?.text ?? "";
      title = title.substring(0, title.length - updateDate.length - 1);
      title = trimAllLF(title);
      var url = e.attributes["href"] ?? "";
      chapters.add(Chapter(title, url, 0, []));
    });

    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var params = {
      "s": name,
    };
    var resp = await MyDio().getHtml(RequestOptions(
      path: searchBase,
      method: "GET",
      queryParameters: params,
    ));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    // parse page
    var pageCount = 1;

    List<ComicSimple> list = [];
    doc
        .querySelector(".generate-columns-container")
        ?.querySelectorAll("article")
        .forEach((e) {
      var title = e.querySelector("h2")?.text ?? "";
      title = trimAllLF(title);

      var thumb = e.querySelector("img")?.attributes["data-src"] ??
          e.querySelector("img")?.attributes["src"] ??
          "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var updateDate = "";
      var source = "baozi";
      var sourceName = sourcesName["baozi"] ?? "";
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

    doc
        .querySelector("#primary-menu.main-nav>ul")
        ?.querySelectorAll("li")
        .forEach((element) {
      var href = element.firstChild?.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, href));
    });
    return res.sublist(1, res.length - 1);
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    var resp = await MyDio().getHtml(
      RequestOptions(
          path: "${path}page/$page", baseUrl: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    List<ComicSimple> list = [];
    doc
        .querySelector("div.generate-columns-container")
        ?.querySelectorAll("div.gb-inside-container")
        .forEach((e) {
      var title = e.querySelector("h2")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["data-src"] ??
          e.querySelector("img")?.attributes["src"] ??
          "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";
      var child = e.querySelector(".updateon")?.clone(true);
      child?.querySelector(":nth-child(1)")?.remove();

      var updateDate = "";
      var source = "baozi";
      var sourceName = sourcesName["baozi"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    var maxPage = doc
            .querySelector("nav.ct-pagination>div")
            ?.querySelectorAll("a")
            .last
            .text ??
        "";
    var pageCount = "";
    if (maxPage.isNotEmpty) {
      for (int i = 0; i < maxPage.length; i++) {
        if (maxPage[i].contains(RegExp(r'[0-9]'))) {
          pageCount += maxPage[i];
        }
      }
    }
    return ComicPageData(int.tryParse(pageCount) ?? 1, list);
  }
}
