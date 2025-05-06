// [Start lib/main.dart Überarbeitet]
import 'dart:async';
import 'dart:convert'; // Für jsonDecode
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für rootBundle
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

// Eigene Imports
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/routing_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campground Nav App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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
  LatLng? _startLatLng; // Umbenannt von _mockStartLatLng
  LatLng? _endLatLng; // Umbenannt von _mockEndLatLng
  bool _isCalculatingRoute = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchableFeature> _searchResults = [];
  bool _showSearchResults = false;
  SearchableFeature? _selectedSearchFeatureForStart;
  SearchableFeature? _selectedSearchFeatureForEnd;

  bool _isDataReady = false; // NEU: Statusvariable für geladene Daten

  // Statische Werte für die Karte
  static const LatLng defaultInitialCenter = LatLng(51.0245, 5.8630); // Fallback-Zentrum, falls GPS nicht verfügbar
  static const double markerWidth = 80.0;
  static const double markerHeight = 80.0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print("<<< initState: MapScreen wird initialisiert. >>>");
    }
    _loadData();
    _initializeGps();
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

  List<SearchableFeature> _extractSearchableFeaturesFromGeoJson(String geoJsonString) {
    final List<SearchableFeature> features = [];
    final decodedJson = jsonDecode(geoJsonString);

    if (kDebugMode) {
      print("<<< _extractSearchableFeaturesFromGeoJson: Starte Extraktion... >>>");
    }

    if (decodedJson is Map<String, dynamic> &&
        decodedJson['type'] == 'FeatureCollection' &&
        decodedJson['features'] is List) {
      int featureCount = 0;
      for (final featureJson in decodedJson['features']) {
        featureCount++;
        if (featureJson is Map<String, dynamic>) {
          final properties = featureJson['properties'] as Map<String, dynamic>?;
          final geometry = featureJson['geometry'] as Map<String, dynamic>?;

          // *** DEBUGGING-HILFE (AUSKOMMENTIERT) ***
          // Aktivieren Sie diese Logs bei Bedarf, um die Extraktion im Detail zu sehen
          /*
          if (kDebugMode) {
            print("--- Feature $featureCount ---");
            print("    Properties: $properties");
            print("    Geometry type: ${geometry?['type']}");
          }
          */

          if (properties != null && geometry != null) {
            final dynamic id = featureJson['id'] ??
                properties['@id'] ??
                'feature_${DateTime.now().millisecondsSinceEpoch}_$featureCount'; // Eindeutigere Fallback-ID
            final String? name = properties['name'] as String?;
            String type = properties['highway'] as String? ??
                properties['amenity'] as String? ??
                properties['shop'] as String? ??
                properties['building'] as String? ??
                'unknown';

            // *** DEBUGGING-HILFE (AUSKOMMENTIERT) ***
            /*
            if (kDebugMode) {
              print("    Extracted Name: '$name', Type: '$type', ID: '$id'");
            }
            */

            if (name != null && name.isNotEmpty) {
              LatLng? center;
              if (geometry['type'] == 'Point') {
                final coords = geometry['coordinates'] as List?;
                if (coords != null && coords.length >= 2 && coords[0] is num && coords[1] is num) {
                  center = LatLng(coords[1].toDouble(), coords[0].toDouble());
                }
              } else if (geometry['type'] == 'LineString') {
                final coordsList = geometry['coordinates'] as List?;
                if (coordsList != null && coordsList.isNotEmpty) {
                  final firstPointList = coordsList.first as List?;
                  if (firstPointList != null && firstPointList.length >= 2 && firstPointList[0] is num && firstPointList[1] is num) {
                    center = LatLng(firstPointList[1].toDouble(), firstPointList[0].toDouble());
                  }
                }
              } else if (geometry['type'] == 'Polygon') {
                final coordsList = geometry['coordinates'] as List?;
                if (coordsList != null && coordsList.isNotEmpty) {
                  final firstRing = coordsList.first as List?;
                  if (firstRing != null && firstRing.isNotEmpty) {
                    final firstPointList = firstRing.first as List?;
                    if (firstPointList != null && firstPointList.length >= 2 && firstPointList[0] is num && firstPointList[1] is num) {
                      center = LatLng(firstPointList[1].toDouble(), firstPointList[0].toDouble());
                    }
                  }
                }
              }

              // *** DEBUGGING-HILFE (AUSKOMMENTIERT) ***
              /*
              if (kDebugMode) {
                if (center != null) {
                  print("    Calculated Center for '$name': $center");
                } else {
                  print("    WARNING: Could not calculate center for '$name'. Geometry: $geometry");
                }
              }
              */

              if (center != null) {
                features.add(SearchableFeature(
                  id: id.toString(), // Sicherstellen, dass ID ein String ist
                  name: name,
                  type: type,
                  center: center,
                ));
              }
            } /* else { // Optional: Log für übersprungene Features ohne Namen
              if (kDebugMode) {
                 print("    Feature ID '$id' (Typ: '$type') übersprungen: Name ist null oder leer.");
              }
            } */
          }
        }
      }
    }
    if (kDebugMode) {
      print("<<< _extractSearchableFeaturesFromGeoJson: ${features.length} suchbare Features extrahiert. >>>");
    }
    return features;
  }

  Future<void> _loadData() async {
    if (kDebugMode) {
      print("<<< _loadData: Starte das Laden der GeoJSON Daten... >>>");
    }
    setState(() { // Sofort _isDataReady auf false setzen, falls es mehrfach aufgerufen wird
      _isDataReady = false;
    });

    try {
      final String geoJsonString = await rootBundle.loadString('assets/data/export.geojson');
      if (kDebugMode) {
        print("<<< _loadData: GeoJSON String erfolgreich geladen (${geoJsonString.length} Zeichen). >>>");
      }

      final RoutingGraph graph = GeojsonParserService.parseGeoJson(geoJsonString);
      if (kDebugMode) {
        if (graph.nodes.isEmpty) {
          print(">>> _loadData WARNUNG: Routing Graph vom Parser erhalten, aber er hat 0 Knoten. Überprüfen Sie GeoJSON-Inhalt und Parser-Logik (insb. _routableHighwayTypes).");
        } else {
          print("<<< _loadData: Routing Graph vom Parser erhalten mit ${graph.nodes.length} Knoten. >>>");
        }
      }

      final List<SearchableFeature> features = _extractSearchableFeaturesFromGeoJson(geoJsonString);
      // Die Debug-Ausgabe für 'features.length' ist bereits in _extractSearchableFeaturesFromGeoJson

      if (mounted) {
        setState(() {
          _routingGraph = graph;
          _searchableFeatures = features;

          if (_routingGraph != null && _routingGraph!.nodes.isNotEmpty) {
            _isDataReady = true;
            if (kDebugMode) {
              print("<<< _loadData SUCCESS: Daten sind jetzt bereit (_isDataReady = true). Routing Graph mit ${_routingGraph!.nodes.length} Knoten. Suchbare Features: ${_searchableFeatures.length}. >>>");
            }
          } else {
            _isDataReady = false;
            if (kDebugMode) {
              print(">>> _loadData ERROR: Routing Graph nicht korrekt initialisiert oder leer. _isDataReady bleibt false. Routing Graph: ${_routingGraph?.nodes.length ?? 'null'} Knoten. Suchbare Features: ${_searchableFeatures.length}. >>>");
            }
            _showErrorDialog("Fehler bei der Initialisierung der Routing-Daten. Einige Funktionen könnten beeinträchtigt sein.");
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> _loadData FATAL ERROR: Fehler beim Laden/Parsen der GeoJSON Daten: $e");
        print(stacktrace);
      }
      if (mounted) {
        setState(() { // Sicherstellen, dass _isDataReady false ist bei Fehler
          _isDataReady = false;
        });
        _showErrorDialog('Schwerwiegender Fehler beim Laden der Kartendaten: $e. App möglicherweise nicht funktionsfähig.');
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
        });
      }
      return;
    }

    final results = _searchableFeatures.where((feature) {
      return feature.name.toLowerCase().contains(query) ||
             feature.type.toLowerCase().contains(query);
    }).toList();

    if (mounted) {
      setState(() {
        _searchResults = results;
        _showSearchResults = _searchFocusNode.hasFocus && results.isNotEmpty && _searchController.text.isNotEmpty;
      });
    }
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() {
        _showSearchResults = _searchFocusNode.hasFocus && _searchResults.isNotEmpty && _searchController.text.isNotEmpty;
      });
    }
  }

  void _selectFeatureAndSetPoint(SearchableFeature feature) {
    if (kDebugMode) {
      print("<<< _selectFeatureAndSetPoint: Feature ausgewählt: ${feature.name} an Position ${feature.center} >>>");
    }

    _searchController.clear();
    _searchResults = [];
    _showSearchResults = false;
    _searchFocusNode.unfocus();

    if (_selectedSearchFeatureForStart == null) {
      _selectedSearchFeatureForStart = feature;
      if (mounted) {
        setState(() {
          _startLatLng = feature.center;
          _startMarker = _createMarker(feature.center, Colors.green, Icons.flag, "Start: ${feature.name}");
          if (kDebugMode) {
            print("<<< _selectFeatureAndSetPoint: Startpunkt gesetzt auf: ${feature.name} >>>");
          }
        });
      }
      _showSnackbar("Startpunkt: ${feature.name}. Ziel auswählen oder auf Karte tippen.");
    } else if (_selectedSearchFeatureForEnd == null) {
      _selectedSearchFeatureForEnd = feature;
      if (mounted) {
        setState(() {
          _endLatLng = feature.center;
          _endMarker = _createMarker(feature.center, Colors.red, Icons.flag, "Ziel: ${feature.name}");
          if (kDebugMode) {
            print("<<< _selectFeatureAndSetPoint: Zielpunkt gesetzt auf: ${feature.name} >>>");
          }
        });
      }
      _calculateAndDisplayRoute();
    }
  }

  Future<void> _initializeGps() async {
    if (kDebugMode) {
      print("<<< _initializeGps: Starte GPS Initialisierung... >>>");
    }
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorDialog("GPS ist deaktiviert. Bitte aktiviere es, um deine Position zu sehen und die Navigation zu nutzen.");
      if (kDebugMode) print(">>> _initializeGps: GPS-Dienst nicht aktiviert.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (kDebugMode) print("<<< _initializeGps: GPS-Berechtigung ist 'denied', frage an...");
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog("GPS-Berechtigung verweigert. Dein Standort kann nicht angezeigt werden.");
        if (kDebugMode) print(">>> _initializeGps: GPS-Berechtigung nach Anfrage immer noch 'denied'.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog("GPS-Berechtigung dauerhaft verweigert. Bitte in den App-Einstellungen ändern, um deinen Standort zu sehen.");
      if (kDebugMode) print(">>> _initializeGps: GPS-Berechtigung 'deniedForever'.");
      return;
    }

    if (kDebugMode) print("<<< _initializeGps: GPS-Berechtigung erteilt. Starte Positions-Stream...");
    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10))
        .listen((Position position) {
      if (mounted) {
        final bool isFirstFix = _currentGpsPosition == null;
        setState(() {
          _currentGpsPosition = LatLng(position.latitude, position.longitude);
          _currentLocationMarker = _createMarker(
              _currentGpsPosition!, Colors.blue, Icons.my_location, "Meine Position");
        });
        if (kDebugMode) {
          print("<<< _initializeGps: Neue GPS Position: $_currentGpsPosition >>>");
        }
        if (isFirstFix && _currentGpsPosition != null) {
          _mapController.move(_currentGpsPosition!, _mapController.camera.zoom);
          if (kDebugMode) print("<<< _initializeGps: Karte auf erste GPS-Position zentriert. >>>");
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print(">>> _initializeGps: Fehler im GPS Positions-Stream: $error");
      }
      _showErrorDialog("Fehler beim Empfang der GPS-Position: $error");
    });
  }

  Marker _createMarker(LatLng position, Color color, IconData icon, String tooltip) {
    return Marker(
      width: markerWidth,
      height: markerHeight,
      point: position,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: 30.0),
      ),
      alignment: Alignment.center, // Standardmäßig mittig
    );
  }

  Future<void> _calculateAndDisplayRoute() async {
    if (kDebugMode) {
      print("<<< _calculateAndDisplayRoute: Aufgerufen. _isDataReady: $_isDataReady >>>");
    }
    if (!_isDataReady) { // NEU: Prüfung auf _isDataReady
      _showErrorDialog("Kartendaten sind noch nicht bereit. Bitte warten Sie einen Moment.");
      if (kDebugMode) print(">>> _calculateAndDisplayRoute: Abbruch, da _isDataReady = false.");
      return;
    }

    // Die Prüfung auf _routingGraph == null sollte durch _isDataReady abgedeckt sein,
    // aber eine zusätzliche defensive Prüfung schadet nicht.
    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      _showErrorDialog("Routing-Daten nicht verfügbar oder fehlerhaft. Navigation nicht möglich.");
      if (kDebugMode) print(">>> _calculateAndDisplayRoute: Routing Graph nicht initialisiert oder leer (trotz _isDataReady=true, das sollte nicht passieren!). Abbruch. Graph: $_routingGraph, Nodes: ${_routingGraph?.nodes.length}");
      return;
    }

    if (_startLatLng == null || _endLatLng == null) {
      _showErrorDialog("Start- oder Zielpunkt nicht gesetzt.");
      if (kDebugMode) print(">>> _calculateAndDisplayRoute: Start- oder Zielpunkt nicht gesetzt. Abbruch.");
      return;
    }

    if (mounted) setState(() => _isCalculatingRoute = true);
    if (kDebugMode) print("<<< _calculateAndDisplayRoute: Starte Routenberechnung von $_startLatLng nach $_endLatLng >>>");

    try {
      final GraphNode? startNode = _routingGraph!.findNearestNode(_startLatLng!);
      final GraphNode? endNode = _routingGraph!.findNearestNode(_endLatLng!);

      if (startNode == null || endNode == null) {
        _showErrorDialog("Start- oder Zielpunkt konnte nicht auf dem Wegenetz gefunden werden.");
        if (kDebugMode) print(">>> _calculateAndDisplayRoute: Start- (${startNode?.id}) oder Endknoten (${endNode?.id}) nicht im Graphen gefunden. Abbruch.");
        if (mounted) setState(() => _isCalculatingRoute = false);
        return;
      }

      if (startNode.id == endNode.id) {
        _showSnackbar("Start- und Zielpunkt sind identisch.");
        if (kDebugMode) print("<<< _calculateAndDisplayRoute: Start- und Endknoten sind identisch. Keine Route berechnet.");
        if (mounted) setState(() => _isCalculatingRoute = false);
        _clearRoute(showConfirmation: false, clearMarkers: false); // Nur Polylinie löschen
        return;
      }

      _routingGraph!.resetAllNodeCosts(); // Wichtig: Kosten vor jeder Suche zurücksetzen
      final List<LatLng>? routePoints = await RoutingService.findPath(_routingGraph!, startNode, endNode);

      if (mounted) {
        setState(() {
          if (routePoints != null && routePoints.isNotEmpty) {
            _routePolyline = Polyline(
              points: routePoints,
              strokeWidth: 5.0,
              color: Colors.deepPurple,
            );
            if (kDebugMode) print("<<< _calculateAndDisplayRoute: Route gefunden mit ${routePoints.length} Punkten. >>>");
            _showSnackbar("Route berechnet.", durationSeconds: 3);
          } else {
            _routePolyline = null;
            _showErrorDialog("Keine Route zwischen den gewählten Punkten gefunden.");
            if (kDebugMode) print("<<< _calculateAndDisplayRoute: Keine Route gefunden (RoutingService lieferte null oder leere Liste). >>>");
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> _calculateAndDisplayRoute: Fehler bei der Routenberechnung: $e");
        print(stacktrace);
      }
      if (mounted) _showErrorDialog("Fehler bei der Routenberechnung: $e");
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    if (kDebugMode) print("<<< _handleMapTap: Auf Karte getippt: $latLng >>>");
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      if(mounted) setState(() => _showSearchResults = false);
    }

    if (_isCalculatingRoute) return;

    if (_selectedSearchFeatureForStart == null) {
      if (mounted) {
        setState(() {
          _startLatLng = latLng;
          _selectedSearchFeatureForStart = SearchableFeature(id: "tap_start_${DateTime.now().millisecondsSinceEpoch}", name: "Start (Karte)", type: "map_tap", center: latLng);
          _startMarker = _createMarker(latLng, Colors.green, Icons.flag, "Start (Position: ${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})");
          if (kDebugMode) print("<<< _handleMapTap: Startpunkt via Karte gesetzt. >>>");
        });
      }
      _showSnackbar("Startpunkt gesetzt. Ziel auswählen oder auf Karte tippen.");
    } else if (_selectedSearchFeatureForEnd == null) {
      if (mounted) {
        setState(() {
          _endLatLng = latLng;
          _selectedSearchFeatureForEnd = SearchableFeature(id: "tap_end_${DateTime.now().millisecondsSinceEpoch}", name: "Ziel (Karte)", type: "map_tap", center: latLng);
          _endMarker = _createMarker(latLng, Colors.red, Icons.flag, "Ziel (Position: ${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})");
          if (kDebugMode) print("<<< _handleMapTap: Zielpunkt via Karte gesetzt. Routenberechnung wird gestartet. >>>");
        });
      }
      _calculateAndDisplayRoute();
    } else {
      _showConfirmationDialog(
        "Neue Route?",
        "Möchtest du einen neuen Startpunkt setzen? Die aktuelle Route und die Punkte werden dabei gelöscht.",
        () {
          if (mounted) {
            _clearAll(); // Eigene Funktion zum Löschen von allem
            setState(() {
              _startLatLng = latLng;
              _selectedSearchFeatureForStart = SearchableFeature(id: "tap_start_${DateTime.now().millisecondsSinceEpoch}", name: "Start (Karte)", type: "map_tap", center: latLng);
              _startMarker = _createMarker(latLng, Colors.green, Icons.flag, "Start (Position: ${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})");
              if (kDebugMode) print("<<< _handleMapTap: Neuer Startpunkt nach Bestätigung gesetzt. >>>");
            });
            _showSnackbar("Neuer Startpunkt gesetzt. Ziel auswählen oder auf Karte tippen.");
          }
        }
      );
    }
  }

  void _clearRoute({bool showConfirmation = true, bool clearMarkers = true}) { // Option zum Beibehalten der Marker
    final VoidCallback clearAction = () {
      if (mounted) {
        setState(() {
          _routePolyline = null;
          if (clearMarkers) {
            _startMarker = null;
            _endMarker = null;
            _startLatLng = null;
            _endLatLng = null;
            _selectedSearchFeatureForStart = null;
            _selectedSearchFeatureForEnd = null;
            if (kDebugMode) print("<<< _clearRoute: Route UND Marker gelöscht. >>>");
          } else {
            if (kDebugMode) print("<<< _clearRoute: Nur Route-Polyline gelöscht. Marker beibehalten. >>>");
          }
        });
      }
      if (clearMarkers) _showSnackbar("Route und Punkte gelöscht.", durationSeconds: 3);
      else _showSnackbar("Route gelöscht.", durationSeconds: 3);
    };

    if (showConfirmation && (_routePolyline != null || (clearMarkers && (_startMarker != null || _endMarker != null)) ) ) {
      _showConfirmationDialog(
        clearMarkers ? "Route & Punkte löschen?" : "Route löschen?",
        clearMarkers ? "Möchtest du die aktuelle Route und die gesetzten Punkte wirklich löschen?" : "Möchtest du die aktuelle Route wirklich löschen?",
        clearAction
      );
    } else {
      clearAction();
    }
  }
  // NEUE Methode, um alles zurückzusetzen
  void _clearAll() {
    if (mounted) {
      setState(() {
        _routePolyline = null;
        _startMarker = null;
        _endMarker = null;
        _startLatLng = null;
        _endLatLng = null;
        _selectedSearchFeatureForStart = null;
        _selectedSearchFeatureForEnd = null;
        _searchController.clear(); // Suchfeld auch leeren
        _searchResults = [];
        _showSearchResults = false;
        if (kDebugMode) print("<<< _clearAll: Alle Routen-, Punkt- und Suchdaten gelöscht. >>>");
      });
    }
  }


  void _centerOnGps() {
    if (_currentGpsPosition != null) {
      _mapController.move(_currentGpsPosition!, 17.0);
      if (kDebugMode) print("<<< _centerOnGps: Zentriere auf GPS-Position: $_currentGpsPosition >>>");
    } else {
      if (kDebugMode) print(">>> _centerOnGps: Keine GPS-Position verfügbar zum Zentrieren. >>>");
      _showSnackbar("Keine GPS-Position verfügbar.");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted || !ModalRoute.of(context)!.isCurrent) {
        // Verhindern, dass Dialoge angezeigt werden, wenn der Screen nicht mehr aktiv ist
        // oder bereits ein Dialog offen ist (vereinfachte Prüfung).
        if (kDebugMode) print(">>> _showErrorDialog: Dialog nicht angezeigt (Screen nicht mounted oder nicht aktuell). Message: $message");
        return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Fehler"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
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
        if (kDebugMode) print(">>> _showSnackbar: Snackbar nicht angezeigt (Screen nicht mounted). Message: $message");
        return;
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
      ),
    );
  }

  void _showConfirmationDialog(String title, String content, VoidCallback onConfirm) {
    if (!mounted || !ModalRoute.of(context)!.isCurrent) {
        if (kDebugMode) print(">>> _showConfirmationDialog: Dialog nicht angezeigt. Message: $title");
        return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text("Abbrechen"),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              child: const Text("Bestätigen"),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
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
    if (kDebugMode) {
      // print("<<< BUILD MapScreen: _isDataReady: $_isDataReady, Start: ${_startLatLng}, Ende: ${_endLatLng} >>>");
    }

    List<Marker> activeMarkers = [];
    if (_currentLocationMarker != null) activeMarkers.add(_currentLocationMarker!);
    if (_startMarker != null) activeMarkers.add(_startMarker!);
    if (_endMarker != null) activeMarkers.add(_endMarker!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campground Nav"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentGpsPosition ?? defaultInitialCenter,
              initialZoom: 16.0,
              minZoom: 13.0, // Etwas weiter rauszoomen erlaubt
              maxZoom: 19.0,
              onTap: _handleMapTap,
              // NEU: Bei Verschieben der Karte durch Nutzer, Suchergebnisse ausblenden
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture && _searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                   if(mounted) setState(() => _showSearchResults = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'de.firma.campgroundnavi.app',
                tileProvider: CancellableNetworkTileProvider(),
                 // NEU: Fehlerbehandlung für Kacheln direkt im Layer
                errorImage: const Center(child: Icon(Icons.error_outline, color: Colors.grey, size: 48)), // Zeigt ein Fehlericon anstatt grauer Kachel
                // Optional: Ladeindikator, aber kann bei vielen Kacheln störend sein
                // tileBuilder: (context, tileWidget, tile) {
                //   if (tile.loading) {
                //     return const Center(child: CircularProgressIndicator(strokeWidth: 2.0));
                //   }
                //   return tileWidget;
                // },
              ),
              if (_routePolyline != null) PolylineLayer(polylines: [_routePolyline!]),
              MarkerLayer(markers: activeMarkers),
              // Hier könnten weitere Layer wie Gebäude, POIs etc. aus GeoJSON hinzukommen (PolygonLayer, etc.)
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: _selectedSearchFeatureForStart == null
                        ? "Startpunkt suchen..."
                        : "Zielpunkt suchen...",
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              // _searchFocusNode.unfocus(); // Unfocus passiert schon durch _onSearchChanged bei leerem Query
                              if(mounted) {
                                setState(() {
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
          if (_showSearchResults)
            Positioned(
              top: 70, // Höhe der Suchleiste (ca. 50-60) + kleiner Abstand
              left: 10,
              right: 10,
              child: Card(
                elevation: 4.0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4, // Begrenzt Höhe der Ergebnisliste
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final feature = _searchResults[index];
                      return ListTile(
                        title: Text(feature.name),
                        subtitle: Text("Typ: ${feature.type}"),
                        onTap: () => _selectFeatureAndSetPoint(feature),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_isCalculatingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // FAB zum Löschen wurde geändert zu _clearAll
          if ((_routePolyline != null && _routePolyline!.points.isNotEmpty) || _startMarker != null || _endMarker != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: "clearAllBtn", // Geändert
                onPressed: () => _clearAll(), // Verwendet jetzt _clearAll
                backgroundColor: Colors.redAccent,
                tooltip: 'Alles zurücksetzen (Route & Punkte)', // Tooltip angepasst
                child: const Icon(Icons.delete_sweep, color: Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0), // Ggf. anpassen, falls der andere FAB weg ist
            child: FloatingActionButton.small(
              heroTag: "centerGpsBtn",
              onPressed: _centerOnGps,
              backgroundColor: Colors.blueAccent,
              tooltip: 'Auf GPS zentrieren',
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
// [Ende lib/main.dart Überarbeitet]