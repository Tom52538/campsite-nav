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
      // Wir rufen hier loadDataForSelectedLocation auf, um die Daten für den initialen Standort zu laden.
      // Da dies ein Future ist und der Konstruktor nicht async sein kann,
      // verwenden wir .then() oder ein Future.microtask, um Fehlerbehandlung oder weitere Aktionen
      // nach dem Laden zu ermöglichen, falls nötig. Fürs Erste reicht der Aufruf.
      loadDataForSelectedLocation(); // NEU: Initiales Laden anstoßen
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
      loadDataForSelectedLocation(); // NEU: Laden für neuen Standort anstoßen
      // notifyListeners() wird jetzt von loadDataForSelectedLocation übernommen (am Anfang und Ende)
    }
  }

  // NEUE METHODE / GRUNDGERÜST
  Future<void> loadDataForSelectedLocation() async {
    if (_selectedLocation == null) {
      if (kDebugMode) {
        print(
            "[LocationProvider] Kein Standort ausgewählt, Laden abgebrochen.");
      }
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
      _isLoadingLocationData =
          false; // Sicherstellen, dass der Zustand korrekt ist
      notifyListeners();
      return;
    }

    if (kDebugMode) {
      print(
          "[LocationProvider] Starte Laden der Daten für: ${_selectedLocation!.name}");
    }

    _isLoadingLocationData = true;
    _currentRoutingGraph = null; // Alte Daten ggf. löschen
    _currentSearchableFeatures = []; // Alte Daten ggf. löschen
    notifyListeners(); // UI informieren, dass Ladevorgang startet

    // Simuliert eine Ladezeit, damit man den Ladeindikator später testen kann
    // await Future.delayed(const Duration(seconds: 2));

    // HIER KOMMT IN SCHRITT 1.4 und 1.5 die Lade- und Parsing-Logik
    // z.B.
    // try {
    //   final String geoJsonString = await rootBundle.loadString(_selectedLocation!.geojsonAssetPath);
    //   // ... parsen ...
    //   // _currentRoutingGraph = ...
    //   // _currentSearchableFeatures = ...
    // } catch (e) {
    //   if (kDebugMode) {
    //     print("[LocationProvider] Fehler beim Laden der Daten für ${_selectedLocation!.name}: $e");
    //   }
    //   _currentRoutingGraph = null;
    //   _currentSearchableFeatures = [];
    // }

    _isLoadingLocationData = false;
    notifyListeners(); // UI informieren, dass Ladevorgang beendet ist

    if (kDebugMode) {
      print(
          "[LocationProvider] Laden der Daten für ${_selectedLocation!.name} abgeschlossen. Graph: ${_currentRoutingGraph != null}, Features: ${_currentSearchableFeatures.isNotEmpty}");
    }
  }
}
