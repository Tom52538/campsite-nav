// lib/screens/map_screen/map_screen_controller.dart - IMPORT FIXES & SMARTPHONE OPTIMIERT
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/search_types.dart'; // ✅ FIX: SearchFieldType Import
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/widgets/modern_map_markers.dart';
import 'package:camping_osm_navi/services/tts_service.dart';
import 'package:camping_osm_navi/services/routing_service.dart';

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
  SearchFieldType? _mapSelectionFor; // ✅ FIX: Type verfügbar

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

  // ✅ Smartphone UX States
  SearchInterfaceState _searchInterfaceState = SearchInterfaceState.expanded;
  bool _autoHideAfterRoute = true;

  // Getters
  Marker? get startMarker => _startMarker;
  Marker? get destinationMarker => _destinationMarker;
  List<Polyline> get routePolylines => _routePolylines;

  SearchableFeature? get selectedStart => _selectedStart;
  SearchableFeature? get selectedDestination => _selectedDestination;
  bool get isStartLocked => _isStartLocked;
  bool get isDestinationLocked => _isDestinationLocked;
  bool get isMapSelectionActive => _isMapSelectionMode;
  SearchFieldType? get mapSelectionFor => _mapSelectionFor; // ✅ FIX: Type verfügbar

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

  // ✅ Smartphone UX Getters
  SearchInterfaceState get searchInterfaceState => _searchInterfaceState;
  bool get shouldAutoHideInterface => _autoHideAfterRoute && hasActiveRoute;

  bool get hasActiveRoute => routePolyline != null &&
                            _selectedStart != null &&
                            _selectedDestination != null;

  bool get shouldShowCompactMode => hasActiveRoute &&
                                    isStartLocked &&
                                    isDestinationLocked;

  MapScreenController(this._locationProvider) {
    ttsService = TtsService();
    _initializeListeners();
  }

  void _initializeListeners() {
    // Listeners für Smartphone UX
    startSearchController.addListener(_onSearchTextChanged);
    endSearchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    // Auto-expand Interface wenn User tippt
    if (_searchInterfaceState != SearchInterfaceState.expanded) {
      setSearchInterfaceState(SearchInterfaceState.expanded);
    }
  }

  // ✅ Smartphone UX Methods
  void setSearchInterfaceState(SearchInterfaceState newState) {
    if (_searchInterfaceState != newState) {
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
        
        // ✅ Smartphone UX: Interface erweitern bei Keyboard
        if (visible) {
          setCompactSearchMode(true);
          setSearchInterfaceState(SearchInterfaceState.expanded);
        } else if (!visible) {
          setCompactSearchMode(false);
          // Auto-hide nur wenn Route aktiv und Auto-Hide aktiviert
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
    notifyListeners();
  }

  void setRouteOverviewMode(bool isOverview) {
    _isInRouteOverviewMode = isOverview;
    notifyListeners();
  }

  // ✅ MODERNISIERTE START LOCATION METHODE
  void setStartLocation(SearchableFeature feature) {
    _selectedStart = feature;
    _isStartLocked = false;
    startSearchController.text = feature.name;
    showRouteInfoAndFadeFields = false;
    
    // ✅ NEU: Erstelle modernen Start Marker
    _startMarker = ModernMapMarkers.createStartMarker(
      feature.center,
      label: feature.name,
    );
    
    _tryCalculateRoute();
    
    // ✅ Smartphone UX: Auto-collapse nach Auswahl
    if (_selectedDestination != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (hasActiveRoute) {
          setSearchInterfaceState(SearchInterfaceState.collapsed);
        }
      });
    }
    
    notifyListeners();
  }

  // ✅ MODERNISIERTE DESTINATION METHODE
  void setDestination(SearchableFeature feature) {
    _selectedDestination = feature;
    _isDestinationLocked = false;
    endSearchController.text = feature.name;
    showRouteInfoAndFadeFields = false;
    
    // ✅ NEU: Erstelle modernen Destination Marker
    _destinationMarker = ModernMapMarkers.createDestinationMarker(
      feature.center,
      label: feature.name,
    );
    
    _tryCalculateRoute();
    
    // ✅ Smartphone UX: Auto-collapse nach Auswahl
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
    attemptRouteCalculationOrClearRoute();
    notifyListeners();
  }

  void toggleDestinationLock() {
    _isDestinationLocked = !_isDestinationLocked;
    attemptRouteCalculationOrClearRoute();
    notifyListeners();
  }

  Future<void> attemptRouteCalculationOrClearRoute() async {
    if (isStartLocked &&
        isDestinationLocked &&
        _selectedStart != null &&
        _selectedDestination != null) {

      setCalculatingRoute(true);
      notifyListeners();

      final graph = _locationProvider.currentRoutingGraph;
      if (graph == null) {
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
          
          // ✅ NEU: Erstelle moderne Route mit Gradient
          _setModernRoutePolylines(path);
          
          setCurrentManeuvers(maneuvers);
          updateRouteMetrics(path);

          if (maneuvers.isNotEmpty) {
            updateCurrentDisplayedManeuver(maneuvers.first);
          }

          showRouteInfoAndFadeFields = true;
          
          // ✅ Smartphone UX: Auto-transition zu Navigation Mode
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (shouldAutoHideInterface) {
              setSearchInterfaceState(SearchInterfaceState.navigationMode);
            }
          });
          
          ttsService.speakImmediate("Route calculated. ${formatDistance(routeDistance)} in about $routeTimeMinutes minutes.");

        } else {
          resetRouteAndNavigation();
          showRouteInfoAndFadeFields = false;
        }
      } else {
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

  // ✅ NEU: Moderne Route Polylines erstellen
  void _setModernRoutePolylines(List<LatLng> path) {
    if (followGps && currentGpsPosition != null) {
      // Während Navigation: Gradient Route
      _routePolylines = ModernRoutePolyline.createGradientRoute(path);
      routePolyline = ModernRoutePolyline.createNavigationRoute(path);
    } else {
      // Normal: Einfache moderne Route
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

    // ✅ NEU: Marker Types nach Swap anpassen
    if (_selectedStart != null) {
      _startMarker = ModernMapMarkers.createStartMarker(_selectedStart!.center);
    }
    if (_selectedDestination != null) {
      _destinationMarker = ModernMapMarkers.createDestinationMarker(_selectedDestination!.center);
    }

    showRouteInfoAndFadeFields = false;
    _tryCalculateRoute();
    notifyListeners();
  }

  void activateMapSelection(SearchFieldType fieldType) {
    _isMapSelectionMode = true;
    _mapSelectionFor = fieldType;
    
    // ✅ Smartphone UX: Interface verstecken für Karten-Selektion
    setSearchInterfaceState(SearchInterfaceState.hidden);
    
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

    if (_mapSelectionFor == SearchFieldType.start) {
      setStartLocation(mapSelectedFeature);
    } else {
      setDestination(mapSelectedFeature);
    }

    _isMapSelectionMode = false;
    _mapSelectionFor = null;
    
    // ✅ Smartphone UX: Interface wieder anzeigen
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

    if (distance != null && timeMinutes != null) {
      if (lastSpokenDistance == null || lastSpokenTime == null ||
          (distance - lastSpokenDistance!).abs() > 100 ||
          (timeMinutes - lastSpokenTime!).abs() >= 1) {

        if (timeMinutes <= 1) {
          ttsService.speakImmediate("Destination almost reached.");
        } else if (timeMinutes <= 5) {
          ttsService.speakImmediate("About $timeMinutes minutes to destination.");
        }

        lastSpokenDistance = distance;
        lastSpokenTime = timeMinutes;
      }
    }

    notifyListeners();
  }

  void setCalculatingRoute(bool calculating) {
    isCalculatingRoute = calculating;
    notifyListeners();
  }

  void setFollowGps(bool follow) {
    followGps = follow;
    // ✅ NEU: Route Style ändern bei GPS Follow
    if (routePolyline != null && _routePolylines.isNotEmpty) {
      _setModernRoutePolylines(routePolyline!.points);
    }
    
    // ✅ Smartphone UX: Navigation Mode aktivieren
    if (follow && hasActiveRoute) {
      setSearchInterfaceState(SearchInterfaceState.navigationMode);
    }
    
    notifyListeners();
  }

  void setRouteActiveForCardSwitch(bool active) {
    isRouteActiveForCardSwitch = active;
    notifyListeners();
  }

  // ✅ MODERNISIERTE GPS MARKER METHODE
  void updateCurrentLocationMarker() {
    if (currentGpsPosition != null) {
      currentLocationMarker = ModernMapMarkers.createGpsMarker(currentGpsPosition!);
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
    notifyListeners();
  }

  void setCurrentManeuvers(List<Maneuver> maneuvers) {
    currentManeuvers = maneuvers;
    notifyListeners();
  }

  void setRoutePolyline(Polyline? polyline) {
    routePolyline = polyline;
    if (polyline != null) {
      _setModernRoutePolylines(polyline.points);
    }
    notifyListeners();
  }

  // ✅ ERWEITERTE RESET METHODE
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
    
    // ✅ Smartphone UX: Interface zurück zu expanded
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
    
    // ✅ Smartphone UX: Interface zurück zu expanded
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
    }
  }

  void toggleMockLocation() {
    useMockLocation = !useMockLocation;
    followGps = false;
    resetRouteAndNavigation();
    notifyListeners();
  }

  void toggleSearchInterfaceMode() {
    showRouteInfoAndFadeFields = !showRouteInfoAndFadeFields;
    
    // ✅ Smartphone UX: State entsprechend anpassen
    if (showRouteInfoAndFadeFields && hasActiveRoute) {
      setSearchInterfaceState(SearchInterfaceState.navigationMode);
    } else {
      setSearchInterfaceState(SearchInterfaceState.expanded);
    }
    
    notifyListeners();
  }

  void setRouteInfoAndFadeFields(bool value) {
    if (showRouteInfoAndFadeFields != value) {
      showRouteInfoAndFadeFields = value;
      
      // ✅ Smartphone UX: State entsprechend anpassen
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
    mapController.dispose();
    ttsService.stop();
    startSearchController.dispose();
    endSearchController.dispose();
    startFocusNode.dispose();
    endFocusNode.dispose();
    super.dispose();
  }
}