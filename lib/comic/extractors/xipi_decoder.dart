// ============================================================================
// chapter_decoder2.dart
// ============================================================================
//
// 由反编译的 chapter-decoder2.js（另一个漫画网站的章节解码器）翻译为 Dart。
//
// 与 chapter_decoder.dart（第一个网站）对比：
//   ✅ 解码管线完全相同（分段 → 重排 → 7字符分组翻转 → 字母表替换 → Base64url）
//   ✅ 字母表完全相同（自定义 64 字符表 ↔ 标准 Base64url 表）
//   ❌ 外层常量不同：前缀 qM9 / 后缀 Z7 / 标记 Vx、pL0（第一个站是 J7r/nQ/kD/W4s）
//   ❌ 本版本【没有域名白名单校验】（第一个站有 9 个域名的白名单）
//   ❌ 错误码含义不同（见下表）
//
//   错误码对照表：
//     码    本站(decoder2)含义            第一个站(decoder1)含义
//     x0    字符不在源字母表中             域名不在白名单
//     x1    前缀/后缀不匹配               字符不在源字母表中
//     x2    负载长度 <= 0                 前缀/后缀不匹配
//     x3    标记不匹配/长度校验失败       负载长度 <= 0
//     x4    （不存在）                    标记不匹配/长度校验失败
//
// 本文件把核心管线实现为参数化的 [GenericChapterDecoder]，将来遇到同族的
// 第三个站点时只需新增一行配置即可。
//
// 使用示例:
//   final data = XipiDecoder.decode(encodedString);
//   final images = (data['images'] as List).cast<String>();
//
// ============================================================================

import 'dart:convert';
import 'dart:math' as math;

/// 解码失败异常。消息码 'x0' ~ 'x3' 与原 JS 版 Error('x0') ~ Error('x3') 对应。
class XipiDecoderException implements Exception {
  final String code;
  const XipiDecoderException(this.code);

  @override
  String toString() => 'XipiDecoderException($code)';
}

/// 参数化的通用章节解码器。
///
/// 封装了这一族漫画网站共用的解码管线：
///   输入: prefix + [part1] + marker1 + [part2] + marker2 + [part3] + suffix
///   1. 校验并去掉前后缀
///   2. 按标记和计算出的三段长度分割
///   3. 重排: part3 + part1 + part2
///   4. 分组翻转: 每 [groupSize] 字符一组，奇数索引组反转（自反操作）
///   5. 字符替换: 源字母表 → 标准 Base64url 字母表（单表代换）
///   6. Base64url 解码 → UTF-8 JSON 字符串 → jsonDecode
class GenericChapterDecoder {
  /// 输入前缀（如 'qM9'）
  final String prefix;

  /// 输入后缀（如 'Z7'）
  final String suffix;

  /// 分段标记 1，位于 part1/part2 之间
  final String marker1;

  /// 分段标记 2，位于 part2/part3 之间
  final String marker2;

  /// 分组翻转的分组大小
  final int groupSize;

  /// 源字符集（输入数据使用的自定义 64 字符字母表）
  final String sourceCharset;

  /// 目标字符集（标准 Base64url 64 字符字母表）
  final String targetCharset;

  /// 各错误码（不同站点错误码含义不同，故做成可配置）
  final String codePrefixSuffix; // 前缀/后缀校验失败
  final String codePayloadLen; // 负载长度校验失败
  final String codeMarker; // 标记/长度校验失败
  final String codeBadChar; // 字符不在源字母表

  /// 预构建的字符映射表（源字符 → 目标字符），O(1) 查找。
  late final Map<String, String> _replaceMap = {
    for (var i = 0; i < sourceCharset.length; i++)
      sourceCharset[i]: targetCharset[i],
  };

  GenericChapterDecoder({
    required this.prefix,
    required this.suffix,
    required this.marker1,
    required this.marker2,
    required this.groupSize,
    required this.sourceCharset,
    required this.targetCharset,
    required this.codePrefixSuffix,
    required this.codePayloadLen,
    required this.codeMarker,
    required this.codeBadChar,
  });

