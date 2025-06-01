// lib/screens/map_screen/map_screen_controller.dart - KEYBOARD CRASH FIXED
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart'; // For SearchFieldType
import 'package:camping_osm_navi/services/tts_service.dart';

class MapScreenController with ChangeNotifier {
  final MapController mapController = MapController();
  late TtsService ttsService;

  // State Variables
  Polyline? routePolyline;
  Marker? currentLocationMarker;
  LatLng? currentGpsPosition;

  // New search related state
  SearchableFeature? _selectedStart;
  SearchableFeature? _selectedDestination;
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

  // List<SearchableFeature> searchResults = []; // REMOVED
  // List<SearchableFeature> visibleSearchResults = []; // REMOVED

  // ActiveSearchField activeSearchField = ActiveSearchField.none; // REMOVED

  // final TextEditingController startSearchController = TextEditingController(); // REMOVED
  // final TextEditingController endSearchController = TextEditingController(); // REMOVED
  // final FocusNode startFocusNode = FocusNode(); // REMOVED
  // final FocusNode endFocusNode = FocusNode(); // REMOVED

  // double fullSearchCardHeight = 0; // REMOVED
  String _maptilerUrlTemplate = '';

  bool _isKeyboardVisible = false;
  double _keyboardHeight = 0;
  bool _compactSearchMode = false;
  // bool _showHorizontalPOIStrip = false; // REMOVED

  // Getters for new search state
  SearchableFeature? get selectedStart => _selectedStart;
  SearchableFeature? get selectedDestination => _selectedDestination;
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
  // bool get showHorizontalPOIStrip => _showHorizontalPOIStrip; // REMOVED

  MapScreenController() {
    ttsService = TtsService();
    _initializeListeners();
  }

  void _initializeListeners() {
    // Listeners for new focus nodes (optional, if specific logic needed on focus change)
    // startFocusNode.addListener(_onNewStartFocusChanged);
    // endFocusNode.addListener(_onNewEndFocusChanged);
  }

