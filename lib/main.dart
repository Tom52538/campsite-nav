// lib/main.dart (Code für Schritt 9)

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
    // HINWEIS: Der MaterialApp Teil wurde hier zur Kürze weggelassen,
    // er sollte aber dem aus deiner letzten main.dart entsprechen
    // oder einfach gehalten sein wie dieser hier:
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
  // States (inklusive _calculatedRoute, _isCalculatingRoute etc. aus Schritt 8 behalten)
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionStreamSubscription;
  final MapController _mapController = MapController();
  bool _locationLoading = true;
  String? _locationError;
  List<Polygon> _polygons = [];
  List<Polyline> _polylines = []; // Für Wege etc. aus GeoJSON
  List<Marker> _poiMarkers = [];
  bool _geoJsonLoading = true;
  String? _geoJsonError;
  List<SearchableFeature> _searchableFeatures = [];
  final TextEditingController _searchController = TextEditingController();
  List<SearchableFeature> _searchResults = [];
  bool _isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();
  RoutingGraph? _routingGraph;
  List<LatLng>? _calculatedRoute; // Hier wird die berechnete Route gespeichert
  bool _isCalculatingRoute = false; // Wird noch nicht verwendet in Schritt 9

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

  // --- Methoden (größtenteils unverändert zu deiner letzten Version/Schritt 8) ---
  // _initializeLocation, _loadAndParseGeoJson, _parseGeoJsonForDisplay,
  // _handleMarkerTap, _showFeatureDetails, _getColorFromProperties, _onSearchChanged,
  // _buildSearchAppBar, _buildNormalAppBar, _getIconForFeatureType
  // Kopiere diese Methoden aus deiner letzten funktionierenden main.dart hierher
  // oder übernehme sie aus dem Code in Dokument 2 , falls du unsicher bist.

  // Beispielhaft hier nur die Signaturen, damit nichts fehlt:
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
            // Unterscheidung Mock/Real erst in späteren Schritten relevant für Anzeige
            _currentLatLng = LatLng(position.latitude, position.longitude);
            _locationLoading = false;
            _locationError = null;
             if (kDebugMode) {
              print("Position Update: $_currentLatLng");
            }
         });
      }, onError: (error) {
        if (mounted)
          setState(() {
            _locationError = "Standortupdates fehlgeschlagen: $error";
            _locationLoading = false;
          });
      });
      // Initialen Standort holen (falls Stream nicht sofort liefert)
       try {
           Position initialPosition = await Geolocator.getCurrentPosition(
             desiredAccuracy: LocationAccuracy.high,
             timeLimit: const Duration(seconds: 5) // Timeout hinzufügen
           );
            if (mounted && _currentLatLng == null) { // Nur setzen, wenn Stream noch nichts geliefert hat
                 setState(() {
                    _currentLatLng = LatLng(initialPosition.latitude, initialPosition.longitude);
                     _locationLoading = false; // Standort gefunden
                     _locationError = null;
                      if (kDebugMode) {
                       print("Initial Position: $_currentLatLng");
                     }
                 });
            }
       } catch (e) {
           if (mounted && _currentLatLng == null) { // Nur Fehler setzen, wenn weder Stream noch Initial erfolgreich
               setState(() {
                   _locationError = "Initialer Standort fehlgeschlagen: $e";
                    _locationLoading = false; // Laden beendet, aber mit Fehler
                });
           }
            if (kDebugMode) {
             print("Error getting initial position: $e");
           }
       }


    } catch (e) {
      if (mounted)
        setState(() {
          _locationError = e.toString();
          _locationLoading = false;
        });
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
       _calculatedRoute = null; // Route auch zurücksetzen beim Neuladen
    });
    try {
      const String assetPath = 'assets/export.geojson';
      final String geoJsonString = await rootBundle.loadString(assetPath);
      final decodedJson = jsonDecode(geoJsonString);

      if (decodedJson is Map<String, dynamic>) {
         if (kDebugMode) print("GeoJSON dekodiert, starte Parsing...");
        _parseGeoJsonForDisplay(decodedJson); // Für Kartenanzeige
        _routingGraph = GeojsonParserService.parseGeoJson(geoJsonString); // Für Routing-Graph
        if (kDebugMode) {
          print( "Routing Graph nach dem Parsen: Nodes=${_routingGraph?.nodes.length ?? 0}, Edges=${_routingGraph?.totalEdges ?? 0}");
          // Optional: Mehr Debug-Infos zum Graphen
          // _routingGraph?.printGraphSummary();
        }
      } else {
        throw Exception("GeoJSON-Struktur ungültig");
      }
    } catch (e, stacktrace) {
      if (mounted) setState(() => _geoJsonError = "Lade-/Parse-Fehler: $e");
      if (kDebugMode) {
        print("Fehler beim Laden/Parsen der GeoJSON: $e");
        print(stacktrace);
      }
    } finally {
      if (mounted) {
        setState(() => _geoJsonLoading = false);
        if (kDebugMode) print("GeoJSON Verarbeitung abgeschlossen (Display & Routing). GeoJsonLoading: $_geoJsonLoading, Error: $_geoJsonError");
      }
    }
  }

  void _parseGeoJsonForDisplay(Map<String, dynamic> geoJsonData) {
     if (kDebugMode) print("Beginne Display-Parsing...");
    final List<Polygon> tempPolygons = [];
    final List<Polyline> tempPolylines = [];
    final List<Marker> tempPoiMarkers = [];
    final List<SearchableFeature> tempSearchableFeatures = [];

    if (geoJsonData['type'] == 'FeatureCollection' && geoJsonData['features'] is List) {
      List features = geoJsonData['features'];
      if (kDebugMode) print("Parsing ${features.length} Features für Display...");

      for (var feature in features) {
        if (feature is Map<String, dynamic> && feature['geometry'] is Map<String, dynamic>) {
          final geometry = feature['geometry'];
          final properties = Map<String, dynamic>.from(feature['properties'] ?? <String, dynamic>{});
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];
          final dynamic featureId = feature['id'] ?? properties['@id'] ?? DateTime.now().millisecondsSinceEpoch.toString(); // Sicherstellen, dass ID ein String ist

           // --- Durchsuchbare Features erstellen ---
           if (properties['name'] != null && properties['name'].isNotEmpty) {
             String featureName = properties['name'];
             String featureType = 'Unknown';
             LatLng? centerPoint;

              // Typzuweisung (kann verfeinert werden)
             if (properties['building'] != null) featureType = 'Building';
             else if (properties['amenity'] == 'parking') featureType = 'Parking';
             else if (properties['highway'] == 'footway') featureType = 'Footway';
             else if (properties['highway'] == 'service') featureType = 'Service Road';
             else if (properties['barrier'] == 'gate') featureType = 'Gate';
             else if (properties['amenity'] == 'bus_station' || properties['highway'] == 'bus_stop') featureType = 'Bus Stop';
             else if (properties['highway'] == 'cycleway') featureType = 'Cycleway';
             else if (properties['highway'] == 'platform') featureType = 'Platform';
             else if (properties['highway'] == 'tertiary') featureType = 'Tertiary Road';
             else if (properties['highway'] == 'unclassified') featureType = 'Unclassified Road';
             else if (type == 'Point') featureType = 'Point of Interest';


             // Mittelpunkt berechnen (vereinfacht)
             try {
               if (type == 'Point') {
                 if (coordinates is List && coordinates.length >= 2 && coordinates[0] is num && coordinates[1] is num) {
                   centerPoint = LatLng(coordinates[1].toDouble(), coordinates[0].toDouble());
                 }
               } else if (type == 'Polygon') {
                 // Vereinfachte Mittelpunktberechnung für Polygone
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
                 // Vereinfachte Mittelpunktberechnung für Linien
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
                   id: featureId.toString(), // ID als String
                   name: featureName,
                   type: featureType,
                   center: centerPoint
                 ));
             }
          }

          // --- Kartenlayer erstellen ---
          if (coordinates is List) {
            try {
              if (type == 'Polygon') {
                 if (coordinates.isNotEmpty && coordinates[0] is List) {
                   // Polygonpunkte extrahieren
                   final List<LatLng> points = (coordinates[0] as List).map((coord) {
                     // Fehlerprüfung für Koordinatenformat
                     if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
                       return LatLng(coord[1].toDouble(), coord[0].toDouble());
                     }
                     if (kDebugMode) print("Ungültiges Koordinatenformat in Polygon gefunden: $coord");
                     return null; // Ungültige Punkte überspringen
                   }).where((p) => p != null).cast<LatLng>().toList(); // Null-Werte entfernen

                    if (points.length >= 3) { // Ein Polygon braucht mind. 3 Punkte
                         tempPolygons.add(Polygon(
                             points: points,
                             color: _getColorFromProperties(properties, Colors.grey.withAlpha((0.2 * 255).round())),
                             borderColor: _getColorFromProperties(properties, Colors.grey, border: true),
                             borderStrokeWidth: (properties['amenity'] == 'parking') ? 1.0 : 1.5,
                             isFilled: true
                         ));
                     } else if (kDebugMode && points.isNotEmpty) {
                          print("Polygon Feature $featureId hat weniger als 3 gültige Punkte und wird ignoriert.");
                     }
                 }
              } else if (type == 'LineString') {
                 // Linienpunkte extrahieren
                   final List<LatLng> points = coordinates.map((coord) {
                     if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
                       return LatLng(coord[1].toDouble(), coord[0].toDouble());
                     }
                      if (kDebugMode) print("Ungültiges Koordinatenformat in LineString gefunden: $coord");
                      return null;
                   }).where((p) => p != null).cast<LatLng>().toList();

                  if (points.length >= 2) { // Eine Linie braucht mind. 2 Punkte
                     tempPolylines.add(Polyline(
                         points: points,
                         color: _getColorFromProperties(properties, Colors.black54),
                         strokeWidth: (properties['highway'] == 'footway' || properties['highway'] == 'cycleway' || properties['highway'] == 'platform') ? 2.0 : 3.0
                     ));
                 } else if (kDebugMode && points.isNotEmpty) {
                      print("LineString Feature $featureId hat weniger als 2 gültige Punkte und wird ignoriert.");
                 }
              } else if (type == 'Point') {
                 if (coordinates.length >= 2 && coordinates[0] is num && coordinates[1] is num) {
                     final pointLatLng = LatLng(coordinates[1].toDouble(), coordinates[0].toDouble());
                     Icon? markerIcon;
                     // POI-Marker hinzufügen (nur für bestimmte Typen)
                     if (properties['highway'] == 'bus_stop' || properties['amenity'] == 'bus_station') {
                         markerIcon = const Icon(Icons.directions_bus, color: Colors.indigo, size: 24.0);
                     } else if (properties['barrier'] == 'gate') {
                         markerIcon = Icon(Icons.fence, color: Colors.brown.shade700, size: 20.0);
                     }
                     // Hier könnten weitere POI-Typen hinzugefügt werden

                      if (markerIcon != null) {
                         // Klickbar machen und Details anzeigen
                         final markerWidget = GestureDetector(
                           onTap: () => _handleMarkerTap(properties),
                           child: markerIcon,
                         );
                         tempPoiMarkers.add(Marker(
                           point: pointLatLng,
                           width: 30.0, // Größe des anklickbaren Bereichs
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
      _geoJsonError = "GeoJSON ist keine gültige FeatureCollection."; // Fehler setzen
    }

    if (kDebugMode) print("Display-Parsing beendet: ${tempPolygons.length} Polygone, ${tempPolylines.length} Polylinien, ${tempPoiMarkers.length} POI-Marker, ${tempSearchableFeatures.length} durchsuchbare Features gefunden.");

     // Sicherstellen, dass setState nur aufgerufen wird, wenn das Widget noch gemountet ist
     if (mounted) {
         setState(() {
             _polygons = tempPolygons;
             _polylines = tempPolylines; // Wege etc.
             _poiMarkers = tempPoiMarkers;
             _searchableFeatures = tempSearchableFeatures;
          });
     } else if (kDebugMode) {
        print("ParseGeoJsonForDisplay: Widget nicht mehr gemountet, setState wird übersprungen.");
     }
  }

  void _handleMarkerTap(Map<String, dynamic> properties) {
     _showFeatureDetails(context, properties);
   }

  void _showFeatureDetails( BuildContext context, Map<String, dynamic> properties) {
     final List<Widget> details = [];
      // Titel hinzufügen, falls vorhanden
     if (properties['name'] != null) {
         details.add(Text(properties['name'].toString(), style: Theme.of(context).textTheme.headlineSmall));
         details.add(const SizedBox(height: 8));
     }
      // Andere relevante Tags hinzufügen
     properties.forEach((key, value) {
         // Filtern uninteressanter oder bereits angezeigter Tags
         if (!key.startsWith('@') && !key.startsWith('ref:') && value != null && value.toString().isNotEmpty && key != 'name') {
             details.add(ListTile(
                 dense: true,
                 visualDensity: VisualDensity.compact,
                 title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                 subtitle: Text(value.toString())
             ));
         }
     });

     showModalBottomSheet(
         context: context,
         isScrollControlled: true, // Wichtig für variable Höhe
         shape: const RoundedRectangleBorder(
             borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))
         ),
         builder: (builderContext) => ConstrainedBox(
             constraints: BoxConstraints(
                 maxHeight: MediaQuery.of(context).size.height * 0.6 // Maximal 60% der Bildschirmhöhe
             ),
             child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                     mainAxisSize: MainAxisSize.min, // Nimmt nur benötigte Höhe
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                         Expanded( // Lässt die Liste scrollen, wenn sie zu lang wird
                             child: details.isEmpty
                                 ? const Center(child: Text("Keine Details verfügbar."))
                                 : ListView(
                                     shrinkWrap: true, // Passt sich dem Inhalt an
                                     children: details
                                 )
                         ),
                         const SizedBox(height: 10),
                         Align(
                             alignment: Alignment.centerRight,
                             child: TextButton(
                                 child: const Text('Schliessen'),
                                 onPressed: () => Navigator.pop(builderContext)
                             )
                         )
                     ]
                 )
             )
         )
     );
   }

  Color _getColorFromProperties( Map<String, dynamic> properties, Color defaultColor, {bool border = false}) {
     // Farben basierend auf OSM Tags anpassen
      if (properties['amenity'] == 'parking') {
         return border ? Colors.grey.shade600 : Colors.grey.withAlpha((0.4 * 255).round());
     }
     if (properties['building'] != null) {
         // Unterscheidung nach Gebäudeart (optional)
         if (properties['building'] == 'warehouse') {
              return border ? Colors.brown.shade700 : Colors.brown.withAlpha((0.3 * 255).round());
         }
         if (properties['building'] == 'construction') {
             return border ? Colors.orangeAccent : Colors.orange.withAlpha((0.3 * 255).round());
         }
         // Standardgebäude
         return border ? Colors.blueGrey : Colors.blueGrey.withAlpha((0.3 * 255).round());
     }
     if (properties['highway'] != null) {
         switch (properties['highway']) {
             case 'footway':
             case 'path':
             case 'steps':
                 return Colors.lime.shade900; // Grünlich für Fußwege
             case 'cycleway':
                 return Colors.deepPurpleAccent; // Lila für Radwege
             case 'service':
                 return Colors.grey.shade700; // Dunkelgrau für Service-Wege
             case 'platform':
                 return Colors.lightBlueAccent; // Hellblau für Plattformen
             case 'tertiary':
             case 'unclassified':
             case 'residential': // ggf. auch Straßen einzeichnen
                 return Colors.black87; // Schwarz/Dunkelgrau für Straßen
             default:
                 return defaultColor; // Fallback für andere highway-Typen
         }
     }
     // Weitere Typen hier hinzufügen (z.B. landuse, natural, etc.)
      if (properties['landuse'] == 'grass') {
          return border ? Colors.green.shade800 : Colors.green.withAlpha((0.2 * 255).round());
     }
      if (properties['natural'] == 'water') {
         return border ? Colors.blue.shade800 : Colors.blue.withAlpha((0.4 * 255).round());
     }

      return defaultColor; // Standardfarbe, wenn kein passendes Tag gefunden wurde
   }

  void _onSearchChanged() {
     String query = _searchController.text.toLowerCase().trim();
     if (query.isEmpty) {
       if (_searchResults.isNotEmpty) {
         setState(() => _searchResults = []);
       }
       return;
     }
     // Filtern der Features basierend auf der Suchanfrage
     List<SearchableFeature> filteredResults = _searchableFeatures
         .where((feature) => feature.name.toLowerCase().contains(query))
         .toList();
     // Optional: Nach Relevanz sortieren (z.B. exakte Treffer zuerst)
     // filteredResults.sort((a, b) => a.name.toLowerCase().startsWith(query) ? -1 : 1);

      setState(() => _searchResults = filteredResults);
   }

  AppBar _buildSearchAppBar() {
     final ThemeData theme = Theme.of(context);
     final Color foregroundColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
     final Color? hintColor = theme.hintColor.withOpacity(0.6); // Etwas transparenter

      return AppBar(
       leading: IconButton(
         icon: Icon(Icons.arrow_back, color: foregroundColor),
         tooltip: 'Suche verlassen',
         onPressed: () => setState(() {
           _isSearching = false;
           _searchController.clear(); // Löscht Text und damit Ergebnisse
           _searchFocusNode.unfocus(); // Schließt Tastatur
         }),
       ),
       title: TextField(
         controller: _searchController,
         focusNode: _searchFocusNode,
         autofocus: true,
         decoration: InputDecoration(
           hintText: 'Ort suchen...',
           border: InputBorder.none, // Kein Rand innerhalb der AppBar
           hintStyle: TextStyle(color: hintColor),
         ),
         style: TextStyle(color: foregroundColor, fontSize: 18), // Passende Textfarbe und Größe
         cursorColor: foregroundColor,
       ),
       actions: [
         // "Löschen"-Button nur anzeigen, wenn Text im Feld ist
         if (_searchController.text.isNotEmpty)
           IconButton(
             icon: Icon(Icons.clear, color: foregroundColor),
             tooltip: 'Suche löschen',
             onPressed: () => _searchController.clear(), // Controller leeren -> löst _onSearchChanged aus
           ),
       ],
     );
   }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('Campground Navi'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Suche öffnen',
          onPressed: () {
            setState(() => _isSearching = true);
             // Fokus auf Suchfeld setzen, nachdem es aufgebaut wurde
            Future.delayed(const Duration(milliseconds: 100), () {
                 if (mounted) { // Sicherstellen, dass das Widget noch existiert
                     FocusScope.of(context).requestFocus(_searchFocusNode);
                 }
            });
          },
        ),
      ],
    );
  }

  IconData _getIconForFeatureType(String type) {
    // Icons für verschiedene Feature-Typen zurückgeben
    switch (type) {
        case 'Building': return Icons.business;
        case 'Parking': return Icons.local_parking;
        case 'Gate': return Icons.fence;
        case 'Bus Stop': return Icons.directions_bus;
        case 'Footway': return Icons.directions_walk;
        case 'Cycleway': return Icons.directions_bike;
        case 'Service Road': return Icons.minor_crash_outlined; // Oder anderes passendes Icon
        case 'Platform': return Icons.train;
        case 'Tertiary Road': return Icons.traffic;
        case 'Unclassified Road': return Icons.edit_road;
        case 'Point of Interest': return Icons.place; // Generisches POI Icon
        default: return Icons.location_pin; // Fallback
     }
   }

  // --- Build Methode ---
  @override
  Widget build(BuildContext context) {
    final bool isLoading = _locationLoading || _geoJsonLoading;
    final String? errorMessage = _locationError ?? _geoJsonError;

    // Verwende den Mock-Standort für die initiale Kartenansicht, wenn aktiv
    // Oder den echten Standort, falls verfügbar, sonst einen Fallback
    final LatLng initialMapCenter = const LatLng(51.024370, 5.861582); // Collé Sittard

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Stack(
        children: [
          // Kartenanzeige
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Fehler: $errorMessage', textAlign: TextAlign.center)))
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialMapCenter, // Dynamisch oder statisch setzen
                        initialZoom: 17.0,
                        minZoom: 15.0, // Verhindert zu weites Rauszoomen
                        maxZoom: 19.0, // Verhindert zu starkes Reinzoomen
                        // onTap löst Routenberechnung aus
                        onTap: (tapPosition, point) {
                          if (_isSearching) { // Suche schließen bei Kartentap
                            setState(() {
                                _isSearching = false;
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                            });
                          }
                          if (kDebugMode) print("Map tapped at: $point. Triggering route calculation.");
                          _calculateAndDisplayRoute(destination: point);
                        },
                      ),
                      children: [
                        // Basiskarte (OpenStreetMap Kacheln)
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.camping_osm_navi',
                          // Optional: Ladeindikator für Kacheln
                          // tileBuilder: (context, tileWidget, tile) {
                          //   if (tile.loading) {
                          //     return Center(child: CircularProgressIndicator());
                          //   }
                          //   return tileWidget;
                          // },
                        ),

                        // Layer für Polygone (Gebäude, Parkplätze etc.)
                         if (_polygons.isNotEmpty) PolygonLayer(polygons: _polygons),

                        // Layer für Polylinien (Wege, Straßen etc. aus GeoJSON)
                        if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),

                        // --- NEU: Layer für die berechnete Route ---
                        if (_calculatedRoute != null && _calculatedRoute!.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _calculatedRoute!,
                                color: Colors.blueAccent.withOpacity(0.8), // Leicht transparent
                                strokeWidth: 5.0,      // Dicke Linie
                                isDotted: false,        // Durchgezogene Linie
                                strokeCap: StrokeCap.round, // Runde Enden
                                strokeJoin: StrokeJoin.round, // Runde Verbindungen
                              ),
                            ],
                          ),
                        // --- Ende Neuer Layer ---

                         // Layer für POI Marker (Bushaltestellen etc.)
                         if (_poiMarkers.isNotEmpty) MarkerLayer(markers: _poiMarkers),

                        // Layer für die aktuelle Nutzerposition
                         if (_currentLatLng != null)
                           MarkerLayer(markers: [
                             Marker(
                               point: _currentLatLng!,
                               width: 40, // Größe des Markers
                               height: 40,
                               child: const Icon(Icons.location_pin, color: Colors.redAccent, size: 40.0)
                               // Optional: Richtungsanzeiger (Kompass)
                               // rotate: true, // Marker mit Karte drehen
                               // child: Transform.rotate(
                               //   angle: _currentHeading ?? 0.0, // Benötigt Kompassdaten
                               //   child: Icon(Icons.navigation, color: Colors.blue, size: 30.0),
                               // ),
                             )
                           ]),

                         // Optional: Start-/Endpunkte der Route hervorheben
                         if (_calculatedRoute != null && _calculatedRoute!.isNotEmpty)
                             MarkerLayer(markers: [
                                 Marker( // Startpunkt
                                     point: _calculatedRoute!.first, width: 30, height: 30,
                                     child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30), ),
                                 Marker( // Endpunkt
                                     point: _calculatedRoute!.last, width: 30, height: 30,
                                     child: const Icon(Icons.flag, color: Colors.red, size: 30), )
                             ]),
                      ],
                    ),

          // Suchergebnisliste (über der Karte)
           if (_isSearching && _searchResults.isNotEmpty)
             Positioned(
               top: 0, // Direkt unter der AppBar
               left: 10,
               right: 10,
               child: Card(
                 elevation: 4.0,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                 child: Container(
                   // Begrenzte Höhe, um nicht die ganze Karte zu verdecken
                   constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                   child: ListView.builder(
                     shrinkWrap: true, // Passt sich der Anzahl der Ergebnisse an
                     itemCount: _searchResults.length,
                     itemBuilder: (context, index) {
                       final feature = _searchResults[index];
                       return ListTile(
                         dense: true, // Kompakteres Layout
                         leading: Icon(_getIconForFeatureType(feature.type), size: 20),
                         title: Text(feature.name),
                         subtitle: Text(feature.type),
                         onTap: () {
                            if (kDebugMode) {
                                print('Tapped on search result: ${feature.name}. Triggering route calculation.');
                            }
                            // Karte auf Feature zentrieren
                            _mapController.move(feature.center, 18.0); // Zoom-Stufe anpassen
                            // Suche schließen und Route berechnen
                            setState(() {
                               _isSearching = false;
                               _searchController.clear();
                               // _searchResults = []; // Nicht löschen, damit Liste verschwindet
                               _searchFocusNode.unfocus();
                            });
                            _calculateAndDisplayRoute(destination: feature.center);
                         },
                       );
                     },
                   ),
                 ),
               ),
             ),

          // Floating Action Button zum Zentrieren (unten rechts)
          if (_currentLatLng != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  if (_currentLatLng != null) {
                     _mapController.move(_currentLatLng!, 17.0); // Auf aktuelle Position zoomen
                  }
                },
                tooltip: 'Auf meine Position zentrieren',
                child: const Icon(Icons.my_location)
             ),
            ),

          // HIER kommen die Buttons für Ladeindikator (Schritt 10) und Route löschen (Schritt 11) hin
          // Beispiel Ladeindikator (Platzhalter, wird in Schritt 10 implementiert)
          // if (_isCalculatingRoute)
          //   Positioned.fill(
          //     child: Container(
          //       color: Colors.black.withOpacity(0.3),
          //       child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
          //     ),
          //   ),

          // Beispiel Löschen-Button (Platzhalter, wird in Schritt 11 implementiert)
          // if (_calculatedRoute != null && _calculatedRoute!.isNotEmpty)
          // Positioned(
          //   top: 80, // Oder andere Position
          //   right: 20,
          //   child: FloatingActionButton(
          //     onPressed: () { /* Logik zum Löschen der Route */ },
          //     tooltip: 'Route löschen',
          //     backgroundColor: Colors.redAccent,
          //     mini: true,
          //     child: Icon(Icons.close, color: Colors.white),
          //   ),
          // ),


        ],
      ),
    );
  }


  // --- Methode für Routenberechnung (aus Schritt 8 übernommen) ---
  Future<void> _calculateAndDisplayRoute({required LatLng destination}) async {
    if (!mounted) return; // Prüfen, ob das Widget noch im Baum ist

     // Verwende den aktuellen Standort oder den Mock-Standort basierend auf _useMockLocation
     // HINWEIS: Die _useMockLocation Logik wird erst in einem späteren Schritt hinzugefügt.
     //          Hier verwenden wir vorerst immer _currentLatLng.
     final LatLng? startLatLng = _currentLatLng; // Wird später dynamisch

     if (startLatLng == null) {
       if (kDebugMode) print("Aktueller Standort nicht verfügbar.");
       if (mounted) { // Prüfen vor dem Anzeigen der SnackBar
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

    // Ladezustand anzeigen (wird in Schritt 10 implementiert)
    // setState(() => _isCalculatingRoute = true);
    // Bestehende Route löschen, bevor neue berechnet wird
    setState(() => _calculatedRoute = null);


    List<LatLng>? path;
    try {
        // Nächste Knoten zu Start- und Zielpunkt finden
        final GraphNode? startNode = _routingGraph!.findNearestNode(startLatLng);
        final GraphNode? endNode = _routingGraph!.findNearestNode(destination);

         if (startNode == null || endNode == null) {
             throw Exception("Start- oder Endpunkt konnte keinem Weg zugeordnet werden.");
         }

         if (startNode.id == endNode.id) {
             if (kDebugMode) print("Start- und Zielpunkt sind identisch (oder nächster Knoten ist derselbe).");
             // Optional: Kurze Meldung an den User
              if (mounted) {
                 // Ladezustand beenden (wird in Schritt 10 implementiert)
                 // setState(() => _isCalculatingRoute = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                     content: Text("Start und Ziel sind zu nah beieinander."),
                     duration: Duration(seconds: 2),
                 ));
             }
             return; // Keine Route nötig
         }

        if (kDebugMode) {
           print(">>> Berechne Route von Knoten ${startNode.id} (Start: $startLatLng) zu ${endNode.id} (Ziel: $destination)");
        }

         // Kosten zurücksetzen (wichtig für Dijkstra)
        _routingGraph!.resetAllNodeCosts();

         // Pfad mit Dijkstra finden
         // Hinweis: findPath ist jetzt eine asynchrone Methode!
        path = await RoutingService.findPath(_routingGraph!, startNode, endNode);

        if (mounted) { // Erneut prüfen nach async Operation
            setState(() => _calculatedRoute = path); // Ergebnis im State speichern (auch wenn null)

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
                   duration: Duration(seconds: 2) // Kürzere Anzeige bei Erfolg
                 ));
                 // Optional: Auf die Route zoomen/zentrieren
                 // _mapController.fitBounds(LatLngBounds.fromPoints(path));
             }
        }

    } catch (e, stacktrace) {
        if (kDebugMode) {
            print(">>> Fehler bei Routenberechnung: $e");
            print(stacktrace);
        }
        if (mounted) { // Prüfen vor setState und SnackBar
             setState(() => _calculatedRoute = null); // Sicherstellen, dass keine alte Route angezeigt wird
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                // Fehlermeldung verständlicher machen
                content: Text("Routenberechnung fehlgeschlagen: ${e.toString().replaceFirst("Exception: ", "")}"),
                backgroundColor: Colors.red,
            ));
        }
    } finally {
        if (mounted) {
             // Ladezustand beenden (wird in Schritt 10 implementiert)
             // setState(() => _isCalculatingRoute = false);
             if (kDebugMode) print("<<< Routenberechnungsmethode beendet.");
        }
    }
  }

} // Ende _MapScreenState