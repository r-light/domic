import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

class Gufeng extends Parser {
  static Gufeng? _instance;
  String domainBase = "https://www.gufengmh.com/";
  String searchBase = "https://www.gufengmh.com/search/";

  Gufeng._internal() {
    _instance = this;
  }

  factory Gufeng() => _instance ?? Gufeng._internal();

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
    RegExp reg = RegExp(r'chapterImages\s*=\s*\[([\s\S]*?)\]');
    var match = reg.firstMatch(content);
    List<String> chapterImages = [];
    if (match != null) {
      chapterImages = match.group(1)!.split(",");
      for (int i = 0; i < chapterImages.length; i++) {
        var tmp = trimAllLF(chapterImages[i]);
        chapterImages[i] = tmp.substring(1, tmp.length - 1);
      }
    }
    // parse chapterPath
    reg = RegExp(r'chapterPath\s*=\s*"([\s\S]*?)"');
    match = reg.firstMatch(content);
    var chapterPath = match?.group(1) ?? "";
    chapterPath = chapterPath.replaceFirst(r'/(^\/*)|(\/*$)/g', "");

    // parse chapterPath
    reg = RegExp(r'pageImage\s*=\s*"([\s\S]*?)"');
    match = reg.firstMatch(content);
    var domain = match?.group(1) ?? "";
    reg = RegExp(r'([\s\S]*?com|[\s\S]*?cn)');
    match = reg.firstMatch(domain);
    domain = match?.group(1) ?? "";
    domain = domain.replaceFirst(r'/(^\/*)|(\/*$)/g', "");

    chapter.len = chapterImages.length;
    chapter.images = [];
    for (int i = 0; i < chapterImages.length; i++) {
      if (chapterImages[i].startsWith("https")) {
        chapter.images.add(ImageInfo(chapterImages[i]));
      } else {
        chapter.images
            .add(ImageInfo("$domain/$chapterPath/${chapterImages[i]}"));
      }
    }
  }

  @override
  Future<ComicInfo> comicById(String id) async {
    var resp = await MyDio().getHtml(RequestOptions(
      path: id,
      method: "GET",
    ));
    var content = resp.value?.data.toString();
    var doc = parse(content);
    var title = doc.querySelector(".book-title>h1")?.text ?? "";
    title = trimAllLF(title);
    var detailList = doc.querySelector(".detail-list")?.children ?? [];
    var state = ComicState.unknown;
    if (detailList.isNotEmpty) {
      var text = detailList[0].querySelector("a")?.text ?? "";
      if (text == "连载中") {
        state = ComicState.ongoing;
      }
      if (text == "已完结") {
        state = ComicState.completed;
      }
    }
    var author = "";
    if (detailList.length > 1) {
      author = detailList[1].children.last.children.last.text;
    }
    var thumb =
        doc.querySelector(".book-cover>.cover>img")?.attributes["src"] ?? "";

    var updateDate = "";
    if (detailList.length > 2) {
      var clone = detailList[2].querySelector("sj")?.clone(true);
      clone?.querySelector("strong")?.remove();
      updateDate = clone?.text ?? "";
    }
    var uploadDate = updateDate;

    var description = doc.querySelector(".book-intro>#intro-cut")?.text ?? "";
    description = trimAllLF(description);
    List<Chapter> chapters = [];

    // parse chapter
    doc.querySelector(".chapter-body")?.querySelectorAll("li").forEach((e) {
      var title = e.querySelector("span")?.text ?? "";
      var url = e.children.first.attributes["href"] ?? "";
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
    var params = {
      "keywords": name,
      "page": page,
    };
    var resp = await MyDio().getHtml(RequestOptions(
      path: searchBase,
      method: "GET",
      queryParameters: params,
    ));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    // parse page
    var pageCount = int.tryParse(doc
                .querySelector(".page-container>.pagination>.last")
                ?.firstChild
                ?.attributes["data-page"] ??
            "1") ??
        1;
    List<ComicSimple> list = [];
    doc.querySelector("#contList")?.querySelectorAll("li").forEach((e) {
      var title = e.querySelector("p>a")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["src"] ?? "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var child = e.querySelector(".updateon")?.clone(true);
      child?.querySelector(":nth-child(1)")?.remove();

      var updateDate = child?.text ?? "";
      if (updateDate.isNotEmpty) {
        int i = 0;
        while (i < updateDate.length &&
            !(updateDate[i].codeUnitAt(0) >= '0'.codeUnitAt(0) &&
                updateDate[i].codeUnitAt(0) <= '9'.codeUnitAt(0))) {
          i++;
        }
        updateDate = updateDate.substring(i);
        updateDate = trimAllLF(updateDate);
      }
      var source = "gufeng";
      var sourceName = sourcesName["gufeng"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    return ComicPageData(pageCount, list);
  }

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(baseUrl: domainBase, path: "/rank/", method: "GET"),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];
    doc.querySelectorAll(".fl>.orderby>li").forEach((element) {
      var href = element.firstChild?.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, href));
    });
    return res;
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    var resp = await MyDio().getHtml(
      RequestOptions(path: path, baseUrl: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    List<ComicSimple> list = [];
    doc
        .querySelector(".rank-list.clearfix")
        ?.querySelectorAll("li")
        .forEach((e) {
      var title = e.querySelector("p>a")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["src"] ?? "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var child = e.querySelector(".updateon")?.clone(true);
      child?.querySelector(":nth-child(1)")?.remove();

      var updateDate = child?.text ?? "";
      if (updateDate.isNotEmpty) {
        int i = 0;
        while (i < updateDate.length &&
            !(updateDate[i].codeUnitAt(0) >= '0'.codeUnitAt(0) &&
                updateDate[i].codeUnitAt(0) <= '9'.codeUnitAt(0))) {
          i++;
        }
        updateDate = updateDate.substring(i);
        updateDate = trimAllLF(updateDate);
      }
      var source = "gufeng";
      var sourceName = sourcesName["gufeng"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    var maxPage = 1;
    return ComicPageData(maxPage, list, maxNum: list.length);
  }
}
