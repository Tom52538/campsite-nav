// lib/services/style_caching_service.dart

import 'dart:io';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class StyleCachingService {
  StyleCachingService._();
  static final instance = StyleCachingService._();

  // --- KORREKTUR: Gibt jetzt Future<Theme> zurück ---
  Future<Theme> getTheme(String styleUrl) async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final fileName = p.basename(styleUrl);
    final file = File(p.join(cacheDir.path, fileName));

    if (await file.exists()) {
      // Lade aus dem Cache
      final mapJson = await file.readAsString();
      return await ThemeReader.fromString(mapJson);
    } else {
      // Lade aus dem Netzwerk und speichere im Cache
      final response = await http.get(Uri.parse(styleUrl));
      if (response.statusCode == 200) {
        await file.writeAsString(response.body);
        return await ThemeReader.fromString(response.body);
      } else {
        throw Exception('Failed to load style from $styleUrl');
      }
    }
  }
}
