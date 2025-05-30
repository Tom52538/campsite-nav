// lib/main.dart - MIT DEBUG ROUTE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/screens/map_screen.dart';
import 'package:camping_osm_navi/debug/keyboard_debug_screen.dart'; // NEU
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => LocationProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campground Nav App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 4.0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepOrangeAccent,
          foregroundColor: Colors.white,
        ),
      ),
      // ✅ NEU: Routen für Debug
      initialRoute: '/',
      routes: {
        '/': (context) => const MapScreen(),
        '/debug': (context) => const KeyboardDebugScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
