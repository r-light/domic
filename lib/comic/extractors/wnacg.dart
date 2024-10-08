import 'dart:math';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

class Wnacg extends Parser {
  static Wnacg? _instance;
  String domainBase = "https://wnacg.com/";
  String searchBase = "https://wnacg.com/search/index.php";

  Wnacg._internal() {
    _instance = this;
  }

  factory Wnacg() => _instance ?? Wnacg._internal();

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

    List<Future<ImageInfo>> list = [];
    doc.querySelectorAll("div.gallary_wrap.tb>ul>li").forEach(
      (element) {
        var url = element.querySelector("a")?.attributes["href"] ?? "";
        list.add(parseImageHelper(url));
      },
    );
    chapter.images = [];
    chapter.images.addAll(await Future.wait(list));
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
    var maxLenText = "1";
    try {
      doc.querySelectorAll(".bot_toolbar>.paginator>a").last.text;
    } catch (e) {}
    var maxLen = int.tryParse(maxLenText) ?? 1;
    List<Chapter> chapters = [];
    for (int i = 1; i <= maxLen; i++) {
      var title = i.toString();
      List<String> ids = id.split("-").toList();
      ids.insert(2, title);
      ids.insert(2, "page");
      var url = ids.join("-");
      chapters.add(Chapter(title, url, 0, []));
    }
    chapters = chapters.reversed.toList();

    List<String> tags = [];
    List<String> tagsUrl = [];
    doc.querySelectorAll(".addtags>a.tagshow").forEach(
      (e) {
        var title = trimAllLF(e.text);
        tags.add(title);
        tagsUrl.add(e.attributes["href"] ?? "");
      },
    );
    var thumb = doc
            .querySelector("#bodywrap>.asTB")
            ?.querySelector("img")
            ?.attributes["src"] ??
        "";
    if (thumb.startsWith("//")) {
      thumb = "http:$thumb";
    }

    var title = doc.querySelector("#bodywrap>h2")?.text ?? "";
    title = trimAllLF(title);

    var state = ComicState.unknown;
    var author = "";
    var updateDate = "";
    var uploadDate = updateDate;
    var description = "";

    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;

    res.tags = tags;
    res.tagsUrl = tagsUrl;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var params = {
      "q": name,
      "m": "",
      "syn": "yes",
      "f": "_all",
      "s": "create_time_DESC",
      "p": page,
    };
    var resp = await MyDio().getHtml(
      RequestOptions(
        queryParameters: params,
        path: searchBase,
        method: "GET",
      ),
    );
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    List<ComicSimple> list = [];
    doc.querySelectorAll("div.gallary_wrap>ul").forEach((element) {
      for (var e in element.children) {
        var id = e.querySelector("a")?.attributes["href"] ?? "";
        var title = e.querySelector("a")?.attributes["title"] ?? "";
        title = trimAllLF(title);
        var thumb = e.querySelector("img")?.attributes["src"] ?? "";
        if (thumb.startsWith("//")) {
          thumb = "http:$thumb";
        }
        var updateDate = e.querySelector(".info_col")?.text ?? "";
        updateDate = updateDate.split("於").last;
        var source = "wnacg";
        var sourceName = sourcesName["wnacg"] ?? "";
        var author = "";
        var c = ComicSimple(
            id, title, thumb, author, updateDate, source, sourceName);
        list.add(c);
      }
    });

