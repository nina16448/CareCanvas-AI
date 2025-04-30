import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:carecanvasai/widgets/chat.dart';
import 'package:carecanvasai/widgets/player.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;

bool conn = false;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double width = screenSize.width; // 獲取視窗寬度
    double height = screenSize.height; // 獲取視窗高度
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 255, 255, 255),
        toolbarHeight: 70,
        title: Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                color: Color.fromARGB(0, 0, 0, 0),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', width: 50, height: 50, fit: BoxFit.contain),
                    SizedBox(width: 15),
                    Text("CareCanvasAI", style: TextStyle(fontFamily: 'Montserrat', height: 1, fontWeight: FontWeight.w400, color: Color.fromARGB(255, 0, 0, 0), fontSize: 24.0)),
                  ],
                ),
                onPressed: () {
                  setState(() {
                    html.window.location.reload();
                  });
                },
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // CupertinoButton(
                  //   color: Color.fromARGB(255, 66, 61, 57),
                  //   borderRadius: BorderRadius.circular(100),
                  //   child: Container(
                  //     alignment: Alignment.center,
                  //     width: 100,
                  //     child: Text(
                  //       conn ? "已連接" : "連接印表機",
                  //       style: TextStyle(fontFamily: 'Montserrat', height: 1, fontWeight: FontWeight.w400, color: Color.fromARGB(255, 255, 255, 255), fontSize: 20.0),
                  //     ),
                  //   ),
                  //   onPressed: () async {
                  //     setState(() {
                  //       conn = true;
                  //     });
                  //     const url = 'http://127.0.0.1:8000/epson/auth';

                  //     if (await canLaunchUrl(Uri.parse(url))) {
                  //       await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  //     } else {
                  //       throw '無法打開網址：$url';
                  //     }
                  //   },
                  // ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Row(
          children: [
            Container(
              width: 100,
              padding: EdgeInsets.symmetric(vertical: 10),
              height: height < 600 ? 530 : height - 70,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    color: Color.fromARGB(255, 248, 248, 248),
                    child: Column(
                      children: [
                        SizedBox(height: 20, width: 50),
                        IconButton(onPressed: () {}, icon: Icon(Icons.home, size: 30)),
                        SizedBox(height: 10),
                        IconButton(onPressed: () {}, icon: Icon(Icons.sms)),
                        SizedBox(height: 10),
                        IconButton(onPressed: () {}, icon: Icon(Icons.event_note)),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    color: Color.fromARGB(255, 248, 248, 248),
                    child: Column(
                      children: [
                        SizedBox(height: 20, width: 50),
                        IconButton(onPressed: () {}, icon: Icon(Icons.print)),
                        SizedBox(height: 10),
                        IconButton(onPressed: () {}, icon: Icon(Icons.description)),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    color: Color.fromARGB(255, 248, 248, 248),
                    child: Column(
                      children: [
                        SizedBox(height: 20, width: 50),
                        IconButton(onPressed: () {}, icon: Icon(Icons.settings)),
                        SizedBox(height: 10),
                        IconButton(onPressed: () {}, icon: Icon(Icons.account_circle)),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 20),
            // Column(children: []),
            // SizedBox(width: 10),
            ChatWidget(),
          ],
        ),
      ),
    );
  }
}
