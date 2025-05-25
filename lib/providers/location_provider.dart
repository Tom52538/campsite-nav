// lib/providers/location_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/style_caching_service.dart'; // NEU

class LocationProvider with ChangeNotifier {
  final List<LocationInfo> _availableLocations = appLocations;
  LocationInfo? _selectedLocation;

  RoutingGraph? _currentRoutingGraph;
  List<SearchableFeature> _currentSearchableFeatures = [];
  bool _isLoadingLocationData = false;

  // --- NEUE FELDER ---
  final StyleCachingService _styleCachingService = StyleCachingService();
  String? _cachedStylePath;
  // --- ENDE NEUE FELDER ---

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
  String? get cachedStylePath => _cachedStylePath; // NEU

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
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
      _cachedStylePath = null; // NEU
      _isLoadingLocationData = false;
      Future.microtask(() {
        notifyListeners();
      });
      return;
    }

    Future.microtask(() {
      _isLoadingLocationData = true;
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
      _cachedStylePath = null; // NEU
      notifyListeners();
    });

    try {
      // Parallel das Caching und das Parsen der GeoJSON-Daten ausführen
      final results = await Future.wait([
        _styleCachingService.ensureStyleIsCached(
            styleUrl: _selectedLocation!.styleUrl,
            styleId: _selectedLocation!.styleId),
        rootBundle.loadString(_selectedLocation!.geojsonAssetPath),
      ]);

      _cachedStylePath = results[0] as String?;
      final String geoJsonString = results[1] as String;

      if (kDebugMode) {
        print(
            "[LocationProvider] GeoJSON-String für ${_selectedLocation!.name} geladen.");
      }

      final parsedData =
          GeojsonParserService.parseGeoJsonToGraphAndFeatures(geoJsonString);
      _currentRoutingGraph = parsedData.graph;
      _currentSearchableFeatures = parsedData.features;

      if (kDebugMode) {
        print(
            "[LocationProvider] Daten für ${_selectedLocation!.name} erfolgreich verarbeitet. Style-Pfad: $_cachedStylePath");
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            "[LocationProvider] Fehler beim Laden der Daten für ${_selectedLocation!.name}: $e");
        print("[LocationProvider] Stacktrace: $stacktrace");
      }
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
      _cachedStylePath = null;
    }

    _isLoadingLocationData = false;
    notifyListeners();
  }
}