  // ==========================================================================
  // 解码
  // ==========================================================================

  /// 主解码入口：将加密的章节字符串解码为 JSON 对象。
  ///
  /// 三段长度计算（N = 去掉前缀、后缀、两个标记后的负载长度）：
  ///   segLen1 = floor(N / 3)              → part3 的长度
  ///   segLen2 = floor((N - segLen1) / 2)  → part1 的长度
  ///   segLen3 = N - segLen1 - segLen2     → part2 的长度
  ///
  /// [跨语言说明] 原 JS 导出为 async 函数（window.__cimg.r），但内部全为同步
  /// 操作；Dart 版直接提供同步方法即可，语义完全等价。
  dynamic decode(String encoded) {
    // ---- 输入校验：必须以 prefix 开头、suffix 结尾 ----
    // （原 JS 还有 typeof 检查，Dart 强类型天然保证）
    if (!encoded.startsWith(prefix) || !encoded.endsWith(suffix)) {
      throw XipiDecoderException(codePrefixSuffix); // 'x1'
    }

    // ---- 去掉前缀和后缀 ----
    // encoded = prefix + core + suffix
    // Dart 与 JS 的 String.length 均按 UTF-16 码元计数；
    // 本算法输入只含单字节字母表字符，两者行为完全一致。
    final core = encoded.substring(
      prefix.length,
      encoded.length - suffix.length,
    );

    // ---- 计算负载长度 ----
    // core 结构: [part1][marker1][part2][marker2][part3]
    final payloadLen = core.length - marker1.length - marker2.length;
    if (payloadLen <= 0) {
      throw XipiDecoderException(codePayloadLen); // 'x2'
    }

    // ---- 计算三段长度 ----
    final segLen1 = payloadLen ~/ 3; // part3 长度
    final segLen2 = (payloadLen - segLen1) ~/ 2; // part1 长度
    final segLen3 = payloadLen - segLen1 - segLen2; // part2 长度（余数）

    // ---- 分割 core ----
    // 布局: [part1: segLen2][marker1][part2: segLen3][marker2][part3: segLen1]
    var offset = 0;

    final part1 = core.substring(offset, offset + segLen2);
    offset += segLen2;

    final marker1Found = core.substring(offset, offset + marker1.length);
    offset += marker1.length;

    final part2 = core.substring(offset, offset + segLen3);
    offset += segLen3;

    final marker2Found = core.substring(offset, offset + marker2.length);
    offset += marker2.length;

    final part3 = core.substring(offset); // 剩余全部

    // ---- 校验标记和长度 ----
    if (marker1Found != marker1 ||
        marker2Found != marker2 ||
        part3.length != segLen1) {
      throw XipiDecoderException(codeMarker); // 'x3'
    }

    // ---- 解码管线 ----

    // 步骤 1: 重排 — part3 + part1 + part2（打乱原始顺序）
    final reordered = part3 + part1 + part2;

    // 步骤 2: 分组翻转 — 每 groupSize 字符一组，奇数索引组反转
    final unshuffled = _groupReverse(reordered);

    // 步骤 3: 字符替换 — 自定义字母表 → 标准 Base64url 字母表
    final standardB64Url = _charReplace(unshuffled);

    // 步骤 4: Base64url 解码 → UTF-8 字符串
    final jsonStr = _base64UrlDecode(standardB64Url);

    // 步骤 5: JSON 解析 → Dart 对象
    return jsonDecode(jsonStr);
  }

  // ==========================================================================
  // 编码（附加：由解码管线逆向推导，用于测试/生成数据）
  // ==========================================================================

