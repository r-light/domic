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

  static const pufeiCacheBox = "pufeiCacheLazy";
  static const jmttCacheBox = "jmttCacheLazy";
  static const gufengCacheBox = "gufengCacheLazy";
  static const bainianCacheBox = "bainianCacheLazy";

  static const comicBox = "comic";
  static const propertyBox = "property";
  static const timeBox = "cacheTimeStamp";

  static const boxName = [propertyBox, comicBox, timeBox];

  static const lazyBoxName = [
    pufeiCacheBox,
    jmttCacheBox,
    gufengCacheBox,
    bainianCacheBox
  ];

  static const sourceToLazyBox = {
    pufei: pufeiCacheBox,
    jmtt: jmttCacheBox,
    gufeng: gufengCacheBox,
    bainian: bainianCacheBox
  };

  static const readerDirectionName = ["从上到下", "从左到右", "从右到左"];

  static const defaultCoverUrl =
      "http://i.ywzqzx.com/mh/cover/2019/11/19/1159a8ff17.jpg/420";
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
}
