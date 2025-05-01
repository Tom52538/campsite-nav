// lib/main.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:camping_osm_navi/models/searchable_feature.dart'; // Korrekter Import

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
      debugShowCheckedModeBanner: false, // Entfernt das Debug-Banner
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- State für Standort ---
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionStreamSubscription;
  final MapController _mapController = MapController();
  bool _locationLoading = true;
  String? _locationError;

  // --- State für GeoJSON Daten ---
  List<Polygon> _polygons = [];
  List<Polyline> _polylines = [];
  List<Marker> _poiMarkers = [];
  bool _geoJsonLoading = true;
  String? _geoJsonError;
  List<SearchableFeature> _searchableFeatures = [];

  // --- NEU: State für die Suche ---
  final TextEditingController _searchController =
      TextEditingController(); // Controller für das Suchfeld
  List<SearchableFeature> _searchResults =
      []; // Liste der aktuellen Suchergebnisse
  bool _isSearching = false; // Zustand, ob die Such-AppBar aktiv ist
  final FocusNode _searchFocusNode = FocusNode(); // Um den Fokus zu steuern

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadAndParseGeoJson();

    // NEU: Listener für das Suchfeld hinzufügen
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _searchController
        .removeListener(_onSearchChanged); // NEU: Listener entfernen
    _searchController.dispose(); // NEU: Controller freigeben
    _searchFocusNode.dispose(); // NEU: FocusNode freigeben
    _mapController.dispose(); // MapController auch freigeben
    super.dispose();
  }

  // --- Standort-Logik (unverändert) ---
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

  // --- GeoJSON Lade- und Parse-Logik (unverändert) ---
  Future<void> _loadAndParseGeoJson() async {
    print("Versuche GeoJSON zu laden...");
    setState(() {
      _geoJsonLoading = true;
      _geoJsonError = null;
      _polygons = [];
      _polylines = [];
      _poiMarkers = [];
      _searchableFeatures = [];
    });
    try {
      const String assetPath = 'assets/export.geojson';
      final String geoJsonString = await rootBundle.loadString(assetPath);
      final decodedJson = jsonDecode(geoJsonString);
      if (decodedJson is Map<String, dynamic>) {
        _parseGeoJsonFeatures(decodedJson);
      } else {
        throw Exception("GeoJSON-Struktur ungültig");
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _geoJsonError = "Lade-/Parse-Fehler: $e";
        });
    } finally {
      if (mounted)
        setState(() {
          _geoJsonLoading = false;
          print("GeoJSON Verarbeitung abgeschlossen");
        });
    }
  }

  void _parseGeoJsonFeatures(Map<String, dynamic> geoJsonData) {
    print("Beginne Parsing...");
    final List<Polygon> tempPolygons = [];
    final List<Polyline> tempPolylines = [];
    final List<Marker> tempPoiMarkers = [];
    final List<SearchableFeature> tempSearchableFeatures = [];
    if (geoJsonData['type'] == 'FeatureCollection' &&
        geoJsonData['features'] is List) {
      List features = geoJsonData['features'];
      print("Parsing ${features.length} Features...");
      for (var feature in features) {
        if (feature is Map<String, dynamic> &&
            feature['geometry'] is Map<String, dynamic>) {
          final geometry = feature['geometry'];
          final properties = Map<String, dynamic>.from(
              feature['properties'] ?? <String, dynamic>{});
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];
          // --- Suchfunktion-Teil ---
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
                    for (final point in polygonPoints) {
                      if (point is List &&
                          point.length >= 2 &&
                          point[0] is num &&
                          point[1] is num) {
                        totalLng += point[0].toDouble();
                        totalLat += point[1].toDouble();
                        pointCount++;
                      }
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
                  for (final point in coordinates) {
                    if (point is List &&
                        point.length >= 2 &&
                        point[0] is num &&
                        point[1] is num) {
                      totalLng += point[0].toDouble();
                      totalLat += point[1].toDouble();
                      pointCount++;
                    }
                  }
                  if (pointCount > 0)
                    centerPoint =
                        LatLng(totalLat / pointCount, totalLng / pointCount);
                }
              }
            } catch (e) {
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
          // --- Kartenlayer-Teil ---
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
                        color: _getColorFromProperties(
                            properties, Colors.grey.withOpacity(0.2)),
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
              print(
                  "Fehler beim Verarbeiten eines Karten-Layers für Feature: $e");
            }
          }
        }
      }
    } else {
      throw Exception("GeoJSON ist keine gültige FeatureCollection");
    }
    print(
        "Parsing beendet: ${tempPolygons.length} Polygone, ${tempPolylines.length} Polylinien, ${tempPoiMarkers.length} POI-Marker, ${tempSearchableFeatures.length} durchsuchbare Features gefunden.");
    if (mounted)
      setState(() {
        _polygons = tempPolygons;
        _polylines = tempPolylines;
        _poiMarkers = tempPoiMarkers;
        _searchableFeatures = tempSearchableFeatures;
      });
  }

  // --- Marker Tap & Details Sheet (unverändert) ---
  void _handleMarkerTap(Map<String, dynamic> properties) {
    _showFeatureDetails(context, properties);
  }

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
                                ? const Center(
                                    child: Text("Keine Details verfügbar."))
                                : ListView(
                                    shrinkWrap: true, children: details)),
                        const SizedBox(height: 10),
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                child: const Text('Schliessen'),
                                onPressed: () => Navigator.pop(builderContext)))
                      ])));
        });
  }

  // --- Farb-Logik (unverändert) ---
  Color _getColorFromProperties(
      Map<String, dynamic> properties, Color defaultColor,
      {bool border = false}) {
    if (properties['amenity'] == 'parking')
      return border ? Colors.grey.shade600 : Colors.grey.withOpacity(0.4);
    if (properties['building'] != null) {
      if (properties['building'] == 'construction')
        return border ? Colors.orangeAccent : Colors.orange.withOpacity(0.3);
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

  // --- NEU: Suchlogik (Platzhalter, wird in Schritt 3 implementiert) ---
  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      if (_searchResults.isNotEmpty) {
        setState(() {
          _searchResults = []; // Leere Ergebnisse, wenn Suche leer ist
        });
      }
      return;
    }

    // Hier kommt die eigentliche Filterlogik in Schritt 3
    // Vorerst: Dummy-Implementierung zum Testen der UI
    List<SearchableFeature> filteredResults =
        _searchableFeatures.where((feature) {
      return feature.name.toLowerCase().contains(query);
    }).toList();

    setState(() {
      _searchResults = filteredResults;
    });
  }

  // --- NEU: Such-AppBar bauen ---
  AppBar _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Suche verlassen',
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear(); // Suchtext löschen
            _searchResults = []; // Ergebnisse löschen
            _searchFocusNode.unfocus(); // Tastatur ausblenden
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode, // Fokus zuweisen
        autofocus: true, // Fokus direkt auf das Feld setzen
        decoration: const InputDecoration(
          hintText: 'Ort suchen...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white70),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 18.0),
        cursorColor: Colors.white,
      ),
      actions: [
        // Button zum Löschen des Suchtextes
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Suche löschen',
            onPressed: () {
              _searchController.clear();
              // _onSearchChanged wird durch den Listener automatisch aufgerufen
            },
          ),
      ],
    );
  }

  // --- NEU: Normale AppBar bauen ---
  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('Campground Navi'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Suche öffnen',
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
            // Kleiner Delay, damit das Feld sichtbar ist, bevor der Fokus gesetzt wird
            Future.delayed(const Duration(milliseconds: 100), () {
              _searchFocusNode.requestFocus();
            });
          },
        ),
      ],
    );
  }

  // --- MODIFIZIERT: Build-Methode ---
  @override
  Widget build(BuildContext context) {
    final bool isLoading = _locationLoading || _geoJsonLoading;
    final String? errorMessage = _locationError ?? _geoJsonError;

    return Scaffold(
      // MODIFIZIERT: Wählt die AppBar basierend auf _isSearching
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Stack(
        children: [
          // --- Kartenanzeige ---
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
                        minZoom: 12.0,
                        maxZoom: 19.0,
                        // NEU: Bei Tap auf die Karte die Suche beenden/Tastatur ausblenden
                        onTap: (tapPosition, point) {
                          if (_isSearching) {
                            _searchFocusNode
                                .unfocus(); // Fokus wegnehmen blendet Tastatur aus
                            // Optional: Suche komplett beenden
                            // setState(() { _isSearching = false; _searchController.clear(); _searchResults = []; });
                          }
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

          // --- NEU: Suchergebnisliste ---
          // Wird nur angezeigt, wenn gesucht wird UND Ergebnisse vorhanden sind
          if (_isSearching && _searchResults.isNotEmpty)
            Positioned(
              top: 0, // Direkt unter der AppBar
              left: 10,
              right: 10,
              child: Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: Container(
                  // Begrenzt die Höhe der Ergebnisliste
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap:
                        true, // Passt die Höhe an den Inhalt an (bis maxHeight)
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final feature = _searchResults[index];
                      return ListTile(
                        dense: true, // Kompakteres Layout
                        leading: Icon(_getIconForFeatureType(feature.type),
                            size: 20), // Icon basierend auf Typ
                        title: Text(feature.name),
                        subtitle:
                            Text(feature.type), // Zeigt den Typ unter dem Namen
                        onTap: () {
                          // --- Aktion bei Klick auf Ergebnis (wird in Schritt 5 implementiert) ---
                          print('Tapped on: ${feature.name}');
                          _mapController.move(feature.center,
                              18.0); // Zentriere Karte (Zoom 18)

                          // Suche beenden und Tastatur ausblenden
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

          // --- Zentrierungsbutton (unverändert) ---
          if (!isLoading && _currentLatLng != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  if (_currentLatLng != null)
                    _mapController.move(_currentLatLng!, 17.0);
                },
                tooltip: 'Auf meine Position zentrieren',
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }

  // --- NEU: Hilfsfunktion für Icons in Suchergebnissen ---
  IconData _getIconForFeatureType(String type) {
    switch (type) {
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
        return Icons.minor_crash_outlined; // Beispiel
      case 'Platform':
        return Icons.train; // Beispiel
      case 'Tertiary Road':
        return Icons.traffic; // Beispiel
      case 'Unclassified Road':
        return Icons.edit_road; // Beispiel
      case 'Point of Interest':
        return Icons.place;
      default:
        return Icons.location_pin; // Standard-Icon
    }
  }
}
