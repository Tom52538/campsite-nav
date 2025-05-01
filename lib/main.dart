import 'dart:async';
import 'dart:convert'; // Für jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für rootBundle (Assets laden)
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // State für Standort
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionStreamSubscription;
  final MapController _mapController = MapController();
  bool _locationLoading = true;
  String? _locationError;

  // State für GeoJSON Daten
  List<Polygon> _polygons = [];
  List<Polyline> _polylines = [];
  List<Marker> _poiMarkers = []; // Liste für POI-Marker (Bus, Gate etc.)
  bool _geoJsonLoading = true;
  String? _geoJsonError;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadAndParseGeoJson();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Standortdienste sind deaktiviert.');
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString();
          _locationLoading = false;
        });
      }
    }
  }

  Future<void> _loadAndParseGeoJson() async {
    print("Versuche GeoJSON zu laden...");
    setState(() {
      _geoJsonLoading = true;
      _geoJsonError = null;
      _polygons = [];
      _polylines = [];
      _poiMarkers = [];
    });
    try {
      const String assetPath = 'assets/export.geojson'; // Bestätigter Dateiname
      print("Lade Asset: $assetPath");
      final String geoJsonString = await rootBundle.loadString(assetPath);
      print("GeoJSON String geladen...");
      final decodedJson = jsonDecode(geoJsonString);
      if (decodedJson is Map<String, dynamic>) {
        _parseGeoJsonFeatures(decodedJson);
      } else {
        throw Exception("GeoJSON-Struktur ungültig");
      }
    } catch (e) {
      print("Fehler beim Laden/Parsen: $e");
      if (mounted) {
        setState(() {
          _geoJsonError = "Lade-/Parse-Fehler: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _geoJsonLoading = false;
          print("GeoJSON Verarbeitung abgeschlossen");
        });
      }
    }
  }

  void _parseGeoJsonFeatures(Map<String, dynamic> geoJsonData) {
    print("Beginne Parsing...");
    final List<Polygon> polygons = [];
    final List<Polyline> polylines = [];
    final List<Marker> poiMarkers = [];

    if (geoJsonData['type'] == 'FeatureCollection' &&
        geoJsonData['features'] is List) {
      List features = geoJsonData['features'];
      print("Parsing ${features.length} Features...");
      for (var feature in features) {
        if (feature is Map<String, dynamic> &&
            feature['geometry'] is Map<String, dynamic>) {
          final geometry = feature['geometry'];
          // Wichtig: Properties kopieren für den Callback
          final properties = Map<String, dynamic>.from(
              feature['properties'] ?? <String, dynamic>{});
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];

          if (coordinates is List) {
            try {
              if (type == 'Polygon') {
                if (coordinates.isNotEmpty && coordinates[0] is List) {
                  final List<LatLng> points = (coordinates[0] as List)
                      .map((coord) =>
                          LatLng(coord[1].toDouble(), coord[0].toDouble()))
                      .toList();
                  if (points.isNotEmpty) {
                    polygons.add(Polygon(
                      points: points,
                      color: _getColorFromProperties(
                          properties, Colors.grey.withOpacity(0.2)),
                      borderColor: _getColorFromProperties(
                          properties, Colors.grey,
                          border: true),
                      borderStrokeWidth:
                          (properties['amenity'] == 'parking') ? 1.0 : 1.5,
                      isFilled: true,
                    ));
                  }
                }
              } else if (type == 'LineString') {
                final List<LatLng> points = coordinates
                    .map((coord) =>
                        LatLng(coord[1].toDouble(), coord[0].toDouble()))
                    .toList();
                if (points.length >= 2) {
                  polylines.add(Polyline(
                    points: points,
                    color: _getColorFromProperties(properties, Colors.black54),
                    strokeWidth: (properties['highway'] == 'footway' ||
                            properties['highway'] == 'cycleway' ||
                            properties['highway'] == 'platform')
                        ? 2.0
                        : 3.0,
                  ));
                }
              } else if (type == 'Point') {
                if (coordinates.length >= 2 &&
                    coordinates[0] is num &&
                    coordinates[1] is num) {
                  final lat = coordinates[1].toDouble();
                  final lon = coordinates[0].toDouble();
                  final pointLatLng = LatLng(lat, lon);
                  Icon? markerIcon; // Temporäre Variable für das Icon

                  if (properties['highway'] == 'bus_stop') {
                    markerIcon = const Icon(Icons.directions_bus,
                        color: Colors.indigo, size: 24.0);
                  } else if (properties['barrier'] == 'gate') {
                    markerIcon = Icon(Icons.fence,
                        color: Colors.brown.shade700, size: 20.0);
                  } // Füge hier ggf. weitere `else if` für andere Icons hinzu

                  if (markerIcon != null) {
                    // Erstelle das finale Widget mit GestureDetector
                    final markerWidget = GestureDetector(
                      onTap: () => _handleMarkerTap(
                          properties), // Ruft State-Methode auf
                      child: markerIcon, // Das eigentliche Icon
                    );
                    // Füge den Marker mit dem GestureDetector als Kind hinzu
                    poiMarkers.add(Marker(
                      point: pointLatLng,
                      width: 30.0,
                      height: 30.0,
                      child: markerWidget,
                    ));
                  }
                }
              }
            } catch (e) {
              print("Fehler beim Verarbeiten eines Features: $e");
            }
          }
        }
      }
    } else {
      throw Exception("GeoJSON ist keine gültige FeatureCollection");
    }

    print(
        "Parsing beendet: ${polygons.length} Polygone, ${polylines.length} Polylinien, ${poiMarkers.length} POI-Marker gefunden.");
    if (mounted) {
      setState(() {
        _polygons = polygons;
        _polylines = polylines;
        _poiMarkers = poiMarkers;
      });
    }
  }

  // Wird vom GestureDetector aufgerufen
  void _handleMarkerTap(Map<String, dynamic> properties) {
    _showFeatureDetails(context, properties);
  }

  // Zeigt das Bottom Sheet mit den Feature-Details an
  void _showFeatureDetails(
      BuildContext context, Map<String, dynamic> properties) {
    final List<Widget> details = [];
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
          key != 'name') {
        details.add(ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(value.toString()),
        ));
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
              maxHeight: MediaQuery.of(context).size.height * 0.5),
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
                          )),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    child: const Text('Schliessen'),
                    onPressed: () => Navigator.pop(builderContext),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getColorFromProperties(
      Map<String, dynamic> properties, Color defaultColor,
      {bool border = false}) {
    // Farb-Logik unverändert
    if (properties['amenity'] == 'parking') {
      return border ? Colors.grey.shade600 : Colors.grey.withOpacity(0.4);
    }
    if (properties['building'] != null) {
      if (properties['building'] == 'construction') {
        return border ? Colors.orangeAccent : Colors.orange.withOpacity(0.3);
      }
      return border ? Colors.blueGrey : Colors.blueGrey.withOpacity(0.3);
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

  @override
  Widget build(BuildContext context) {
    // Build-Logik unverändert
    final bool isLoading = _locationLoading || _geoJsonLoading;
    final String? errorMessage = _locationError ?? _geoJsonError;
    return Scaffold(
      appBar: AppBar(title: const Text('Campground Navi')),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Fehler: $errorMessage',
                            textAlign: TextAlign.center,
                          )))
                  : FlutterMap(
                      mapController: _mapController,
                      options: const MapOptions(
                        initialCenter: LatLng(51.024370, 5.861582),
                        initialZoom: 17.0,
                        minZoom: 12.0,
                        maxZoom: 19.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.camping_osm_navi',
                        ),
                        PolygonLayer(polygons: _polygons),
                        PolylineLayer(polylines: _polylines),
                        MarkerLayer(markers: _poiMarkers), // POI Marker
                        if (_currentLatLng != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_pin,
                                    color: Colors.redAccent, size: 40.0),
                              ),
                            ],
                          ), // User Marker
                      ],
                    ),
          // Zentrierungsbutton
          if (!isLoading && _currentLatLng != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  if (_currentLatLng != null) {
                    _mapController.move(_currentLatLng!, 17.0);
                  }
                },
                tooltip: 'Auf meine Position zentrieren',
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }
}
