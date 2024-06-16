// todo json_serializable

import 'package:hive_flutter/adapters.dart';

part 'dto.g.dart';

const sourcesName = {
  "pufei": "扑飞漫画",
  "jmtt": "禁漫天堂",
  "gufeng": "古风漫画",
  "bainian": "百年漫画",
  "qimiao": "奇妙漫画",
  "qiman": "奇漫屋",
  "maofly": "漫画猫",
  "kuman": "酷漫屋",
  "baozi": "包子漫画"
};

@HiveType(typeId: 1)
enum ComicState {
  @HiveField(0)
  unknown,

  @HiveField(1)
  completed,

  @HiveField(2)
  ongoing
}

@HiveType(typeId: 2)
class PageData {
  @HiveField(0)
  late int pageCount;

  PageData(this.pageCount);

  PageData.fromJson(Map<String, dynamic> json) {
    pageCount = json["page_count"] ?? 1;
  }
}

@HiveType(typeId: 3)
class ComicSimple {
  @HiveField(0)
  late String id;
  @HiveField(1)
  late String title;
  @HiveField(2)
  late String thumb;
  @HiveField(3)
  late String author;
  @HiveField(4)
  late String updateDate;
  @HiveField(5)
  late String source;
  @HiveField(6)
  late String sourceName;
  @HiveField(7)
  List<String>? categories;
  @HiveField(8)
  List<String>? tags;
  @HiveField(9)
  String? star;

  ComicSimple(
    this.id,
    this.title,
    this.thumb,
    this.author,
    this.updateDate,
    this.source,
    this.sourceName,
  );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "categories": categories,
        "tags": tags,
        "thumb": thumb,
        "star": star,
        "author": author,
        "updateDate": updateDate,
        "source": source,
        "sourceName": sourceName,
      };

  ComicSimple.fromJson(Map<String, dynamic> json) {
    id = json["id"] ?? "";
    title = json["title"] ?? "";
    categories = (json["categories"] ?? []).cast<String>();
    tags = (json["tags"] ?? []).cast<String>();
    thumb = json["thumb"] ?? "";
    star = json["star"] ?? "";
    author = json["author"] ?? "";
    updateDate = json["update_date"] ?? "";
    source = json["source"] ?? "";
    sourceName = json["source_name"] ?? "";
  }
}

@HiveType(typeId: 4)
class ComicPageData extends PageData {
  @HiveField(1)
  late List<ComicSimple> records;
  @HiveField(2)
  int? maxNum;

  ComicPageData(int pageCount, this.records, {this.maxNum}) : super(pageCount);
  ComicPageData.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    records = (json["records"] ?? [])
        .map((e) => ComicSimple.fromJson(e))
        .toList()
        .cast<ComicSimple>();
    maxNum = json["max_num"];
  }
}

@HiveType(typeId: 5)
class ImageInfo {
  @HiveField(0)
  late String src;
  @HiveField(1)
  int? height;
  @HiveField(2)
  int? width;
  @HiveField(3)
  String? pid;
  @HiveField(4)
  Map<String, dynamic>? headers;

  ImageInfo(this.src);

  Map<String, dynamic> toJson() => {
        "src": src,
        "height": height,
        "width": width,
        "pid": pid,
        "headers": headers
      };

  ImageInfo.fromJson(Map<String, dynamic> json) {
    src = json["src"] ?? "";
    height = json["height"] ?? 0;
    width = json["width"] ?? 0;
    pid = json["pid"] ?? "";
    headers = json["headers"] ?? {};
  }

  ImageInfo.from(ImageInfo image) {
    src = image.src;
    height = image.height;
    width = image.width;
    pid = image.pid;
    headers = image.headers;
  }
}

@HiveType(typeId: 6)
class Chapter {
  @HiveField(0)
  late String title;
  @HiveField(1)
  late String url;
  @HiveField(2)
  late int len;
  @HiveField(3)
  late List<ImageInfo> images;
  @HiveField(4)
  String? uploadDate;
  @HiveField(5)
  int? scrambleId;
  @HiveField(6)
  int? aid;

