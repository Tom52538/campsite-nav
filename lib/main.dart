// lib/main.dart

import 'dart:async';
import 'dart:convert'; // Für jsonDecode // Wird hier nicht mehr direkt verwendet
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für rootBundle // Wird hier nicht mehr direkt verwendet
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Wird für Distance benötigt
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:provider/provider.dart';

// Eigene Imports
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
// GeojsonParserService wird hier nicht mehr direkt benötigt
// import 'package:camping_osm_navi/services/geojson_parser_service.dart';
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

class MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  Polyline? _routePolyline;
  Marker? _currentLocationMarker;
  Marker? _startMarker;
  Marker? _endMarker;
  LatLng? _currentGpsPosition;
  LatLng? _endLatLng;
  bool _isCalculatingRoute = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    if (kDebugMode) {
      print(
          "<<< initState: MapScreenState initialisiert. _lastProcessedLocation ist anfangs: ${_lastProcessedLocation?.name} >>>");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Holen des Providers hier ist ok, aber Änderungen sollten die build-Methode triggern,
    // wenn Provider.of mit listen:true verwendet wird oder ein Consumer-Widget.
    final locationProvider = Provider.of<LocationProvider>(context,
        listen: false); // listen: false, da wir hier nur Aktionen auslösen
    final newSelectedLocation = locationProvider.selectedLocation;

    if (newSelectedLocation != null &&
        (newSelectedLocation.id != _lastProcessedLocation?.id)) {
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
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

    final bool isInitialLoad = _lastProcessedLocation == null;

    setState(() {
      _routePolyline = null;
      _startMarker = null;
      _endMarker = null;
      _endLatLng = null;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });

    if (_isMapReady) {
      _mapController.move(newLocation.initialCenter, 17.0);
    }

    if (!isInitialLoad) {
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

    Provider.of<LocationProvider>(context, listen: false)
        .loadDataForSelectedLocation();
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
        if (_isMapReady) {
          _mapController.move(activeInitialCenterForMock, 17.0);
          if (kDebugMode) {
            print(
                "<<< _initializeGpsOrMock (mock): Karte bewegt, da _isMapReady true. >>>");
          }
        }

        if (_endLatLng != null) {
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
    if (!_isMapReady || !mounted) {
      return;
    }

    final location =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
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
        final Distance distance = Distance();
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

    if (targetToMoveTo != null) {
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

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }
    final locationProvider = Provider.of<LocationProvider>(context,
        listen: false); // Zugriff auf Provider
    final currentSearchableFeatures =
        locationProvider.currentSearchableFeatures;

    final query = _searchController.text.toLowerCase().trim();
    List<SearchableFeature> results = [];

    if (query.isNotEmpty && currentSearchableFeatures.isNotEmpty) {
      // ANPASSUNG
      results = currentSearchableFeatures.where((feature) {
        // ANPASSUNG
        return feature.name.toLowerCase().contains(query) ||
            feature.type.toLowerCase().contains(query);
      }).toList();
    }
    setStateIfMounted(() {
      _searchResults = results;
      _showSearchResults =
          _searchFocusNode.hasFocus && results.isNotEmpty && query.isNotEmpty;
    });
  }

  void _onSearchFocusChanged() {
    if (!mounted) {
      return;
    }
    // Die Logik hier bleibt gleich, da _searchResults und _searchFocusNode lokale UI-Steuerungsgrößen sind
    final bool hasFocus = _searchFocusNode.hasFocus;
    final bool hasText = _searchController.text.isNotEmpty;
    final bool hasResults = _searchResults.isNotEmpty;
    if (kDebugMode) {
      print(
          "<<< _onSearchFocusChanged: hasFocus: $hasFocus, hasText: $hasText, hasResults: $hasResults. Current _showSearchResults: $_showSearchResults >>>");
    }
    if (hasFocus) {
      setStateIfMounted(() {
        _showSearchResults = hasText && hasResults;
      });
    } else {
      if (kDebugMode) {
        print(
            "<<< _onSearchFocusChanged: Focus LOST. Intentionally NOT changing _showSearchResults state here. Waiting for item selection or map tap. >>>");
      }
    }
  }

  void _selectFeatureAndSetPoint(SearchableFeature feature) {
    if (kDebugMode) {
      print(
          "<<< _selectFeatureAndSetPoint: Feature ausgewählt: ${feature.name} >>>");
    }
    if (!mounted) {
      return;
    }

    _searchController.clear();
    _searchResults = [];
    _showSearchResults = false;
    _searchFocusNode.unfocus();

    setStateIfMounted(() {
      _endLatLng = feature.center;
      _endMarker = _createMarker(feature.center, Colors.red, Icons.flag_circle,
          "Ziel: ${feature.name}");
      if (kDebugMode) {
        print(
            "<<< _selectFeatureAndSetPoint: Zielpunkt gesetzt auf: ${feature.name} >>>");
      }
      _calculateAndDisplayRoute();
    });
    if (_isMapReady) {
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

      if (isFirstFix && _currentGpsPosition != null && _isMapReady) {
        final Distance distance = Distance();
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
      if (_endLatLng != null) {
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
    // ANPASSUNG: Daten und Ladezustand vom Provider holen
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final RoutingGraph? currentGraph = locationProvider.currentRoutingGraph;
    final bool isDataReadyForRouting =
        !locationProvider.isLoadingLocationData && currentGraph != null;

    final selectedLocationFromProvider =
        locationProvider.selectedLocation; // Kann bleiben für Namen etc.

    LatLng? routeStartPoint;
    String startPointType = "";
    final LatLng activeMockCenter =
        selectedLocationFromProvider?.initialCenter ?? fallbackInitialCenter;

    if (_useMockLocation) {
      routeStartPoint = activeMockCenter;
      startPointType =
          "Mock Position (${selectedLocationFromProvider?.name ?? 'Default'})";
    } else {
      routeStartPoint = _currentGpsPosition;
      startPointType = "Echte GPS Position";
    }

    if (routeStartPoint != null && mounted) {
      setStateIfMounted(() {
        _startMarker = _createMarker(routeStartPoint!, Colors.green,
            Icons.flag_circle, "Start: $startPointType");
      });
    } else if (mounted) {
      setStateIfMounted(() {
        _startMarker = null;
      });
    }

    if (kDebugMode) {
      print(
          "<<< _calculateAndDisplayRoute: Aufgerufen. Verwende Startpunkt: $startPointType ($routeStartPoint) >>>");
    }
    if (!mounted) {
      return;
    }

    if (!isDataReadyForRouting) {
      // ANPASSUNG
      _showErrorDialog(
          "Kartendaten für ${selectedLocationFromProvider?.name ?? 'ausgewählten Standort'} nicht bereit für Routing.");
      return;
    }
    if (currentGraph == null || currentGraph.nodes.isEmpty) {
      // ANPASSUNG
      _showErrorDialog(
          "Routing-Daten (Graph) für ${selectedLocationFromProvider?.name ?? 'ausgewählten Standort'} nicht verfügbar.");
      return;
    }
    if (routeStartPoint == null || _endLatLng == null) {
      setStateIfMounted(() => _routePolyline = null);
      if (routeStartPoint == null) {
        _showErrorDialog("Startpunkt (GPS/Mock) nicht verfügbar.");
      }
      return;
    }

    setStateIfMounted(() => _isCalculatingRoute = true);
    if (kDebugMode) {
      print(
          "<<< _calculateAndDisplayRoute: Starte Routenberechnung von $routeStartPoint nach $_endLatLng >>>");
    }
    try {
      final GraphNode? startNode =
          currentGraph.findNearestNode(routeStartPoint); // ANPASSUNG
      final GraphNode? endNode =
          currentGraph.findNearestNode(_endLatLng!); // ANPASSUNG

      if (startNode == null || endNode == null) {
        _showErrorDialog("Start/Ziel nicht auf Wegenetz gefunden.");
        setStateIfMounted(() => _routePolyline = null);
      } else if (startNode.id == endNode.id) {
        _showSnackbar("Start/Ziel identisch.");
        _clearRoute(showConfirmation: false, clearMarkers: false);
      } else {
        currentGraph.resetAllNodeCosts(); // ANPASSUNG
        final List<LatLng>? routePoints = await RoutingService.findPath(
            currentGraph, startNode, endNode); // ANPASSUNG
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
      print("<<< _handleMapTap: Auf Karte getippt: $latLng >>>");
    }
    if (!mounted) {
      return;
    }

    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      setStateIfMounted(() => _showSearchResults = false);
    } else if (_showSearchResults) {
      setStateIfMounted(() => _showSearchResults = false);
    }

    if (_isCalculatingRoute) {
      return;
    }

    final bool isNewTarget = _endLatLng == null || _endMarker == null;
    if (isNewTarget) {
      setStateIfMounted(() {
        _endLatLng = latLng;
        _endMarker = _createMarker(
            latLng, Colors.red, Icons.flag_circle, "Ziel (Karte)");
      });
      _calculateAndDisplayRoute();
    } else {
      _showConfirmationDialog(
          "Neues Ziel?", "Altes Ziel verwerfen und neues Ziel setzen?", () {
        if (!mounted) {
          return;
        }
        setStateIfMounted(() {
          _routePolyline = null;
          _endMarker = null;
          _endLatLng = latLng;
          _endMarker = _createMarker(
              latLng, Colors.red, Icons.flag_circle, "Ziel (Karte)");
        });
        _calculateAndDisplayRoute();
      });
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
          _endMarker = null;
          _endLatLng = null;
        }
      });
      _showSnackbar(
          clearMarkers ? "Route und Ziel gelöscht." : "Route gelöscht.",
          durationSeconds: 2);
    }

    final bool somethingToDelete =
        _routePolyline != null || (clearMarkers && _endMarker != null);

    if (showConfirmation && somethingToDelete) {
      _showConfirmationDialog(
          clearMarkers ? "Route & Ziel löschen?" : "Route löschen?",
          clearMarkers
              ? "Route und Ziel wirklich löschen?"
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

    if (centerTarget != null) {
      if (_isMapReady) {
        _mapController.move(centerTarget, 17.0);
      }
      if (kDebugMode) {
        print(
            "<<< _centerOnGps: Zentriere auf aktuell verwendete Position: $centerTarget (${_useMockLocation ? 'Mock für ${selectedLocationFromProvider?.name ?? 'Default'}' : 'Echt'}) >>>");
      }
    } else {
      if (kDebugMode) {
        print(">>> _centerOnGps: Keine Position verfügbar.");
      }
      _showSnackbar("Keine Position verfügbar.");
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
    // Zugriff auf den Provider. 'listen: true' ist hier wichtig, damit die UI
    // auf Änderungen im Provider reagiert (z.B. wenn isLoadingLocationData sich ändert).
    final locationProvider = Provider.of<LocationProvider>(context);
    final selectedLocationFromUI =
        locationProvider.selectedLocation; // Kann für UI-Texte bleiben
    final availableLocationsFromUI =
        locationProvider.availableLocations; // Kann für UI-Texte bleiben

    // Ladezustand und Daten aus dem Provider holen
    final bool isLoading = locationProvider.isLoadingLocationData;
    final RoutingGraph? currentGraph = locationProvider.currentRoutingGraph;
    final List<SearchableFeature> currentFeatures =
        locationProvider.currentSearchableFeatures;
    final bool isUiReady =
        !isLoading && currentGraph != null; // Eigene Logik für UI-Bereitschaft

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
                  onChanged: _onLocationSelectedFromDropdown,
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
              onPressed: _toggleMockLocation,
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
              onTap: _handleMapTap,
              onMapReady: () {
                if (!mounted) {
                  return;
                }
                if (kDebugMode) {
                  print("<<< Map ist jetzt bereit (onMapReady Callback) >>>");
                }
                setState(() {
                  _isMapReady = true;
                });
                _performInitialMapMove();
              },
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture && _searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                  if (mounted) {
                    setStateIfMounted(() => _showSearchResults = false);
                  }
                } else if (hasGesture && _showSearchResults) {
                  setStateIfMounted(() => _showSearchResults = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'de.tomsoft.campsitenav.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (isUiReady && _routePolyline != null) // ANPASSUNG
                PolylineLayer(polylines: [_routePolyline!]),
              if (isUiReady && activeMarkers.isNotEmpty) // ANPASSUNG
                MarkerLayer(markers: activeMarkers),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 6.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText:
                        "Suche in ${selectedLocationFromUI?.name ?? 'aktuellem Standort'}...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                  enabled: isUiReady, // ANPASSUNG
                ),
              ),
            ),
          ),
          if (_showSearchResults &&
              _searchResults.isNotEmpty &&
              isUiReady) // ANPASSUNG
            Positioned(
              top: 75,
              left: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  if (mounted) {
                    setStateIfMounted(() => _showSearchResults = false);
                    _searchFocusNode.unfocus();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
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
            ),
          if (_isCalculatingRoute) // Bleibt, da reine UI-Steuerung
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.3 * 255).round()),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          if (isLoading) // ANPASSUNG: Ladeindikator basierend auf Provider-Status
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
              (_routePolyline != null || _endMarker != null)) // ANPASSUNG
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: "clearRouteAndTargetBtn",
                onPressed: () => _clearRoute(clearMarkers: true),
                tooltip: 'Route & Ziel löschen',
                child: const Icon(Icons.delete_outline),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.small(
              heroTag: "centerBtn",
              onPressed: _centerOnGps,
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
        return Icons.room_service;
      case 'sanitary':
        return Icons.wc;
      case 'restaurant':
        return Icons.restaurant;
      default:
        return Icons.location_pin;
    }
  }
}
// [Ende lib/main.dart - Further SnackBar Refinements]
