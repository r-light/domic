import 'dart:collection';

import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

class Global {
  const Global._();
  static late final String defaultCover;
  static late final List<ComicSimple> shouldUpdate;
  static String comicSimpleKey(ComicSimple item) {
    return item.id + item.source;
  }

  static String comicInfoKey(String source, String id) {
    return source + id;
  }

  static String indexKey(ComicSimple record) {
    return "${Global.comicSimpleKey(record)}index";
  }

  static String reversedKey(ComicSimple record) {
    return "${Global.comicSimpleKey(record)}reversed";
  }

  static void removeIndex(ComicSimple record) {
    Hive.box(ConstantString.comicBox).delete(indexKey(record));
  }

  static void removeReversed(ComicSimple record) {
    Hive.box(ConstantString.comicBox).delete(reversedKey(record));
  }

  static void removeComicInfo(ComicSimple record) {
    Hive.box(ConstantString.comicBox)
        .delete(comicInfoKey(record.source, record.id));
  }

  static void showSnackBar(BuildContext context, String text,
      [Duration? duration]) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    duration == null
        ? ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(text),
            // behavior: SnackBarBehavior.floating,
          ))
        : ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(text),
            duration: duration,
            // behavior: SnackBarBehavior.floating,
          ));
  }

  static void remove(ComicSimple record) {
    removeIndex(record);
    removeReversed(record);
    removeComicInfo(record);
  }

  static void openUrl(String url) async {
    var uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $uri';
    }
  }
}

class ComicLocal with ChangeNotifier {
  static const defaultLimit = 100;
  static const historyKey = "savedHistory";
  static const favoriteKey = "savedFavorite";
  static const historyLimitKey = "historyLimit";

  late LinkedHashMap<String, ComicSimple> history;
  late LinkedHashMap<String, ComicSimple> favorite;
  late int _historyLimit;
  late Box box;

  ComicLocal() {
    box = Hive.box(ConstantString.comicBox);
    // load history
    history = LinkedHashMap<String, ComicSimple>.from(
        box.get(historyKey) ?? <String, ComicSimple>{});
    // load favorite
    favorite = LinkedHashMap<String, ComicSimple>.from(
        box.get(favoriteKey) ?? <String, ComicSimple>{});
    // load limit
    _historyLimit = box.get(historyLimitKey) ?? 100;
  }

  int get historyLimit => _historyLimit;

  set historyLimit(int limit) {
    _historyLimit = limit;
    if (history.length <= limit) return;
    while (history.length > limit) {
      String key = history.keys.first;
      history.remove(key);
    }
    notifyListeners();
    box.put(historyKey, history);
  }

  Future saveHistory(ComicSimple item) async {
    final key = Global.comicSimpleKey(item);
    history.remove(key);
    history[key] = item;
    notifyListeners();
    box.put(historyKey, history);
  }

  void removeHistory() {
    if (history.length <= historyLimit) return;
    while (history.length > historyLimit) {
      String key = history.keys.first;
      if (!favorite.containsKey(key)) {
        Global.remove(history[key]!);
      }
      history.remove(key);
    }
    notifyListeners();
    box.put(historyKey, history);
  }

  Future removeAllHistory() async {
    if (history.isEmpty) return;
    for (var entry in history.entries) {
      if (!favorite.containsKey(entry.key)) {
        Global.remove(entry.value);
      }
    }
    history.clear();
    notifyListeners();
    box.delete(historyKey);
  }

  bool isFavorite(ComicSimple item) {
    final key = Global.comicSimpleKey(item);
    return favorite.containsKey(key);
  }

  Future saveFavorite(ComicSimple item) async {
    final key = Global.comicSimpleKey(item);
    if (favorite.containsKey(key)) return;
    favorite[key] = item;
    notifyListeners();
    box.put(favoriteKey, favorite);
  }

  Future removeFavorite(ComicSimple item) async {
    final key = Global.comicSimpleKey(item);
    if (favorite.containsKey(key)) {
      if (!history.containsKey(key)) {
        Global.remove(favorite[key]!);
      }
      favorite.remove(key);
      notifyListeners();
      box.put(favoriteKey, favorite);
    }
  }

  Future removeAllFavorite() async {
    if (favorite.isEmpty) return;
    for (var entry in favorite.entries) {
      if (!history.containsKey(entry.key)) {
        Global.remove(entry.value);
      }
    }
    favorite.clear();
    notifyListeners();
    box.delete(favoriteKey);
  }

  void moveToFirstFromFavorite(List<ComicSimple> items) {
    if (items.isEmpty) return;
    for (var item in items) {
      var key = Global.comicSimpleKey(item);
      favorite.remove(key);
      favorite[key] = item;
    }
    notifyListeners();
  }
}

class Configs with ChangeNotifier {
  static const listViewInSearchResultKey = "listViewInSearchResult";
  static const readerDirectionKey = "readerDirection";
  static const showTimeInReaderKey = "showTimeInReader";

  late bool _listViewInSearchResult;
  late ReaderDirection _readerDirection;
  late bool _showTimeInReader;
  late Box box;

  Configs() {
    box = Hive.box(ConstantString.propertyBox);
    _listViewInSearchResult = box.get(listViewInSearchResultKey) ?? true;
    _readerDirection =
        box.get(readerDirectionKey) ?? ReaderDirection.topToBottom;
    _showTimeInReader = box.get(showTimeInReaderKey) ?? true;
  }

  bool get listViewInSearchResult => _listViewInSearchResult;

  set listViewInSearchResult(bool value) {
    _listViewInSearchResult = value;
    notifyListeners();
    box.put(listViewInSearchResultKey, value);
  }

  ReaderDirection get readerDirection => _readerDirection;

  set readerDirection(ReaderDirection value) {
    _readerDirection = value;
    notifyListeners();
    box.put(readerDirectionKey, value);
  }

  bool get showTimeInReader => _showTimeInReader;

  set showTimeInReader(bool value) {
    _showTimeInReader = value;
    notifyListeners();
    box.put(showTimeInReaderKey, value);
  }
}

class ComicSource with ChangeNotifier {
  static const sourceMapKey = "sourceMap";
  static const sourceMap18Key = "sourceMap18";

  late Map<String, bool> sourceMap;
  late Map<String, bool> source18Map;
  late Box box;

  ComicSource() {
    box = Hive.box(ConstantString.comicBox);
    sourceMap = Map<String, bool>.from(box.get(sourceMapKey) ?? {});
    source18Map = Map<String, bool>.from(box.get(sourceMap18Key) ?? {});
    if (sourceMap.isEmpty) {
      for (String source in comicMethod.keys) {
        sourceMap[source] = true;
      }
      box.put(sourceMapKey, sourceMap);
    }
    if (source18Map.isEmpty) {
      for (String source in comic18Method.keys) {
        source18Map[source] = false;
      }
      box.put(sourceMap18Key, source18Map);
    }
  }

  void reverseSourceOrDefault(String source, {bool? active}) {
    if (active == null) {
      sourceMap[source] = !sourceMap[source]!;
    } else {
      sourceMap[source] = active;
    }
    notifyListeners();
  }

  void reverseSource18OrDefault(String source, {bool? active}) {
    if (active == null) {
      source18Map[source] = !source18Map[source]!;
    } else {
      source18Map[source] = active;
    }
    notifyListeners();
  }

  void save() {
    box.put(sourceMapKey, sourceMap);
    box.put(sourceMap18Key, source18Map);
  }
}
