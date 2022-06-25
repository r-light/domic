import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:html/parser.dart';
import 'package:path/path.dart';

class Pufei extends Parser {
  static Pufei? _instance;
  String domainBase = "http://www.pfmh.net/";
  String searchBase = "http://www.pfmh.net/e/search/";
  String picBase = "http://res.img.tueqi.com/";
  String searchPath = "/index.php";

  Pufei._internal() {
    _instance = this;
  }

  factory Pufei() => _instance ?? Pufei._internal();

  @override
  comicByChapter(ComicInfo comicInfo, {int idx = 0}) async {
    if (idx >= comicInfo.chapters.length) return;
    var chapter = comicInfo.chapters[idx];
    var resp = await MyDio().getHtml(RequestOptions(
        path: chapter.url,
        baseUrl: domainBase,
        method: "GET",
        responseDecoder: gbkDecoder));
    var content = resp.value?.data.toString() ?? "";
    RegExp reg = RegExp(r'packed\s*=\s*"([\s\S]*?)"');
    var match = reg.firstMatch(content);
    if (match != null) {
      String decoded = utf8.decode(base64.decode(match.group(1)!));
      reg = RegExp(r'}\(([\s\S]*)\)\)');
      match = reg.firstMatch(decoded);
      if (match != null) {
        var args = match.group(1)!.split(",");
        var ss = args[3].split(".")[0];
        var arg3 = ss.substring(1, ss.length - 1).split("|");
        var res = getImgUrl(args[0].substring(1, args[0].length - 1),
            int.tryParse(args[1]) ?? 0, int.tryParse(args[2]) ?? 0, arg3, {});
        chapter.len = res.length;
        chapter.images = [];
        for (var path in res) {
          if (path.startsWith("http")) {
            chapter.images.add(ImageInfo(path));
          } else {
            chapter.images.add(ImageInfo(picBase + path));
          }
        }
      }
    }
  }

  @override
  Future<ComicInfo> comicById(String id) async {
    var resp = await MyDio().getHtml(RequestOptions(
        path: id,
        baseUrl: domainBase,
        method: "GET",
        responseDecoder: gbkDecoder));
    var content = resp.value?.data.toString();
    var doc = parse(content);
    var title = doc.querySelector(".titleInfo>h1")?.text ?? "";
    title = trimAllLF(title);
    var state = ComicState.unknown;
    if (doc.querySelector(".titleInfo>span")?.text == "连载") {
      // this website seems not to have the completed state
      state = ComicState.ongoing;
    }
    var thumb = doc.querySelector(".info_cover>img")?.attributes["src"] ?? "";
    var children =
        doc.querySelector(".detailInfo")?.querySelectorAll("li") ?? [];
    var updateDate = children.isNotEmpty
        ? (children[0].querySelector("font")?.text ?? "")
        : "";
    var uploadDate = updateDate;
    var author = children.length > 1 ? (children[1].text) : "";
    var description =
        doc.querySelector(".leftContent>.description>#intro1")?.text ?? "";
    List<Chapter> chapters = [];

    // parse chapter
    doc.querySelector("#play_0")?.querySelectorAll("li").forEach((e) {
      var title = e.firstChild?.attributes["title"] ?? "";
      var url = e.firstChild?.attributes["href"] ?? "";
      chapters.add(Chapter(title, url, 0, []));
    });
    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var formData = {
      "orderby": "1",
      "myorder": "1",
      "tbname": "mh",
      "tempid": "3",
      "show": "title,player,playadmin,bieming,pinyin",
      "keyboard": name,
      "Submit": "搜索漫画",
    };
    var resp = await MyDio().getHtml(
      RequestOptions(
          data: formData,
          path: searchPath,
          baseUrl: searchBase,
          method: "POST",
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) {
            return status == null || status < 500;
          },
          requestEncoder: (input, ops) {
            String res = "";
            res += "orderby=${Uri.encodeQueryComponent(ops.data["orderby"])}&";
            res += "myorder=${Uri.encodeQueryComponent(ops.data["myorder"])}&";
            res += "tbname=${Uri.encodeQueryComponent(ops.data["tbname"])}&";
            res += "tempid=${Uri.encodeQueryComponent(ops.data["tempid"])}&";
            res += "show=${Uri.encodeQueryComponent(ops.data["show"])}&";
            res += "keyboard=${gbkUrlLenEncode(ops.data["keyboard"])}&";
            res += "Submit=${gbkUrlLenEncode(ops.data["Submit"])}";
            return gbk.encode(res);
          },
          responseDecoder: gbkDecoder),
    );
    var resPath = resp.value?.headers.map['location']?.first ?? "";
    if (resPath.isEmpty) return ComicPageData(0, []);
    resp = await MyDio().getHtml(RequestOptions(
      path: resPath,
      baseUrl: searchBase,
      method: "GET",
      responseDecoder: gbkDecoder,
    ));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    // parse page
    var pager = doc.querySelectorAll("#pagerH>strong");

