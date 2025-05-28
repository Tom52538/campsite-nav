import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    hide Theme; // Theme ausblenden um Konflikt zu vermeiden
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;
import 'package:vector_tile_renderer/vector_tile_renderer.dart'; // Theme kommt von hier
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/style_caching_service.dart';

class LocationProvider with ChangeNotifier {
  final List<LocationInfo> _availableLocations = []; // final hinzugefügt
  LocationInfo? _selectedLocation;
  bool _isLoadingLocationData = false;

  Theme? _mapTheme; // Theme aus vector_tile_renderer
  RoutingGraph? _currentRoutingGraph;
  final List<SearchableFeature> _currentSearchableFeatures =
      []; // final hinzugefügt

  List<LocationInfo> get availableLocations => _availableLocations;
  LocationInfo? get selectedLocation => _selectedLocation;
  bool get isLoadingLocationData => _isLoadingLocationData;

  Theme? get mapTheme => _mapTheme;
  RoutingGraph? get currentRoutingGraph => _currentRoutingGraph;
  List<SearchableFeature> get currentSearchableFeatures =>
      _currentSearchableFeatures;

  LocationProvider() {
    _loadAvailableLocations();
  }

  Future<void> _loadAvailableLocations() async {
    _availableLocations.addAll([
      LocationInfo(
        id: 'camping_de_grote_lier',
        name: 'Camping de Grote Lier',
        geojsonAssetPath: "assets/data/export_camping_de_grote_lier.geojson",
        initialLatitude: 51.4880,
        initialLongitude: 3.6550,
        radiusInMeters: 2000.0,
        styleId: "maptiler_dataviz_grote_lier",
        styleUrl:
            "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
      ),
      LocationInfo(
        id: "sittard",
        name: "Testgelände Sittard",
        geojsonAssetPath: "assets/data/export.geojson",
        initialLatitude: 51.02518780487824,
        initialLongitude: 5.858832278816441,
        radiusInMeters: 1000.0,
        styleId: "maptiler_dataviz_sittard",
        styleUrl:
            "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
      ),
      LocationInfo(
        id: "kamperland",
        name: "Camping Resort Kamperland",
        geojsonAssetPath: "assets/data/export_kamperland.geojson",
        initialLatitude: 51.5833,
        initialLongitude: 3.6333,
        radiusInMeters: 1500.0,
        styleId: "maptiler_dataviz_kamperland",
        styleUrl:
            "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
      ),
      LocationInfo(
        id: "amsterdam",
        name: "Amsterdamse Bos Camping",
        geojsonAssetPath: "assets/data/export_amsterdam.geojson",
        initialLatitude: 52.3275,
        initialLongitude: 4.8589,
        radiusInMeters: 2500.0,
        styleId: "maptiler_dataviz_amsterdam",
        styleUrl:
            "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
      ),
      LocationInfo(
        id: "gangelt",
        name: "Umgebung Zuhause (Gangelt)",
        geojsonAssetPath: "assets/data/export_gangelt.geojson",
        initialLatitude: 51.001452,
        initialLongitude: 6.051261,
        radiusInMeters: 2000.0,
        styleId: "maptiler_dataviz_gangelt",
        styleUrl:
            "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
      ),
    ]);

    if (_availableLocations.isNotEmpty) {
      _selectedLocation = _availableLocations.first;
      await _loadLocationData(_selectedLocation!);
    }
  }

  Future<void> selectLocation(LocationInfo location) async {
    if (_selectedLocation == location) return;
    _selectedLocation = location;
    notifyListeners();
    await _loadLocationData(location);
  }

  Future<void> _loadLocationData(LocationInfo newLocationInfo) async {
    _isLoadingLocationData = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print(
            "INFO: ${DateTime.now()}: LocationProvider: Lade Vector-Theme für ${newLocationInfo.name} von ${newLocationInfo.styleUrl}");
      }

      _mapTheme =
          await StyleCachingService.instance.getTheme(newLocationInfo.styleUrl);

      if (kDebugMode) {
        print(
            "INFO: ${DateTime.now()}: LocationProvider: Vector-Theme erfolgreich geladen von: ${newLocationInfo.styleUrl}");
      }

      if (kDebugMode) {
        print(
            "INFO: ${DateTime.now()}: LocationProvider: Lade GeoJSON-String für ${newLocationInfo.name}.");
      }

      final String geojsonString =
          await rootBundle.loadString(newLocationInfo.geojsonAssetPath);

      if (kDebugMode) {
        print(
            "INFO: ${DateTime.now()}: LocationProvider: GeoJSON-String für ${newLocationInfo.name} geladen.");
      }

      // KORREKTUR: await entfernt, da parseGeoJsonToGraphAndFeatures kein Future zurückgibt
      final ({RoutingGraph graph, List<SearchableFeature> features}) result =
          GeojsonParserService.parseGeoJsonToGraphAndFeatures(geojsonString);

      _currentRoutingGraph = result.graph;
      _currentSearchableFeatures.clear();
      _currentSearchableFeatures.addAll(result.features);

      if (kDebugMode) {
        print(
            "INFO: ${DateTime.now()}: LocationProvider: Daten für ${newLocationInfo.name} erfolgreich verarbeitet. Theme geladen: ${_mapTheme != null}");
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            "FEHLER: ${DateTime.now()}: LocationProvider: Fehler beim Laden der Standortdaten für ${newLocationInfo.name}: $e");
        print(stacktrace);
      }
      _mapTheme = null;
      _currentRoutingGraph = null;
      _currentSearchableFeatures.clear();
    } finally {
      _isLoadingLocationData = false;
      notifyListeners();
    }
  }
}
