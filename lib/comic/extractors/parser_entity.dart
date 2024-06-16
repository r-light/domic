import 'package:domic/comic/extractors/dto.dart';

abstract class Parser {
  Future<ComicPageData> comicByName(String name, int page);
  Future<ComicInfo> comicById(String id);
  comicByChapter(ComicInfo comicInfo, {int idx = 0});
}
