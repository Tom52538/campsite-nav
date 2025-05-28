import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/style_caching_service.dart';

class LocationProvider with ChangeNotifier {
  List<LocationInfo> _availableLocations = [];
  LocationInfo? _selectedLocation;
  bool _isLoadingLocationData = false;

  Theme? _mapTheme;
  RoutingGraph? _currentRoutingGraph;
  List<SearchableFeature> _currentSearchableFeatures = [];

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
    _availableLocations = [
      LocationInfo(
        id: 'camping_de_grote_lier',
        name: 'Camping de Grote Lier',
        geojsonUrl:
            'https://raw.githubusercontent.com/TomTomDE/campsite-navigation/main/assets/geojson/DeGroteLier.geojson',
        styleUrl:
            'https://raw.githubusercontent.com/TomTomDE/campsite-navigation/main/assets/styles/dataviz_style_de_grote_lier.json',
        initialCenter: const LatLng(51.02518780487824, 5.858832278816441),
      ),
    ];

    if (_availableLocations.isNotEmpty) {
      await selectLocation(_availableLocations.first);
    } else {
      notifyListeners();
    }
  }

  Future<void> selectLocation(LocationInfo location) async {
    if (_selectedLocation?.id == location.id) {
      return;
    }

    _selectedLocation = location;
    _isLoadingLocationData = true;
    _mapTheme = null;
    _currentRoutingGraph = null;
    _currentSearchableFeatures = [];
    notifyListeners();

    await _loadLocationData(location);
  }

  Future<void> _loadLocationData(LocationInfo location) async {
    try {
      final themeFuture =
          StyleCachingService.instance.getTheme(location.styleUrl);
      final graphFuture =
          GeoJsonParserService.instance.loadAndParse(location.geojsonUrl);

      final results = await Future.wait([themeFuture, graphFuture]);

      _mapTheme = results[0] as Theme?;
      _currentRoutingGraph = results[1] as RoutingGraph?;

      if (_mapTheme != null && _currentRoutingGraph != null) {
        _currentSearchableFeatures = GeoJsonParserService.instance
            .extractSearchableFeatures(_currentRoutingGraph!);
      } else {
        _mapTheme = null;
        _currentRoutingGraph = null;
        _currentSearchableFeatures = [];
      }
    } catch (e) {
      if (kDebugMode) {
        print("Fehler beim Laden der Standortdaten für ${location.name}: $e");
      }
      _mapTheme = null;
      _currentRoutingGraph = null;
      _currentSearchableFeatures = [];
    }

    _isLoadingLocationData = false;
    notifyListeners();
  }
}
