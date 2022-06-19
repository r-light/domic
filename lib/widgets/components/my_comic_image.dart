import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_status.dart';
import 'package:flutter/material.dart' hide ImageInfo;
import 'package:image/image.dart' as image_tool;

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

Widget normalImageWidget(String url,
    {double? height,
    double? width,
    double? statusWidth,
    double? statusHeight}) {
  return CachedNetworkImage(
    imageUrl: url,
    fadeInDuration: Duration.zero,
    fadeOutDuration: Duration.zero,
    height: height,
    width: width,
    placeholder: (context, url) => waiting(statusWidth, statusHeight),
    errorWidget: (context, url, error) => Container(),
  );
}

class MyJmttComicImage extends StatefulWidget {
  final ImageInfo imageInfo;
  final String source;
  final int? scrambleId;
  final int? aid;
  final double? height;
  final double? width;
  final double? statusHeight;
  final double? statusWidth;

  const MyJmttComicImage({
    Key? key,
    required this.imageInfo,
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

  Future<Uint8List> loadingJmttImage() async {
    if (widget.aid! < widget.scrambleId!) return Uint8List(0);

    var lazyBoxName = ConstantString.sourceToLazyBox[widget.source]!;
    var key = widget.imageInfo.src;
    if (MyHive().isInHive(lazyBoxName, key)) {
      return await MyHive().getInHive(lazyBoxName, key);
    } else {
      var resp = await MyDio().dio.get<List<int>>(key,
          options: Options(responseType: ResponseType.bytes));
      var bytes = resp.data;
      if (bytes == null) return Uint8List(0);
      image_tool.Image? rawImg;
      if (widget.imageInfo.src.endsWith("jpg")) {
        rawImg = image_tool.decodeJpg(bytes);
      } else if (widget.imageInfo.src.endsWith("png")) {
        rawImg = image_tool.decodePng(bytes);
      } else {
        rawImg = image_tool.decodeImage(bytes);
      }
      if (rawImg == null) return Uint8List(0);

      var height = rawImg.height, width = rawImg.width;
      widget.imageInfo.height = height;
      widget.imageInfo.width = width;
      var target = image_tool.Image(width, height);
      var s =
          getScrambleNum(widget.aid!, widget.imageInfo.pid!.split(".").first);
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
      MyHive().putInHive(lazyBoxName, key, res);
      return res as Uint8List;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // jmtt
    if (widget.source == ConstantString.jmtt) {
      if (widget.aid! < widget.scrambleId!) {
        return normalImageWidget(widget.imageInfo.src,
            width: widget.width,
            height: widget.height,
            statusWidth: widget.statusWidth,
            statusHeight: widget.statusHeight);
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
      return normalImageWidget(widget.imageInfo.src,
          width: widget.width,
          height: widget.height,
          statusWidth: widget.statusWidth,
          statusHeight: widget.statusHeight);
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
