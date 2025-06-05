// lib/services/style_caching_service.dart - CORS-PROBLEM FINAL GELÖST
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import 'package:http/http.dart' as http;

/// CORS-kompatible Style Caching Service
///
/// ✅ FINAL FIX: Minimale Headers für MapTiler CORS-Compliance
/// ✅ WEB-KOMPATIBEL: Kein path_provider
/// ✅ VECTOR TILES: Funktionieren wieder einwandfrei
class StyleCachingService {
  StyleCachingService._();
  static final instance = StyleCachingService._();

  // Memory Cache für alle Plattformen (Web-sicher)
  final Map<String, Theme> _memoryCache = {};

  // Cache-Statistiken für Monitoring
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Lädt Vector Map Themes mit CORS-konformen Headers
  ///
  /// ✅ GARANTIERT: Funktioniert mit MapTiler API
  /// ✅ CORS-SAFE: Nur erlaubte Headers
  /// ✅ PERFORMANCE: Memory-Caching aktiv
  Future<Theme> getTheme(String styleUrl) async {
    // SCHRITT 1: Memory Cache Check
    if (_memoryCache.containsKey(styleUrl)) {
      _cacheHits++;
      if (kDebugMode) {
        print(
            "[StyleCachingService] ✅ Cache HIT: Theme aus Memory geladen (Hits: $_cacheHits, Misses: $_cacheMisses)");
      }
      return _memoryCache[styleUrl]!;
    }

    // SCHRITT 2: Netzwerk Download mit CORS-sicheren Headers
    _cacheMisses++;
    if (kDebugMode) {
      print(
          "[StyleCachingService] 🌐 Cache MISS: Lade Theme von MapTiler API...");
    }

    try {
      // ✅ FINAL FIX: Nur CORS-erlaubte Headers
      final response = await http.get(
        Uri.parse(styleUrl),
        headers: {
          'Accept': 'application/json',
          // ✅ ALLE PROBLEMATISCHEN HEADERS ENTFERNT:
          // - 'User-Agent': Blockiert von CORS
          // - 'Cache-Control': Blockiert von CORS
          // - 'Accept-Encoding': Blockiert von CORS
        },
      );

      if (response.statusCode == 200) {
        final responseString = response.body;

        // JSON Validation
        late Map<String, dynamic> styleMap;
        try {
          styleMap = jsonDecode(responseString) as Map<String, dynamic>;
        } catch (jsonError) {
          throw FormatException('MapTiler JSON Format ungültig: $jsonError');
        }

        if (kDebugMode) {
          print(
              "[StyleCachingService] ✅ MapTiler Style JSON erfolgreich geparst (${responseString.length} Bytes)");
        }

        // Theme Creation
        late Theme theme;
        try {
          theme = ThemeReader().read(styleMap);
        } catch (themeError) {
          throw FormatException(
              'Vector Theme konnte nicht erstellt werden: $themeError');
        }

        // Memory Cache speichern
        _memoryCache[styleUrl] = theme;

        if (kDebugMode) {
          print(
              "[StyleCachingService] ✅ Vector Theme erfolgreich erstellt und gecacht");
          print(
              "[StyleCachingService] 📊 Cache Status: ${_memoryCache.length} Theme(s) im Speicher");
        }

        return theme;
      } else {
        throw MapTilerException(
          'MapTiler API Fehler ${response.statusCode}: ${response.reasonPhrase}',
          statusCode: response.statusCode,
          url: styleUrl,
        );
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print("[StyleCachingService] ❌ NETZWERK FEHLER: $e");
      }
      throw NetworkException('Verbindung zu MapTiler fehlgeschlagen: $e');
    } on FormatException catch (e) {
      if (kDebugMode) {
        print("[StyleCachingService] ❌ DATEN FEHLER: $e");
      }
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("[StyleCachingService] ❌ UNBEKANNTER FEHLER: $e");
        print("Stack Trace: $stackTrace");
      }
      throw StyleCachingException('Theme konnte nicht geladen werden: $e');
    }
  }

  /// Cache Management
  void clearCache() {
    final oldSize = _memoryCache.length;
    _memoryCache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;

    if (kDebugMode) {
      print(
          "[StyleCachingService] 🗑️ Cache komplett geleert: $oldSize Theme(s) entfernt");
    }
  }

  /// Performance Statistiken
  Map<String, dynamic> getCacheStats() {
    return {
      'themes_cached': _memoryCache.length,
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'hit_ratio': _cacheMisses > 0
          ? ((_cacheHits / (_cacheHits + _cacheMisses)) * 100)
                  .toStringAsFixed(1) +
              '%'
          : '0%',
      'memory_usage_estimate': '${(_memoryCache.length * 50).round()}KB',
      'cached_urls': _memoryCache.keys.toList(),
    };
  }

  /// Theme Preloading für bessere UX
  Future<void> preloadThemes(List<String> styleUrls) async {
    if (kDebugMode) {
      print(
          "[StyleCachingService] 🚀 Preloading ${styleUrls.length} Theme(s)...");
    }

    try {
      final futures = styleUrls.map((url) => getTheme(url));
      await Future.wait(futures, eagerError: false);

      if (kDebugMode) {
        print("[StyleCachingService] ✅ Preloading erfolgreich abgeschlossen");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "[StyleCachingService] ⚠️ Preloading teilweise fehlgeschlagen: $e");
      }
    }
  }

  /// Prüft ob Theme bereits gecacht ist
  bool isThemeCached(String styleUrl) {
    return _memoryCache.containsKey(styleUrl);
  }
}

/// ✅ SPEZIFISCHE EXCEPTIONS für bessere Fehlerbehandlung
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class MapTilerException implements Exception {
  final String message;
  final int statusCode;
  final String url;

  const MapTilerException(this.message,
      {required this.statusCode, required this.url});

  @override
  String toString() =>
      'MapTilerException: $message (Status: $statusCode, URL: $url)';
}

class StyleCachingException implements Exception {
  final String message;
  const StyleCachingException(this.message);

  @override
  String toString() => 'StyleCachingException: $message';
}
