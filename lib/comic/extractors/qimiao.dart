import 'dart:math';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

class Qimiao extends Parser {
  static Qimiao? _instance;
  String domainBase = "https://www.qimiaomh.com/";
  String searchBase = "https://www.qimiaomh.com/search/";

  Qimiao._internal() {
    _instance = this;
  }

  factory Qimiao() => _instance ?? Qimiao._internal();

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
      if (chapterImages[i].contains("mh1.88bada.com")) {
        chapterImages[i]
            .replaceAll("mh1.88bada.com", "mh1.xinxiongyuehardware.com");
      }
      if (chapterImages[i].contains("mh2.88bada.com")) {
        chapterImages[i]
            .replaceAll("mh2.88bada.com", "mh2.xinxiongyuehardware.com");
      }
      if (chapterImages[i].contains("i.ougannike.com")) {
        chapterImages[i].replaceAll("i.ougannike.com", "i.ywzqzx.com");
      }
      if (chapterImages[i].contains("res.img.yzrbhb.com")) {
        chapterImages[i].replaceAll("res.img.yzrbhb.com", "res.img.djk123.net");
      }
      chapter.images.add(ImageInfo(chapterImages[i]));
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

    var detailList = doc.querySelector(".ctdbRight>.ctdbRightInner");

    var clone = detailList?.querySelector(".title")?.clone(true);
    clone?.querySelector("span")?.remove();
    var title = clone?.text ?? "";
    title = trimAllLF(title);
    var state = ComicState.unknown;
    if (detailList?.querySelector(".updeteStatus")?.text.contains("连载") ??
        false) {
      state = ComicState.ongoing;
    } else if (detailList
            ?.querySelector(".updeteStatus")
            ?.text
            .contains("完结") ??
        false) {
      state = ComicState.completed;
    }

    clone = detailList?.querySelector(".author")?.clone(true);
    clone?.querySelector("span")?.remove();
    var author = clone?.text ?? "";
    author = trimAllLF(author);

    var thumb =
        doc.querySelector("inner")?.querySelector("img")?.attributes["src"] ??
            "";
    var updateDate = detailList?.querySelector(".date")?.text ?? "";
    int i = 0;
    while (i < updateDate.length &&
        !(updateDate[i].codeUnitAt(0) >= '0'.codeUnitAt(0) &&
            updateDate[i].codeUnitAt(0) <= '9'.codeUnitAt(0))) {
      i++;
    }
    updateDate = updateDate.substring(i);
    var uploadDate = updateDate;

    var description = doc.querySelector("#worksDesc")?.text ?? "";
    description = trimAllLF(description);
    List<Chapter> chapters = [];
    // parse chapter
    doc
        .querySelector(".comic-content-list")
        ?.querySelectorAll("ul")
        .forEach((e) {
      var title = e.querySelector(".tit")?.text ?? "";
      title = trimAllLF(title);
      var url = e.querySelector(".tit>a")?.attributes["href"] ?? "";
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
    doc
        .querySelector(".wrapper.clearfix.mt20>.mt20")
        ?.querySelectorAll(".classification")
        .forEach((e) {
      var title = e.querySelector("h2")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["data-src"] ??
          e.querySelector("img")?.attributes["src"] ??
          "";
      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var updateDate = "";

      var source = "qimiao";
      var sourceName = sourcesName["qimiao"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    return ComicPageData(pageCount, list);
  }
}
