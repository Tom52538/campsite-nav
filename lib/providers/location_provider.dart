// lib/providers/location_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Für rootBundle
import 'dart:async'; // Für Future

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
// Import für GeojsonParserService wird später relevant, kann aber schon hinzugefügt werden:
// import 'package:camping_osm_navi/services/geojson_parser_service.dart';

class LocationProvider with ChangeNotifier {
  final List<LocationInfo> _availableLocations =
      appLocations; // Aus location_info.dart
  LocationInfo? _selectedLocation;

  RoutingGraph? _currentRoutingGraph;
  List<SearchableFeature> _currentSearchableFeatures = [];
  bool _isLoadingLocationData = false;

  LocationProvider() {
    if (_availableLocations.isNotEmpty) {
      _selectedLocation = _availableLocations.first;
      loadDataForSelectedLocation();
    }
  }

  List<LocationInfo> get availableLocations => _availableLocations;
  LocationInfo? get selectedLocation => _selectedLocation;

  RoutingGraph? get currentRoutingGraph => _currentRoutingGraph;
  List<SearchableFeature> get currentSearchableFeatures =>
      _currentSearchableFeatures;
  bool get isLoadingLocationData => _isLoadingLocationData;

  void selectLocation(LocationInfo? newLocation) {
    if (newLocation != null && newLocation != _selectedLocation) {
      _selectedLocation = newLocation;
      if (kDebugMode) {
        print("[LocationProvider] Standort gewechselt zu: ${newLocation.name}");
      }
      loadDataForSelectedLocation();
    }
  }

  Future<void> loadDataForSelectedLocation() async {
    if (_selectedLocation == null) {
      if (kDebugMode) {
        print(
            "[LocationProvider] Kein Standort ausgewählt, Laden abgebrochen.");
      }
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
      _isLoadingLocationData = false;
      notifyListeners();
      return;
    }

    if (kDebugMode) {
      print(
          "[LocationProvider] Starte Laden der Daten für: ${_selectedLocation!.name}");
    }

    _isLoadingLocationData = true;
    _currentRoutingGraph = null;
    _currentSearchableFeatures = [];
    notifyListeners();

    try {
      final String geoJsonString =
          await rootBundle.loadString(_selectedLocation!.geojsonAssetPath);
      if (kDebugMode) {
        print(
            "[LocationProvider] GeoJSON-String für ${_selectedLocation!.name} geladen (${geoJsonString.length} Zeichen).");
      }

      // HIER KOMMT IN SCHRITT 1.5 die Parsing-Logik
      // z.B.
      // final parsedData = GeojsonParserService.parseGeoJsonToGraphAndFeatures(geoJsonString); // (Methode existiert noch nicht so)
      // _currentRoutingGraph = parsedData.graph;
      // _currentSearchableFeatures = parsedData.features;

      // Temporär, um zu sehen, dass der Ladevorgang durchläuft
      if (geoJsonString.isNotEmpty) {
        // ÄUSSERE IF-BEDINGUNG
        if (kDebugMode) {
          // INNERE IF-BEDINGUNG JETZT MIT KLAMMERN
          print(
              "[LocationProvider] GeoJSON String erfolgreich gelesen, Parsing folgt in Schritt 1.5.");
        }
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            "[LocationProvider] Fehler beim Laden der Daten für ${_selectedLocation!.name}: $e");
        print("[LocationProvider] Stacktrace: $stacktrace");
      }
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
    }

    _isLoadingLocationData = false;
    notifyListeners();

    if (kDebugMode) {
      print(
          "[LocationProvider] Laden der Daten für ${_selectedLocation!.name} abgeschlossen. Graph: ${_currentRoutingGraph != null}, Features: ${_currentSearchableFeatures.isNotEmpty}");
    }
  }
}
