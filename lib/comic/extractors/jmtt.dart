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
    chapter.len = imgs.length;
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
      author += "$element ";
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

    var desc =
        doc.querySelectorAll(".panel-body>.row>.col-lg-7>div>.p-t-5.p-b-5");
    var description = "";
    if (desc.length > 1) {
      description = trimAllLF(desc[1].text);
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
        var thumb = e.querySelector("img")?.attributes["data-original"] ??
            e.querySelector("img")?.attributes["src"] ??
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
        ?.querySelectorAll(".text-white");
    int? total;
    if (page == 1 && pager != null && pager.length >= 4) {
      var from = int.tryParse(pager[1].text) ?? 0;
      var to = int.tryParse(pager[2].text) ?? 1;
      total = int.tryParse(pager[3].text) ?? 1;
      maxPage = (total - 1) ~/ (to - from + 1) + 1;
    } else if (page == 1 && pager != null && pager.length >= 3) {
      var from = int.tryParse(pager[0].text) ?? 0;
      var to = int.tryParse(pager[1].text) ?? 1;
      total = int.tryParse(pager[2].text) ?? 1;
      maxPage = (total - 1) ~/ (to - from + 1) + 1;
    }
    return ComicPageData(maxPage, list, maxNum: total);
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

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(baseUrl: domainBase, path: "/theme", method: "GET"),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];
    doc.querySelectorAll(".btn.btn-default>a").forEach((element) {
      var href = element.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, href));
    });
    return res.sublist(8);
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    if (page != 1) {
      path += "&page=$page";
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

  Future<List<ComicSimple>> comicByRelated(String id) async {
    List<ComicSimple> list = [];
    var resp = await MyDio().getHtml(
      RequestOptions(
        path: id,
        baseUrl: domainBase,
        method: "GET",
      ),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    doc
        .querySelector(".row.m-l-0.m-r-0.m-b-10>.owl-carousel")
        ?.querySelectorAll(".p-b-15.p-l-5.p-r-5")
        .forEach((e) {
      var id = e.querySelector("a")?.attributes["href"] ?? "";
      var title = e.querySelector("span.video-title")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["data-src"] ??
          e.querySelector("img")?.attributes["src"] ??
          "";
      var updateDate = "";
      var star = e.querySelector(".label-loveicon")?.text.trim() ?? "";
      List<String> tags = [];
      e
          .querySelectorAll(".title-truncate")
          .last
          .querySelectorAll("a")
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
      var c =
          ComicSimple(id, title, thumb, author, updateDate, source, sourceName);
      c.tags = tags;
      c.categories = categories;
      c.star = star;
      list.add(c);
    });
    return list;
  }

  Future<MapEntry<List<CommentInfo>, bool>> commentById(String id,
      {int page = 1}) async {
    List<String> ids = id.split("/");
    for (var t in ids) {
      if (int.tryParse(t) != null) {
        id = t;
        break;
      }
    }
    var res = <CommentInfo>[];
    var resp = (await MyDio().getHtml(RequestOptions(
        method: "POST",
        baseUrl: domainBase,
        path: '/ajax/album_pagination',
        data: {"video_id": id, "page": page},
        contentType: Headers.formUrlEncodedContentType)));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    doc.querySelectorAll(".panel.panel-default.timeline-panel").forEach((e) {
      var left = e.querySelectorAll(".timeline-left");
      var right = e.querySelectorAll(".timeline-right");
      int length = left.length < right.length ? left.length : right.length;
      CommentInfo? comment;
      for (int i = 0; i < length; i++) {
        var avatarInfo = left[i];
        var avatar = avatarInfo.querySelector("img")?.attributes["src"] ?? "";
        if (!avatar.startsWith("http")) {
          if (avatar.startsWith("/")) {
            avatar = domainBase.substring(0, domainBase.length - 1) + avatar;
          } else {
            avatar = domainBase + avatar;
          }
        }
        var commentInfo = right[i];
        var name = commentInfo.querySelector(".timeline-username")?.text ?? "";
        name = trimAllLF(name);
        var content =
            commentInfo.querySelector(".timeline-content")?.text ?? "";
        content = trimAllLF(content);
        var date = commentInfo.querySelector(".timeline-date")?.text ?? "";
        date = trimAllLF(date);
        if (comment == null) {
          comment = CommentInfo(name, avatar, date, content, []);
        } else {
          comment.reply.add(CommentInfo(name, avatar, date, content, []));
        }
      }
      if (comment != null) res.add(comment);
    });
    bool hasNext = false;
    var next = doc.querySelectorAll("div").last.text;
    if (next.contains("查看更多")) hasNext = true;
    return MapEntry(res, hasNext);
  }
}
