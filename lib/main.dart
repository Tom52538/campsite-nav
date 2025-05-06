// [Start lib/main.dart]
import 'dart:async';
import 'dart:convert'; // Für jsonDecode in _extractSearchableFeaturesFromGeoJson
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
  LatLng? _mockStartLatLng;
  LatLng? _mockEndLatLng;
  bool _isCalculatingRoute = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchableFeature> _searchResults = [];
  bool _showSearchResults = false;
  SearchableFeature? _selectedSearchFeatureForStart;
  SearchableFeature? _selectedSearchFeatureForEnd;

  // Name korrigiert für ASCII-Kompatibilität als Identifier
  static const LatLng colleGelaendeMitte = LatLng(51.002014, 5.870863);

  static const double markerWidth = 80.0;
  static const double markerHeight = 80.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeGps();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _positionStreamSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Hilfsmethode, um SearchableFeatures aus dem GeoJSON zu extrahieren
  List<SearchableFeature> _extractSearchableFeaturesFromGeoJson(String geoJsonString) {
    final List<SearchableFeature> features = [];
    final decodedJson = jsonDecode(geoJsonString);

    if (decodedJson is Map<String, dynamic> &&
        decodedJson['type'] == 'FeatureCollection' &&
        decodedJson['features'] is List) {
      for (final featureJson in decodedJson['features']) {
        if (featureJson is Map<String, dynamic>) {
          final properties = featureJson['properties'] as Map<String, dynamic>?;
          final geometry = featureJson['geometry'] as Map<String, dynamic>?;

          if (properties != null && geometry != null) {
            final dynamic id = featureJson['id'] ?? properties['@id'] ?? DateTime.now().millisecondsSinceEpoch.toString(); // Fallback ID
            final String? name = properties['name'] as String?;
            String type = properties['highway'] as String? ??
                          properties['amenity'] as String? ??
                          properties['shop'] as String? ??
                          properties['building'] as String? ?? // Fallback für building-Typ
                          'unknown'; // Fallback-Typ

            // Nur Features mit Namen hinzufügen
            if (name != null && name.isNotEmpty) {
              LatLng? center;
              if (geometry['type'] == 'Point') {
                final coords = geometry['coordinates'] as List?;
                if (coords != null && coords.length >= 2) {
                  center = LatLng(coords[1] as double, coords[0] as double);
                }
              } else if (geometry['type'] == 'LineString' || geometry['type'] == 'Polygon') {
                // Für Linien/Polygone den ersten Punkt als Zentrum nehmen (vereinfacht)
                // Eine bessere Methode wäre, den Mittelpunkt der Bounding Box zu berechnen
                final coordsList = geometry['coordinates'] as List?;
                if (coordsList != null && coordsList.isNotEmpty) {
                  List<dynamic> firstPointList = coordsList.first as List;
                  if (geometry['type'] == 'Polygon') { // Polygone haben eine zusätzliche Verschachtelung
                      firstPointList = (coordsList.first as List).first as List;
                  }
                   if (firstPointList.length >= 2) {
                     center = LatLng(firstPointList[1] as double, firstPointList[0] as double);
                   }
                }
              }

              if (center != null) {
                features.add(SearchableFeature(
                  id: id,
                  name: name,
                  type: type, // Hier den extrahierten Typ verwenden
                  center: center,
                ));
              }
            }
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
    try {
      final String geoJsonString = await rootBundle.loadString('assets/data/export.geojson');
      final RoutingGraph graph = GeojsonParserService.parseGeoJson(geoJsonString);
      final List<SearchableFeature> features = _extractSearchableFeaturesFromGeoJson(geoJsonString);

      if (mounted) {
        setState(() {
          _routingGraph = graph;
          _searchableFeatures = features;
          if (kDebugMode) {
            print("<<< _loadData: GeoJSON Daten verarbeitet. Routing Graph initialisiert. Suchbare Features: ${_searchableFeatures.length} >>>");
            print("<<< _loadData: Routing Graph: ${_routingGraph?.nodes.length ?? 0} Knoten >>>");
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> _loadData: Fehler beim Laden/Parsen der GeoJSON Daten: $e");
        print(stacktrace);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Kartendaten: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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

    // Suche in Name und Typ
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
          _mockStartLatLng = feature.center; // Position von feature.center nehmen
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
          _mockEndLatLng = feature.center; // Position von feature.center nehmen
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorDialog("GPS ist deaktiviert. Bitte aktiviere es.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog("GPS-Berechtigung verweigert. Navigation nicht möglich.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog("GPS-Berechtigung dauerhaft verweigert. Bitte in den Einstellungen ändern.");
      return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentGpsPosition = LatLng(position.latitude, position.longitude);
          _currentLocationMarker = _createMarker(
              _currentGpsPosition!, Colors.blue, Icons.my_location, "Meine Position");
          if (kDebugMode) {
            print("<<< _initializeGps: Neue GPS Position: $_currentGpsPosition >>>");
          }
        });
      }
    });
  }

  Marker _createMarker(LatLng position, Color color, IconData icon, String tooltip) {
    // FlutterMap richtet Marker standardmäßig oft mittig unten aus (gut für Pins).
    // Für eine Ausrichtung oben/mittig:
    Alignment alignment = Alignment.topCenter;

    return Marker(
      width: markerWidth,
      height: markerHeight,
      point: position,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: 30.0),
      ),
      alignment: alignment,
    );
  }

  Future<void> _calculateAndDisplayRoute() async {
    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      _showErrorDialog("Routing-Daten nicht geladen. Navigation nicht möglich.");
      if (kDebugMode) print(">>> _calculateAndDisplayRoute: Routing Graph nicht initialisiert oder leer. Abbruch. >>>");
      return;
    }

    if (_mockStartLatLng == null || _mockEndLatLng == null) {
      _showErrorDialog("Start- oder Zielpunkt nicht gesetzt.");
      if (kDebugMode) print(">>> _calculateAndDisplayRoute: Start- oder Zielpunkt nicht gesetzt. Abbruch. >>>");
      return;
    }

    if (mounted) setState(() => _isCalculatingRoute = true);

    if (kDebugMode) print("<<< _calculateAndDisplayRoute: Starte Routenberechnung von $_mockStartLatLng nach $_mockEndLatLng >>>");

    try {
      // Nächstgelegene Knoten im Graphen finden
      final GraphNode? startNode = _routingGraph!.findNearestNode(_mockStartLatLng!);
      final GraphNode? endNode = _routingGraph!.findNearestNode(_mockEndLatLng!);

      if (startNode == null || endNode == null) {
        _showErrorDialog("Start- oder Zielpunkt konnte nicht auf dem Wegenetz gefunden werden.");
        if (kDebugMode) print(">>> _calculateAndDisplayRoute: Start- oder Endknoten nicht im Graphen gefunden. Abbruch.");
        if (mounted) setState(() => _isCalculatingRoute = false);
        return;
      }

      if (startNode.id == endNode.id) {
        _showErrorDialog("Start- und Zielpunkt sind identisch (oder zu nah beieinander).");
         if (kDebugMode) print(">>> _calculateAndDisplayRoute: Start- und Endknoten sind identisch. Abbruch.");
        if (mounted) setState(() => _isCalculatingRoute = false);
        _clearRoute(showConfirmation: false); // Route löschen, da keine Berechnung nötig
        return;
      }


      // Kosten zurücksetzen vor jeder neuen Suche
      _routingGraph!.resetAllNodeCosts();

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
            _showSnackbar("Route berechnet. Neuen Startpunkt wählen oder Route löschen.", durationSeconds: 5);
          } else {
            _routePolyline = null;
            _showErrorDialog("Keine Route zwischen den gewählten Punkten gefunden.");
            if (kDebugMode) print("<<< _calculateAndDisplayRoute: Keine Route gefunden. >>>");
            // _clearRoute(showConfirmation: false); // Optional: Punkte beibehalten für neuen Versuch
          }
        });
      }
    } catch (e) {
      if (kDebugMode) print(">>> _calculateAndDisplayRoute: Fehler bei der Routenberechnung: $e >>>");
      if (mounted) _showErrorDialog("Fehler bei der Routenberechnung: $e");
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  void _handleMapTap(dynamic tapPosition, LatLng latLng) {
    if (kDebugMode) print("<<<MapScreenState>>> Tapped on map: $latLng");

    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      if(mounted) setState(() => _showSearchResults = false);
    }

    if (_isCalculatingRoute) return;

    if (_selectedSearchFeatureForStart == null) { // Statt _mockStartLatLng direkt _selectedSearchFeatureForStart prüfen
      if (mounted) {
        setState(() {
          _mockStartLatLng = latLng;
          // Erstelle ein temporäres SearchableFeature für getappte Punkte
          _selectedSearchFeatureForStart = SearchableFeature(id: "tap_${DateTime.now().millisecondsSinceEpoch}", name: "Start (Karte)", type: "map_tap", center: latLng);
          _startMarker = _createMarker(latLng, Colors.green, Icons.flag, "Start");
          if (kDebugMode) print("<<<MapScreenState>>> Setting mock start point (via map tap).");
        });
      }
      _showSnackbar("Startpunkt gesetzt. Ziel auswählen oder auf Karte tippen.");
    } else if (_selectedSearchFeatureForEnd == null) { // Statt _mockEndLatLng direkt _selectedSearchFeatureForEnd prüfen
      if (mounted) {
        setState(() {
          _mockEndLatLng = latLng;
          _selectedSearchFeatureForEnd = SearchableFeature(id: "tap_${DateTime.now().millisecondsSinceEpoch}", name: "Ziel (Karte)", type: "map_tap", center: latLng);
          _endMarker = _createMarker(latLng, Colors.red, Icons.flag, "Ziel");
          if (kDebugMode) print("<<<MapScreenState>>> Setting mock end point (via map tap). Ready to calculate.");
        });
      }
      _calculateAndDisplayRoute();
    } else {
      _showConfirmationDialog(
        "Route vorhanden",
        "Möchtest du einen neuen Startpunkt setzen? Die aktuelle Route wird dabei gelöscht.",
        () {
          if (mounted) {
            _clearRoute(showConfirmation: false);
            setState(() {
              _mockStartLatLng = latLng;
              _selectedSearchFeatureForStart = SearchableFeature(id: "tap_${DateTime.now().millisecondsSinceEpoch}", name: "Start (Karte)", type: "map_tap", center: latLng);
              _startMarker = _createMarker(latLng, Colors.green, Icons.flag, "Start");
              if (kDebugMode) print("<<<MapScreenState>>> Setting NEW mock start point after confirmation.");
            });
            _showSnackbar("Neuer Startpunkt gesetzt. Ziel auswählen oder auf Karte tippen.");
          }
        }
      );
    }
  }

  void _clearRoute({bool showConfirmation = true}) {
    final VoidCallback clearAction = () {
      if (mounted) {
        setState(() {
          _routePolyline = null;
          _startMarker = null;
          _endMarker = null;
          _mockStartLatLng = null;
          _mockEndLatLng = null;
          _selectedSearchFeatureForStart = null;
          _selectedSearchFeatureForEnd = null;
          if (kDebugMode) print("<<< _clearRoute: Route und Marker gelöscht. >>>");
        });
      }
      _showSnackbar("Route gelöscht. Startpunkt auswählen oder auf Karte tippen.", durationSeconds: 3);
    };

    if (showConfirmation && (_routePolyline != null || _startMarker != null || _endMarker != null)) { // Nur fragen, wenn etwas zu löschen ist
      _showConfirmationDialog("Route löschen", "Möchtest du die aktuelle Route und die gesetzten Punkte wirklich löschen?", clearAction);
    } else {
      clearAction(); // Direkt ausführen, wenn showConfirmation false ist oder nichts zu löschen ist
    }
  }

  void _centerOnGps() {
    if (_currentGpsPosition != null) {
      _mapController.move(_currentGpsPosition!, 17.0);
      if (kDebugMode) print("<<< _centerOnGps: Zentriere auf GPS-Position: $_currentGpsPosition >>>");
    } else {
      if (kDebugMode) print("<<< _centerOnGps: Keine GPS-Position verfügbar zum Zentrieren. >>>");
      _showErrorDialog("Keine GPS-Position verfügbar.");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    // Verhindere das Öffnen mehrerer Dialoge gleichzeitig
    if (ModalRoute.of(context)?.isCurrent == true && Navigator.of(context).canPop()) {
         // Es ist bereits ein Dialog offen, also nicht noch einen zeigen oder den aktuellen zuerst schließen.
         // Für Einfachheit: Wir zeigen keinen neuen, wenn schon einer da ist.
         // Alternativ: Navigator.of(context).pop(); // Schließe existierenden Dialog
         // showDialog(...); // Zeige neuen Dialog
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
      ),
    );
  }

  void _showConfirmationDialog(String title, String content, VoidCallback onConfirm) {
    if (!mounted) return;
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
      print("<<< BUILD >>> _mockStartLatLng is: $_mockStartLatLng, _selectedSearchFeatureForStart: ${_selectedSearchFeatureForStart?.name}");
      if (_mockStartLatLng == null) {
         print("<<< BUILD >>> _mockStartLatLng is null, not preparing start marker.");
      } else if (_startMarker != null) {
         print("<<< BUILD >>> Preparing green mock start marker!");
      }
    }

    List<Marker> activeMarkers = [];
    if (_currentLocationMarker != null) activeMarkers.add(_currentLocationMarker!);
    if (_startMarker != null) activeMarkers.add(_startMarker!);
    if (_endMarker != null) activeMarkers.add(_endMarker!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campground Navi"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentGpsPosition ?? colleGelaendeMitte,
              initialZoom: 16.0,
              minZoom: 14.0,
              maxZoom: 19.0,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'de.firma.campgroundnavi.app', // Beispielhafter eindeutiger User-Agent
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (_routePolyline != null) PolylineLayer(polylines: [_routePolyline!]),
              MarkerLayer(markers: activeMarkers),
              // Hier könnten weitere Layer wie Gebäude, POIs etc. aus GeoJSON hinzukommen
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
                    hintText: _selectedSearchFeatureForStart == null ? "Startpunkt suchen..." : "Zielpunkt suchen...",
                    suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
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
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final feature = _searchResults[index];
                      return ListTile(
                        title: Text(feature.name),
                        subtitle: Text(feature.type), // Typ des Features anzeigen
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
          if ((_routePolyline != null && _routePolyline!.points.isNotEmpty) || _startMarker != null || _endMarker != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: "clearRouteBtn",
                onPressed: _clearRoute,
                backgroundColor: Colors.redAccent,
                tooltip: 'Route/Punkte löschen',
                child: const Icon(Icons.delete_sweep, color: Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
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
// [Ende lib/main.dart]