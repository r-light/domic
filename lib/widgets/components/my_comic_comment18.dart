import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/jmtt.dart';
import 'package:domic/widgets/components/my_status.dart';
import 'package:flutter/material.dart';

class MyComicComment18 extends StatefulWidget {
  final String id;

  const MyComicComment18({
    required this.id,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => MyComicComment18State();
}

class MyComicComment18State extends State<MyComicComment18>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  bool hasMore = true;
  int currentPage = 1;
  List<CommentInfo> comments = [];
  late Color fontColor =
      MediaQuery.of(context).platformBrightness == Brightness.dark
          ? Colors.white
          : Colors.grey.shade800;
  late Color iconColor =
      MediaQuery.of(context).platformBrightness == Brightness.dark
          ? Colors.white
          : Colors.grey;
  void loadMoreComments() async {
    isLoading = true;
    var id = widget.id;
    var entry = await Jmtt().commentById(id, page: currentPage);
    comments.addAll(entry.key);
    setState(() {
      isLoading = false;
      currentPage++;
      hasMore = entry.value;
    });
  }

  @override
  void initState() {
    super.initState();
    loadMoreComments();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading && comments.isEmpty) {
      return const MyWaiting();
    }

    return ListView.separated(
        padding: const EdgeInsets.all(5.0),
        itemBuilder: (context, index) {
          if (index >= comments.length) {
            if (!isLoading) {
              loadMoreComments();
            }
            return const MyWaiting();
          }
          var comment = comments[index];
          return commentListTile(comment);
        },
        separatorBuilder: (context, index) => const Divider(
              thickness: 4,
            ),
        itemCount: hasMore ? comments.length + 1 : comments.length);
  }

  Widget cacheImg(String url) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(10000.0),
        child: CachedNetworkImage(
          width: 60,
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
        ));
  }

  @override
  bool get wantKeepAlive => true;

  Widget commentListTile(CommentInfo comment) {
    return ListTile(
      leading: cacheImg(comment.avatar),
      title: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              comment.name.substring(0, min(comment.name.length, 10)),
              style: TextStyle(color: fontColor, fontSize: 14),
            ),
            Text(comment.date, style: TextStyle(color: fontColor, fontSize: 12))
          ],
        ),
      ),
      trailing: SizedBox(
        width: 50,
        child: comment.reply.isEmpty
            ? TextButton.icon(
                icon: Icon(Icons.comment, color: iconColor),
                label: Text(
                  comment.reply.length.toString(),
                  style: TextStyle(color: iconColor),
                ),
                onPressed: () {},
              )
            : TextButton.icon(
                icon: const Icon(
                  Icons.comment,
                ),
                label: Text(
                  comment.reply.length.toString(),
                  style: TextStyle(color: iconColor),
                ),
                onPressed: () {
                  if (comment.reply.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) {
                      return Scaffold(
                          appBar: AppBar(),
                          body: innerCommentListTile(comment));
                    }),
                  );
                },
              ),
      ),
      subtitle: Text(
        comment.content,
        style: TextStyle(color: fontColor),
      ),
    );
  }

  Widget innerCommentListTile(CommentInfo root) {
    // ignore: prefer_function_declarations_over_variables
    var tile = (CommentInfo comment) {
      return ListTile(
        leading: cacheImg(comment.avatar),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment.name.substring(0, min(comment.name.length, 10)),
                style: TextStyle(color: fontColor, fontSize: 14),
              ),
              Text(comment.date,
                  style: TextStyle(color: fontColor, fontSize: 12))
            ],
          ),
        ),
        subtitle: Text(
          comment.content,
          style: TextStyle(color: fontColor),
        ),
      );
    };

    return ListView.separated(
        padding: const EdgeInsets.all(5.0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return tile(root);
          }
          return tile(root.reply[index - 1]);
        },
        separatorBuilder: (context, index) => const Divider(
              thickness: 4,
            ),
        itemCount: root.reply.length + 1);
  }
}
