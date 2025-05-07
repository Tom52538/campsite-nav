// [Start lib/main.dart Überarbeitet für Fehlerbehebung]
import 'dart:async';
import 'dart:convert'; // Für jsonDecode
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
import 'package:camping_osm_navi/models/graph_node.dart'; // Import für GraphNode hinzugefügt/aktiviert
import 'package:camping_osm_navi/services/geojson_parser_service.dart';
import 'package:camping_osm_navi/services/routing_service.dart';

void main() {
  // Stelle sicher, dass Flutter Widgets initialisiert sind, bevor auf rootBundle zugegriffen wird (wichtig für manche Plattformen/Szenarien)
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campground Nav App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange), // Geändert zu deepOrange
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          // Globale AppBarTheme für Konsistenz
          backgroundColor: Colors.deepOrange.shade700,
          foregroundColor: Colors.white,
          elevation: 4.0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          // Globale FAB Theme
          backgroundColor: Colors.deepOrangeAccent,
          foregroundColor: Colors.white,
        ),
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
  LatLng? _startLatLng;
  LatLng? _endLatLng;
  bool _isCalculatingRoute = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchableFeature> _searchResults = [];
  bool _showSearchResults = false;
  SearchableFeature? _selectedSearchFeatureForStart;
  SearchableFeature? _selectedSearchFeatureForEnd;

  bool _isDataReady = false;

  static const LatLng defaultInitialCenter =
      LatLng(51.0245, 5.8630); // Beispiel-Koordinaten Campingplatz
  static const double markerWidth =
      40.0; // Kleinere Marker für bessere Übersicht
  static const double markerHeight = 40.0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print("<<< initState: MapScreen wird initialisiert. >>>");
    }
    _loadData(); // Daten laden
    _initializeGps(); // GPS initialisieren
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print("<<< dispose: MapScreen wird zerstört. >>>");
    }
    _mapController.dispose();
    _positionStreamSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<SearchableFeature> _extractSearchableFeaturesFromGeoJson(
      String geoJsonString) {
    final List<SearchableFeature> features = [];
    final dynamic decodedJson = jsonDecode(geoJsonString);

    if (kDebugMode) {
      print(
          "<<< _extractSearchableFeaturesFromGeoJson: Starte Extraktion... >>>");
    }

    if (decodedJson is Map<String, dynamic> &&
        decodedJson['type'] == 'FeatureCollection' &&
        decodedJson['features'] is List) {
      int featureCount = 0;
      for (final featureJson in decodedJson['features'] as List) {
        featureCount++;
        if (featureJson is Map<String, dynamic>) {
          final properties = featureJson['properties'] as Map<String, dynamic>?;
          final geometry = featureJson['geometry'] as Map<String, dynamic>?;

          if (properties != null && geometry != null) {
            final dynamic id = featureJson['id'] ??
                properties['@id'] ??
                'feature_${DateTime.now().millisecondsSinceEpoch}_$featureCount';
            final String? name = properties['name'] as String?;
            String type = properties['highway'] as String? ??
                properties['amenity'] as String? ??
                properties['shop'] as String? ??
                properties['building'] as String? ??
                properties['tourism'] as String? ?? // Zusätzlicher Typ
                'unknown';

            if (name != null && name.isNotEmpty) {
              LatLng? center;
              final String? geomType = geometry['type'] as String?;
              final dynamic coordsRaw = geometry['coordinates'];

              try {
                // Fehlerbehandlung für Koordinaten-Parsing
                if (geomType == 'Point' &&
                    coordsRaw is List &&
                    coordsRaw.length >= 2 &&
                    coordsRaw[0] is num &&
                    coordsRaw[1] is num) {
                  center = LatLng((coordsRaw[1] as num).toDouble(),
                      (coordsRaw[0] as num).toDouble());
                } else if (geomType == 'LineString' &&
                    coordsRaw is List &&
                    coordsRaw.isNotEmpty) {
                  // Mittelpunkt einer LineString (vereinfacht: erster Punkt)
                  if (coordsRaw.first is List) {
                    final firstPointList = coordsRaw.first as List;
                    if (firstPointList.length >= 2 &&
                        firstPointList[0] is num &&
                        firstPointList[1] is num) {
                      center = LatLng((firstPointList[1] as num).toDouble(),
                          (firstPointList[0] as num).toDouble());
                    }
                  }
                } else if (geomType == 'Polygon' &&
                    coordsRaw is List &&
                    coordsRaw.isNotEmpty) {
                  // Mittelpunkt eines Polygons (vereinfacht: erster Punkt des ersten Rings)
                  if (coordsRaw.first is List) {
                    final firstRing = coordsRaw.first as List;
                    if (firstRing.isNotEmpty && firstRing.first is List) {
                      final firstPointList = firstRing.first as List;
                      if (firstPointList.length >= 2 &&
                          firstPointList[0] is num &&
                          firstPointList[1] is num) {
                        center = LatLng((firstPointList[1] as num).toDouble(),
                            (firstPointList[0] as num).toDouble());
                      }
                    }
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print(
                      ">>> Fehler beim Parsen der Koordinaten für Feature '$name': $e");
                }
              }

              if (center != null) {
                features.add(SearchableFeature(
                  id: id.toString(),
                  name: name,
                  type: type,
                  center: center,
                ));
              } else if (kDebugMode) {
                // print("    WARNUNG: Konnte kein Zentrum für '$name' (Typ: $geomType) bestimmen. Überspringe.");
              }
            }
          }
        }
      }
    }
    if (kDebugMode) {
      print(
          "<<< _extractSearchableFeaturesFromGeoJson: ${features.length} suchbare Features extrahiert. >>>");
    }
    return features;
  }

  Future<void> _loadData() async {
    if (kDebugMode) {
      print("<<< _loadData: Starte das Laden der GeoJSON Daten... >>>");
    }
    if (!mounted) return;

    setState(() {
      _isDataReady = false;
    });

    try {
      final String geoJsonString =
          await rootBundle.loadString('assets/data/export.geojson');
      if (kDebugMode) {
        print(
            "<<< _loadData: GeoJSON String erfolgreich geladen (${geoJsonString.length} Zeichen). >>>");
      }

      final RoutingGraph graph =
          GeojsonParserService.parseGeoJson(geoJsonString);
      if (kDebugMode) {
        if (graph.nodes.isEmpty) {
          print(
              ">>> _loadData WARNUNG: Routing Graph vom Parser erhalten, aber er hat 0 Knoten. Überprüfen Sie GeoJSON-Inhalt und Parser-Logik (insb. _routableHighwayTypes).");
        } else {
          print(
              "<<< _loadData: Routing Graph vom Parser erhalten mit ${graph.nodes.length} Knoten. >>>");
        }
      }

      final List<SearchableFeature> features =
          _extractSearchableFeaturesFromGeoJson(geoJsonString);

      if (!mounted) return;
      setState(() {
        _routingGraph = graph;
        _searchableFeatures = features;

        if (_routingGraph != null && _routingGraph!.nodes.isNotEmpty) {
          _isDataReady = true;
          if (kDebugMode) {
            print(
                "<<< _loadData SUCCESS: Daten sind jetzt bereit (_isDataReady = true). Routing Graph mit ${_routingGraph!.nodes.length} Knoten. Suchbare Features: ${_searchableFeatures.length}. >>>");
          }
        } else {
          _isDataReady = false;
          if (kDebugMode) {
            print(
                ">>> _loadData ERROR: Routing Graph nicht korrekt initialisiert oder leer. _isDataReady bleibt false. Routing Graph: ${_routingGraph?.nodes.length ?? 'null'} Knoten. Suchbare Features: ${_searchableFeatures.length}. >>>");
          }
          _showErrorDialog(
              "Fehler bei der Initialisierung der Routing-Daten. Einige Funktionen könnten beeinträchtigt sein.");
        }
      });
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            ">>> _loadData FATAL ERROR: Fehler beim Laden/Parsen der GeoJSON Daten: $e");
        print(stacktrace);
      }
      if (!mounted) return;
      setState(() {
        _isDataReady = false;
      });
      _showErrorDialog(
          'Schwerwiegender Fehler beim Laden der Kartendaten: $e. App möglicherweise nicht funktionsfähig.');
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final results = _searchableFeatures.where((feature) {
      return feature.name.toLowerCase().contains(query) ||
          feature.type.toLowerCase().contains(query);
    }).toList();

    setState(() {
      _searchResults = results;
      _showSearchResults = _searchFocusNode.hasFocus &&
          results.isNotEmpty &&
          _searchController.text.isNotEmpty;
    });
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    setState(() {
      _showSearchResults = _searchFocusNode.hasFocus &&
          _searchResults.isNotEmpty &&
          _searchController.text.isNotEmpty;
    });
  }

  void _selectFeatureAndSetPoint(SearchableFeature feature) {
    if (kDebugMode) {
      print(
          "<<< _selectFeatureAndSetPoint: Feature ausgewählt: ${feature.name} an Position ${feature.center} >>>");
    }
    if (!mounted) return;

    _searchController.clear(); // Suchtext löschen
    _searchResults = []; // Suchergebnisse leeren
    _showSearchResults = false; // Suchergebnisse ausblenden
    _searchFocusNode.unfocus(); // Fokus vom Suchfeld nehmen

    setState(() {
      // UI Update erzwingen
      if (_selectedSearchFeatureForStart == null) {
        _selectedSearchFeatureForStart = feature;
        _startLatLng = feature.center;
        _startMarker = _createMarker(feature.center, Colors.green,
            Icons.flag_circle, "Start: ${feature.name}"); // Geändertes Icon
        if (kDebugMode) {
          print(
              "<<< _selectFeatureAndSetPoint: Startpunkt gesetzt auf: ${feature.name} >>>");
        }
        _showSnackbar(
            "Startpunkt: ${feature.name}. Ziel auswählen oder auf Karte tippen.");
      } else if (_selectedSearchFeatureForEnd == null) {
        _selectedSearchFeatureForEnd = feature;
        _endLatLng = feature.center;
        _endMarker = _createMarker(feature.center, Colors.red,
            Icons.flag_circle, "Ziel: ${feature.name}"); // Geändertes Icon
        if (kDebugMode) {
          print(
              "<<< _selectFeatureAndSetPoint: Zielpunkt gesetzt auf: ${feature.name} >>>");
        }
        _calculateAndDisplayRoute(); // Route berechnen und anzeigen
      }
      // Wenn Start und Ziel schon gesetzt sind, könnte man hier _clearAll und dann den Start neu setzen
    });
    _mapController.move(
        feature.center, 18.0); // Auf ausgewähltes Feature zoomen/verschieben
  }

  Future<void> _initializeGps() async {
    if (kDebugMode) {
      print("<<< _initializeGps: Starte GPS Initialisierung... >>>");
    }
    if (!mounted) return;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showErrorDialog(
          "GPS ist deaktiviert. Bitte aktiviere es, um deine Position zu sehen und die Navigation zu nutzen.");
      if (kDebugMode) {
        print(">>> _initializeGps: GPS-Dienst nicht aktiviert.");
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (kDebugMode) {
        print("<<< _initializeGps: GPS-Berechtigung ist 'denied', frage an...");
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        _showErrorDialog(
            "GPS-Berechtigung verweigert. Dein Standort kann nicht angezeigt werden.");
        if (kDebugMode) {
          print(
              ">>> _initializeGps: GPS-Berechtigung nach Anfrage immer noch 'denied'.");
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _showErrorDialog(
          "GPS-Berechtigung dauerhaft verweigert. Bitte in den App-Einstellungen ändern, um deinen Standort zu sehen.");
      if (kDebugMode) {
        print(">>> _initializeGps: GPS-Berechtigung 'deniedForever'.");
      }
      return;
    }

    if (kDebugMode) {
      print(
          "<<< _initializeGps: GPS-Berechtigung erteilt. Starte Positions-Stream...");
    }
    _positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter:
                    5)) // Höhere Genauigkeit, kleinerer Distanzfilter
        .listen((Position position) {
      if (!mounted) return;
      final bool isFirstFix = _currentGpsPosition == null;
      setState(() {
        _currentGpsPosition = LatLng(position.latitude, position.longitude);
        _currentLocationMarker = _createMarker(
            _currentGpsPosition!,
            Colors.blueAccent,
            Icons.circle,
            "Meine Position"); // Einfacher Kreis für GPS-Marker
      });
      if (kDebugMode) {
        print(
            "<<< _initializeGps: Neue GPS Position: $_currentGpsPosition >>>");
      }
      if (isFirstFix && _currentGpsPosition != null) {
        _mapController.move(
            _currentGpsPosition!, 17.0); // Auf erste Position zoomen
        if (kDebugMode) {
          print(
              "<<< _initializeGps: Karte auf erste GPS-Position zentriert. >>>");
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print(">>> _initializeGps: Fehler im GPS Positions-Stream: $error");
      }
      if (!mounted) return;
      _showErrorDialog("Fehler beim Empfang der GPS-Position: $error");
    });
  }

  Marker _createMarker(
      LatLng position, Color color, IconData icon, String tooltip,
      {double size = 30.0}) {
    return Marker(
      width: markerWidth,
      height: markerHeight,
      point: position,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: size),
      ),
      alignment: Alignment
          .center, // Stellt sicher, dass die Icon-Spitze auf dem Punkt ist
    );
  }

  Future<void> _calculateAndDisplayRoute() async {
    if (kDebugMode) {
      print(
          "<<< _calculateAndDisplayRoute: Aufgerufen. _isDataReady: $_isDataReady >>>");
    }
    if (!mounted) return;

    if (!_isDataReady) {
      _showErrorDialog(
          "Kartendaten sind noch nicht bereit. Bitte warten Sie einen Moment.");
      if (kDebugMode) {
        print(
            ">>> _calculateAndDisplayRoute: Abbruch, da _isDataReady = false.");
      }
      return;
    }

    if (_routingGraph == null || _routingGraph!.nodes.isEmpty) {
      _showErrorDialog(
          "Routing-Daten nicht verfügbar oder fehlerhaft. Navigation nicht möglich.");
      if (kDebugMode) {
        print(
            ">>> _calculateAndDisplayRoute: Routing Graph nicht initialisiert oder leer. Abbruch. Graph: $_routingGraph, Nodes: ${_routingGraph?.nodes.length}");
      }
      return;
    }

    if (_startLatLng == null || _endLatLng == null) {
      _showErrorDialog("Start- oder Zielpunkt nicht gesetzt.");
      if (kDebugMode) {
        print(
            ">>> _calculateAndDisplayRoute: Start- oder Zielpunkt nicht gesetzt. Abbruch.");
      }
      return;
    }

    setState(() => _isCalculatingRoute = true);
    if (kDebugMode) {
      print(
          "<<< _calculateAndDisplayRoute: Starte Routenberechnung von $_startLatLng nach $_endLatLng >>>");
    }

    try {
      final GraphNode? startNode =
          _routingGraph!.findNearestNode(_startLatLng!);
      final GraphNode? endNode = _routingGraph!.findNearestNode(_endLatLng!);

      if (startNode == null || endNode == null) {
        _showErrorDialog(
            "Start- oder Zielpunkt konnte nicht auf dem Wegenetz gefunden werden.");
        if (kDebugMode) {
          print(
              ">>> _calculateAndDisplayRoute: Start- (${startNode?.id}) oder Endknoten (${endNode?.id}) nicht im Graphen gefunden. Abbruch.");
        }
        if (!mounted) return;
        setState(() => _isCalculatingRoute = false);
        return;
      }

      if (startNode.id == endNode.id) {
        _showSnackbar("Start- und Zielpunkt sind identisch.");
        if (kDebugMode) {
          print(
              "<<< _calculateAndDisplayRoute: Start- und Endknoten sind identisch. Keine Route berechnet.");
        }
        if (!mounted) return;
        setState(() => _isCalculatingRoute = false);
        _clearRoute(
            showConfirmation: false,
            clearMarkers: false); // Nur Route löschen, Marker bleiben
        return;
      }

      _routingGraph!.resetAllNodeCosts();
      final List<LatLng>? routePoints =
          await RoutingService.findPath(_routingGraph!, startNode, endNode);

      if (!mounted) return;
      setState(() {
        if (routePoints != null && routePoints.isNotEmpty) {
          _routePolyline = Polyline(
            points: routePoints,
            strokeWidth: 5.0,
            color: Colors.deepPurpleAccent, // Andere Farbe für die Route
            isDotted: false,
          );
          if (kDebugMode) {
            print(
                "<<< _calculateAndDisplayRoute: Route gefunden mit ${routePoints.length} Punkten. >>>");
          }
          _showSnackbar("Route berechnet.", durationSeconds: 3);
        } else {
          _routePolyline =
              null; // Explizit null setzen, wenn keine Route gefunden wurde
          _showErrorDialog(
              "Keine Route zwischen den gewählten Punkten gefunden.");
          if (kDebugMode) {
            print(
                "<<< _calculateAndDisplayRoute: Keine Route gefunden (RoutingService lieferte null oder leere Liste). >>>");
          }
        }
      });
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            ">>> _calculateAndDisplayRoute: Fehler bei der Routenberechnung: $e");
        print(stacktrace);
      }
      if (!mounted) return;
      _showErrorDialog("Fehler bei der Routenberechnung: $e");
    } finally {
      if (!mounted) return;
      setState(() => _isCalculatingRoute = false);
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    if (kDebugMode) {
      print("<<< _handleMapTap: Auf Karte getippt: $latLng >>>");
    }
    if (!mounted) return;

    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      setState(() => _showSearchResults = false);
    }

    if (_isCalculatingRoute)
      return; // Keine Interaktion während Routenberechnung

    setState(() {
      // UI Update in jedem Fall, um Marker zu setzen/aktualisieren
      if (_selectedSearchFeatureForStart == null) {
        _startLatLng = latLng;
        // _selectedSearchFeatureForStart = SearchableFeature(id: "tap_start_${DateTime.now().millisecondsSinceEpoch}", name: "Start (Karte)", type: "map_tap", center: latLng);
        _startMarker = _createMarker(latLng, Colors.green, Icons.flag_circle,
            "Start (Position: ${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})");
        if (kDebugMode) {
          print("<<< _handleMapTap: Startpunkt via Karte gesetzt. >>>");
        }
        _showSnackbar(
            "Startpunkt gesetzt. Ziel auswählen oder auf Karte tippen.");
      } else if (_selectedSearchFeatureForEnd == null) {
        _endLatLng = latLng;
        // _selectedSearchFeatureForEnd = SearchableFeature(id: "tap_end_${DateTime.now().millisecondsSinceEpoch}", name: "Ziel (Karte)", type: "map_tap", center: latLng);
        _endMarker = _createMarker(latLng, Colors.red, Icons.flag_circle,
            "Ziel (Position: ${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})");
        if (kDebugMode) {
          print(
              "<<< _handleMapTap: Zielpunkt via Karte gesetzt. Routenberechnung wird gestartet. >>>");
        }
        _calculateAndDisplayRoute();
      } else {
        // Beide Punkte sind gesetzt, Dialog für neue Route
        _showConfirmationDialog("Neue Route?",
            "Möchtest du einen neuen Startpunkt setzen? Die aktuelle Route und die Punkte werden dabei gelöscht.",
            () {
          if (!mounted) return;
          _clearAll(); // Alles löschen
          setState(() {
            // Dann den neuen Startpunkt setzen
            _startLatLng = latLng;
            // _selectedSearchFeatureForStart = SearchableFeature(id: "tap_start_${DateTime.now().millisecondsSinceEpoch}", name: "Start (Karte)", type: "map_tap", center: latLng);
            _startMarker = _createMarker(
                latLng,
                Colors.green,
                Icons.flag_circle,
                "Start (Position: ${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})");
            if (kDebugMode) {
              print(
                  "<<< _handleMapTap: Neuer Startpunkt nach Bestätigung gesetzt. >>>");
            }
          });
          _showSnackbar(
              "Neuer Startpunkt gesetzt. Ziel auswählen oder auf Karte tippen.");
        });
      }
    });
  }

  void _clearRoute({bool showConfirmation = true, bool clearMarkers = true}) {
    final clearAction = () {
      if (!mounted) return;
      setState(() {
        _routePolyline = null;
        if (clearMarkers) {
          _startMarker = null;
          _endMarker = null;
          _startLatLng = null;
          _endLatLng = null;
          _selectedSearchFeatureForStart = null;
          _selectedSearchFeatureForEnd = null;
          if (kDebugMode) {
            print("<<< _clearRoute: Route UND Marker gelöscht. >>>");
          }
        } else {
          if (kDebugMode) {
            print(
                "<<< _clearRoute: Nur Route-Polyline gelöscht. Marker beibehalten. >>>");
          }
        }
      });
      if (clearMarkers) {
        _showSnackbar("Route und Punkte gelöscht.", durationSeconds: 2);
      } else {
        _showSnackbar("Route gelöscht.", durationSeconds: 2);
      }
    };

    if (showConfirmation &&
        (_routePolyline != null ||
            (clearMarkers && (_startMarker != null || _endMarker != null)))) {
      _showConfirmationDialog(
          clearMarkers ? "Route & Punkte löschen?" : "Route löschen?",
          clearMarkers
              ? "Möchtest du die aktuelle Route und die gesetzten Punkte wirklich löschen?"
              : "Möchtest du die aktuelle Route wirklich löschen?",
          clearAction);
    } else if (_routePolyline != null ||
        (clearMarkers && (_startMarker != null || _endMarker != null))) {
      // Nur ausführen, wenn auch was zu löschen da ist
      clearAction();
    }
  }

  void _clearAll() {
    if (!mounted) return;
    setState(() {
      _routePolyline = null;
      _startMarker = null;
      _endMarker = null;
      _startLatLng = null;
      _endLatLng = null;
      _selectedSearchFeatureForStart = null;
      _selectedSearchFeatureForEnd = null;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      if (kDebugMode) {
        print(
            "<<< _clearAll: Alle Routen-, Punkt- und Suchdaten gelöscht. >>>");
      }
    });
    _showSnackbar("Alle Eingaben zurückgesetzt.", durationSeconds: 2);
  }

  void _centerOnGps() {
    if (!mounted) return;
    if (_currentGpsPosition != null) {
      _mapController.move(_currentGpsPosition!, 17.0);
      if (kDebugMode) {
        print(
            "<<< _centerOnGps: Zentriere auf GPS-Position: $_currentGpsPosition >>>");
      }
    } else {
      if (kDebugMode) {
        print(
            ">>> _centerOnGps: Keine GPS-Position verfügbar zum Zentrieren. >>>");
      }
      _showSnackbar("Keine GPS-Position verfügbar.");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted || !ModalRoute.of(context)!.isCurrent) {
      if (kDebugMode) {
        print(
            ">>> _showErrorDialog: Dialog NICHT angezeigt (Screen nicht mounted oder nicht aktuell). Message: $message");
      }
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Anderer Name für context um Verwechslung zu vermeiden
        return AlertDialog(
          title: const Text("Fehler"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showSnackbar(String message, {int durationSeconds = 3}) {
    if (!mounted) {
      if (kDebugMode) {
        print(
            ">>> _showSnackbar: Snackbar NICHT angezeigt (Screen nicht mounted). Message: $message");
      }
      return;
    }
    ScaffoldMessenger.of(context)
        .removeCurrentSnackBar(); // Entferne ggf. alte Snackbars
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating, // Modernerer Look
      ),
    );
  }

  void _showConfirmationDialog(
      String title, String content, VoidCallback onConfirm) {
    if (!mounted || !ModalRoute.of(context)!.isCurrent) {
      if (kDebugMode) {
        print(
            ">>> _showConfirmationDialog: Dialog NICHT angezeigt. Message: $title");
      }
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text("Abbrechen"),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
            TextButton(
              child: const Text("Bestätigen"),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
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
    List<Marker> activeMarkers = [];
    if (_currentLocationMarker != null)
      activeMarkers.add(_currentLocationMarker!);
    if (_startMarker != null) activeMarkers.add(_startMarker!);
    if (_endMarker != null) activeMarkers.add(_endMarker!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campground Navigator"), // Titel angepasst
        // backgroundColor und foregroundColor werden von der globalen Theme übernommen
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentGpsPosition ?? defaultInitialCenter,
              initialZoom: 16.0,
              minZoom: 13.0,
              maxZoom: 19.0,
              onTap: _handleMapTap,
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture && _searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                  if (mounted) {
                    // mounted check
                    setState(() => _showSearchResults = false);
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName:
                    'de.tomsoft.campsitenav.app', // Eigene User Agent Kennung
                tileProvider:
                    CancellableNetworkTileProvider(), // Empfohlen für bessere Performance und Fehlerbehandlung
                // errorImage: AssetImage('assets/images/tile_error_placeholder.png'), // Beispiel für Fehler-Kachel (Bild muss existieren)
              ),
              if (_routePolyline != null)
                PolylineLayer(polylines: [_routePolyline!]),
              if (activeMarkers.isNotEmpty)
                MarkerLayer(
                    markers:
                        activeMarkers), // Nur hinzufügen, wenn Marker vorhanden
            ],
          ),
          Positioned(
            // Suchfeld
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 6.0, // Etwas mehr Schatten
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: _selectedSearchFeatureForStart == null
                        ? "Startpunkt suchen..."
                        : "Zielpunkt suchen...",
                    prefixIcon: const Icon(Icons.search), // Such-Icon
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              if (mounted) {
                                // mounted check
                                setState(() {
                                  _searchResults = [];
                                  _showSearchResults = false;
                                });
                              }
                            },
                          )
                        : null,
                    border: InputBorder.none, // Kein Rand innerhalb der Card
                  ),
                ),
              ),
            ),
          ),
          if (_showSearchResults &&
              _searchResults
                  .isNotEmpty) // Auch auf _searchResults.isNotEmpty prüfen
            Positioned(
              // Suchergebnisliste
              top: 75, // Angepasst an Höhe des Suchfelds
              left: 10,
              right: 10,
              child: Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height *
                        0.35, // Etwas weniger Höhe
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final feature = _searchResults[index];
                      return ListTile(
                        leading: Icon(_getIconForFeatureType(
                            feature.type)), // Icon basierend auf Feature-Typ
                        title: Text(feature.name),
                        subtitle: Text("Typ: ${feature.type}"),
                        onTap: () => _selectFeatureAndSetPoint(feature),
                        dense: true, // Kompaktere Darstellung
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_isCalculatingRoute) // Ladeindikator für Routenberechnung
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3), // Leichter Overlay
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          if (!_isDataReady &&
              _routingGraph == null) // Ladeindikator für Initialdaten
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: const Center(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Lade Kartendaten...",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                )),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        // Mehrere FABs untereinander
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if ((_routePolyline != null && _routePolyline!.points.isNotEmpty) ||
              _startMarker != null ||
              _endMarker != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                // Kleinerer Button
                heroTag: "clearAllBtn", // Eindeutiger HeroTag
                onPressed: _clearAll,
                // backgroundColor von Theme
                tooltip: 'Alles zurücksetzen (Route & Punkte)',
                child: const Icon(Icons.delete_sweep),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.small(
              // Kleinerer Button
              heroTag: "centerGpsBtn", // Eindeutiger HeroTag
              onPressed: _centerOnGps,
              // backgroundColor von Theme
              tooltip: 'Auf GPS zentrieren',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat, // Position der FABs
    );
  }

  // Hilfsmethode für Feature Icons
  IconData _getIconForFeatureType(String type) {
    switch (type.toLowerCase()) {
      case 'parking':
        return Icons.local_parking;
      case 'building':
        return Icons.business;
      case 'shop':
        return Icons.store;
      case 'amenity':
        return Icons.place; // Generisch für Annehmlichkeiten
      case 'tourism':
        return Icons.attractions;
      case 'reception':
        return Icons.room_service; // Beispiel
      case 'sanitary':
        return Icons.wc; // Beispiel
      case 'restaurant':
        return Icons.restaurant; // Beispiel
      default:
        return Icons.location_pin;
    }
  }
}
// [Ende lib/main.dart Überarbeitet für Fehlerbehebung]
