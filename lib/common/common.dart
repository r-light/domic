class ConstantString {
  static const appName = "domic";
  static const favorite = "收藏";
  static const favorite18 = "收藏";
  static const history = "历史";
  static const source = "图源";
  static const setting = "设置";
  static const about = "关于";
  static const comicPageTitle = "漫画";
  static const searchPageTitle = "搜索";

  static const comicDefaultSearchContent = "请输入您的内容...";

  static const pufei = "pufei";
  static const jmtt = "jmtt";
  static const gufeng = "gufeng";
  static const bainian = "bainian";
  static const qimiao = "qimiao";
  static const qiman = "qiman";

  static const pufeiCacheBox = "pufeiCacheLazy";
  static const jmttCacheBox = "jmttCacheLazy";
  static const gufengCacheBox = "gufengCacheLazy";
  static const bainianCacheBox = "bainianCacheLazy";
  static const qimiaoCacheBox = "qimiaoCacheLazy";
  static const qimanCacheBox = "qimanCacheLazy";

  static const comic18DownloadBox = "comic18DownloadLazy";

  static const comicBox = "comic";
  static const propertyBox = "property";
  static const timeBox = "cacheTimeStamp";

  static const boxName = [propertyBox, comicBox, timeBox];
  static const downloadBox = [comic18DownloadBox];

  static const lazyBoxName = [
    pufeiCacheBox,
    jmttCacheBox,
    gufengCacheBox,
    bainianCacheBox,
    qimiaoCacheBox,
    qimanCacheBox,
  ];

  static const sourceToLazyBox = {
    pufei: pufeiCacheBox,
    jmtt: jmttCacheBox,
    gufeng: gufengCacheBox,
    bainian: bainianCacheBox,
    qimiao: qimiaoCacheBox,
    qiman: qimanCacheBox,
  };

  static const readerDirectionName = ["从上到下", "从左到右", "从右到左"];
  static const readerTypeName = ["卷轴模式", "相册模式"];

  static const defaultCoverUrl =
      "https://manhua.acimg.cn/vertical/0/18_17_39_ea5671977fc690a42459210737b4c67a_1592473175770.jpg/420";
  static const versionUrl =
      "https://api.github.com/repos/r-light/domic/releases/latest";
  static const releaseUrl = "https://github.com/r-light/domic/releases/";
}

class Routes {
  // static const String myComicPageRoute = "MyComicPage";
  static const String myComicSearchPageRoute = "MyComicSearchPage";
  static const String myComicSourceRoute = "MyComicSource";
  static const String myComicSearchResultRoute = "MyComicSearchResult";
  static const String mySettingRoute = "MySettingsAction";
  static const String myComicInfoRoute = "MyComicInfo";
  static const String myComicReaderRoute = "MyComicReader";
  static const String myAboutMeRoute = "MyAboutMe";
  static const String myComicHomeRoute = "MyComicHome";
  static const String myComicTagRoute = "MyComicTag";
  static const String myDownloadRoute = "MyDownload";
  static const routes = {
    // ConstantString.pufei: myComicTagRoute,
    // ConstantString.gufeng: myComicTagRoute,
    // ConstantString.bainian: myComicTagRoute,
    ConstantString.qiman: myComicTagRoute,
    ConstantString.jmtt: myComicTagRoute,
  };
}
