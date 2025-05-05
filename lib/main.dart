// lib/main.dart (Stand: Button zum Löschen oben links implementiert)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // States
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionStreamSubscription;
  final MapController _mapController = MapController();
  bool _locationLoading = true;
  String? _locationError;
  List<Polygon> _polygons = [];
  List<Polyline> _polylines = [];
  List<Marker> _poiMarkers = [];
  bool _geoJsonLoading = true;
  String? _geoJsonError;
  List<SearchableFeature> _searchableFeatures = [];
  final TextEditingController _searchController = TextEditingController();
  List<SearchableFeature> _searchResults = [];
  bool _isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();
  RoutingGraph? _routingGraph;
  List<LatLng>? _calculatedRoute;
  bool _isCalculatingRoute = false; // Für Ladeindikator

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadAndParseGeoJson();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // --- Methoden ---
  Future<void> _initializeLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Standortdienste sind deaktiviert.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Standortberechtigung wurde verweigert.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Standortberechtigung wurde dauerhaft verweigert.');
      }

      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high, distanceFilter: 10))
          .listen((Position position) {
        if (mounted) {
          setState(() {
            _currentLatLng = LatLng(position.latitude, position.longitude);
            _locationLoading = false;
            _locationError = null;
          });
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            _locationError = "Standortupdates fehlgeschlagen: $error";
            _locationLoading = false;
          });
        }
      });

      try {
        Position initialPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5));
        if (mounted && _currentLatLng == null) {
          setState(() {
            _currentLatLng =
                LatLng(initialPosition.latitude, initialPosition.longitude);
             _locationLoading = false;
             _locationError = null;
          });
        }
      } catch (e) {
         if (mounted && _currentLatLng == null) {
            setState(() {
                 _locationError ??= "Initialer Standort fehlgeschlagen: $e";
                 _locationLoading = false;
            });
         }
        if (kDebugMode) {
          print("Error getting initial position (ignoring if stream works): $e");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString();
          _locationLoading = false;
        });
      }
      if (kDebugMode) {
        print("Error initializing location: $e");
      }
    }
  }


  Future<void> _loadAndParseGeoJson() async {
    if (kDebugMode) print("Versuche GeoJSON zu laden...");
    setState(() {
      _geoJsonLoading = true;
      _geoJsonError = null;
      _polygons = [];
      _polylines = [];
      _poiMarkers = [];
      _searchableFeatures = [];
      _routingGraph = null;
      _calculatedRoute = null;
    });
    try {
      const String assetPath = 'assets/export.geojson';
      final String geoJsonString = await rootBundle.loadString(assetPath);
      final decodedJson = jsonDecode(geoJsonString);

      if (decodedJson is Map<String, dynamic>) {
        if (kDebugMode) print("GeoJSON dekodiert, starte Parsing...");
        _parseGeoJsonForDisplay(decodedJson);
        _routingGraph = GeojsonParserService.parseGeoJson(geoJsonString);
        if (kDebugMode) {
          print(
              "Routing Graph nach dem Parsen: Nodes=${_routingGraph?.nodes.length ?? 0}");
        }
      } else {
        throw Exception("GeoJSON-Struktur ungültig");
      }
    } catch (e, stacktrace) {
      if (mounted) {
        setState(() => _geoJsonError = "Lade-/Parse-Fehler: $e");
      }
      if (kDebugMode) {
        print("Fehler beim Laden/Parsen der GeoJSON: $e");
        print(stacktrace);
      }
    } finally {
      if (mounted) {
        setState(() => _geoJsonLoading = false);
        if (kDebugMode) {
          print(
              "GeoJSON Verarbeitung abgeschlossen (Display & Routing). GeoJsonLoading: $_geoJsonLoading, Error: $_geoJsonError");
        }
      }
    }
  }

 void _parseGeoJsonForDisplay(Map<String, dynamic> geoJsonData) {
    // ... (Code unverändert) ...
    if (kDebugMode) print("Beginne Display-Parsing...");
    final List<Polygon> tempPolygons = [];
    final List<Polyline> tempPolylines = [];
    final List<Marker> tempPoiMarkers = [];
    final List<SearchableFeature> tempSearchableFeatures = [];

    if (geoJsonData['type'] == 'FeatureCollection' &&
        geoJsonData['features'] is List) {
      List features = geoJsonData['features'];
      if (kDebugMode) print("Parsing ${features.length} Features für Display...");

      for (var feature in features) {
        if (feature is Map<String, dynamic> &&
            feature['geometry'] is Map<String, dynamic>) {
          final geometry = feature['geometry'];
          final properties = Map<String, dynamic>.from(
              feature['properties'] ?? <String, dynamic>{});
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];
          final dynamic featureId = feature['id'] ??
              properties['@id'] ??
              DateTime.now().millisecondsSinceEpoch.toString(); // Fallback ID

          // --- Feature für Suche extrahieren ---
          if (properties['name'] != null && properties['name'].isNotEmpty) {
            String featureName = properties['name'];
            String featureType = 'Unknown';
            LatLng? centerPoint;

            // Typ bestimmen (vereinfacht)
            if (properties['building'] != null) {featureType = 'Building';}
            else if (properties['amenity'] == 'parking') {featureType = 'Parking';}
            else if (properties['highway'] == 'footway') {featureType = 'Footway';}
            else if (properties['highway'] == 'service') {featureType = 'Service Road';}
            else if (properties['barrier'] == 'gate') {featureType = 'Gate';}
            else if (properties['amenity'] == 'bus_station' || properties['highway'] == 'bus_stop') {featureType = 'Bus Stop';}
            else if (properties['highway'] == 'cycleway') {featureType = 'Cycleway';}
            else if (properties['highway'] == 'platform') {featureType = 'Platform';}
            else if (properties['highway'] == 'tertiary') {featureType = 'Tertiary Road';}
            else if (properties['highway'] == 'unclassified') {featureType = 'Unclassified Road';}
            else if (type == 'Point') {featureType = 'Point of Interest';}


            // Mittelpunkt für Suche/Zoom berechnen
            try {
              if (type == 'Point') {
                if (coordinates is List && coordinates.length >= 2 && coordinates[0] is num && coordinates[1] is num) {
                   centerPoint = LatLng(coordinates[1].toDouble(), coordinates[0].toDouble());
                }
              } else if (type == 'Polygon') {
                if (coordinates is List && coordinates.isNotEmpty && coordinates[0] is List) {
                  final List polygonPoints = coordinates[0];
                  if (polygonPoints.isNotEmpty) {
                    double totalLat = 0, totalLng = 0;
                    int pointCount = 0;
                    for (final point in polygonPoints) {
                      if (point is List && point.length >= 2 && point[0] is num && point[1] is num) {
                        totalLng += point[0].toDouble();
                        totalLat += point[1].toDouble();
                        pointCount++;
                      }
                    }
                    if (pointCount > 0) {
                       centerPoint = LatLng(totalLat / pointCount, totalLng / pointCount);
                    }
                  }
                }
              } else if (type == 'LineString') {
                if (coordinates is List && coordinates.isNotEmpty) {
                  double totalLat = 0, totalLng = 0;
                  int pointCount = 0;
                  for (final point in coordinates) {
                    if (point is List && point.length >= 2 && point[0] is num && point[1] is num) {
                      totalLng += point[0].toDouble();
                      totalLat += point[1].toDouble();
                      pointCount++;
                    }
                  }
                  if (pointCount > 0) {
                    centerPoint = LatLng(totalLat / pointCount, totalLng / pointCount);
                  }
                }
              }
            } catch (e) {
               if (kDebugMode) print("Fehler bei Centroid-Berechnung für Feature $featureId: $e");
            }

             if (centerPoint != null) {
               tempSearchableFeatures.add(SearchableFeature(
                   id: featureId.toString(),
                   name: featureName,
                   type: featureType,
                   center: centerPoint));
             }
          }

          // --- Feature für Anzeige erstellen ---
          if (coordinates is List) {
            try {
              if (type == 'Polygon') {
                if (coordinates.isNotEmpty && coordinates[0] is List) {
                  final List<LatLng> points = (coordinates[0] as List)
                      .map((coord) {
                        if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
                           return LatLng(coord[1].toDouble(), coord[0].toDouble());
                        }
                        return null;
                      })
                      .where((p) => p != null)
                      .cast<LatLng>()
                      .toList();
                  if (points.length >= 3) {
                     tempPolygons.add(Polygon(
                        points: points,
                        color: _getColorFromProperties(properties, Colors.grey.withAlpha((0.2 * 255).round())),
                        borderColor: _getColorFromProperties(properties, Colors.grey, border: true),
                        borderStrokeWidth: (properties['amenity'] == 'parking') ? 1.0 : 1.5,
                        isFilled: true));
                  }
                }
              } else if (type == 'LineString') {
                final List<LatLng> points = coordinates
                    .map((coord) {
                      if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
                        return LatLng(coord[1].toDouble(), coord[0].toDouble());
                      }
                      return null;
                    })
                    .where((p) => p != null)
                    .cast<LatLng>()
                    .toList();
                 if (points.length >= 2) {
                    tempPolylines.add(Polyline(
                        points: points,
                        color: _getColorFromProperties(properties, Colors.black54),
                        strokeWidth: (properties['highway'] == 'footway' || properties['highway'] == 'cycleway' || properties['highway'] == 'platform') ? 2.0 : 3.0));
                 }
              } else if (type == 'Point') {
                 if (coordinates.length >= 2 && coordinates[0] is num && coordinates[1] is num) {
                   final pointLatLng = LatLng(coordinates[1].toDouble(), coordinates[0].toDouble());
                   Icon? markerIcon;
                    if (properties['highway'] == 'bus_stop' || properties['amenity'] == 'bus_station') {
                         markerIcon = const Icon(Icons.directions_bus, color: Colors.indigo, size: 24.0);
                    } else if (properties['barrier'] == 'gate') {
                         markerIcon = Icon(Icons.fence, color: Colors.brown.shade700, size: 20.0);
                    }

                   if (markerIcon != null) {
                     final markerWidget = GestureDetector(
                       onTap: () => _handleMarkerTap(properties),
                       child: markerIcon,
                     );
                     tempPoiMarkers.add(Marker(
                       point: pointLatLng,
                       width: 30.0,
                       height: 30.0,
                       child: markerWidget,
                     ));
                   }
                 }
              }
            } catch (e, stacktrace) {
              if (kDebugMode) {
                print("Fehler beim Verarbeiten eines Karten-Layers für Feature $featureId: $e");
                print(stacktrace);
              }
            }
          }
        } else if (kDebugMode) {
           print("Skipping feature due to invalid structure: $feature");
        }
      }
    } else {
      if (kDebugMode) print("GeoJSON ist keine gültige FeatureCollection für Display.");
      _geoJsonError = "GeoJSON ist keine gültige FeatureCollection.";
    }

    if (kDebugMode) {
       print("Display-Parsing beendet: ${tempPolygons.length} Polygone, ${tempPolylines.length} Polylinien, ${tempPoiMarkers.length} POI-Marker, ${tempSearchableFeatures.length} durchsuchbare Features gefunden.");
    }
    if (mounted) {
      setState(() {
        _polygons = tempPolygons;
        _polylines = tempPolylines;
        _poiMarkers = tempPoiMarkers;
        _searchableFeatures = tempSearchableFeatures;
      });
    }
  }


  void _handleMarkerTap(Map<String, dynamic> properties) {
    // ... (Code unverändert) ...
    _showFeatureDetails(context, properties);
  }

 void _showFeatureDetails(
      BuildContext context, Map<String, dynamic> properties) {
    // ... (Code unverändert) ...
    final List<Widget> details = [];
    if (properties['name'] != null) {
       details.add(Text(properties['name'].toString(), style: Theme.of(context).textTheme.headlineSmall));
       details.add(const SizedBox(height: 8));
    }
    properties.forEach((key, value) {
      if (!key.startsWith('@') && !key.startsWith('ref:') && value != null && value.toString().isNotEmpty && key != 'name') {
         details.add(ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(value.toString())));
      }
    });
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        builder: (builderContext) {
           return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: details.isEmpty
                          ? const Center(child: Text("Keine Details verfügbar."))
                          : ListView(
                              shrinkWrap: true,
                              children: details,
                            ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        child: const Text('Schliessen'),
                        onPressed: () => Navigator.pop(builderContext),
                      ),
                    ),
                  ],
                ),
              ),
           );
        });
  }


  Color _getColorFromProperties(
      Map<String, dynamic> properties, Color defaultColor,
      {bool border = false}) {
      // ... (Code unverändert) ...
    if (properties['amenity'] == 'parking') {
      return border ? Colors.grey.shade600 : Colors.grey.withAlpha((0.4 * 255).round());
    }
    if (properties['building'] != null) {
      if (properties['building'] == 'warehouse') {
         return border ? Colors.brown.shade700 : Colors.brown.withAlpha((0.3 * 255).round());
      }
      if (properties['building'] == 'construction') {
         return border ? Colors.orangeAccent : Colors.orange.withAlpha((0.3 * 255).round());
      }
      return border ? Colors.blueGrey : Colors.blueGrey.withAlpha((0.3 * 255).round());
    }
    if (properties['highway'] != null) {
      switch (properties['highway']) {
        case 'footway': case 'path': case 'steps': return Colors.lime.shade900;
        case 'cycleway': return Colors.deepPurpleAccent;
        case 'service': return Colors.grey.shade700;
        case 'platform': return Colors.lightBlueAccent;
        case 'tertiary': case 'unclassified': case 'residential': return Colors.black87;
        default: return defaultColor;
      }
    }
     if (properties['landuse'] == 'grass') {
         return border ? Colors.green.shade800 : Colors.green.withAlpha((0.2 * 255).round());
     }
     if (properties['natural'] == 'water') {
         return border ? Colors.blue.shade800 : Colors.blue.withAlpha((0.4 * 255).round());
     }
    return defaultColor;
  }

  void _onSearchChanged() {
    // ... (Code unverändert) ...
    String query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      if (_searchResults.isNotEmpty) {
        setState(() => _searchResults = []);
      }
      return;
    }
    List<SearchableFeature> filteredResults = _searchableFeatures
        .where((feature) => feature.name.toLowerCase().contains(query))
        .toList();
    setState(() => _searchResults = filteredResults);
  }

  AppBar _buildSearchAppBar() {
    // ... (Code unverändert) ...
    final ThemeData theme = Theme.of(context);
    final Color? foregroundColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final Color? hintColor = theme.hintColor.withAlpha((0.6 * 255).round());

    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: foregroundColor),
        tooltip: 'Suche verlassen',
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _searchFocusNode.unfocus();
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Ort suchen...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: hintColor),
        ),
        style: TextStyle(color: foregroundColor, fontSize: 18),
        cursorColor: foregroundColor,
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: Icon(Icons.clear, color: foregroundColor),
            tooltip: 'Suche löschen',
            onPressed: () => _searchController.clear(),
          ),
      ],
    );
  }

  AppBar _buildNormalAppBar() {
    // ... (Code unverändert) ...
    return AppBar(
      title: const Text('Campground Navi'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Suche öffnen',
          onPressed: () {
            setState(() => _isSearching = true);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                FocusScope.of(context).requestFocus(_searchFocusNode);
              }
            });
          },
        ),
      ],
    );
  }

  IconData _getIconForFeatureType(String type) {
    // ... (Code unverändert) ...
    switch (type) {
      case 'Building': return Icons.business;
      case 'Parking': return Icons.local_parking;
      case 'Gate': return Icons.fence;
      case 'Bus Stop': return Icons.directions_bus;
      case 'Footway': return Icons.directions_walk;
      case 'Cycleway': return Icons.directions_bike;
      case 'Service Road': return Icons.minor_crash_outlined;
      case 'Platform': return Icons.train;
      case 'Tertiary Road': return Icons.traffic;
      case 'Unclassified Road': return Icons.edit_road;
      case 'Point of Interest': return Icons.place;
      default: return Icons.location_pin;
    }
  }

  void _centerOnUser() {
    // ... (Code unverändert) ...
     if (_currentLatLng != null) {
        _mapController.move(_currentLatLng!, 17.5);
     }
  }

  void _clearRoute() {
    // ... (Code unverändert) ...
    setState(() {
      _calculatedRoute = null;
    });
     if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Route gelöscht."), duration: Duration(seconds: 2)),
        );
     }
  }


  // --- Build Methode ---
  @override
  Widget build(BuildContext context) {
    final bool isLoading = _locationLoading || _geoJsonLoading;
    final String? errorMessage = _locationError ?? _geoJsonError;
    const LatLng initialMapCenter = LatLng(51.024370, 5.861582);

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Stack( // Stack ermöglicht das Überlagern von Widgets
        children: [
          // Kartenanzeige
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Fehler: $errorMessage', textAlign: TextAlign.center),
                    ))
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialMapCenter,
                        initialZoom: 17.0,
                        minZoom: 15.0,
                        maxZoom: 19.0,
                        onTap: (tapPosition, point) {
                           if (_isSearching) {
                             setState(() {
                               _isSearching = false;
                               _searchController.clear();
                               _searchFocusNode.unfocus();
                             });
                           }
                          if (kDebugMode) {
                            print("Map tapped at: $point. Triggering route calculation.");
                          }
                          _calculateAndDisplayRoute(destination: point);
                        },
                      ),
                      children: [
                        TileLayer(
                           urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                           userAgentPackageName: 'com.example.camping_osm_navi',
                        ),
                        if (_polygons.isNotEmpty) PolygonLayer(polygons: _polygons),
                        if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
                        if (_calculatedRoute != null && _calculatedRoute!.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _calculatedRoute!,
                                color: Colors.blueAccent.withAlpha((0.8 * 255).round()),
                                strokeWidth: 5.0,
                                isDotted: false,
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round,
                              ),
                            ],
                          ),
                        if (_poiMarkers.isNotEmpty) MarkerLayer(markers: _poiMarkers),
                        if (_currentLatLng != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: _currentLatLng!,
                              width: 40, height: 40,
                              child: const Icon(Icons.location_pin, color: Colors.redAccent, size: 40.0),
                            )
                          ]),
                          if (_calculatedRoute != null && _calculatedRoute!.isNotEmpty)
                            MarkerLayer(markers: [
                               Marker(
                                  point: _calculatedRoute!.first, width: 30, height: 30,
                                  child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30),
                               ),
                               Marker(
                                 point: _calculatedRoute!.last, width: 30, height: 30,
                                 child: const Icon(Icons.flag, color: Colors.red, size: 30),
                               )
                            ]),
                      ],
                    ),

          // Suchergebnisliste (über der Karte, wenn Suche aktiv)
          if (_isSearching && _searchResults.isNotEmpty)
            Positioned(
              top: 0, left: 10, right: 10,
              child: Card(
                 elevation: 4.0,
                 child: ConstrainedBox(
                   constraints: BoxConstraints( maxHeight: MediaQuery.of(context).size.height * 0.4, ),
                   child: ListView.builder(
                     shrinkWrap: true,
                     itemCount: _searchResults.length,
                     itemBuilder: (context, index) {
                       final feature = _searchResults[index];
                       return ListTile(
                         leading: Icon(_getIconForFeatureType(feature.type)),
                         title: Text(feature.name),
                         subtitle: Text(feature.type),
                         onTap: () {
                            _mapController.move(feature.center, 18.0);
                            setState(() {
                              _isSearching = false;
                              _searchController.clear();
                              _searchResults = [];
                              _searchFocusNode.unfocus();
                            });
                         },
                       );
                     },
                   ),
                 ),
              ),
            ),

          // *** NEUE POSITION FÜR CLEAR BUTTON ***
          // Wird nur angezeigt, wenn eine Route vorhanden ist
          if (_calculatedRoute != null && _calculatedRoute!.isNotEmpty)
            Positioned(
              top: 10.0, // Abstand vom oberen Rand (ggf. anpassen)
              left: 10.0,  // Abstand vom linken Rand
              child: FloatingActionButton(
                mini: true, // Kleinerer Button
                heroTag: "clearRouteBtn", // Eindeutiger Tag
                onPressed: _clearRoute, // Ruft die Löschfunktion auf
                tooltip: 'Route löschen',
                // Angepasste Farben für besseren Kontrast auf der Karte
                backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(220), // Heller Hintergrund mit Transparenz
                foregroundColor: Theme.of(context).colorScheme.onSurface, // Passende Icon-Farbe
                elevation: 4.0, // Leichter Schatten
                child: const Icon(Icons.clear),
              ),
            ),
          // *** ENDE CLEAR BUTTON ***

          // Ladeindikator für Routenberechnung (über allem)
          if (_isCalculatingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.3 * 255).round()),
                child: const Center(
                  child: CircularProgressIndicator(
                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),

       // *** HIER WURDE DER ALTE CLEAR BUTTON ENTFERNT ***
       // -> Nur noch der Button zum Zentrieren ist hier
       floatingActionButton: FloatingActionButton(
            heroTag: "locationBtn", // Eindeutiger Tag
            onPressed: _centerOnUser,
            tooltip: 'Auf meinen Standort zentrieren',
            child: const Icon(Icons.my_location),
        ),

    );
  }


  // --- Methode für Routenberechnung ---
  Future<void> _calculateAndDisplayRoute({required LatLng destination}) async {
    // ... (Code unverändert) ...
    if (!mounted) return;
    final LatLng? startLatLng = _currentLatLng;

    if (startLatLng == null) {
      if (kDebugMode) print("Aktueller Standort nicht verfügbar.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Aktueller Standort nicht verfügbar."),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      if (kDebugMode) print("Routing-Daten nicht geladen oder Graph leer.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Routing-Daten nicht geladen."),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
      _calculatedRoute = null;
    });

    List<LatLng>? path;
    try {
      final GraphNode? startNode = _routingGraph!.findNearestNode(startLatLng);
      final GraphNode? endNode = _routingGraph!.findNearestNode(destination);

       if (startNode == null || endNode == null) {
         throw Exception("Start- oder Endpunkt konnte keinem Weg zugeordnet werden.");
       }

       if (startNode.id == endNode.id) {
         if (kDebugMode) print("Start- und Zielpunkt sind identisch (oder nächster Knoten ist derselbe).");
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Start und Ziel sind zu nah beieinander."),
            duration: Duration(seconds: 2),
           ));
         }
         if (mounted) setState(() => _isCalculatingRoute = false);
         return;
       }

      if (kDebugMode) {
        print(
            ">>> Berechne Route von Knoten ${startNode.id} (Start: $startLatLng) zu ${endNode.id} (Ziel: $destination)");
      }
      _routingGraph!.resetAllNodeCosts();
      path = await RoutingService.findPath(_routingGraph!, startNode, endNode);

      if (mounted) {
        setState(() => _calculatedRoute = path);

        if (path == null || path.isEmpty) {
          if (kDebugMode) print("<<< Kein Pfad gefunden.");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Keine Route gefunden."),
            backgroundColor: Colors.orange,
          ));
        } else {
          if (kDebugMode) print("<<< Route berechnet (${path.length} Punkte).");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Route berechnet."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
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
         setState(() => _calculatedRoute = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
        if (kDebugMode) print("<<< Routenberechnungsmethode beendet (finally).");
      }
    }
  }


} // Ende _MapScreenState