  /// 编码函数（解码的逆过程）。
  ///
  /// [不确定性标注] 原始混淆代码只包含解码逻辑；此编码函数按解码管线逐步
  /// 求逆推导（分组翻转自反、字符替换双射、分段长度按同样公式反推），
  /// 已通过与真实解码器的往返对照验证。但无法 100% 保证与网站服务端的
  /// 原始编码器在所有边界情况下一致。仅建议用于测试。
  String encode(Object obj) {
    // 步骤 5 逆: JSON → UTF-8 → Base64url（去掉 '=' 填充）
    final b64url =
        base64Url.encode(utf8.encode(jsonEncode(obj))).replaceAll('=', '');

    // 步骤 3 逆: 标准 Base64url 字母表 → 自定义字母表
    final replaced = String.fromCharCodes(
      b64url.codeUnits.map((c) {
        final idx = targetCharset.indexOf(String.fromCharCode(c));
        if (idx < 0) throw XipiDecoderException(codeBadChar);
        return sourceCharset.codeUnitAt(idx);
      }),
    );

    // 步骤 2 逆: 分组翻转自反，直接再执行一次
    final shuffled = _groupReverse(replaced);

    // 步骤 1 逆: 按同样公式分段，按 [part1][marker1][part2][marker2][part3] 拼接
    final n = shuffled.length;
    final s1 = n ~/ 3; // part3 长度
    final s2 = (n - s1) ~/ 2; // part1 长度

    final part3 = shuffled.substring(0, s1); // 前 s1 → part3
    final part1 = shuffled.substring(s1, s1 + s2); // 中 s2 → part1
    final part2 = shuffled.substring(s1 + s2); // 剩余 s3 → part2

    return '$prefix$part1$marker1$part2$marker2$part3$suffix';
  }

  // ==========================================================================
  // 内部步骤
  // ==========================================================================

  /// 字符替换：源字母表 → 目标字母表（单表代换密码）。
  /// 抛出 [XipiDecoderException]（码 = codeBadChar）当遇到未知字符。
  String _charReplace(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final mapped = _replaceMap[input[i]];
      if (mapped == null) {
        throw XipiDecoderException(codeBadChar); // 'x0'
      }
      buffer.write(mapped);
    }
    return buffer.toString();
  }

  /// 分组翻转：每 [groupSize] 字符一组，奇数索引组反转。
  /// 自反操作（执行两次 = 不操作），编码解码共用。
  String _groupReverse(String input) {
    final buffer = StringBuffer();
    var groupIndex = 0;
    for (var i = 0; i < input.length; i += groupSize, groupIndex++) {
      final end = math.min(i + groupSize, input.length);
      final chunk = input.substring(i, end);
      if (groupIndex % 2 != 0) {
        // 奇数索引组反转（输入为单字节字母表字符，反转码元即可）
        buffer.write(String.fromCharCodes(chunk.codeUnits.reversed));
      } else {
        buffer.write(chunk);
      }
    }
    return buffer.toString();
  }

  /// Base64url 解码 → UTF-8 字符串。
  ///
  /// [跨语言差异标注] Dart 的 base64Url.decode 是「严格规范」校验的：
  /// 末组数据字符低位比特非零（非规范 Base64）会抛 FormatException；
  /// JS 的 atob 宽松处理会直接丢弃多余比特。真实网站数据由服务端标准
  /// 编码器生成必然规范，不影响实际使用。
  String _base64UrlDecode(String input) {
    // 补齐 padding: 长度 % 4 != 0 时补 '='（Dart 解码器要求正确填充）
    var padded = input;
    final remainder = input.length % 4;
    if (remainder != 0) {
      padded += '=' * (4 - remainder);
    }
    // Dart 的 base64Url 字母表本身含 '-' '_'，无需像 JS 那样先转回 '+' '/'
    return utf8.decode(base64Url.decode(padded));
  }
}

