import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/common/logger.dart';
import 'package:domic/widgets/components/my_status.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ImageInfo;
import 'package:hive/hive.dart';
import 'package:image/image.dart' as image_tool;

double getRealHeight(
    double maxWidth, int? width, int? height, double defaultHeight) {
  if (width == null || height == null || width == 0) return defaultHeight;
  return maxWidth / width * height;
}

Map<String, dynamic> convertJmttHelper(Map<String, dynamic> params) {
  // ignore: prefer_function_declarations_over_variables
  var func = (int aid, String pid) {
    int a = 10;

    var m = md5.convert(utf8.encode(aid.toString() + pid)).toString();
    var hash = m.codeUnitAt(m.length - 1);
    if (aid >= 268850 && aid <= 421925) {
      hash %= 10;
    } else if (aid >= 421926) {
      hash %= 8;
    }

    if (hash >= 0 && hash <= 9) {
      a = (hash + 1) * 2;
    }
    return a;
  };

  Map<String, dynamic> map = {};
  var bytes = params["bytes"];
  image_tool.Image? rawImg;
  var src = params["src"];
  if (src.endsWith("jpg")) {
    rawImg = image_tool.decodeJpg(bytes);
  } else if (src.endsWith("png")) {
    rawImg = image_tool.decodePng(bytes);
  } else {
    rawImg = image_tool.decodeImage(bytes);
  }
  if (rawImg == null) return map..putIfAbsent("data", () => Uint8List(0));
  var height = rawImg.height, width = rawImg.width;
  map["height"] = height;
  map["width"] = width;
  var target = image_tool.Image(width, height);
  var s = func(params["aid"]!, params["pid"]!.split(".").first);
  var left = height % s;
  for (int m = 0; m < s; m++) {
    var c = height ~/ s, g = c * m, h = height - c * (m + 1) - left;
    if (m == 0) {
      c += left;
    } else {
      g += left;
    }
    image_tool.drawImage(target, rawImg,
        dstX: 0,
        dstY: g,
        dstW: width,
        dstH: c,
        srcX: 0,
        srcY: h,
        srcH: c,
        srcW: width);
  }
  var res = image_tool.encodeJpg(target, quality: 90);
  return map..putIfAbsent("data", () => res);
}

Widget waiting(double? width, double? height) {
  return SizedBox(width: width, height: height, child: const MyWaiting());
}

Widget error(double? width, double? height) {
  return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: Icon(
          Icons.error,
          color: Colors.red,
        ),
      ));
}

Widget normalImageWidget(MapEntry<int, ImageInfo> entry, dynamic setter,
    {double? height,
    double? width,
    double? statusWidth,
    double? statusHeight,
    Map<String, String>? header}) {
  var info = entry.value;
  return ExtendedImage.network(
    headers: header,
    info.src,
    height: height,
    width: width,
    loadStateChanged: (ExtendedImageState state) {
      if (state.extendedImageLoadState == LoadState.loading) {
        return waiting(statusWidth, statusHeight);
      }
      if (state.extendedImageLoadState == LoadState.failed) {
        return error(statusWidth, statusHeight);
      }
      if (info.height == null && info.width == null) {
        setter(entry.key, state.extendedImageInfo!.image.width,
            state.extendedImageInfo!.image.height);
      }
      info.height = state.extendedImageInfo!.image.height;
      info.width = state.extendedImageInfo!.image.width;
      return null;
    },
    timeLimit: const Duration(seconds: 5),
    timeRetry: const Duration(seconds: 1),
  );
}

class MyJmttComicImage extends StatefulWidget {
  final ImageInfo imageInfo;
  final String source;
  final int index;
  final int? scrambleId;
  final int? aid;
  final double? height;
  final double? width;
  final double? statusHeight;
  final double? statusWidth;
  final dynamic setter;

  const MyJmttComicImage({
    Key? key,
    required this.imageInfo,
    required this.setter,
    required this.index,
    required this.source,
    this.scrambleId,
    this.aid,
    this.height,
    this.width,
    this.statusHeight,
    this.statusWidth,
  }) : super(key: key);

  @override
  State<MyJmttComicImage> createState() => _MyJmttComicImageState();
}

class _MyJmttComicImageState extends State<MyJmttComicImage>
    with AutomaticKeepAliveClientMixin {
  late Future<Uint8List> jmttBytes = loadingJmttImage();
  late var downloadBox = Hive.lazyBox(ConstantString.comic18DownloadBox);
  late Future downloadBytes = downloadBox.get(widget.imageInfo.src);

  Future<Uint8List> loadingJmttImage() async {
    if (widget.aid! < widget.scrambleId!) return Uint8List(0);

    var lazyBoxName = ConstantString.sourceToLazyBox[widget.source]!;
    var key = widget.imageInfo.src;
    Map res;
    if (MyHive().isInHive(lazyBoxName, key)) {
      res = await MyHive().getInHive(lazyBoxName, key);
    } else {
      var resp = await MyDio().dio.get<List<int>>(
            key,
            options: Options(responseType: ResponseType.bytes),
          );
      var bytes = resp.data;
      if (bytes == null) return Uint8List(0);
      Map<String, dynamic> params = {};
      params["src"] = widget.imageInfo.src;
      params["bytes"] = bytes;
      params["aid"] = widget.aid!;
      params["pid"] = widget.imageInfo.pid!;
      res = await compute(convertJmttHelper, params);
      MyHive().putInHive(lazyBoxName, key, res);
    }
    widget.imageInfo.height = res["height"];
    widget.imageInfo.width = res["width"];
    return res["data"];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // download
    if (downloadBox.containsKey(widget.imageInfo.src)) {
      return FutureBuilder(
        future: downloadBytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return error(widget.statusWidth, widget.statusHeight);
          }
          if (!snapshot.hasData) {
            return waiting(widget.statusWidth, widget.statusHeight);
          }
          var image = Image.memory(
            snapshot.requireData as Uint8List,
            width: widget.width,
            height: widget.height,
          );
          image.image
              .resolve(const ImageConfiguration())
              .addListener(ImageStreamListener((info, _) {
            widget.imageInfo.height = info.image.height;
            widget.imageInfo.width = info.image.width;
          }));
          return image;
        },
      );
    }
    // jmtt
    if (widget.source == ConstantString.jmtt) {
      if (widget.aid! < widget.scrambleId!) {
        return normalImageWidget(
          MapEntry(widget.index, widget.imageInfo),
          widget.setter,
          width: widget.width,
          height: widget.height,
          statusWidth: widget.statusWidth,
          statusHeight: widget.statusHeight,
        );
      }
      // scramble
      return FutureBuilder<Uint8List>(
        future: jmttBytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return error(widget.statusWidth, widget.statusHeight);
          }
          if (!snapshot.hasData || snapshot.requireData.isEmpty) {
            return waiting(widget.statusWidth, widget.statusHeight);
          }
          return Image.memory(
            snapshot.requireData,
            width: widget.width,
            height: widget.height,
          );
        },
      );
    } else {
      return normalImageWidget(
        MapEntry(widget.index, widget.imageInfo),
        widget.setter,
        width: widget.width,
        height: widget.height,
        statusWidth: widget.statusWidth,
        statusHeight: widget.statusHeight,
      );
    }
  }

  int getScrambleNum(int aid, String pid) {
    int a = 10;
    if (aid >= 268850) {
      var m = md5.convert(utf8.encode(aid.toString() + pid)).toString();
      var hash = m.codeUnitAt(m.length - 1);
      hash %= 10;
      return (hash + 1) * 2;
    }
    return a;
  }

  @override
  bool get wantKeepAlive => true;
}
