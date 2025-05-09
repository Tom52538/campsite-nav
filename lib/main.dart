// [Start lib/main.dart - Mit Standortauswahl-Dropdown]
import 'dart:async';
import 'dart:convert'; // Für jsonDecode
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für rootBundle
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Wird für Distance benötigt
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

// Eigene Imports
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/models/location_info.dart'; // NEUER IMPORT

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campground Nav App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 4.0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepOrangeAccent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  RoutingGraph? _routingGraph;
  List<SearchableFeature> _searchableFeatures = [];
  Polyline? _routePolyline;
  Marker? _currentLocationMarker;
  Marker? _startMarker;
  Marker? _endMarker;
  LatLng? _currentGpsPosition;
  LatLng? _endLatLng;
  bool _isCalculatingRoute = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchableFeature> _searchResults = [];
  bool _showSearchResults = false;
  SearchableFeature? _selectedSearchFeatureForEnd;

  bool _isDataReady = false;
  bool _useMockLocation = true;

  // NEU: Ausgewählter Standort und verfügbare Standorte
  LocationInfo? _selectedLocation;
  final List<LocationInfo> _availableLocations =
      appLocations; // Aus location_info.dart

  // defaultInitialCenter wird jetzt vom _selectedLocation oder als Fallback verwendet
  static const LatLng
      fallbackInitialCenter = // Umbenannt von defaultInitialCenter
      LatLng(51.02518780487824, 5.858832278816441);
  static const double markerWidth = 40.0;
  static const double markerHeight = 40.0;
  static const double centerOnGpsMaxDistanceMeters = 5000;

  @override
  void initState() {
    super.initState();

    // Initialisiere den ausgewählten Standort
    if (_availableLocations.isNotEmpty) {
      _selectedLocation = _availableLocations.first;
    } else {
      // Fallback, falls appLocations leer ist (sollte nicht passieren)
      _selectedLocation = null;
    }

    if (kDebugMode) {
      print(
          "<<< initState: MapScreen wird initialisiert. Ausgewählter Standort: ${_selectedLocation?.name ?? "Keiner"}. Mock-Location: $_useMockLocation >>>");
    }

    // WICHTIG: _loadData und _initializeGpsOrMock müssen noch angepasst werden,
    // um den _selectedLocation.geojsonAssetPath und ggf. _selectedLocation.initialCenter zu verwenden,
    // wenn Mock-Location aktiv ist und kein GPS-Fix da ist.
    // Für diesen Schritt laden wir weiterhin die Standard-Daten.
    _loadData(); // Lädt aktuell noch hartcodiert 'assets/data/export.geojson'
    _initializeGpsOrMock();

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print("<<< dispose: MapScreen wird zerstört. >>>");
    }
    _mapController.dispose();
    _positionStreamSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onLocationChanged(LocationInfo? newLocation) {
    if (newLocation == null || newLocation == _selectedLocation) return;
    if (!mounted) return;

    setState(() {
      _selectedLocation = newLocation;
      // Alle standortspezifischen Daten zurücksetzen
      _routingGraph = null;
      _searchableFeatures = [];
      _routePolyline = null;
      // _currentLocationMarker bleibt (da GPS oder Mock-Standort)
      _startMarker = null;
      _endMarker = null;
      _endLatLng = null;
      _selectedSearchFeatureForEnd = null;
      _isDataReady = false; // Daten für neuen Standort müssen geladen werden
    });

    _mapController.move(
        _selectedLocation!.initialCenter, 17.0); // Zoom anpassen?
    _showSnackbar("Standort geändert zu: ${_selectedLocation!.name}",
        durationSeconds: 3);

    if (kDebugMode) {
      print(
          "<<< _onLocationChanged: Standort gewechselt zu ${_selectedLocation!.name}. GeoJSON: ${_selectedLocation!.geojsonAssetPath} >>>");
    }

    // TODO Phase 2: Hier _loadData(_selectedLocation!.geojsonAssetPath) aufrufen und ggf. _initializeGpsOrMock anpassen
    // Fürs Erste simulieren wir, dass die Daten neu geladen werden müssen, aber die _loadData Methode lädt noch das alte File.
    // Der _loadData Aufruf wird in einem späteren Schritt dynamisch gemacht.
    // _loadData(); // AKTUELL NICHT AUFRUFEN, da es die alte Datei lädt und zu Verwirrung führen könnte.
    // Stattdessen zeigen wir dem Nutzer, dass etwas passieren würde:
    _showSnackbar("Lade Daten für ${_selectedLocation!.name}...",
        durationSeconds: 2);
    // Manuell _isDataReady auf false setzen, bis die echte Ladelogik implementiert ist
    // und dann wieder auf true, nachdem geladen wurde.
    // Hier noch keine echten Daten laden, das ist der nächste Schritt im Plan.
    // Als Platzhalter: Nach kurzer Verzögerung so tun, als wären Daten geladen (für UI-Demo)
    // Dies ist nur für die Demo des Wechsels, die echte Ladelogik kommt später
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _selectedLocation == newLocation) {
        // Sicherstellen, dass der Standort nicht erneut gewechselt wurde
        // setState(() { _isDataReady = true; }); // Nur aktivieren, wenn _loadData wirklich aufgerufen und erfolgreich war
        // Da _loadData noch nicht dynamisch ist, lassen wir _isDataReady vorerst so, wie es von der initialen Ladung ist
        // oder setzen es explizit, um den "Lade"-Zustand zu simulieren.
        // Für diesen Schritt ist es besser, wenn der Nutzer sieht, dass die Daten noch nicht zum Standort passen.
      }
    });
  }

  LatLng _getActiveInitialCenter() {
    if (_useMockLocation) {
      // Wenn Mock-Location aktiv ist, verwende das initialCenter des ausgewählten Standorts
      return _selectedLocation?.initialCenter ?? fallbackInitialCenter;
    }
    // Wenn echtes GPS aktiv ist und eine Position vorhanden ist, wird diese verwendet.
    // Das defaultInitialCenter für die MapOptions ist nur der erste Startpunkt.
    return _selectedLocation?.initialCenter ?? fallbackInitialCenter;
  }

  void _toggleMockLocation() {
    if (!mounted) return;
    setState(() {
      _useMockLocation = !_useMockLocation;
      _initializeGpsOrMock(); // Diese Methode muss _selectedLocation.initialCenter für Mock berücksichtigen
    });
    _showSnackbar(
        _useMockLocation
            ? "Mock-Position (${_selectedLocation?.name ?? 'Fallback'}) aktiviert."
            : "Echtes GPS aktiviert (mit Distanzprüfung).",
        durationSeconds: 4);
    if (kDebugMode) {
      print(
          "<<< _toggleMockLocation: Mock-Location ist jetzt: $_useMockLocation für Standort ${_selectedLocation?.name} >>>");
    }
  }

  void _initializeGpsOrMock() {
    _positionStreamSubscription?.cancel();
    setStateIfMounted(() {
      _currentGpsPosition = null;
      _currentLocationMarker = null;
    });

    final LatLng activeInitialCenterForMock =
        _selectedLocation?.initialCenter ?? fallbackInitialCenter;

    if (_useMockLocation) {
      if (kDebugMode) {
        print(
            "<<< _initializeGpsOrMock: Mock-Modus AKTIV. Setze Position auf initialCenter von ${_selectedLocation?.name ?? "Fallback"}: $activeInitialCenterForMock. >>>");
      }
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _currentGpsPosition = activeInitialCenterForMock;
            _currentLocationMarker = _createMarker(
                _currentGpsPosition!,
                Colors.orangeAccent,
                Icons.pin_drop,
                "Mock Position (${_selectedLocation?.name ?? 'Gelände'})");
            _mapController.move(
                _currentGpsPosition!, 17.0); // Ggf. Zoom anpassen
            if (kDebugMode) {
              print(
                  "<<< _initializeGpsOrMock: Map auf Mock Position für ${_selectedLocation?.name} zentriert >>>");
            }
          });
          // Routen neu berechnen, falls ein Ziel existiert, da sich der Startpunkt geändert haben könnte
          if (_endLatLng != null) _calculateAndDisplayRoute();
        }
      });
    } else {
      if (kDebugMode) {
        print(
            "<<< _initializeGpsOrMock: Echtes GPS AKTIV. Starte Initialisierung... >>>");
      }
      _initializeGpsReal();
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  List<SearchableFeature> _extractSearchableFeaturesFromGeoJson(
      String geoJsonString) {
    final List<SearchableFeature> features = [];
    final dynamic decodedJson = jsonDecode(geoJsonString);

    if (kDebugMode) {
      print(
          "<<< _extractSearchableFeaturesFromGeoJson: Starte Extraktion... >>>");
    }

    if (decodedJson is Map<String, dynamic> &&
        decodedJson['type'] == 'FeatureCollection' &&
        decodedJson['features'] is List) {
      int featureCount = 0;
      for (final featureJson in decodedJson['features'] as List) {
        featureCount++;
        if (featureJson is Map<String, dynamic>) {
          final properties = featureJson['properties'] as Map<String, dynamic>?;
          final geometry = featureJson['geometry'] as Map<String, dynamic>?;

          if (properties != null && geometry != null) {
            final dynamic id = featureJson['id'] ??
                properties['@id'] ??
                'feature_${DateTime.now().millisecondsSinceEpoch}_$featureCount';
            final String? name = properties['name'] as String?;
            String type = properties['highway'] as String? ??
                properties['amenity'] as String? ??
                properties['shop'] as String? ??
                properties['building'] as String? ??
                properties['tourism'] as String? ??
                'unknown';

            if (name != null && name.isNotEmpty) {
              LatLng? center;
              final String? geomType = geometry['type'] as String?;
              final dynamic coordsRaw = geometry['coordinates'];

              try {
                if (geomType == 'Point' &&
                    coordsRaw is List &&
                    coordsRaw.length >= 2 &&
                    coordsRaw[0] is num &&
                    coordsRaw[1] is num) {
                  center = LatLng((coordsRaw[1] as num).toDouble(),
                      (coordsRaw[0] as num).toDouble());
                } else if (geomType == 'LineString' &&
                    coordsRaw is List &&
                    coordsRaw.isNotEmpty) {
                  if (coordsRaw.first is List) {
                    final firstPointList = coordsRaw.first as List;
                    if (firstPointList.length >= 2 &&
                        firstPointList[0] is num &&
                        firstPointList[1] is num) {
                      center = LatLng((firstPointList[1] as num).toDouble(),
                          (firstPointList[0] as num).toDouble());
                    }
                  }
                } else if (geomType == 'Polygon' &&
                    coordsRaw is List &&
                    coordsRaw.isNotEmpty) {
                  if (coordsRaw.first is List) {
                    final firstRing = coordsRaw.first as List;
                    if (firstRing.isNotEmpty && firstRing.first is List) {
                      final firstPointList = firstRing.first as List;
                      if (firstPointList.length >= 2 &&
                          firstPointList[0] is num &&
                          firstPointList[1] is num) {
                        center = LatLng((firstPointList[1] as num).toDouble(),
                            (firstPointList[0] as num).toDouble());
                      }
                    }
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print(
                      ">>> Fehler beim Parsen der Koordinaten für Feature '$name': $e");
                }
              }

              if (center != null) {
                features.add(SearchableFeature(
                  id: id.toString(),
                  name: name,
                  type: type,
                  center: center,
                ));
              }
            }
          }
        }
      }
    }
    if (kDebugMode) {
      print(
          "<<< _extractSearchableFeaturesFromGeoJson: ${features.length} suchbare Features extrahiert. >>>");
    }
    return features;
  }

  // TODO Phase 2: _loadData anpassen, um geojsonAssetPath als Parameter zu akzeptieren
  Future<void> _loadData() async {
    // Aktuell wird immer noch die Standard-Datei geladen.
    // Dies wird in Phase 2, Schritt 3 angepasst.
    final String currentGeoJsonPath =
        _selectedLocation?.geojsonAssetPath ?? 'assets/data/export.geojson';
    if (kDebugMode) {
      print(
          "<<< _loadData: Starte das Laden der GeoJSON Daten von: $currentGeoJsonPath (Hinweis: Muss noch dynamisch werden für Standortwechsel!). >>>");
    }
    if (!mounted) return;
    setStateIfMounted(() {
      _isDataReady = false;
    });

    try {
      final String geoJsonString = await rootBundle.loadString(
          currentGeoJsonPath); // Verwende (noch nicht voll dynamischen) Pfad
      if (kDebugMode) {
        print(
            "<<< _loadData: GeoJSON String erfolgreich geladen (${geoJsonString.length} Zeichen). >>>");
      }

      final RoutingGraph graph =
          GeojsonParserService.parseGeoJson(geoJsonString);
      if (kDebugMode) {
        if (graph.nodes.isEmpty) {
          print(
              ">>> _loadData WARNUNG: Routing Graph vom Parser erhalten, aber er hat 0 Knoten für $currentGeoJsonPath.");
        } else {
          print(
              "<<< _loadData: Routing Graph vom Parser erhalten mit ${graph.nodes.length} Knoten für $currentGeoJsonPath. >>>");
        }
      }

      final List<SearchableFeature> features =
          _extractSearchableFeaturesFromGeoJson(geoJsonString);

      if (!mounted) return;
      setStateIfMounted(() {
        _routingGraph = graph;
        _searchableFeatures = features;
        if (_routingGraph != null && _routingGraph!.nodes.isNotEmpty) {
          _isDataReady = true;
          if (kDebugMode) {
            print(
                "<<< _loadData SUCCESS: Daten sind jetzt bereit (_isDataReady = true). Graph: ${_routingGraph!.nodes.length} Knoten. Features: ${_searchableFeatures.length}. >>>");
          }
        } else {
          _isDataReady = false; // Bleibt false, wenn Graph leer
          if (kDebugMode) {
            print(
                ">>> _loadData ERROR: Routing Graph nicht korrekt initialisiert oder leer für $currentGeoJsonPath. _isDataReady bleibt false.");
          }
          _showErrorDialog(
              "Fehler bei der Initialisierung der Routing-Daten für $currentGeoJsonPath.");
        }
      });
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            ">>> _loadData FATAL ERROR: Fehler beim Laden/Parsen der GeoJSON Daten von $currentGeoJsonPath: $e\n$stacktrace");
      }
      if (!mounted) return;
      setStateIfMounted(() {
        _isDataReady = false;
      });
      _showErrorDialog(
          'Schwerwiegender Fehler beim Laden der Kartendaten von $currentGeoJsonPath: $e.');
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase().trim();
    List<SearchableFeature> results = [];
    if (query.isNotEmpty) {
      results = _searchableFeatures.where((feature) {
        return feature.name.toLowerCase().contains(query) ||
            feature.type.toLowerCase().contains(query);
      }).toList();
    }
    setStateIfMounted(() {
      _searchResults = results;
      _showSearchResults =
          _searchFocusNode.hasFocus && results.isNotEmpty && query.isNotEmpty;
    });
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    final bool hasFocus = _searchFocusNode.hasFocus;
    final bool hasText = _searchController.text.isNotEmpty;
    final bool hasResults = _searchResults.isNotEmpty;
    if (kDebugMode) {
      print(
          "<<< _onSearchFocusChanged: hasFocus: $hasFocus, hasText: $hasText, hasResults: $hasResults. Current _showSearchResults: $_showSearchResults >>>");
    }
    if (hasFocus) {
      setStateIfMounted(() {
        _showSearchResults = hasText && hasResults;
      });
    } else {
      if (kDebugMode) {
        print(
            "<<< _onSearchFocusChanged: Focus LOST. Intentionally NOT changing _showSearchResults state here. Waiting for item selection or map tap. >>>");
      }
    }
  }

  void _selectFeatureAndSetPoint(SearchableFeature feature) {
    if (kDebugMode) {
      print(
          "<<< _selectFeatureAndSetPoint: Feature ausgewählt: ${feature.name} >>>");
    }
    if (!mounted) return;

    _searchController.clear();
    _searchResults = [];
    _showSearchResults = false;
    _searchFocusNode.unfocus();

    setStateIfMounted(() {
      _endLatLng = feature.center;
      _endMarker = _createMarker(feature.center, Colors.red, Icons.flag_circle,
          "Ziel: ${feature.name}");
      _selectedSearchFeatureForEnd = feature;
      if (kDebugMode) {
        print(
            "<<< _selectFeatureAndSetPoint: Zielpunkt gesetzt auf: ${feature.name} >>>");
      }
      _calculateAndDisplayRoute();
    });
    _mapController.move(feature.center, 18.0);
  }

  Future<void> _initializeGpsReal() async {
    if (kDebugMode) {
      print("<<< _initializeGpsReal: Starte ECHTE GPS Initialisierung... >>>");
    }
    if (!mounted) return;

    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorDialog("GPS ist deaktiviert. Bitte aktiviere es.");
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorDialog("GPS-Berechtigung verweigert.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog("GPS-Berechtigung dauerhaft verweigert.");
        return;
      }
    } catch (e) {
      if (kDebugMode)
        print(">>> _initializeGpsReal: Fehler bei Berechtigungsprüfung: $e");
      _showErrorDialog("Fehler GPS-Berechtigungen: $e");
      return;
    }

    final LatLng centerForDistanceCheck =
        _selectedLocation?.initialCenter ?? fallbackInitialCenter;

    _positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 5))
        .listen((Position position) {
      if (!mounted) return;
      final bool isFirstFix = _currentGpsPosition == null;
      setStateIfMounted(() {
        _currentGpsPosition = LatLng(position.latitude, position.longitude);
        _currentLocationMarker = _createMarker(_currentGpsPosition!,
            Colors.blueAccent, Icons.circle, "Meine Position");
      });
      if (kDebugMode)
        print(
            "<<< _initializeGpsReal: Neue ECHTE GPS Position: $_currentGpsPosition >>>");

      if (isFirstFix && _currentGpsPosition != null) {
        final Distance distance = Distance();
        final double meters =
            distance(centerForDistanceCheck, _currentGpsPosition!);
        if (meters <= centerOnGpsMaxDistanceMeters) {
          _mapController.move(_currentGpsPosition!, 17.0);
          if (kDebugMode)
            print(
                "<<< _initializeGpsReal: Karte auf erste, nahe ECHTE GPS-Position ($meters m entfernt von ${centerForDistanceCheck}) zentriert. >>>");
        } else {
          if (kDebugMode)
            print(
                "<<< _initializeGpsReal: Erste ECHTE GPS-Position ($meters m entfernt) ist zu weit weg (> $centerOnGpsMaxDistanceMeters m von ${centerForDistanceCheck}). Karte NICHT zentriert. >>>");
          _showSnackbar(
              "Echte GPS-Position zu weit entfernt vom aktuellen Standort.",
              durationSeconds: 4);
        }
      }
      // Routen neu berechnen, wenn GPS-Position sich ändert und ein Ziel existiert
      if (_endLatLng != null) _calculateAndDisplayRoute();
    }, onError: (error) {
      if (kDebugMode)
        print(
            ">>> _initializeGpsReal: Fehler im ECHTEN GPS Positions-Stream: $error");
      _showErrorDialog("Fehler GPS-Empfang: $error");
    });
  }

  Marker _createMarker(
      LatLng position, Color color, IconData icon, String tooltip,
      {double size = 30.0}) {
    return Marker(
      width: markerWidth,
      height: markerHeight,
      point: position,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: size),
      ),
      alignment: Alignment.center,
    );
  }

  Future<void> _calculateAndDisplayRoute() async {
    LatLng? routeStartPoint;
    String startPointType = "";
    final LatLng activeMockCenter =
        _selectedLocation?.initialCenter ?? fallbackInitialCenter;

    if (_useMockLocation) {
      routeStartPoint = activeMockCenter;
      startPointType =
          "Mock Position (${_selectedLocation?.name ?? 'Default'})";
    } else {
      routeStartPoint = _currentGpsPosition;
      startPointType = "Echte GPS Position";
    }

    // Start-Marker immer basierend auf routeStartPoint aktualisieren/setzen
    if (routeStartPoint != null && mounted) {
      setStateIfMounted(() {
        _startMarker = _createMarker(routeStartPoint!, Colors.green,
            Icons.flag_circle, "Start: $startPointType");
      });
    } else if (mounted) {
      // Falls routeStartPoint null ist (z.B. kein GPS Fix)
      setStateIfMounted(() {
        _startMarker = null;
      });
    }

    if (kDebugMode)
      print(
          "<<< _calculateAndDisplayRoute: Aufgerufen. Verwende Startpunkt: $startPointType ($routeStartPoint) >>>");

    if (!mounted) return;
    if (!_isDataReady) {
      _showErrorDialog(
          "Kartendaten für ${_selectedLocation?.name ?? 'ausgewählten Standort'} nicht bereit.");
      return;
    }
    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      _showErrorDialog(
          "Routing-Daten für ${_selectedLocation?.name ?? 'ausgewählten Standort'} nicht verfügbar.");
      return;
    }
    if (routeStartPoint == null || _endLatLng == null) {
      // Alte Route löschen, wenn Start- oder Endpunkt ungültig wird
      setStateIfMounted(() => _routePolyline = null);
      if (routeStartPoint == null)
        _showErrorDialog("Startpunkt (GPS/Mock) nicht verfügbar.");
      // Kein Fehlerdialog für fehlendes Ziel, da das normal sein kann
      return;
    }

    setStateIfMounted(() => _isCalculatingRoute = true);
    if (kDebugMode)
      print(
          "<<< _calculateAndDisplayRoute: Starte Routenberechnung von $routeStartPoint nach $_endLatLng >>>");

    try {
      final GraphNode? startNode =
          _routingGraph!.findNearestNode(routeStartPoint);
      final GraphNode? endNode = _routingGraph!.findNearestNode(_endLatLng!);

      if (startNode == null || endNode == null) {
        _showErrorDialog("Start/Ziel nicht auf Wegenetz gefunden.");
        setStateIfMounted(() => _routePolyline = null);
      } else if (startNode.id == endNode.id) {
        _showSnackbar("Start/Ziel identisch.");
        _clearRoute(
            showConfirmation: false,
            clearMarkers: false); // Nur Polyline löschen
      } else {
        _routingGraph!.resetAllNodeCosts();
        final List<LatLng>? routePoints =
            await RoutingService.findPath(_routingGraph!, startNode, endNode);
        if (!mounted) return;
        setStateIfMounted(() {
          if (routePoints != null && routePoints.isNotEmpty) {
            _routePolyline = Polyline(
              points: routePoints,
              strokeWidth: 5.0,
              color: Colors.deepPurpleAccent,
            );
            _showSnackbar("Route berechnet.", durationSeconds: 3);
          } else {
            _routePolyline = null;
            _showErrorDialog("Keine Route gefunden.");
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode)
        print(
            ">>> _calculateAndDisplayRoute: Fehler Routenberechnung: $e\n$stacktrace");
      _showErrorDialog("Fehler Routenberechnung: $e");
      setStateIfMounted(() => _routePolyline = null);
    } finally {
      if (mounted) {
        setStateIfMounted(() => _isCalculatingRoute = false);
      }
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    if (kDebugMode) print("<<< _handleMapTap: Auf Karte getippt: $latLng >>>");
    if (!mounted) return;

    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      setStateIfMounted(() => _showSearchResults = false);
    } else if (_showSearchResults) {
      setStateIfMounted(() => _showSearchResults = false);
    }

    if (_isCalculatingRoute) return;

    final bool isNewTarget = _endLatLng == null || _endMarker == null;

    if (isNewTarget) {
      setStateIfMounted(() {
        _endLatLng = latLng;
        _endMarker = _createMarker(
            latLng, Colors.red, Icons.flag_circle, "Ziel (Karte)");
        _selectedSearchFeatureForEnd = null;
      });
      _calculateAndDisplayRoute();
    } else {
      _showConfirmationDialog(
          "Neues Ziel?", "Altes Ziel verwerfen und neues Ziel setzen?", () {
        if (!mounted) return;
        setStateIfMounted(() {
          _routePolyline = null;
          _endMarker = null;
          _endLatLng = latLng;
          _endMarker = _createMarker(
              latLng, Colors.red, Icons.flag_circle, "Ziel (Karte)");
          _selectedSearchFeatureForEnd = null;
        });
        _calculateAndDisplayRoute();
      });
    }
  }

  void _clearRoute({bool showConfirmation = true, bool clearMarkers = true}) {
    final clearAction = () {
      if (!mounted) return;
      setStateIfMounted(() {
        _routePolyline = null;
        if (clearMarkers) {
          _endMarker = null;
          _endLatLng = null;
          _selectedSearchFeatureForEnd = null;
        }
      });
      _showSnackbar(
          clearMarkers ? "Route und Ziel gelöscht." : "Route gelöscht.",
          durationSeconds: 2);
    };

    final bool somethingToDelete =
        _routePolyline != null || (clearMarkers && _endMarker != null);

    if (showConfirmation && somethingToDelete) {
      _showConfirmationDialog(
          clearMarkers ? "Route & Ziel löschen?" : "Route löschen?",
          clearMarkers
              ? "Route und Ziel wirklich löschen?"
              : "Route wirklich löschen?",
          clearAction);
    } else if (somethingToDelete) {
      clearAction();
    }
  }

  void _centerOnGps() {
    if (!mounted) return;
    LatLng? centerTarget;
    if (_useMockLocation) {
      centerTarget = _selectedLocation?.initialCenter ?? fallbackInitialCenter;
    } else {
      centerTarget = _currentGpsPosition;
    }

    if (centerTarget != null) {
      _mapController.move(centerTarget, 17.0); // Ggf. Zoom anpassen
      if (kDebugMode) {
        print(
            "<<< _centerOnGps: Zentriere auf aktuell verwendete Position: $centerTarget (${_useMockLocation ? 'Mock für ' + (_selectedLocation?.name ?? 'Default') : 'Echt'}) >>>");
      }
    } else {
      if (kDebugMode) print(">>> _centerOnGps: Keine Position verfügbar.");
      _showSnackbar("Keine Position verfügbar.");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Fehler"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showSnackbar(String message, {int durationSeconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConfirmationDialog(
      String title, String content, VoidCallback onConfirm) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text("Abbrechen"),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
            TextButton(
              child: const Text("Bestätigen"),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> activeMarkers = [];
    if (_currentLocationMarker != null) {
      activeMarkers.add(_currentLocationMarker!);
    }
    if (_startMarker != null) {
      activeMarkers.add(_startMarker!);
    }
    if (_endMarker != null) {
      activeMarkers.add(_endMarker!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campground Navigator"),
        actions: [
          // NEU: Dropdown zur Standortauswahl
          if (_availableLocations.isNotEmpty && _selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: DropdownButtonHideUnderline(
                // Optional: Entfernt die Standard-Unterstreichung
                child: DropdownButton<LocationInfo>(
                  value: _selectedLocation,
                  icon: const Icon(Icons.public,
                      color: Colors.white), // Icon für das Dropdown
                  dropdownColor: Colors
                      .deepOrange[700], // Hintergrundfarbe der Dropdown-Liste
                  style: const TextStyle(
                      color: Colors
                          .white), // Textfarbe für ausgewählten Eintrag in der AppBar
                  items: _availableLocations
                      .map<DropdownMenuItem<LocationInfo>>(
                          (LocationInfo location) {
                    return DropdownMenuItem<LocationInfo>(
                      value: location,
                      child: Text(
                        location.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14), // Textfarbe für Items in der Liste
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onLocationChanged,
                  hint: const Text("Standort wählen",
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
          Tooltip(
            message: _useMockLocation
                ? "Echtes GPS aktivieren"
                : "Mock-Position aktivieren",
            child: IconButton(
              icon: Icon(
                  _useMockLocation ? Icons.location_on : Icons.location_off),
              color: _useMockLocation ? Colors.orangeAccent : Colors.white,
              onPressed: _toggleMockLocation,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Verwende initialCenter des ausgewählten Standorts oder Fallback
              initialCenter:
                  _selectedLocation?.initialCenter ?? fallbackInitialCenter,
              initialZoom: 17.0, // TODO: Ggf. Zoom aus LocationInfo übernehmen
              minZoom: 13.0,
              maxZoom: 19.0,
              onTap: _handleMapTap,
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture && _searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                  if (mounted) {
                    setStateIfMounted(() => _showSearchResults = false);
                  }
                } else if (hasGesture && _showSearchResults) {
                  setStateIfMounted(() => _showSearchResults = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'de.tomsoft.campsitenav.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (_isDataReady &&
                  _routePolyline !=
                      null) // Zeige Polyline nur wenn Daten bereit sind
                PolylineLayer(polylines: [_routePolyline!]),
              if (_isDataReady &&
                  activeMarkers
                      .isNotEmpty) // Zeige Marker nur wenn Daten bereit sind
                MarkerLayer(markers: activeMarkers),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 6.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText:
                        "Suche in ${_selectedLocation?.name ?? 'aktuellem Standort'}...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                  enabled:
                      _isDataReady, // Deaktiviere Suche, wenn Daten nicht bereit sind
                ),
              ),
            ),
          ),
          if (_showSearchResults && _searchResults.isNotEmpty && _isDataReady)
            Positioned(
              top: 75,
              left: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  if (mounted) {
                    setStateIfMounted(() => _showSearchResults = false);
                    _searchFocusNode.unfocus();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final feature = _searchResults[index];
                        return ListTile(
                          leading: Icon(_getIconForFeatureType(feature.type)),
                          title: Text(feature.name),
                          subtitle: Text("Typ: ${feature.type}"),
                          onTap: () {
                            _selectFeatureAndSetPoint(feature);
                          },
                          dense: true,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          if (_isCalculatingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          // Zeige Ladeindikator spezifischer, wenn _isDataReady false ist NACHDEM ein Standort ausgewählt wurde
          if (!_isDataReady) // Allgemeiner Ladeindikator, wenn Daten initial nicht bereit sind
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                        "Lade Kartendaten für ${_selectedLocation?.name ?? 'Start-Standort'}...",
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                )),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isDataReady && (_routePolyline != null || _endMarker != null))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: "clearRouteAndTargetBtn",
                onPressed: () => _clearRoute(clearMarkers: true),
                tooltip: 'Route & Ziel löschen',
                child: const Icon(Icons.delete_outline),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.small(
              heroTag: "centerBtn",
              onPressed: _centerOnGps,
              tooltip: 'Auf aktuelle Position zentrieren',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  IconData _getIconForFeatureType(String type) {
    switch (type.toLowerCase()) {
      case 'parking':
        return Icons.local_parking;
      case 'building':
        return Icons.business;
      case 'shop':
        return Icons.store;
      case 'amenity':
        return Icons.place;
      case 'tourism':
        return Icons.attractions;
      case 'reception':
        return Icons.room_service;
      case 'sanitary':
        return Icons.wc;
      case 'restaurant':
        return Icons.restaurant;
      default:
        return Icons.location_pin;
    }
  }
}
// [Ende lib/main.dart - Mit Standortauswahl-Dropdown]
