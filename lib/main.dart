import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';

main() => runApp(App());

class App extends StatelessWidget {
  @override
  build(BuildContext context) {
    return MaterialApp(
      home: Home(),
      theme: ThemeData(
        fontFamily: 'Overpass',
      ),
    );
  }
}

class Home extends StatefulWidget {
  @override
  createState() => _Home();
}

class _Home extends State<Home> {
  static String msg = "Timer starts on your first character!";

  var te = TextEditingController();
  var wpm;
  var artist;
  var song;
  var enable = false;
  var hint = msg;
  var text = "Whos gon croon today?";
  var line = Colors.green;
  var sw = Stopwatch();
  var out = List();
  var headerKey = GlobalKey<RefreshHeaderState>();
  var rand = Random();

  @override
  initState() {
    super.initState();
    rootBundle.loadString('assets/artist.csv').then((e) {
      out = CsvToListConverter().convert(e);
      refresh();
    });
  }

  Future<void> refresh() async {
    await getArtist().then((e) async {
      await getLyrics(e[0], e[1]).then((u) {
        setState(() {
          artist = e[0];
          song = e[1];
          text = u;
          enable = true;
          hint = msg;
          te.clear();
        });
      });
    });
  }

  lyrics() {
    return Container(
      child: Text(
        text,
        style: TextStyle(
          height: 1.2,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  input() {
    return Container(
      child: Column(
        children: <Widget>[
          TextField(
            enabled: enable,
            controller: te,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: hint,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: line,
                  width: 5,
                ),
              ),
            ),
            onChanged: (e) {
              if (e.length > 0 && e.length < 3) {
                sw.reset();
                sw.start();
              }
              if (!text.contains(e)) {
                setState(() {
                  line = Colors.red;
                  hint = "Oops!";
                });
              } else if (text == e) {
                sw.stop();
                wpm = getWPM(sw.elapsedMilliseconds, text.length).toString();
                setState(() {
                  text = "That was:\n" +
                      artist +
                      "\nsinging\n" +
                      song +
                      "\n\nPull down to get lyrics.";

                  hint = "WPM: " + wpm;
                  enable = false;
                  te.clear();
                });
              } else {
                setState(() {
                  line = Colors.green;
                  hint = "Don't stop!";
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: EasyRefresh(
        refreshHeader: ClassicsHeader(
          key: headerKey,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 60.0),
          child: Column(
            children: <Widget>[
              lyrics(),
              input(),
            ],
          ),
        ),
        onRefresh: () async => await refresh(),
      ),
    ));
  }

  Future<String> getLyrics(artist, song) async {
    var format;
    await http
        .get("https://api.lyrics.ovh/v1/" + artist + "/" + song)
        .then((e) async {
      if (e.body.length < 99) {
        await getArtist().then((e) async {
          await getLyrics(e[0], e[1]).then((e) {
            format = e;
          });
        });
      } else {
        var buffer = StringBuffer();
        var pre = List();
        var list = json.decode(e.body)["lyrics"].split("\n");
        for (var s in list) {
          if (s != "") pre.add(s.trim());
        }
        int index = next(1, pre.length - 4);
        for (int i = index; i < index + 4; i++) {
          buffer.write(pre[i] + "\n");
        }
        format = buffer.toString().trim();
      }
    });
    return format;
  }

  Future<dynamic> getArtist() async {
    var data = List();
    var x = next(0, out.length);
    data.add(out[x][0]);
    data.add(out[x][1]);
    return data;
  }

  next(min, max) => min + rand.nextInt(max - min);

  getWPM(sec, len) => ((len / 5) / (sec / 60000)).toInt();
}
