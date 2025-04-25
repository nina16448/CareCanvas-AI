import 'package:flutter/material.dart';
import 'home.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _scaffoldKey,
      debugShowCheckedModeBanner: false,
      title: 'CareCanvasAI',
      theme: ThemeData(
        textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme),
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 255, 255, 255)),
        useMaterial3: true,
      ),
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name!);
        if (settings.name == '/') {
          return PageRouteBuilder(settings: settings, pageBuilder: (context, animation1, animation2) => const MyHomePage(), transitionDuration: const Duration(seconds: 0));
        }
        return null;
      },
    );
  }
}
