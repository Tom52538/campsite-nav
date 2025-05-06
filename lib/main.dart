// lib/main.dart (Version mit Korrekturen basierend auf ALLEN Logs und Model-Dateien)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// Eigene Imports
import 'package:camping_osm_navi/models/searchable_feature.dart'; // Wird noch als ungenutzt markiert, ok für jetzt
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
      title: 'Camping Navi App',
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
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // Daten-Variablen
  // WICHTIG: Diese werden aktuell nicht direkt vom GeojsonParserService (wie er jetzt ist) befüllt.
  // Das muss ggf. in einer zukünftigen Version des Parsers oder über separate Ladevorgänge geschehen.
  // Fürs Erste lassen wir sie als leere Listen, damit die App baut.
  List<SearchableFeature> _searchableFeatures = [];
  List<Polygon> _buildings = [];
  List<Polyline> _paths = [];
  List<Marker> _poiMarkers = [];
  RoutingGraph? _routingGraph; // Wird jetzt korrekt initialisiert

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 1,
  );
  final LatLng _initialCenter = const LatLng(51.0004, 5.8660);

  Polyline? _routePoints;
  Marker? _startMarker;
  Marker? _endMarker;
  bool _isCalculatingRoute = false;
  // KORREKTUR: Typ angepasst an Rückgabetyp von RoutingService.findPath
  List<LatLng>? _calculatedRoutePathLatLngs; // Vormals _calculatedRoute (List<GraphNode>)

  LatLng? _mockStartLatLng;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initLocationService();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final String geoJsonString =
          await rootBundle.loadString('assets/data/export.geojson');

      // KORREKTUR: GeojsonParserService.parseGeoJson gibt direkt den RoutingGraph zurück.
      // Die anderen Elemente (Buildings, Paths, POIs) müssten separat geparst werden,
      // falls der Service das nicht intern macht und im Graphen ablegt oder anders bereitstellt.
      // Fürs Erste initialisieren wir nur den Graphen.
      final RoutingGraph graph = GeojsonParserService.parseGeoJson(geoJsonString);

      if (mounted) {
        setState(() {
          _routingGraph = graph;
          // Setze die anderen Listen vorerst leer, da der Parser sie nicht liefert.
          _buildings = [];
          _paths = [];
          _poiMarkers = [];
          _searchableFeatures = [];
        });
        if (kDebugMode) {
          print("<<< GeoJSON Daten verarbeitet. Routing Graph initialisiert. >>>");
          int nodeCount = _routingGraph?.nodes.length ?? 0;
          print("<<< Routing Graph: $nodeCount Knoten >>>");
        }
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> Fehler beim Laden/Parsen der GeoJSON Daten: $e");
        print(stacktrace);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Fehler beim Laden der Kartendaten: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showLocationServiceDialog(); // KORREKTUR: mounted Check
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showPermissionDeniedDialog('Standortberechtigung verweigert.'); // KORREKTUR: mounted Check
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showPermissionDeniedDialog('Standortberechtigung dauerhaft verweigert. Bitte in den App-Einstellungen ändern.'); // KORREKTUR: mounted Check
      return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    }, onError: (error) {
      if (kDebugMode) print(">>> Fehler beim GPS Stream: $error");
    });
  }

  void _centerOnGps() { /* ... unverändert ... */ }

  // KORREKTUR: AlertDialog Aufrufe korrigiert
  Future<void> _showLocationServiceDialog() async {
    if (!mounted) return;
    await showDialog<void>( // Typspezifizierung für showDialog
      context: context,
      builder: (BuildContext dialogContext) { // Korrekten Context verwenden
        return AlertDialog(
          title: const Text('Standortdienste deaktiviert'),
          content: const Text('Bitte aktiviere die Standortdienste, um deinen Standort auf der Karte zu sehen.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(dialogContext).pop(), // dialogContext verwenden
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDeniedDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>( // Typspezifizierung für showDialog
      context: context,
      builder: (BuildContext dialogContext) { // Korrekten Context verwenden
        return AlertDialog(
          title: const Text('Berechtigung erforderlich'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(dialogContext).pop(), // dialogContext verwenden
            ),
          ],
        );
      },
    );
  }

  Future<void> _calculateAndDisplayRoute(LatLng start, LatLng end) async {
    if (_routingGraph == null) {
      if (kDebugMode) print(">>> Routing Graph nicht initialisiert.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Routing-Daten nicht bereit."),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    // WICHTIG: Kosten der Knoten vor jeder neuen Suche zurücksetzen!
    _routingGraph!.resetAllNodeCosts();

    setState(() => _isCalculatingRoute = true);

    List<LatLng>? pathLatLngs; // Variable für das Ergebnis von findPath

    try {
      final startNode = _routingGraph!.findNearestNode(start);
      final endNode = _routingGraph!.findNearestNode(end);

      if (startNode == null || endNode == null) {
        throw Exception("Start- oder Endpunkt außerhalb des Routing-Bereichs.");
      }

      if (kDebugMode) {
        print("<<< Suche Route von Knoten ${startNode.id} zu Knoten ${endNode.id}");
      }

      pathLatLngs = await RoutingService.findPath(_routingGraph!, startNode, endNode);

      if (mounted) {
        _calculatedRoutePathLatLngs = pathLatLngs; // Zuweisung an State-Variable

        if (pathLatLngs == null || pathLatLngs.isEmpty) {
          if (kDebugMode) print("<<< Kein Pfad gefunden.");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Keine Route gefunden."),
            backgroundColor: Colors.orange,
          ));
          setState(() {
            _routePoints = null;
            _startMarker = null;
            _endMarker = null;
          });
        } else {
          if (kDebugMode) print("<<< Route berechnet (${pathLatLngs.length} Punkte).");

          _routePoints = Polyline(
            points: pathLatLngs, // Direkt die LatLng-Liste verwenden
            color: Colors.blue,
            strokeWidth: 5.0,
          );

          _startMarker = Marker(
            width: 80.0, height: 80.0,
            point: pathLatLngs.first,
            alignment: Alignment.topCenter,
            child: const Icon(Icons.location_on, color: Colors.green, size: 30),
          );
          _endMarker = Marker(
            width: 80.0, height: 80.0,
            point: pathLatLngs.last,
            alignment: Alignment.topCenter,
            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
          );

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Route berechnet."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
          setState(() {}); // Um UI zu aktualisieren
        }
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> Fehler bei Routenberechnung: $e");
        print(stacktrace);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Routenberechnung fehlgeschlagen: ${e.toString().replaceFirst("Exception: ", "")}"),
          backgroundColor: Colors.red,
        ));
        setState(() {
          _calculatedRoutePathLatLngs = null;
          _routePoints = null;
          _startMarker = null;
          _endMarker = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  void _clearRoute() { /* ... unverändert, aber _calculatedRoutePathLatLngs berücksichtigen ... */
    if (kDebugMode) print("<<< _clearRoute aufgerufen.");
    setState(() {
      _routePoints = null;
      _startMarker = null;
      _endMarker = null;
      _mockStartLatLng = null;
      _calculatedRoutePathLatLngs = null; // KORREKTUR: Angepasste Variable
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar( // KORREKTUR: SnackBar direkt als Argument
        content: Text("Route gelöscht..."),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print("<<< BUILD >>> _mockStartLatLng is: $_mockStartLatLng");

    Marker? mockStartMarker;
    if (_mockStartLatLng != null) {
      if (kDebugMode) print("<<< BUILD >>> Preparing green mock start marker!");
      mockStartMarker = Marker(
        width: 80.0, height: 80.0,
        point: _mockStartLatLng!,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.pin_drop, color: Colors.green, size: 30.0),
      );
    } else {
      if (kDebugMode) print("<<< BUILD >>> NOT preparing green mock start marker (_mockStartLatLng is null).");
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campground Nav'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Daten neu laden'),
          // TODO: Suchfunktion
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 17.0, minZoom: 16.0, maxZoom: 19.0,
              onTap: (tapPosition, point) {
                if (kDebugMode) print("<<<MapScreenState>>> Tapped on map: $point");
                if (_isCalculatingRoute) return;
                if (_mockStartLatLng == null) {
                  setState(() {
                    _mockStartLatLng = point;
                    _routePoints = null; _startMarker = null; _endMarker = null; _calculatedRoutePathLatLngs = null;
                  });
                  if (kDebugMode) print("<<<MapScreenState>>> Setting mock start point.");
                  ScaffoldMessenger.of(context).showSnackBar( // KORREKTUR: SnackBar direkt als Argument
                    const SnackBar(
                      content: Text("Startpunkt gesetzt. Erneut tippen für Ziel."),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  if (kDebugMode) print("<<<MapScreenState>>> Setting mock end point and calculating route.");
                  _calculateAndDisplayRoute(_mockStartLatLng!, point);
                  setState(() => _mockStartLatLng = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.camping_osm_navi',
                errorTileCallback: (tile, error, stacktrace) {
                  if (kDebugMode) print("Tile Error: ${tile.coordinates}, Error: $error");
                },
              ),
              PolygonLayer(polygons: _buildings), // Werden aktuell leer sein
              PolylineLayer(polylines: _paths),   // Werden aktuell leer sein
              if (_routePoints != null) PolylineLayer(polylines: [_routePoints!]),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      width: 80.0, height: 80.0,
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 30.0),
                    ),
                  ..._poiMarkers, // Werden aktuell leer sein
                  if (mockStartMarker != null) mockStartMarker,
                  if (_startMarker != null) _startMarker!,
                  if (_endMarker != null) _endMarker!,
                ],
              ),
            ],
          ),
          // KORREKTUR: Positioned.fill mit child
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
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_routePoints != null && _routePoints!.points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10.0, left: 10.0),
              child: FloatingActionButton.small(
                heroTag: "clearRouteBtn",
                onPressed: _clearRoute,
                backgroundColor: Colors.redAccent,
                tooltip: 'Route löschen',
                child: const Icon(Icons.clear, color: Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10.0, left: 10.0),
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
    );
  }
}