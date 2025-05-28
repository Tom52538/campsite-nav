import 'dart:io';
import 'dart:convert'; // Für jsonDecode hinzugefügt
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
      final Map<String, dynamic> styleMap = jsonDecode(mapJson);
      // KORREKTUR: ThemeReader().read() braucht Map<String, dynamic>
      return ThemeReader().read(styleMap);
    } else {
      if (kDebugMode) {
        print(
            "[StyleCachingService] Stil '$styleUrl' aus Netzwerk geladen und gecacht.");
      }
      final response = await http.get(Uri.parse(styleUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        final responseString = String.fromCharCodes(response.bodyBytes);
        final Map<String, dynamic> styleMap = jsonDecode(responseString);
        // KORREKTUR: ThemeReader().read() braucht Map<String, dynamic>
        return ThemeReader().read(styleMap);
      } else {
        throw Exception(
            'Failed to load map style from network: ${response.statusCode}');
      }
    }
  }
}
