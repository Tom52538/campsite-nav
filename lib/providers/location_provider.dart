import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/style_caching_service.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

class LocationProvider with ChangeNotifier {
  List<LocationInfo> _availableLocations = [];
  LocationInfo? _selectedLocation;
  bool _isLoadingLocationData = false;

  // --- KORREKTUR: Typ von Style auf Theme geändert, um mit der Map-Bibliothek kompatibel zu sein ---
  Theme? _mapTheme;
  RoutingGraph? _currentRoutingGraph;
  List<SearchableFeature> _currentSearchableFeatures = [];

  List<LocationInfo> get availableLocations => _availableLocations;
  LocationInfo? get selectedLocation => _selectedLocation;
  bool get isLoadingLocationData => _isLoadingLocationData;

  // --- KORREKTUR: Getter liefert jetzt das Theme-Objekt ---
  Theme? get mapTheme => _mapTheme;
  RoutingGraph? get currentRoutingGraph => _currentRoutingGraph;
  List<SearchableFeature> get currentSearchableFeatures =>
      _currentSearchableFeatures;

  LocationProvider() {
    _loadAvailableLocations();
  }

  Future<void> _loadAvailableLocations() async {
    // Hier würdest du normalerweise die verfügbaren Standorte laden,
    // z.B. aus einer Konfigurationsdatei oder einem API-Endpunkt.
    // Für dieses Beispiel sind sie hartcodiert.
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
      // Füge hier bei Bedarf weitere Standorte hinzu
    ];

    if (_availableLocations.isNotEmpty) {
      // Wähle den ersten Standort standardmäßig aus und lade seine Daten
      await selectLocation(_availableLocations.first);
    } else {
      notifyListeners();
    }
  }

  Future<void> selectLocation(LocationInfo location) async {
    if (_selectedLocation?.id == location.id) {
      return; // Nichts zu tun, wenn der Standort bereits ausgewählt ist
    }

    _selectedLocation = location;
    _isLoadingLocationData = true;
    // Setze alte Daten zurück, während neue geladen werden
    _mapTheme = null;
    _currentRoutingGraph = null;
    _currentSearchableFeatures = [];
    notifyListeners(); // Benachrichtige die UI, dass ein Ladevorgang beginnt

    await _loadLocationData(location);
  }

  Future<void> _loadLocationData(LocationInfo location) async {
    try {
      // Lade das Theme für die Vektorkarte und den Routing-Graphen parallel
      // --- KORREKTUR: Ruft die neue Methode auf, die ein Future<Theme> zurückgibt ---
      final themeFuture =
          StyleCachingService.instance.getTheme(location.styleUrl);
      final graphFuture =
          GeoJsonParserService.instance.loadAndParse(location.geojsonUrl);

      final results = await Future.wait([themeFuture, graphFuture]);

      // --- KORREKTUR: Weise die korrekten Typen zu ---
      _mapTheme = results[0] as Theme?;
      _currentRoutingGraph = results[1] as RoutingGraph?;

      if (_mapTheme != null && _currentRoutingGraph != null) {
        _currentSearchableFeatures = GeoJsonParserService.instance
            .extractSearchableFeatures(_currentRoutingGraph!);
      } else {
        // Fallback, falls einer der Ladevorgänge fehlschlägt
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
    notifyListeners(); // Benachrichtige die UI, dass die neuen Daten verfügbar sind
  }
}
