// lib/main.dart - MIT ENHANCED USER JOURNEY LOGGING
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/screens/map_screen.dart';
import 'package:camping_osm_navi/services/user_journey_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // ✅ LOGGING: App Start
  UserJourneyLogger.startSession();

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
    // ✅ LOGGING: App UI bereit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Nach dem ersten Frame - App vollständig geladen
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      UserJourneyLogger.appStarted(
          locationProvider.currentSearchableFeatures.length,
          locationProvider.selectedLocation?.name ?? "Unbekannter Standort");
    });

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
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
