/*
 * @Author: r-light 414271394@qq.com
 * @Date: 2023-02-25 17:34:02
 * @LastEditors: r-light 414271394@qq.com
 * @LastEditTime: 2023-09-09 18:19:21
 * @FilePath: /domic/lib/comic/api.dart
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
import 'package:domic/comic/extractors/gufeng.dart';
import 'package:domic/comic/extractors/jmtt.dart';
import 'package:domic/comic/extractors/kuman.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/qiman.dart';

final Map<String, Parser> comicMethod = {
  // "pufei": Pufei(),
  "gufeng": Gufeng(),
  // "bainian": Bainian(),
  // "qimiao": Qimiao(),
  "qiman": Qiman(),
  // "maofly": MaoFly(),
  "kuman": Kuman(),
  // "baozi": Baozi(),
};

final Map<String, Parser> comic18Method = {
  "jmtt": Jmtt(),
};
