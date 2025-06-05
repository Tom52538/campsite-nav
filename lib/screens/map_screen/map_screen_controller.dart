// lib/screens/map_screen/map_screen_controller.dart - MIT ENHANCED LOGGING
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/widgets/modern_map_markers.dart';
import 'package:camping_osm_navi/services/tts_service.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/services/user_journey_logger.dart'; // ✅ NEUES LOGGING

class MapScreenController with ChangeNotifier {
  final MapController mapController = MapController();
  late TtsService ttsService;
  final LocationProvider _locationProvider;

  // State Variables
  Polyline? routePolyline;
  List<Polyline> _routePolylines = [];
  Marker? currentLocationMarker;
  Marker? _startMarker;
  Marker? _destinationMarker;
  LatLng? currentGpsPosition;

  SearchableFeature? _selectedStart;
  SearchableFeature? _selectedDestination;
  bool _isStartLocked = false;
  bool _isDestinationLocked = false;
  bool _isMapSelectionMode = false;
  SearchFieldType? _mapSelectionFor;

  final TextEditingController startSearchController = TextEditingController();
  final TextEditingController endSearchController = TextEditingController();
  final FocusNode startFocusNode = FocusNode();
  final FocusNode endFocusNode = FocusNode();

  bool isCalculatingRoute = false;
  bool showSearchResults = false;
  bool useMockLocation = true;
  bool isMapReady = false;
  bool followGps = false;
  bool isRouteActiveForCardSwitch = false;
  bool showPOILabels = false;

  LocationInfo? lastProcessedLocation;

  double? routeDistance;
  int? routeTimeMinutes;
  double? remainingRouteDistance;
  int? remainingRouteTimeMinutes;
  List<Maneuver> currentManeuvers = [];
  Maneuver? currentDisplayedManeuver;

  bool _isInRouteOverviewMode = false;
  DateTime? _lastRerouteTime;
  bool _isRerouting = false;

  String _maptilerUrlTemplate = '';

  bool _isKeyboardVisible = false;
  double _keyboardHeight = 0;
  bool _compactSearchMode = false;
  bool showRouteInfoAndFadeFields = false;

  double? lastSpokenDistance;
  int? lastSpokenTime;

  SearchInterfaceState _searchInterfaceState = SearchInterfaceState.expanded;
  bool _autoHideAfterRoute = true;

  // ✅ LOGGING: Performance Tracking
  DateTime? _routeCalculationStartTime;
  int _navigationSteps = 0;

  // Getters
  Marker? get startMarker => _startMarker;
  Marker? get destinationMarker => _destinationMarker;
  List<Polyline> get routePolylines => _routePolylines;

  SearchableFeature? get selectedStart => _selectedStart;
  SearchableFeature? get selectedDestination => _selectedDestination;
  bool get isStartLocked => _isStartLocked;
  bool get isDestinationLocked => _isDestinationLocked;
  bool get isMapSelectionActive => _isMapSelectionMode;
  SearchFieldType? get mapSelectionFor => _mapSelectionFor;

  static const double followGpsZoomLevel = 17.5;
  static const LatLng fallbackInitialCenter =
      LatLng(51.02518780487824, 5.858832278816441);
  static const double centerOnGpsMaxDistanceMeters = 5000;
  static const double maneuverReachedThreshold = 15.0;
  static const double significantGpsChangeThreshold = 2.0;
  static const Distance distanceCalculatorInstance = Distance();

  bool get isInRouteOverviewMode => _isInRouteOverviewMode;
  bool get isRerouting => _isRerouting;
  String get maptilerUrlTemplate => _maptilerUrlTemplate;
  bool get isKeyboardVisible => _isKeyboardVisible;
  double get keyboardHeight => _keyboardHeight;
  bool get compactSearchMode => _compactSearchMode;

  SearchInterfaceState get searchInterfaceState => _searchInterfaceState;
  bool get shouldAutoHideInterface => _autoHideAfterRoute && hasActiveRoute;

  bool get hasActiveRoute =>
      routePolyline != null &&
      _selectedStart != null &&
      _selectedDestination != null;

  bool get shouldShowCompactMode =>
      hasActiveRoute && isStartLocked && isDestinationLocked;

