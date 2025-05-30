// lib/screens/map_screen/map_screen_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/services/tts_service.dart';

enum ActiveSearchField { none, start, end }

class MapScreenController with ChangeNotifier {
  final MapController mapController = MapController();
  late TtsService ttsService;

  // State Variables
  Polyline? routePolyline;
  Marker? currentLocationMarker;
  Marker? startMarker;
  Marker? endMarker;
  LatLng? currentGpsPosition;
  LatLng? endLatLng;
  LatLng? startLatLng;

  bool isCalculatingRoute = false;
  bool showSearchResults = false;
  bool useMockLocation = true;
  bool isMapReady = false;
  bool followGps = false;
  bool isRouteActiveForCardSwitch = false;
  bool showPOILabels = true; // ✅ NEU: POI-Labels Kontrolle

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

  List<SearchableFeature> searchResults = [];
  ActiveSearchField activeSearchField = ActiveSearchField.none;

  final TextEditingController startSearchController = TextEditingController();
  final TextEditingController endSearchController = TextEditingController();
  final FocusNode startFocusNode = FocusNode();
  final FocusNode endFocusNode = FocusNode();

  double fullSearchCardHeight = 0;
  String _maptilerUrlTemplate = '';

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

  MapScreenController() {
    ttsService = TtsService();
    _initializeListeners();
  }

  void _initializeListeners() {
    startSearchController.addListener(_onStartSearchChanged);
    endSearchController.addListener(_onEndSearchChanged);
    startFocusNode.addListener(_onStartFocusChanged);
    endFocusNode.addListener(_onEndFocusChanged);
  }

  void initializeMaptilerUrl(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) {
      if (kDebugMode) {
        print("WARNUNG: MAPTILER_API_KEY nicht in .env gefunden!");
      }
      _maptilerUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    } else {
      _maptilerUrlTemplate =
          'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$apiKey';
    }
  }

  void setMapReady() {
    isMapReady = true;
    notifyListeners();
  }

  void setFullSearchCardHeight(double height) {
    fullSearchCardHeight = height;
    notifyListeners();
  }

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

  // ✅ NEU: POI Toggle Methode
  void togglePOILabels() {
    showPOILabels = !showPOILabels;
    notifyListeners();
  }

  bool shouldTriggerReroute() {
    if (_lastRerouteTime == null) return true;
    final timeSinceLastReroute = DateTime.now().difference(_lastRerouteTime!);
    return timeSinceLastReroute.inSeconds >=
        3; // RoutingService.rerouteDelaySeconds
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

  void setShowSearchResults(bool show) {
    showSearchResults = show;
    notifyListeners();
  }

  void setSearchResults(List<SearchableFeature> results) {
    searchResults = results;
    notifyListeners();
  }

  void setActiveSearchField(ActiveSearchField field) {
    activeSearchField = field;
    notifyListeners();
  }

  // ✅ SCHÖNE CAMPING-MARKER
  void updateCurrentLocationMarker() {
    if (currentGpsPosition != null) {
      currentLocationMarker = Marker(
        width: 80.0,
        height: 80.0,
        point: currentGpsPosition!,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
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

  void updateStartMarker() {
    if (startLatLng != null &&
        startSearchController.text != "Aktueller Standort") {
      startMarker = Marker(
        point: startLatLng!,
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 32.0,
          ),
        ),
      );
    } else {
      startMarker = null;
    }
    notifyListeners();
  }

  void updateEndMarker() {
    if (endLatLng != null) {
      endMarker = Marker(
        point: endLatLng!,
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: const Icon(
            Icons.flag,
            color: Colors.white,
            size: 32.0,
          ),
        ),
      );
    } else {
      endMarker = null;
    }
    notifyListeners();
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
    searchResults.clear();
    showSearchResults = false;
    startLatLng = null;
    endLatLng = null;
    startMarker = null;
    endMarker = null;
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

  void setStartLatLng(LatLng? latLng) {
    startLatLng = latLng;
    notifyListeners();
  }

  void setEndLatLng(LatLng? latLng) {
    endLatLng = latLng;
    notifyListeners();
  }

  void toggleMockLocation() {
    useMockLocation = !useMockLocation;
    followGps = false;
    resetRouteAndNavigation();
    notifyListeners();
  }

  void swapStartAndEnd() {
    final tempName = startSearchController.text;
    final tempLatLng = startLatLng;

    startSearchController.text = endSearchController.text;
    startLatLng = endLatLng;
    endSearchController.text = tempName;
    endLatLng = tempLatLng;

    updateStartMarker();
    updateEndMarker();
    notifyListeners();
  }

  void unfocusSearchFieldsAndCollapse() {
    if (startFocusNode.hasFocus) {
      startFocusNode.unfocus();
    }
    if (endFocusNode.hasFocus) {
      endFocusNode.unfocus();
    }
    if (routePolyline != null) {
      isRouteActiveForCardSwitch = true;
      notifyListeners();
    }
  }

  // Focus and Search Listeners
  void _onStartSearchChanged() {
    // This will be handled by SearchHandler
  }

  void _onEndSearchChanged() {
    // This will be handled by SearchHandler
  }

  void _onStartFocusChanged() {
    if (startFocusNode.hasFocus) {
      activeSearchField = ActiveSearchField.start;
      isRouteActiveForCardSwitch = false;
    } else {
      if (activeSearchField == ActiveSearchField.start) {
        activeSearchField = ActiveSearchField.none;
      }
    }
    notifyListeners();
  }

  void _onEndFocusChanged() {
    if (endFocusNode.hasFocus) {
      activeSearchField = ActiveSearchField.end;
      isRouteActiveForCardSwitch = false;
    } else {
      if (activeSearchField == ActiveSearchField.end) {
        activeSearchField = ActiveSearchField.none;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    mapController.dispose();
    ttsService.stop();
    startSearchController.removeListener(_onStartSearchChanged);
    startSearchController.dispose();
    endSearchController.removeListener(_onEndSearchChanged);
    endSearchController.dispose();
    startFocusNode.removeListener(_onStartFocusChanged);
    startFocusNode.dispose();
    endFocusNode.removeListener(_onEndFocusChanged);
    endFocusNode.dispose();
    super.dispose();
  }
}
