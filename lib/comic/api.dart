import 'package:domic/comic/extractors/jmtt.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/pufei.dart';

final Map<String, Parser> comicMethod = {
  "pufei": Pufei(),
};

final Map<String, Parser> comic18Method = {
  "jmtt": Jmtt(),
};
