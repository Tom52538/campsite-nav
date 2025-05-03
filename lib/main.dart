// lib/main.dart (Mit allem bisherigen UND Mock-Location-Toggle)

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
  // --- NEUER STATE ---
  bool _useMockLocation = true; // Standardmäßig Mock-Position verwenden
  final LatLng mockStartPosition =
      const LatLng(51.024370, 5.861582); // Feste Mock-Position
  // -----------------

  // Bestehende States
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
  bool _isCalculatingRoute = false;

  // initState, dispose (unverändert)
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

  // _initializeLocation, _loadAndParseGeoJson, _parseGeoJsonForDisplay (unverändert)
  Future<void> _initializeLocation() async {
    /* ... wie in Schritt 12 ... */ setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Standortdienste sind deaktiviert.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Standortberechtigung wurde verweigert.');
      }
      if (permission == LocationPermission.deniedForever)
        throw Exception('Standortberechtigung wurde dauerhaft verweigert.');
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high, distanceFilter: 10))
          .listen((Position position) {
        if (mounted)
          setState(() {
            _currentLatLng = LatLng(position.latitude, position.longitude);
            _locationLoading = false;
            _locationError = null;
          });
      }, onError: (error) {
        if (mounted)
          setState(() {
            _locationError = "Standortupdates fehlgeschlagen: $error";
            _locationLoading = false;
          });
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _locationError = e.toString();
          _locationLoading = false;
        });
    }
  }

  Future<void> _loadAndParseGeoJson() async {
    /* ... wie in Schritt 12 ... */ if (kDebugMode)
      print("Versuche GeoJSON zu laden...");
    setState(() {
      _geoJsonLoading = true;
      _geoJsonError = null;
      _polygons = [];
      _polylines = [];
      _poiMarkers = [];
      _searchableFeatures = [];
      _routingGraph = null;
    });
    try {
      const String assetPath = 'assets/export.geojson';
      final String geoJsonString = await rootBundle.loadString(assetPath);
      final decodedJson = jsonDecode(geoJsonString);
      if (decodedJson is Map<String, dynamic>) {
        _parseGeoJsonForDisplay(decodedJson);
        _routingGraph = GeojsonParserService.parseGeoJson(geoJsonString);
        if (kDebugMode)
          print(
              "Routing Graph nach dem Parsen: Nodes=${_routingGraph?.nodes.length ?? 0}");
      } else {
        throw Exception("GeoJSON-Struktur ungültig");
      }
    } catch (e) {
      if (mounted) setState(() => _geoJsonError = "Lade-/Parse-Fehler: $e");
      if (kDebugMode) print("Fehler beim Laden/Parsen: $e");
    } finally {
      if (mounted) {
        setState(() => _geoJsonLoading = false);
        if (kDebugMode)
          print("GeoJSON Verarbeitung abgeschlossen (Display & Routing)");
      }
    }
  }

  void _parseGeoJsonForDisplay(Map<String, dynamic> geoJsonData) {
    /* ... wie in Schritt 12 ... */ if (kDebugMode)
      print("Beginne Display-Parsing...");
    final List<Polygon> tempPolygons = [];
    final List<Polyline> tempPolylines = [];
    final List<Marker> tempPoiMarkers = [];
    final List<SearchableFeature> tempSearchableFeatures = [];
    if (geoJsonData['type'] == 'FeatureCollection' &&
        geoJsonData['features'] is List) {
      List features = geoJsonData['features'];
      if (kDebugMode)
        print("Parsing ${features.length} Features für Display...");
      for (var feature in features) {
        if (feature is Map<String, dynamic> &&
            feature['geometry'] is Map<String, dynamic>) {
          final geometry = feature['geometry'];
          final properties = Map<String, dynamic>.from(
              feature['properties'] ?? <String, dynamic>{});
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];
          if (properties['name'] != null && properties['name'].isNotEmpty) {
            final dynamic featureId = feature['id'] ??
                properties['@id'] ??
                DateTime.now().millisecondsSinceEpoch;
            final String featureName = properties['name'];
            String featureType = 'Unknown';
            LatLng? centerPoint;
            if (properties['building'] != null)
              featureType = 'Building';
            else if (properties['amenity'] == 'parking')
              featureType = 'Parking';
            else if (properties['highway'] == 'footway')
              featureType = 'Footway';
            else if (properties['highway'] == 'service')
              featureType = 'Service Road';
            else if (properties['barrier'] == 'gate')
              featureType = 'Gate';
            else if (properties['amenity'] == 'bus_station')
              featureType = 'Bus Stop';
            else if (properties['highway'] == 'bus_stop')
              featureType = 'Bus Stop';
            else if (properties['highway'] == 'cycleway')
              featureType = 'Cycleway';
            else if (properties['highway'] == 'platform')
              featureType = 'Platform';
            else if (properties['highway'] == 'tertiary')
              featureType = 'Tertiary Road';
            else if (properties['highway'] == 'unclassified')
              featureType = 'Unclassified Road';
            else if (type == 'Point') featureType = 'Point of Interest';
            try {
              if (type == 'Point') {
                if (coordinates is List &&
                    coordinates.length >= 2 &&
                    coordinates[0] is num &&
                    coordinates[1] is num)
                  centerPoint = LatLng(
                      coordinates[1].toDouble(), coordinates[0].toDouble());
              } else if (type == 'Polygon') {
                if (coordinates is List &&
                    coordinates.isNotEmpty &&
                    coordinates[0] is List) {
                  final List polygonPoints = coordinates[0];
                  if (polygonPoints.isNotEmpty) {
                    double totalLat = 0, totalLng = 0;
                    int pointCount = 0;
                    for (final point in polygonPoints)
                      if (point is List &&
                          point.length >= 2 &&
                          point[0] is num &&
                          point[1] is num) {
                        totalLng += point[0].toDouble();
                        totalLat += point[1].toDouble();
                        pointCount++;
                      }
                    if (pointCount > 0)
                      centerPoint =
                          LatLng(totalLat / pointCount, totalLng / pointCount);
                  }
                }
              } else if (type == 'LineString') {
                if (coordinates is List && coordinates.isNotEmpty) {
                  double totalLat = 0, totalLng = 0;
                  int pointCount = 0;
                  for (final point in coordinates)
                    if (point is List &&
                        point.length >= 2 &&
                        point[0] is num &&
                        point[1] is num) {
                      totalLng += point[0].toDouble();
                      totalLat += point[1].toDouble();
                      pointCount++;
                    }
                  if (pointCount > 0)
                    centerPoint =
                        LatLng(totalLat / pointCount, totalLng / pointCount);
                }
              }
            } catch (e) {
              if (kDebugMode)
                print(
                    "Fehler bei Centroid-Berechnung für Feature $featureId: $e");
            }
            if (centerPoint != null)
              tempSearchableFeatures.add(SearchableFeature(
                  id: featureId,
                  name: featureName,
                  type: featureType,
                  center: centerPoint));
          }
          if (coordinates is List) {
            try {
              if (type == 'Polygon') {
                if (coordinates.isNotEmpty && coordinates[0] is List) {
                  final List<LatLng> points = (coordinates[0] as List)
                      .map((coord) =>
                          LatLng(coord[1].toDouble(), coord[0].toDouble()))
                      .toList();
                  if (points.isNotEmpty)
                    tempPolygons.add(Polygon(
                        points: points,
                        color: _getColorFromProperties(properties,
                            Colors.grey.withAlpha((0.2 * 255).round())),
                        borderColor: _getColorFromProperties(
                            properties, Colors.grey, border: true),
                        borderStrokeWidth:
                            (properties['amenity'] == 'parking') ? 1.0 : 1.5,
                        isFilled: true));
                }
              } else if (type == 'LineString') {
                final List<LatLng> points = coordinates
                    .map((coord) =>
                        LatLng(coord[1].toDouble(), coord[0].toDouble()))
                    .toList();
                if (points.length >= 2)
                  tempPolylines.add(Polyline(
                      points: points,
                      color:
                          _getColorFromProperties(properties, Colors.black54),
                      strokeWidth: (properties['highway'] == 'footway' ||
                              properties['highway'] == 'cycleway' ||
                              properties['highway'] == 'platform')
                          ? 2.0
                          : 3.0));
              } else if (type == 'Point') {
                if (coordinates.length >= 2 &&
                    coordinates[0] is num &&
                    coordinates[1] is num) {
                  final pointLatLng = LatLng(
                      coordinates[1].toDouble(), coordinates[0].toDouble());
                  Icon? markerIcon;
                  if (properties['highway'] == 'bus_stop')
                    markerIcon = const Icon(Icons.directions_bus,
                        color: Colors.indigo, size: 24.0);
                  else if (properties['barrier'] == 'gate')
                    markerIcon = Icon(Icons.fence,
                        color: Colors.brown.shade700, size: 20.0);
                  if (markerIcon != null) {
                    final markerWidget = GestureDetector(
                        onTap: () => _handleMarkerTap(properties),
                        child: markerIcon);
                    tempPoiMarkers.add(Marker(
                        point: pointLatLng,
                        width: 30.0,
                        height: 30.0,
                        child: markerWidget));
                  }
                }
              }
            } catch (e) {
              if (kDebugMode)
                print(
                    "Fehler beim Verarbeiten eines Karten-Layers für Feature: $e");
            }
          }
        }
      }
    } else {
      if (kDebugMode)
        print("GeoJSON ist keine gültige FeatureCollection für Display.");
    }
    if (kDebugMode)
      print(
          "Display-Parsing beendet: ${tempPolygons.length} Polygone, ${tempPolylines.length} Polylinien (Wege), ${tempPoiMarkers.length} POI-Marker, ${tempSearchableFeatures.length} durchsuchbare Features gefunden.");
    if (mounted)
      setState(() {
        _polygons = tempPolygons;
        _polylines = tempPolylines;
        _poiMarkers = tempPoiMarkers;
        _searchableFeatures = tempSearchableFeatures;
      });
  }

  // _handleMarkerTap, _showFeatureDetails, _getColorFromProperties, _onSearchChanged, _buildSearchAppBar, _buildNormalAppBar, _getIconForFeatureType (unverändert)
  void _handleMarkerTap(Map<String, dynamic> properties) {
    /* ... wie in Schritt 12 ... */ _showFeatureDetails(context, properties);
  }

  void _showFeatureDetails(
      BuildContext context, Map<String, dynamic> properties) {
    /* ... wie in Schritt 12 ... */ final List<Widget> details = [];
    if (properties['name'] != null) {
      details.add(Text(properties['name'].toString(),
          style: Theme.of(context).textTheme.headlineSmall));
      details.add(const SizedBox(height: 8));
    }
    properties.forEach((key, value) {
      if (!key.startsWith('@') &&
          !key.startsWith('ref:') &&
          value != null &&
          value.toString().isNotEmpty &&
          key != 'name')
        details.add(ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title:
                Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(value.toString())));
    });
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
        builder: (builderContext) => ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: details.isEmpty
                              ? const Center(
                                  child: Text("Keine Details verfügbar."))
                              : ListView(shrinkWrap: true, children: details)),
                      const SizedBox(height: 10),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              child: const Text('Schliessen'),
                              onPressed: () => Navigator.pop(builderContext)))
                    ]))));
  }

  Color _getColorFromProperties(
      Map<String, dynamic> properties, Color defaultColor,
      {bool border = false}) {
    /* ... wie in Schritt 12 ... */ if (properties['amenity'] == 'parking')
      return border
          ? Colors.grey.shade600
          : Colors.grey.withAlpha((0.4 * 255).round());
    if (properties['building'] != null) {
      if (properties['building'] == 'construction')
        return border
            ? Colors.orangeAccent
            : Colors.orange.withAlpha((0.3 * 255).round());
      return border
          ? Colors.blueGrey
          : Colors.blueGrey.withAlpha((0.3 * 255).round());
    }
    if (properties['highway'] != null) {
      if (properties['highway'] == 'cycleway') return Colors.deepPurpleAccent;
      if (properties['highway'] == 'platform') return Colors.lightBlueAccent;
      if (properties['highway'] == 'footway') return Colors.lime.shade900;
      if (properties['highway'] == 'service') return Colors.grey.shade700;
      if (properties['highway'] == 'unclassified') return Colors.black87;
      if (properties['highway'] == 'tertiary') return Colors.black;
    }
    return defaultColor;
  }

  void _onSearchChanged() {
    /* ... wie in Schritt 12 ... */ String query =
        _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      if (_searchResults.isNotEmpty) setState(() => _searchResults = []);
      return;
    }
    List<SearchableFeature> filteredResults = _searchableFeatures
        .where((feature) => feature.name.toLowerCase().contains(query))
        .toList();
    setState(() => _searchResults = filteredResults);
  }

  AppBar _buildSearchAppBar() {
    /* ... wie in Schritt 12 ... */ final ThemeData theme = Theme.of(context);
    final Color foregroundColor =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final Color? hintColor = theme.hintColor;
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: foregroundColor),
        tooltip: 'Suche verlassen',
        onPressed: () => setState(() {
          _isSearching = false;
          _searchController.clear();
          _searchResults = [];
          _searchFocusNode.unfocus();
        }),
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Ort suchen...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: hintColor ?? Colors.black54),
        ),
        style: TextStyle(color: foregroundColor),
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
    /* ... wie in Schritt 12 ... */ return AppBar(
      title: const Text('Campground Navi'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Suche öffnen',
          onPressed: () {
            setState(() => _isSearching = true);
            Future.delayed(const Duration(milliseconds: 100),
                () => _searchFocusNode.requestFocus());
          },
        ),
      ],
    );
  }

  IconData _getIconForFeatureType(String type) {
    /* ... wie in Schritt 12 ... */ switch (type) {
      case 'Building':
        return Icons.business;
      case 'Parking':
        return Icons.local_parking;
      case 'Gate':
        return Icons.fence;
      case 'Bus Stop':
        return Icons.directions_bus;
      case 'Footway':
        return Icons.directions_walk;
      case 'Cycleway':
        return Icons.directions_bike;
      case 'Service Road':
        return Icons.minor_crash_outlined;
      case 'Platform':
        return Icons.train;
      case 'Tertiary Road':
        return Icons.traffic;
      case 'Unclassified Road':
        return Icons.edit_road;
      case 'Point of Interest':
        return Icons.place;
      default:
        return Icons.location_pin;
    }
  }

  void _clearRoute() {
    // Unverändert
    setState(() => _calculatedRoute = null);
    if (kDebugMode) print("Route cleared.");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Route gelöscht."),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2)));
  }

  // --- NEUE METHODE ZUM UMSCHALTEN DES MOCK-MODUS ---
  void _toggleMockLocation() {
    setState(() {
      _useMockLocation = !_useMockLocation;
    });
    if (kDebugMode) {
      print("Mock location usage toggled: $_useMockLocation");
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_useMockLocation
          ? "Startpunkt: Mock-Position (Sittard)"
          : "Startpunkt: Echter GPS-Standort"),
      duration: const Duration(seconds: 2),
      backgroundColor: _useMockLocation ? Colors.orange : Colors.blue,
    ));
  }
  // --- ENDE NEUE METHODE ---

  // Build-Methode JETZT MIT Mock-Toggle-Button
  @override
  Widget build(BuildContext context) {
    final bool isLoading = _locationLoading || _geoJsonLoading;
    final String? errorMessage = _locationError ?? _geoJsonError;

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Stack(
        children: [
          // Kartenanzeige (wie in Schritt 12)
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Fehler: $errorMessage',
                              textAlign: TextAlign.center)))
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(51.024370, 5.861582),
                        initialZoom: 17.0,
                        minZoom: 15.0,
                        maxZoom: 19.0,
                        onTap: (tapPosition, point) {
                          if (_isSearching) _searchFocusNode.unfocus();
                          if (kDebugMode)
                            print(
                                "Map tapped at: $point. Triggering route calculation.");
                          _calculateAndDisplayRoute(destination: point);
                        },
                      ),
                      children: [
                        TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.camping_osm_navi'),
                        PolygonLayer(polygons: _polygons),
                        PolylineLayer(polylines: _polylines),
                        if (_calculatedRoute != null &&
                            _calculatedRoute!.isNotEmpty)
                          PolylineLayer(polylines: [
                            Polyline(
                                points: _calculatedRoute!,
                                color: Colors.blueAccent.withOpacity(0.8),
                                strokeWidth: 5.0,
                                isDotted: false,
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round),
                          ]),
                        if (_calculatedRoute != null &&
                            _calculatedRoute!.isNotEmpty)
                          MarkerLayer(markers: [
                            Marker(
                                point: _calculatedRoute!.first,
                                width: 30,
                                height: 30,
                                child: const Icon(Icons.person_pin_circle,
                                    color: Colors.blue, size: 30)),
                            Marker(
                                point: _calculatedRoute!.last,
                                width: 30,
                                height: 30,
                                child: const Icon(Icons.flag,
                                    color: Colors.red, size: 30)),
                          ]),
                        MarkerLayer(markers: _poiMarkers),
                        if (_currentLatLng != null)
                          MarkerLayer(markers: [
                            Marker(
                                point: _currentLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_pin,
                                    color: Colors.redAccent, size: 40.0))
                          ]),
                      ],
                    ),

          // Suchergebnisliste (wie in Schritt 12)
          if (_isSearching && _searchResults.isNotEmpty)
            Positioned(
              top: 0,
              left: 10,
              right: 10,
              child: Card(
                  /* ... wie vorher ... */
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  child: Container(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final feature = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(_getIconForFeatureType(feature.type),
                                size: 20),
                            title: Text(feature.name),
                            subtitle: Text(feature.type),
                            onTap: () {
                              if (kDebugMode)
                                print(
                                    'Tapped on search result: ${feature.name}. Triggering route calculation.');
                              _mapController.move(feature.center, 18.0);
                              setState(() {
                                _isSearching = false;
                                _searchController.clear();
                                _searchResults = [];
                                _searchFocusNode.unfocus();
                              });
                              _calculateAndDisplayRoute(
                                  destination: feature.center);
                            },
                          );
                        }),
                  )),
            ),

          // --- UI ELEMENTE UNTEN ---
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              // Row, um Buttons nebeneinander zu platzieren
              mainAxisAlignment: MainAxisAlignment
                  .spaceBetween, // Buttons an die Enden schieben
              children: [
                // --- NEU: Mock Location Toggle Button ---
                FloatingActionButton(
                  onPressed: _toggleMockLocation,
                  tooltip: 'Toggle Mock Location',
                  backgroundColor: _useMockLocation
                      ? Colors.orangeAccent
                      : Colors.lightBlueAccent,
                  mini: true, // Kleiner Button
                  child: Icon(
                    _useMockLocation
                        ? Icons.location_off
                        : Icons.location_on, // Icon wechselt
                    color: Colors.white,
                  ),
                ),
                // --- Ende Mock Location Toggle Button ---

                // --- Bestehender Zentrierungsbutton ---
                // Wird nur angezeigt, wenn echter Standort vorhanden ist (macht Sinn)
                if (_currentLatLng != null)
                  FloatingActionButton(
                      onPressed: () {
                        if (_currentLatLng != null)
                          _mapController.move(_currentLatLng!, 17.0);
                      },
                      tooltip: 'Auf meine Position zentrieren',
                      child: const Icon(Icons.my_location)),
                // --- Ende Zentrierungsbutton ---
              ],
            ),
          ),

          // Ladeindikator (wie in Schritt 12)
          if (_isCalculatingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white))),
              ),
            ),

          // Löschen-Button (Position wie in Schritt 12)
          if (_calculatedRoute != null && _calculatedRoute!.isNotEmpty)
            Positioned(
              top: 80,
              right: 20,
              child: FloatingActionButton(
                onPressed: _clearRoute,
                tooltip: 'Route löschen',
                backgroundColor: Colors.redAccent,
                child: const Icon(Icons.close, color: Colors.white),
                mini: true,
              ),
            ),
        ],
      ),
    );
  }

  // Methode für Routenberechnung JETZT MIT Berücksichtigung von _useMockLocation
  Future<void> _calculateAndDisplayRoute({required LatLng destination}) async {
    if (!mounted) return;

    // --- Startpunkt bestimmen: Mock oder Real? ---
    LatLng?
        startLatLng; // Kann null sein, wenn realer Standort benötigt wird aber fehlt
    if (_useMockLocation) {
      startLatLng = mockStartPosition; // Immer die Mock-Position verwenden
    } else {
      startLatLng =
          _currentLatLng; // Versuche, den echten Standort zu verwenden
    }

    // --- Prüfen, ob der benötigte Startpunkt verfügbar ist ---
    if (startLatLng == null) {
      // Dies tritt nur auf, wenn _useMockLocation false ist UND _currentLatLng null ist
      if (kDebugMode)
        print("Echter GPS-Standort benötigt, aber nicht verfügbar.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Echter GPS-Standort nicht verfügbar."),
        backgroundColor: Colors.orange,
      ));
      return; // Abbruch, da kein Startpunkt vorhanden
    }

    // --- Prüfen, ob Routing-Daten geladen sind ---
    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      if (kDebugMode) print("Routing-Daten nicht geladen.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Routing-Daten nicht geladen."),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // --- Berechnung starten ---
    setState(() {
      _isCalculatingRoute = true;
      _calculatedRoute = null;
    });

    List<LatLng>? path;
    try {
      // Nächste Knoten für Start und Ziel finden
      // WICHTIG: startLatLng ist hier garantiert nicht null!
      final GraphNode? startNode = _routingGraph!.findNearestNode(startLatLng);
      final GraphNode? endNode = _routingGraph!.findNearestNode(destination);

      if (startNode == null || endNode == null) {
        throw Exception(
            "Start- oder Endpunkt konnte keinem Weg zugeordnet werden.");
      }
      if (startNode.id == endNode.id) {
        if (kDebugMode)
          print(
              "Start- und Zielpunkt sind identisch (oder nächster Knoten ist derselbe).");
        if (mounted) setState(() => _isCalculatingRoute = false);
        return;
      }

      // Angepasste Debug-Ausgabe
      if (kDebugMode) {
        final startType = _useMockLocation
            ? "Mock-Position $startLatLng"
            : "echter Position $_currentLatLng";
        print(
            ">>> Berechne Route von Knoten ${startNode.id} (ausgehend von $startType) zu Knoten ${endNode.id} (Ziel: $destination)");
      }

      // Dijkstra ausführen
      _routingGraph!.resetAllNodeCosts();
      path = await RoutingService.findPath(_routingGraph!, startNode, endNode);

      // Ergebnis verarbeiten (UI-Update)
      if (mounted) {
        setState(() =>
            _calculatedRoute = path); // Route setzen (kann auch null sein)

        // Feedback
        if (path == null || path.isEmpty) {
          if (kDebugMode) print("<<< Kein Pfad gefunden.");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Keine Route gefunden."),
              backgroundColor: Colors.orange));
        } else {
          if (kDebugMode) print("<<< Route berechnet (${path.length} Punkte).");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Route berechnet."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2)));
        }
      }
    } catch (e) {
      if (kDebugMode) print(">>> Fehler bei Routenberechnung: $e");
      if (mounted) {
        setState(() => _calculatedRoute = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Routenberechnung fehlgeschlagen: ${e.toString().split(':').last.trim()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      // Ladezustand beenden
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
      if (kDebugMode) print("<<< Routenberechnungsmethode beendet.");
    }
  }
} // Ende _MapScreenState
