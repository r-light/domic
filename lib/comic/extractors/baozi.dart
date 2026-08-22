import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:domic/comic/extractors/baozi_decoder.dart';
import 'package:domic/comic/extractors/dio.dart';
import 'package:domic/comic/extractors/dto.dart';
import 'package:domic/comic/extractors/parser_entity.dart';
import 'package:domic/comic/extractors/utils.dart';
import 'package:extended_image/extended_image.dart';
import 'package:html/parser.dart';

class Baozi extends Parser {
  static Baozi? _instance;
  String domainBase = "https://baozimh.org/";
  String searchBase = "https://baozimh.org/";
  String chapterListBase = "https://api-get-v3.mgsearcher.com/api/manga/get";
  String chapterImageBase = "https://v2.apikk.top/api/v2/chapter/getinfo";

  Baozi._internal() {
    _instance = this;
  }

  factory Baozi() => _instance ?? Baozi._internal();

  @override
  comicByChapter(ComicInfo comicInfo, {int idx = 0}) async {
    if (idx >= comicInfo.chapters.length) return;
    var chapter = comicInfo.chapters[idx];
    var resp = await MyDio().getHtml(RequestOptions(
      path: chapter.url,
      baseUrl: domainBase,
      method: "GET",
    ));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    var chapterContent = doc.querySelector("#chapterContent");
    var dataMs = chapterContent?.attributes["data-ms"] ?? "";
    var dataCs = chapterContent?.attributes["data-cs"] ?? "";

    resp = await MyDio().getHtml(RequestOptions(
        path: chapterImageBase,
        method: "GET",
        queryParameters: {"m": dataMs, "c": dataCs},
        headers: {"Referer": "https://m.baozimh.one/"}));
    chapter.images = [];
    try {
      var listString =
          resp.value?.data["data"]["info"]["images"]["images"] as String;
      var list = BaoziDecoder.decode(listString) as List;

      list.sort((o1, o2) => o1["order"] - o2["order"]);
      for (var image in list) {
        String prefix = image["line"] == 2
            ? "https://c-nd2-1.6wm.top"
            : "https://t-nd2-1.6wm.top";
        var url = image["url"] as String;
        if (!url.startsWith("http")) {
          url = prefix + url;
        }
        chapter.images.add(
            ImageInfo(url)..headers = {"Referer": "https://m.baozimh.one/"});
      }
    } catch (e) {}

    chapter.len = chapter.images.length;
  }

  @override
  Future<ComicInfo> comicById(String id) async {
    var resp = await MyDio().getHtml(RequestOptions(
      baseUrl: domainBase,
      path: id,
      method: "GET",
    ));
    var content = resp.value?.data.toString();
    var doc = parse(content);

    // parse chapter
    var mid = doc.querySelector("#firstchap")?.attributes["data-mid"] ?? "";
    List<Chapter> chapters = [];
    var chapterInfoResp = MyDio()
        .getHtml(
      RequestOptions(path: chapterListBase, method: "GET", queryParameters: {
        "mid": mid,
        "mode": "all"
      }, headers: {
        "Referer": "https://baozimh.org/",
        "origin": "https://baozimh.org"
      }),
    )
        .then((r) {
      var map = r.value?.data as Map;
      var list = map["data"]["chapters"] as List;
      for (var chapter in list) {
        var title = "", url = "";
        try {
          title = trimAllLF(chapter["attributes"]["title"] ?? "");
          url = "$id/${chapter["attributes"]["slug"]}";
          // ignore: empty_catches
        } catch (e) {}
        chapters.add(Chapter(title, url, 0, []));
      }
      chapters = chapters.reversed.toList();
    });

    var thumb = doc
            .querySelector("#MangaCard")
            ?.querySelector("img")
            ?.attributes["src"] ??
        "";
    if (!thumb.startsWith("http")) {
      thumb = domainBase + thumb;
    }

    var detailList = doc
        .querySelector("#info")
        ?.querySelector("div.block.text-left.mx-auto");

    var titleAndState = detailList?.querySelector("h1")?.text ?? "";
    titleAndState = trimAllLF(titleAndState);
    var title = trimAllLF(titleAndState.split(" ").first);
    var state = ComicState.unknown;
    var stateDesc = trimAllLF(titleAndState.split(" ").last);
    if (stateDesc == "完結" || stateDesc == "完结") {
      state = ComicState.completed;
    }
    if (stateDesc == "連載中" || stateDesc == "连载中") {
      state = ComicState.ongoing;
    }

    var author = detailList?.querySelector("a")?.text ?? "";

    var updateDate = "";
    var uploadDate = updateDate;

    var description = "";
    if (detailList != null && detailList.children.length >= 5) {
      description = detailList.children[4].text;
    }

    description = trimAllLF(description);

    await chapterInfoResp;
    var res = ComicInfo(id, title, thumb, updateDate, uploadDate, description,
        chapters, author);
    res.state = state;
    return res;
  }

