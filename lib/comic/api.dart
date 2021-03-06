import 'package:domic/comic/extractors/bainian.dart';
import 'package:domic/comic/extractors/gufeng.dart';
import 'package:domic/comic/extractors/jmtt.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/pufei.dart';
import 'package:domic/comic/extractors/qimiao.dart';

final Map<String, Parser> comicMethod = {
  "pufei": Pufei(),
  "gufeng": Gufeng(),
  "bainian": Bainian(),
  "qimiao": Qimiao(),
};

final Map<String, Parser> comic18Method = {
  "jmtt": Jmtt(),
};
