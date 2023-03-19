import 'package:dio/dio.dart';

class MyDio {
  static MyDio? _instance;
  late Dio dio;

  MyDio._internal() {
    dio = Dio();
    dio.options.connectTimeout = 5000;
    dio.options.receiveTimeout = 10000;
    _instance = this;
  }

  factory MyDio() => _instance ?? MyDio._internal();

  Future<MapEntry<int, Response?>> getHtml(
      RequestOptions requestOptions) async {
    try {
      var resp = await MyDio().dio.fetch(requestOptions);
      return MapEntry(resp.statusCode ?? 0, resp);
    } catch (e) {
      return const MapEntry(-1, null);
    }
  }
}
