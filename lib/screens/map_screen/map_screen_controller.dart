// lib/screens/map_screen/map_screen_controller.dart - KEYBOARD CRASH FIXED
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';
import 'package:camping_osm_navi/services/tts_service.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
// provider.dart and location_provider.dart are already imported in the original file.

class MapScreenController with ChangeNotifier {
  final MapController mapController = MapController();
  late TtsService ttsService;
  final LocationProvider _locationProvider;

  // State Variables
  Polyline? routePolyline;
  Marker? currentLocationMarker;
  LatLng? currentGpsPosition;

  // New search related state
  SearchableFeature? _selectedStart;
  SearchableFeature? _selectedDestination;
  bool _isStartLocked = false;
  bool _isDestinationLocked = false;
  bool _isMapSelectionMode = false;
  SearchFieldType? _mapSelectionFor;

  // Text editing controllers and focus nodes for new search inputs
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

  // Getters for new search state
  SearchableFeature? get selectedStart => _selectedStart;
  SearchableFeature? get selectedDestination => _selectedDestination;
  bool get isStartLocked => _isStartLocked;
  bool get isDestinationLocked => _isDestinationLocked;
  bool get isMapSelectionActive => _isMapSelectionMode;
  SearchFieldType? get mapSelectionFor => _mapSelectionFor;

  // Constants
  static const double followGpsZoomLevel = 17.5;
  static const LatLng fallbackInitialCenter =
      LatLng(51.02518780487824, 5.858832278816441);
  static const double centerOnGpsMaxDistanceMeters = 5000;
  static const double maneuverReachedThreshold = 15.0;
  static const double significantGpsChangeThreshold = 2.0;
  static const Distance distanceCalculatorInstance = Distance();

  // Getters
  bool get isInRouteOverviewMode => _isInRouteOverviewMode;
  bool get isRerouting => _isRerouting;
  String get maptilerUrlTemplate => _maptilerUrlTemplate;
  bool get isKeyboardVisible => _isKeyboardVisible;
  double get keyboardHeight => _keyboardHeight;
  bool get compactSearchMode => _compactSearchMode;

  MapScreenController(this._locationProvider) { // Modified constructor
    ttsService = TtsService();
    _initializeListeners();
  }

  void _initializeListeners() {
    // Listeners for new focus nodes (optional, if specific logic needed on focus change)
  }

  void initializeMaptilerUrl(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) {
      _maptilerUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    } else {
      _maptilerUrlTemplate =
          'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$apiKey';
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
        } else if (!visible) {
          setCompactSearchMode(false);
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
    notifyListeners();
  }

  void setRouteOverviewMode(bool isOverview) {
    _isInRouteOverviewMode = isOverview;
    notifyListeners();
  }

  void setStartLocation(SearchableFeature feature) {
    _selectedStart = feature;
    _isStartLocked = false;
    startSearchController.text = feature.name;
    _tryCalculateRoute();
    notifyListeners();
  }

  void setDestination(SearchableFeature feature) {
    _selectedDestination = feature;
    _isDestinationLocked = false;
    endSearchController.text = feature.name;
    _tryCalculateRoute();
    notifyListeners();
  }

  void toggleStartLock() {
    _isStartLocked = !_isStartLocked;
    _attemptRouteCalculationOrClearRoute(); // Added call
    notifyListeners();
  }

  void toggleDestinationLock() {
    _isDestinationLocked = !_isDestinationLocked;
    _attemptRouteCalculationOrClearRoute(); // Added call
    notifyListeners();
  }

  Future<void> _attemptRouteCalculationOrClearRoute() async {
    if (isStartLocked && isDestinationLocked && _selectedStart != null && _selectedDestination != null) {
      setCalculatingRoute(true);
      notifyListeners(); // Ensure UI updates for loading state

      // Retrieve the RoutingGraph from LocationProvider
      // This requires access to BuildContext to get the provider.
      // For now, we'll assume a way to access it or pass it.
      // This part might need adjustment depending on how LocationProvider is accessed from the controller.
      // Let's assume a placeholder for graph access for now, and refine if needed.
      // final locationProvider = Provider.of<LocationProvider>(<BuildContext_NEEDS_TO_BE_PASSED_OR_ACCESSED_DIFFERENTLY>, listen: false);
      // final graph = locationProvider.currentRoutingGraph;

      // Placeholder: Directly use a method that can access the graph if available
      // This is a common challenge when a controller needs data from a provider without direct context.
      // A robust solution might involve passing the graph or a graph accessor function.
      // For this subtask, we'll add a comment and proceed with the logic,
      // acknowledging that graph retrieval needs to be handled correctly in the app's architecture.

      final graph = _locationProvider.currentRoutingGraph;

      if (graph == null) {
        setCalculatingRoute(false);
        notifyListeners();
        return;
      }

      final startNode = graph.findNearestNode(_selectedStart!.center);
      final endNode = graph.findNearestNode(_selectedDestination!.center);

      if (startNode != null && endNode != null) {
        graph.resetAllNodeCosts(); // Reset costs before finding a new path
        final List<LatLng>? path = await RoutingService.findPath(graph, startNode, endNode);

        if (path != null && path.isNotEmpty) {
          final maneuvers = RoutingService.analyzeRouteForTurns(path);
          setRoutePolyline(Polyline(points: path, strokeWidth: 4.0, color: Colors.blue));
          setCurrentManeuvers(maneuvers);
          updateRouteMetrics(path); // Calculate and set distance/time
          if (maneuvers.isNotEmpty) {
            updateCurrentDisplayedManeuver(maneuvers.first);
          }
        } else {
          // No path found, clear existing route info
          resetRouteAndNavigation();
          // Optionally, show a message to the user that no route could be found
        }
      } else {
        // Start or end node not found on graph
        resetRouteAndNavigation();
        // Optionally, show a message
      }
      setCalculatingRoute(false);
    } else {
      resetRouteAndNavigation(); // Clear route if not locked or points missing
    }
    notifyListeners();
  }

