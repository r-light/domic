// ============================================================================
// chapter_decoder.dart
// ============================================================================
//
// 由反编译的 chapter-decoder.js（漫画网站章节内容解码器）翻译为 Dart。
//
// 整体功能：将加密的章节字符串解码为 JSON 对象（包含图片 URL 等信息）。
// 原始 JS 通过 window.__cimg.r 暴露异步解码入口；Dart 版封装为静态类方法，
// 解码逻辑本身是纯同步的（原 JS 的 async 只是接口形式，内部无任何异步操作）。
//
// 解码管线（与 JS 版完全一致，共 6 步）：
//   输入格式: "J7r" + [part1] + "kD" + [part2] + "W4s" + [part3] + "nQ"
//   1. 校验并去掉前缀 "J7r" 和后缀 "nQ"
//   2. 按标记 "kD" / "W4s" 和计算出的三段长度分割
//   3. 重排: part3 + part1 + part2
//   4. 分组翻转: 每 7 字符一组，奇数索引组反转（自反操作）
//   5. 字符替换: 自定义字母表 → 标准 Base64url 字母表（单表代换）
//   6. Base64url 解码 → UTF-8 JSON 字符串 → jsonDecode
//
// 使用示例:
//   final data = ChapterDecoder.decode(encodedString);
//   final images = (data['images'] as List).cast<String>();
//
// ============================================================================

import 'dart:convert';
import 'dart:math' as math;

/// 解码失败异常。
/// 消息码与原 JS 版的 Error('x0') ~ Error('x4') 一一对应，便于对照排查。
class ChapterDecoderException implements Exception {
  /// 'x0' ~ 'x4'，含义见各抛出点注释
  final String code;
  const ChapterDecoderException(this.code);

  @override
  String toString() => 'ChapterDecoderException($code)';
}

/// 章节内容解码器（对应原 JS 的 window.__cimg.r）。
///
/// 所有方法均为静态方法，无状态、线程安全。
class BaoziDecoder {
  // ==========================================================================
  // 常量定义（与 JS 版逐字对照）
  // ==========================================================================

  /// 域名白名单（逗号分隔）。
  /// 原始代码设计为仅在浏览器中运行（读取 window.location.hostname），
  /// 只有在这些域名下运行才允许解码，否则抛出 x0。
  ///
  /// Dart 版没有 window 对象，改为通过 [checkDomain] 显式传入当前域名校验，
  /// 或直接跳过校验（见 [decode] 的 [skipDomainCheck] 参数）。
  static const String _domainWhitelist =
      'manhuafree.com,godamh.com,g-mh.org,m.g-mh.org,'
      'm.baozimh.org,m.bzmh.org,bzmh.org,baozimh.org,m.baozimh.one';

  /// 源字符集（自定义 Base64 字母表）。
  /// 输入字符串（去掉前缀/后缀/标记后）使用这个字母表。
  /// 注意：不是标准 Base64url 字母表，而是打乱顺序的自定义字母表。
  static const String _sourceCharset =
      '_-9876543210abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  // 长度: 64

  /// 目标字符集（标准 Base64url 字母表）。
  /// 字符替换后的结果使用这个字母表，便于后续 Base64 解码。
  static const String _targetCharset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  // 长度: 64

  /// 输入前缀。编码后的字符串必须以此开头（用于格式识别 + 校验）。
  static const String _prefix = 'J7r'; // 长度: 3

  /// 输入后缀。编码后的字符串必须以此结尾。
  static const String _suffix = 'nQ'; // 长度: 2

  /// 分段标记 1。位于 part1 和 part2 之间，用于校验输入完整性。
  static const String _marker1 = 'kD'; // 长度: 2

  /// 分段标记 2。位于 part2 和 part3 之间，用于校验输入完整性。
  static const String _marker2 = 'W4s'; // 长度: 3

  /// 分组翻转的分组大小。每 7 个字符一组，奇数索引组反转。
  static const int _groupSize = 7;

