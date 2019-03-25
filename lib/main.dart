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
      home: Scaffold(
        body: new Center(child: Home()),
      ),
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
  static var msg = "Timer starts on your first character!";

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
  var r = RegExp(r"[^\s\w]");

  @override
  initState() {
    super.initState();
    rootBundle.loadString('assets/artist.csv').then((e) {
      out = CsvToListConverter().convert(e);
      refresh();
    });
  }

  refresh() async {
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

  head() {
    return Text(
      "⌨️ typ'em",
      style: TextStyle(
        fontSize: 60,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  lyrics() {
    return Container(
      child: Text(
        text,
        style: TextStyle(
          height: 1.2,
          fontSize: 16,
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
                enable = false;
                te.clear();
                sw.stop();
                wpm = getWPM(sw.elapsedMilliseconds, text.length).toString();
                setState(() {
                  text = "That was:\n 💽 $song \n🎙 $artist \n\n👇 Pull down to get new lyrics!";
                  hint = "WPM: " + wpm;
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
    return EasyRefresh(
      refreshHeader: ClassicsHeader(
        key: headerKey,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 50),
        child: Column(
          children: <Widget>[
            head(),
            lyrics(),
            input(),
          ],
        ),
      ),
      onRefresh: () async => await refresh(),
    );
  }

  getLyrics(artist, song) async {
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
        var buf = StringBuffer();
        var pre = List();
        var list = json.decode(e.body)["lyrics"].split("\n");
        for (var s in list) {
          if (s != "") pre.add(s.trim());
        }
        int index = next(1, pre.length - 4);
        for (int i = index; i < index + 4; i++) {
          buf.write(pre[i].toString().toLowerCase().replaceAll(r, "") + "\n");
        }
        format = buf.toString().trim();
      }
    });
    return format;
  }

  getArtist() async {
    var data = List();
    var x = next(0, out.length);
    data.add(out[x][0]);
    data.add(out[x][1]);
    return data;
  }

  next(min, max) => min + rand.nextInt(max - min);

  getWPM(sec, len) => ((len / 5) / (sec / 60000)).toInt();
}