  MapScreenController(this._locationProvider) {
    ttsService = TtsService();
    _initializeListeners();

    // ✅ LOGGING: Controller initialisiert
    UserJourneyLogger.startSession();
  }

  void _initializeListeners() {
    startSearchController.addListener(_onSearchTextChanged);
    endSearchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    if (_searchInterfaceState != SearchInterfaceState.expanded) {
      setSearchInterfaceState(SearchInterfaceState.expanded);
    }
  }

  void setSearchInterfaceState(SearchInterfaceState newState) {
    if (_searchInterfaceState != newState) {
      // ✅ LOGGING: Interface State Change
      UserJourneyLogger.logContextSwitch(
          _searchInterfaceState.value, newState.value);

      _searchInterfaceState = newState;
      notifyListeners();
    }
  }

  void setAutoHideAfterRoute(bool autoHide) {
    _autoHideAfterRoute = autoHide;
    notifyListeners();
  }

  void initializeMaptilerUrl(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) {
      _maptilerUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

      // ✅ LOGGING: Fallback auf OSM
      UserJourneyLogger.warning(
          "MAP_TILES", "Kein MapTiler API Key - Fallback auf OSM");
    } else {
      _maptilerUrlTemplate =
          'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$apiKey';

      // ✅ LOGGING: MapTiler aktiviert
      UserJourneyLogger.mapReady(_maptilerUrlTemplate, true);
    }
  }

  void updateKeyboardVisibility(bool visible, double height) {
    if (visible != _isKeyboardVisible ||
        (height - _keyboardHeight).abs() > 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isKeyboardVisible = visible;
        _keyboardHeight = height;

        if (visible) {
          setCompactSearchMode(true);
          setSearchInterfaceState(SearchInterfaceState.expanded);
        } else if (!visible) {
          setCompactSearchMode(false);
          if (shouldAutoHideInterface) {
            setSearchInterfaceState(SearchInterfaceState.navigationMode);
          }
        }
        notifyListeners();
      });
    }
  }

  void setCompactSearchMode(bool compact) {
    if (_compactSearchMode != compact) {
      _compactSearchMode = compact;
      notifyListeners();
    }
  }

  void setMapReady() {
    isMapReady = true;

    // ✅ LOGGING: Map ist bereit für Interaktionen
    UserJourneyLogger.mapReady("Flutter Map Ready", false);

    notifyListeners();
  }

  void setRouteOverviewMode(bool isOverview) {
    _isInRouteOverviewMode = isOverview;

    // ✅ LOGGING: Route Overview Mode
    UserJourneyLogger.buttonPressed("Route Overview",
        isOverview ? "Vollroute anzeigen" : "Zurück zur Navigation");

    notifyListeners();
  }

  void setStartLocation(SearchableFeature feature) {
    _selectedStart = feature;
    _isStartLocked = false;
    startSearchController.text = feature.name;
    showRouteInfoAndFadeFields = false;

    // ✅ LOGGING: Start location gesetzt
    UserJourneyLogger.buttonPressed(
        "Set Start Location", "Start: ${feature.name}");

    _startMarker = ModernMapMarkers.createStartMarker(
      feature.center,
      label: feature.name,
    );

    _tryCalculateRoute();

    if (_selectedDestination != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (hasActiveRoute) {
          setSearchInterfaceState(SearchInterfaceState.collapsed);
        }
      });
    }

    notifyListeners();
  }

  void setDestination(SearchableFeature feature) {
    _selectedDestination = feature;
    _isDestinationLocked = false;
    endSearchController.text = feature.name;
    showRouteInfoAndFadeFields = false;

    // ✅ LOGGING: Destination gesetzt
    UserJourneyLogger.buttonPressed("Set Destination", "Ziel: ${feature.name}");

    _destinationMarker = ModernMapMarkers.createDestinationMarker(
      feature.center,
      label: feature.name,
    );

    _tryCalculateRoute();

    if (_selectedStart != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (hasActiveRoute) {
          setSearchInterfaceState(SearchInterfaceState.collapsed);
        }
      });
    }

    notifyListeners();
  }

  void toggleStartLock() {
    _isStartLocked = !_isStartLocked;

    // ✅ LOGGING: Start Lock Toggle
    UserJourneyLogger.buttonPressed("Toggle Start Lock",
        _isStartLocked ? "Start gesperrt" : "Start entsperrt");

    attemptRouteCalculationOrClearRoute();
    notifyListeners();
  }

  void toggleDestinationLock() {
    _isDestinationLocked = !_isDestinationLocked;

    // ✅ LOGGING: Destination Lock Toggle
    UserJourneyLogger.buttonPressed("Toggle Destination Lock",
        _isDestinationLocked ? "Ziel gesperrt" : "Ziel entsperrt");

    attemptRouteCalculationOrClearRoute();
    notifyListeners();
  }

  Future<void> attemptRouteCalculationOrClearRoute() async {
    if (isStartLocked &&
        isDestinationLocked &&
        _selectedStart != null &&
        _selectedDestination != null) {
      // ✅ LOGGING: Route-Berechnung startet
      _routeCalculationStartTime = DateTime.now();
      UserJourneyLogger.routeCalculationStarted(
          _selectedStart!.name, _selectedDestination!.name);

      setCalculatingRoute(true);
      notifyListeners();

      final graph = _locationProvider.currentRoutingGraph;
      if (graph == null) {
        // ✅ LOGGING: Kein Graph verfügbar
        UserJourneyLogger.routeCalculationFailed(
            "Routing-Graph nicht verfügbar");

        setCalculatingRoute(false);
        notifyListeners();
        return;
      }

      final startNode = graph.findNearestNode(_selectedStart!.center);
      final endNode = graph.findNearestNode(_selectedDestination!.center);

      if (startNode != null && endNode != null) {
        graph.resetAllNodeCosts();
        final List<LatLng>? path =
            await RoutingService.findPath(graph, startNode, endNode);

        if (path != null && path.isNotEmpty) {
          final maneuvers = RoutingService.analyzeRouteForTurns(path);

          _setModernRoutePolylines(path);
          setCurrentManeuvers(maneuvers);
          updateRouteMetrics(path);

          if (maneuvers.isNotEmpty) {
            updateCurrentDisplayedManeuver(maneuvers.first);
          }

          // ✅ LOGGING: Route erfolgreich berechnet
          if (_routeCalculationStartTime != null) {
            final calculationTime = DateTime.now()
                .difference(_routeCalculationStartTime!)
                .inMilliseconds;

            UserJourneyLogger.routeCalculated(routeDistance ?? 0,
                routeTimeMinutes ?? 0, path.length, maneuvers.length);

            UserJourneyLogger.performanceMetric(
                "Route Calculation", calculationTime, "SUCCESS");
          }

          showRouteInfoAndFadeFields = true;

          Future.delayed(const Duration(milliseconds: 1500), () {
            if (shouldAutoHideInterface) {
              setSearchInterfaceState(SearchInterfaceState.navigationMode);
            }
          });

          ttsService.speakImmediate(
              "Route calculated. ${formatDistance(routeDistance)} in about $routeTimeMinutes minutes.");
        } else {
          // ✅ LOGGING: Route-Berechnung fehlgeschlagen - kein Pfad
          UserJourneyLogger.routeCalculationFailed(
              "Kein Pfad zwischen Start und Ziel gefunden");

          resetRouteAndNavigation();
          showRouteInfoAndFadeFields = false;
        }
      } else {
        // ✅ LOGGING: Route-Berechnung fehlgeschlagen - keine Knoten
        UserJourneyLogger.routeCalculationFailed(
            "Start- oder Endknoten nicht im Routing-Graph gefunden");

        resetRouteAndNavigation();
        showRouteInfoAndFadeFields = false;
      }

      setCalculatingRoute(false);
    } else {
      resetRouteAndNavigation();
      showRouteInfoAndFadeFields = false;
    }
    notifyListeners();
  }

  void _setModernRoutePolylines(List<LatLng> path) {
    if (followGps && currentGpsPosition != null) {
      _routePolylines = ModernRoutePolyline.createGradientRoute(path);
      routePolyline = ModernRoutePolyline.createNavigationRoute(path);
    } else {
      _routePolylines = [ModernRoutePolyline.createModernRoute(path)];
      routePolyline = ModernRoutePolyline.createModernRoute(path);
    }
  }

  void setCurrentLocationAsStart() {
    if (currentGpsPosition != null) {
      final currentLocationFeature = SearchableFeature(
        id: "current_location",
        name: "Current Location",
        type: "Current Location",
        center: currentGpsPosition!,
      );

      // ✅ LOGGING: GPS Position als Start
      UserJourneyLogger.buttonPressed("Use GPS as Start",
          "GPS Position: ${currentGpsPosition!.latitude.toStringAsFixed(4)}, ${currentGpsPosition!.longitude.toStringAsFixed(4)}");

      setStartLocation(currentLocationFeature);
    }
    notifyListeners();
  }

  void swapStartAndDestination() {
    final tempFeature = _selectedStart;
    final tempText = startSearchController.text;
    final tempMarker = _startMarker;

    _selectedStart = _selectedDestination;
    startSearchController.text = endSearchController.text;
    _startMarker = _destinationMarker;

    _selectedDestination = tempFeature;
    endSearchController.text = tempText;
    _destinationMarker = tempMarker;

    if (_selectedStart != null) {
      _startMarker = ModernMapMarkers.createStartMarker(_selectedStart!.center);
    }
    if (_selectedDestination != null) {
      _destinationMarker = ModernMapMarkers.createDestinationMarker(
          _selectedDestination!.center);
    }

    // ✅ LOGGING: Start/Ziel getauscht
    UserJourneyLogger.swapStartDestination();

    showRouteInfoAndFadeFields = false;
    _tryCalculateRoute();
    notifyListeners();
  }

  void activateMapSelection(SearchFieldType fieldType) {
    _isMapSelectionMode = true;
    _mapSelectionFor = fieldType;

    setSearchInterfaceState(SearchInterfaceState.hidden);

    // ✅ LOGGING: Map Selection aktiviert
    UserJourneyLogger.buttonPressed(
        "Map Selection", "Karten-Auswahl für ${fieldType.displayName}");

    notifyListeners();
  }

  void handleMapTapForSelection(LatLng tappedPoint) {
    if (!_isMapSelectionMode || _mapSelectionFor == null) return;

    final mapSelectedFeature = SearchableFeature(
      id: "map_selection_${_mapSelectionFor.toString()}",
      name:
          "Map Point (${_mapSelectionFor == SearchFieldType.start ? 'Start' : 'Destination'})",
      type: "Map Selection",
      center: tappedPoint,
    );

    // ✅ LOGGING: Punkt auf Karte gewählt
    UserJourneyLogger.buttonPressed("Map Point Selected",
        "Koordinaten: ${tappedPoint.latitude.toStringAsFixed(4)}, ${tappedPoint.longitude.toStringAsFixed(4)}");

    if (_mapSelectionFor == SearchFieldType.start) {
      setStartLocation(mapSelectedFeature);
    } else {
      setDestination(mapSelectedFeature);
    }

    _isMapSelectionMode = false;
    _mapSelectionFor = null;

    setSearchInterfaceState(SearchInterfaceState.expanded);

    notifyListeners();
  }

  void _tryCalculateRoute() {
    attemptRouteCalculationOrClearRoute();
  }

  void setRerouting(bool rerouting) {
    _isRerouting = rerouting;
    if (rerouting) {
      _lastRerouteTime = DateTime.now();

      // ✅ LOGGING: Rerouting gestartet
      UserJourneyLogger.warning(
          "NAVIGATION", "Rerouting gestartet - Benutzer ist off-route");
    }
    notifyListeners();
  }

  void togglePOILabels() {
    showPOILabels = !showPOILabels;

    // ✅ LOGGING: POI Labels Toggle
    UserJourneyLogger.buttonPressed("Toggle POI Labels",
        showPOILabels ? "POI Labels aktiviert" : "POI Labels deaktiviert");

    notifyListeners();
  }

  bool shouldTriggerReroute() {
    if (_lastRerouteTime == null) return true;
    final timeSinceLastReroute = DateTime.now().difference(_lastRerouteTime!);
    return timeSinceLastReroute.inSeconds >= 3;
  }

  void updateCurrentGpsPosition(LatLng newPosition) {
    currentGpsPosition = newPosition;

    // ✅ LOGGING: GPS Position Update (nur jede 5. Position loggen)
    _navigationSteps++;
    if (_navigationSteps % 5 == 0) {
      UserJourneyLogger.gpsPositionUpdate(
          newPosition.latitude, newPosition.longitude, 10.0 // Mock accuracy
          );
    }

    notifyListeners();
  }

  void updateRemainingRouteInfo(double? distance, int? timeMinutes) {
    remainingRouteDistance = distance;
    remainingRouteTimeMinutes = timeMinutes;

    if (distance != null && timeMinutes != null) {
      if (lastSpokenDistance == null ||
          lastSpokenTime == null ||
          (distance - lastSpokenDistance!).abs() > 100 ||
          (timeMinutes - lastSpokenTime!).abs() >= 1) {
        String announcement = "";
        if (timeMinutes <= 1) {
          announcement = "Destination almost reached.";
        } else if (timeMinutes <= 5) {
          announcement = "About $timeMinutes minutes to destination.";
        }

        if (announcement.isNotEmpty) {
          // ✅ LOGGING: Entfernungsansage
          UserJourneyLogger.turnInstructionIssued(announcement, distance);
          ttsService.speakImmediate(announcement);
        }

        lastSpokenDistance = distance;
        lastSpokenTime = timeMinutes;
      }
    }

    notifyListeners();
  }

  void setCalculatingRoute(bool calculating) {
    isCalculatingRoute = calculating;

    if (calculating) {
      // ✅ LOGGING: Route-Berechnung UI State
      UserJourneyLogger.performanceMetric("Route Calculation UI", 0, "STARTED");
    }

    notifyListeners();
  }

  void setFollowGps(bool follow) {
    followGps = follow;

    if (routePolyline != null && _routePolylines.isNotEmpty) {
      _setModernRoutePolylines(routePolyline!.points);
    }

    if (follow && hasActiveRoute) {
      setSearchInterfaceState(SearchInterfaceState.navigationMode);

      // ✅ LOGGING: Navigation gestartet
      UserJourneyLogger.navigationStarted(follow, "de-DE");
    } else if (!follow) {
      // ✅ LOGGING: GPS Following deaktiviert
      UserJourneyLogger.buttonPressed(
          "Disable GPS Follow", "Follow-GPS Modus deaktiviert");
    }

    notifyListeners();
  }

  void setRouteActiveForCardSwitch(bool active) {
    isRouteActiveForCardSwitch = active;
    notifyListeners();
  }

  void updateCurrentLocationMarker() {
    if (currentGpsPosition != null) {
      currentLocationMarker =
          ModernMapMarkers.createGpsMarker(currentGpsPosition!);
      notifyListeners();
    }
  }

  void updateRouteMetrics(List<LatLng> path) {
    if (path.isEmpty) return;
    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance +=
          distanceCalculatorInstance.distance(path[i], path[i + 1]);
    }
    routeDistance = totalDistance;
    routeTimeMinutes = (totalDistance / 100).ceil();
    notifyListeners();
  }

  void updateCurrentDisplayedManeuver(Maneuver? maneuver) {
    currentDisplayedManeuver = maneuver;

    if (maneuver != null) {
      // ✅ LOGGING: Neue Turn Instruction
      UserJourneyLogger.turnInstructionIssued(
          maneuver.instructionText ?? "Turn instruction",
          50.0 // Default distance
          );
    }

    notifyListeners();
  }

  void setCurrentManeuvers(List<Maneuver> maneuvers) {
    currentManeuvers = maneuvers;

    // ✅ LOGGING: Manöver generiert
    UserJourneyLogger.performanceMetric("Turn Instructions", 0, "GENERATED");

    notifyListeners();
  }

  void setRoutePolyline(Polyline? polyline) {
    routePolyline = polyline;
    if (polyline != null) {
      _setModernRoutePolylines(polyline.points);
    }
    notifyListeners();
  }

  void resetRouteAndNavigation() {
    routePolyline = null;
    _routePolylines.clear();
    _startMarker = null;
    _destinationMarker = null;
    isCalculatingRoute = false;
    currentManeuvers.clear();
    currentDisplayedManeuver = null;
    followGps = false;
    routeDistance = null;
    routeTimeMinutes = null;
    remainingRouteDistance = null;
    remainingRouteTimeMinutes = null;
    isRouteActiveForCardSwitch = false;
    _isRerouting = false;
    _lastRerouteTime = null;
    showRouteInfoAndFadeFields = false;
    _navigationSteps = 0;

    // ✅ LOGGING: Route zurückgesetzt
    UserJourneyLogger.clearRoute();

    setSearchInterfaceState(SearchInterfaceState.expanded);

    notifyListeners();
  }

  void resetSearchFields() {
    startSearchController.clear();
    endSearchController.clear();
    _selectedStart = null;
    _selectedDestination = null;
    _startMarker = null;
    _destinationMarker = null;
    _isMapSelectionMode = false;
    _mapSelectionFor = null;
    _isStartLocked = false;
    _isDestinationLocked = false;

    if (startFocusNode.hasFocus) startFocusNode.unfocus();
    if (endFocusNode.hasFocus) endFocusNode.unfocus();

    showRouteInfoAndFadeFields = false;

    // ✅ LOGGING: Suchfelder zurückgesetzt
    UserJourneyLogger.buttonPressed(
        "Reset Search Fields", "Alle Eingabefelder geleert");

    setSearchInterfaceState(SearchInterfaceState.expanded);

    attemptRouteCalculationOrClearRoute();
    notifyListeners();
  }

  void performInitialMapMove(
      {LocationInfo? newLocation, required BuildContext context}) {
    final locationToCenterOn = newLocation ??
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    if (isMapReady && locationToCenterOn != null) {
      mapController.move(locationToCenterOn.initialCenter, 17.0);

      // ✅ LOGGING: Initiale Karten-Position
      UserJourneyLogger.buttonPressed("Initial Map Move",
          "Karte zentriert auf: ${locationToCenterOn.name}");
    }
  }

  void toggleMockLocation() {
    useMockLocation = !useMockLocation;
    followGps = false;
    resetRouteAndNavigation();

    // ✅ LOGGING: Mock Location Toggle
    UserJourneyLogger.buttonPressed("Toggle Mock GPS",
        useMockLocation ? "Mock GPS aktiviert" : "Real GPS aktiviert");

    notifyListeners();
  }

  void toggleSearchInterfaceMode() {
    showRouteInfoAndFadeFields = !showRouteInfoAndFadeFields;

    if (showRouteInfoAndFadeFields && hasActiveRoute) {
      setSearchInterfaceState(SearchInterfaceState.navigationMode);
    } else {
      setSearchInterfaceState(SearchInterfaceState.expanded);
    }

    // ✅ LOGGING: Interface Mode Toggle
    UserJourneyLogger.buttonPressed("Toggle Interface Mode",
        showRouteInfoAndFadeFields ? "Route Info Modus" : "Such Modus");

    notifyListeners();
  }

  void setRouteInfoAndFadeFields(bool value) {
    if (showRouteInfoAndFadeFields != value) {
      showRouteInfoAndFadeFields = value;

      if (value && hasActiveRoute) {
        setSearchInterfaceState(SearchInterfaceState.navigationMode);
      } else {
        setSearchInterfaceState(SearchInterfaceState.expanded);
      }

      notifyListeners();
    }
  }

  String formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return "unknown";

    if (distanceMeters < 1000) {
      return "${distanceMeters.round()} meters";
    } else {
      return "${(distanceMeters / 1000).toStringAsFixed(1)} kilometers";
    }
  }

  @override
  void dispose() {
    // ✅ LOGGING: Session Ende
    UserJourneyLogger.generateJourneySummary();
    UserJourneyLogger.endSession();

    mapController.dispose();
    ttsService.stop();
    startSearchController.dispose();
    endSearchController.dispose();
    startFocusNode.dispose();
    endFocusNode.dispose();
    super.dispose();
  }
}
