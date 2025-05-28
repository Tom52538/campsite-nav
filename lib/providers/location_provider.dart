import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show rootBundle; // Hinzugefügt für rootBundle
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart'
    as vector_map_tiles; // Alias hinzugefügt
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/style_caching_service.dart';

class LocationProvider with ChangeNotifier {
  List<LocationInfo> _availableLocations = [];
  LocationInfo? _selectedLocation;
  bool _isLoadingLocationData = false;

  vector_map_tiles.Theme? _mapTheme; // Verwendung des Aliases
  RoutingGraph? _currentRoutingGraph;
  List<SearchableFeature> _currentSearchableFeatures = [];

  List<LocationInfo> get availableLocations => _availableLocations;
  LocationInfo? get selectedLocation => _selectedLocation;
  bool get isLoadingLocationData => _isLoadingLocationData;

  vector_map_tiles.Theme? get mapTheme => _mapTheme; // Verwendung des Aliases
  RoutingGraph? get currentRoutingGraph => _currentRoutingGraph;
  List<SearchableFeature> get currentSearchableFeatures =>
      _currentSearchableFeatures;

  LocationProvider() {
    _loadAvailableLocations();
  }

  Future<void> _loadAvailableLocations() async {
    _availableLocations = [
      LocationInfo(
        id: 'camping_de_grote_lier',
        name: 'Camping de Grote Lier',
        geojsonAssetPath: "assets/data/export_camping_de_grote_lier.geojson",
        initialLatitude: 51.4880, // Beispielwert
        initialLongitude: 3.6550, // Beispielwert
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
        initialLatitude: 51.5833, // Beispielwert
        initialLongitude: 3.6333, // Beispielwert
        radiusInMeters: 1500.0,
        styleId: "maptiler_dataviz_kamperland",
        styleUrl:
            "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
      ),
      LocationInfo(
        id: "amsterdam",
        name: "Amsterdamse Bos Camping",
        geojsonAssetPath: "assets/data/export_amsterdam.geojson",
        initialLatitude: 52.3275, // Beispielwert
        initialLongitude: 4.8589, // Beispielwert
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
    ];
    // Setze den ersten Standort als Standard oder lade einen gespeicherten
    if (_availableLocations.isNotEmpty) {
      _selectedLocation = _availableLocations.first;
      _loadLocationData(_selectedLocation!);
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
      _mapTheme = await StyleCachingService.instance.getTheme(
          newLocationInfo.styleUrl); // Korrigierte Verwendung des Aliases
      if (kDebugMode) {
        print(
            "INFO: ${DateTime.now()}: LocationProvider: Vector-Theme erfolgreich geladen von: ${newLocationInfo.styleUrl}");
      }

      if (kDebugMode) {
        print(
            "INFO: ${DateTime.now()}: LocationProvider: Lade GeoJSON-String für ${newLocationInfo.name}.");
      }
      // Verwendung von geojsonAssetPath zum Laden der Asset-Datei
      final String geojsonString =
          await rootBundle.loadString(newLocationInfo.geojsonAssetPath);
      if (kDebugMode) {
        print(
            "INFO: ${DateTime.now()}: LocationProvider: GeoJSON-String für ${newLocationInfo.name} geladen.");
      }

      final ({RoutingGraph graph, List<SearchableFeature> features}) result =
          await GeojsonParserService.parseGeoJsonToGraphAndFeatures(
              geojsonString);

      _currentRoutingGraph = result.graph;
      _currentSearchableFeatures = result.features;

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
      _currentSearchableFeatures = [];
    } finally {
      _isLoadingLocationData = false;
      notifyListeners();
    }
  }
}
