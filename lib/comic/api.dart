import 'package:domic/comic/extractors/baozi.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/wnacg.dart';
import 'package:domic/comic/extractors/xipi.dart';

final Map<String, Parser> comicMethod = {
  // "pufei": Pufei(),
  // "gufeng": Gufeng(),
  // "bainian": Bainian(),
  // "qimiao": Qimiao(),
  // "qiman": Qiman(),
  // "maofly": MaoFly(),
  // "kuman": Kuman(),
  "baozi": Baozi(),
  "xipi": Xipi()
};

final Map<String, Parser> comic18Method = {
  "wnacg": Wnacg()
  // "jmtt": Jmtt(),
};
