import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

class Jmtt extends Parser {
  static Jmtt? _instance;
  String domainBase = "https://18comic.org/";
  String searchPath = "/search/photos/";

  Jmtt._internal() {
    _instance = this;
  }

  factory Jmtt() => _instance ?? Jmtt._internal();

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

    // ScrambleId
    var target = doc
        .querySelectorAll("script")
        .firstWhere((element) => element.text.contains("scramble_id"))
        .text;
    RegExp reg = RegExp(r'scramble_id\s*=\s*(.*?)\s*;');
    var match = reg.firstMatch(target);
    var scrambleIds = 0;
    if (match != null) {
      scrambleIds = int.tryParse(match.group(match.groupCount) ?? "0") ?? 0;
    }
    chapter.scrambleId = scrambleIds;

    // aid
    target = doc
        .querySelectorAll("script")
        .firstWhere((element) => element.text.contains("aid"))
        .text;
    reg = RegExp(r'aid\s*=\s*(.*?)\s*;');
    match = reg.firstMatch(target);
    var aid = 0;
    if (match != null) {
      aid = int.tryParse(match.group(match.groupCount) ?? "0") ?? 0;
    }
    chapter.aid = aid;

    List<ImageInfo> imgs = [];
    doc
        .querySelectorAll(".panel-body>.thumb-overlay-albums>.scramble-page")
        .forEach((element) {
      var src = element.querySelector("img")?.attributes["data-original"] ?? "";
      var pid = element.attributes["id"];
      imgs.add(ImageInfo(src)..pid = pid);
    });
    chapter.images = imgs;
  }

  @override
  Future<ComicInfo> comicById(String id) async {
    var resp = await MyDio().getHtml(
      RequestOptions(
        path: id,
        baseUrl: domainBase,
        method: "GET",
      ),
    );

    var content = resp.value?.data.toString();
    var doc = parse(content);

    var title =
        doc.querySelector(".panel-heading>[itemprop='name']")?.text.trim() ??
            "";
    title = trimAllLF(title);
    var thumb = doc
            .querySelector("#album_photo_cover")
            ?.querySelector("img")
            ?.attributes["src"] ??
        "";
    List<String> works = [], tags = [], authors = [], characters = [];
    List<String> tagsUrl = [];
    doc
        .querySelector("[itemprop='author'][data-type='works']")
        ?.children
        .forEach((element) {
      works.add(element.text);
    });
    doc
        .querySelector("[itemprop='author'][data-type='actor']")
        ?.children
        .forEach((element) {
      characters.add(element.text);
    });
    doc
        .querySelector("[itemprop='genre'][data-type='tags']")
        ?.children
        .forEach((element) {
      tags.add(element.text);
      tagsUrl.add(element.attributes["href"] ?? "");
    });
    doc
        .querySelector("[itemprop='author'][data-type='author']")
        ?.children
        .forEach((element) {
      authors.add(element.text);
    });
    var state = ComicState.unknown;

    var author = "";
    for (var element in authors) {
      author += element;
    }
    author = trimAllLF(author);
    var updateDate = "", uploadDate = "", views = "", star = "";

    doc.querySelectorAll("#album_photo_cover>div").last.children.forEach((s) {
      var text = s.text;
      if (text.contains("上架日期")) {
        uploadDate = s.attributes["content"] ?? "";
        return;
      }
      if (text.contains("更新日期")) {
        updateDate = s.attributes["content"] ?? "";
        return;
      }
      if (text.contains("觀看")) {
        views = text.split(" ").first.trim();
      }
      if (text.contains("點擊喜歡")) {
        star = s.children.first.text;
      }
    });

    var desc = doc.querySelectorAll("#album_photo_cover>div>.p-t-5.p-b-5");
    var description = "";
    if (desc.length > 1) {
      description = desc[1].text;
    }

    List<Chapter> chapters = [];
    // parse chapter
    if (doc.querySelector("#episode-block") != null) {
      doc
          .querySelector("#episode-block")
          ?.querySelector("ul")
          ?.children
          .reversed
          .forEach((s) {
        var title = s.querySelector("li")?.firstChild?.text ?? "";
        title = trimAllLF(title);

        var url = s.attributes["href"] ?? "";
        var chapter = Chapter(title, url, 0, []);
        chapter.uploadDate = s.querySelectorAll("li>span").last.text;
        chapters.add(chapter);
      });
    } else {
      var title =
          doc.querySelector(".panel-heading>[itemprop='name']")?.text ?? "";
      title = trimAllLF(title);
      var url =
          doc.querySelector(".dropdown-toggle.reading")?.attributes["href"] ??
              "";
      var chapter = Chapter(title, url, 0, []);
      chapter.uploadDate = updateDate;
      chapters.add(chapter);
    }

    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    res.authors = authors;
    res.works = works;
    res.tags = tags;
    res.characters = characters;
    res.views = views;
    res.star = star;
    res.tagsUrl = tagsUrl;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var params = {
      "search_query": name,
      "search-type": "photos",
      "main_tag": 0,
      "page": page,
    };
    var resp = await MyDio().getHtml(
      RequestOptions(
        queryParameters: params,
        path: searchPath,
        baseUrl: domainBase,
        method: "GET",
      ),
    );

    return parseComicPageHelper(resp, page);
  }

  ComicPageData parseComicPageHelper(
      MapEntry<int, Response<dynamic>?> resp, int page) {
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    List<ComicSimple> list = [];
    doc
        .querySelectorAll(
            "div.row.m-0,div.col-xs-12.col-md-12.col-sm-12>div.row")
        .forEach((element) {
      for (var e in element.children) {
        var id = e.querySelector("a")?.attributes["href"] ?? "";
        var title = e.querySelector("span.video-title")?.text ?? "";
        title = trimAllLF(title);
        var thumb = e
                .querySelector(".thumb-overlay")
                ?.querySelector("img")
                ?.attributes["data-original"] ??
            "";
        var updateDate = "";
        var star = e.querySelector(".label-loveicon")?.text.trim() ?? "";
        List<String> tags = [];
        e
            .querySelector("div.tags")
            ?.querySelectorAll(".tag")
            .forEach((element) {
          tags.add(element.text.trim());
        });
        List<String> categories = [];
        e.querySelector(".category-icon")?.children.forEach((element) {
          categories.add(element.text);
        });
        var source = "jmtt";
        var sourceName = sourcesName["jmtt"] ?? "";
        var author = e.querySelector("div.title-truncate")?.text ?? "";
        author = trimAllLF(author);
        var c = ComicSimple(
            id, title, thumb, author, updateDate, source, sourceName);
        c.tags = tags;
        c.categories = categories;
        c.star = star;
        list.add(c);
      }
    });

    // parse page
    var maxPage = 1;
    var pager = doc
        .querySelector(".col-xs-12.col-md-9.col-sm-8>.well.well-sm")
        ?.querySelectorAll(">.text-white");
    int? total;
    if (page == 1 && pager != null && pager.length >= 4) {
      var from = int.tryParse(pager[1].text) ?? 0;
      var to = int.tryParse(pager[2].text) ?? 1;
      total = int.tryParse(pager[3].text) ?? 1;
      maxPage = (total - 1) ~/ (to - from + 1) + 1;
    }
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

  Future<ComicPageData> comicByTag(String path, int page,
      {int type = 0}) async {
    path += "&page=$page";
    if (type == 0) {
      path += "&o=mr";
    } else if (type == 1) {
      path += "&o=mv";
    } else if (type == 2) {
      path += '&o=mp';
    } else if (type == 3) {
      path += "&o=tf";
    }
    var resp = await MyDio().getHtml(
      RequestOptions(
        path: path,
        baseUrl: domainBase,
        method: "GET",
      ),
    );
    return parseComicPageHelper(resp, page);
  }
}

// void main() async {
//   var pageData = await Jmtt().comicByName("星野", 1);
//   print(pageData.pageCount);

//   // var comicInfo = await Pufei().comicById(pageData.records[0].id);
//   // await Pufei().comicByChapter(comicInfo, idx: 0);
//   // print(comicInfo.chapters[0].images[0].src);
// }
