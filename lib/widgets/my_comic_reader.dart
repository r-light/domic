import 'package:domic/comic/api.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/global.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_comic_image.dart';
import 'package:flutter/material.dart' hide ImageInfo;
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

// import 'package:image_pixels/image_pixels.dart';

import '../common/common.dart';

String comicChapterKey(String source, String id, int idx) {
  return "$source$id@$idx";
}

class MyComicReader extends StatefulWidget {
  /*  "chapters": seqList,
      "index": _reversed ? _length! - 1 - _index! : _index!,
      "source": record.source,
      "comicInfo": snapshot.requireData,
   */
  const MyComicReader({Key? key, required this.content}) : super(key: key);
  final dynamic content;

  @override
  State<MyComicReader> createState() => _MyComicReaderState();
}

class _MyComicReaderState extends State<MyComicReader> {
  late ReaderType _readerType = ReaderType.scroll;

  @override
  Widget build(BuildContext context) {
    return buildReader();
  }

  Widget buildReader() {
    switch (_readerType) {
      case ReaderType.scroll:
        return ScrollReader(
          content: widget.content,
        );
      case ReaderType.album:
        return ScrollReader(
          content: widget.content,
        );
    }
  }
}

class ScrollReader extends StatefulWidget {
  /*  "chapters": seqList,
      "index": _reversed ? _length! - 1 - _index! : _index!,
      "source": record.source,
      "comicInfo": snapshot.requireData,
   */
  const ScrollReader({
    Key? key,
    required this.content,
  }) : super(key: key);

  final dynamic content;

  @override
  State<ScrollReader> createState() => _ScrollReaderState();
}

class _ScrollReaderState extends State<ScrollReader> {
  final ScrollController _controller =
      ScrollController(keepScrollOffset: false);
  late bool _isLoading;
  late bool _hasMore;
  late int nextEp;
  final List<MapEntry<int, ImageInfo>> imageInfos = [];
  final List<MapEntry<int, int>> aidScrambleId = [];
  final List<double> sum = [];
  late final maxHeight = MediaQuery.of(context).size.height;
  late final maxWidth = MediaQuery.of(context).size.width;
  late final maxStatusHeightInJmtt = maxHeight / 3;
  late final maxStatusHeight = maxHeight / 5;
  late Axis axis;

  void _onScroll() {
    int idx = 0;
    double offset = _controller.offset;
    while (idx < sum.length) {
      offset -= sum[idx];
      if (offset <= 0) {
        break;
      }
      idx++;
    }
    if (idx >= sum.length) idx--;
    if (widget.content["reversed"]) {
      Hive.box(ConstantString.comicBox).put(
          Global.indexKey(widget.content["comicSimple"]),
          widget.content["index"] + idx);
    } else {
      Hive.box(ConstantString.comicBox).put(
          Global.indexKey(widget.content["comicSimple"]),
          widget.content["reversedIndex"] - idx);
    }
  }

  @override
  void initState() {
    _controller.addListener(_onScroll);
    super.initState();

    _isLoading = true;
    _hasMore = true;
    nextEp = widget.content["index"];
    loadNextEpisode();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    super.dispose();
  }

  void setter(int idx, int width, int height) {
    double real = 0, placeholder = 0;
    if (widget.content["source"] == ConstantString.jmtt) {
      real = axis == Axis.vertical
          ? (getRealHeight(maxWidth, width, height, maxStatusHeightInJmtt))
          : maxWidth;
      placeholder = axis == Axis.vertical ? maxStatusHeightInJmtt : maxWidth;
    } else {
      real = axis == Axis.vertical
          ? (getRealHeight(maxWidth, width, height, maxStatusHeight))
          : maxWidth;
      placeholder = axis == Axis.vertical ? maxStatusHeight : maxWidth;
    }
    sum[idx] += real - placeholder;
  }

