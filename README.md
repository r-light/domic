<!--
 * @Author: r-light 414271394@qq.com
 * @Date: 2022-07-10 07:39:59
 * @LastEditors: r-light 414271394@qq.com
 * @LastEditTime: 2024-01-09 09:20:45
 * @FilePath: /domic/README.md
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
-->

# domic

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/r-light/domic)

一个简单的漫画客户端，使用 flutter 开发。

## 实现功能

- [x] 搜索
- [x] 收藏
- [x] 历史
- [x] 下载
- [x] 多种图源
- [x] 浏览部分主页
- [x] 多种阅读方向(:arrow_down:, :arrow_right:, :arrow_left:)
- [x] 多种阅读模式(卷轴、相册)

## 支持图源

- [x] 古风漫画
- [x] 奇漫屋
- [x] 酷漫屋
- [x] 包子漫画

## 界面

<p float="left">
<img src="images/screenshot1.png" alt="Simulator Screen Shot - iPhone 11 - 2022-07-04 at 20.37.35"  width="300"  />
<img src="images/screenshot2.png" alt="Simulator Screen Shot - iPhone 11 - 2022-07-04 at 20.41.28"  width="300"  />
</p>

## 致谢

开发过程中遇到了很多问题，同时也发现了一些比较流行的第三方包，特此鸣谢。

- [Provider](https://pub.dev/packages/provider)
- [cached_network_image](https://pub.dev/packages/cached_network_image)
- [dio](https://pub.dev/packages/dio)
- [hive](https://pub.dev/packages/hive)
- [reorderable_grid_view](https://pub.dev/packages/reorderable_grid_view)

- [How to change Android minSdkVersion in flutter project](https://stackoverflow.com/questions/52060516/how-to-change-android-minsdkversion-in-flutter-project)
- [Flutter build Runtime JAR files in the classpath should have the same version](https://stackoverflow.com/questions/71347054/flutter-build-runtime-jar-files-in-the-classpath-should-have-the-same-version-t)
- [Networking in Flutter using Dio](https://www.lmlphp.com/user/16515/article/item/492232/)
- [M1 设备的 Xcode 编译问题深究](https://www.jianshu.com/p/7e9acc13cbbd)
- [ListView disposes and recreates the State & RenderObject of all children (identified by ValueKey) when the item order changes](https://github.com/flutter/flutter/issues/21023)
- [Sqflite guide](https://github.com/tekartik/sqflite/blob/master/sqflite/doc/how_to.md)
- [Dartlang wait more than one future](https://stackoverflow.com/questions/42176092/dartlang-wait-more-than-one-future)
- [Flutter 中的异步](https://juejin.cn/post/6987637272375984165#heading-6)