/// 第二个网站的章节解码器（对应 chapter-decoder2.js 的 window.__cimg.r）。
///
/// 配置来源（运行时从混淆代码中提取并验证）：
///   - 前缀 'qM9'、后缀 'Z7'、标记1 'Vx'、标记2 'pL0'
///   - 分组大小 7（经真实解码器行为验证）
///   - 字母表与第一个网站完全相同
///   - 无域名白名单校验（原 JS 直接 async x => decode(x)，无 checkDomain）
class XipiDecoder {
  /// 站点专属配置。
  static final GenericChapterDecoder _impl = GenericChapterDecoder(
    prefix: 'qM9',
    suffix: 'Z7',
    marker1: 'Vx',
    marker2: 'pL0',
    groupSize: 7,
    sourceCharset:
        '_-9876543210abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
    targetCharset:
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_',
    // 本站错误码含义（与第一个站不同！）：
    codePrefixSuffix: 'x1', // 前缀/后缀不匹配
    codePayloadLen: 'x2', // 负载长度 <= 0
    codeMarker: 'x3', // 标记不匹配/长度校验失败
    codeBadChar: 'x0', // 字符不在源字母表
  );

  /// 主解码入口（同步；对应 JS 的 window.__cimg.r，其 async 仅为接口形式）。
  static dynamic decode(String encoded) => _impl.decode(encoded);

  /// 编码入口（测试用，解码的逆过程）。
  static String encode(Object obj) => _impl.encode(obj);
}

// ============================================================================
// 自测入口（dart run chapter_decoder2.dart 直接运行验证）
// ============================================================================

void main() {
  // 测试向量 1: 由真实混淆代码（Node 运行时提取的 window.__cimg.r）验证过的数据，
  // 含中文和 emoji（覆盖 UTF-8 多字节路径）
  const testVector1 =
      'qM9kPKp5iQ0HXQmI7IoB-B3Of4owKwq4aU0MX5qH65szLz0AbJpI-B0wXgnMVx2r0929pvfRpO3UawKwpU3gnOXA3IgSFsoYwPoYvkwJzs1qyDDQpHjQ3BOpL0sM2xo56x3Mj5rKCwTUMGaG3gBJws3AzHmkrMkU3Mqz2Cr4fKqSjQ0JCNmZ7';
  const expected1 = {
    'chapter': '第1话',
    'images': ['https://example.com/a.jpg', 'https://example.com/b.png'],
    'total': 2,
    'note': '中文测试✓emoji',
  };

  final result1 = XipiDecoder.decode(testVector1);
  _assertDeepEqual(result1, expected1, '测试向量 1（真实解码器验证的数据）');
  print('[PASS] 测试向量 1: 与混淆 JS 原版输出完全一致');
  print('       解码结果: $result1\n');

  // 测试向量 2: Dart encode → Dart decode 往返（多种长度，覆盖三段划分的各种余数）
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
    final encoded = XipiDecoder.encode(samples[i]);
    final decoded = XipiDecoder.decode(encoded);
    _assertDeepEqual(decoded, samples[i], '往返测试 ${i + 1}');
    print('[PASS] 往返测试 ${i + 1}: 编码→解码还原成功');
    print('       长度: ${encoded.length} 字符\n');
  }

  // 测试向量 3: 异常路径（错误码与原 JS 版一致）
  void expectException(String code, void Function() fn) {
    try {
      fn();
    } on XipiDecoderException catch (e) {
      if (e.code != code) throw '期望 $code 实际 ${e.code}';
      print('[PASS] 异常测试: 正确抛出 $code');
      return;
    }
    throw '期望抛出 $code 但未抛出';
  }

  expectException('x1', () => XipiDecoder.decode('bad-input')); // 前缀/后缀错误
  expectException('x1', () => XipiDecoder.decode('qM9XXXX')); // 缺后缀
  expectException('x2', () => XipiDecoder.decode('qM9VxpL0Z7')); // 空负载
  expectException('x3', () => XipiDecoder.decode('qM9${'A' * 20}Z7')); // 标记不匹配
  print('\n全部测试通过 ✓');
}

/// 简易深度相等断言（测试辅助）。
void _assertDeepEqual(dynamic actual, dynamic expected, String label) {
  final a = jsonEncode(actual);
  final e = jsonEncode(expected);
  if (a != e) {
    throw '断言失败 [$label]\n  实际: $a\n  期望: $e';
  }
}
