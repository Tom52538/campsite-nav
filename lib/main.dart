// lib/main.dart (Version mit Debug-Prints in der build-Methode)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// Eigene Imports (Stelle sicher, dass diese Pfade korrekt sind)
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
  List<SearchableFeature> _searchableFeatures = []; // Für Suchfunktion (optional)
  List<Polygon> _buildings = [];                   // Gebäude-Polygone
  List<Polyline> _paths = [];                      // Wege-Linien
  List<Marker> _poiMarkers = [];                   // POI-Marker
  RoutingGraph? _routingGraph;                     // Graph für Routing

  // GPS-Variablen
  Position? _currentPosition;                      // Aktuelle GPS Position
  StreamSubscription<Position>? _positionStreamSubscription; // Stream für Updates
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,              // Hohe Genauigkeit
    distanceFilter: 1,                           // Update bei 1 Meter Bewegung
  );
  final LatLng _initialCenter = const LatLng(51.0004, 5.8660); // Mittelpunkt Collé

  // Routing-Variablen
  Polyline? _routePoints;                          // Die zu zeichnende Route
  Marker? _startMarker;                            // Startmarker der Route
  Marker? _endMarker;                              // Endmarker der Route
  bool _isCalculatingRoute = false;                // Zeigt Ladeindikator an
  List<GraphNode>? _calculatedRoute;               // Die berechneten Knoten (für Debug/Info)

  // Mock Location Variablen (für Klick-Routing)
  LatLng? _mockStartLatLng;                        // Startpunkt durch Klick

  //---------------------------------------------------------------------------
  // INITIALISIERUNG & DATEN LADEN
  //---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadData(); // Lade GeoJSON Daten beim Start
    _initLocationService(); // Starte GPS Service
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel(); // GPS Stream beenden
    _mapController.dispose(); // Map Controller freigeben
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Lade GeoJSON String aus Assets
      final String geoJsonString =
          await rootBundle.loadString('assets/data/export.geojson');
      // Parse GeoJSON für Anzeige und Routing Graph
      final parsedData = await GeojsonParserService.parseGeoJson(geoJsonString);

      if (mounted) { // Prüfe ob Widget noch im Baum ist
        setState(() {
          _buildings = parsedData['buildings']!;
          _paths = parsedData['paths']!;
          _poiMarkers = parsedData['poiMarkers']!;
          _routingGraph = parsedData['routingGraph'];
          _searchableFeatures = parsedData['searchableFeatures']!; // Für Suche
           if (kDebugMode) {
              print("<<< GeoJSON Daten geladen und verarbeitet. >>>");
              print("<<< Routing Graph: ${_routingGraph?.nodes.length} Knoten, ${_routingGraph?.edgeCount} Kanten >>>");
           }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> Fehler beim Laden/Parsen der GeoJSON Daten: $e");
        print(stacktrace);
      }
      // Optional: Fehlermeldung anzeigen
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
  // GPS FUNKTIONEN
  //---------------------------------------------------------------------------
  Future<void> _initLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Prüfe ob Standortdienste aktiviert sind
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return; // Frühzeitiger Ausstieg, wenn Dienste aus sind
    }

    // Prüfe Berechtigungen
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog('Standortberechtigung verweigert.');
        return; // Ausstieg
      }
    }

    if (permission == LocationPermission.deniedForever) {
       _showPermissionDeniedDialog(
          'Standortberechtigung dauerhaft verweigert. Bitte in den App-Einstellungen ändern.');
      return; // Ausstieg
    }

    // Berechtigungen sind erteilt, starte Stream
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
           if (kDebugMode) print("<<< GPS Update: ${position.latitude}, ${position.longitude} >>>");
        });
      }
    }, onError: (error) {
       if (kDebugMode) print(">>> Fehler beim GPS Stream: $error");
       // Optional: Fehlermeldung anzeigen
    });
  }

  // Zentriert die Karte auf die aktuelle GPS Position
  void _centerOnGps() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _mapController.camera.zoom, // Behalte aktuellen Zoom bei
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

   // Zeigt Dialog, wenn Standortdienste deaktiviert sind
  Future<void> _showLocationServiceDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Standortdienste deaktiviert'),
        content: const Text(
            'Bitte aktiviere die Standortdienste, um deinen Standort auf der Karte zu sehen.'),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // Zeigt Dialog, wenn Berechtigung verweigert wurde
  Future<void> _showPermissionDeniedDialog(String message) async {
     if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Berechtigung erforderlich'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }


  //---------------------------------------------------------------------------
  // ROUTING FUNKTIONEN
  //---------------------------------------------------------------------------

  // Berechnet und zeigt die Route zwischen zwei Punkten an
  Future<void> _calculateAndDisplayRoute(LatLng start, LatLng end) async {
    if (_routingGraph == null) {
       if (kDebugMode) print(">>> Routing Graph nicht initialisiert.");
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
           content: Text("Routing-Daten nicht bereit."),
           backgroundColor: Colors.red,
         ));
      return;
    }

    setState(() => _isCalculatingRoute = true); // Ladeindikator starten

    List<GraphNode>? path; // Ergebnis der Routenberechnung

    try {
      // Finde die nächstgelegenen Knoten im Graph für Start und End LatLng
      final startNode = _routingGraph!.findNearestNode(start.latitude, start.longitude);
      final endNode = _routingGraph!.findNearestNode(end.latitude, end.longitude);

      if (kDebugMode) {
         print("<<< Suche Route von Knoten ${startNode.id} (${startNode.lat}, ${startNode.lon})");
         print("<<< zu Knoten ${endNode.id} (${endNode.lat}, ${endNode.lon})");
      }

      // Berechne den Pfad mit dem RoutingService (Dijkstra)
      // Hinweis: findPath ist jetzt async (war es vorher vielleicht nicht?)
      path = await RoutingService.findPath(_routingGraph!, startNode, endNode);

      if (mounted) { // Prüfe, ob Widget noch existiert

         // Setze den Zustand mit dem berechneten Pfad (oder null)
         setState(() => _calculatedRoute = path);

        if (path == null || path.isEmpty) {
          // --- Keine Route gefunden ---
          if (kDebugMode) print("<<< Kein Pfad gefunden.");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Keine Route gefunden."),
            backgroundColor: Colors.orange,
          ));
          // Setze visuelle Elemente zurück (falls nötig, sollte aber schon passiert sein)
          setState(() {
            _routePoints = null;
            _startMarker = null;
            _endMarker = null;
          });

        } else {
          // --- Route gefunden ---
          if (kDebugMode) print("<<< Route berechnet (${path.length} Punkte).");

          // Route visualisieren
          _routePoints = Polyline(
            points: path.map((node) => LatLng(node.lat, node.lon)).toList(),
            color: Colors.blue,
            strokeWidth: 5.0,
          );

          // Start- und Endmarker erstellen
          _startMarker = Marker(
            width: 80.0, height: 80.0,
            point: LatLng(path.first.lat, path.first.lon),
            child: const Icon(Icons.location_on, color: Colors.green, size: 30),
            anchorPos: AnchorPos.align(AnchorAlign.top),
          );
          _endMarker = Marker(
            width: 80.0, height: 80.0,
            point: LatLng(path.last.lat, path.last.lon),
            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
            anchorPos: AnchorPos.align(AnchorAlign.top),
          );

          // Erfolgsmeldung
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Route berechnet."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));

           // Wichtig: Hier nochmal setState aufrufen, um _routePoints, _startMarker, _endMarker anzuzeigen
           setState(() {});
        }
      }

    } catch (e, stacktrace) {
      // --- Fehler bei der Berechnung ---
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
         // Setze Route und Marker zurück
         setState(() {
            _calculatedRoute = null;
            _routePoints = null;
            _startMarker = null;
            _endMarker = null;
         });
      }
    } finally {
       // --- Aufräumen (immer ausführen) ---
      if (mounted) {
        // Ladeindikator beenden
        setState(() => _isCalculatingRoute = false);
         if (kDebugMode) print("<<< Routenberechnung abgeschlossen (finally).");
      }
    }
  }


  // Löscht die aktuell angezeigte Route und Marker
  void _clearRoute() {
    if (kDebugMode) print("<<< _clearRoute aufgerufen.");
    setState(() {
      _routePoints = null;
      _startMarker = null;
      _endMarker = null;
      _mockStartLatLng = null; // Auch Mock-Startpunkt löschen
      _calculatedRoute = null; // Berechnete Rohdaten löschen
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
  // BUILD METHODE
  //---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // --- DEBUG PRINT 1 ---
    // Gibt den aktuellen Wert von _mockStartLatLng bei jedem Neuaufbau aus.
    if (kDebugMode) {
      print("<<< BUILD >>> _mockStartLatLng is: $_mockStartLatLng");
    }

    // --- Vorbereitung des grünen Mock-Start-Markers ---
    // Definiere den Marker oder null basierend auf der Bedingung.
    // Dies vermeidet komplexe Logik direkt in der Marker-Liste.
    Marker? mockStartMarker;
    if (_mockStartLatLng != null) {
       // --- DEBUG PRINT 2 ---
       // Wird ausgegeben, wenn der Marker erstellt wird.
       if (kDebugMode) print("<<< BUILD >>> Preparing green mock start marker!");
       mockStartMarker = Marker(
          width: 80.0,
          height: 80.0,
          point: _mockStartLatLng!,
          child: const Icon(Icons.pin_drop, color: Colors.green, size: 30.0),
          anchorPos: AnchorPos.align(AnchorAlign.top), // Oben zentriert
        );
    } else {
       // --- DEBUG PRINT 3 ---
       // Wird ausgegeben, wenn kein Marker erstellt wird.
       if (kDebugMode) print("<<< BUILD >>> NOT preparing green mock start marker (_mockStartLatLng is null).");
    }
    // --- Ende Vorbereitung Mock-Marker ---


    // --- Das eigentliche Scaffold der App ---
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campground Nav'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData, // Lädt GeoJSON neu
            tooltip: 'Daten neu laden',
          ),
          // TODO: Suchfunktion (optional)
          // IconButton(
          //   icon: const Icon(Icons.search),
          //   onPressed: () {
          //     // Implementiere Suchlogik oder zeige Suchdialog
          //   },
          // ),
        ],
      ),
      body: Stack( // Stack legt Widgets übereinander
        children: [
          // --- Die FlutterMap Karte ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 17.0, // Angepasster initialer Zoom
              minZoom: 16.0,     // Minimaler Zoom (näher ran)
              maxZoom: 19.0,     // Maximaler Zoom (weiter weg)
              onTap: (tapPosition, point) {
                if (kDebugMode) print("<<<MapScreenState>>> Tapped on map: $point");

                if (_isCalculatingRoute) { // Keine Klicks während Berechnung erlauben
                  return;
                }

                // --- Mock Location Logic ---
                if (_mockStartLatLng == null) {
                  // Erster Klick: Setze Startpunkt
                  setState(() {
                    _mockStartLatLng = point;
                    // Lösche alte Route, wenn neuer Start gesetzt wird
                    _routePoints = null;
                    _startMarker = null;
                    _endMarker = null;
                    _calculatedRoute = null; // Auch die Rohdaten löschen
                  });
                   if (kDebugMode) print("<<<MapScreenState>>> Setting mock start point.");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Startpunkt gesetzt. Erneut tippen für Ziel."),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Zweiter Klick: Setze Endpunkt und berechne Route
                  if (kDebugMode) print("<<<MapScreenState>>> Setting mock end point and calculating route.");
                  _calculateAndDisplayRoute(_mockStartLatLng!, point); // Starte Berechnung
                  // Setze _mockStartLatLng sofort auf null, damit der grüne Pin verschwindet
                  setState(() {
                     _mockStartLatLng = null;
                  });
                }
                // --- End Mock Location Logic ---
              },
              onPositionChanged: (position, hasGesture) {
                // Optional: Aktuellen Zoom/Center speichern oder ausgeben
                // if (kDebugMode) print("Map Center: ${position.center}, Zoom: ${position.zoom}");
              },
            ),
            children: [ // Layer der Karte
              // --- Kachel-Layer (Hintergrund) ---
              TileLayer(
                // CORS Problem: Zeigt aktuell grauen Hintergrund in Codespaces
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.camping_osm_navi',
                // Fallback, falls Kacheln nicht laden (optional)
                // errorImage: AssetImage('assets/images/placeholder.png'),
                errorTileCallback: (tile, error, stacktrace) {
                   if (kDebugMode) print("Tile Error: ${tile.coords}, Error: $error");
                },
              ),

              // --- Gebäude Layer ---
              PolygonLayer(polygons: _buildings),

              // --- Wege Layer ---
              PolylineLayer(polylines: _paths),

              // --- Routen Layer ---
              // Zeigt die berechnete Route an, wenn _routePoints vorhanden ist
              if (_routePoints != null)
                 PolylineLayer(polylines: [_routePoints!]),

              // --- Marker Layer (POIs, GPS, Route, Mock-Start) ---
              MarkerLayer(
                markers: [
                  // GPS Position Marker (Rot)
                  if (_currentPosition != null)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 30.0),
                      anchorPos: AnchorPos.align(AnchorAlign.top),
                    ),

                  // POI Markers
                  ..._poiMarkers,

                  // Mock Start Point Marker (Grüner Pin)
                  // Wird angezeigt, wenn mockStartMarker (oben vorbereitet) nicht null ist
                  if (mockStartMarker != null) mockStartMarker,

                  // Route Start/End Markers (falls vorhanden)
                  if (_startMarker != null) _startMarker!,
                  if (_endMarker != null) _endMarker!,
                ],
              ),
            ], // Ende FlutterMap Children
          ), // Ende FlutterMap

          // --- Ladeindikator ---
          // Wird über die Karte gelegt, wenn _isCalculatingRoute true ist
          if (_isCalculatingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5), // Dunkelt Hintergrund ab
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),

        ], // Ende Stack Children
      ), // Ende Stack

      // --- Floating Action Buttons ---
      // Positioniert oben links
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
      floatingActionButtons: Column(
        mainAxisAlignment: MainAxisAlignment.start, // Vertikal oben starten
        crossAxisAlignment: CrossAxisAlignment.start, // Horizontal links starten
        children: [
          // --- Button zum Löschen der Route ---
          // Wird nur angezeigt, wenn eine Route (_routePoints) existiert.
          // Das Padding (top: 10.0) positioniert ihn nahe am oberen linken Rand.
          if (_routePoints != null && _routePoints!.points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10.0, left: 10.0), // <<< KORRIGIERTES PADDING
              child: FloatingActionButton.small(
                heroTag: "clearRouteBtn",
                onPressed: _clearRoute,
                backgroundColor: Colors.redAccent,
                child: const Icon(Icons.clear, color: Colors.white),
                tooltip: 'Route löschen',
              ),
            ),

          // --- Button zum Zentrieren auf GPS ---
          // Ist immer sichtbar.
           Padding(
             padding: const EdgeInsets.only(top: 10.0, left: 10.0), // Unverändert zum Original
             child: FloatingActionButton.small(
                heroTag: "centerGpsBtn",
                onPressed: _centerOnGps,
                backgroundColor: Colors.blueAccent,
                child: const Icon(Icons.my_location, color: Colors.white),
                tooltip: 'Auf GPS zentrieren',
              ),
           ),
        ],
      ), // Ende Column für FABs
    ); // Ende Scaffold
  }
  // --- Ende BUILD METHODE ---

} // Ende _MapScreenState Klasse