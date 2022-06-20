import 'package:domic/common/common.dart';
import 'package:domic/widgets/components/my_setting_action.dart';
import 'package:flutter/material.dart';

/// MyComicSearchPage : search page
class MyComicSearchPage extends StatefulWidget {
  const MyComicSearchPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MyComicSearchPageState();
}

class MyComicSearchPageState extends State<MyComicSearchPage> {
  var _searchInfo = "";
  final _textEditingController = TextEditingController();
  final _searchContentFocusNode = FocusNode();
  final double height = 15;
  final double padding = 15;
  late Decoration? dec =
      MediaQuery.of(context).platformBrightness == Brightness.dark
          ? null
          : BoxDecoration(color: Theme.of(context).colorScheme.primary);

  @override
  void initState() {
    super.initState();
    _textEditingController.text = _searchInfo;
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _searchContentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          title: const Text(ConstantString.searchPageTitle,
              textAlign: TextAlign.left),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.source,
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.myComicSourceRoute),
            ),
            ...alwaysInActions()
          ],
        ),
        body: LimitedBox(
          maxHeight: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              Container(
                height: height,
                decoration: dec,
              ),
              Container(
                decoration: dec,
                padding: EdgeInsets.all(padding),
                child: TextField(
                    scrollPadding: EdgeInsets.all(padding),
                    textAlignVertical: TextAlignVertical.bottom,
                    toolbarOptions: const ToolbarOptions(
                        copy: true, cut: true, paste: true, selectAll: true),
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    controller: _textEditingController,
                    onChanged: (value) => _searchInfo = value,
                    focusNode: _searchContentFocusNode,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      // contentPadding: EdgeInsets.only(top: 0, bottom: 0),
                      hintText: ConstantString.comicDefaultSearchContent,
                      hintStyle: TextStyle(
                        color: Colors.white,
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    keyboardType: TextInputType.text,
                    onSubmitted: (String value) => Navigator.of(context)
                        .pushNamed(Routes.myComicSearchResultRoute,
                            arguments: value)),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(0, 0, 10, 5),
                decoration: dec,
                alignment: Alignment.centerRight,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                        Routes.myComicSearchResultRoute,
                        arguments: _searchInfo);
                  },
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
