// lib/services/style_caching_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StyleCachingService {
  Future<String?> ensureStyleIsCached(
      {required String styleUrl, required String styleId}) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final styleDir = Directory(p.join(cacheDir.path, 'map_styles', styleId));
      final styleFile = File(p.join(styleDir.path, 'style.json'));

      // Wenn der Stil bereits gecached ist, den lokalen Pfad zurückgeben.
      if (await styleFile.exists()) {
        if (kDebugMode) {
          print(
              "[StyleCachingService] Stil '$styleId' aus Cache geladen: ${styleFile.path}");
        }
        return styleFile.path;
      }

      if (kDebugMode) {
        print(
            "[StyleCachingService] Stil '$styleId' nicht im Cache. Lade von: $styleUrl");
      }

      // Haupt-Stil-Datei herunterladen
      final response = await http.get(Uri.parse(styleUrl));
      if (response.statusCode != 200) {
        throw Exception(
            'Fehler beim Laden der style.json: ${response.statusCode}');
      }

      // Verzeichnis erstellen, falls nicht vorhanden
      await styleDir.create(recursive: true);

      // Stil-JSON verarbeiten, um relative Pfade zu Ressourcen zu finden und herunterzuladen
      final styleJson = jsonDecode(response.body) as Map<String, dynamic>;
      final baseUrl = Uri.parse(styleUrl);

      // Ressourcen (Sprites, Glyphs) herunterladen und Pfade in JSON anpassen
      await _downloadStyleResource(styleJson, 'sprite', baseUrl, styleDir);
      await _downloadStyleResource(styleJson, 'glyphs', baseUrl, styleDir);

      // Die bearbeitete style.json Datei lokal speichern
      await styleFile.writeAsString(jsonEncode(styleJson));

      if (kDebugMode) {
        print(
            "[StyleCachingService] Stil '$styleId' erfolgreich heruntergeladen und im Cache gespeichert.");
      }
      return styleFile.path;
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print("[StyleCachingService] Fehler beim Cachen des Stils: $e");
        print("[StyleCachingService] Stacktrace: $stacktrace");
      }
      return null;
    }
  }

  Future<void> _downloadStyleResource(Map<String, dynamic> styleJson,
      String key, Uri baseUrl, Directory styleDir) async {
    if (styleJson.containsKey(key)) {
      String resourceUrl = styleJson[key].toString();

      // Komplette URL erstellen, falls der Pfad relativ ist
      if (!resourceUrl.startsWith('http')) {
        resourceUrl = baseUrl.resolve(resourceUrl).toString();
      }

      final localBaseName = p.basename(resourceUrl.split('?').first);

      // Sprite-Dateien (.json und .png) haben oft keinen Dateinamen im Pfad
      if (key == 'sprite') {
        if (kDebugMode) {
          print("[StyleCachingService] Lade Sprite-Ressource: $localBaseName");
        }
        // Sprite JSON
        await _downloadAndSave(
            '${resourceUrl}.json', styleDir, '${localBaseName}.json');
        // Sprite PNG
        await _downloadAndSave(
            '${resourceUrl}.png', styleDir, '${localBaseName}.png');

        // Pfad in der style.json auf den relativen, lokalen Pfad aktualisieren
        styleJson[key] = './$localBaseName';
      } else if (key == 'glyphs') {
        if (kDebugMode) {
          print("[StyleCachingService] Passe Glyphen-Pfad an.");
        }
        // Bei Glyphen ist der Pfad eine Vorlage, die wir nur auf relativ ändern
        // z.B. "maptiler://fonts/{fontstack}/{range}.pbf" -> "./{fontstack}/{range}.pbf"
        styleJson[key] = './fonts/{fontstack}/{range}.pbf';
      }
    }
  }

  Future<void> _downloadAndSave(
      String url, Directory targetDir, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(p.join(targetDir.path, fileName));
        await file.writeAsBytes(response.bodyBytes);
      } else {
        if (kDebugMode) {
          print(
              "[StyleCachingService] Fehler beim Download von $url: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("[StyleCachingService] Fehler beim Speichern von $fileName: $e");
      }
    }
  }
}
