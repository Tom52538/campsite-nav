// lib/screens/map_screen/map_screen_controller.dart - KEYBOARD CRASH FIXED
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
// import 'package:camping_osm_navi/models/searchable_feature.dart'; // REMOVED
import 'package:camping_osm_navi/services/tts_service.dart';

// enum ActiveSearchField { none, start, end } // REMOVED

class MapScreenController with ChangeNotifier {
  final MapController mapController = MapController();
  late TtsService ttsService;

  // State Variables
  Polyline? routePolyline;
  Marker? currentLocationMarker;
  // Marker? startMarker; // REMOVED
  // Marker? endMarker; // REMOVED
  LatLng? currentGpsPosition;
  // LatLng? endLatLng; // REMOVED
  // LatLng? startLatLng; // REMOVED

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
    // ✅ FIXED: Wrap focus listeners in addPostFrameCallback to prevent setState during build
    // startFocusNode.addListener(_onStartFocusChanged); // REMOVED
    // endFocusNode.addListener(_onEndFocusChanged); // REMOVED
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
        if (visible) { // MODIFIED - Condition related to focus nodes removed
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

  LatLngBounds _calculateBoundsForPoints(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(fallbackInitialCenter, fallbackInitialCenter);
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  void setMapReady() {
    isMapReady = true;
    notifyListeners();
  }

  // REMOVED setFullSearchCardHeight

  void setRouteOverviewMode(bool isOverview) {
    _isInRouteOverviewMode = isOverview;
    notifyListeners();
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
    // startSearchController.clear(); // REMOVED
    // endSearchController.clear(); // REMOVED
    // searchResults.clear(); // REMOVED
    // showSearchResults = false; // REMOVED
    // startLatLng = null; // REMOVED
    // endLatLng = null; // REMOVED
    // startMarker = null; // REMOVED
    // endMarker = null; // REMOVED
    // visibleSearchResults.clear(); // REMOVED
    // setShowHorizontalPOIStrip(false); // REMOVED
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
    // startSearchController.dispose(); // REMOVED
    // endSearchController.dispose(); // REMOVED
    // startFocusNode.removeListener(_onStartFocusChanged); // REMOVED
    // startFocusNode.dispose(); // REMOVED
    // endFocusNode.removeListener(_onEndFocusChanged); // REMOVED
    // endFocusNode.dispose(); // REMOVED
    super.dispose();
  }
}
