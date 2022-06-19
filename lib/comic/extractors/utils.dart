import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';

String gbkUrlLenEncode(String input, {String sep = "%"}) {
  List<int> gbk = gbk_bytes.encode(input);
  var hex = '';
  for (var i in gbk) {
    hex += sep + i.toRadixString(16).toUpperCase();
  }
  return hex;
}

String gbkDecoder(List<int> responseBytes, RequestOptions options,
    ResponseBody responseBody) {
  return gbk_bytes.decode(responseBytes);
}

String trimAllLF(String s) {
  return s.replaceAll('\n', " ").trim();
}