    // parse page
    var maxPage = 1;
    var totalText = doc
            .querySelector("#bodywrap")
            ?.querySelector(".result")
            ?.querySelector("b")
            ?.text ??
        "";
    totalText = totalText.replaceAll(",", "");
    int? total = int.tryParse(totalText) ?? 0;
    if (total != 0) {
      maxPage = (total / list.length).ceil();
    }
    return ComicPageData(maxPage, list, maxNum: total);
  }

  Future<ImageInfo> parseImageHelper(String url) async {
    var resp = await MyDio().getHtml(RequestOptions(
      path: url,
      baseUrl: domainBase,
      method: "GET",
    ));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    var imageUrl = doc.querySelector("#picarea")?.attributes["src"] ?? "";
    if (imageUrl.startsWith("//")) {
      imageUrl = "http:$imageUrl";
    }
    return ImageInfo(imageUrl);
  }

  Future<ComicPageData> comicByTag(String path, int page,
      {int type = 0}) async {
    List<String> paths = path.split("-").toList();
    paths.insert(2, page.toString());
    paths.insert(2, "page");

    var resp = await MyDio().getHtml(
      RequestOptions(
        path: paths.join("-"),
        baseUrl: domainBase,
        method: "GET",
      ),
    );

    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    List<ComicSimple> list = [];
    doc.querySelectorAll("div.gallary_wrap>ul").forEach((element) {
      for (var e in element.children) {
        var id = e.querySelector("a")?.attributes["href"] ?? "";
        var title = e.querySelector("a")?.attributes["title"] ?? "";
        title = trimAllLF(title);
        var thumb = e.querySelector("img")?.attributes["src"] ?? "";
        if (thumb.startsWith("//")) {
          thumb = "http:$thumb";
        }
        var updateDate = e.querySelector(".info_col")?.text ?? "";
        updateDate = updateDate.split("於").last;
        var source = "wnacg";
        var sourceName = sourcesName["wnacg"] ?? "";
        var author = "";
        var c = ComicSimple(
            id, title, thumb, author, updateDate, source, sourceName);
        list.add(c);
      }
    });

    // parse page
    var maxLenText = "1";
    try {
      maxLenText = doc.querySelectorAll(".bot_toolbar>.paginator>a").last.text;
    } catch (e) {}

    var maxPage = int.tryParse(maxLenText) ?? 1;
    return ComicPageData(maxPage, list);
  }

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(path: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];

    doc.querySelectorAll("#album_tabs>li").forEach((element) {
      var child = element.querySelector("#drop")?.querySelector("a") ??
          element.querySelector("a");
      var href = child?.attributes["href"] ?? "";
      var text = trimAllLF(element.querySelector("a")?.text ?? "");
      res.add(MapEntry(text, href));
    });
    return res.sublist(1, res.length - 1);
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    List<String> paths = [];
    if (path.contains("-")) {
      paths = path.split("-").toList();
      paths.insert(2, page.toString());
      paths.insert(2, "page");
    } else {
      paths = path.split(".").toList();
      paths.insert(1, page.toString());
      paths.insert(1, "page");
      paths.insert(1, "index");
    }

    var resp = await MyDio().getHtml(
      RequestOptions(
        path: paths.join("-"),
        baseUrl: domainBase,
        method: "GET",
      ),
    );

    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    List<ComicSimple> list = [];
    doc.querySelectorAll("div.gallary_wrap>ul").forEach((element) {
      for (var e in element.children) {
        var id = e.querySelector("a")?.attributes["href"] ?? "";
        var title = e.querySelector("a")?.attributes["title"] ?? "";
        title = trimAllLF(title);
        var thumb = e.querySelector("img")?.attributes["src"] ?? "";
        if (thumb.startsWith("//")) {
          thumb = "http:$thumb";
        }
        var updateDate = e.querySelector(".info_col")?.text ?? "";
        updateDate = updateDate.split("於").last;
        var source = "wnacg";
        var sourceName = sourcesName["wnacg"] ?? "";
        var author = "";
        var c = ComicSimple(
            id, title, thumb, author, updateDate, source, sourceName);
        list.add(c);
      }
    });

    var maxLen = 1;

    try {
      doc
          .querySelector(".bot_toolbar")
          ?.querySelectorAll("a")
          .forEach((element) {
        maxLen = max(maxLen, int.tryParse(trimAllLF(element.text)) ?? 1);
      });
    } catch (e) {}

    return ComicPageData(maxLen, list);
  }
}
