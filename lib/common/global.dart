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

  static String latestKey(ComicSimple record) {
    return "${Global.comicSimpleKey(record)}latest";
  }

  static void removeIndex(ComicSimple record) {
    Hive.box(ConstantString.comicBox).delete(indexKey(record));
  }

  static void removeReversed(ComicSimple record) {
    Hive.box(ConstantString.comicBox).delete(reversedKey(record));
  }

  static void removeLatest(ComicSimple record) {
    Hive.box(ConstantString.comicBox).delete(latestKey(record));
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
    removeLatest(record);
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
  static const favorite18Key = "savedFavorite18";
  static const historyLimitKey = "historyLimit";
  static const latestKey = "comicSimpleLatestKey";

  late LinkedHashMap<String, ComicSimple> history;
  late LinkedHashMap<String, ComicSimple> favorite;
  late LinkedHashMap<String, ComicSimple> favorite18;
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
    // load favorite18
    favorite18 = LinkedHashMap<String, ComicSimple>.from(
        box.get(favorite18Key) ?? <String, ComicSimple>{});
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
      if (!favorite.containsKey(key) && !favorite18.containsKey(key)) {
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
      if (!favorite.containsKey(entry.key) &&
          !favorite18.containsKey(entry.key)) {
        Global.remove(entry.value);
      }
    }
    history.clear();
    notifyListeners();
    box.delete(historyKey);
  }

  bool isFavorite(ComicSimple item) {
    final key = Global.comicSimpleKey(item);
    return favorite.containsKey(key) || favorite18.containsKey(key);
  }

  Future saveFavorite(ComicSimple item) async {
    final key = Global.comicSimpleKey(item);
    if (favorite.containsKey(key) || favorite18.containsKey(key)) return;
    if (comicMethod.containsKey(item.source)) {
      favorite[key] = item;
      box.put(favoriteKey, favorite);
    } else {
      favorite18[key] = item;
      box.put(favorite18Key, favorite18);
    }
    notifyListeners();
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
    } else if (favorite18.containsKey(key)) {
      if (!history.containsKey(key)) {
        Global.remove(favorite18[key]!);
      }
      favorite18.remove(key);
      notifyListeners();
      box.put(favorite18Key, favorite18);
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

  Future removeAllFavorite18() async {
    if (favorite18.isEmpty) return;
    for (var entry in favorite18.entries) {
      if (!history.containsKey(entry.key)) {
        Global.remove(entry.value);
      }
    }
    favorite18.clear();
    notifyListeners();
    box.delete(favorite18Key);
  }

  void moveToFirstFromFavorite(List<ComicSimple> items) {
    if (items.isEmpty) return;
    LinkedHashMap<String, ComicSimple> other = LinkedHashMap();
    for (var item in items) {
      var key = Global.comicSimpleKey(item);
      other[key] = item;
      favorite.remove(key);
      box.put(Global.latestKey(item), false);
    }
    other.addAll(favorite);
    favorite = other;
    notifyListeners();
    box.put(favoriteKey, favorite);
  }

  void moveToFirstFromFavorite18(List<ComicSimple> items) {
    if (items.isEmpty) return;
    LinkedHashMap<String, ComicSimple> other = LinkedHashMap();
    for (var item in items) {
      var key = Global.comicSimpleKey(item);
      other[key] = item;
      favorite18.remove(key);
      box.put(Global.latestKey(item), false);
    }
    other.addAll(favorite18);
    favorite18 = other;
    notifyListeners();
    box.put(favorite18Key, favorite18);
  }

  void swapFavoriteIndex(int index1, int index2) {
    if (index1 == index2) return;
    MapEntry<String, ComicSimple>? e1, e2;
    int i = 0;
    for (var entry in favorite.entries) {
      if (i == index1) {
        e1 = entry;
      }
      if (i == index2) {
        e2 = entry;
      }
      if (e1 != null && e2 != null) break;
      i++;
    }
    i = 0;
    LinkedHashMap<String, ComicSimple> other = LinkedHashMap();
    for (var entry in favorite.entries) {
      if (i == index1) {
        other[e2!.key] = e2.value;
        i++;
        continue;
      }
      if (i == index2) {
        other[e1!.key] = e1.value;
        i++;
        continue;
      }
      other[entry.key] = entry.value;
      i++;
    }
    favorite = other;
    notifyListeners();
    box.put(favoriteKey, favorite);
  }

  void swapFavorite18Index(int index1, int index2) {
    if (index1 == index2) return;
    MapEntry<String, ComicSimple>? e1, e2;
    int i = 0;
    for (var entry in favorite18.entries) {
      if (i == index1) {
        e1 = entry;
      }
      if (i == index2) {
        e2 = entry;
      }
      if (e1 != null && e2 != null) break;
      i++;
    }
    i = 0;
    LinkedHashMap<String, ComicSimple> other = LinkedHashMap();
    for (var entry in favorite18.entries) {
      if (i == index1) {
        other[e2!.key] = e2.value;
        i++;
        continue;
      }
      if (i == index2) {
        other[e1!.key] = e1.value;
        i++;
        continue;
      }
      other[entry.key] = entry.value;
      i++;
    }
    favorite18 = other;
    notifyListeners();
    box.put(favorite18Key, favorite18);
  }
}

class Configs with ChangeNotifier {
  static const listViewInSearchResultKey = "listViewInSearchResult";
  static const readerDirectionKey = "readerDirection";
  static const showTimeInReaderKey = "showTimeInReader";
  static const autoRefreshKey = "autoRefresh";

  late bool _listViewInSearchResult;
  late ReaderDirection _readerDirection;
  late bool _showTimeInReader;
  late bool _autoRefresh;
  late Box box;

  Configs() {
    box = Hive.box(ConstantString.propertyBox);
    _listViewInSearchResult = box.get(listViewInSearchResultKey) ?? true;
    _readerDirection =
        box.get(readerDirectionKey) ?? ReaderDirection.topToBottom;
    _showTimeInReader = box.get(showTimeInReaderKey) ?? true;
    _autoRefresh = box.get(autoRefreshKey) ?? true;
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

  bool get autoRefresh => _autoRefresh;

  set autoRefresh(bool value) {
    _autoRefresh = value;
    notifyListeners();
    box.put(autoRefreshKey, value);
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
    if (sourceMap.length != comicMethod.length) {
      for (String source in comicMethod.keys) {
        sourceMap.putIfAbsent(source, () => true);
      }
      box.put(sourceMapKey, sourceMap);
    }
    if (source18Map.isEmpty) {
      for (String source in comic18Method.keys) {
        source18Map.putIfAbsent(source, () => false);
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