  void setCurrentLocationAsStart() {
    if (currentGpsPosition != null) {
      final currentLocationFeature = SearchableFeature(
        id: "current_location",
        name: "Aktueller Standort",
        type: "Current Location",
        center: currentGpsPosition!,
      );
      setStartLocation(currentLocationFeature);
    }
    notifyListeners();
  }

  void swapStartAndDestination() {
    final tempFeature = _selectedStart;
    final tempText = startSearchController.text;

    _selectedStart = _selectedDestination;
    startSearchController.text = endSearchController.text;

    _selectedDestination = tempFeature;
    endSearchController.text = tempText;

    _tryCalculateRoute();
    notifyListeners();
  }

  void activateMapSelection(SearchFieldType fieldType) {
    _isMapSelectionMode = true;
    _mapSelectionFor = fieldType;
    notifyListeners();
  }

  void handleMapTapForSelection(LatLng tappedPoint) {
    if (!_isMapSelectionMode || _mapSelectionFor == null) return;

    final mapSelectedFeature = SearchableFeature(
      id: "map_selection_${_mapSelectionFor.toString()}",
      name:
          "Kartenpunkt (${_mapSelectionFor == SearchFieldType.start ? 'Start' : 'Ziel'})",
      type: "Map Selection",
      center: tappedPoint,
    );

    if (_mapSelectionFor == SearchFieldType.start) {
      setStartLocation(mapSelectedFeature);
    } else {
      setDestination(mapSelectedFeature);
    }

    _isMapSelectionMode = false;
    _mapSelectionFor = null;
    notifyListeners();
  }

  void _tryCalculateRoute() {
    _attemptRouteCalculationOrClearRoute();
  }

  void setRerouting(bool rerouting) {
    _isRerouting = rerouting;
    if (rerouting) {
      _lastRerouteTime = DateTime.now();
    }
    notifyListeners();
  }

  void togglePOILabels() {
    showPOILabels = !showPOILabels;
    notifyListeners();
  }

  bool shouldTriggerReroute() {
    if (_lastRerouteTime == null) return true;
    final timeSinceLastReroute = DateTime.now().difference(_lastRerouteTime!);
    return timeSinceLastReroute.inSeconds >= 3;
  }

  void updateCurrentGpsPosition(LatLng newPosition) {
    currentGpsPosition = newPosition;
    notifyListeners();
  }

  void updateRemainingRouteInfo(double? distance, int? timeMinutes) {
    remainingRouteDistance = distance;
    remainingRouteTimeMinutes = timeMinutes;
    notifyListeners();
  }

  void setCalculatingRoute(bool calculating) {
    isCalculatingRoute = calculating;
    notifyListeners();
  }

  void setFollowGps(bool follow) {
    followGps = follow;
    notifyListeners();
  }

  void setRouteActiveForCardSwitch(bool active) {
    isRouteActiveForCardSwitch = active;
    notifyListeners();
  }

  void updateCurrentLocationMarker() {
    if (currentGpsPosition != null) {
      currentLocationMarker = Marker(
        width: 80.0,
        height: 80.0,
        point: currentGpsPosition!,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha((0.2 * 255).round()),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 3.0),
          ),
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 28.0,
          ),
        ),
      );
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
    routeTimeMinutes = (totalDistance / 80).ceil();
    notifyListeners();
  }

  void updateCurrentDisplayedManeuver(Maneuver? maneuver) {
    currentDisplayedManeuver = maneuver;
    notifyListeners();
  }

  void setCurrentManeuvers(List<Maneuver> maneuvers) {
    currentManeuvers = maneuvers;
    notifyListeners();
  }

  void setRoutePolyline(Polyline? polyline) {
    routePolyline = polyline;
    notifyListeners();
  }

  void resetRouteAndNavigation() {
    routePolyline = null;
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
    notifyListeners();
  }

  void resetSearchFields() {
    startSearchController.clear();
    endSearchController.clear();
    _selectedStart = null;
    _selectedDestination = null;
    _isMapSelectionMode = false;
    _mapSelectionFor = null;

    _isStartLocked = false; // Added
    _isDestinationLocked = false; // Added

    if (startFocusNode.hasFocus) startFocusNode.unfocus();
    if (endFocusNode.hasFocus) endFocusNode.unfocus();

    // It's important to also clear the route if search fields are reset
    // and points were potentially locked.
    // Calling _attemptRouteCalculationOrClearRoute() will handle this
    // because the points will be null and locks will be false.
    _attemptRouteCalculationOrClearRoute();

    notifyListeners();
  }

  void performInitialMapMove(
      {LocationInfo? newLocation, required BuildContext context}) {
    final locationToCenterOn = newLocation ??
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    if (isMapReady && locationToCenterOn != null) {
      mapController.move(locationToCenterOn.initialCenter, 17.0);
    }
  }

  void toggleMockLocation() {
    useMockLocation = !useMockLocation;
    followGps = false;
    resetRouteAndNavigation();
    notifyListeners();
  }

  @override
  void dispose() {
    mapController.dispose();
    ttsService.stop();
    startSearchController.dispose();
    endSearchController.dispose();
    startFocusNode.dispose();
    endFocusNode.dispose();
    super.dispose();
  }
}
