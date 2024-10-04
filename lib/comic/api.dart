import 'package:domic/comic/extractors/baozi.dart';
import 'package:domic/comic/extractors/gufeng.dart';
import 'package:domic/comic/extractors/jmtt.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/wnacg.dart';

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
  "wnacg": Wnacg()
  // "jmtt": Jmtt(),
};
