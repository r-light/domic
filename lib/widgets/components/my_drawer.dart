import 'package:cached_network_image/cached_network_image.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({
    Key? key,
  }) : super(key: key);

  static const topPadding = 38.0;
  static const leftPadding = 10.0;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: MediaQuery.removePadding(
          context: context,
          // removeTop: true,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const MyCover(),
                ListTile(
                  leading: const Icon(
                    Icons.import_contacts,
                  ),
                  title: const Text(ConstantString.comicPageTitle),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.source,
                  ),
                  title: const Text(ConstantString.source),
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.myComicSourceRoute),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.settings,
                  ),
                  title: const Text(ConstantString.setting),
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.mySettingRoute),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                  ),
                  title: const Text(ConstantString.about),
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.myAboutMeRoute),
                ),
                Expanded(
                  child: ListView(
                    children: getComicSource(context),
                  ),
                ),
              ],
            ),
          )),
    );
  }

  List<Widget> getComicSource(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(
          Icons.import_contacts,
        ),
        title: Text(sourcesName["pufei"]!),
        onTap: () =>
            Navigator.pushNamed(context, Routes.myComicHomeRoute, arguments: {
          "source": "pufei",
        }),
      ),
    ];
  }
}

class MyCover extends StatefulWidget {
  const MyCover({
    Key? key,
  }) : super(key: key);

  @override
  State<MyCover> createState() => _MyCoverState();
}

class _MyCoverState extends State<MyCover> {
  @override
  Widget build(BuildContext context) {
    var favorite = Provider.of<ComicLocal>(context, listen: true).favorite;
    var history = Provider.of<ComicLocal>(context, listen: true).history;
    return SizedBox(
      height: MediaQuery.of(context).size.height / 3,
      child: CachedNetworkImage(
        imageUrl: favorite.isNotEmpty
            ? favorite.values.last.thumb
            : (history.isNotEmpty
                ? history.values.last.thumb
                : Global.defaultCover),
        fit: BoxFit.cover,
        width: double.infinity,
      ),
    );
  }
}