  Chapter(this.title, this.url, this.len, this.images);

  Map<String, dynamic> toJson() => {
        "title": title,
        "url": url,
        "upload_date": uploadDate,
        "len": len,
        "scramble_id": scrambleId,
        "aid": aid,
        "images": images,
      };

  Chapter.fromJson(Map<String, dynamic> json) {
    title = json["title"] ?? "";
    url = json["url"] ?? "";
    uploadDate = json["upload_date"] ?? "";
    len = json["len"] ?? 0;
    scrambleId = json["scramble_id"] ?? 0;
    aid = json["aid"] ?? 0;
    images = (json["images"] ?? [])
        .map((e) => ImageInfo.fromJson(e))
        .toList()
        .cast<ImageInfo>();
  }

  Chapter.from(Chapter chapter) {
    title = chapter.title;
    url = chapter.url;
    uploadDate = chapter.uploadDate;
    len = chapter.len;
    scrambleId = chapter.scrambleId;
    aid = chapter.aid;
    images = chapter.images.map(ImageInfo.from).toList();
  }
}

@HiveType(typeId: 7)
class ComicInfo {
  @HiveField(0)
  late String id;
  @HiveField(1)
  late String title;
  @HiveField(2)
  late String thumb;
  @HiveField(3)
  late String uploadDate;
  @HiveField(4)
  late String updateDate;
  @HiveField(5)
  late String description;
  @HiveField(6)
  late List<Chapter> chapters;
  @HiveField(7)
  late String author;

  @HiveField(8)
  List<String>? works;
  @HiveField(9)
  List<String>? characters;
  @HiveField(10)
  List<String>? authors;
  @HiveField(11)
  List<String>? tags;
  @HiveField(12)
  String? star;
  @HiveField(13)
  String? views;
  @HiveField(14)
  ComicState? state;
  @HiveField(15)
  List<String>? tagsUrl;

  ComicInfo(this.id, this.title, this.thumb, this.updateDate, this.uploadDate,
      this.description, this.chapters, this.author);

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "thumb": thumb,
        "works": works,
        "characters": characters,
        "authors": authors,
        "tags": tags,
        "star": star,
        "views": views,
        "upload_date": uploadDate,
        "update_date": updateDate,
        "chapters": chapters,
        "state": ComicState.values.indexOf(state ?? ComicState.unknown),
        "description": description,
        "author": author,
        "tags_url": tagsUrl,
      };

  ComicInfo.fromJson(Map<String, dynamic> json) {
    id = json["id"] ?? "";
    title = json["title"] ?? "";
    thumb = json["thumb"] ?? "";
    works = (json["works"] ?? []).cast<String>();
    characters = (json["characters"] ?? []).cast<String>();
    authors = (json["tags"] ?? []).cast<String>();
    tags = (json["authors"] ?? []).cast<String>();
    star = json["star"] ?? "";
    views = json["views"] ?? "";
    uploadDate = json["upload_date"] ?? "";
    updateDate = json["update_date"] ?? "";
    state = ComicState.values[json["state"] ?? 0];
    description = json["description"] ?? "";
    chapters = (json["chapters"] ?? [])
        .map((e) => Chapter.fromJson(e))
        .toList()
        .cast<Chapter>();
    author = json["author"] ?? "";
    tagsUrl = (json["tags_url"] ?? []).cast<String>();
  }
}

@HiveType(typeId: 8)
enum ReaderType {
  @HiveField(0)
  scroll,
  @HiveField(1)
  album,
}

@HiveType(typeId: 9)
enum ReaderDirection {
  @HiveField(0)
  topToBottom,
  @HiveField(1)
  leftToRight,
  @HiveField(2)
  rightToLeft,
}

class CommentInfo {
  late String name;
  late String avatar;
  late String date;
  late String content;
  late List<CommentInfo> reply;
  CommentInfo(this.name, this.avatar, this.date, this.content, this.reply);
}
