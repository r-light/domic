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
  late Axis axis;
  late bool reversed;
  late int cachedNum;
  final List<MapEntry<int, ImageInfo>> imageInfos = [];
  final List<MapEntry<int, int>> aidScrambleId = [];
  final List<double> sum = [];
  late final maxHeight = MediaQuery.of(context).size.height;
  late final maxWidth = MediaQuery.of(context).size.width;
  late final maxStatusHeightInJmtt = maxHeight / 3;
  late final maxStatusHeight = maxHeight / 5;
  double _imageIdx = 0;
  bool _showFrame = false;

  // this is used to load next episode
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

  void _onScrollImage() {
    int idx = 0;
    double offset = _controller.offset;
    while (idx < imageInfos.length) {
      if (axis == Axis.vertical) {
        var placeholder = widget.content["source"] == ConstantString.jmtt
            ? maxStatusHeightInJmtt
            : maxStatusHeight;
        offset -= getRealHeight(maxWidth, imageInfos[idx].value.width,
            imageInfos[idx].value.height, placeholder);
      } else {
        offset -= maxWidth;
      }
      if (offset <= 0) {
        break;
      }
      idx++;
    }
    if (idx == imageInfos.length) idx--;
    if (idx != _imageIdx.round()) {
      setState(() {
        _imageIdx = idx.toDouble();
      });
    }
    return;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
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
    var key = Global.comicChapterKey(source, comicInfo.id, nextEp);
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
    reversed = context.select((Configs configs) => configs.readerDirection) ==
            ReaderDirection.rightToLeft
        ? true
        : false;
    cachedNum = widget.content["source"] == ConstantString.jmtt
        ? context.select((Configs configs) => configs.cacheImage18Num)
        : context.select((Configs configs) => configs.cacheImageNum);

    var showBottomSlider =
        context.select((Configs configs) => configs.showBottomSlider);
    if (showBottomSlider) {
      _controller.addListener(_onScrollImage);
      return Stack(
        children: [buildReader(), buildFrame()],
      );
    } else {
      return buildReader();
    }
  }

  Widget buildReader() {
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

  Widget buildFrame() {
    return Column(
      children: [
        // showFrame ? _buildAppBar() : Container(),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() {
                _showFrame = !_showFrame;
              });
            },
            child: Container(),
          ),
        ),
        _showFrame ? _buildSlider() : Container()
      ],
    );
  }

  Widget _buildSlider() {
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          thumbColor: Colors.white,
          inactiveTickMarkColor: Colors.transparent,
          activeTickMarkColor: Colors.transparent,
        ),
        child: Slider(
          min: 0,
          max: (imageInfos.length - 1).toDouble(),
          divisions: imageInfos.length,
          value: _imageIdx,
          label: (_imageIdx.round() + 1).toString(),
          onChanged: (value) {
            _imageIdx = value;
            double pos = 0;
            for (int i = 0, length = value.round(); i < length; i++) {
              if (axis == Axis.vertical) {
                var placeholder =
                    widget.content["source"] == ConstantString.jmtt
                        ? maxStatusHeightInJmtt
                        : maxStatusHeight;
                pos += getRealHeight(maxWidth, imageInfos[i].value.width,
                    imageInfos[i].value.height, placeholder);
              } else {
                pos += maxWidth;
              }
            }
            setState(() => _controller.jumpTo(pos));
          },
        ),
      ),
    );
  }
}
