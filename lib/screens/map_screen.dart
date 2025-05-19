// lib/screens/map_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
// Import für CancellableNetworkTileProvider wird nicht mehr zwingend benötigt,
// wenn wir den Standard-TileProvider von flutter_map mit einem CORS-Proxy verwenden.
// import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:provider/provider.dart';

// Eigene Imports
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static const double searchCardTopPadding = 8.0;
  static const double searchInputRowHeight = 40.0;
  static const double dividerAndSwapButtonHeight = 28.0;
  static const double routeInfoHeight = 30.0;
  static const double cardInternalVerticalPadding = 4.0;
  static const double searchCardMaxWidth = 360.0;
  static const double searchCardHorizontalMargin = 10.0;
  static const double instructionCardSpacing = 5.0;

  @override
  MapScreenState createState() => MapScreenState();
}

enum ActiveSearchField { none, start, end }

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
  List<SearchableFeature> _searchResults = [];
  bool _showSearchResults = false;

  bool _useMockLocation = true;
  bool _isMapReady = false;

  LocationInfo? _lastProcessedLocation;

  double? _routeDistance;
  int? _routeTimeMinutes;

  List<Maneuver> _currentManeuvers = [];
  Maneuver? _currentDisplayedManeuver;
  bool _followGps = false;
  static const double _followGpsZoomLevel = 17.5;

  static const LatLng fallbackInitialCenter =
      LatLng(51.02518780487824, 5.858832278816441);
  static const double markerWidth = 40.0;
  static const double markerHeight = 40.0;
  static const double centerOnGpsMaxDistanceMeters = 5000;

  final TextEditingController _startSearchController = TextEditingController();
  final TextEditingController _endSearchController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  LatLng? _startLatLng;
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
    final newLocationInfo = locationProvider.selectedLocation;

    if (newLocationInfo != null &&
        (_lastProcessedLocation == null ||
            newLocationInfo.id != _lastProcessedLocation!.id)) {
      if (kDebugMode) {
        print(
            "<<< didChangeDependencies: Standortwechsel/Initialisierung für ${newLocationInfo.name}. Vorheriger: ${_lastProcessedLocation?.name} >>>");
      }
      _handleLocationChangeUIUpdates(newLocationInfo);
      _lastProcessedLocation = newLocationInfo;
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
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
    final bool hasFocus = _startFocusNode.hasFocus;
    setStateIfMounted(() {
      if (hasFocus) {
        _activeSearchField = ActiveSearchField.start;
        _showSearchResults =
            _startSearchController.text.isNotEmpty && _searchResults.isNotEmpty;
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted &&
              !_startFocusNode.hasFocus &&
              _activeSearchField == ActiveSearchField.start) {
            setStateIfMounted(() {
              _showSearchResults = false;
            });
          }
        });
      }
    });
  }

  void _onEndFocusChanged() {
    if (!mounted) {
      return;
    }
    final bool hasFocus = _endFocusNode.hasFocus;
    setStateIfMounted(() {
      if (hasFocus) {
        _activeSearchField = ActiveSearchField.end;
        _showSearchResults =
            _endSearchController.text.isNotEmpty && _searchResults.isNotEmpty;
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted &&
              !_endFocusNode.hasFocus &&
              _activeSearchField == ActiveSearchField.end) {
            setStateIfMounted(() {
              _showSearchResults = false;
            });
          }
        });
      }
    });
  }

  void _onLocationSelectedFromDropdown(LocationInfo? newLocationParam) {
    if (newLocationParam == null) {
      return;
    }
    Provider.of<LocationProvider>(context, listen: false)
        .selectLocation(newLocationParam);
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
      _routeDistance = null;
      _routeTimeMinutes = null;
      _currentManeuvers = [];
      _currentDisplayedManeuver = null;
      _followGps = false;
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
      _followGps = !_useMockLocation && _routePolyline != null;
      if (!_useMockLocation &&
          _startSearchController.text.toLowerCase().contains("mock position")) {
        _startLatLng = null;
        _startMarker = null;
        _startSearchController.clear();
        _routePolyline = null;
        _routeDistance = null;
        _routeTimeMinutes = null;
        _currentManeuvers = [];
        _currentDisplayedManeuver = null;
        _followGps = false;
      }
      if (currentLocation != null) {
        _initializeGpsOrMock(currentLocation);
      }
    });
    _showSnackbar(
        _useMockLocation
            ? "Mock-Position (${currentLocation?.name ?? 'Fallback'}) aktiviert."
            : "Echtes GPS aktiviert. Follow-Modus ${_followGps ? "an" : "aus"}.",
        durationSeconds: 4);
  }

  void _initializeGpsOrMock(LocationInfo location) {
    _positionStreamSubscription?.cancel();
    LatLng? oldGpsPosition = _currentGpsPosition;

    setStateIfMounted(() {
      _currentGpsPosition = null;
      _currentLocationMarker = null;
    });
    final LatLng activeInitialCenterForMock = location.initialCenter;

    if (_useMockLocation) {
      setStateIfMounted(() => _followGps = false);
      if (kDebugMode) {
        print(
            "<<< _initializeGpsOrMock: Mock-Modus AKTIV. Setze Position auf initialCenter von ${location.name}: $activeInitialCenterForMock. >>>");
      }
      if (mounted) {
        setState(() {
          _currentGpsPosition = activeInitialCenterForMock;
          _currentLocationMarker = _createMarker(
              activeInitialCenterForMock,
              Colors.orangeAccent,
              Icons.pin_drop,
              "Mock Position (${location.name})");
          if (_startSearchController.text == "Aktueller Standort" ||
              (_startSearchController.text
                      .toLowerCase()
                      .contains("mock position") &&
                  oldGpsPosition != _currentGpsPosition)) {
            _startLatLng =
                activeInitialCenterForMock; 
            _startMarker = _createMarker(
                _startLatLng!,
                Colors.green, 
                Icons.flag_circle,
                "Start: Mock Position (${location.name})");
            _startSearchController.text = "Mock Position (${location.name})";
          }
        });
        if (_isMapReady && mounted) {
          _mapController.move(activeInitialCenterForMock, _followGpsZoomLevel);
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
      return;
    }
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final location = locationProvider.selectedLocation;
    if (location == null) {
      return;
    }

    LatLng? targetToMoveToNullSafe;
    if (_useMockLocation) {
      targetToMoveToNullSafe = _currentGpsPosition ?? location.initialCenter;
    } else {
      if (_currentGpsPosition != null) {
        const distance = Distance();
        if (distance(_currentGpsPosition!, location.initialCenter) <=
            centerOnGpsMaxDistanceMeters) {
          targetToMoveToNullSafe = _currentGpsPosition;
        } else {
          targetToMoveToNullSafe = location.initialCenter;
        }
      } else {
        targetToMoveToNullSafe = location.initialCenter;
      }
    }

    if (mounted && targetToMoveToNullSafe != null) { 
      _mapController.move(targetToMoveToNullSafe,
          _followGps && !_useMockLocation ? _followGpsZoomLevel : 17.0);
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
          "<<< _selectFeatureAndSetPoint: Feature ${feature.name} für Feld $_activeSearchField >>>");
    }
    if (!mounted) {
      return;
    }

    TextEditingController? controllerToUpdate;
    FocusNode focusToUnset; 
    FocusNode? nextFocus;
    bool isStartField = _activeSearchField == ActiveSearchField.start;

    if (isStartField) {
      controllerToUpdate = _startSearchController;
      focusToUnset = _startFocusNode;
      nextFocus = _endSearchController.text.isEmpty ? _endFocusNode : null;
      setStateIfMounted(() {
        _startLatLng = feature.center;
        _startMarker = _createMarker(feature.center, Colors.green,
            Icons.flag_circle, "Start: ${feature.name}");
      });
    } else if (_activeSearchField == ActiveSearchField.end) {
      controllerToUpdate = _endSearchController;
      focusToUnset = _endFocusNode;
      nextFocus = _startSearchController.text.isEmpty ? _startFocusNode : null;
      setStateIfMounted(() {
        _endLatLng = feature.center;
        _endMarker = _createMarker(feature.center, Colors.red,
            Icons.flag_circle, "Ziel: ${feature.name}");
      });
    } else {
      if (kDebugMode) {
        print(
            "<<< _selectFeatureAndSetPoint: Kein aktives Suchfeld für Auswahl! >>>");
      }
      return;
    }

    if (controllerToUpdate != null) { 
        controllerToUpdate.value = TextEditingValue(
        text: feature.name,
        selection: TextSelection.fromPosition(
            TextPosition(offset: feature.name.length)),
        );
    }
  
    setStateIfMounted(() {
      _showSearchResults = false;
      _searchResults = [];
      _followGps = false;
    });

    focusToUnset.unfocus(); 

    if (nextFocus != null) {
      FocusScope.of(context).requestFocus(nextFocus);
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
      print("<<< _initializeGpsReal für ${location.name} >>>");
    }
    if (!mounted) {
      return;
    }

    late LocationPermission permission;
    bool serviceEnabled;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showErrorDialog("GPS ist deaktiviert.");
          setStateIfMounted(() => _followGps = false);
        }
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showErrorDialog("GPS-Berechtigung verweigert.");
            setStateIfMounted(() => _followGps = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showErrorDialog("GPS-Berechtigung dauerhaft verweigert.");
          setStateIfMounted(() => _followGps = false);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog("Fehler GPS-Berechtigungen: $e");
        setStateIfMounted(() => _followGps = false);
      }
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
      LatLng newGpsPos = LatLng(position.latitude, position.longitude);

      setStateIfMounted(() {
        _currentGpsPosition = newGpsPos;
        _currentLocationMarker = _createMarker(
            newGpsPos, Colors.blueAccent, Icons.circle, "Meine Position");
        if (_startSearchController.text == "Aktueller Standort") {
          _startLatLng = _currentGpsPosition;
          if (_startLatLng != null) {
            _startMarker = _createMarker(_startLatLng!, Colors.green,
                Icons.flag_circle, "Start: Aktueller Standort");
          }
        }
      });

      if (_followGps && _isMapReady && mounted && _currentGpsPosition != null) {
        _mapController.move(_currentGpsPosition!, _followGpsZoomLevel);
      } else if (isFirstFix &&
          _currentGpsPosition != null &&
          _isMapReady &&
          mounted) {
        const distance = Distance();
        final double meters =
            distance(_currentGpsPosition!, centerForDistanceCheck);
        if (meters <= centerOnGpsMaxDistanceMeters) {
          _mapController.move(_currentGpsPosition!, _followGpsZoomLevel);
        } else {
          _showSnackbar(
              "Echte GPS-Position zu weit entfernt vom aktuellen Standort.",
              durationSeconds: 4);
        }
      }
      if (_startLatLng != null && _endLatLng != null && !_isCalculatingRoute) {
        _calculateAndDisplayRoute();
      }
    }, onError: (error) {
      _showErrorDialog("Fehler GPS-Empfang: $error");
      if (mounted) {
        setStateIfMounted(() => _followGps = false);
      }
    });
  }

  Marker _createMarker(
      LatLng position, Color color, IconData icon, String tooltip,
      {double size = 30.0}) {
    return Marker(
      width: markerWidth,
      height: markerHeight,
      point: position,
      alignment: Alignment.center,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: size),
      ),
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
          "<<< _calculateAndDisplayRoute: Start: $_startLatLng, Ziel: $_endLatLng >>>");
    }
    if (!mounted) {
      return;
    }

    setStateIfMounted(() {
      _routeDistance = null;
      _routeTimeMinutes = null;
      _currentManeuvers = [];
      _currentDisplayedManeuver = null;
    });

    if (!isDataReadyForRouting) {
      _showErrorDialog(
          "Kartendaten für ${selectedLocationFromProvider?.name ?? ''} nicht bereit.");
      setStateIfMounted(() {
        _isCalculatingRoute = false;
        _followGps = false;
      });
      return;
    }

    if (currentGraph.nodes.isEmpty) { 
      _showErrorDialog(
          "Routing-Daten für ${selectedLocationFromProvider?.name ?? ''} nicht verfügbar.");
      setStateIfMounted(() {
        _isCalculatingRoute = false;
        _followGps = false;
      });
      return;
    }

    if (_startLatLng == null || _endLatLng == null) {
      setStateIfMounted(() {
        _routePolyline = null;
        _isCalculatingRoute = false;
        _followGps = false;
      });
      return;
    }

    setStateIfMounted(() => _isCalculatingRoute = true);

    try {
      currentGraph.resetAllNodeCosts();
      final GraphNode? startNode = currentGraph.findNearestNode(_startLatLng!);
      final GraphNode? endNode = currentGraph.findNearestNode(_endLatLng!);

      if (startNode == null || endNode == null) {
        _showErrorDialog("Start/Ziel nicht auf Wegenetz gefunden.");
        setStateIfMounted(() {
          _routePolyline = null;
          _followGps = false;
        });
      } else if (startNode.id == endNode.id) {
        _showSnackbar("Start- und Zielpunkt sind identisch.");
        _currentDisplayedManeuver = Maneuver(
            point: _startLatLng!,
            turnType: TurnType.arrive,
            instructionText: "Start- und Zielpunkt sind identisch.");
        _clearRoute(showConfirmation: false, clearMarkers: false);
        if (_isMapReady && mounted && _startLatLng != null) {
          _mapController.move(_startLatLng!, _mapController.camera.zoom);
        }
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
                color: Colors.deepPurpleAccent);

            _routeDistance = RoutingService.calculateTotalDistance(routePoints);
            _routeTimeMinutes =
                RoutingService.estimateWalkingTimeMinutes(_routeDistance!);

            _currentManeuvers =
                RoutingService.analyzeRouteForTurns(routePoints);
            if (kDebugMode) {
              print("Berechnete Manöver für die aktuelle Route:");
              for (var maneuver in _currentManeuvers) {
                print(maneuver.toString());
              }
            }

            if (_currentManeuvers.length > 1) {
              if (_currentManeuvers[1].turnType != TurnType.arrive) {
                _currentDisplayedManeuver = _currentManeuvers[1];
              } else {
                _currentDisplayedManeuver = _currentManeuvers.last;
              }
            } else if (_currentManeuvers.isNotEmpty) {
              _currentDisplayedManeuver = _currentManeuvers.first;
            } else {
              _currentDisplayedManeuver = null;
            }

            if (!_useMockLocation) {
              _followGps = true;
              if (_currentGpsPosition != null && _isMapReady && mounted) {
                _mapController.move(_currentGpsPosition!, _followGpsZoomLevel);
              }
            } else {
              _followGps = false;
            }

            _showSnackbar("Route berechnet.", durationSeconds: 3);

            if (_isMapReady && mounted) {
              try {
                List<LatLng> pointsForBounds = List.from(routePoints);
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(pointsForBounds),
                    padding: const EdgeInsets.only(
                        top: 230.0, bottom: 80.0, left: 30.0, right: 30.0),
                  ),
                );
              } catch (e) {
                if (kDebugMode) {
                  print(
                      "Fehler beim Anpassen der Kartenansicht an die Route: $e");
                  if (_endLatLng != null) {
                    _mapController.move(
                        _endLatLng!, _mapController.camera.zoom);
                  }
                }
              }
            }
          } else {
            _routePolyline = null;
            _currentDisplayedManeuver = null;
            _followGps = false;
            _showErrorDialog("Keine Route gefunden.");
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> Fehler Routenberechnung: $e $stacktrace");
      }
      _showErrorDialog("Fehler Routenberechnung: $e");
      setStateIfMounted(() {
        _routePolyline = null;
        _followGps = false;
      });
    } finally {
      if (mounted) {
        setStateIfMounted(() => _isCalculatingRoute = false);
      }
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    if (kDebugMode) {
      print(
          "<<< _handleMapTap: $latLng, aktives Feld vor Tap: $_activeSearchField >>>");
    }
    if (!mounted) {
      return;
    }
    setStateIfMounted(() => _followGps = false);

    bool hadFocus = _startFocusNode.hasFocus || _endFocusNode.hasFocus;
    if (_startFocusNode.hasFocus) {
      _startFocusNode.unfocus();
    }
    if (_endFocusNode.hasFocus) {
      _endFocusNode.unfocus();
    }

    if (hadFocus || _showSearchResults) {
      setStateIfMounted(() {
        _showSearchResults = false;
      });
    }

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.isLoadingLocationData ||
        locationProvider.currentRoutingGraph == null) {
      _showSnackbar("Kartendaten werden noch geladen.", durationSeconds: 2);
      return;
    }
    if (_isCalculatingRoute) {
      return;
    }

    ActiveSearchField fieldToSetByTapDecision = _activeSearchField;

    if (fieldToSetByTapDecision == ActiveSearchField.none) {
      if (_startLatLng == null && _startSearchController.text.isEmpty) {
        fieldToSetByTapDecision = ActiveSearchField.start;
      } else if (_endLatLng == null && _endSearchController.text.isEmpty) {
        fieldToSetByTapDecision = ActiveSearchField.end;
      } else {
        fieldToSetByTapDecision = ActiveSearchField.end;
      }
    }

    _setPointFromMapTap(latLng, fieldToSetByTapDecision);

    setStateIfMounted(() {
      _activeSearchField = ActiveSearchField.none;
    });
  }

  void _setPointFromMapTap(LatLng latLng, ActiveSearchField fieldToSet) {
    String pointName = (fieldToSet == ActiveSearchField.start)
        ? "Start (Karte)"
        : "Ziel (Karte)";
    TextEditingController relevantController =
        (fieldToSet == ActiveSearchField.start)
            ? _startSearchController
            : _endSearchController;

    void performUpdateAndRoute() {
      setStateIfMounted(() {
        _followGps = false;
        if (fieldToSet == ActiveSearchField.start) {
          _startLatLng = latLng;
          _startMarker =
              _createMarker(latLng, Colors.green, Icons.flag_circle, pointName);
          relevantController.text = pointName;
        } else {
          _endLatLng = latLng;
          _endMarker =
              _createMarker(latLng, Colors.red, Icons.flag_circle, pointName);
          relevantController.text = pointName;
        }
        _routePolyline = null;
        _routeDistance = null;
        _routeTimeMinutes = null;
        _currentManeuvers = [];
        _currentDisplayedManeuver = null;
      });

      if (_startLatLng != null && _endLatLng != null) {
        _calculateAndDisplayRoute();
      }
    }

    bool isOverwriting =
        (fieldToSet == ActiveSearchField.start && _startLatLng != null) ||
            (fieldToSet == ActiveSearchField.end && _endLatLng != null);

    if (isOverwriting) {
      _showConfirmationDialog(
          "Neuen ${fieldToSet == ActiveSearchField.start ? 'Start' : 'Ziel'}punkt setzen?",
          "Aktuellen ${fieldToSet == ActiveSearchField.start ? 'Start' : 'Ziel'}punkt verwerfen und neuen Punkt auf Karte setzen?",
          performUpdateAndRoute);
    } else {
      performUpdateAndRoute();
    }
  }

  void _clearRoute({bool showConfirmation = true, bool clearMarkers = true}) {
    void doClearAction() {
      if (!mounted) {
        return;
      }
      setStateIfMounted(() {
        _routePolyline = null;
        _routeDistance = null;
        _routeTimeMinutes = null;
        _currentManeuvers = [];
        _currentDisplayedManeuver = null;
        _followGps = false;
        if (clearMarkers) {
          _startMarker = null;
          _startLatLng = null;
          _startSearchController.clear();
          _endMarker = null;
          _endLatLng = null;
          _endSearchController.clear();
          _activeSearchField = ActiveSearchField.none;
          _showSearchResults = false;
        }
      });
      _showSnackbar(
          clearMarkers
              ? "Route, Start- und Zielpunkt gelöscht."
              : "Route gelöscht.",
          durationSeconds: 2);
    }

    final bool somethingToDelete = _routePolyline != null ||
        (clearMarkers &&
            (_startMarker != null ||
                _endMarker != null ||
                _startSearchController.text.isNotEmpty ||
                _endSearchController.text.isNotEmpty));

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

    if (_useMockLocation) {
      _showSnackbar("Follow-Modus ist nur mit echtem GPS verfügbar.",
          durationSeconds: 3);
      LatLng? centerTarget = _currentGpsPosition ??
          selectedLocationFromProvider?.initialCenter ??
          fallbackInitialCenter;
      if (centerTarget != null && _isMapReady) { 
        _mapController.move(centerTarget, _followGpsZoomLevel);
      }
      return;
    }

    if (_currentGpsPosition != null && _isMapReady) {
      setStateIfMounted(() {
        _followGps = true;
      });
      _mapController.move(_currentGpsPosition!, _followGpsZoomLevel);
      _showSnackbar("Follow-GPS Modus aktiviert.", durationSeconds: 2);
    } else {
      _showSnackbar(
          "Aktuelle GPS-Position nicht verfügbar oder Karte nicht bereit.",
          durationSeconds: 3);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
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
                onPressed: () => Navigator.of(dialogContext).pop()),
          ],
        );
      },
    );
  }

  void _showSnackbar(String message, {int durationSeconds = 3}) {
    if (!mounted) {
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
                onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
                child: const Text("Bestätigen"),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onConfirm();
                }),
          ],
        );
      },
    );
  }

  void _swapStartAndEnd() {
    if (!mounted) return;

    if (_startLatLng == null && _endLatLng == null) {
      _showSnackbar("Kein Start- oder Zielpunkt zum Tauschen vorhanden.",
          durationSeconds: 3);
      return;
    }

    setStateIfMounted(() {
      final LatLng? tempLatLng = _startLatLng;
      _startLatLng = _endLatLng;
      _endLatLng = tempLatLng;

      final String tempStartText = _startSearchController.text;
      _startSearchController.text = _endSearchController.text;
      _endSearchController.text = tempStartText;

      if (_startLatLng != null) {
        _startMarker = _createMarker(
          _startLatLng!,
          Colors.green,
          Icons.flag_circle,
          "Start: ${_startSearchController.text.isNotEmpty ? _startSearchController.text : 'Gesetzter Punkt'}",
        );
      } else {
        _startMarker = null;
      }

      if (_endLatLng != null) {
        _endMarker = _createMarker(
          _endLatLng!,
          Colors.red,
          Icons.flag_circle,
          "Ziel: ${_endSearchController.text.isNotEmpty ? _endSearchController.text : 'Gesetzter Punkt'}",
        );
      } else {
        _endMarker = null;
      }

      _routeDistance = null;
      _routeTimeMinutes = null;
      _currentManeuvers = [];
      _currentDisplayedManeuver = null;
      _followGps = false;

      if (_startLatLng != null && _endLatLng != null) {
        _calculateAndDisplayRoute();
      } else {
        _routePolyline = null;
      }
    });

    _showSnackbar("Start und Ziel getauscht.", durationSeconds: 2);
  }

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) {
      return ""; 
    }
    if (distanceMeters < 1000) {
      return "${distanceMeters.round()} m";
    } else {
      return "${(distanceMeters / 1000).toStringAsFixed(1)} km";
    }
  }

  final GlobalKey _searchUiCardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final selectedLocationFromUI = locationProvider.selectedLocation;
    final availableLocationsFromUI = locationProvider.availableLocations;

    final bool isLoading = locationProvider.isLoadingLocationData;
    final RoutingGraph? currentGraph = locationProvider.currentRoutingGraph;
    final bool isUiReady = !isLoading && currentGraph != null;

    List<Marker> activeMarkers = [];
    final localCurrentLocationMarker = _currentLocationMarker;
    if (localCurrentLocationMarker != null) {
      activeMarkers.add(localCurrentLocationMarker);
    }
    if (_startMarker != null) {
      activeMarkers.add(_startMarker!);
    }
    if (_endMarker != null) {
      activeMarkers.add(_endMarker!);
    }

    double searchUiCardHeight = (MapScreen.searchInputRowHeight * 2) +
        MapScreen.dividerAndSwapButtonHeight +
        (MapScreen.cardInternalVerticalPadding * 2);
    if (_routeDistance != null) {
      searchUiCardHeight += MapScreen.routeInfoHeight;
    }

    double instructionCardTop = MapScreen.searchCardTopPadding +
        searchUiCardHeight +
        MapScreen.instructionCardSpacing;

    double searchResultsTopPosition = instructionCardTop;
    bool instructionCardVisible = _currentDisplayedManeuver != null &&
        _currentDisplayedManeuver!.turnType != TurnType.depart &&
        !(_currentManeuvers.length <= 2 &&
            _currentDisplayedManeuver!.turnType == TurnType.arrive);

    if (instructionCardVisible) {
      searchResultsTopPosition += 65.0 + MapScreen.instructionCardSpacing;
    } else {
      searchResultsTopPosition = MapScreen.searchCardTopPadding +
          searchUiCardHeight +
          MapScreen.instructionCardSpacing;
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
                          (LocationInfo location) =>
                              DropdownMenuItem<LocationInfo>(
                                value: location,
                                child: Text(location.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                              ))
                      .toList(),
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
              onMapEvent: (MapEvent mapEvent) {
                if (mapEvent is MapEventMove &&
                    (mapEvent.source == MapEventSource.dragStart ||
                        mapEvent.source ==
                            MapEventSource.flingAnimationController) &&
                    _followGps) {
                  setStateIfMounted(() {
                    _followGps = false;
                    _showSnackbar("Follow-GPS Modus deaktiviert.",
                        durationSeconds: 2);
                  });
                }
                if (mapEvent is MapEventMove &&
                    (mapEvent.source == MapEventSource.dragStart ||
                        mapEvent.source ==
                            MapEventSource.flingAnimationController) &&
                    (_startFocusNode.hasFocus || _endFocusNode.hasFocus)) {
                  if (_startFocusNode.hasFocus) {
                    _startFocusNode.unfocus();
                  }
                  if (_endFocusNode.hasFocus) {
                    _endFocusNode.unfocus();
                  }
                }
              },
              onMapReady: () {
                if (!mounted) {
                  return;
                }
                if (kDebugMode) {
                  print("<<< Map bereit, _isMapReady=true >>>");
                }
                setState(() => _isMapReady = true);
                _performInitialMapMove();
              },
            ),
            children: [
              TileLayer(
                // ====== HIER IST DIE ÄNDERUNG für den CORS-Proxy ======
                urlTemplate: "https://api.allorigins.win/raw?url=https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'dev.tom52538.campsitenav.app', 
                // tileProvider: CancellableNetworkTileProvider(), // Vorerst auskommentiert für Standard-Web-Verhalten oder CORS-Proxy-Test
                // ======================================================
              ),
              if (isUiReady && _routePolyline != null)
                PolylineLayer(polylines: [_routePolyline!]),
              if (isUiReady && activeMarkers.isNotEmpty)
                MarkerLayer(markers: activeMarkers),
            ],
          ),
          Positioned(
            key: _searchUiCardKey,
            top: MapScreen.searchCardTopPadding,
            left: MapScreen.searchCardHorizontalMargin,
            child: Container(
              constraints:
                  const BoxConstraints(maxWidth: MapScreen.searchCardMaxWidth),
              child: Card(
                elevation: 6.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: MapScreen.cardInternalVerticalPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: _startFocusNode.hasFocus
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5)
                              : Border.all(
                                  color: Colors.transparent, width: 1.5),
                          borderRadius: BorderRadius.circular(6.0),
                          color: _startFocusNode.hasFocus
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha((255 * 0.05).round())
                              : null,
                        ),
                        child: SizedBox(
                          height: MapScreen.searchInputRowHeight,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _startSearchController,
                                  focusNode: _startFocusNode,
                                  decoration: InputDecoration(
                                    hintText: "Startpunkt wählen",
                                    prefixIcon: const Icon(Icons.trip_origin),
                                    suffixIcon: _startSearchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            iconSize: 20,
                                            onPressed: () {
                                              _startSearchController.clear();
                                              setStateIfMounted(() {
                                                _startLatLng = null;
                                                _startMarker = null;
                                                _routePolyline = null;
                                                _routeDistance = null;
                                                _routeTimeMinutes = null;
                                                _currentManeuvers = [];
                                                _currentDisplayedManeuver =
                                                    null;
                                                _followGps = false;
                                              });
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 8.0),
                                  ),
                                  enabled: isUiReady,
                                ),
                              ),
                              Tooltip(
                                message:
                                    "Aktuellen Standort als Start verwenden",
                                child: IconButton(
                                  icon: const Icon(Icons.my_location),
                                  color: Theme.of(context).colorScheme.primary,
                                  iconSize: 22,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: isUiReady
                                      ? () {
                                          if (_currentGpsPosition != null) {
                                            final String locationName =
                                                _useMockLocation
                                                    ? "Mock Position (${selectedLocationFromUI?.name ?? ''})"
                                                    : "Aktueller Standort";
                                            setStateIfMounted(() {
                                              _startLatLng =
                                                  _currentGpsPosition;
                                              if (_startLatLng != null) {
                                                _startMarker = _createMarker(
                                                    _startLatLng!,
                                                    Colors.green,
                                                    Icons.flag_circle,
                                                    "Start: $locationName");
                                              }
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                if (mounted) {
                                                  _startSearchController.text =
                                                      locationName;
                                                }
                                              });

                                              if (_startFocusNode.hasFocus) {
                                                _startFocusNode.unfocus();
                                              }
                                              _showSearchResults = false;
                                              _activeSearchField =
                                                  ActiveSearchField.none;
                                              _followGps = false;
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
                        ),
                      ),
                      SizedBox(
                        height: MapScreen.dividerAndSwapButtonHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Expanded(
                                child: Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    indent: 20,
                                    endIndent: 5)),
                            Tooltip(
                              message: "Start und Ziel tauschen",
                              child: IconButton(
                                icon: Icon(Icons.swap_vert,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                iconSize: 20,
                                padding: const EdgeInsets.all(4.0),
                                constraints: const BoxConstraints(),
                                onPressed: (isUiReady &&
                                        (_startLatLng != null ||
                                            _endLatLng != null))
                                    ? _swapStartAndEnd
                                    : null,
                              ),
                            ),
                            const Expanded(
                                child: Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    indent: 5,
                                    endIndent: 20)),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: _endFocusNode.hasFocus
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5)
                              : Border.all(
                                  color: Colors.transparent, width: 1.5),
                          borderRadius: BorderRadius.circular(6.0),
                          color: _endFocusNode.hasFocus
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha((255 * 0.05).round())
                              : null,
                        ),
                        child: SizedBox(
                          height: MapScreen.searchInputRowHeight,
                          child: TextField(
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
                                          _routeDistance = null;
                                          _routeTimeMinutes = null;
                                          _currentManeuvers = [];
                                          _currentDisplayedManeuver = null;
                                          _followGps = false;
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 8.0),
                            ),
                            enabled: isUiReady,
                          ),
                        ),
                      ),
                      if (_routeDistance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                          child: SizedBox(
                            height: MapScreen.routeInfoHeight - 6.0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.directions_walk,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 18),
                                const SizedBox(width: 6),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            "~ ${_routeTimeMinutes ?? '?'} min",
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            " / ${_formatDistance(_routeDistance)}",
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (instructionCardVisible)
            Positioned(
                top: instructionCardTop,
                left: MapScreen.searchCardHorizontalMargin,
                right: MapScreen.searchCardHorizontalMargin,
                child: Center(
                  child: TurnInstructionCard(
                    maneuver: _currentDisplayedManeuver!,
                    maxWidth: MapScreen.searchCardMaxWidth + 50,
                  ),
                )),
          if (_showSearchResults && _searchResults.isNotEmpty && isUiReady)
            Positioned(
              top: searchResultsTopPosition,
              left: MapScreen.searchCardHorizontalMargin,
              child: Container(
                constraints: const BoxConstraints(
                    maxWidth: MapScreen.searchCardMaxWidth),
                child: Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final feature = _searchResults[index];
                        return ListTile(
                          leading: Icon(getIconForFeatureType(feature.type)),
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
          if (_isCalculatingRoute && isUiReady)
            Positioned.fill(
                child: Container(
                    color: Colors.black.withAlpha(70),
                    child: const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white)))),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(180),
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                      "Lade Kartendaten für ${selectedLocationFromUI?.name ?? '...'}...",
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                ])),
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
              tooltip: _followGps
                  ? 'Follow-GPS Modus aktiv'
                  : 'Follow-GPS Modus aktivieren',
              backgroundColor: _followGps
                  ? Colors.greenAccent[700]
                  : Colors.deepOrangeAccent,
              child: Icon(_followGps ? Icons.navigation : Icons.my_location),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  IconData getIconForFeatureType(String type) {
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