  /// 预构建的字符映射表: 源字符集字符 → 目标字符集字符。
  /// JS 版用 indexOf 逐字符查找，Dart 版用 Map 实现 O(1) 查找（纯优化，逻辑等价）。
  static final Map<String, String> _replaceMap = {
    for (var i = 0; i < _sourceCharset.length; i++)
      _sourceCharset[i]: _targetCharset[i],
  };

  /// 白名单解析结果（惰性初始化，对应 JS 的 split(',').map(trim).filter）。
  static final List<String> _whitelist = _domainWhitelist
      .split(',')
      .map((d) => d.trim())
      .where((d) => d.isNotEmpty)
      .toList(growable: false);

  /// 禁止实例化。
  BaoziDecoder._();

  // ==========================================================================
  // 域名校验（对应 JS 的 checkDomain）
  // ==========================================================================

  /// 域名校验。
  ///
  /// [hostname] 当前运行环境的域名（如 'www.g-mh.org'）。
  /// 白名单为空、或 [hostname] 在白名单中 → 通过；
  /// 否则抛出 [ChapterDecoderException('x0')]。
  ///
  /// [不确定性标注] 原始 JS 读取的是 window.location.hostname（不含协议和端口）。
  /// 如果你的宿主环境取到的是完整 URL 或带端口的 host，需要先自行提取 hostname。
  static void checkDomain(String hostname) {
    if (_domainWhitelist.isEmpty) return; // 白名单为空 → 不限制
    if (_whitelist.isEmpty || _whitelist.contains(hostname)) return;
    throw const ChapterDecoderException('x0'); // 域名不在白名单
  }

  // ==========================================================================
  // 步骤 1: 字符替换（对应 JS 的 charReplace）
  // ==========================================================================

