import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_tile_renderer/vector_tile_renderer.dart'; // Theme kommt von hier
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';

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
    // TEST VERSION: Leere styleUrl für OpenStreetMap-Tiles
    _availableLocations.addAll([
      const LocationInfo(
        id: "sittard",
        name: "Testgelände Sittard",
        geojsonAssetPath: "assets/data/export.geojson",
        initialLatitude: 51.02518780487824,
        initialLongitude: 5.858832278816441,
        radiusInMeters: 1000.0,
        styleId: "osm_test_sittard",
        styleUrl: "", // TEST: Leerer String für Standard OSM-Tiles
      ),
      const LocationInfo(
        id: "kamperland",
        name: "Camping Resort Kamperland",
        geojsonAssetPath: "assets/data/export_kamperland.geojson",
        initialLatitude: 51.5833,
        initialLongitude: 3.6333,
        radiusInMeters: 1500.0,
        styleId: "osm_test_kamperland",
        styleUrl: "", // TEST: Leerer String für Standard OSM-Tiles
      ),
      const LocationInfo(
        id: "gangelt",
        name: "Umgebung Zuhause (Gangelt)",
        geojsonAssetPath: "assets/data/zuhause_umgebung.geojson",
        initialLatitude: 51.001452,
        initialLongitude: 6.051261,
        radiusInMeters: 2000.0,
        styleId: "osm_test_gangelt",
        styleUrl: "", // TEST: Leerer String für Standard OSM-Tiles
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
            "TEST: ${DateTime.now()}: LocationProvider: Lade OSM-Theme für ${newLocationInfo.name}");
      }

      // TEST: Für OSM-Tiles setzen wir Theme auf null
      _mapTheme = null;

      if (kDebugMode) {
        print(
            "TEST: ${DateTime.now()}: LocationProvider: OSM-Theme gesetzt (null für Standard-Tiles)");
      }

      if (kDebugMode) {
        print(
            "TEST: ${DateTime.now()}: LocationProvider: Lade GeoJSON-String für ${newLocationInfo.name}.");
      }

      final String geojsonString =
          await rootBundle.loadString(newLocationInfo.geojsonAssetPath);

      if (kDebugMode) {
        print(
            "TEST: ${DateTime.now()}: LocationProvider: GeoJSON-String für ${newLocationInfo.name} geladen.");
      }

      // KORREKTUR: await entfernt, da parseGeoJsonToGraphAndFeatures kein Future zurückgibt
      final ({RoutingGraph graph, List<SearchableFeature> features}) result =
          GeojsonParserService.parseGeoJsonToGraphAndFeatures(geojsonString);

      _currentRoutingGraph = result.graph;
      _currentSearchableFeatures.clear();
      _currentSearchableFeatures.addAll(result.features);

      if (kDebugMode) {
        print(
            "TEST: ${DateTime.now()}: LocationProvider: Daten für ${newLocationInfo.name} erfolgreich verarbeitet. OSM-Modus aktiv.");
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            "TEST FEHLER: ${DateTime.now()}: LocationProvider: Fehler beim Laden der Standortdaten für ${newLocationInfo.name}: $e");
        print("Stack trace: $stacktrace");
      }
      _mapTheme = null;
      _currentRoutingGraph = null;
      _currentSearchableFeatures.clear();

      // Nicht-kritische Fehler: App läuft weiter, aber ohne erweiterte Features
    } finally {
      _isLoadingLocationData = false;
      notifyListeners();
    }
  }
}
