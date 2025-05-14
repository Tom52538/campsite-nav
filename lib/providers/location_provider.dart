// lib/providers/location_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Für rootBundle
import 'dart:async'; // Für Future

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';

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
      // Daten für den initialen Standort laden
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
      // Daten für den neu ausgewählten Standort laden
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
      // Da dies auch den Zustand ändert, ggf. auch in Future.microtask verpacken,
      // aber meist ist es unkritischer, wenn es keine UI-Aktualisierung direkt im Build-Zyklus auslöst.
      // Für Konsistenz könnte man es tun.
      Future.microtask(() {
        notifyListeners();
      });
      return;
    }

    if (kDebugMode) {
      print(
          "[LocationProvider] Starte Laden der Daten für: ${_selectedLocation!.name}");
    }

    // KORREKTUR: Verzögere den ersten notifyListeners-Aufruf
    Future.microtask(() {
      _isLoadingLocationData = true;
      _currentRoutingGraph = null; // Alte Daten vor dem Laden löschen
      _currentSearchableFeatures = []; // Alte Daten vor dem Laden löschen
      notifyListeners(); // UI informieren, dass Ladevorgang startet
    });

    // await Future.delayed(Duration.zero); // Alternative kleine Verzögerung, falls microtask nicht reicht

    try {
      final String geoJsonString =
          await rootBundle.loadString(_selectedLocation!.geojsonAssetPath);
      if (kDebugMode) {
        print(
            "[LocationProvider] GeoJSON-String für ${_selectedLocation!.name} geladen (${geoJsonString.length} Zeichen).");
      }

      final parsedData =
          GeojsonParserService.parseGeoJsonToGraphAndFeatures(geoJsonString);
      _currentRoutingGraph = parsedData.graph;
      _currentSearchableFeatures = parsedData.features;

      if (kDebugMode) {
        print(
            "[LocationProvider] Daten für ${_selectedLocation!.name} erfolgreich geparst und zugewiesen. Graph-Knoten: ${_currentRoutingGraph?.nodes.length ?? 0}, Features: ${_currentSearchableFeatures.length}");
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            "[LocationProvider] Fehler beim Laden oder Parsen der Daten für ${_selectedLocation!.name}: $e");
        print("[LocationProvider] Stacktrace: $stacktrace");
      }
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
    }

    _isLoadingLocationData = false;
    // Der finale notifyListeners kann oft direkt erfolgen, da die asynchronen Operationen (await)
    // den synchronen Build-Flow bereits unterbrochen haben.
    notifyListeners();

    if (kDebugMode) {
      print(
          "[LocationProvider] Laden der Daten für ${_selectedLocation!.name} abgeschlossen (nach try-catch). Graph vorhanden: ${_currentRoutingGraph != null}, Features vorhanden: ${_currentSearchableFeatures.isNotEmpty}");
    }
  }
}