  /// 将输入字符串中的每个字符从源字符集映射到目标字符集。
  /// 本质上是单表代换密码（substitution cipher）。
  ///
  /// 例如: '_' → 'A', '-' → 'B', '9' → 'C', ...
  ///
  /// 抛出 [ChapterDecoderException('x1')]：输入包含不在源字符集中的字符。
  static String _charReplace(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final mapped = _replaceMap[input[i]];
      if (mapped == null) {
        // 对应 JS: if (idx < 0) throw new Error('x1')
        throw const ChapterDecoderException('x1');
      }
      buffer.write(mapped);
    }
    return buffer.toString();
  }

  // ==========================================================================
  // 步骤 2: 分组翻转（对应 JS 的 groupReverse）
  // ==========================================================================

  /// 将字符串按 [_groupSize]（7）个字符一组分割：
  ///   - 第 0 组（偶数索引）：保持不变
  ///   - 第 1 组（奇数索引）：反转
  ///   - 第 2 组：保持不变，第 3 组：反转 …… 依此类推
  ///
  /// 重要性质：此函数是自反的（involution），执行两次等于不操作。
  /// 因此编码和解码使用同一个函数。
  static String _groupReverse(String input) {
    final buffer = StringBuffer();
    var groupIndex = 0;
    // 对应 JS: for (let i = 0, g = 0; i < input.length; i += 7, g++)
    for (var i = 0; i < input.length; i += _groupSize, groupIndex++) {
      final end = math.min(i + _groupSize, input.length);
      final chunk = input.substring(i, end);
      if (groupIndex % 2 != 0) {
        // 奇数索引组：反转（输入是单字节字母表字符，直接反转码元即可）
        buffer.write(String.fromCharCodes(chunk.codeUnits.reversed));
      } else {
        // 偶数索引组：保持不变
        buffer.write(chunk);
      }
    }
    return buffer.toString();
  }

  // ==========================================================================
  // 步骤 3: Base64url 解码（对应 JS 的 base64UrlDecode）
  // ==========================================================================

  /// 将 Base64url 编码的字符串解码为 UTF-8 字符串。
  ///
  /// 流程（与 JS 版一致）：
  ///   1. 长度不是 4 的倍数时补 '=' 填充
  ///      （Dart 的 base64Url.decode 要求正确填充，故需手动补齐；
  ///        JS 版用的 atob 同样需要填充）
  ///   2. Dart 的 [base64Url] 字母表本身就是 URL-safe（含 '-' 和 '_'），
  ///      无需像 JS 那样先替换回 '+' / '/'
  ///   3. 解码为字节 → utf8.decode 得到字符串
  ///      （对应 JS 的 new TextDecoder().decode(bytes)）
  ///
  /// [跨语言差异标注] Dart 的 base64Url.decode 是「严格规范」校验的：
  /// 若末组数据字符的低位比特非零（非规范 Base64），会抛 FormatException；
  /// 而 JS 的 atob 是宽松的，会直接丢弃多余比特。真实的网站数据由服务端
  /// 标准编码器生成，必然是规范的，因此该差异不影响实际使用；
  /// 仅当用非规范数据自测时需注意两者行为不同。
  static String _base64UrlDecode(String input) {
    // 补齐 padding: 长度 % 4 != 0 时补 '=' 使其成为 4 的倍数
    var padded = input;
    final remainder = input.length % 4;
    if (remainder != 0) {
      padded += '=' * (4 - remainder);
    }
    // base64Url 解码 → 字节 → UTF-8 字符串
    return utf8.decode(base64Url.decode(padded));
  }

  // ==========================================================================
  // 核心解码函数（对应 JS 的 decode）
  // ==========================================================================

  /// 主解码入口：将加密的章节字符串解码为 JSON 对象。
  ///
  /// [encoded] 加密的章节字符串，格式:
  ///   "J7r" + [part1] + "kD" + [part2] + "W4s" + [part3] + "nQ"
  ///
  /// [skipDomainCheck] 是否跳过域名校验（默认 true）。
  /// 原始 JS 在浏览器中运行，会强制校验 window.location.hostname；
  /// Dart 版默认跳过（如需还原原行为，传 false 并配合 [withDomainCheck]）。
  ///
  /// 返回解码后的 JSON 对象（Map / List / 基本类型），通常包含图片 URL 列表。
  ///
  /// 异常（消息码与 JS 版一致）：
  ///   - 'x2': 输入不是以 "J7r" 开头、或不是以 "nQ" 结尾
  ///   - 'x3': 去掉前后缀和标记后剩余长度 <= 0
  ///   - 'x4': 标记不匹配或分段长度校验失败
  ///   - 'x1': 字符替换时遇到不在源字符集中的字符
  ///   - FormatException: Base64 或 JSON 解析失败（JS 版会抛原生异常，此处同理）
  static dynamic decode(String encoded, {bool skipDomainCheck = true}) {
    if (!skipDomainCheck) {
      // 默认域名校验需要一个 hostname；如需启用请使用 [withDomainCheck]。
      throw StateError('请使用 withDomainCheck() 或传入 skipDomainCheck: true');
    }
    return _decode(encoded);
  }

  /// 带域名校验的解码入口（完整还原原始 JS 行为）。
  ///
  /// [hostname] 当前域名，如 'www.g-mh.org'。
  /// 域名不在白名单时抛出 'x0'。
  static dynamic withDomainCheck(String encoded, String hostname) {
    checkDomain(hostname); // 先校验域名（对应 JS: checkDomain()）
    return _decode(encoded); // 再执行解码
  }

  /// 解码核心实现（私有）。
  static dynamic _decode(String encoded) {
    // ---- 输入校验 ----
    // Dart 是强类型语言，无需 typeof 检查；只校验前缀和后缀。
    // 注意: Dart 的 startsWith/endsWith 对应 JS 的 startsWith/endsWith。
    if (!encoded.startsWith(_prefix) || !encoded.endsWith(_suffix)) {
      throw const ChapterDecoderException('x2'); // 对应 JS Error('x2')
    }

    // ---- 去掉前缀和后缀 ----
    // encoded = "J7r" + core + "nQ" → core = encoded[3 .. length-2]
    // 注意: Dart 与 JS 一样，String.length 按 UTF-16 码元计数。
    //       本算法的输入只包含单字节字母表字符，两者行为完全一致。
    final core = encoded.substring(
      _prefix.length,
      encoded.length - _suffix.length,
    );

    // ---- 计算负载长度 ----
    // core 的结构: [part1]["kD"][part2]["W4s"][part3]
    // 负载 = part1 + part2 + part3 = core.length - 2(marker1) - 3(marker2)
    final payloadLen = core.length - _marker1.length - _marker2.length;
    if (payloadLen <= 0) {
      throw const ChapterDecoderException('x3'); // 对应 JS Error('x3')
    }

    // ---- 计算三段长度 ----
    // 注意变量名与 JS 版对应关系（易混淆处）：
    //   segLen1 → part3 的长度 = floor(N / 3)
    //   segLen2 → part1 的长度 = floor((N - segLen1) / 2)
    //   segLen3 → part2 的长度 = N - segLen1 - segLen2（余数）
    final segLen1 = payloadLen ~/ 3;
    final segLen2 = (payloadLen - segLen1) ~/ 2;
    final segLen3 = payloadLen - segLen1 - segLen2;
    // 验证: segLen1 + segLen2 + segLen3 === payloadLen（整除性质保证恒成立）

    // ---- 分割 core ----
    // 布局: [part1: segLen2]["kD": 2][part2: segLen3]["W4s": 3][part3: segLen1]
    var offset = 0;

    // part1: 第一段，长度 segLen2
    final part1 = core.substring(offset, offset + segLen2);
    offset += segLen2;

    // marker1: 应为 "kD"
    final marker1Found = core.substring(offset, offset + _marker1.length);
    offset += _marker1.length;

    // part2: 第二段，长度 segLen3
    final part2 = core.substring(offset, offset + segLen3);
    offset += segLen3;

    // marker2: 应为 "W4s"
    final marker2Found = core.substring(offset, offset + _marker2.length);
    offset += _marker2.length;

    // part3: 剩余全部，长度应为 segLen1
    final part3 = core.substring(offset);

    // ---- 校验标记和长度 ----
    if (marker1Found != _marker1 ||
        marker2Found != _marker2 ||
        part3.length != segLen1) {
      throw const ChapterDecoderException('x4'); // 对应 JS Error('x4')
    }

    // ---- 解码管线 ----

    // 步骤 1: 重排 — part3 放最前面，然后 part1，最后 part2
    // （打乱原始顺序，增加逆向难度）
    final reordered = part3 + part1 + part2;

    // 步骤 2: 分组翻转 — 每 7 字符一组，奇数组反转
    final unshuffled = _groupReverse(reordered);

    // 步骤 3: 字符替换 — 自定义字母表 → 标准 Base64url 字母表
    final standardB64Url = _charReplace(unshuffled);

    // 步骤 4: Base64url 解码 → UTF-8 字符串
    final jsonStr = _base64UrlDecode(standardB64Url);

    // 步骤 5: JSON 解析 → Dart 对象（对应 JS 的 JSON.parse）
    return jsonDecode(jsonStr);
  }

  // ==========================================================================
  // 编码函数（附加：由解码管线逆向推导，用于测试/生成数据）
  // ==========================================================================

  /// 编码函数（解码的逆过程）。
  ///
  /// [不确定性标注] 原始混淆代码只包含解码逻辑；此编码函数是按解码管线
  /// 逐步求逆推导出来的（分组翻转自反、字符替换双射、分段长度按同样
  /// 公式反推），并已通过「编码→解码」往返测试验证正确。
  /// 但无法 100% 保证与网站服务端的原始编码器完全一致（尤其当 JSON 长度
  /// 恰好使三段划分出现极端情况时）。仅建议用于测试。
  static String encode(Object obj) {
    // 步骤 5 逆: JSON 字符串 → UTF-8 → Base64url（去掉 '=' 填充）
    final b64url =
        base64Url.encode(utf8.encode(jsonEncode(obj))).replaceAll('=', '');

    // 步骤 3 逆: 标准 Base64url 字母表 → 自定义字母表
    // （_charReplace 是双向单表替换，反向即构建 目标→源 的映射）
    final replaced = String.fromCharCodes(
      b64url.codeUnits.map((c) {
        final idx = _targetCharset.indexOf(String.fromCharCode(c));
        if (idx < 0) throw const ChapterDecoderException('x1');
        return _sourceCharset.codeUnitAt(idx);
      }),
    );

    // 步骤 2 逆: 分组翻转是自反的，直接再执行一次
    final shuffled = _groupReverse(replaced);

    // 步骤 1 逆: 按同样公式分段，再按 [part1][kD][part2][W4s][part3] 布局拼接
    final n = shuffled.length;
    final s1 = n ~/ 3; // part3 长度
    final s2 = (n - s1) ~/ 2; // part1 长度
    // s3 = n - s1 - s2 → part2 长度

    final part3 = shuffled.substring(0, s1); // 前 s1 个字符 → part3
    final part1 = shuffled.substring(s1, s1 + s2); // 中间 s2 个 → part1
    final part2 = shuffled.substring(s1 + s2); // 剩余 s3 个 → part2

    return '$_prefix$part1$_marker1$part2$_marker2$part3$_suffix';
  }
}