  void loadNextEpisode() async {
    _isLoading = true;
    ComicInfo comicInfo = widget.content["comicInfo"];
    String source = widget.content["source"];
    var lazyBoxName = ConstantString.sourceToLazyBox[source]!;
    var key = comicChapterKey(source, comicInfo.id, nextEp);
    if (MyHive().isInHive(lazyBoxName, key)) {
      comicInfo.chapters[nextEp] = await MyHive().getInHive(lazyBoxName, key);
    } else {
      var parser = comicMethod[source] ?? comic18Method[source]!;
      await parser.comicByChapter(comicInfo, idx: nextEp);
      MyHive().putInHive(lazyBoxName, key, comicInfo.chapters[nextEp]);
    }
    Future.delayed(Duration.zero, () {
      setState(() {
        sum.add(0);
        for (var imageInfo in comicInfo.chapters[nextEp].images) {
          imageInfos.add(
              MapEntry(nextEp - (widget.content["index"] as int), imageInfo));
          aidScrambleId.add(MapEntry(comicInfo.chapters[nextEp].aid ?? 0,
              comicInfo.chapters[nextEp].scrambleId ?? 0));
          if (widget.content["source"] == ConstantString.jmtt) {
            sum[sum.length - 1] +=
                axis == Axis.vertical ? maxStatusHeightInJmtt : maxWidth;
          } else {
            sum[sum.length - 1] +=
                axis == Axis.vertical ? maxStatusHeight : maxWidth;
          }
        }
        _isLoading = false;
        nextEp++;
        if (nextEp >= comicInfo.chapters.length) {
          _hasMore = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    axis = context.select((Configs configs) => configs.readerDirection) ==
            ReaderDirection.topToBottom
        ? Axis.vertical
        : Axis.horizontal;
    var reversed =
        context.select((Configs configs) => configs.readerDirection) ==
                ReaderDirection.rightToLeft
            ? true
            : false;
    var cachedNum = widget.content["source"] == ConstantString.jmtt
        ? context.select((Configs configs) => configs.cacheImage18Num)
        : context.select((Configs configs) => configs.cacheImageNum);

    return Container(
      color: Colors.black,
      child: ListView.builder(
        scrollDirection: axis,
        controller: _controller,
        reverse: reversed,
        cacheExtent: axis == Axis.horizontal
            ? maxWidth * cachedNum
            : maxHeight * cachedNum,
        itemBuilder: (context, index) {
          if (index >= imageInfos.length) {
            if (!_isLoading && _hasMore) {
              loadNextEpisode();
            }
            return _hasMore ? waiting(maxWidth, maxHeight) : Container();
          }
          if (widget.content["source"] == ConstantString.jmtt) {
            return MyJmttComicImage(
              imageInfo: imageInfos[index].value,
              index: imageInfos[index].key,
              setter: setter,
              source: widget.content["source"],
              aid: aidScrambleId[index].key,
              scrambleId: aidScrambleId[index].value,
              width: maxWidth,
              statusWidth: maxWidth,
              statusHeight: axis == Axis.horizontal
                  ? maxHeight
                  : getRealHeight(maxWidth, imageInfos[index].value.width,
                      imageInfos[index].value.height, maxStatusHeightInJmtt),
            );
          } else {
            return normalImageWidget(imageInfos[index], setter,
                width: maxWidth,
                statusWidth: maxWidth,
                statusHeight: axis == Axis.horizontal
                    ? maxHeight
                    : getRealHeight(maxWidth, imageInfos[index].value.width,
                        imageInfos[index].value.height, maxStatusHeight)
                // maxHeight / 5,
                );
          }
        },
        itemCount: _hasMore ? imageInfos.length + 1 : imageInfos.length,
      ),
    );
  }

  double getRealHeight(
      double maxWidth, int? width, int? height, double dafaultHeight) {
    if (width == null || height == null || width == 0) return dafaultHeight;
    return maxWidth / width * height;
  }
}
