// lib/services/style_caching_service.dart - WEB-KOMPATIBEL BEREINIGT
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import 'package:http/http.dart' as http;

/// Web-kompatible Style Caching Service
///
/// Verwendet ausschließlich Memory-Cache für alle Plattformen
/// um Web-Kompatibilitätsprobleme zu vermeiden.
class StyleCachingService {
  StyleCachingService._();
  static final instance = StyleCachingService._();

  // ✅ WEB-KOMPATIBEL: Nur Memory Cache (kein path_provider)
  final Map<String, Theme> _memoryCache = {};

  // ✅ OPTIONAL: Cache-Statistiken für Debug
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Lädt und cached Vector Map Themes
  ///
  /// - Priorität 1: Memory Cache (sofort verfügbar)
  /// - Priorität 2: Netzwerk Download mit HTTP Caching
  /// - Fallback: Error Handling mit detailliertem Logging
  Future<Theme> getTheme(String styleUrl) async {
    // ✅ SCHRITT 1: Memory Cache Check
    if (_memoryCache.containsKey(styleUrl)) {
      _cacheHits++;
      if (kDebugMode) {
        print(
            "[StyleCachingService] ✅ Cache HIT: '$styleUrl' (Hits: $_cacheHits, Misses: $_cacheMisses)");
      }
      return _memoryCache[styleUrl]!;
    }

    // ✅ SCHRITT 2: Netzwerk Download
    _cacheMisses++;
    if (kDebugMode) {
      print(
          "[StyleCachingService] 🌐 Cache MISS: Lade '$styleUrl' aus Netzwerk... (Hits: $_cacheHits, Misses: $_cacheMisses)");
    }

    try {
      // ✅ OPTIMIERTE HTTP-REQUEST mit besseren Headers
      final response = await http.get(
        Uri.parse(styleUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'CampsiteNav/1.0 (Flutter)',
          'Cache-Control': 'max-age=3600', // 1 Stunde Browser-Cache
          'Accept-Encoding': 'gzip, deflate',
        },
      );

      if (response.statusCode == 200) {
        final responseString = response.body;

        // ✅ JSON VALIDATION vor Theme-Erstellung
        late Map<String, dynamic> styleMap;
        try {
          styleMap = jsonDecode(responseString) as Map<String, dynamic>;
        } catch (jsonError) {
          throw FormatException('Ungültiges JSON Format: $jsonError');
        }

        if (kDebugMode) {
          print(
              "[StyleCachingService] ✅ Style JSON erfolgreich geparst (${responseString.length} Zeichen)");
        }

        // ✅ THEME CREATION mit Error Handling
        late Theme theme;
        try {
          theme = ThemeReader().read(styleMap);
        } catch (themeError) {
          throw FormatException('Theme Reader Fehler: $themeError');
        }

        // ✅ MEMORY CACHE SPEICHERN
        _memoryCache[styleUrl] = theme;

        if (kDebugMode) {
          print(
              "[StyleCachingService] ✅ Theme erfolgreich erstellt und im Memory-Cache gespeichert");
          print(
              "[StyleCachingService] 📊 Cache Status: ${_memoryCache.length} Themes gecacht");
        }

        return theme;
      } else {
        throw HttpException(
          'HTTP Fehler ${response.statusCode}: ${response.reasonPhrase}',
          uri: Uri.parse(styleUrl),
        );
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print(
            "[StyleCachingService] ❌ CLIENT FEHLER beim Laden von $styleUrl: $e");
      }
      throw NetworkException('Netzwerk-Verbindungsfehler: $e');
    } on FormatException catch (e) {
      if (kDebugMode) {
        print(
            "[StyleCachingService] ❌ FORMAT FEHLER beim Parsen von $styleUrl: $e");
      }
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(
            "[StyleCachingService] ❌ UNBEKANNTER FEHLER beim Laden von $styleUrl: $e");
        print("[StyleCachingService] Stack Trace: $stackTrace");
      }
      rethrow;
    }
  }

  /// ✅ CACHE MANAGEMENT: Leert Memory Cache
  void clearCache() {
    final oldSize = _memoryCache.length;
    _memoryCache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;

    if (kDebugMode) {
      print(
          "[StyleCachingService] 🗑️ Cache geleert: $oldSize Themes entfernt");
    }
  }

  /// ✅ CACHE STATISTIKEN für Performance-Monitoring
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_themes': _memoryCache.length,
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'hit_ratio': _cacheMisses > 0
          ? (_cacheHits / (_cacheHits + _cacheMisses) * 100)
                  .toStringAsFixed(1) +
              '%'
          : '0%',
      'cached_urls': _memoryCache.keys.toList(),
    };
  }

  /// ✅ PRELOAD: Themes im Voraus laden
  Future<void> preloadThemes(List<String> styleUrls) async {
    if (kDebugMode) {
      print(
          "[StyleCachingService] 🚀 Preloading ${styleUrls.length} Themes...");
    }

    final futures = styleUrls.map((url) => getTheme(url));
    await Future.wait(futures, eagerError: false);

    if (kDebugMode) {
      print("[StyleCachingService] ✅ Preloading abgeschlossen");
    }
  }
}

/// ✅ CUSTOM EXCEPTIONS für bessere Fehlerbehandlung
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class HttpException implements Exception {
  final String message;
  final Uri uri;
  const HttpException(this.message, {required this.uri});

  @override
  String toString() => 'HttpException: $message (URL: $uri)';
}