  @override
  Future<ComicPageData> comicByName(String name, int page) async {
    var resp = await MyDio().getHtml(RequestOptions(
        baseUrl: searchBase,
        path: "/s/$name",
        method: "GET",
        queryParameters: {"page": page}));
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);

    // var respp = await MyDio().getHtml(RequestOptions(
    //   path: "https://go.mgsearcher.com/indexes/mangaStrapiPro/search",
    //   method: "POST",
    //   data: {"q": name, "hitsPerPage": 30, "page": page},
    // ));

    List<ComicSimple> list = [];
    doc
        .querySelector("div.grid-cols-3.cardlist")
        ?.querySelectorAll("div.pb-2")
        .forEach((e) {
      var title = e.querySelector("h3")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["src"] ??
          e.querySelector("img")?.attributes["srcset"] ??
          "";
      if (!thumb.startsWith("http")) {
        thumb = domainBase + thumb;
      }

      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var updateDate = "";
      var source = "baozi";
      var sourceName = sourcesName["baozi"] ?? "";
      var author = "";

      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    var maxPage = doc
            .querySelector(
                "div.flex.justify-between.items-center.mt-5.mb-10>div")
            ?.querySelectorAll("a")
            .last
            .text ??
        "";
    return ComicPageData(int.tryParse(maxPage) ?? 1, list);
  }

  Future<List<MapEntry<String, String>>> getComicTabs() async {
    var resp = await MyDio().getHtml(
      RequestOptions(path: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString();
    var doc = parse(content);
    List<MapEntry<String, String>> res = [];

    doc
        .querySelector("body>main>div>div.homenavtax")
        ?.querySelectorAll("a")
        .forEach((element) {
      var href = element.attributes["href"] ?? "";
      var text = trimAllLF(element.text);
      res.add(MapEntry(text, href));
    });
    return res;
  }

  Future<ComicPageData> comicByTab(String path, int page) async {
    var resp = await MyDio().getHtml(
      RequestOptions(
          path: "$path/page/$page", baseUrl: domainBase, method: "GET"),
    );
    var content = resp.value?.data.toString() ?? "";
    var doc = parse(content);
    List<ComicSimple> list = [];
    doc
        .querySelector("div.grid-cols-3.cardlist")
        ?.querySelectorAll("div.pb-2")
        .forEach((e) {
      var title = e.querySelector("h3")?.text ?? "";
      title = trimAllLF(title);
      var thumb = e.querySelector("img")?.attributes["src"] ??
          e.querySelector("img")?.attributes["srcset"] ??
          "";
      if (!thumb.startsWith("http")) {
        thumb = domainBase + thumb;
      }

      var id = e.querySelector("a")?.attributes["href"] ?? "";

      var updateDate = "";
      var source = "baozi";
      var sourceName = sourcesName["baozi"] ?? "";
      var author = "";
      list.add(ComicSimple(
          id, title, thumb, author, updateDate, source, sourceName));
    });
    var maxPage = doc
            .querySelector(
                "div.flex.justify-between.items-center.mt-5.mb-10>div")
            ?.querySelectorAll("a")
            .last
            .text ??
        "";
    return ComicPageData(int.tryParse(maxPage) ?? 1, list);
  }

  List<Map<String, dynamic>> decrypt(String payload) {
    /* 
    "J7r8ak7Qbhm8cx6AbMyKaxeNcvnhcQekc5eOmxuAmtbhaJePahzAmKihcKiQa8iSchqAmKuhbOfxbQ6xnIyNmy25rQjwq92RpwG40X2ynl3wcP290O7xqAKwcw3ApJvAsJrNo5jInDvQqPfQr5zvpBDhaOWwpPmJa8vzbQ7kav6NbhmMbA6xaKy8cxeNckeQcOe5cvnhmxuJahfNax6hct3Ta8_LawfQmTikmAaKb8exaxr8nRfvbkaOcwjQrIa5q92X04Glny2Rpw3wcx7P0wKAqP29cw3JsAv5oNrApJjInQfPqvz5rDvQpBDPpwW8aJmhaOvzbN6vaMmhbQ7kbA6xc8ykcNexaKeQchnvcJuxmOe5ahjtmhfxaQqNbzmNa57MaNm5cwn8aNeNaAi8bOiNbL_TmxmIrX29qwjQ04GwpR2xcw3lny7Q092PqJ3wcwKAsAvJpArQnIj5oNfPqQvDrPDBpvz5pwWOahmNbzv8aJ6vak7Qbx6AbMmhc8yKaxehcQekcNnvc5eOmtnhaJuxc8qKbxmkaN38nQmMn5iSbT3NmAfhn83SnhykaLekbRaIrQjwqwG40X29pR2ynl390R7xcw2PqAKwcJvAsJ3wpArNo5jQqPfQnIvDr5zvpOWwpPDBahmJa8vkav6Nbz7QbhmMbKy8cx6AaxeNcke5cvnhcQeOmxuJavjAatrhcheTb8jhbw-8bwyRbNaPaS_hnAjNaAmNaxiQrIy8nRjwq92X0y2RpwG4nl3wcx7AqP290SKwcw3JsNrApJvAo5jInQf5rDvQqPzvpBDPpJmhaOWwa8vzbN6hbQ7kavmMbA6xcNexaKy8ckeQchnxmOe5cvuJahvtmNmkaNiAb8rybN6NaPehnzeQaAaLcK7haPu8mNqQmxm9qwjQrI2X04Gwpw3lny2Rcx7T092wcwKAqP3JsAvJpIj5oNrAnQfPqQvBpvz5rDDPpwWOazv8aJmhbN6vak7AbMmhbQ6xc8yKaQekcNexchnvc5ehaJuxmOztbhrxaQyNmvz8bkmTaNzhczjkczuSah6vbvbkmR_8n8yIrQj40X29qwGwpR2ynK3xcw3l092PqAKAsJ3wcwvJpArNoPfQnIj5qQvDr5zwpPDBpvWOahmJav6Nbzv8ak7Qbhm8cx6AbMyKaxeNcvnhcQekc5eOmxuhmt-xaJbzb5nyaQy8bQ78nhnvnxz8nSihcxnznx_MbIe5aNyNrQjwq92RpwG40X2ynl3wcP290L3xqAKwcw3ApJvAsJrNo5jInDvQqPfQr5zvpBDhaOWwpPmJa8vzbQ7kav6NbhmMbA6xaKy8cxeNckeQcOe5cvnhmxuJax6NaLihat7KahfzbTuxmR78mNaMbk7QbxjAaL7Sc8zznwjQrIu8q92X04Glny2Rpw3wcx3M0wKAqP29cw3JsAv5oNrApJjInQfPqvz5rDvQpBDPpwW8aJmhaOvzbN6vaMmhbQ7kbA6xc8ykcNexaKeQchnvcJuxmOe5ax2tbhe5bQikaRiNc8yOayj5bTmAb8aSbN78bK_haQiRaQ3IrX29qwjQ04GwpR2xcw3lny3N092PqJ3wcwKAsAvJpArQnIj5oNfPqQvDrPDBpvz5pwWOahmNbzv8aJ6vak7Qbx6AbMmhc8yKaxehcQekcNnvc5eOmtbxaJuxchmLnki8bNmQaS-xnhzymx2xmQ_hnxaLnAnxmwjhcxmIrQjwqwG40X29pR2ynl390O3xcw2PqAKwcJvAsJ3wpArNo5jQqPfQnIvDr5zvpOWwpPDBahmJa8vkav6Nbz7QbhmMbKy8cx6AaxeNcke5cvnhcQeOmxuJaRikbtfxnxrwmNvhnMixbyvynA3QbK_hnv6hmxaKahjQrI3AmAjwq92X0y2RpwG4nl3wcx3AqP290PKwcw3JsNrApJvAo5jInQf5rDvQqPzvpBDPpJmhaOWwa8vzbN6hbQ7kavmMbA6xcNexaKy8ckeQchnxmOe5cvuJaxjtbv25aSkD_hnxeLaNyxmKi5aMzvmNnwnzb5nLu8ch6wbN_9qwjQrI2X04Gwpw3lny2Rcx3Q092wcwKAqP3JsAvJpIj5oNrAnQfPqQvBpvz5rDDPpwWOazv8aJmhbN6vak7AbMmhbQ6xc8yKaQekcNexchnvc5exaJuxmOntmh2vbz2hcT3QnhuNahz8cNyxnvvvbh6wazr8bA25b8yIrQj40X29qwGwpR2ynR3xcw3l092PqAKAsJ3wcwvJpArNoPfQnIj5qQvDr5zwpPDBpvWOahmJav6Nbzv8ak7Qbhm8cx6AbMyKaxeNcvnhcQekc5eOmxukatrxaJ7Sc8aMcT7hbM_hbNbvmhm5nKehcM3Qbk2zbI7kaNeQrQjwq92RpwG40X2ynl3wcP290S3xqAKwcw3ApJvAsJrNo5jInDvQqPfQr5zvpBDhaOWwpPmJa8vzbQ7kav6NbhmMbA6xaKy8cxeNckeQcOe5cvnhmxuJaxvxnx2xnt6wbhzwaReNaKy8nxeNbx7xaKe5bMmKakiSbwjQrIekq92X04Glny2Rpw3wcx3T0wKAqP29cw3JsAv5oNrApJjInQfPqvz5rDvQpBDPpwW8aJmhaOvzbN6vaMmhbQ7kbA6xc8ykcNexaKeQchnvcJuxmOe5axztmhm5aTqxaQ3TbNuPaOaxmTuxb8vwak7NmKmAbKjvbA3IrX29qwjQ04GwpR2xcw3lnyaK092PqJ3wcwKAsAvJpArQnIj5oNfPqQvDrPDBpvz5pwWOahmNbzv8aJ6vak7Qbx6AbMmhc8yKaxehcQekcNnvc5eOmt-NaJuxbNrxmNihnynhaMiOchbAbSiAnLmNb5aObA75aRe5cTmIrQjwqwG40X29pR2ynl390Laxcw2PqAKwcJvAsJ3wpArNo5jQqPfQnIvDr5zvpOWwpPDBahmJa8vkav6Nbz7QbhmMbKy8cx6AaxeNcke5cvnhcQeOmxuJaOahct6NakmPbAmNbyvNmNmLa8uMaOexnQihchuSb8nQrIikmvjwq92X0y2RpwG4nl3wcxaAqP290MKwcw3JsNrApJvAo5jInQf5rDvQqPzvpBDPpJmhaOWwa8vzbN6hbQ7kavmMbA6xcNexaKy8ckeQchnxmOe5cvuJaN2taAzxmy28mk7Mbk68nMmxbz3TmNjybQiQbvzxckeQaQa9qwjQrI2X04Gwpw3lny2RcxaN092wcwKAqP3JsAvJpIj5oNrAnQfPqQvBpvz5rDDPpwWOazv8aJmhbN6vak7AbMmhbQ6xc8yKaQekcNexchnvc5eNaJuxmObtmQeRaNahnwb8akbxbx_Amz2QbQ6vchaMbxnNmw2Ank7IrQj40X29qwGwpR2ynOaxcw3l092PqAKAsJ3wcwvJpArNoPfQnIj5qQvDr5zwpPDBpvWOahmJav6Nbzv8ak7Qbhm8cx6AbMyKaxeNcvnhcQekc5eOmxu8atfNaJ-ynxyOnMe8nQ7kb8uNax2xnOmhbveQb8nwmImxnO_xrQjwq92RpwG40X2ynl3wcP290PaxqAKwcw3ApJvAsJrNo5jInDvQqPfQr5zvpBDhaOWwpPmJa8vzbQ7kav6NbhmMbA6xaKy8cxeNckeQcOe5cvnhmxuJaNjxnS38btjxmAfznw25ax-hbxnvc8qkcMaQaR3Oa5aOmwjQrIqhq92X04Glny2Rpw3wcxaQ0wKAqP29cw3JsAv5oNrApJjInQfPqvz5rDvQpBDPpwW8aJmhaOvzbN6vaMmhbQ7kbA6xc8ykcNexaKeQchnvcJuxmOe5aNntche5cwvxaPiLaNqLaSu8nw2NmxaKahjAmAf8ayjvbAeIrX29qwjQ04GwpR2xcw3lnyaR092PqJ3wcwKAsAvJpArQnIj5oNfPqQvDrPDBpvz5pwWOahmNbzv8aJ6vak7Qbx6AbMmhc8yKaxehcQekcNnvc5eOmtrNaJuxmkiLnh2hbwb8bAiTb5mKmQahmPyxbhrxc8rQmOaNmAiIrQjwqelX29W4skRGwpR2xcw3lny7G3BjMpUXw3U39o5XInRb4nBTknCjNo5zOoIjBsI6k0NeLbwWkaRi5cK7LmhmPbSakmQ3xch_Mb8aAbTm8nT7Sn8fwcSaNlLW9mAnybx7xmOaknTyPc8_PnK3Nmyj8nAmNahaB0My8aPrzmB_wtMXA3VLgn5jM3xCAqP290MKwcw3JsNrApJvAo5jInQf5rDvQqPzvpBDPpJmhaOWwa8vzbN6hbQ7kavmMbA6xcNexaKy8ckeQchnxmOe5cvuJazWOmPm5azrhaN7TnhnNbK_NmxeOb8mOny-hcN3AbN_NcgTB3K2knROGsM2JqU3wqzfAaMKwrl2R0wCx3GDCpQTBqyrApzvQrlbColfkrUTkmDSJb87Q0LqhnS_Nmh6vbxiNmvnxaQuTa83OaQyxbyzNmhvyb53NatbN0S7TnxiMbK7knPmkah_Nc8ixnTe8aReNa8iSmIuhbzfQrQjwq92RpwG40X2ynl3wcMjB3Gexp93U3wXRnIX5oUbCnkTBnOz5oNj4ok6IsBjwbLeN0IWKc5iRaPmhmL7kbx3Qmka8bM_hcSaTn8mTbwf8nS7Ac9WOlQihnPeQmMrAaA6vaybNbybQc5mRmhb8nO3hmAnzahyR0w_BmzrBtgLV3AXx3Mj5nMCP092PqJ3wcwKAsAvJpArQnIj5oNfPqQvDrPDBpvz5pwWOahmNbzv8aJ6vak7Qbx6AbMmhc8yKaxehcQekcNnvc5eOmKWjbJuxmxzxnxaxmNi5nO7MbknzbK3kmxv8n53Oc5jwnyfxbxTRnk2K3J2MsGOBqAfzqw3lrwKwbU2G3xCw0BTQpCDRqQvzpArloCblryfDmkTUrQ78bJSk0N_Snhqxbv6hmLiQaxnvmO38aTuNaNzybxy5byvhmQ3S0NntawvxnS3hn8qLbNzxbK3NmwjxbhePmvbAay-xah2wn8a9qwjQrI2X04Gwpw3lny2RcxqG3Bjw3U39pMXUo5XInBTknCbRn4jNo5zBsI6koOjI0NeLbRi5cKWwak7LmhmkmQ3xbPaSch_MbTm8nTa8bA7Sn8fQlRW9cw3QmQmQmAbxaAfQbxuLaxyhbAb5nP-AckiPmxbAbz-x0BrzmB_A3VLgtwXMn5jM3P290SCxqAKwcw3ApJvAsJrNo5jInDvQqPfQr5zvpBDhaOWwpPmJa8vzbQ7kav6NbhmMbA6xaKy8cxeNckeQcOe5cvnhmxuJc6XQbPikcxnvaxnxcxfxbMe5bkbwa5i8aRakcRbAa56waK2knRTw3BOGsM2wqzfAqJ3UcgKwrwCx3G2l0RDCpQTApzvQqBryrlbCoUTkmDflrkSJb87hnS_N0QqLmh6vbvnxaQixmNuTa83xbyzNaOyQmhvybtzN0S35mN6wnxuhmPe5nL6vnxqPaPekmQ7kb8eTnxuNbv-NmKuIrQjwqwG40X29pR2ynl390K7xcw2PqAKwcJvAsJ3wpArNo5jQqPfQnIvDr5zvpOWwpPDBahmJa8vkav6Nbz7QbhmMbKy8cx6AaxeNcke5cvnhcQeOmxuJaQiQmt-hmhaKbxaAbT7AmRaKnA7KaN7QmxfxcheNnkiQrIuhbQjwq92X0y2RpwG4nl3wcx7AqP290LKwcw3JsNrApJvAo5jInQf5rDvQqPzvpBDPpJmhaOWwa8vzbN6hbQ7kavmMbA6xcNexaKy8ckeQchnxmOe5cvuJah6tbNuhazfxbxyOb825cL7kcw7Kch2ybKmhmS_8bhmSaQ79qwjQrI2X04Gwpw3lny2Rcx7M092wcwKAqP3JsAvJpIj5oNrAnQfPqQvBpvz5rDDPpwWOazv8aJmhbN6vak7AbMmhbQ6xc8yKaQekcNexchnvc5ehaJuxmO2tchvxcxjknv68n5eOmxe8cwnkmOvznxvxnNqNaT_8bkiIrQj40X29qwGwpR2ynN7xcw3l092PqAKAsJ3wcwvJpArNoPfQnIj5qQvDr5zwpPDBpvWOahmJav6NbzvnQ"
 */
    const String header = "kD";
    const String footer = "nQ";
    const String sign = "J7r";
    const int stride = 7;

    final lastKD = payload.lastIndexOf(header);
    final lastNQ = payload.lastIndexOf(footer);

    if (lastKD == -1 || lastNQ == -1 || lastNQ <= lastKD) {
      throw Exception("基础校验失败x2");
    }

    final body = payload.substring(lastKD + header.length, lastNQ);

    final tailLen = body.length - stride;
    if (tailLen <= 0) throw Exception("基础校验失败x3");

    final blockCount = tailLen ~/ 3;
    final remainder = tailLen - blockCount;
    final headerLen = remainder - blockCount;

    if (headerLen < 0) {
      throw Exception('基础校验失败x4');
    }

    final core = payload.substring(
      header.length,
      payload.length - footer.length,
    );

    final S = remainder; // _0x5a0a3f
    final H = headerLen; // _0x157843

    final aOffset = S;
    final aEnd = S + header.length;

    final payloadOffset = aEnd;
    final payloadEnd = aEnd + H;

    final bOffset = payloadEnd;
    final bEnd = bOffset + footer.length;

// 切片
    final part1 = core.substring(0, S);
    final partA = core.substring(aOffset, aEnd);
    final encoded = core.substring(payloadOffset, payloadEnd);
    final partB = core.substring(bOffset, bEnd);
    final tail = core.substring(bEnd);

    print(partA);
    print(partB);
    if (partA != header || partB != footer) {
      throw Exception('基础校验失败x5');
    }

    final sigStart = blockCount * 7 + remainder;

    // final sig = tail.substring(sigStart);
    // final expectedSig = tail.substring(sigStart - sign.length, sigStart);

    // if (sig != sign || expectedSig != sign) {
    //   throw Exception("x4");
    // }

    // 4. Base64URL → Base64
    String base64 = body.replaceAll("-", "+").replaceAll("_", "/");

    // 5. padding
    switch (base64.length % 4) {
      case 2:
        base64 += "==";
        break;
      case 3:
        base64 += "=";
        break;
    }

    // 6. 解码
    final bytes = base64Decode(base64);
    final jsonStr = utf8.decode(bytes);

    print(jsonStr);
    // 7. 解析
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.cast<Map<String, dynamic>>();
  }
}
