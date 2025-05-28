// ===== KORRIGIERTER LOCATION_PROVIDER.DART =====
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Für Theme-Klasse hinzugefügt
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // dotenv Import hinzugefügt
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;
import 'package:vector_tile_renderer/vector_tile_renderer.dart'; // WICHTIG: Theme kommt hier her!
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/style_caching_service.dart';

class LocationProvider with ChangeNotifier {
  List<LocationInfo> _availableLocations = [];
  LocationInfo? _selectedLocation;
  bool _isLoadingLocationData = false;

  Theme? _mapTheme; // KORREKTUR: Theme aus vector_tile_renderer
  RoutingGraph? _currentRoutingGraph;
  List<SearchableFeature> _currentSearchableFeatures = [];

  List<LocationInfo> get availableLocations => _availableLocations;
  LocationInfo? get selectedLocation => _selectedLocation;
  bool get isLoadingLocationData => _isLoadingLocationData;

  Theme? get mapTheme => _mapTheme; // KORREKTUR: Theme aus vector_tile_renderer
  RoutingGraph? get currentRoutingGraph => _currentRoutingGraph;
  List<SearchableFeature> get currentSearchableFeatures =>
      _currentSearchableFeatures;

  // ... Rest des Codes bleibt gleich ...
}

// ===== KORRIGIERTER STYLE_CACHING_SERVICE.DART =====
import 'dart:io';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;
import 'package:vector_tile_renderer/vector_tile_renderer.dart'; // WICHTIG: Theme kommt hier her!
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class StyleCachingService {
  StyleCachingService._();
  static final instance = StyleCachingService._();

  // KORREKTUR: Theme aus vector_tile_renderer
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
      // KORREKTUR: ThemeReader().read() aus vector_tile_renderer
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
        // KORREKTUR: ThemeReader().read() aus vector_tile_renderer
        return ThemeReader().read(responseString);
      } else {
        throw Exception(
            'Failed to load map style from network: ${response.statusCode}');
      }
    }
  }
}