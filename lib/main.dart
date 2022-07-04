import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/common/common.dart';
import 'package:domic/common/global.dart';
import 'package:domic/common/hive.dart';
import 'package:domic/widgets/components/my_comic_home.dart';
import 'package:domic/widgets/components/my_comic_tag.dart';
import 'package:domic/widgets/components/my_download_page.dart';
import 'package:domic/widgets/components/my_setting_action.dart';
import 'package:domic/widgets/components/my_version.dart';
import 'package:domic/widgets/my_about_me.dart';
import 'package:domic/widgets/my_comic_info.dart';
import 'package:domic/widgets/my_comic_reader.dart';
import 'package:domic/widgets/my_comic_source.dart';
import 'package:domic/widgets/my_search_page.dart';
import 'package:domic/widgets/my_comic_page.dart';
import 'package:domic/widgets/my_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hive/hive.dart';
import 'package:html/parser.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Hive.registerAdapter(PageDataAdapter());
  Hive.registerAdapter(ComicSimpleAdapter());
  Hive.registerAdapter(ComicPageDataAdapter());
  Hive.registerAdapter(ImageInfoAdapter());
  Hive.registerAdapter(ChapterAdapter());
  Hive.registerAdapter(ComicInfoAdapter());
  Hive.registerAdapter(ComicStateAdapter());
  Hive.registerAdapter(ReaderDirectionAdapter());
  Hive.registerAdapter(ReaderTypeAdapter());
  await MyHive().init();

  var e = await MyDio().getHtml(RequestOptions(path: "http://www.pfmh.net/"));
  var doc = parse(e.value?.data.toString() ?? "");
  Global.defaultCover = doc.querySelector("img")?.attributes["src"] ??
      ConstantString.defaultCoverUrl;
  await initVersion();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => ComicLocal(),
        lazy: false,
      ),
      ChangeNotifierProvider(
        create: (_) => Configs(),
        lazy: false,
      ),
      ChangeNotifierProvider(
        create: (_) => ComicSource(),
        lazy: false,
      ),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ConstantString.appName,
      initialRoute: "/",
      locale: const Locale('zh', 'CN'),
      onGenerateRoute: (RouteSettings settings) {
        var routes = <String, WidgetBuilder>{
          Routes.myComicSearchResultRoute: (ctx) =>
              MyComicSearchResult(content: settings.arguments),
          Routes.myComicInfoRoute: (ctx) =>
              MyComicInfoPage(content: settings.arguments),
          Routes.myComicReaderRoute: (ctx) =>
              MyComicReader(content: settings.arguments),
          Routes.myComicHomeRoute: (ctx) =>
              MyComicHome(content: settings.arguments),
          Routes.myComicTagRoute: (ctx) =>
              MyComicTag(content: settings.arguments),
          Routes.myDownloadRoute: (ctx) =>
              MyDownloadPage(content: settings.arguments)
        };
        WidgetBuilder builder = routes[settings.name]!;
        return MaterialPageRoute(builder: (ctx) => builder(ctx));
      },
      routes: {
        Routes.myComicSearchPageRoute: (context) => const MyComicSearchPage(),
        Routes.myComicSourceRoute: (context) => const MyComicSource(),
        Routes.mySettingRoute: (context) => const MySetting(),
        Routes.myAboutMeRoute: (context) => const MyAboutMe(),
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        backgroundColor: Colors.white,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        /* dark theme settings */
      ),
      themeMode: ThemeMode.system,
      home: const MyComicPage(),
      builder: EasyLoading.init(),
    );
  }
}
