// lib/main.dart (Version mit Korrekturen aus error log.txt und Debug-Prints)

import 'dart:async';
// import 'dart:convert'; // Nicht mehr benötigt nach Korrektur -> entfernt
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
// Import für Alignment hinzugefügt (für Marker-Ausrichtung)
import 'package:flutter_map/src/misc/point_extensions.dart'; // Für Anchor

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// Eigene Imports (Stelle sicher, dass diese Pfade korrekt sind)
// Annahme: Diese Klassen existieren und haben die erwarteten Eigenschaften/Methoden
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart'; // Annahme: hat 'LatLng position'
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/routing_service.dart'; // Annahme: findPath ist async

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
  // Map Controller
  final MapController _mapController = MapController();

  // Daten-Variablen
  List<SearchableFeature> _searchableFeatures = []; // Wird aktuell nicht verwendet (siehe warning)
  List<Polygon> _buildings = [];
  List<Polyline> _paths = [];
  List<Marker> _poiMarkers = [];
  RoutingGraph? _routingGraph;

  // GPS-Variablen
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 1,
  );
  final LatLng _initialCenter = const LatLng(51.0004, 5.8660);

  // Routing-Variablen
  Polyline? _routePoints;
  Marker? _startMarker;
  Marker? _endMarker;
  bool _isCalculatingRoute = false;
  List<GraphNode>? _calculatedRoute; // Wird aktuell nicht verwendet (siehe warning)

  // Mock Location Variablen
  LatLng? _mockStartLatLng;

  //---------------------------------------------------------------------------
  // INITIALISIERUNG & DATEN LADEN
  //---------------------------------------------------------------------------
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

      // Korrektur: Annahme, dass parseGeoJson NICHT async ist (gemäß lint warning)
      // -> await entfernt. Falls es doch async ist, await wieder hinzufügen.
      final parsedData = GeojsonParserService.parseGeoJson(geoJsonString);

      if (mounted) {
        setState(() {
          // Korrektur: Direkte Zuweisung zu den State-Variablen
          _buildings = parsedData['buildings'] as List<Polygon>? ?? []; // Mit Typ-Cast und Fallback
          _paths = parsedData['paths'] as List<Polyline>? ?? [];
          _poiMarkers = parsedData['poiMarkers'] as List<Marker>? ?? [];
          _routingGraph = parsedData['routingGraph'] as RoutingGraph?; // Typ-Cast
          _searchableFeatures = parsedData['searchableFeatures'] as List<SearchableFeature>? ?? [];
        });
         if (kDebugMode) {
            print("<<< GeoJSON Daten geladen und verarbeitet. >>>");
            // Korrektur: Zugriff auf nodes.length statt nicht vorhandenem edgeCount
            // (Annahme: RoutingGraph hat eine 'nodes'-Liste)
            int nodeCount = _routingGraph?.nodes.length ?? 0;
            // Kantenanzahl ist komplexer, evtl. hat RoutingGraph eine Methode dafür?
            // Wir lassen die Kantenzahl hier erstmal weg für die Korrektur.
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

  //---------------------------------------------------------------------------
  // GPS FUNKTIONEN (unverändert)
  //---------------------------------------------------------------------------
  Future<void> _initLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog('Standortberechtigung verweigert.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
       _showPermissionDeniedDialog(
          'Standortberechtigung dauerhaft verweigert. Bitte in den App-Einstellungen ändern.');
      return;
    }

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
           // if (kDebugMode) print("<<< GPS Update: ${position.latitude}, ${position.longitude} >>>"); // Weniger gesprächig
        });
      }
    }, onError: (error) {
       if (kDebugMode) print(">>> Fehler beim GPS Stream: $error");
    });
  }

  void _centerOnGps() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _mapController.camera.zoom,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aktuelle Position noch nicht verfügbar."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showLocationServiceDialog() async {
    if (!mounted) return;
    await showDialog( /* ... unverändert ... */ );
  }

  Future<void> _showPermissionDeniedDialog(String message) async {
     if (!mounted) return;
    await showDialog( /* ... unverändert ... */ );
  }


  //---------------------------------------------------------------------------
  // ROUTING FUNKTIONEN (mit Korrekturen)
  //---------------------------------------------------------------------------
  Future<void> _calculateAndDisplayRoute(LatLng start, LatLng end) async {
    if (_routingGraph == null) {
       if (kDebugMode) print(">>> Routing Graph nicht initialisiert.");
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
           content: Text("Routing-Daten nicht bereit."),
           backgroundColor: Colors.red,
         ));
      return;
    }

    setState(() => _isCalculatingRoute = true);

    List<GraphNode>? path;

    try {
      // Korrektur: Übergabe der LatLng Objekte an findNearestNode
      final startNode = _routingGraph!.findNearestNode(start);
      final endNode = _routingGraph!.findNearestNode(end);

      // Korrektur: Null check für gefundene Knoten
      if (startNode == null || endNode == null) {
         if (kDebugMode) print(">>> Start- oder Endknoten nicht gefunden.");
         throw Exception("Start- oder Endpunkt außerhalb des Routing-Bereichs.");
      }

      if (kDebugMode) {
         // Annahme: GraphNode hat eine 'id'-Eigenschaft und 'position' vom Typ LatLng
         print("<<< Suche Route von Knoten ${startNode.id} (${startNode.position.latitude}, ${startNode.position.longitude})");
         print("<<< zu Knoten ${endNode.id} (${endNode.position.latitude}, ${endNode.position.longitude})");
      }

      // Korrektur: Übergabe der non-null Knoten
      path = await RoutingService.findPath(_routingGraph!, startNode, endNode);

      if (mounted) {
        // Korrektur: _calculatedRoute direkt den Pfad zuweisen
        _calculatedRoute = path; // Kann immer noch null sein, wenn kein Pfad gefunden

        if (path == null || path.isEmpty) {
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
          if (kDebugMode) print("<<< Route berechnet (${path.length} Punkte).");

          // Route visualisieren
          // Korrektur: Zugriff auf node.position.latitude / longitude (Annahme!)
          _routePoints = Polyline(
            points: path.map((node) => LatLng(node.position.latitude, node.position.longitude)).toList(),
            color: Colors.blue,
            strokeWidth: 5.0,
          );

          // Start- und Endmarker erstellen
          // Korrektur: Zugriff auf node.position
          // Korrektur: Verwendung von alignment statt anchorPos
          _startMarker = Marker(
            width: 80.0, height: 80.0,
            point: LatLng(path.first.position.latitude, path.first.position.longitude),
            child: const Icon(Icons.location_on, color: Colors.green, size: 30),
            // anchorPos: AnchorPos.align(AnchorAlign.top), // Alt & Falsch
            alignment: Alignment.topCenter, // Korrektur/Alternative
          );
          _endMarker = Marker(
            width: 80.0, height: 80.0,
            point: LatLng(path.last.position.latitude, path.last.position.longitude),
            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
            // anchorPos: AnchorPos.align(AnchorAlign.top), // Alt & Falsch
            alignment: Alignment.topCenter, // Korrektur/Alternative
          );

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Route berechnet."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));

           setState(() {}); // Um _routePoints und Marker anzuzeigen
        }
      }

    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> Fehler bei Routenberechnung: $e");
        print(stacktrace);
      }
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text(
               "Routenberechnung fehlgeschlagen: ${e.toString().replaceFirst("Exception: ", "")}"),
           backgroundColor: Colors.red,
         ));
         setState(() {
            _calculatedRoute = null; // Zurücksetzen
            _routePoints = null;
            _startMarker = null;
            _endMarker = null;
         });
      }
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
         // if (kDebugMode) print("<<< Routenberechnung abgeschlossen (finally)."); // Weniger gesprächig
      }
    }
  }


  // Löscht die aktuell angezeigte Route und Marker (unverändert)
  void _clearRoute() {
    if (kDebugMode) print("<<< _clearRoute aufgerufen.");
    setState(() {
      _routePoints = null;
      _startMarker = null;
      _endMarker = null;
      _mockStartLatLng = null;
      _calculatedRoute = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Route gelöscht..."),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  //---------------------------------------------------------------------------
  // BUILD METHODE (mit Korrekturen und Debug-Prints)
  //---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // --- DEBUG PRINT 1 ---
    if (kDebugMode) {
      print("<<< BUILD >>> _mockStartLatLng is: $_mockStartLatLng");
    }

    // --- Vorbereitung des grünen Mock-Start-Markers ---
    Marker? mockStartMarker;
    if (_mockStartLatLng != null) {
       // --- DEBUG PRINT 2 ---
       if (kDebugMode) print("<<< BUILD >>> Preparing green mock start marker!");
       mockStartMarker = Marker(
          width: 80.0,
          height: 80.0,
          point: _mockStartLatLng!,
          // Korrektur: Verwende alignment statt anchorPos
          alignment: Alignment.topCenter,
          child: const Icon(Icons.pin_drop, color: Colors.green, size: 30.0),
        );
    } else {
       // --- DEBUG PRINT 3 ---
       if (kDebugMode) print("<<< BUILD >>> NOT preparing green mock start marker (_mockStartLatLng is null).");
    }
    // --- Ende Vorbereitung Mock-Marker ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campground Nav'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Daten neu laden',
          ),
          // TODO: Suchfunktion (optional) [cite: 45]
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 17.0,
              minZoom: 16.0,
              maxZoom: 19.0,
              onTap: (tapPosition, point) { // onTap Logik bleibt vorerst gleich
                if (kDebugMode) print("<<<MapScreenState>>> Tapped on map: $point");
                if (_isCalculatingRoute) return;
                if (_mockStartLatLng == null) {
                  setState(() {
                    _mockStartLatLng = point;
                    _routePoints = null; _startMarker = null; _endMarker = null; _calculatedRoute = null;
                  });
                   if (kDebugMode) print("<<<MapScreenState>>> Setting mock start point.");
                  ScaffoldMessenger.of(context).showSnackBar( /* ... SnackBar ... */ );
                } else {
                   if (kDebugMode) print("<<<MapScreenState>>> Setting mock end point and calculating route.");
                  _calculateAndDisplayRoute(_mockStartLatLng!, point);
                  setState(() { _mockStartLatLng = null; });
                }
              },
              onPositionChanged: (position, hasGesture) { /* ... optional ... */ },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.camping_osm_navi',
                errorTileCallback: (tile, error, stacktrace) {
                   // Korrektur: Zugriff auf tile.coordinates statt tile.coords (Annahme basierend auf API)
                   if (kDebugMode) print("Tile Error: ${tile.coordinates}, Error: $error");
                },
              ),
              PolygonLayer(polygons: _buildings),
              PolylineLayer(polylines: _paths),
              if (_routePoints != null) PolylineLayer(polylines: [_routePoints!]),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      width: 80.0, height: 80.0,
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      // Korrektur: Verwende alignment
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 30.0),
                    ),
                  ..._poiMarkers, // POI Marker sollten 'alignment' statt 'anchorPos' verwenden
                                  // (Annahme: POI Marker werden extern erstellt und müssen ggf. angepasst werden)
                  if (mockStartMarker != null) mockStartMarker, // Grüner Pin (oben vorbereitet)
                  if (_startMarker != null) _startMarker!, // Bereits korrigiert in _calculateAndDisplayRoute
                  if (_endMarker != null) _endMarker!,   // Bereits korrigiert in _calculateAndDisplayRoute
                ],
              ),
            ],
          ), // Ende FlutterMap

          if (_isCalculatingRoute) // Ladeindikator (unverändert)
            Positioned.fill( /* ... */ ),
        ],
      ), // Ende Stack

      // Korrektur: floatingActionButton statt floatingActionButtons
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_routePoints != null && _routePoints!.points.isNotEmpty)
            Padding(
              // Korrektur: Child property nach hinten (lint warning)
              padding: const EdgeInsets.only(top: 10.0, left: 10.0), // Korrigiertes Padding
              child: FloatingActionButton.small(
                heroTag: "clearRouteBtn",
                onPressed: _clearRoute,
                backgroundColor: Colors.redAccent,
                tooltip: 'Route löschen',
                child: const Icon(Icons.clear, color: Colors.white), // Child am Ende
              ),
            ),
           Padding(
             // Korrektur: Child property nach hinten (lint warning)
             padding: const EdgeInsets.only(top: 10.0, left: 10.0),
             child: FloatingActionButton.small(
                heroTag: "centerGpsBtn",
                onPressed: _centerOnGps,
                backgroundColor: Colors.blueAccent,
                tooltip: 'Auf GPS zentrieren',
                child: const Icon(Icons.my_location, color: Colors.white), // Child am Ende
              ),
           ),
        ],
      ), // Ende Column für FAB
    ); // Ende Scaffold
  }
  // --- Ende BUILD METHODE ---

} // Ende _MapScreenState Klasse