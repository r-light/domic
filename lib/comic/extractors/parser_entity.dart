import 'package:domic/comic/extractors/dto.dart';

abstract class Parser {
  Future<ComicPageData> comicByName(String name, int page);
  Future<ComicInfo> comicById(String id);
  comicByChapter(ComicInfo comicInfo, {int idx = 0});
}

abstract class ParserWebview {
  Future<ComicPageData> comicByNameWebview(String name, int page);
  Future<ComicInfo> comicByIdWebview(Map<String, dynamic> map);
  comicByChapterWebview(ComicInfo comicInfo, Map<String, dynamic> map,
      {int idx = 0});
  String parseComicInfoUrl(String id);
  String parseChapterUrl(String id);
  Map<String, String>? getHeader();
}