    var total =
        pager.isNotEmpty ? int.tryParse(trimAllLF(pager[0].text)) ?? 0 : 0;
    var perPage =
        pager.length > 1 ? int.tryParse(trimAllLF(pager[1].text)) ?? 1 : 1;

    List<ComicSimple> list = [];
    doc.querySelector("#dmList")?.querySelectorAll("li").forEach((e) {
      var title = e.querySelector("dl>dt>a")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["_src"] ?? "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";
      var children = e.querySelectorAll("dl>dd>p");
      var updateDate = children.isNotEmpty ? children[0].text : "";
      if (updateDate.isNotEmpty) {
        int i = 0;
        while (i < updateDate.length &&
            !(updateDate[i].codeUnitAt(0) >= '0'.codeUnitAt(0) &&
                updateDate[i].codeUnitAt(0) <= '9'.codeUnitAt(0))) {
          i++;
        }
        updateDate = updateDate.substring(i);
      }
      var source = "pufei";
      var sourceName = sourcesName["pufei"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    var maxPage = total ~/ perPage + (total % perPage == 0 ? 0 : 1);
    return ComicPageData(maxPage, list, maxNum: total);
  }

  String listHelper(var a, var c) {
    return (c < a ? "" : listHelper(a, c ~/ a)) +
        ((c = c % a) > 35 ? String.fromCharCode(c + 29) : c.toRadixString(36));
  }

  List<String> getImgUrl(String p, int a, int c, List<String> k, Map d) {
    while (c-- > 0) {
      d[listHelper(a, c)] = k[c].isEmpty ? listHelper(a, c) : k[c];
    }
    c = 1;
    List<String> urls = p.split(";");
    if (urls.last.isEmpty) urls.removeLast();
    urls = urls.map((element) {
      var tmp = element.split("=").last;
      return tmp.substring(1, tmp.length - 1);
    }).toList();
    urls = urls.map((element) {
      String res = "";
      element.split("/").forEach((element) {
        if (element.contains(".")) {
          var tmp = element.split(".");
          res += (d[tmp[0]] ?? element) + ".";
          res += (d[tmp[1]] ?? element) + "/";
        } else {
          res += (d[element] ?? element) + "/";
        }
      });
      res = res.substring(0, res.length - 1);
      return res;
    }).toList();
    return urls;
  }

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(
          path: domainBase, method: "GET", responseDecoder: gbkDecoder),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];
    (doc.querySelector(".navWarp")?.children
          ?..removeLast()
          ..removeAt(0))
        ?.forEach((element) {
      var href = element.firstChild?.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, join(href, "view.html")));
    });
    return res;
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    if (page != 1) {
      var list = path.split(".");
      if (list.isNotEmpty) list[0] += "_$page";
      path = list.join(".");
    }
    var resp = await MyDio().getHtml(
      RequestOptions(
          path: path,
          baseUrl: domainBase,
          method: "GET",
          responseDecoder: gbkDecoder),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    // parse page
    var pager = doc.querySelectorAll("#pagerH>strong");

    var total =
        pager.isNotEmpty ? int.tryParse(trimAllLF(pager[0].text)) ?? 0 : 0;
    var perPage =
        pager.length > 1 ? int.tryParse(trimAllLF(pager[1].text)) ?? 1 : 1;
    List<ComicSimple> list = [];
    doc.querySelector("#dmList")?.querySelectorAll("li").forEach((e) {
      var title = e.querySelector("dl>dt>a")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["_src"] ?? "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";
      var children = e.querySelectorAll("dl>dd>p");
      var updateDate = children.isNotEmpty ? children[0].text : "";
      if (updateDate.isNotEmpty) {
        int i = 0;
        while (i < updateDate.length &&
            !(updateDate[i].codeUnitAt(0) >= '0'.codeUnitAt(0) &&
                updateDate[i].codeUnitAt(0) <= '9'.codeUnitAt(0))) {
          i++;
        }
        updateDate = updateDate.substring(i);
      }
      var author = "";
      if (children.length > 3) {
        var clone = children[2].clone(true);
        clone.querySelector("em")?.remove();
        author = clone.text;
      }
      var source = "pufei";
      var sourceName = sourcesName["pufei"] ?? "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    var maxPage = total ~/ perPage + (total % perPage == 0 ? 0 : 1);
    return ComicPageData(maxPage, list, maxNum: total);
  }
}

// void main() async {
//   var pageData = await Pufei().comicByName("柯南", 1);
//   var comicInfo = await Pufei().comicById(pageData.records[0].id);
//   await Pufei().comicByChapter(comicInfo, idx: 0);
//   print(comicInfo.chapters[0].images[0].src);
// }
