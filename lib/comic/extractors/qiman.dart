import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

class Qiman extends Parser {
  static Qiman? _instance;
  String domainBase = "http://www.qmanwu.com/";
  String searchBase = "http://www.qmanwu.com/search.php";

  Qiman._internal() {
    _instance = this;
  }

  factory Qiman() => _instance ?? Qiman._internal();

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
    RegExp reg = RegExp(r'eval\(([\s\S]*)}\(([\s\S]*)\)\)');
    var match = reg.firstMatch(content);

    if (match != null) {
      content = match.group(2)!;
      reg = RegExp(r"'([\s\S]*?)'");
      match = reg.firstMatch(content);
      var args0 = "";
      if (match != null) {
        args0 = match.group(1)!;
      }

      reg = RegExp(r"',([0-9]*),");
      match = reg.firstMatch(content);
      var args1 = 0;
      if (match != null) {
        args1 = int.tryParse(match.group(1)!) ?? 0;
      }

      reg = RegExp(r",([0-9]*),'");
      match = reg.firstMatch(content);
      var args2 = 0;
      if (match != null) {
        args2 = int.tryParse(match.group(1)!) ?? 0;
      }

      reg = RegExp(r",'([\s\S]*?)'");
      match = reg.firstMatch(content);
      List<String> args3 = [];
      if (match != null) {
        args3 = match.group(1)!.split("|");
      }
      var res = getImgUrl(args0, args1, args2, args3, {});
      for (var element in res) {
        chapter.images.add(ImageInfo(element));
      }
      chapter.len = chapter.images.length;
    }
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

    var comicInfoBox = doc.querySelector(".comicInfo");
    var thumb = comicInfoBox?.querySelector("img")?.attributes["src"] ?? "";

    var title = comicInfoBox?.querySelector(".name_mh")?.text ?? "";
    title = trimAllLF(title);

    var comicState =
        comicInfoBox?.querySelectorAll("span.ib.s").last.text.contains("连载");
    var state = comicState == null
        ? ComicState.unknown
        : (comicState ? ComicState.ongoing : ComicState.completed);

    var author =
        comicInfoBox?.querySelector("span.ib.l")?.text.split("：").last ?? "";
    author = trimAllLF(author);

    var updateDate =
        comicInfoBox?.querySelector("span.ib.s")?.text.split("：").last ?? "";
    var uploadDate = updateDate;

    var description = comicInfoBox?.querySelector(".content")?.text ?? "";
    if (description.contains("介绍")) {
      description = description.split(":").last;
    }
    description = trimAllLF(description);
    List<Chapter> chapters = [];

    // parse chapter
    var pureId = getId(id);
    doc.querySelector("#chapter-list1")?.querySelectorAll("a").forEach((e) {
      var title = e.text;
      title = trimAllLF(title);
      var url = e.attributes["href"] ?? "";
      chapters.add(Chapter(title, url, 0, []));
    });
    resp = (await MyDio().getHtml(RequestOptions(
        method: "POST",
        baseUrl: domainBase,
        path: "/bookchapter/",
        data: {"id": pureId, "id2": 1},
        contentType: Headers.formUrlEncodedContentType)));
    if (resp.key != -1) {
      var table = jsonDecode(resp.value?.data);
      for (var m in table) {
        var title = m["chaptername"] ?? "";
        var url = "";
        if (m.containsKey("chapterid")) {
          // ignore: prefer_interpolation_to_compose_strings
          url = ("/" + pureId + "/" + m["chapterid"] + ".html");
        }
        chapters.add(Chapter(title, url, 0, []));
      }
    }

    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var params = {
      "keyword": name,
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
    doc.querySelectorAll(".bookList_3>div").forEach((e) {
      var title = e.querySelector(".title")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["src"] ?? "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";
      var author = e.querySelector(".tip")?.text ?? "";
      author = trimAllLF(author);
      var updateDate = "";
      var source = "qiman";
      var sourceName = sourcesName[source] ?? "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    return ComicPageData(pageCount, list);
  }

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(
          baseUrl: domainBase, path: "/rank/1-1.html", method: "GET"),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];
    doc.querySelector(".rankNavNew")?.querySelectorAll("a").forEach((element) {
      var href = element.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, href));
    });
    return res;
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    List<ComicSimple> list = [];
    path = path.split("-").first;
    path += "-$page.html";
    var resp = await MyDio().getHtml(
      RequestOptions(path: path, baseUrl: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);

    doc.querySelectorAll(".bookList_3>div").forEach((e) {
      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var thumb = e.querySelector("img")?.attributes["src"] ?? "";

      var title = e.querySelector(".title")?.text ?? "";
      title = trimAllLF(title);

      var author = e.querySelector(".tip")?.text ?? "";
      author = trimAllLF(author);

      var updateDate = "";
      var source = "qiman";
      var sourceName = sourcesName["qiman"] ?? "";

      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });

    var maxPage = 10;
    return ComicPageData(maxPage, list, maxNum: 200);
  }

  String getId(String id) {
    int i = 0, j = id.length - 1;
    if (id[i] == '/') i++;
    if (id[j] == '/') j--;
    return id.substring(i, j + 1);
  }

  String listHelper(var a, var c) {
    return (c < a ? "" : listHelper(a, c ~/ a)) +
        ((c = c % a) > 35 ? String.fromCharCode(c + 29) : c.toRadixString(36));
  }

  List<String> getImgUrl(String p, int a, int c, List<String> k, Map d) {
    while (c-- > 0) {
      d[listHelper(a, c)] = k[c].isNotEmpty ? k[c] : listHelper(a, c);
    }
    c = 1;
    List<String> urls = p.split(",");
    urls = urls.map((element) {
      String res = element.replaceAllMapped(RegExp(r'\b(\w+)\b'), (match) {
        return d[match[0]] ?? match[0];
      });
      var reg = RegExp(r'"([\s\S]*?)"');
      var match = reg.firstMatch(res);
      if (match != null) {
        return match.group(1)!;
      }
      return res;
    }).toList();
    return urls;
  }
}
