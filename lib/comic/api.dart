import 'package:domic/comic/extractors/baozi.dart';
import 'package:domic/comic/extractors/gufeng.dart';
import 'package:domic/comic/extractors/jmtt.dart';
import 'package:domic/comic/extractors/parser_entity.dart';

final Map<String, Parser> comicMethod = {
  // "pufei": Pufei(),
  "gufeng": Gufeng(),
  // "bainian": Bainian(),
  // "qimiao": Qimiao(),
  // "qiman": Qiman(),
  // "maofly": MaoFly(),
  // "kuman": Kuman(),
  "baozi": Baozi(),
};

final Map<String, Parser> comic18Method = {
  "jmtt": Jmtt(),
};

final Map<String, ParserWebview> webviewMethod = {"baozi": Baozi()};
