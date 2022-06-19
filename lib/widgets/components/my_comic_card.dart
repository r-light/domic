import 'package:cached_network_image/cached_network_image.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:flutter/material.dart';

class ComicSimpleItem extends StatelessWidget {
  const ComicSimpleItem({
    Key? key,
    required this.isList,
    required this.comicSimple,
  }) : super(key: key);

  static final Color lightColor = Colors.grey.shade700;
  final ComicSimple comicSimple;
  final bool isList;
  static const double fontSize = 12;

  Widget listItem() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 2,
          child: cacheImg(comicSimple.thumb),
        ),
        Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    comicSimple.title,
                    style: const TextStyle(
                      fontSize: fontSize,
                    ),
                    maxLines: 5,
                  ),
                  Text(
                    comicSimple.author,
                    style: TextStyle(fontSize: fontSize, color: lightColor),
                  ),
                  Text(
                    comicSimple.star == null ? "" : "${comicSimple.star}喜欢",
                    style: TextStyle(fontSize: fontSize, color: lightColor),
                  ),
                ],
              ),
            )),
        Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  comicSimple.sourceName,
                  style: TextStyle(
                    color: lightColor,
                    fontSize: fontSize,
                  ),
                ),
                Text(
                  comicSimple.updateDate,
                  style: TextStyle(
                    color: lightColor,
                    fontSize: fontSize,
                  ),
                ),
              ],
            )),
      ],
    );
  }

  Widget gridItem() {
    return GridTile(
      footer: Container(
        color: Colors.white54,
        child: Column(children: [
          Text(
            comicSimple.title,
            style: const TextStyle(color: Colors.black, fontSize: fontSize),
            textAlign: TextAlign.center,
            maxLines: 1,
            // overflow: TextOverflow.ellipsis,
          ),
          Text(
            comicSimple.author,
            style: TextStyle(color: Colors.grey[800], fontSize: fontSize),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
          Text(
            comicSimple.sourceName,
            style: const TextStyle(color: Colors.black, fontSize: fontSize),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ]),
      ),
      child: cacheImg(comicSimple.thumb),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isList ? listItem() : gridItem();
  }

  Widget cacheImg(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      errorWidget: (context, url, error) => const Center(
        child: Icon(
          Icons.error,
          color: Colors.red,
        ),
      ),
    );
  }
}
