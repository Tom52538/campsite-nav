// [Start lib/main.dart - Versuch Klick auf Suchergebnis zu ermöglichen]
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

  static const LatLng defaultInitialCenter =
      LatLng(51.02518780487824, 5.858832278816441);
  static const double markerWidth = 40.0;
  static const double markerHeight = 40.0;
  static const double centerOnGpsMaxDistanceMeters = 5000;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print(
          "<<< initState: MapScreen wird initialisiert. Mock-Location: $_useMockLocation >>>");
    }
    _loadData();
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

  void _toggleMockLocation() {
    if (!mounted) return;
    setState(() {
      _useMockLocation = !_useMockLocation;
      _initializeGpsOrMock();
    });
    _showSnackbar(
        _useMockLocation
            ? "Mock-Position (Firmengelände) aktiviert."
            : "Echtes GPS aktiviert (mit Distanzprüfung).",
        durationSeconds: 4);
    if (kDebugMode) {
      print(
          "<<< _toggleMockLocation: Mock-Location ist jetzt: $_useMockLocation >>>");
    }
  }

  void _initializeGpsOrMock() {
    _positionStreamSubscription?.cancel();
    setStateIfMounted(() {
      _currentGpsPosition = null;
      _currentLocationMarker = null;
    });

    if (_useMockLocation) {
      if (kDebugMode) {
        print(
            "<<< _initializeGpsOrMock: Mock-Modus AKTIV. Setze Position auf defaultInitialCenter. >>>");
      }
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _currentGpsPosition = defaultInitialCenter;
            _currentLocationMarker = _createMarker(_currentGpsPosition!,
                Colors.orangeAccent, Icons.pin_drop, "Mock Position (Gelände)");
            _mapController.move(_currentGpsPosition!, 17.0);
            print(
                "<<< _initializeGpsOrMock: Map auf Mock Position zentriert >>>");
          });
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
    // ... (Code unverändert) ...
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

  Future<void> _loadData() async {
    // ... (Code unverändert) ...
    if (kDebugMode) {
      print("<<< _loadData: Starte das Laden der GeoJSON Daten... >>>");
    }
    if (!mounted) return;
    setStateIfMounted(() {
      _isDataReady = false;
    });

    try {
      final String geoJsonString =
          await rootBundle.loadString('assets/data/export.geojson');
      if (kDebugMode) {
        print(
            "<<< _loadData: GeoJSON String erfolgreich geladen (${geoJsonString.length} Zeichen). >>>");
      }

      final RoutingGraph graph =
          GeojsonParserService.parseGeoJson(geoJsonString);
      if (kDebugMode) {
        if (graph.nodes.isEmpty) {
          print(
              ">>> _loadData WARNUNG: Routing Graph vom Parser erhalten, aber er hat 0 Knoten.");
        } else {
          print(
              "<<< _loadData: Routing Graph vom Parser erhalten mit ${graph.nodes.length} Knoten. >>>");
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
          _isDataReady = false;
          if (kDebugMode) {
            print(
                ">>> _loadData ERROR: Routing Graph nicht korrekt initialisiert oder leer. _isDataReady bleibt false.");
          }
          _showErrorDialog("Fehler bei der Initialisierung der Routing-Daten.");
        }
      });
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            ">>> _loadData FATAL ERROR: Fehler beim Laden/Parsen der GeoJSON Daten: $e\n$stacktrace");
      }
      if (!mounted) return;
      setStateIfMounted(() {
        _isDataReady = false;
      });
      _showErrorDialog(
          'Schwerwiegender Fehler beim Laden der Kartendaten: $e.');
    }
  }

  void _onSearchChanged() {
    // ... (Code unverändert) ...
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
      _showSearchResults = _searchFocusNode.hasFocus && results.isNotEmpty;
    });
  }

  void _onSearchFocusChanged() {
    // ... (Code unverändert) ...
    if (!mounted) return;
    setStateIfMounted(() {
      _showSearchResults = _searchFocusNode.hasFocus &&
          _searchResults.isNotEmpty &&
          _searchController.text.isNotEmpty;
    });
  }

  void _selectFeatureAndSetPoint(SearchableFeature feature) {
    // ... (Code unverändert) ...
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
    // ... (Code unverändert) ...
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
        if (kDebugMode) {
          print(">>> _initializeGpsReal: GPS-Dienst nicht aktiviert.");
        }
        return;
      }
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print(
              "<<< _initializeGpsReal: GPS-Berechtigung ist 'denied', frage an...");
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorDialog("GPS-Berechtigung verweigert.");
          if (kDebugMode) {
            print(
                ">>> _initializeGpsReal: GPS-Berechtigung nach Anfrage 'denied'.");
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog("GPS-Berechtigung dauerhaft verweigert.");
        if (kDebugMode) {
          print(">>> _initializeGpsReal: GPS-Berechtigung 'deniedForever'.");
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print(">>> _initializeGpsReal: Fehler bei Berechtigungsprüfung: $e");
      }
      _showErrorDialog("Fehler GPS-Berechtigungen: $e");
      return;
    }

    if (kDebugMode) {
      print(
          "<<< _initializeGpsReal: GPS-Berechtigung erteilt. Starte Positions-Stream...");
    }

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
      if (kDebugMode) {
        print(
            "<<< _initializeGpsReal: Neue ECHTE GPS Position: $_currentGpsPosition >>>");
      }

      if (isFirstFix && _currentGpsPosition != null) {
        final Distance distance = Distance();
        final double meters =
            distance(defaultInitialCenter, _currentGpsPosition!);
        if (meters <= centerOnGpsMaxDistanceMeters) {
          _mapController.move(_currentGpsPosition!, 17.0);
          if (kDebugMode) {
            print(
                "<<< _initializeGpsReal: Karte auf erste, nahe ECHTE GPS-Position ($meters m entfernt) zentriert. >>>");
          }
        } else {
          if (kDebugMode) {
            print(
                "<<< _initializeGpsReal: Erste ECHTE GPS-Position ($meters m entfernt) ist zu weit weg (> $centerOnGpsMaxDistanceMeters m). Karte NICHT zentriert. >>>");
          }
          _showSnackbar("Echte GPS-Position zu weit entfernt.",
              durationSeconds: 4);
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print(
            ">>> _initializeGpsReal: Fehler im ECHTEN GPS Positions-Stream: $error");
      }
      _showErrorDialog("Fehler GPS-Empfang: $error");
    });
  }

  Marker _createMarker(
      LatLng position, Color color, IconData icon, String tooltip,
      {double size = 30.0}) {
    // ... (Code unverändert) ...
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
    // ... (Code unverändert) ...
    LatLng? routeStartPoint;
    String startPointType = "";
    if (_useMockLocation) {
      routeStartPoint = defaultInitialCenter;
      startPointType = "Mock Position";
      if (_startMarker == null && mounted) {
        setStateIfMounted(() {
          _startMarker = _createMarker(defaultInitialCenter, Colors.green,
              Icons.flag_circle, "Start: Mock Position");
        });
      }
    } else {
      routeStartPoint = _currentGpsPosition;
      startPointType = "Echte GPS Position";
      if (_startMarker == null && _currentGpsPosition != null && mounted) {
        setStateIfMounted(() {
          _startMarker = _createMarker(_currentGpsPosition!, Colors.green,
              Icons.flag_circle, "Start: GPS Position");
        });
      }
    }
    if (kDebugMode) {
      print(
          "<<< _calculateAndDisplayRoute: Aufgerufen. Verwende Startpunkt: $startPointType ($routeStartPoint) >>>");
    }
    if (!mounted) return;
    if (!_isDataReady) {
      _showErrorDialog("Kartendaten nicht bereit.");
      return;
    }
    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      _showErrorDialog("Routing-Daten nicht verfügbar.");
      return;
    }
    if (routeStartPoint == null || _endLatLng == null) {
      _showErrorDialog(routeStartPoint == null
          ? "Startpunkt (GPS/Mock) nicht verfügbar."
          : "Zielpunkt nicht gesetzt.");
      return;
    }
    setStateIfMounted(() => _isCalculatingRoute = true);
    if (kDebugMode) {
      print(
          "<<< _calculateAndDisplayRoute: Starte Routenberechnung von $routeStartPoint nach $_endLatLng >>>");
    }

    try {
      final GraphNode? startNode =
          _routingGraph!.findNearestNode(routeStartPoint);
      final GraphNode? endNode = _routingGraph!.findNearestNode(_endLatLng!);
      if (startNode == null || endNode == null) {
        _showErrorDialog("Start/Ziel nicht auf Wegenetz gefunden.");
        if (kDebugMode) {
          print(
              ">>> _calculateAndDisplayRoute: Start/Endknoten nicht im Graphen gefunden.");
        }
      } else if (startNode.id == endNode.id) {
        _showSnackbar("Start/Ziel identisch.");
        if (kDebugMode) {
          print("<<< _calculateAndDisplayRoute: Start/Endknoten identisch.");
        }
        _clearRoute(showConfirmation: false, clearMarkers: false);
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
            if (kDebugMode) {
              print(
                  "<<< _calculateAndDisplayRoute: Route gefunden (${routePoints.length} Punkte). >>>");
            }
            _showSnackbar("Route berechnet.", durationSeconds: 3);
          } else {
            _routePolyline = null;
            _showErrorDialog("Keine Route gefunden.");
            if (kDebugMode) {
              print("<<< _calculateAndDisplayRoute: Keine Route gefunden.");
            }
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            ">>> _calculateAndDisplayRoute: Fehler Routenberechnung: $e\n$stacktrace");
      }
      _showErrorDialog("Fehler Routenberechnung: $e");
    } finally {
      if (mounted) {
        setStateIfMounted(() => _isCalculatingRoute = false);
      }
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    // ... (Code unverändert) ...
    if (kDebugMode) {
      print("<<< _handleMapTap: Auf Karte getippt: $latLng >>>");
    }
    if (!mounted) return;
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
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
      if (kDebugMode) {
        print(
            "<<< _handleMapTap: Ziel via Karte gesetzt. Starte Berechnung. >>>");
      }
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
          if (kDebugMode) {
            print("<<< _handleMapTap: Neues Ziel nach Bestätigung. >>>");
          }
        });
        _calculateAndDisplayRoute();
      });
    }
  }

  void _clearRoute({bool showConfirmation = true, bool clearMarkers = true}) {
    // ... (Code unverändert) ...
    final clearAction = () {
      if (!mounted) return;
      setStateIfMounted(() {
        _routePolyline = null;
        if (clearMarkers) {
          _endMarker = null;
          _endLatLng = null;
          _selectedSearchFeatureForEnd = null;
          if (kDebugMode) {
            print("<<< _clearRoute: Route UND Ziel gelöscht. >>>");
          }
        } else {
          if (kDebugMode) {
            print("<<< _clearRoute: Nur Route gelöscht. >>>");
          }
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
    // ... (Code unverändert) ...
    if (!mounted) return;
    if (_currentGpsPosition != null) {
      _mapController.move(_currentGpsPosition!, 17.0);
      if (kDebugMode) {
        print(
            "<<< _centerOnGps: Zentriere auf aktuell verwendete Position: $_currentGpsPosition (${_useMockLocation ? 'Mock' : 'Echt'}) >>>");
      }
    } else {
      if (kDebugMode) {
        print(">>> _centerOnGps: Keine Position verfügbar.");
      }
      _showSnackbar("Keine Position verfügbar.");
    }
  }

  void _showErrorDialog(String message) {
    // ... (Code unverändert) ...
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
      if (kDebugMode) {
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
    // ... (Code unverändert) ...
    if (!mounted) {
      if (kDebugMode) {
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
    // ... (Code unverändert) ...
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
      if (kDebugMode) {
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
    if (_currentLocationMarker != null)
      activeMarkers.add(_currentLocationMarker!);
    // Start-Marker wird jetzt nur noch intern in _calculateRoute gesetzt
    if (_startMarker != null)
      activeMarkers.add(
          _startMarker!); // WIEDER HINZUGEFÜGT, wird für Mock/GPS Start gesetzt
    if (_endMarker != null) activeMarkers.add(_endMarker!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campground Navigator"),
        actions: [
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
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultInitialCenter,
              initialZoom: 17.0,
              minZoom: 13.0,
              maxZoom: 19.0,
              onTap: _handleMapTap,
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture && _searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                  if (mounted) {
                    setStateIfMounted(() => _showSearchResults = false);
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'de.tomsoft.campsitenav.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (_routePolyline != null)
                PolylineLayer(polylines: [_routePolyline!]),
              if (activeMarkers.isNotEmpty) MarkerLayer(markers: activeMarkers),
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
                    hintText: "Zielpunkt suchen...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              if (mounted) {
                                setStateIfMounted(() {
                                  _searchResults = [];
                                  _showSearchResults = false;
                                });
                              }
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          // === WICHTIGE ÄNDERUNG HIER: GestureDetector um die Suchergebnisliste ===
          if (_showSearchResults && _searchResults.isNotEmpty)
            Positioned(
              top: 75, left: 10, right: 10,
              // GestureDetector fängt Klicks ab, auch wenn darunterliegende Widgets sie vielleicht blockieren
              child: GestureDetector(
                // Verhindert, dass Klicks zur Karte durchgehen, wenn die Liste sichtbar ist
                onTap: () {
                  if (kDebugMode)
                    print("GestureDetector tapped - preventing map tap.");
                  // Optional: Fokus wegnehmen, wenn auf den leeren Bereich der Card geklickt wird
                  // _searchFocusNode.unfocus();
                  // setStateIfMounted(() => _showSearchResults = false);
                },
                // Sorgt dafür, dass der GestureDetector den Bereich ausfüllt
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
                            // Der eigentliche onTap für das Listenelement
                            if (kDebugMode) {
                              print(
                                  "<<< ListTile tapped! Feature: ${feature.name} >>>");
                            }
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
          // ================================================================
          if (_isCalculatingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          if (!_isDataReady && _routingGraph == null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: const Center(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Lade Kartendaten...",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
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
          if (_routePolyline != null || _endMarker != null)
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
// [Ende lib/main.dart - Versuch Klick auf Suchergebnis zu ermöglichen]