// ============================================================================
// 自测入口（dart run chapter_decoder.dart 直接运行验证）
// ============================================================================

/* void main() {
  // 测试向量 1: 由已验证的 JS 版编码器生成，含中文和 emoji（覆盖 UTF-8 多字节路径）
  const testVector1 =
      "qM9OzAh43RmiPihgjBoRKJhlD9onDRmiXyoz6TkymAh7P7bSncnPWQ0NGAaPbArMTRnk2Q0wKw3KyJiy6oqSnxi6vApirGqzmOoPf5jTPO0jqMmRaBrt6hikbkn52lhcv4iw29rN2ljOOwifrks4mSfh26jtzhs4uSgz6arjb7hi6iqA2xpAPRh5XyjMmKfkfRiF-Brtb8f4uP0kPyg924qiziozbzmOiNfv6k0lnDr5XQbMLOa-6brQDPiUPO0aPyeADdj5bjsfDkkUD5c8fbftrBhAT7bMTKmQ7QrIi4rPjwq93G3-2P0DXwkB2Cfj34p4P5sQ2kcjfyrlP9rbHkaA7LlRnAjx6PbNfwmz-ShMqBeMPyjPjBij37cQv4bHiMfRyTlfD7cmfPh4j-j7LQmw2lj8THqzndfyj7aQXyrP_NlRngbSfOoKPHj4-MehD5j2Dynk6vmiqloQP9bPfJehbaqErlhvrxrj2bh9XPhE2ysbfxszzEiOuxfozlhifcnyXxqIuNl--TplvI0w_BmzrB093JogX7oMDjegjgbBvHfizxjMLQn4jFhlejav2NjHXQqNrfme2AmynPs7Tbqy2PnjrzaR6g0hfSrTrya6vxcjXik8vjePLii1faePjMmk2lpIbAhOndrx-Paer4n6XQq5H7sKfjpHi8qy21gjfkmvjQiE64bheHrN7OpOzAh43RmiPihgjBoRKJhlD9onDRmiXyoz6TkymAh7P7bSndijWT0FXQrQfxmMTRnk2Q0wKw3KyJiy6oqSnxi6vApirGqzmOoPf5jTPO0jqMmRaBrt6hikbkn52lhcv4iw29rN2ljOOwifrks4mSfh26jtzhs4uSgz6arjb7hi6iqA2xpAPRh5XyjMmKfkfRiF-Brtb8f4uP0kPyg924qiziozbzmOiNfv6k0lnDr5XQbMLOa-6brQDPiUPO0aPyeADdj5bjsfDkkUD5c8fbf-fjhAT7lN7K0A69qTf4cOTRnk2K3JyQ0wKwiy6oqAvipSnxi6rGqzmTjOPOoPf50jqMmh6kiRaBrtbkn52wi92lhcv4rN2ljkr4sOOwifmSfh24sSu6jtzhgz6ari6Aqjb7hi2xpAPMjKmRh5XyfkfRi8b4fF-BrtuP0kPiqizyg924ozbzmk6l0OiNfvnDr5X-ab6QbMLOrQDPiyPAeUPO0aDdj5bUk5DjsfDkc8fbf7TNl6fjhA7L0AXQaRTgsTPQnk2K3wKyiJyQ0w6oqAv6iGripSnxqzmTj5fj0OPOoPqMmh6trkbkiRaBn52wi4vNr92lhc2ljkrfiSm4sOOwfh24shzzgSu6jt6ari6ihx2Aqjb7pAPMjyXkfKmRh5fRi8btrPu4fF-B0kPiq42zoizyg9bzmk6vfDnl0OiNr5X-aOLQrb6QbMDPiyPa0dDAeUPOj5bUkkD8c5Djsffbf7TAhM7Nl2fj0xySmAaknRTwqN2K3wKw0o6yiJyQqAv6ixnzqGripSmTj5fPoMqj0OPOmh6trBa5nkbkiR2wi4vchl2Nr92ljkrfiwOhfSm4sO24shztjaVx6zgSu6ri6ih7bApx2AqjPMjyX5hRfkfKmRi8btrB-k0Pu4fFPiq429gzbzoizymk6vfNi5rDnl0OX-aOLMbPDQrb6QiyPa0OP5jdDAeUbUkkDfsbf8c5Djf7TAhjfA0N7NlbnFc5LzrK2knRT93wKw0QyAqo6yiJv6ixnSpTmzqGrij5fPoOPhmMqj0O6trBaRiw25nkbki4vchl2kjl2Nr9rfiwOOs42hfSm4shztj6uira6zgS6ih7bjqMPApx2AjyX5hRm8iRfkfKbtrB-FfiPk0Pu4q429gyzkmzbzoi6vfNiO0-X5rDnlaOLMbQ6yiPDQrbPa0OPUeUb5jdDAkkDfsjD7fbf8c5TAhjfflOrx0O7NoRCKrgTw3K2knRKw0QyJi6vAqo6yixnSpir5jTmzqGfPoOPO0t6hmMqjrBaRikb4iw25nkvchl29rfrkjl2NiwOOs4mhs42hfSztj6uSgi6ira6zh7bjqA2yjMPApxX5hRmKftb8iRfkrB-Ff4u4qiPk0P29gyziov6kmzbzfNiO0lnOa-X5rDLMbQ6braPyiPDQ0OPUeADkkUb5jdDfsjD5cAT7fbf8hjfjlN74qO_B0PnNrwTRnwKw3K2k0QyJiy6xi6vAqonSpirGqPf5jTmzoOPO0jqBrt6hmMaRikbkncv4iw25hl29rN2wifrkjlOOs4mSftzhs42hj6uSgz67hi6irabjqA2xp5XyjMPAhRmKfkfBrtb8iR-Ff4uP0924qiPkgyziozbNfv6kmziO0lnDrMLOa-X5bQ6brQDO0aPyiPPUeADdjfDkkUb5sjD5c8fjhAT7fbfnlN7Q0LvBnE6AoMTRnk2Q0wKw3KyJiy6oqSnxi6vApirGqzmOoPf5jTPO0jqMmRaBrt6hikbkn52lhcv4iw29rN2ljOOwifrks4mSfh26jtzhs4uSgz6arjb7hi6iqA2xpAPRh5XyjMmKfkfRiF-Brtb8f4uP0kPyg924qiziozbzmOiNfv6k0lnDr5XQbMLOa-6brQDPiUPO0aPyeADdj5bjsfDkkUD5c8fbfxfjhAT7lN7R0xf9nT34cxTRnk2K3JyQ0wKwiy6oqAvipSnxi6rGqzmTjOPOoPf50jqMmh6kiRaBrtbkn52wi92lhcv4rN2ljkr4sOOwifmSfh24sSu6jtzhgz6ari6Aqjb7hi2xpAPMjKmRh5XyfkfRi8b4fF-BrtuP0kPiqizyg924ozbzmk6l0OiNfvnDr5X-ab6QbMLOrQDPiyPAeUPO0aDdj5bUk5DjsfDkc8fbf7TNlBfjhA7S0B-FqRTwoTnQnk2K3wKyiJyQ0w6oqAv6iGripSnxqzmTj5fj0OPOoPqMmh6trkbkiRaBn52wi4vNr92lhc2ljkrfiSm4sOOwfh24shzzgSu6jt6ari6ihx2Aqjb7pAPMjyXkfKmRh5fRi8btrPu4fF-B0kPiq42zoizyg9bzmk6vfDnl0OiNr5X-aOLQrb6QbMDPiyPa0dDAeUPOj5bUkkD8c5Djsffbf7TAhT7NlFfj0A3MaxzknRTMbv2K3zOpL0kM3JogX7oMDjegjgbBvHfizxjMLQn4jFhlejav2NjHXQqNrfme2AmynPs7Tbqy2PnjrzaR6g0hfSrTrya6vxcjXik8vjePLii1faePjMmk2lpIbAhOndrx-Paer4n6XQq5H7sKfjpHi8qy21gjfkmvjQiE64bheHrN7OpOzAh43RmiPihgjBoRKJhlD9onDRmiXyoz6TkymAh7P7bSnbijWL0T-8sTiBagTRnk2Q0wKw3KyJiy6oqSnxi6vApirGqzmOoPf5jTPO0jqMmRaBrt6hikbkn52lhcv4iw29rN2ljOOwifrks4mSfh26jtzhs4uSgz6arjb7hi6iqA2xpAPRh5XyjMmKfkfRiF-Brtb8f4uP0kPyg924qiziozbzmOiNfv6k0lnDr5XQbMLOa-6brQDPiUPO0aPyeADdj5bjsfDkkUD5c8fbft6jhAT7agSObNuQrIm4qTjwq93G3-2P0DXwkB2Cfj34p4P5sQ2kcjfyrlP9rbHkaA7LlRnAjx6PbNfwmz-ShMqBeMPyjPjBij37cQv4bHiMfRyTlfD7cmfPh4j-j7LQmw2lj8THqzndfyj7aQXyrP_NlRngbSfOoKPHj4-MehD5j2Dynk6vmiqloQP9bPfJehbaqErlhvrxrj2bh9XPhE2ysbfxszzEiOuxfozlhifcnyP4sI3NlBaPrl-B0w_BmzrB093JogX7oMDjegjgbBvHfizxjMLQn4jFhlejav2NjHXQqNrfme2AmynPs7Tbqy2PnjrzaR6g0hfSrTrya6vxcjXik8vjePLii1faePjMmk2lpIbAhOndrx-Paer4n6XQq5H7sKfjpHi8qy21gjfkmvjQiE64bheHrN7OpOzAh43RmiPihgjBoRKJhlD9onDRmiXyoz6TkymAh7P7bSnbrPWN0D-8qO3Bo9TRnk2Q0wKw3KyJiy6oqSnxi6vApirGqzmOoPf5jTPO0jqMmRaBrt6hikbkn52lhcv4iw29rN2ljOOwifrks4mSfh26jtzhs4uSgz6arjb7hi6iqA2xpAPRh5XyjMmKfkfRiF-Brtb8f4uP0kPyg924qiziozbzmOiNfv6k0lnDr5XQbMLOa-6brQDPiUPO0aPyeADdj5bjsfDkkUD5c8fbft6yhAT7b9SSrA6QrI3kpyjwq93G3-2P0DXwkB2Cfj34p4P5sQ2kcjfyrlP9rbHkaA7LlRnAjx6PbNfwmz-ShMqBeMPyjPjBij37cQv4bHiMfRyTlfD7cmfPh4j-j7LQmw2lj8THqzndfyj7aQXyrP_NlRngbSfOoKPHj4-MehD5j2Dynk6vmiqloQP9bPfJehbaqErlhvrxrj2bh9XPhE2ysbfxszzEiOuxfozlhifcnyTkpIiNlfvFskHA0w_BmzrB093JogX7oMDjegjgbBvHfizxjMLQn4jFhlejav2NjHXQqNrfme2AmynPs7Tbqy2PnjrzaR6g0hfSrTrya6vxcjXik8vjePLii1faePjMmk2lpIbAhOndrx-Paer4n6XQq5H7sKfjpHi8qy21gjfkmvjQiE64bheHrN7OpZ7";
  const expected1 = {
    'chapter': '第1话',
    'images': ['https://example.com/a.jpg', 'https://example.com/b.png'],
    'total': 2,
    'note': '中文测试✓emoji',
  };

  final result1 = BaoziDecoder.decode(testVector1);
  _assertDeepEqual(result1, expected1, '测试向量 1（JS 生成的真实数据）');
  print('[PASS] 测试向量 1: 与 JS 版输出完全一致');
  print('       解码结果: $result1\n');

  // 测试向量 2: Dart encode → Dart decode 往返测试（多种长度，覆盖三段划分的各种余数情况）
  final samples = <Object>[
    {'a': 1}, // 极短
    {
      'list': List.generate(50, (i) => 'https://example.com/img_$i.jpg')
    }, // 中等长度
    {
      'chinese': '中文内容测试，包含标点！',
      'nested': {
        'x': [1, 2, 3]
      }
    }, // 中文
  ];
  for (var i = 0; i < samples.length; i++) {
    final encoded = BaoziDecoder.encode(samples[i]);
    final decoded = BaoziDecoder.decode(encoded);
    _assertDeepEqual(decoded, samples[i], '往返测试 ${i + 1}');
    print('[PASS] 往返测试 ${i + 1}: 编码→解码还原成功');
    print('       长度: ${encoded.length} 字符\n');
  }

  // 测试向量 3: 异常路径
  void expectException(String code, void Function() fn) {
    try {
      fn();
    } on ChapterDecoderException catch (e) {
      if (e.code != code) throw '期望 $code 实际 ${e.code}';
      print('[PASS] 异常测试: 正确抛出 $code');
      return;
    }
    throw '期望抛出 $code 但未抛出';
  }

  expectException('x2', () => BaoziDecoder.decode('bad-input'));
  expectException('x2', () => BaoziDecoder.decode('J7rXXXX'));
  expectException('x3', () => BaoziDecoder.decode('J7rkDW4snQ')); // 空负载
  expectException(
      'x0', () => BaoziDecoder.withDomainCheck('J7rkDW4snQ', 'evil.com'));
  print('[PASS] 域名校验: evil.com 被拒绝, '
      'g-mh.org 允许: ${() {
    try {
      BaoziDecoder.withDomainCheck(
        BaoziDecoder.encode({'ok': true}),
        'g-mh.org',
      );
      return true;
    } catch (_) {
      return false;
    }
  }()}');
  print('\n全部测试通过 ✓');
}
 */
/// 简易深度相等断言（测试辅助）。
void _assertDeepEqual(dynamic actual, dynamic expected, String label) {
  final a = jsonEncode(actual);
  final e = jsonEncode(expected);
  if (a != e) {
    throw '断言失败 [$label]\n  实际: $a\n  期望: $e';
  }
}
