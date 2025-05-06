// [Start lib/main.dart]
// lib/main.dart (Version mit Korrekturen basierend auf ALLEN Logs und Model-Dateien)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für rootBundle
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'; // <-- NEU HINZUGEFÜGT

// Eigene Imports
// ignore: unused_import
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
// ignore: unused_import
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
  LatLng? _mockStartLatLng; // Für Mock-Startpunkt per Klick
  LatLng? _mockEndLatLng;   // Für Mock-Zielpunkt per Klick
  bool _isCalculatingRoute = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Such-Controller und Fokus-Knoten
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchableFeature> _searchResults = [];
  bool _showSearchResults = false;
  SearchableFeature? _selectedSearchFeatureForStart;
  SearchableFeature? _selectedSearchFeatureForEnd;


  static const LatLng colléGeländeMitte = LatLng(51.002014, 5.870863); // Ungefähre Mitte des Collé-Geländes

  // Konstanten für Marker-Größen und Anchors
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

  Future<void> _loadData() async {
    if (kDebugMode) {
      print("<<< _loadData: Starte das Laden der GeoJSON Daten... >>>");
    }
    try {
      final String geoJsonString = await rootBundle.loadString('assets/data/export.geojson');
      final RoutingGraph graph = GeojsonParserService.parseGeoJson(geoJsonString);
      final List<SearchableFeature> features = GeojsonParserService.extractSearchableFeatures(geoJsonString);


      if (mounted) {
        setState(() {
          _routingGraph = graph;
          _searchableFeatures = features;
           if (kDebugMode) {
            print("<<< _loadData: GeoJSON Daten verarbeitet. Routing Graph initialisiert. Suchbare Features: ${features.length} >>>");
            print("<<< _loadData: Routing Graph: ${_routingGraph?.nodes.length ?? 0} Knoten, ${_routingGraph?.getEdgeCount() ?? 0} Kanten >>>");
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

    final results = _searchableFeatures.where((feature) {
      return feature.name.toLowerCase().contains(query) ||
            (feature.building?.toLowerCase().contains(query) ?? false) ||
            (feature.category?.toLowerCase().contains(query) ?? false);
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
      print("<<< _selectFeatureAndSetPoint: Feature ausgewählt: ${feature.name} an Position ${feature.position} >>>");
    }

    _searchController.clear();
    _searchResults = [];
    _showSearchResults = false;
    _searchFocusNode.unfocus();


    if (_selectedSearchFeatureForStart == null) {
      _selectedSearchFeatureForStart = feature;
       if (mounted) {
          setState(() {
            _mockStartLatLng = feature.position;
            _startMarker = _createMarker(feature.position, Colors.green, Icons.flag, "Start: ${feature.name}");
             if (kDebugMode) {
               print("<<< _selectFeatureAndSetPoint: Startpunkt gesetzt auf: ${feature.name} >>>");
             }
          });
       }
      _showStartEndSelectionDialog("Startpunkt: ${feature.name}. Ziel auswählen oder auf Karte tippen.");
    } else if (_selectedSearchFeatureForEnd == null) {
      _selectedSearchFeatureForEnd = feature;
       if (mounted) {
          setState(() {
            _mockEndLatLng = feature.position;
            _endMarker = _createMarker(feature.position, Colors.red, Icons.flag, "Ziel: ${feature.name}");
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
    var anchor = AnchorPos.align(AnchorAlign.top);

    return Marker(
      width: markerWidth,
      height: markerHeight,
      point: position,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: 30.0),
      ),
      alignment: anchor,
    );
  }

  Future<void> _calculateAndDisplayRoute() async {
    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      _showErrorDialog("Routing-Daten nicht geladen. Navigation nicht möglich.");
      if (kDebugMode) {
        print(">>> _calculateAndDisplayRoute: Routing Graph nicht initialisiert oder leer. Abbruch. >>>");
      }
      return;
    }

    if (_mockStartLatLng == null || _mockEndLatLng == null) {
      _showErrorDialog("Start- oder Zielpunkt nicht gesetzt.");
       if (kDebugMode) {
        print(">>> _calculateAndDisplayRoute: Start- oder Zielpunkt nicht gesetzt. Abbruch. >>>");
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCalculatingRoute = true;
      });
    }

     if (kDebugMode) {
        print("<<< _calculateAndDisplayRoute: Starte Routenberechnung von $_mockStartLatLng nach $_mockEndLatLng >>>");
      }


    try {
      final List<LatLng> route = await Future.delayed(const Duration(milliseconds: 100), () {
        return RoutingService.findPath(_routingGraph!, _mockStartLatLng!, _mockEndLatLng!);
      });


      if (mounted) {
        setState(() {
          if (route.isNotEmpty) {
            _routePolyline = Polyline(
              points: route,
              strokeWidth: 5.0,
              color: Colors.deepPurple,
            );
             if (kDebugMode) {
              print("<<< _calculateAndDisplayRoute: Route gefunden mit ${route.length} Punkten. >>>");
            }
            _showStartEndSelectionDialog("Route berechnet. Neuen Startpunkt wählen oder Route löschen.", durationSeconds: 5);

          } else {
            _routePolyline = null;
            _showErrorDialog("Keine Route zwischen den gewählten Punkten gefunden.");
             if (kDebugMode) {
              print("<<< _calculateAndDisplayRoute: Keine Route gefunden. >>>");
            }
             _clearRoute(showConfirmation: false);
          }
        });
      }
    } catch (e) {
       if (kDebugMode) {
          print(">>> _calculateAndDisplayRoute: Fehler bei der Routenberechnung: $e >>>");
        }
      if (mounted) {
        _showErrorDialog("Fehler bei der Routenberechnung: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  void _handleMapTap(dynamic tapPosition, LatLng latLng) {
    if (kDebugMode) {
      print("<<<MapScreenState>>> Tapped on map: $latLng");
    }

    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      setState(() {
        _showSearchResults = false;
      });
    }

    if (_isCalculatingRoute) return;


    if (_mockStartLatLng == null || _selectedSearchFeatureForStart == null) {
       if (mounted) {
          setState(() {
            _mockStartLatLng = latLng;
            _startMarker = _createMarker(latLng, Colors.green, Icons.flag, "Start");
             _selectedSearchFeatureForStart = SearchableFeature(id: "map_tap_start", name: "Start (Karte)", position: latLng);
             if (kDebugMode) {
               print("<<<MapScreenState>>> Setting mock start point (via map tap).");
             }
          });
       }
      _showStartEndSelectionDialog("Startpunkt gesetzt. Ziel auswählen oder auf Karte tippen.");

    } else if (_mockEndLatLng == null || _selectedSearchFeatureForEnd == null) {
       if (mounted) {
          setState(() {
            _mockEndLatLng = latLng;
            _endMarker = _createMarker(latLng, Colors.red, Icons.flag, "Ziel");
            _selectedSearchFeatureForEnd = SearchableFeature(id: "map_tap_end", name: "Ziel (Karte)", position: latLng);
             if (kDebugMode) {
               print("<<<MapScreenState>>> Setting mock end point (via map tap). Ready to calculate.");
             }
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
              _startMarker = _createMarker(latLng, Colors.green, Icons.flag, "Start");
              _selectedSearchFeatureForStart = SearchableFeature(id: "map_tap_start", name: "Start (Karte)", position: latLng);
              if (kDebugMode) {
                 print("<<<MapScreenState>>> Setting NEW mock start point after confirmation.");
              }
            });
            _showStartEndSelectionDialog("Neuer Startpunkt gesetzt. Ziel auswählen oder auf Karte tippen.");
          }
        }
      );
    }
  }

  void _clearRoute({bool showConfirmation = true}) {
    final Function clearAction = () {
      if (mounted) {
        setState(() {
          _routePolyline = null;
          _startMarker = null;
          _endMarker = null;
          _mockStartLatLng = null;
          _mockEndLatLng = null;
          _selectedSearchFeatureForStart = null;
          _selectedSearchFeatureForEnd = null;
           if (kDebugMode) {
             print("<<< _clearRoute: Route und Marker gelöscht. >>>");
           }
        });
      }
       _showStartEndSelectionDialog("Route gelöscht. Startpunkt auswählen oder auf Karte tippen.", durationSeconds: 3);
    };

    if (showConfirmation) {
      _showConfirmationDialog("Route löschen", "Möchtest du die aktuelle Route und die gesetzten Punkte wirklich löschen?", clearAction);
    } else {
      clearAction();
    }
  }


  void _centerOnGps() {
    if (_currentGpsPosition != null) {
      _mapController.move(_currentGpsPosition!, 17.0);
       if (kDebugMode) {
         print("<<< _centerOnGps: Zentriere auf GPS-Position: $_currentGpsPosition >>>");
       }
    } else {
       if (kDebugMode) {
         print("<<< _centerOnGps: Keine GPS-Position verfügbar zum Zentrieren. >>>");
       }
      _showErrorDialog("Keine GPS-Position verfügbar.");
    }
  }


  void _showErrorDialog(String message) {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (mounted) {
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
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _showStartEndSelectionDialog(String message, {int durationSeconds = 3}) {
    if (mounted && ScaffoldMessenger.of(context).mounted) { // Prüfen ob ScaffoldMessenger mounted ist
      ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Entferne aktuelle Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: durationSeconds),
        ),
      );
    }
  }


  void _showConfirmationDialog(String title, String content, VoidCallback onConfirm) {
    if (mounted) {
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
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text("Bestätigen"),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print("<<< BUILD >>> _mockStartLatLng is: $_mockStartLatLng");
      if (_mockStartLatLng == null && _startMarker == null) {
        print("<<< BUILD >>> NOT preparing green mock start marker (_mockStartLatLng is null).");
      } else if (_mockStartLatLng !=null && _startMarker != null) {
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
              initialCenter: _currentGpsPosition ?? colléGeländeMitte,
              initialZoom: 16.0,
              minZoom: 14.0,
              maxZoom: 19.0,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'de.deinprojekt.app.unique', // WICHTIG: Eindeutiger User-Agent
                tileProvider: CancellableNetworkTileProvider(), // <-- NEUER TILE PROVIDER
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
                             setState(() {
                              _searchResults = [];
                              _showSearchResults = false;
                            });
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
              top: 70,
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
                        subtitle: Text(feature.category ?? feature.building ?? 'Unbekannt'),
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
          if (_routePolyline != null && _routePolyline!.points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: "clearRouteBtn",
                onPressed: _clearRoute,
                backgroundColor: Colors.redAccent,
                tooltip: 'Route löschen',
                child: const Icon(Icons.clear, color: Colors.white),
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