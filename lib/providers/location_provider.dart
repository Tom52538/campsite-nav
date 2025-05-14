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

  // NEUE FELDER (ersetzen die Platzhalter-Kommentare)
  RoutingGraph? _currentRoutingGraph;
  List<SearchableFeature> _currentSearchableFeatures = [];
  bool _isLoadingLocationData = false;

  LocationProvider() {
    if (_availableLocations.isNotEmpty) {
      _selectedLocation = _availableLocations.first;
      // Hier könnte zukünftig der initiale Ladevorgang für den ersten Standort angestoßen werden
      // z.B. loadDataForSelectedLocation(); sobald die Methode existiert
    }
  }

  List<LocationInfo> get availableLocations => _availableLocations;
  LocationInfo? get selectedLocation => _selectedLocation;

  // NEUE GETTER (ersetzen die Platzhalter-Kommentare)
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
      // Hier wird zukünftig loadDataForSelectedLocation() aufgerufen
      notifyListeners();
    }
  }

  // Methode zum Laden der Daten (wird in den nächsten Schritten implementiert)
  // Future<void> loadDataForSelectedLocation() async {
  //   // Implementierung folgt
  // }
}
