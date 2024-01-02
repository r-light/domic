import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

class Kuman extends Parser {
  static Kuman? _instance;
  String domainBase = "http://www.kumwu2.com/";
  String searchBase = "http://www.kumwu2.com/search";

  Kuman._internal() {
    _instance = this;
  }

  factory Kuman() => _instance ?? Kuman._internal();

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

      reg = RegExp(r",([0-9]*?),'");
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

      var c0rst96 = getImgUrl(args0, args1, args2, args3, {});
      var a0ks5217 = int.parse(
          doc.querySelector(".readerContainer")?.attributes["data-id"] ?? "0");
      var a2vrvt32 = [
        "c21raHkyNTg=",
        "c21rZDk1ZnY=",
        "bWQ0OTY5NTI=",
        "Y2Rjc2R3cQ==",
        "dmJmc2EyNTY=",
        "Y2F3ZjE1MWM=",
        "Y2Q1NmN2ZGE=",
        "OGtpaG50OQ==",
        "ZHNvMTV0bG8=",
        "NWtvNnBsaHk="
      ][a0ks5217];
      var ve1rdc3 = utf8.decode(base64.decode(a2vrvt32));
      var ps2ra76 = utf8.decode(base64.decode(c0rst96));
      var lecs58c = ve1rdc3.length;
      var csv489v = "";
      for (int i = 0; i < ps2ra76.length; i++) {
        var k = i % lecs58c;
        csv489v += String.fromCharCode(
            ps2ra76[i].codeUnitAt(0) ^ ve1rdc3[k].codeUnitAt(0));
      }
      var a6ffo512 = utf8.decode(base64.decode(csv489v));
      var list = jsonDecode(a6ffo512);
      for (var element in list) {
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

    var comicInfoBox = doc.querySelector(".banner_detail_form");
    var thumb = comicInfoBox?.querySelector("img")?.attributes["src"] ?? "";

    var title = comicInfoBox?.querySelector("h1")?.text ?? "";
    title = trimAllLF(title);

    var comicState =
        comicInfoBox?.querySelector(".tip>span")?.text.contains("连载");
    var state = comicState == null
        ? ComicState.unknown
        : (comicState ? ComicState.ongoing : ComicState.completed);

    var author =
        comicInfoBox?.querySelector(".subtitle")?.text.split("：").last ?? "";
    author = trimAllLF(author);

    var updateDate =
        comicInfoBox?.querySelectorAll(".tip>span").last.text.split("：").last ??
            "";
    var uploadDate = updateDate;

    var description = comicInfoBox?.querySelector(".content")?.text ?? "";
    if (description.contains("介绍")) {
      description = description.split(":").last;
    }
    description = trimAllLF(description);
    List<Chapter> chapters = [];

    // parse chapter

    doc.querySelector("#chapterlistload")?.querySelectorAll("a").forEach((e) {
      var title = e.text;
      title = trimAllLF(title);
      var url = e.attributes["href"] ?? "";
      chapters.add(Chapter(title, url, 0, []));
    });
    resp = (await MyDio().getHtml(RequestOptions(
      method: "get",
      baseUrl: domainBase,
      path: "/chapterlist$id",
    )));
    if (resp.key != -1) {
      var table = jsonDecode(resp.value?.data);
      List res = table["data"]["list"];
      for (var m in res) {
        var title = m["name"] ?? "";
        var url = "";
        if (m.containsKey("id")) {
          // ignore: prefer_interpolation_to_compose_strings
          url = (id + m["id"] + ".html");
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
    doc.querySelector(".box.container")?.querySelectorAll("li").forEach((e) {
      var title = e.querySelector(".card-text")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["data-src"] ??
          e.querySelector("img")?.attributes["src"] ??
          "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";
      var author = "";
      var updateDate = "";
      var source = "kuman";
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
    doc.querySelector(".cat-list")?.querySelectorAll("a").forEach((element) {
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

    doc.querySelector(".box.container")?.querySelectorAll("li").forEach((e) {
      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var thumb = e.querySelector("img")?.attributes["data-src"] ??
          e.querySelector("img")?.attributes["src"] ??
          "";

      var title = e.querySelector(".card-text")?.text ?? "";
      title = trimAllLF(title);

      var author = "";

      var updateDate = "";
      var source = "kuman";
      var sourceName = sourcesName["kuman"] ?? "";

      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });

    var maxPage = 10;
    return ComicPageData(maxPage, list);
  }

  String listHelper(var a, var c) {
    return (c < a ? "" : listHelper(a, c ~/ a)) +
        ((c = c % a) > 35 ? String.fromCharCode(c + 29) : c.toRadixString(36));
  }

  String getImgUrl(String p, int a, int c, List<String> k, Map d) {
    while (c-- > 0) {
      d[listHelper(a, c)] = k[c].isNotEmpty ? k[c] : listHelper(a, c);
    }
    c = 1;
    List<String> urls = [p];
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
    return urls[0];
  }
}