  void initializeMaptilerUrl(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) {
      _maptilerUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    } else {
      _maptilerUrlTemplate =
          'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$apiKey';
    }
  }

  // REMOVED _onStartFocusChanged
  // REMOVED _onEndFocusChanged

  // ✅ FIXED: Keyboard visibility updates now use addPostFrameCallback
  void updateKeyboardVisibility(bool visible, double height) {
    if (visible != _isKeyboardVisible ||
        (height - _keyboardHeight).abs() > 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isKeyboardVisible = visible;
        _keyboardHeight = height;

        // if (visible && (startFocusNode.hasFocus || endFocusNode.hasFocus)) { // MODIFIED
        if (visible) {
          // MODIFIED - Condition related to focus nodes removed
          setCompactSearchMode(true);
          // if (visibleSearchResults.isNotEmpty) { // REMOVED
          //   setShowHorizontalPOIStrip(true); // REMOVED
          // }
        } else if (!visible) {
          setCompactSearchMode(false);
          // setShowHorizontalPOIStrip(false); // REMOVED
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

  // void setShowHorizontalPOIStrip(bool show) { // REMOVED
  //   if (_showHorizontalPOIStrip != show) {
  //     _showHorizontalPOIStrip = show;
  //     notifyListeners();
  //   }
  // }

  // void setVisibleSearchResults(List<SearchableFeature> results) { // REMOVED
  //   visibleSearchResults = results;
  //
  //   if (isKeyboardVisible && results.isNotEmpty) {
  //     setShowHorizontalPOIStrip(true);
  //   } else if (results.isEmpty) {
  //     setShowHorizontalPOIStrip(false);
  //   }
  //
  //   notifyListeners();
  // }

  // void clearVisibleSearchResults() { // REMOVED
  //   visibleSearchResults.clear();
  //   setShowHorizontalPOIStrip(false);
  //   notifyListeners();
  // }

  // void autoZoomToPOIsWithKeyboard(BuildContext context) { // REMOVED
  // }

  // REMOVED: _calculateBoundsForPoints - unused method

  void setMapReady() {
    isMapReady = true;
    notifyListeners();
  }

  // REMOVED setFullSearchCardHeight

  void setRouteOverviewMode(bool isOverview) {
    _isInRouteOverviewMode = isOverview;
    notifyListeners();
  }

  // New search methods
  void setStartLocation(SearchableFeature feature) {
    _selectedStart = feature;
    startSearchController.text = feature.name;
    // Potentially update map marker if needed
    _tryCalculateRoute();
    notifyListeners();
  }

  void setDestination(SearchableFeature feature) {
    _selectedDestination = feature;
    endSearchController.text = feature.name;
    // Potentially update map marker if needed
    _tryCalculateRoute();
    notifyListeners();
  }

  void setCurrentLocationAsStart() {
    if (currentGpsPosition != null) {
      // Create a SearchableFeature from current GPS or use a predefined "Current Location" feature
      // This might require fetching reverse geocoded name or using a generic name
      final currentLocationFeature = SearchableFeature(
        id: "current_location",
        name: "Aktueller Standort",
        type: "Current Location",
        lat: currentGpsPosition!.latitude,
        lon: currentGpsPosition!.longitude,
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
    // Optionally, provide user feedback (e.g., SnackBar) that map selection is active
    // This is handled in SimpleSearchContainer, but could also be here.
    notifyListeners();
  }

  void handleMapTapForSelection(LatLng tappedPoint) {
    if (!_isMapSelectionMode || _mapSelectionFor == null) return;

    // Create a SearchableFeature from tapped point.
    // This might require reverse geocoding for name/type or using generic "Map Selection"
    final mapSelectedFeature = SearchableFeature(
      id: "map_selection_${_mapSelectionFor.toString()}",
      name: "Kartenpunkt (${_mapSelectionFor == SearchFieldType.start ? 'Start' : 'Ziel'})",
      type: "Map Selection",
      lat: tappedPoint.latitude,
      lon: tappedPoint.longitude,
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
    if (_selectedStart != null && _selectedDestination != null) {
      // This is where you'd call your actual route calculation service
      // For now, it just sets calculating to true and then false as a placeholder
      // And potentially updates route polyline, distance, time etc.
      // Example:
      // setCalculatingRoute(true);
      // final routeData = await routeService.calculate(_selectedStart!, _selectedDestination!);
      // if (routeData != null) {
      //   setRoutePolyline(routeData.polyline);
      //   updateRouteMetrics(routeData.path); // Assuming routeData has a path
      //   setCurrentManeuvers(routeData.maneuvers);
      // }
      // setCalculatingRoute(false);
      print("Route calculation triggered for Start: ${_selectedStart!.name} to Dest: ${_selectedDestination!.name}");
    }
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
    // if (!showPOILabels) { // REMOVED
    //   visibleSearchResults.clear(); // REMOVED
    //   setShowHorizontalPOIStrip(false); // REMOVED
    // }
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

  // void setShowSearchResults(bool show) { // REMOVED
  //   showSearchResults = show;
  //   notifyListeners();
  // }

  // void setSearchResults(List<SearchableFeature> results) { // REMOVED
  //   searchResults = results;
  //   notifyListeners();
  // }

  // REMOVED setActiveSearchField

  void updateCurrentLocationMarker() {
    if (currentGpsPosition != null) {
      currentLocationMarker = Marker(
        width: 80.0,
        height: 80.0,
        point: currentGpsPosition!,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
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

  // REMOVED updateStartMarker
  // REMOVED updateEndMarker

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
    // Reset markers if they are tied to _selectedStart/_selectedDestination
    // startMarker = null;
    // endMarker = null;
    _isMapSelectionMode = false;
    _mapSelectionFor = null;

    // Clear focus
    if (startFocusNode.hasFocus) startFocusNode.unfocus();
    if (endFocusNode.hasFocus) endFocusNode.unfocus();

    // Reset other search related states that were removed if any new ones replace them
    // searchResults.clear(); // If you re-introduce a general search result list
    // showSearchResults = false; // If you re-introduce a general search result visibility flag
    // visibleSearchResults.clear();
    // setShowHorizontalPOIStrip(false);
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

  // REMOVED setStartLatLng
  // REMOVED setEndLatLng

  void toggleMockLocation() {
    useMockLocation = !useMockLocation;
    followGps = false;
    resetRouteAndNavigation();
    notifyListeners();
  }

  // REMOVED swapStartAndEnd
  // REMOVED unfocusSearchFieldsAndCollapse

  @override
  void dispose() {
    mapController.dispose();
    ttsService.stop();
    startSearchController.dispose();
    endSearchController.dispose();
    startFocusNode.dispose();
    endFocusNode.dispose();
    // Remove new focus node listeners if they were added
    // startFocusNode.removeListener(_onNewStartFocusChanged);
    // endFocusNode.removeListener(_onNewEndFocusChanged);
    super.dispose();
  }
}
