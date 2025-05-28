import 'dart:io';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;
import 'package:vector_tile_renderer/vector_tile_renderer.dart'; // Theme kommt von hier
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class StyleCachingService {
  StyleCachingService._();
  static final instance = StyleCachingService._();

  // KORREKTUR: Rückgabetyp geändert zu Theme aus vector_tile_renderer
  Future<Theme> getTheme(String styleUrl) async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final String safeFileName = styleUrl.replaceAll(
        RegExp(r'[^\w\s.-]'), '_'); // Ersetze ungültige Zeichen
    final file = File(p.join(cacheDir.path, "map_styles",
        safeFileName)); // Unterverzeichnis für Styles

    // Erstelle das Verzeichnis, falls es nicht existiert
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    if (await file.exists()) {
      if (kDebugMode) {
        print(
            "[StyleCachingService] Stil '$styleUrl' aus Cache geladen: ${file.path}");
      }
      final mapJson = await file.readAsString();
      // KORREKTUR: ThemeReader().read() statt VectorTileTheme.fromString
      return ThemeReader().read(mapJson);
    } else {
      if (kDebugMode) {
        print(
            "[StyleCachingService] Stil '$styleUrl' aus Netzwerk geladen und gecacht.");
      }
      final response = await http.get(Uri.parse(styleUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        final responseString = String.fromCharCodes(response.bodyBytes);
        // KORREKTUR: ThemeReader().read() statt VectorTileTheme.fromBytes
        return ThemeReader().read(responseString);
      } else {
        throw Exception(
            'Failed to load map style from network: ${response.statusCode}');
      }
    }
  }
}
