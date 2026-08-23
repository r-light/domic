import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:html/parser.dart';

import 'xipi_decoder.dart';

class Xipi extends Parser {
  static Xipi? _instance;
  String domainBase = "https://m.hipmh.com/";
  String searchBase = "https://hipapi1.s3file.top/";
  String coverBase = "https://cover.s3imgs.top";
  String readerBase = "https://reader.hipmh.top/chapter/";
  String chapterImageBase = "https://v2.apikk.top/api/v2/chapter/getinfo";

  Xipi._internal() {
    _instance = this;
  }

  factory Xipi() => _instance ?? Xipi._internal();

  @override
  comicByChapter(ComicInfo comicInfo, {int idx = 0}) async {
    if (idx >= comicInfo.chapters.length) return;
    var chapter = comicInfo.chapters[idx];
    var resp = await MyDio().getHtml(RequestOptions(
      path: chapter.url,
      baseUrl: readerBase,
      method: "GET",
    ));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    var chapterContent = doc.querySelector("#chapcontent");
    var hid = chapterContent?.attributes["data-api-hid"] ?? "";

    resp = await MyDio().getHtml(RequestOptions(
        baseUrl: searchBase,
        path: "v2/chapter",
        method: "GET",
        queryParameters: {"hid": hid},
        headers: {"Referer": "https://reader.hipmh.top/"}));
    chapter.images = [];
    try {
      var listString = resp.value?.data["data"]["images"] as String;
      var list = XipiDecoder.decode(listString) as List;
      String prefix = chapterContent?.attributes["data-chapter-img-base"] ?? "";
      for (var url in list) {
        if (!url.startsWith("http")) {
          url = prefix + url;
        }
        chapter.images.add(
            ImageInfo(url)..headers = {"Referer": "https://reader.hipmh.top/"});
      }
    } catch (e) {}

    chapter.len = chapter.images.length;
  }

  @override
  Future<ComicInfo> comicById(String id) async {
    var resp = await MyDio().getHtml(RequestOptions(
      baseUrl: domainBase,
      path: "works/$id",
      method: "GET",
    ));
    var content = resp.value?.data.toString();
    var doc = parse(content);

    // parse chapter
    var mid =
        doc.querySelector("#chapters-config")?.attributes["data-mid"] ?? "";

    List<Chapter> chapters = [];
    // https://hipapi1.s3file.top/v1/manga/chapters?mid=bToxMzcwOA&page=1&per_page=50&order=desc

    // 看下多少页
    resp = await MyDio().getHtml(
      RequestOptions(
        path: "v1/manga/chapters",
        baseUrl: searchBase,
        method: "GET",
        queryParameters: {
          "order": "desc",
          "mid": mid,
          "page": "1",
          "per_page": "50"
        },
      ),
    );

    var firstPageData = resp.value?.data["data"];
    if (firstPageData == null) {
      throw Exception("请求失败");
    }

    var totalPages = firstPageData['total_pages']; // 总页数
    // 并发请求所有页（从第 1 页到 totalPages）
    final futures = <Future<MapEntry<int, Response?>>>[];
    for (int page = 2; page <= totalPages; page++) {
      futures.add(MyDio().getHtml(RequestOptions(
        path: "v1/manga/chapters",
        baseUrl: searchBase,
        method: "GET",
        queryParameters: {
          "order": "desc",
          "mid": mid,
          "page": page.toString(),
          "per_page": "50"
        },
      )));
    }

    var detailList = doc.querySelector("div.w-full.bg-background>div");
    var thumb = detailList?.querySelector("img")?.attributes["src"] ?? "";
    if (!thumb.startsWith("http")) {
      thumb = coverBase + thumb;
    }
    var title = trimAllLF(detailList?.querySelector("h1")?.text ?? "");
    var state = ComicState.unknown;
    var author = detailList?.querySelector("div.text-xs")?.text ?? "";
    author = trimAllLF(author);

    var updateDate = "";
    var uploadDate = updateDate;

    var description =
        detailList?.querySelector("#d-info-content>p")?.text ?? "";
    description = trimAllLF(description);

    // 等待所有请求完成
    final allResponses = await Future.wait(futures);
    allResponses.insert(0, resp);
    // 合并所有页的 items
    for (final resp in allResponses) {
      var pageData = resp.value?.data["data"];
      if (pageData != null) {
        for (var chapter in pageData["items"]) {
          chapters.add(Chapter(chapter["title"], chapter["hid"], 0, []));
        }
      }
    }
    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var resp = await MyDio().getHtml(RequestOptions(
        baseUrl: searchBase,
        path: "v1/search",
        method: "GET",
        queryParameters: {"page": page, "page_size": "20", "q": name}));

    var pageData = resp.value?.data["data"];
    if (pageData == null) {
      throw Exception("请求失败");
    }
    List<ComicSimple> list = [];

    for (var data in pageData["data"]) {
      var title = data["title"] ?? "";
      title = trimAllLF(title);
      var thumb = data["vertical_image_url"];
      if (!thumb.startsWith("http")) {
        thumb = coverBase + thumb;
      }

      var id = data["id"] ?? "";

      var updateDate = "";
      var source = "xipi";
      var sourceName = sourcesName["xipi"] ?? "";
      var author = "";
      try {
        var authorList = data["authors"] as List;
        author = authorList.first["name"];
      } catch (e) {}

      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    }
    var maxPage = pageData["total_pages"] ?? 1;
    return ComicPageData(maxPage, list);
  }

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(path: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];

