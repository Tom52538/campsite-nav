import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart'; // <- Dieser Import könnte die Exception verursachen, wenn das Paket nicht korrekt für Web konfiguriert ist

class StyleCachingService {
  StyleCachingService._();
  static final instance = StyleCachingService._();

  // In-Memory Cache für Web (ersetzt File-System Cache)
  final Map<String, Theme> _memoryCache = {};

  Future<Theme> getTheme(String styleUrl) async {
    // Überprüfe Memory Cache zuerst
    if (_memoryCache.containsKey(styleUrl)) {
      if (kDebugMode) {
        print(
            "[StyleCachingService] Stil '$styleUrl' aus Memory-Cache geladen");
      }
      return _memoryCache[styleUrl]!;
    }

    if (kDebugMode) {
      print(
          "[StyleCachingService] Stil '$styleUrl' wird aus Netzwerk geladen...");
    }

    try {
      final response = await http.get(
        Uri.parse(styleUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'CampsiteNav/1.0',
        },
      );

      if (response.statusCode == 200) {
        final responseString = response.body;
        final Map<String, dynamic> styleMap = jsonDecode(responseString);

        if (kDebugMode) {
          print(
              "[StyleCachingService] Style JSON erfolgreich geladen und geparst");
        }

        final theme = ThemeReader().read(styleMap);

        // In Memory Cache speichern für zukünftige Verwendung
        _memoryCache[styleUrl] = theme;

        if (kDebugMode) {
          print("[StyleCachingService] Theme erfolgreich erstellt und gecacht");
        }

        return theme;
      } else {
        throw Exception(
            'HTTP Error ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (kDebugMode) {
        print("[StyleCachingService] FEHLER beim Laden von $styleUrl: $e");
      }
      rethrow;
    }
  }
}
