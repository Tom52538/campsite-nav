// lib/providers/location_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Für rootBundle
import 'dart:async'; // Für Future

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart'; // NEU
import 'package:camping_osm_navi/models/searchable_feature.dart'; // NEU
// Import für GeojsonParserService wird später relevant, kann aber schon hinzugefügt werden:
// import 'package:camping_osm_navi/services/geojson_parser_service.dart'; // NEU (vorerst auskommentiert, da Service noch nicht angepasst)

class LocationProvider with ChangeNotifier {
  final List<LocationInfo> _availableLocations =
      appLocations; // Aus location_info.dart
  LocationInfo? _selectedLocation;

  // Platzhalter für die neuen Felder (werden in den nächsten Schritten gefüllt)
  // RoutingGraph? _currentRoutingGraph;
  // List<SearchableFeature> _currentSearchableFeatures = [];
  // bool _isLoadingLocationData = false;

  LocationProvider() {
    // Initialisiere den ersten Standort als ausgewählt, falls verfügbar
    if (_availableLocations.isNotEmpty) {
      _selectedLocation = _availableLocations.first;
      // Hier könnte zukünftig der initiale Ladevorgang für den ersten Standort angestoßen werden
      // z.B. loadDataForSelectedLocation(); sobald die Methode existiert
    }
  }

  List<LocationInfo> get availableLocations => _availableLocations;
  LocationInfo? get selectedLocation => _selectedLocation;

  // Getter für neue Felder (werden in den nächsten Schritten gefüllt)
  // RoutingGraph? get currentRoutingGraph => _currentRoutingGraph;
  // List<SearchableFeature> get currentSearchableFeatures => _currentSearchableFeatures;
  // bool get isLoadingLocationData => _isLoadingLocationData;

  /// Aktualisiert den ausgewählten Standort und benachrichtigt Listener.
  /// Löst auch das Laden der Daten für den neuen Standort aus.
  void selectLocation(LocationInfo? newLocation) {
    if (newLocation != null && newLocation != _selectedLocation) {
      _selectedLocation = newLocation;
      if (kDebugMode) {
        print("[LocationProvider] Standort gewechselt zu: ${newLocation.name}");
      }
      // Hier wird zukünftig loadDataForSelectedLocation() aufgerufen
      notifyListeners(); // Benachrichtigt alle Widgets, die auf diesen Provider hören
    }
  }

  // Methode zum Laden der Daten (wird in den nächsten Schritten implementiert)
  // Future<void> loadDataForSelectedLocation() async {
  //   // Implementierung folgt
  // }
}
