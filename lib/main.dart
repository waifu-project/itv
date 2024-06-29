import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

var scaffoldKey = GlobalKey<ScaffoldState>();

class TV {
  const TV({required this.name, required this.url});
  final String name;
  final String url;
}

class Group {
  final String name;
  final List<TV> tvs;

  Group({required this.name, this.tvs = const []});
  addTV(String tvName, String tvUrl) {
    tvs.add(TV(name: tvName, url: tvUrl));
  }
}

class Groups {
  Map<String, List<TV>> tvs = {};
  addTv(String groupName, String tvName, String tvUrl) {
    if (!tvs.containsKey(groupName)) {
      tvs[groupName] = [TV(name: tvName, url: tvUrl)];
    } else {
      tvs[groupName]!.add(TV(name: tvName, url: tvUrl));
    }
  }

  merge(Groups other) {
    for (var key in other.tvs.keys) {
      if (!tvs.containsKey(key)) {
        tvs[key] = other.tvs[key]!;
      } else {
        tvs[key]!.addAll(other.tvs[key]!);
      }
    }
  }

  List<String> get names => tvs.keys.toList();
}

class TabToggle extends Intent {}

class Loader {
  static final urlReg = RegExp(
      r'(((ht|f)tps?):\/\/)?([^!@#$%^&*?.\s-]([^!@#$%^&*?.\s]{0,63}[^!@#$%^&*?.\s])?\.)+[a-z]{2,6}\/?');
  static Groups parse(String rawText) {
    var lines = rawText.split("\n");
    var groups = Groups();
    var currKey = "";
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) {
        currKey = "";
        continue;
      }
      var cxx = line.split(",");
      if (!urlReg.hasMatch(line) && currKey.isEmpty) {
        currKey = cxx[0];
        continue;
      }
      if (currKey.isEmpty || cxx.length != 2) continue;
      groups.addTv(currKey, cxx[0], cxx[1]);
    }
    return groups;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const Itv());
}

class Itv extends StatelessWidget {
  const Itv({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Itv',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RenderPage(),
    );
  }
}

class RenderPage extends StatefulWidget {
  const RenderPage({super.key});

  @override
  State<RenderPage> createState() => _RenderPageState();
}

class _RenderPageState extends State<RenderPage> {
  bool dragging = false;
  final Groups groups = Groups();
  final FocusScopeNode focusNode = FocusScopeNode();
  var currGroupName = "";
  List<TV> get currTVS {
    if (groups.tvs.containsKey(currGroupName)) {
      return groups.tvs[currGroupName]!;
    }
    return [];
  }

  int currTVIdx = -1;

  late final Player player = Player();
  late final controller = VideoController(player);
  String realURL = "";

  playURL(String url, {isCloseDrawer = true, isWait = true}) async {
    if (url.isEmpty) return;
    realURL = url;
    setState(() {});
    player.open(Media(url));
    if (isCloseDrawer) {
      if (isWait) await Future.delayed(const Duration(milliseconds: 420));
      scaffoldKey.currentState?.closeDrawer();
    }
  }

  @override
  void dispose() async {
    await player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      onDrawerChanged: (flag) {
        if (!flag) {
          focusNode.requestFocus();
        }
      },
      drawer: Drawer(
        width: currTVIdx >= 0 ? 480 : 240,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: AnimatedContainer(
            width: currTVIdx >= 0 ? 480 : 240,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.72),
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    itemCount: groups.names.length,
                    itemBuilder: (cx, idx) {
                      var name = groups.names[idx];
                      var isSelected = currGroupName == name;
                      return ListTile(
                        selected: isSelected,
                        tileColor: isSelected ? Colors.blue : null,
                        title: Text(name),
                        onFocusChange: (flag) {
                          currGroupName = name;
                          currTVIdx = 0;
                          setState(() {});
                          playURL(currTVS[0].url);
                        },
                        onTap: () {
                          currGroupName = name;
                          currTVIdx = 0;
                          setState(() {});
                          playURL(currTVS[0].url, isCloseDrawer: false);
                        },
                      );
                    },
                  ),
                ),
                if (currTVIdx >= 0)
                  Expanded(
                    flex: 4,
                    child: ListView.builder(
                      itemCount: currTVS.length,
                      itemBuilder: (cx, idx) {
                        var tv = currTVS[idx];
                        var isSelected = currTVIdx == idx;
                        return ListTile(
                          selected: isSelected,
                          selectedColor: isSelected ? Colors.blue : null,
                          title: Text(tv.name),
                          onTap: () {
                            currTVIdx = idx;
                            setState(() { });
                            playURL(tv.url);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
              TabToggle(),
        },
        child: Actions(
          actions: {
            TabToggle: CallbackAction<TabToggle>(
              onInvoke: (_) {
                if (scaffoldKey.currentState?.hasDrawer ?? false) {
                  scaffoldKey.currentState?.openDrawer();
                } else {
                  scaffoldKey.currentState?.closeDrawer();
                }
                return null;
              },
            ),
          },
          child: KeyboardListener(
            focusNode: focusNode,
            autofocus: true,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage("http://www.kf666888.cn/api/tvbox/img"),
                  fit: BoxFit.fill,
                ),
              ),
              child: DropTarget(
                onDragDone: (detail) async {
                  var file = detail.files[0];
                  var cx = await file.readAsString(encoding: utf8);
                  var table = Loader.parse(cx);
                  groups.merge(table);
                  setState(() {});
                  scaffoldKey.currentState?.openDrawer();
                },
                onDragEntered: (detail) {
                  scaffoldKey.currentState?.closeDrawer();
                  dragging = true;
                  setState(() {});
                },
                onDragExited: (detail) {
                  dragging = false;
                  setState(() {});
                },
                child: IndexedStack(
                  children: [
                    if (dragging)
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.42),
                        ),
                        child: const Center(
                          child: Text(
                            "拖拽文件到此处",
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (realURL.isEmpty)
                      Center(
                        child: Builder(builder: (context) {
                          return CupertinoButton.filled(
                            onPressed: () async {
                              var result =
                                  await FilePicker.platform.pickFiles();
                              if (result == null) return;
                              File file = File(result.files.single.path!);
                              var cx = file.readAsStringSync(encoding: utf8);
                              var table = Loader.parse(cx);
                              groups.merge(table);
                              setState(() {});
                              scaffoldKey.currentState?.openDrawer();
                            },
                            child: const Text("打开文件"),
                          );
                        }),
                      )
                    else
                      Video(controller: controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
