// [Start lib/main.dart - Korrigiert gemäß Log (curly braces V3)]
// (Basierend auf der vom Nutzer als main_dart.txt Source 1-232 bereitgestellten Datei)
import 'dart:async';
import 'dart:convert'; // Für jsonDecode
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für rootBundle
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Wird für Distance benötigt
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:provider/provider.dart';

// Eigene Imports
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => LocationProvider(),
      child: const MyApp(),
    ),
  );
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

  bool _isDataReady = false;
  bool _useMockLocation = true;

  LocationInfo? _lastProcessedLocation;

  static const LatLng fallbackInitialCenter =
      LatLng(51.02518780487824, 5.858832278816441);
  static const double markerWidth = 40.0;
  static const double markerHeight = 40.0;
  static const double centerOnGpsMaxDistanceMeters = 5000;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialLocation =
          Provider.of<LocationProvider>(context, listen: false)
              .selectedLocation;
      if (initialLocation != null) {
        _lastProcessedLocation = initialLocation;
        if (kDebugMode) {
          print(
              "<<< initState (postFrame): MapScreen wird initialisiert. Ausgewählter Standort vom Provider: ${initialLocation.name}. Mock-Location: $_useMockLocation >>>");
        }
        _loadDataForLocation(initialLocation);
        _initializeGpsOrMock(initialLocation);
      } else {
        if (kDebugMode) {
          print(
              "<<< initState (postFrame): Kein initialer Standort vom Provider verfügbar. >>>");
        }
      }
    });
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocationProvider = Provider.of<LocationProvider>(context);
    final newSelectedLocation = currentLocationProvider.selectedLocation;
    if (newSelectedLocation != null &&
        newSelectedLocation != _lastProcessedLocation) {
      if (kDebugMode) {
        print(
            "<<< didChangeDependencies: Standortwechsel erkannt von ${_lastProcessedLocation?.name} zu ${newSelectedLocation.name} >>>");
      }
      _handleLocationChangeUIUpdates(newSelectedLocation);
      _lastProcessedLocation = newSelectedLocation;
    }
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

  void _onLocationSelectedFromDropdown(LocationInfo? newLocation) {
    if (newLocation == null) {
      return;
    }
    Provider.of<LocationProvider>(context, listen: false)
        .selectLocation(newLocation);
  }

  void _handleLocationChangeUIUpdates(LocationInfo newLocation) {
    if (!mounted) {
      return;
    }
    setState(() {
      _routingGraph = null;
      _searchableFeatures = [];
      _routePolyline = null;
      _startMarker = null;
      _endMarker = null;
      _endLatLng = null;
      _isDataReady = false;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });

    _mapController.move(newLocation.initialCenter, 17.0);
    _showSnackbar("Standort geändert zu: ${newLocation.name}",
        durationSeconds: 3);
    if (kDebugMode) {
      print(
          "<<< _handleLocationChangeUIUpdates: Standort UI Updates für ${newLocation.name}. GeoJSON: ${newLocation.geojsonAssetPath} >>>");
    }

    _loadDataForLocation(newLocation);
    _initializeGpsOrMock(newLocation);
  }

  void _toggleMockLocation() {
    if (!mounted) {
      return;
    }
    final currentLocation =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    setState(() {
      _useMockLocation = !_useMockLocation;
      if (currentLocation != null) {
        _initializeGpsOrMock(currentLocation);
      }
    });
    _showSnackbar(
        _useMockLocation
            ? "Mock-Position (${currentLocation?.name ?? 'Fallback'}) aktiviert."
            : "Echtes GPS aktiviert (mit Distanzprüfung).",
        durationSeconds: 4);
    if (kDebugMode) {
      print(
          "<<< _toggleMockLocation: Mock-Location ist jetzt: $_useMockLocation für Standort ${currentLocation?.name} >>>");
    }
  }

  void _initializeGpsOrMock(LocationInfo location) {
    _positionStreamSubscription?.cancel();
    setStateIfMounted(() {
      _currentGpsPosition = null;
      _currentLocationMarker = null;
    });
    final LatLng activeInitialCenterForMock = location.initialCenter;

    if (_useMockLocation) {
      if (kDebugMode) {
        print(
            "<<< _initializeGpsOrMock: Mock-Modus AKTIV. Setze Position auf initialCenter von ${location.name}: $activeInitialCenterForMock. >>>");
      }
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _currentGpsPosition = activeInitialCenterForMock;
            _currentLocationMarker = _createMarker(
                _currentGpsPosition!,
                Colors.orangeAccent,
                Icons.pin_drop,
                "Mock Position (${location.name})");
            _mapController.move(_currentGpsPosition!, 17.0);
            if (kDebugMode) {
              print(
                  "<<< _initializeGpsOrMock: Map auf Mock Position für ${location.name} zentriert >>>");
            }
          });
          if (_endLatLng != null) {
            _calculateAndDisplayRoute();
          }
        }
      });
    } else {
      if (kDebugMode) {
        print(
            "<<< _initializeGpsOrMock: Echtes GPS AKTIV. Starte Initialisierung für ${location.name}... >>>");
      }
      _initializeGpsReal(location);
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

  Future<void> _loadDataForLocation(LocationInfo location) async {
    final String currentGeoJsonPath = location.geojsonAssetPath;
    if (kDebugMode) {
      print(
          "<<< _loadDataForLocation: Starte das Laden der GeoJSON Daten von: $currentGeoJsonPath für Standort ${location.name}. >>>");
    }
    if (!mounted) {
      return;
    }

    if (!_isCalculatingRoute) {
      setStateIfMounted(() {
        _isDataReady = false;
      });
    }

    try {
      final String geoJsonString =
          await rootBundle.loadString(currentGeoJsonPath);
      if (kDebugMode) {
        print(
            "<<< _loadDataForLocation: GeoJSON String für ${location.name} erfolgreich geladen (${geoJsonString.length} Zeichen). >>>");
      }

      // TODO Phase 2, Schritt 3: Hier den GeojsonParserService modifizieren und aufrufen, um den Graph zu parsen

      final RoutingGraph graph =
          GeojsonParserService.parseGeoJson(geoJsonString);
      final List<SearchableFeature> features =
          _extractSearchableFeaturesFromGeoJson(geoJsonString);
      if (!mounted) {
        return;
      }
      final currentSelectedLocationFromProvider =
          Provider.of<LocationProvider>(context, listen: false)
              .selectedLocation;
      if (currentSelectedLocationFromProvider?.id == location.id) {
        setStateIfMounted(() {
          _routingGraph = graph;
          _searchableFeatures = features;
          if (_routingGraph != null && _routingGraph!.nodes.isNotEmpty) {
            _isDataReady = true;
            if (kDebugMode) {
              print(
                  "<<< _loadDataForLocation SUCCESS: Daten für ${location.name} sind jetzt bereit. Graph: ${_routingGraph!.nodes.length} Knoten. Features: ${_searchableFeatures.length}. >>>");
            }
            if (_endLatLng != null) {
              _calculateAndDisplayRoute();
            }
          } else {
            _isDataReady = false;
            if (kDebugMode) {
              print(
                  ">>> _loadDataForLocation ERROR: Routing Graph für ${location.name} nicht korrekt initialisiert oder leer. _isDataReady bleibt false.");
            }
            _showErrorDialog(
                "Fehler bei der Initialisierung der Routing-Daten für ${location.name}.");
          }
        });
      } else {
        if (kDebugMode) {
          print(
              "<<< _loadDataForLocation: Daten für ${location.name} geladen, aber Standort wurde zwischenzeitlich zu ${currentSelectedLocationFromProvider?.name} gewechselt. Verwerfe geladene Daten. >>>");
        }
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            ">>> _loadDataForLocation FATAL ERROR: Fehler beim Laden/Parsen der GeoJSON Daten von $currentGeoJsonPath: $e\n$stacktrace");
      }
      if (!mounted) {
        return;
      }
      final currentSelectedLocationFromProvider =
          Provider.of<LocationProvider>(context, listen: false)
              .selectedLocation;
      if (currentSelectedLocationFromProvider?.id == location.id) {
        setStateIfMounted(() {
          _isDataReady = false;
        });
        _showErrorDialog(
            'Schwerwiegender Fehler beim Laden der Kartendaten von $currentGeoJsonPath: $e.');
      }
    }
  }

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }

    _searchController.clear();
    _searchResults = [];
    _showSearchResults = false;
    _searchFocusNode.unfocus();

    setStateIfMounted(() {
      _endLatLng = feature.center;
      _endMarker = _createMarker(feature.center, Colors.red, Icons.flag_circle,
          "Ziel: ${feature.name}");
      if (kDebugMode) {
        print(
            "<<< _selectFeatureAndSetPoint: Zielpunkt gesetzt auf: ${feature.name} >>>");
      }
      _calculateAndDisplayRoute();
    });
    _mapController.move(feature.center, 18.0);
  }

  Future<void> _initializeGpsReal(LocationInfo location) async {
    if (kDebugMode) {
      // Log line 608 (Source 240) -> korrigiert in der Version, die ich das letzte Mal geschickt habe. Dies ist die Version des Users, daher hier nochmal fixen.
      print(
          "<<< _initializeGpsReal: Starte ECHTE GPS Initialisierung für ${location.name}... >>>");
    }
    if (!mounted) {
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Log line 574 (Source 239)
        _showErrorDialog("GPS ist deaktiviert. Bitte aktiviere es.");
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Log line 574 (Source 239)
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Log line 574 (Source 239)
          _showErrorDialog("GPS-Berechtigung verweigert.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Log line 574 (Source 239)
        _showErrorDialog("GPS-Berechtigung dauerhaft verweigert.");
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        // Log line 608 (Source 240)
        print(">>> _initializeGpsReal: Fehler bei Berechtigungsprüfung: $e");
      }
      _showErrorDialog("Fehler GPS-Berechtigungen: $e");
      return;
    }

    final LatLng centerForDistanceCheck = location.initialCenter;
    _positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 5))
        .listen((Position position) {
      if (!mounted) {
        return;
      }
      final bool isFirstFix = _currentGpsPosition == null;
      setStateIfMounted(() {
        _currentGpsPosition = LatLng(position.latitude, position.longitude);
        _currentLocationMarker = _createMarker(_currentGpsPosition!,
            Colors.blueAccent, Icons.circle, "Meine Position");
      });
      if (kDebugMode) {
        // Log line 608 (Source 240)
        print(
            "<<< _initializeGpsReal: Neue ECHTE GPS Position: $_currentGpsPosition >>>");
      }

      if (isFirstFix && _currentGpsPosition != null) {
        // Log line 574 (Source 239)
        final Distance distance = Distance();
        final double meters =
            distance(centerForDistanceCheck, _currentGpsPosition!);
        if (meters <= centerOnGpsMaxDistanceMeters) {
          // Log line 574 (Source 239)
          _mapController.move(_currentGpsPosition!, 17.0);
          if (kDebugMode) {
            // Log line 608 (Source 240)
            print(
                "<<< _initializeGpsReal: Karte auf erste, nahe ECHTE GPS-Position ($meters m entfernt von $centerForDistanceCheck) zentriert. >>>");
          }
        } else {
          // Log line 604 (Source 239)
          if (kDebugMode) {
            // Log line 608 (Source 240)
            print(
                "<<< _initializeGpsReal: Erste ECHTE GPS-Position ($meters m entfernt) ist zu weit weg (> $centerOnGpsMaxDistanceMeters m von $centerForDistanceCheck). Karte NICHT zentriert. >>>");
          }
          _showSnackbar(
              "Echte GPS-Position zu weit entfernt vom aktuellen Standort.",
              durationSeconds: 4);
        }
      }
      if (_endLatLng != null) {
        // Log line 574 (Source 239)
        _calculateAndDisplayRoute();
      }
    }, onError: (error) {
      if (kDebugMode) {
        // Log line 608 (Source 240)
        print(
            ">>> _initializeGpsReal: Fehler im ECHTEN GPS Positions-Stream: $error");
      }
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
        // prefer_const_constructors at line 598 - ignored for now
        message: tooltip,
        child: Icon(icon, color: color, size: size),
      ),
      alignment: Alignment.center,
    );
  }

  Future<void> _calculateAndDisplayRoute() async {
    final selectedLocationFromProvider =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    LatLng? routeStartPoint;
    String startPointType = "";
    final LatLng activeMockCenter =
        selectedLocationFromProvider?.initialCenter ?? fallbackInitialCenter;
    if (_useMockLocation) {
      routeStartPoint = activeMockCenter;
      startPointType =
          "Mock Position (${selectedLocationFromProvider?.name ?? 'Default'})";
    } else {
      routeStartPoint = _currentGpsPosition;
      startPointType = "Echte GPS Position";
    }

    if (routeStartPoint != null && mounted) {
      setStateIfMounted(() {
        _startMarker = _createMarker(routeStartPoint!, Colors.green,
            Icons.flag_circle, "Start: $startPointType");
      });
    } else if (mounted) {
      setStateIfMounted(() {
        _startMarker = null;
      });
    }

    if (kDebugMode) {
      // Log line 608 (Source 240)
      print(
          "<<< _calculateAndDisplayRoute: Aufgerufen. Verwende Startpunkt: $startPointType ($routeStartPoint) >>>");
    }
    if (!mounted) {
      return;
    }
    if (!_isDataReady) {
      // Log line 574 (Source 239)
      _showErrorDialog(
          "Kartendaten für ${selectedLocationFromProvider?.name ?? 'ausgewählten Standort'} nicht bereit.");
      return;
    }
    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      // Log line 574 (Source 239)
      _showErrorDialog(
          "Routing-Daten für ${selectedLocationFromProvider?.name ?? 'ausgewählten Standort'} nicht verfügbar.");
      return;
    }
    if (routeStartPoint == null || _endLatLng == null) {
      // Log line 574 (Source 239)
      setStateIfMounted(() => _routePolyline = null);
      if (routeStartPoint == null) {
        // Log line 574 (Source 239)
        _showErrorDialog("Startpunkt (GPS/Mock) nicht verfügbar.");
      }
      return;
    }

    setStateIfMounted(() => _isCalculatingRoute = true);
    if (kDebugMode) {
      // Log line 608 (Source 240)
      print(
          "<<< _calculateAndDisplayRoute: Starte Routenberechnung von $routeStartPoint nach $_endLatLng >>>");
    }
    try {
      final GraphNode? startNode =
          _routingGraph!.findNearestNode(routeStartPoint);
      final GraphNode? endNode = _routingGraph!.findNearestNode(_endLatLng!);

      if (startNode == null || endNode == null) {
        // Log line 594 (Source 239)
        _showErrorDialog("Start/Ziel nicht auf Wegenetz gefunden.");
        setStateIfMounted(() => _routePolyline = null);
      } else if (startNode.id == endNode.id) {
        // Log line 594 (Source 239)
        _showSnackbar("Start/Ziel identisch.");
        _clearRoute(showConfirmation: false, clearMarkers: false);
      } else {
        // Log line 604 (Source 239)
        _routingGraph!.resetAllNodeCosts();
        final List<LatLng>? routePoints =
            await RoutingService.findPath(_routingGraph!, startNode, endNode);
        if (!mounted) {
          return;
        }
        setStateIfMounted(() {
          if (routePoints != null && routePoints.isNotEmpty) {
            // Log line 574 (Source 239)
            _routePolyline = Polyline(
              points: routePoints,
              strokeWidth: 5.0,
              color: Colors.deepPurpleAccent,
            );
            _showSnackbar("Route berechnet.", durationSeconds: 3);
          } else {
            // Log line 604 (Source 239)
            _routePolyline = null;
            _showErrorDialog("Keine Route gefunden.");
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        // Log line 608 (Source 240)
        print(
            ">>> _calculateAndDisplayRoute: Fehler Routenberechnung: $e\n$stacktrace");
      }
      _showErrorDialog("Fehler Routenberechnung: $e");
      setStateIfMounted(() => _routePolyline = null);
    } finally {
      if (mounted) {
        // Log line 574 (Source 239)
        setStateIfMounted(() => _isCalculatingRoute = false);
      }
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    if (kDebugMode) {
      print("<<< _handleMapTap: Auf Karte getippt: $latLng >>>");
    }
    if (!mounted) {
      return;
    }

    if (_searchFocusNode.hasFocus) {
      // Log line 618 (Source 240)
      _searchFocusNode.unfocus();
      setStateIfMounted(() => _showSearchResults = false);
    } else if (_showSearchResults) {
      // Log line 618 (Source 240)
      setStateIfMounted(() => _showSearchResults = false);
    }

    if (_isCalculatingRoute) {
      // Log line 618 (Source 240)
      return;
    }

    final bool isNewTarget = _endLatLng == null || _endMarker == null;
    if (isNewTarget) {
      // Log line 618 (Source 240)
      setStateIfMounted(() {
        _endLatLng = latLng;
        _endMarker = _createMarker(
            latLng, Colors.red, Icons.flag_circle, "Ziel (Karte)");
      });
      _calculateAndDisplayRoute();
    } else {
      // Log line 618 (Source 240)
      _showConfirmationDialog(
          "Neues Ziel?", "Altes Ziel verwerfen und neues Ziel setzen?", () {
        if (!mounted) {
          return;
        }
        setStateIfMounted(() {
          _routePolyline = null;
          _endMarker = null;
          _endLatLng = latLng;
          _endMarker = _createMarker(
              latLng, Colors.red, Icons.flag_circle, "Ziel (Karte)");
        });
        _calculateAndDisplayRoute();
      });
    }
  }

  void _clearRoute({bool showConfirmation = true, bool clearMarkers = true}) {
    void doClearAction() {
      if (!mounted) {
        return;
      }
      setStateIfMounted(() {
        _routePolyline = null;
        if (clearMarkers) {
          // Log line 574 (Source 239)
          _endMarker = null;
          _endLatLng = null;
        }
      });
      _showSnackbar(
          clearMarkers ? "Route und Ziel gelöscht." : "Route gelöscht.",
          durationSeconds: 2);
    }

    final bool somethingToDelete =
        _routePolyline != null || (clearMarkers && _endMarker != null);

    if (showConfirmation && somethingToDelete) {
      // Log line 574 (Source 239)
      _showConfirmationDialog(
          clearMarkers ? "Route & Ziel löschen?" : "Route löschen?",
          clearMarkers
              ? "Route und Ziel wirklich löschen?"
              : "Route wirklich löschen?",
          doClearAction);
    } else if (somethingToDelete) {
      // Log line 574 (Source 239)
      doClearAction();
    }
  }

  void _centerOnGps() {
    if (!mounted) {
      return;
    }
    final selectedLocationFromProvider =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    LatLng? centerTarget;
    if (_useMockLocation) {
      centerTarget =
          selectedLocationFromProvider?.initialCenter ?? fallbackInitialCenter;
    } else {
      centerTarget = _currentGpsPosition;
    }

    if (centerTarget != null) {
      // Log line 574 (Source 239)
      _mapController.move(centerTarget, 17.0);
      if (kDebugMode) {
        // Log line 670 (Source 240)
        print(
            "<<< _centerOnGps: Zentriere auf aktuell verwendete Position: $centerTarget (${_useMockLocation ? 'Mock für ${selectedLocationFromProvider?.name ?? 'Default'}' : 'Echt'}) >>>");
      }
    } else {
      // Log line 604/670 (else part) (Source 239/240)
      if (kDebugMode) {
        // Log line 670 (Source 240)
        print(">>> _centerOnGps: Keine Position verfügbar.");
      }
      _showSnackbar("Keine Position verfügbar.");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
      // Log line 574 (Source 239)
      if (kDebugMode) {
        // Log line 608 (Source 240)
        print(
            ">>> _showErrorDialog: Dialog NICHT angezeigt. Message: $message");
      }
      return;
    }
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
                  // Log line 694 (Source 240)
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
    if (!mounted) {
      // Log line 574 (Source 239)
      if (kDebugMode) {
        // Log line 608 (Source 240)
        print(">>> _showSnackbar: Snackbar NICHT angezeigt. Message: $message");
      }
      return;
    }
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
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
      // Log line 574 (Source 239)
      if (kDebugMode) {
        // Log line 608 (Source 240)
        print(
            ">>> _showConfirmationDialog: Dialog NICHT angezeigt. Message: $title");
      }
      return;
    }
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
                  // Log line 729 (Source 240)
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
            TextButton(
              child: const Text("Bestätigen"),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  // Log line 729 (Source 240)
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
    final locationProvider = Provider.of<LocationProvider>(context);
    final selectedLocationFromUI = locationProvider.selectedLocation;
    final availableLocationsFromUI = locationProvider.availableLocations;

    List<Marker> activeMarkers = [];
    if (_currentLocationMarker != null) {
      // Log line 574 (Source 239)
      activeMarkers.add(_currentLocationMarker!);
    }
    if (_startMarker != null) {
      // Log line 574 (Source 239)
      activeMarkers.add(_startMarker!);
    }
    if (_endMarker != null) {
      // Log line 574 (Source 239)
      activeMarkers.add(_endMarker!);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Campground Navigator"),
        actions: [
          if (availableLocationsFromUI.isNotEmpty &&
              selectedLocationFromUI != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<LocationInfo>(
                  value: selectedLocationFromUI,
                  icon: const Icon(Icons.public, color: Colors.white),
                  dropdownColor: Colors.deepOrange[700],
                  style: const TextStyle(color: Colors.white),
                  items: availableLocationsFromUI
                      .map<DropdownMenuItem<LocationInfo>>(
                          (LocationInfo location) {
                    return DropdownMenuItem<LocationInfo>(
                      value: location,
                      child: Text(
                        location.name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onLocationSelectedFromDropdown,
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
              initialCenter: selectedLocationFromUI?.initialCenter ??
                  fallbackInitialCenter,
              initialZoom: 17.0,
              minZoom: 13.0,
              maxZoom: 19.0,
              onTap: _handleMapTap,
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture && _searchFocusNode.hasFocus) {
                  // Log line 937 (Source 241)
                  _searchFocusNode.unfocus();
                  if (mounted) {
                    // Log line 574 (Source 239)
                    setStateIfMounted(() => _showSearchResults = false);
                  }
                } else if (hasGesture && _showSearchResults) {
                  // Log line 937 (Source 241)
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
                  _routePolyline != null) // Log line 574 (Source 239)
                PolylineLayer(polylines: [_routePolyline!]),
              if (_isDataReady &&
                  activeMarkers.isNotEmpty) // Log line 574 (Source 239)
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
                        "Suche in ${selectedLocationFromUI?.name ?? 'aktuellem Standort'}...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                  enabled: _isDataReady,
                ),
              ),
            ),
          ),
          if (_showSearchResults &&
              _searchResults.isNotEmpty &&
              _isDataReady) // Log line 574 (Source 239)
            Positioned(
              top: 75,
              left: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  if (mounted) {
                    // Log line 574 (Source 239)
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
                          onTap: () => _selectFeatureAndSetPoint(feature),
                          dense: true,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          if (_isCalculatingRoute) // Log line 1003 (Source 241)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.3 * 255).round()),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          if (!_isDataReady) // Log line 574 (Source 239)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.7 * 255).round()),
                child: Center(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                        "Lade Kartendaten für ${selectedLocationFromUI?.name ?? 'Start-Standort'}...",
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
          if (_isDataReady &&
              (_routePolyline != null ||
                  _endMarker != null)) // Log line 574 (Source 239)
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
// [Ende lib/main.dart - Korrigiert gemäß Log (curly braces V3)]
