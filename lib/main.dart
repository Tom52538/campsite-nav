// lib/main.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:provider/provider.dart';

// Eigene Imports
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => LocationProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campground Nav App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 4.0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
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

// PHASE 1, SCHRITT 1.1: Enum für aktives Suchfeld definieren
enum ActiveSearchField { none, start, end }

class MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  Polyline? _routePolyline;
  Marker? _currentLocationMarker;
  Marker? _startMarker; // Bleibt, wird für explizites _startLatLng verwendet
  Marker? _endMarker; // Bleibt
  LatLng? _currentGpsPosition;
  LatLng? _endLatLng; // Bleibt

  bool _isCalculatingRoute = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  List<SearchableFeature> _searchResults = [];
  bool _showSearchResults = false;

  bool _useMockLocation = true;
  bool _isMapReady = false;

  LocationInfo? _lastProcessedLocation;

  static const LatLng fallbackInitialCenter =
      LatLng(51.02518780487824, 5.858832278816441);
  static const double markerWidth = 40.0;
  static const double markerHeight = 40.0;
  static const double centerOnGpsMaxDistanceMeters = 5000;

  // PHASE 1, SCHRITT 1.2: Neue Zustandsvariablen deklarieren
  final TextEditingController _startSearchController = TextEditingController();
  final TextEditingController _endSearchController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  LatLng? _startLatLng; // Für den expliziten Startpunkt
  ActiveSearchField _activeSearchField = ActiveSearchField.none;

  @override
  void initState() {
    super.initState();

    _startSearchController.addListener(_onStartSearchChanged);
    _endSearchController.addListener(_onEndSearchChanged);
    _startFocusNode.addListener(_onStartFocusChanged);
    _endFocusNode.addListener(_onEndFocusChanged);

    if (kDebugMode) {
      print(
          "<<< initState: MapScreenState initialisiert. _lastProcessedLocation ist anfangs: ${_lastProcessedLocation?.name}, _isMapReady: $_isMapReady >>>");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final newSelectedLocation = locationProvider.selectedLocation;

    if (newSelectedLocation != null &&
        (_lastProcessedLocation == null ||
            newSelectedLocation.id != _lastProcessedLocation!.id)) {
      if (kDebugMode) {
        print(
            "<<< didChangeDependencies: Standortwechsel/Initialisierung für ${newSelectedLocation.name}. Vorheriger: ${_lastProcessedLocation?.name} >>>");
      }
      _handleLocationChangeUIUpdates(newSelectedLocation);
      _lastProcessedLocation = newSelectedLocation;
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print("<<< dispose: MapScreen wird zerstört. >>>");
    }
    _mapController.dispose();
    _positionStreamSubscription?.cancel();

    _startSearchController.removeListener(_onStartSearchChanged);
    _startSearchController.dispose();
    _endSearchController.removeListener(_onEndSearchChanged);
    _endSearchController.dispose();
    _startFocusNode.removeListener(_onStartFocusChanged);
    _startFocusNode.dispose();
    _endFocusNode.removeListener(_onEndFocusChanged);
    _endFocusNode.dispose();

    super.dispose();
  }

  void _onStartSearchChanged() {
    if (!mounted) return;
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final query = _startSearchController.text.toLowerCase().trim();
    _updateSearchResults(query, locationProvider.currentSearchableFeatures);
    setStateIfMounted(() {
      _showSearchResults = _startFocusNode.hasFocus &&
          query.isNotEmpty &&
          _searchResults.isNotEmpty;
    });
  }

  void _onEndSearchChanged() {
    if (!mounted) return;
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final query = _endSearchController.text.toLowerCase().trim();
    _updateSearchResults(query, locationProvider.currentSearchableFeatures);
    setStateIfMounted(() {
      _showSearchResults = _endFocusNode.hasFocus &&
          query.isNotEmpty &&
          _searchResults.isNotEmpty;
    });
  }

  void _updateSearchResults(String query, List<SearchableFeature> features) {
    if (query.isNotEmpty && features.isNotEmpty) {
      _searchResults = features.where((feature) {
        return feature.name.toLowerCase().contains(query) ||
            feature.type.toLowerCase().contains(query);
      }).toList();
    } else {
      _searchResults = [];
    }
  }

  void _onStartFocusChanged() {
    if (!mounted) return;
    final bool hasFocus = _startFocusNode.hasFocus;
    setStateIfMounted(() {
      if (hasFocus) {
        _activeSearchField = ActiveSearchField.start;
        _showSearchResults =
            _startSearchController.text.isNotEmpty && _searchResults.isNotEmpty;
      } else {
        // Verhindern, dass Suchergebnisse offen bleiben, wenn Fokus verloren geht,
        // außer eine Auswahl wird gerade getroffen (was _selectFeatureAndSetPoint handhabt)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted &&
              !_startFocusNode.hasFocus &&
              _activeSearchField == ActiveSearchField.start) {
            setStateIfMounted(() {
              _showSearchResults = false;
              // _activeSearchField = ActiveSearchField.none; // Nur wenn keine Auswahl getätigt wird
            });
          }
        });
      }
    });
  }

  void _onEndFocusChanged() {
    if (!mounted) return;
    final bool hasFocus = _endFocusNode.hasFocus;
    setStateIfMounted(() {
      if (hasFocus) {
        _activeSearchField = ActiveSearchField.end;
        _showSearchResults =
            _endSearchController.text.isNotEmpty && _searchResults.isNotEmpty;
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted &&
              !_endFocusNode.hasFocus &&
              _activeSearchField == ActiveSearchField.end) {
            setStateIfMounted(() {
              _showSearchResults = false;
              // _activeSearchField = ActiveSearchField.none;
            });
          }
        });
      }
    });
  }

  void _onLocationSelectedFromDropdown(LocationInfo? newLocation) {
    if (newLocation == null) {
      return;
    }
    Provider.of<LocationProvider>(context, listen: false)
        .selectLocation(newLocation);
  }

  void _handleLocationChangeUIUpdates(LocationInfo newLocation) {
    if (!mounted) {
      return;
    }

    final bool isActualChange = _lastProcessedLocation != null &&
        _lastProcessedLocation!.id != newLocation.id;

    setState(() {
      _routePolyline = null;
      _startMarker = null;
      _endMarker = null;
      _startLatLng = null;
      _endLatLng = null;
      _startSearchController.clear();
      _endSearchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      _activeSearchField = ActiveSearchField.none;
    });

    if (_isMapReady && mounted) {
      _mapController.move(newLocation.initialCenter, 17.0);
    }

    if (isActualChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSnackbar("Standort geändert zu: ${newLocation.name}",
              durationSeconds: 3);
        }
      });
    }

    if (kDebugMode) {
      print(
          "<<< _handleLocationChangeUIUpdates: Standort UI Updates für ${newLocation.name}. GeoJSON: ${newLocation.geojsonAssetPath} >>>");
    }
    _initializeGpsOrMock(newLocation);
  }

  void _toggleMockLocation() {
    if (!mounted) {
      return;
    }
    final currentLocation =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    setState(() {
      _useMockLocation = !_useMockLocation;
      if (currentLocation != null) {
        _initializeGpsOrMock(currentLocation);
      }
    });
    _showSnackbar(
        _useMockLocation
            ? "Mock-Position (${currentLocation?.name ?? 'Fallback'}) aktiviert."
            : "Echtes GPS aktiviert (mit Distanzprüfung).",
        durationSeconds: 4);
    if (kDebugMode) {
      print(
          "<<< _toggleMockLocation: Mock-Location ist jetzt: $_useMockLocation für Standort ${currentLocation?.name} >>>");
    }
  }

  void _initializeGpsOrMock(LocationInfo location) {
    _positionStreamSubscription?.cancel();
    setStateIfMounted(() {
      _currentGpsPosition = null;
      _currentLocationMarker = null;
    });
    final LatLng activeInitialCenterForMock = location.initialCenter;

    if (_useMockLocation) {
      if (kDebugMode) {
        print(
            "<<< _initializeGpsOrMock: Mock-Modus AKTIV. Setze Position auf initialCenter von ${location.name}: $activeInitialCenterForMock. >>>");
      }
      if (mounted) {
        setState(() {
          _currentGpsPosition = activeInitialCenterForMock;
          _currentLocationMarker = _createMarker(
              _currentGpsPosition!,
              Colors.orangeAccent,
              Icons.pin_drop,
              "Mock Position (${location.name})");
        });
        if (_isMapReady && mounted) {
          _mapController.move(activeInitialCenterForMock, 17.0);
          if (kDebugMode) {
            print(
                "<<< _initializeGpsOrMock (mock): Karte bewegt, da _isMapReady true. >>>");
          }
        }
        if (_startLatLng != null && _endLatLng != null) {
          _calculateAndDisplayRoute();
        }
      }
    } else {
      if (kDebugMode) {
        print(
            "<<< _initializeGpsOrMock: Echtes GPS AKTIV. Starte Initialisierung für ${location.name}... >>>");
      }
      _initializeGpsReal(location);
    }
  }

  void _performInitialMapMove() {
    if (!mounted || !_isMapReady) {
      if (kDebugMode && !_isMapReady) {
        print(
            "<<< _performInitialMapMove: Karte noch nicht bereit (_isMapReady ist false). Keine Bewegung. >>>");
      }
      return;
    }

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final location = locationProvider.selectedLocation;

    if (location == null) {
      if (kDebugMode) {
        print(
            "<<< _performInitialMapMove: Kein ausgewählter Standort, keine Bewegung. >>>");
      }
      return;
    }

    LatLng? targetToMoveTo;

    if (_useMockLocation) {
      targetToMoveTo = _currentGpsPosition ?? location.initialCenter;
    } else {
      if (_currentGpsPosition != null) {
        const distance = Distance();
        if (distance(_currentGpsPosition!, location.initialCenter) <=
            centerOnGpsMaxDistanceMeters) {
          targetToMoveTo = _currentGpsPosition;
        } else {
          targetToMoveTo = location.initialCenter;
          if (kDebugMode) {
            print(
                "<<< _performInitialMapMove: Echte GPS-Position zu weit, zentriere auf Standort-Initial. >>>");
          }
        }
      } else {
        targetToMoveTo = location.initialCenter;
      }
    }

    if (targetToMoveTo != null && mounted) {
      _mapController.move(targetToMoveTo, 17.0);
      if (kDebugMode) {
        print(
            "<<< _performInitialMapMove: Karte bewegt zu $targetToMoveTo >>>");
      }
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _selectFeatureAndSetPoint(SearchableFeature feature) {
    if (kDebugMode) {
      print(
          "<<< _selectFeatureAndSetPoint: Feature ausgewählt: ${feature.name}, aktives Feld: $_activeSearchField >>>");
    }
    if (!mounted) {
      return;
    }

    FocusNode? currentFocusNode;
    TextEditingController? currentController;

    if (_activeSearchField == ActiveSearchField.start) {
      currentFocusNode = _startFocusNode;
      currentController = _startSearchController;
      setStateIfMounted(() {
        _startLatLng = feature.center;
        _startMarker = _createMarker(feature.center, Colors.green,
            Icons.flag_circle, "Start: ${feature.name}");
      });
    } else if (_activeSearchField == ActiveSearchField.end) {
      currentFocusNode = _endFocusNode;
      currentController = _endSearchController;
      setStateIfMounted(() {
        _endLatLng = feature.center;
        _endMarker = _createMarker(feature.center, Colors.red,
            Icons.flag_circle, "Ziel: ${feature.name}");
      });
    }

    if (currentController != null) {
      // Um Listener-Schleifen zu vermeiden, den Text direkt über value setzen oder Listener kurz deaktivieren
      currentController.value = TextEditingValue(
        text: feature.name,
        selection: TextSelection.fromPosition(
            TextPosition(offset: feature.name.length)),
      );
    }

    setStateIfMounted(() {
      _showSearchResults = false;
      _searchResults = [];
    });

    currentFocusNode?.unfocus();
    // Nach Auswahl eines Punktes, das aktive Feld zurücksetzen
    // und optional den Fokus auf das nächste leere Feld setzen.
    if (_activeSearchField == ActiveSearchField.start &&
        _endSearchController.text.isEmpty) {
      FocusScope.of(context).requestFocus(_endFocusNode);
      // _activeSearchField = ActiveSearchField.end; // Wird durch den Focus Listener gesetzt
    } else if (_activeSearchField == ActiveSearchField.end &&
        _startSearchController.text.isEmpty) {
      FocusScope.of(context).requestFocus(_startFocusNode);
      // _activeSearchField = ActiveSearchField.start; // Wird durch den Focus Listener gesetzt
    } else {
      _activeSearchField = ActiveSearchField.none;
    }

    if (_startLatLng != null && _endLatLng != null) {
      _calculateAndDisplayRoute();
    }
    if (_isMapReady && mounted) {
      _mapController.move(feature.center, 18.0);
    }
  }

  Future<void> _initializeGpsReal(LocationInfo location) async {
    if (kDebugMode) {
      print(
          "<<< _initializeGpsReal: Starte ECHTE GPS Initialisierung für ${location.name}... >>>");
    }
    if (!mounted) {
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorDialog("GPS ist deaktiviert. Bitte aktiviere es.");
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorDialog("GPS-Berechtigung verweigert.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog("GPS-Berechtigung dauerhaft verweigert.");
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print(">>> _initializeGpsReal: Fehler bei Berechtigungsprüfung: $e");
      }
      _showErrorDialog("Fehler GPS-Berechtigungen: $e");
      return;
    }

    final LatLng centerForDistanceCheck = location.initialCenter;
    _positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 5))
        .listen((Position position) {
      if (!mounted) {
        return;
      }
      final bool isFirstFix = _currentGpsPosition == null;
      setStateIfMounted(() {
        _currentGpsPosition = LatLng(position.latitude, position.longitude);
        _currentLocationMarker = _createMarker(_currentGpsPosition!,
            Colors.blueAccent, Icons.circle, "Meine Position");
      });
      if (kDebugMode) {
        print(
            "<<< _initializeGpsReal: Neue ECHTE GPS Position: $_currentGpsPosition >>>");
      }

      if (isFirstFix && _currentGpsPosition != null && _isMapReady && mounted) {
        const distance = Distance();
        final double meters =
            distance(centerForDistanceCheck, _currentGpsPosition!);
        if (meters <= centerOnGpsMaxDistanceMeters) {
          _mapController.move(_currentGpsPosition!, 17.0);
          if (kDebugMode) {
            print(
                "<<< _initializeGpsReal: Karte auf erste, nahe ECHTE GPS-Position ($meters m entfernt von $centerForDistanceCheck) zentriert. >>>");
          }
        } else {
          if (kDebugMode) {
            print(
                "<<< _initializeGpsReal: Erste ECHTE GPS-Position ($meters m entfernt) ist zu weit weg (> $centerOnGpsMaxDistanceMeters m von $centerForDistanceCheck). Karte NICHT zentriert. >>>");
          }
          _showSnackbar(
              "Echte GPS-Position zu weit entfernt vom aktuellen Standort.",
              durationSeconds: 4);
        }
      }
      if (_startLatLng != null && _endLatLng != null) {
        _calculateAndDisplayRoute();
      }
    }, onError: (error) {
      if (kDebugMode) {
        print(
            ">>> _initializeGpsReal: Fehler im ECHTEN GPS Positions-Stream: $error");
      }
      _showErrorDialog("Fehler GPS-Empfang: $error");
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
      alignment: Alignment.center,
    );
  }

  Future<void> _calculateAndDisplayRoute() async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final RoutingGraph? currentGraph = locationProvider.currentRoutingGraph;
    final bool isLoadingData = locationProvider.isLoadingLocationData;
    final bool isDataReadyForRouting = !isLoadingData && currentGraph != null;
    final selectedLocationFromProvider = locationProvider.selectedLocation;

    if (kDebugMode) {
      print(
          "<<< _calculateAndDisplayRoute: Aufgerufen. Start: $_startLatLng, Ziel: $_endLatLng >>>");
    }
    if (!mounted) {
      return;
    }

    if (!isDataReadyForRouting) {
      _showErrorDialog(
          "Kartendaten für ${selectedLocationFromProvider?.name ?? 'ausgewählten Standort'} nicht bereit für Routing.");
      setStateIfMounted(() => _isCalculatingRoute = false);
      return;
    }

    if (currentGraph == null || currentGraph.nodes.isEmpty) {
      _showErrorDialog(
          "Routing-Daten (Graph) für ${selectedLocationFromProvider?.name ?? 'ausgewählten Standort'} nicht verfügbar oder leer.");
      setStateIfMounted(() => _isCalculatingRoute = false);
      return;
    }
    if (_startLatLng == null || _endLatLng == null) {
      setStateIfMounted(() => _routePolyline = null);
      if (_startLatLng == null &&
          _activeSearchField != ActiveSearchField.start) {
        // Nur anzeigen, wenn nicht gerade aktiv gesucht wird
        _showSnackbar("Startpunkt nicht definiert.");
      }
      if (_endLatLng == null &&
          _startLatLng != null &&
          _activeSearchField != ActiveSearchField.end) {
        _showSnackbar("Zielpunkt nicht definiert.");
      }
      setStateIfMounted(() => _isCalculatingRoute = false);
      return;
    }

    setStateIfMounted(() => _isCalculatingRoute = true);

    try {
      currentGraph.resetAllNodeCosts();
      final GraphNode? startNode = currentGraph.findNearestNode(_startLatLng!);
      final GraphNode? endNode = currentGraph.findNearestNode(_endLatLng!);

      if (startNode == null || endNode == null) {
        _showErrorDialog("Start/Ziel nicht auf Wegenetz gefunden.");
        setStateIfMounted(() => _routePolyline = null);
      } else if (startNode.id == endNode.id) {
        _showSnackbar("Start- und Zielpunkt sind identisch.");
        _clearRoute(showConfirmation: false, clearMarkers: false);
      } else {
        final List<LatLng>? routePoints =
            await RoutingService.findPath(currentGraph, startNode, endNode);
        if (!mounted) {
          return;
        }
        setStateIfMounted(() {
          if (routePoints != null && routePoints.isNotEmpty) {
            _routePolyline = Polyline(
              points: routePoints,
              strokeWidth: 5.0,
              color: Colors.deepPurpleAccent,
            );
            _showSnackbar("Route berechnet.", durationSeconds: 3);
          } else {
            _routePolyline = null;
            _showErrorDialog("Keine Route gefunden.");
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            ">>> _calculateAndDisplayRoute: Fehler Routenberechnung: $e\n$stacktrace");
      }
      _showErrorDialog("Fehler Routenberechnung: $e");
      setStateIfMounted(() => _routePolyline = null);
    } finally {
      if (mounted) {
        setStateIfMounted(() => _isCalculatingRoute = false);
      }
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    if (kDebugMode) {
      print(
          "<<< _handleMapTap: Auf Karte getippt: $latLng, aktives Feld: $_activeSearchField >>>");
    }
    if (!mounted) {
      return;
    }

    bool hadFocus = _startFocusNode.hasFocus || _endFocusNode.hasFocus;
    if (_startFocusNode.hasFocus) _startFocusNode.unfocus();
    if (_endFocusNode.hasFocus) _endFocusNode.unfocus();

    // Nur Suchergebnisse ausblenden, wenn sie vorher sichtbar waren oder Fokus bestand
    if (hadFocus || _showSearchResults) {
      setStateIfMounted(() {
        _showSearchResults = false;
        // _activeSearchField = ActiveSearchField.none; // Nicht hier, da es die Logik unten beeinflusst
      });
    }

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.isLoadingLocationData ||
        locationProvider.currentRoutingGraph == null) {
      _showSnackbar("Kartendaten werden noch geladen. Bitte warten.",
          durationSeconds: 2);
      return;
    }

    if (_isCalculatingRoute) {
      return;
    }

    ActiveSearchField fieldToSetByTap =
        _activeSearchField; // Behalte das aktive Feld, falls eines aktiv war

    if (fieldToSetByTap == ActiveSearchField.none) {
      // Kein Feld war aktiv durch Tastaturfokus
      if (_startLatLng == null && _startSearchController.text.isEmpty) {
        // Wenn Start leer, setze Start
        fieldToSetByTap = ActiveSearchField.start;
      } else if (_endLatLng == null && _endSearchController.text.isEmpty) {
        // Sonst, wenn Ziel leer, setze Ziel
        fieldToSetByTap = ActiveSearchField.end;
      } else {
        // Wenn beide schon was haben (oder per Text gesetzt sind), priorisiere Ziel oder das "logisch nächste"
        fieldToSetByTap = ActiveSearchField
            .end; // Standardmäßig Ziel setzen oder letztes gewähltes
      }
    }

    _setPointFromMapTap(latLng, fieldToSetByTap);

    // Nach dem Tap das _activeSearchField zurücksetzen, da der Tap die Aktion beendet.
    // Es sei denn, man möchte, dass das Feld "aktiv" bleibt für weitere Taps (nicht üblich)
    setStateIfMounted(() {
      _activeSearchField = ActiveSearchField.none;
    });

    if (_startLatLng != null && _endLatLng != null) {
      _calculateAndDisplayRoute();
    }
  }

  void _setPointFromMapTap(LatLng latLng, ActiveSearchField fieldToSet) {
    String pointName = (fieldToSet == ActiveSearchField.start)
        ? "Start (Karte)"
        : "Ziel (Karte)";
    TextEditingController relevantController =
        (fieldToSet == ActiveSearchField.start)
            ? _startSearchController
            : _endSearchController;

    void performUpdate() {
      if (fieldToSet == ActiveSearchField.start) {
        _startLatLng = latLng;
        _startMarker =
            _createMarker(latLng, Colors.green, Icons.flag_circle, pointName);
        relevantController.text =
            pointName; // Direkt setzen, Listener-Problematik ist in _onSearchChanged zu lösen
      } else {
        // ActiveSearchField.end
        _endLatLng = latLng;
        _endMarker =
            _createMarker(latLng, Colors.red, Icons.flag_circle, pointName);
        relevantController.text = pointName;
      }
      _routePolyline = null; // Route löschen, da ein Punkt geändert wurde
    }

    bool isOverwriting =
        (fieldToSet == ActiveSearchField.start && _startLatLng != null) ||
            (fieldToSet == ActiveSearchField.end && _endLatLng != null);

    if (isOverwriting) {
      _showConfirmationDialog(
          "Neuen ${fieldToSet == ActiveSearchField.start ? 'Start' : 'Ziel'}punkt setzen?",
          "Alten ${fieldToSet == ActiveSearchField.start ? 'Start' : 'Ziel'}punkt verwerfen und neuen Punkt auf Karte setzen?",
          () {
        if (!mounted) return;
        setStateIfMounted(performUpdate);
        if (_startLatLng != null && _endLatLng != null) {
          // Neu berechnen nach Bestätigung
          _calculateAndDisplayRoute();
        }
      });
    } else {
      setStateIfMounted(performUpdate);
      if (_startLatLng != null && _endLatLng != null) {
        // Neu berechnen
        _calculateAndDisplayRoute();
      }
    }
  }

  void _clearRoute({bool showConfirmation = true, bool clearMarkers = true}) {
    void doClearAction() {
      if (!mounted) {
        return;
      }
      setStateIfMounted(() {
        _routePolyline = null;
        if (clearMarkers) {
          _startMarker = null;
          _startLatLng = null;
          _startSearchController.clear();

          _endMarker = null;
          _endLatLng = null;
          _endSearchController.clear();
        }
      });
      _showSnackbar(
          clearMarkers
              ? "Route, Start- und Zielpunkt gelöscht."
              : "Route gelöscht.",
          durationSeconds: 2);
    }

    final bool somethingToDelete = _routePolyline != null ||
        (clearMarkers && (_startMarker != null || _endMarker != null));

    if (showConfirmation && somethingToDelete) {
      _showConfirmationDialog(
          clearMarkers ? "Alles löschen?" : "Route löschen?",
          clearMarkers
              ? "Route, Start- und Zielpunkt wirklich löschen?"
              : "Route wirklich löschen?",
          doClearAction);
    } else if (somethingToDelete) {
      doClearAction();
    }
  }

  void _centerOnGps() {
    if (!mounted) {
      return;
    }
    final selectedLocationFromProvider =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    LatLng? centerTarget;
    if (_useMockLocation) {
      centerTarget =
          selectedLocationFromProvider?.initialCenter ?? fallbackInitialCenter;
    } else {
      centerTarget = _currentGpsPosition;
    }

    if (centerTarget != null && _isMapReady && mounted) {
      _mapController.move(centerTarget, 17.0);
      if (kDebugMode) {
        print(
            "<<< _centerOnGps: Zentriere auf aktuell verwendete Position: $centerTarget (${_useMockLocation ? 'Mock für ${selectedLocationFromProvider?.name ?? 'Default'}' : 'Echt'}) >>>");
      }
    } else {
      if (kDebugMode) {
        print(
            ">>> _centerOnGps: Keine Position verfügbar oder Karte nicht bereit.");
      }
      _showSnackbar("Keine Position verfügbar oder Karte nicht bereit.");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
      if (kDebugMode) {
        print(
            ">>> _showErrorDialog: Dialog NICHT angezeigt. Message: $message");
      }
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
        print(">>> _showSnackbar: Snackbar NICHT angezeigt. Message: $message");
      }
      return;
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _showConfirmationDialog(
      String title, String content, VoidCallback onConfirm) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
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
    final locationProvider = Provider.of<LocationProvider>(context);
    final selectedLocationFromUI = locationProvider.selectedLocation;
    final availableLocationsFromUI = locationProvider.availableLocations;

    final bool isLoading = locationProvider.isLoadingLocationData;
    final RoutingGraph? currentGraph = locationProvider.currentRoutingGraph;
    final bool isUiReady = !isLoading && currentGraph != null;

    List<Marker> activeMarkers = [];
    if (_currentLocationMarker != null) {
      activeMarkers.add(_currentLocationMarker!);
    }
    if (_startMarker != null) {
      activeMarkers.add(_startMarker!);
    }
    if (_endMarker != null) {
      activeMarkers.add(_endMarker!);
    }

    const double searchCardTopPadding = 10.0;
    const double searchInputHeight = 56.0;
    const double searchCardItemSpacing = 0; // Divider height is 1
    final double searchUICardHeight = (searchInputHeight * 2) +
        (searchCardItemSpacing * 1) +
        16; // 2 TextFields, 1 Divider, Card Padding
    final double searchResultsTopPosition =
        searchCardTopPadding + searchUICardHeight + 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campground Navigator"),
        actions: [
          if (availableLocationsFromUI.isNotEmpty &&
              selectedLocationFromUI != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<LocationInfo>(
                  value: selectedLocationFromUI,
                  icon: const Icon(Icons.public, color: Colors.white),
                  dropdownColor: Colors.deepOrange[700],
                  style: const TextStyle(color: Colors.white),
                  items: availableLocationsFromUI
                      .map<DropdownMenuItem<LocationInfo>>(
                          (LocationInfo location) {
                    return DropdownMenuItem<LocationInfo>(
                      value: location,
                      child: Text(
                        location.name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: isUiReady ? _onLocationSelectedFromDropdown : null,
                  hint: const Text("Standort wählen",
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
          Tooltip(
            message: _useMockLocation
                ? "Echtes GPS aktivieren"
                : "Mock-Position aktivieren",
            child: IconButton(
              icon: Icon(
                  _useMockLocation ? Icons.location_on : Icons.location_off),
              color: _useMockLocation ? Colors.orangeAccent : Colors.white,
              onPressed: isUiReady ? _toggleMockLocation : null,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: selectedLocationFromUI?.initialCenter ??
                  fallbackInitialCenter,
              initialZoom: 17.0,
              minZoom: 13.0,
              maxZoom: 19.0,
              onTap: isUiReady ? _handleMapTap : null,
              onMapReady: () {
                if (!mounted) {
                  return;
                }
                if (kDebugMode) {
                  print(
                      "<<< Map ist jetzt bereit (onMapReady Callback), _isMapReady wird auf true gesetzt. >>>");
                }
                setState(() {
                  _isMapReady = true;
                });
                _performInitialMapMove();
              },
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture &&
                    (_startFocusNode.hasFocus || _endFocusNode.hasFocus)) {
                  if (_startFocusNode.hasFocus) _startFocusNode.unfocus();
                  if (_endFocusNode.hasFocus) _endFocusNode.unfocus();
                  // Das Ausblenden der Suchergebnisse wird jetzt von den FocusListenern (mit Verzögerung) gehandhabt
                } else if (hasGesture && _showSearchResults) {
                  // setStateIfMounted(() => _showSearchResults = false); // Auch hier, Fokus-Listener sind primär
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'de.tomsoft.campsitenav.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (isUiReady && _routePolyline != null)
                PolylineLayer(polylines: [_routePolyline!]),
              if (isUiReady && activeMarkers.isNotEmpty)
                MarkerLayer(markers: activeMarkers),
            ],
          ),
          Positioned(
            top: searchCardTopPadding,
            left: 10,
            right: 10,
            child: Card(
              elevation: 6.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startSearchController,
                            focusNode: _startFocusNode,
                            decoration: InputDecoration(
                              hintText: "Startpunkt wählen",
                              prefixIcon: const Icon(Icons.trip_origin),
                              suffixIcon: _startSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      iconSize: 20,
                                      onPressed: () {
                                        _startSearchController.clear();
                                        setStateIfMounted(() {
                                          _startLatLng = null;
                                          _startMarker = null;
                                          _routePolyline = null;
                                          _searchResults = [];
                                          _showSearchResults = false;
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            enabled: isUiReady,
                          ),
                        ),
                        Tooltip(
                          message: "Aktuellen Standort als Start verwenden",
                          child: IconButton(
                            icon: const Icon(Icons.my_location),
                            color: Theme.of(context).colorScheme.primary,
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: isUiReady
                                ? () {
                                    if (_currentGpsPosition != null) {
                                      setStateIfMounted(() {
                                        _startLatLng = _currentGpsPosition;
                                        _startMarker = _createMarker(
                                            _startLatLng!,
                                            Colors.green,
                                            Icons.flag_circle,
                                            _useMockLocation
                                                ? "Start: Mock Position (${selectedLocationFromUI?.name ?? ''})"
                                                : "Start: Echte GPS Position");
                                        _startSearchController.text =
                                            _useMockLocation
                                                ? "Mock Position (${selectedLocationFromUI?.name ?? ''})"
                                                : "Aktueller Standort";
                                        if (_startFocusNode.hasFocus)
                                          _startFocusNode.unfocus();
                                        _showSearchResults = false;
                                        _activeSearchField =
                                            ActiveSearchField.none;
                                      });
                                      if (_startLatLng != null &&
                                          _endLatLng != null) {
                                        _calculateAndDisplayRoute();
                                      }
                                    } else {
                                      _showSnackbar(
                                          "Aktuelle Position nicht verfügbar.");
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1, thickness: 1),
                    TextField(
                      controller: _endSearchController,
                      focusNode: _endFocusNode,
                      decoration: InputDecoration(
                        hintText: "Ziel wählen",
                        prefixIcon: const Icon(Icons.flag_outlined),
                        suffixIcon: _endSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                iconSize: 20,
                                onPressed: () {
                                  _endSearchController.clear();
                                  setStateIfMounted(() {
                                    _endLatLng = null;
                                    _endMarker = null;
                                    _routePolyline = null;
                                    _searchResults = [];
                                    _showSearchResults = false;
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      enabled: isUiReady,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showSearchResults && _searchResults.isNotEmpty && isUiReady)
            Positioned(
              top: searchResultsTopPosition,
              left: 10,
              right: 10,
              child: Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final feature = _searchResults[index];
                      return ListTile(
                        leading: Icon(_getIconForFeatureType(feature.type)),
                        title: Text(feature.name),
                        subtitle: Text("Typ: ${feature.type}"),
                        onTap: () => _selectFeatureAndSetPoint(feature),
                        dense: true,
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_isCalculatingRoute && isUiReady)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.3 * 255).round()),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.7 * 255).round()),
                child: Center(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                        "Lade Kartendaten für ${selectedLocationFromUI?.name ?? 'Start-Standort'}...",
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                )),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isUiReady &&
              (_routePolyline != null ||
                  _startMarker != null ||
                  _endMarker != null))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: "clearAllBtn",
                onPressed: () =>
                    _clearRoute(showConfirmation: true, clearMarkers: true),
                tooltip: 'Route, Start & Ziel löschen',
                child: const Icon(Icons.delete_forever_outlined),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.small(
              heroTag: "centerBtn",
              onPressed: isUiReady ? _centerOnGps : null,
              tooltip: 'Auf aktuelle Position zentrieren',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  IconData _getIconForFeatureType(String type) {
    switch (type.toLowerCase()) {
      case 'parking':
        return Icons.local_parking;
      case 'building':
        return Icons.business;
      case 'shop':
        return Icons.store;
      case 'amenity':
        return Icons.place;
      case 'tourism':
        return Icons.attractions;
      case 'reception':
      case 'information':
        return Icons.room_service;
      case 'sanitary':
      case 'toilets':
        return Icons.wc;
      case 'restaurant':
      case 'cafe':
      case 'bar':
        return Icons.restaurant;
      case 'playground':
        return Icons.child_friendly;
      case 'pitch':
      case 'camp_pitch':
        return Icons.holiday_village;
      case 'water_point':
        return Icons.water_drop;
      case 'waste_disposal':
        return Icons.recycling;
      default:
        return Icons.location_pin;
    }
  }
}