    doc
        .querySelector("body > div.container.px-1 > div")
        ?.querySelectorAll("a")
        .forEach((element) {
      var href = element.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, href));
    });
    res.removeAt(0);
    return res;
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    var resp = await MyDio().getHtml(
      RequestOptions(
          path: path,
          baseUrl: domainBase,
          method: "GET",
          queryParameters: {"sort": "updated"}),
    );
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    var categoryId = doc
                .querySelector("div#manga-list-container")
                ?.attributes["data-category-id"]
                ?.isNotEmpty ==
            true
        ? doc
            .querySelector("div#manga-list-container")
            ?.attributes["data-category-id"]
        : null;
    var dataGenreId = doc
                .querySelector("div#manga-list-container")
                ?.attributes["data-genre-id"]
                ?.isNotEmpty ==
            true
        ? doc
            .querySelector("div#manga-list-container")
            ?.attributes["data-genre-id"]
        : null;
    var perPage = doc
                .querySelector("div#manga-list-container")
                ?.attributes["data-per-page"]
                ?.isNotEmpty ==
            true
        ? doc
            .querySelector("div#manga-list-container")
            ?.attributes["data-per-page"]
        : "18";
    List<ComicSimple> list = [];

    int maxPage = 1;
    resp = await MyDio().getHtml(
      RequestOptions(
        path: "v1/mangas",
        baseUrl: searchBase,
        method: "GET",
        queryParameters: {
          "sort": "updated",
          "genre": dataGenreId,
          "category": categoryId,
          "page": maxPage,
          "per_page": perPage
        },
      ),
    );
    var data = resp.value?.data["data"];

    for (var item in data["items"]) {
      var title = item["title"] ?? "";
      title = trimAllLF(title);
      var thumb = item["vertical_image_url"] ?? "";
      if (!thumb.startsWith("http")) {
        thumb = coverBase + thumb;
      }

      var id = item["mid"] ?? "";

      String updateDate = item["updated_at"] ?? "";
      if (updateDate.isNotEmpty) {
        DateTime dt = DateTime.parse(updateDate);
        DateTime local = dt.toLocal();
        updateDate =
            "${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} "
            "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}";
      }
      var source = "xipi";
      var sourceName = sourcesName["xipi"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    }

    return ComicPageData(maxPage, list);
  }
}
