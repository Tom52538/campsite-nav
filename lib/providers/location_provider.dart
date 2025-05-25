// lib/providers/location_provider.dart
import 'dart:convert'; // NEU für jsonDecode, falls styleJson selbst nochmals geparsed werden muss
import 'dart:io'; // NEU für File-Operationen
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/style_caching_service.dart';

class LocationProvider with ChangeNotifier {
  final List<LocationInfo> _availableLocations = appLocations;
  LocationInfo? _selectedLocation;

  RoutingGraph? _currentRoutingGraph;
  List<SearchableFeature> _currentSearchableFeatures = [];
  bool _isLoadingLocationData = false;

  final StyleCachingService _styleCachingService = StyleCachingService();
  vtr.Theme? _mapTheme;

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
  vtr.Theme? get mapTheme => _mapTheme;

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
      _mapTheme = null;
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
      _mapTheme = null;
      notifyListeners();
    });

    try {
      final stylePathFuture = _styleCachingService.ensureStyleIsCached(
          styleUrl: _selectedLocation!.styleUrl,
          styleId: _selectedLocation!.styleId);

      final geoJsonStringFuture =
          rootBundle.loadString(_selectedLocation!.geojsonAssetPath);

      final List<Object?> results =
          await Future.wait([stylePathFuture, geoJsonStringFuture]);

      final stylePath = results[0] as String?;
      final geoJsonString = results[1] as String;

      if (stylePath != null) {
        final styleFile = File(stylePath);
        if (await styleFile.exists()) {
          final String styleJsonContent = await styleFile.readAsString();
          // Die base URI ist wichtig, damit relative Pfade innerhalb des Stylesheets (z.B. für Sprites, Fonts) korrekt aufgelöst werden,
          // falls der Caching Service diese nicht bereits absolut oder korrekt relativ gemacht hat.
          // Da unser StyleCachingService die Pfade bereits relativ zum Style-Ordner macht,
          // sollte die URI des Style-Files selbst als Basis dienen.
          _mapTheme = await vtr.ThemeReader(
                  styleJson: jsonDecode(
                      styleJsonContent), // styleJson erwartet ein Map<String,dynamic>
                  uri: Uri.file(
                      stylePath) // Basis-URI für relative Pfade im Stil
                  )
              .read();
          if (kDebugMode) {
            print(
                "[LocationProvider] Vector-Theme erfolgreich geladen von: $stylePath");
          }
        } else {
          if (kDebugMode) {
            print(
                "[LocationProvider] Fehler: Gecachte Style-Datei nicht gefunden unter $stylePath");
          }
          _mapTheme = null;
        }
      } else {
        if (kDebugMode) {
          print(
              "[LocationProvider] Fehler: Style-Pfad konnte nicht ermittelt werden.");
        }
        _mapTheme = null;
      }

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
            "[LocationProvider] Daten für ${_selectedLocation!.name} erfolgreich verarbeitet. Theme geladen: ${_mapTheme != null}");
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            "[LocationProvider] Fehler beim Laden der Daten für ${_selectedLocation!.name}: $e");
        print("[LocationProvider] Stacktrace: $stacktrace");
      }
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
      _mapTheme = null;
    }

    _isLoadingLocationData = false;
    notifyListeners();
  }
}
