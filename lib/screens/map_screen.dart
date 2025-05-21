// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:math'; // Für sqrt, pow, min
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
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';
import 'package:camping_osm_navi/services/tts_service.dart';

// Import des neuen Mixins
import 'map_screen_parts/map_screen_ui_mixin.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  // UI Konstanten wurden ins Mixin verschoben, können hier aber auch bleiben oder von dort importiert werden
  // static const double searchCardTopPadding = kSearchCardTopPadding; // aus Mixin
  // ... andere Konstanten könnten hier bleiben, wenn sie nicht spezifisch für UI-Build-Methoden sind

  @override
  MapScreenState createState() => MapScreenState();
}

enum ActiveSearchField { none, start, end }

// Verwende das UI Mixin
class MapScreenState extends State<MapScreen> with MapScreenUIMixin { // HIER WIRD DAS MIXIN EINGEBUNDEN
  final MapController _mapController = MapController();
  late TtsService _ttsService;

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
  // static const double markerWidth = 40.0; // jetzt in kMarkerWidth im Mixin
  // static const double markerHeight = 40.0; // jetzt in kMarkerHeight im Mixin
  static const double centerOnGpsMaxDistanceMeters = 5000;

  final TextEditingController _startSearchController = TextEditingController();
  final TextEditingController _endSearchController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  LatLng? _startLatLng;
  ActiveSearchField _activeSearchField = ActiveSearchField.none;

  static const double _maneuverReachedThreshold = 15.0;
  static const double _significantGpsChangeThreshold = 2.0;

  static const double _offRouteThreshold = 25.0;
  final Distance _distanceCalculatorInstance = const Distance();

  bool _isRouteActiveForCardSwitch = false;
  final GlobalKey _fullSearchCardKey = GlobalKey();
  double _fullSearchCardHeight = 0;


  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _startSearchController.addListener(_onStartSearchChanged);
    _endSearchController.addListener(_onEndSearchChanged);
    _startFocusNode.addListener(_onStartFocusChanged);
    _endFocusNode.addListener(_onEndFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_fullSearchCardKey.currentContext != null) {
        final RenderBox? renderBox = _fullSearchCardKey.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null && mounted) { // mounted Check hinzugefügt
          setStateIfMounted(() { // setStateIfMounted verwenden
             _fullSearchCardHeight = renderBox.size.height;
          });
        }
      }
    });

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
    _ttsService.stop();

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
        _isRouteActiveForCardSwitch = false;
        _showSearchResults =
            _startSearchController.text.isNotEmpty && _searchResults.isNotEmpty;
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted &&
              !_startFocusNode.hasFocus &&
              _activeSearchField == ActiveSearchField.start) {
            setStateIfMounted(() {
              _showSearchResults = false;
              if (!_endFocusNode.hasFocus && _routePolyline != null) {
                _isRouteActiveForCardSwitch = true;
              }
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
         _isRouteActiveForCardSwitch = false;
        _showSearchResults =
            _endSearchController.text.isNotEmpty && _searchResults.isNotEmpty;
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted &&
              !_endFocusNode.hasFocus &&
              _activeSearchField == ActiveSearchField.end) {
            setStateIfMounted(() {
              _showSearchResults = false;
              if (!_startFocusNode.hasFocus && _routePolyline != null) {
                _isRouteActiveForCardSwitch = true;
              }
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
      _isRouteActiveForCardSwitch = false;
    });
    if (_isMapReady && mounted) {
      _mapController.move(newLocation.initialCenter, 17.0);
    }
    if (isActualChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showSnackbar("Standort geändert zu: ${newLocation.name}", // Aufruf der Mixin-Methode
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
        _isRouteActiveForCardSwitch = false;
      }
      if (currentLocation != null) {
        _initializeGpsOrMock(currentLocation);
      }
    });
    showSnackbar( // Aufruf der Mixin-Methode
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
          _currentLocationMarker = createMarker( // Aufruf der Mixin-Methode
              activeInitialCenterForMock,
              Colors.orangeAccent,
              Icons.pin_drop,
              "Mock Position (${location.name})");
          if (_startSearchController.text == "Aktueller Standort" ||
              (_startSearchController.text
                      .toLowerCase()
                      .contains("mock position") &&
                  oldGpsPosition != _currentGpsPosition)) {
            _startLatLng = activeInitialCenterForMock;
            if (_startLatLng != null) {
              _startMarker = createMarker(_startLatLng!, Colors.green, // Aufruf der Mixin-Methode
                  Icons.flag_circle, "Start: Mock Position (${location.name})");
            }
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
        _startMarker = createMarker(feature.center, Colors.green, // Aufruf der Mixin-Methode
            Icons.flag_circle, "Start: ${feature.name}");
      });
    } else if (_activeSearchField == ActiveSearchField.end) {
      controllerToUpdate = _endSearchController;
      focusToUnset = _endFocusNode;
      nextFocus = _startSearchController.text.isEmpty ? _startFocusNode : null;
      setStateIfMounted(() {
        _endLatLng = feature.center;
        _endMarker = createMarker(feature.center, Colors.red, // Aufruf der Mixin-Methode
            Icons.flag_circle, "Ziel: ${feature.name}");
      });
    } else {
      if (kDebugMode) {
        print(
            "<<< _selectFeatureAndSetPoint: Kein aktives Suchfeld für Auswahl! >>>");
      }
      return;
    }

    controllerToUpdate.value = TextEditingValue(
      text: feature.name,
      selection:
          TextSelection.fromPosition(TextPosition(offset: feature.name.length)),
    );

    setStateIfMounted(() {
      _showSearchResults = false;
      _searchResults = [];
      _followGps = false;
    });

    focusToUnset.unfocus();

    if (nextFocus != null) {
      FocusScope.of(context).requestFocus(nextFocus);
      setStateIfMounted(() {
        _isRouteActiveForCardSwitch = false;
      });
    } else {
      _activeSearchField = ActiveSearchField.none;
      if (_routePolyline != null) {
         setStateIfMounted(() {
          _isRouteActiveForCardSwitch = true;
        });
      }
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
          showErrorDialog("GPS ist deaktiviert."); // Aufruf der Mixin-Methode
          setStateIfMounted(() => _followGps = false);
        }
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showErrorDialog("GPS-Berechtigung verweigert."); // Aufruf der Mixin-Methode
            setStateIfMounted(() => _followGps = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showErrorDialog("GPS-Berechtigung dauerhaft verweigert."); // Aufruf der Mixin-Methode
          setStateIfMounted(() => _followGps = false);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog("Fehler GPS-Berechtigungen: $e"); // Aufruf der Mixin-Methode
        setStateIfMounted(() => _followGps = false);
      }
      return;
    }

    final LatLng centerForDistanceCheck = location.initialCenter;
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) {
        return;
      }
      final bool isFirstFix = _currentGpsPosition == null;
      LatLng newGpsPos = LatLng(position.latitude, position.longitude);

      bool significantPositionChange = true;
      if (_currentGpsPosition != null) {
        if (_distanceCalculatorInstance(_currentGpsPosition!, newGpsPos) <
            _significantGpsChangeThreshold) {
          significantPositionChange = false;
        }
      }

      if (significantPositionChange) {
        _currentGpsPosition = newGpsPos;
        setStateIfMounted(() {
          _currentLocationMarker = createMarker( // Aufruf der Mixin-Methode
              newGpsPos, Colors.blueAccent, Icons.circle, "Meine Position");
          if (_startSearchController.text == "Aktueller Standort") {
            _startLatLng = _currentGpsPosition;
            if (_startLatLng != null) {
              _startMarker = createMarker(_startLatLng!, Colors.green, // Aufruf der Mixin-Methode
                  Icons.flag_circle, "Start: Aktueller Standort");
            }
          }
        });
      }

      if (_followGps &&
          _isMapReady &&
          mounted &&
          _currentGpsPosition != null &&
          significantPositionChange) {
        _mapController.move(_currentGpsPosition!, _followGpsZoomLevel);
      } else if (isFirstFix &&
          _currentGpsPosition != null &&
          _isMapReady &&
          mounted &&
          significantPositionChange) {
        final double meters = _distanceCalculatorInstance(
            _currentGpsPosition!, centerForDistanceCheck);
        if (meters <= centerOnGpsMaxDistanceMeters) {
          _mapController.move(_currentGpsPosition!, _followGpsZoomLevel);
        } else {
          showSnackbar( // Aufruf der Mixin-Methode
              "Echte GPS-Position zu weit entfernt vom aktuellen Standort.",
              durationSeconds: 4);
        }
      }

      if (_routePolyline != null &&
          _currentManeuvers.isNotEmpty &&
          significantPositionChange &&
          _currentGpsPosition != null) {
        _updateCurrentManeuverOnGpsUpdate(_currentGpsPosition!);
      }

      if (_routePolyline != null &&
          _routePolyline!.points.isNotEmpty &&
          !_isCalculatingRoute &&
          _currentGpsPosition != null &&
          significantPositionChange) {
        final double distanceToRoute = _calculateDistanceToPolyline(
            _currentGpsPosition!, _routePolyline!.points);
        if (distanceToRoute > _offRouteThreshold) {
          if (kDebugMode) {
            print(
                "[MapScreen] Von Route abgekommen! Distanz: ${distanceToRoute.toStringAsFixed(1)}m. Schwellenwert: $_offRouteThreshold m. Berechne neu...");
          }
          showSnackbar("Von Route abgekommen. Neue Route wird berechnet...", // Aufruf der Mixin-Methode
              durationSeconds: 3);

          _startLatLng = _currentGpsPosition;
          _startSearchController.text = "Aktueller Standort (neu)";
          if (_startLatLng != null) {
            _startMarker = createMarker(_startLatLng!, Colors.green, // Aufruf der Mixin-Methode
                Icons.flag_circle, "Start: ${_startSearchController.text}");
          }
          _isRouteActiveForCardSwitch = false;
          _calculateAndDisplayRoute();
        }
      }
    }, onError: (error) {
      showErrorDialog("Fehler GPS-Empfang: $error"); // Aufruf der Mixin-Methode
      if (mounted) {
        setStateIfMounted(() => _followGps = false);
      }
    });
  }

  void _updateCurrentManeuverOnGpsUpdate(LatLng currentPosition) {
    if (_currentManeuvers.isEmpty || _currentDisplayedManeuver == null || _routePolyline == null || _routePolyline!.points.isEmpty) {
      return;
    }

    if (_currentDisplayedManeuver!.turnType == TurnType.arrive) {
      return;
    }

    int displayedManeuverIndex = _currentManeuvers.indexOf(_currentDisplayedManeuver!);

    if (displayedManeuverIndex == -1) {
      if (kDebugMode) {
        print("[MapScreen] Fehler: _currentDisplayedManeuver nicht in _currentManeuvers gefunden.");
      }
      if (_currentManeuvers.isNotEmpty) {
        Maneuver initialManeuver = _currentManeuvers.first;
        if (_currentManeuvers.length > 1 && initialManeuver.turnType == TurnType.depart) {
          if (_currentManeuvers[1].turnType != TurnType.arrive || _currentManeuvers.length == 2) {
            initialManeuver = _currentManeuvers[1];
          } else if (_currentManeuvers.length > 2 && _currentManeuvers[1].turnType == TurnType.arrive) {
            initialManeuver = _currentManeuvers[1];
          }
        }
        if (_currentDisplayedManeuver != initialManeuver) {
          setStateIfMounted(() {
            _currentDisplayedManeuver = initialManeuver;
            if (_currentDisplayedManeuver?.instructionText != null) {
              _ttsService.speak(_currentDisplayedManeuver!.instructionText!);
            }
          });
        }
      }
      return;
    }

    final double distanceToDisplayedManeuverPoint = _distanceCalculatorInstance(
      currentPosition,
      _currentDisplayedManeuver!.point,
    );

    if (kDebugMode) {
      // print("[MapScreen] Distanz zu '${_currentDisplayedManeuver!.instructionText}': ${distanceToDisplayedManeuverPoint.toStringAsFixed(1)}m. Aktueller Index: $displayedManeuverIndex");
    }

    if (distanceToDisplayedManeuverPoint < _maneuverReachedThreshold) {
      final int nextManeuverIndex = displayedManeuverIndex + 1;

      if (nextManeuverIndex < _currentManeuvers.length) {
        Maneuver newPotentialManeuver = _currentManeuvers[nextManeuverIndex];

        if (newPotentialManeuver.turnType == TurnType.arrive) {
          if (_routePolyline != null && _routePolyline!.points.isNotEmpty) {
            final LatLng actualDestinationPoint = _routePolyline!.points.last;
            final double distanceToActualDestination = _distanceCalculatorInstance(
              currentPosition,
              actualDestinationPoint,
            );

            if (distanceToActualDestination < _maneuverReachedThreshold) {
              if (newPotentialManeuver != _currentDisplayedManeuver) {
                setStateIfMounted(() {
                  _currentDisplayedManeuver = newPotentialManeuver;
                  if (kDebugMode) {
                    print("[MapScreen] Ziel erreicht und Ankunfts-Manöver gesetzt: ${_currentDisplayedManeuver!.instructionText}");
                  }
                  if (_currentDisplayedManeuver?.instructionText != null) {
                    _ttsService.speak(_currentDisplayedManeuver!.instructionText!);
                  }
                });
              }
            } else {
              if (kDebugMode) {
                print("[MapScreen] Vorletztes Manöver erreicht, aber Ziel (${distanceToActualDestination.toStringAsFixed(1)}m) noch nicht nah genug für 'Ankunft'. Aktuelles Manöver bleibt: ${_currentDisplayedManeuver?.instructionText}");
              }
            }
          } else {
             if (kDebugMode) {
                print("[MapScreen] Warnung: 'Ankunft'-Manöver wird geprüft, aber _routePolyline ist null oder leer.");
             }
          }
        } else {
          if (newPotentialManeuver != _currentDisplayedManeuver) {
            setStateIfMounted(() {
              _currentDisplayedManeuver = newPotentialManeuver;
              if (kDebugMode) {
                print("[MapScreen] Nächstes reguläres Manöver gesetzt: ${_currentDisplayedManeuver!.instructionText}");
              }
              if (_currentDisplayedManeuver?.instructionText != null) {
                _ttsService.speak(_currentDisplayedManeuver!.instructionText!);
              }
            });
          }
        }
      } else if (displayedManeuverIndex == _currentManeuvers.length - 1 &&
          _currentDisplayedManeuver!.turnType != TurnType.arrive) {
        if (kDebugMode) {
          print("[MapScreen] Letztes Manöver der Liste erreicht, aber es war nicht 'Arrive'. Aktuell angezeigt: ${_currentDisplayedManeuver!.instructionText}");
        }
      }
    }
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
      _routePolyline = null;
      _routeDistance = null;
      _routeTimeMinutes = null;
      _currentManeuvers = [];
      _currentDisplayedManeuver = null;
      _isRouteActiveForCardSwitch = false;
    });

    if (!isDataReadyForRouting) {
      showErrorDialog( // Aufruf der Mixin-Methode
          "Kartendaten für ${selectedLocationFromProvider?.name ?? ''} nicht bereit.");
      setStateIfMounted(() {
        _isCalculatingRoute = false;
        _followGps = false;
      });
      return;
    }

    if (currentGraph.nodes.isEmpty) {
      showErrorDialog( // Aufruf der Mixin-Methode
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
        showErrorDialog("Start/Ziel nicht auf Wegenetz gefunden."); // Aufruf der Mixin-Methode
        setStateIfMounted(() {
          _routePolyline = null;
          _followGps = false;
           _isRouteActiveForCardSwitch = false;
        });
      } else if (startNode.id == endNode.id) {
        showSnackbar("Start- und Zielpunkt sind identisch."); // Aufruf der Mixin-Methode
        setStateIfMounted(() {
          _currentDisplayedManeuver = Maneuver(
              point: _startLatLng!,
              turnType: TurnType.arrive,
              instructionText: "Start- und Zielpunkt sind identisch.");
          if (_currentDisplayedManeuver?.instructionText != null) {
            _ttsService.speak(_currentDisplayedManeuver!.instructionText!);
          }
          _clearRoute(showConfirmation: false, clearMarkers: false);
        });
        if (_isMapReady && mounted) {
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

            if (_currentManeuvers.isNotEmpty) {
              _currentDisplayedManeuver = _currentManeuvers.first;
              if (_currentManeuvers.length > 1 &&
                  _currentManeuvers.first.turnType == TurnType.depart) {
                if (_currentManeuvers[1].turnType != TurnType.arrive ||
                    _currentManeuvers.length == 2) {
                  _currentDisplayedManeuver = _currentManeuvers[1];
                } else if (_currentManeuvers.length > 2) {
                  _currentDisplayedManeuver = _currentManeuvers[1];
                }
              } else if (_currentManeuvers.first.turnType != TurnType.depart) {
                _currentDisplayedManeuver = _currentManeuvers.first;
              }
              if (_currentDisplayedManeuver?.instructionText != null) {
                _ttsService.speak(_currentDisplayedManeuver!.instructionText!);
              }
            } else {
              _currentDisplayedManeuver = null;
            }

            _isRouteActiveForCardSwitch = true;

            if (!_useMockLocation) {
              _followGps = true;
              if (_currentGpsPosition != null && _isMapReady && mounted) {
                _mapController.move(_currentGpsPosition!, _followGpsZoomLevel);
              }
            } else {
              _followGps = false;
            }

            showSnackbar("Route berechnet.", durationSeconds: 3); // Aufruf der Mixin-Methode

            if (_isMapReady && mounted) {
              try {
                List<LatLng> pointsForBounds = List.from(routePoints);
                if (_currentGpsPosition != null &&
                    _startLatLng == _currentGpsPosition) {
                  pointsForBounds.add(_currentGpsPosition!);
                }
                if (_startFocusNode.hasFocus) _startFocusNode.unfocus();
                if (_endFocusNode.hasFocus) _endFocusNode.unfocus();

                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(pointsForBounds),
                    padding: const EdgeInsets.only(
                        top: kCompactCardHeight + kSearchCardTopPadding + 20, 
                        bottom: 80.0, left: 30.0, right: 30.0),
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
            _isRouteActiveForCardSwitch = false;
            showErrorDialog("Keine Route gefunden."); // Aufruf der Mixin-Methode
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(">>> Fehler Routenberechnung: $e $stacktrace");
      }
      showErrorDialog("Fehler Routenberechnung: $e"); // Aufruf der Mixin-Methode
      setStateIfMounted(() {
        _routePolyline = null;
        _followGps = false;
        _isRouteActiveForCardSwitch = false;
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
    if(_routePolyline != null && !_startFocusNode.hasFocus && !_endFocusNode.hasFocus) {
        setStateIfMounted(() {
            _isRouteActiveForCardSwitch = true;
        });
    }

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.isLoadingLocationData ||
        locationProvider.currentRoutingGraph == null) {
      showSnackbar("Kartendaten werden noch geladen.", durationSeconds: 2); // Aufruf der Mixin-Methode
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
    setStateIfMounted(() {
       _isRouteActiveForCardSwitch = false;
    });

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
              createMarker(latLng, Colors.green, Icons.flag_circle, pointName); // Aufruf der Mixin-Methode
          relevantController.text = pointName;
        } else { 
          _endLatLng = latLng;
          _endMarker =
              createMarker(latLng, Colors.red, Icons.flag_circle, pointName); // Aufruf der Mixin-Methode
          relevantController.text = pointName;
        }
        _routePolyline = null;
        _routeDistance = null;
        _routeTimeMinutes = null;
        _currentManeuvers = [];
        _currentDisplayedManeuver = null;
        _isRouteActiveForCardSwitch = false; 
      });

      if (_startLatLng != null && _endLatLng != null) {
        _calculateAndDisplayRoute();
      }
    }

    bool isOverwriting =
        (fieldToSet == ActiveSearchField.start && _startLatLng != null && _startSearchController.text.isNotEmpty) ||
            (fieldToSet == ActiveSearchField.end && _endLatLng != null && _endSearchController.text.isNotEmpty);

    if (isOverwriting) {
      showConfirmationDialog( // Aufruf der Mixin-Methode
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
        _isRouteActiveForCardSwitch = false;
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
      showSnackbar( // Aufruf der Mixin-Methode
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
      showConfirmationDialog( // Aufruf der Mixin-Methode
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
      showSnackbar("Follow-Modus ist nur mit echtem GPS verfügbar.", // Aufruf der Mixin-Methode
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
        _followGps = !_followGps;
      });

      if (_followGps) {
        _mapController.move(_currentGpsPosition!, _followGpsZoomLevel);
        showSnackbar("Follow-GPS Modus aktiviert.", durationSeconds: 2); // Aufruf der Mixin-Methode
      } else {
        showSnackbar("Follow-GPS Modus deaktiviert.", durationSeconds: 2); // Aufruf der Mixin-Methode
      }
    } else {
      showSnackbar( // Aufruf der Mixin-Methode
          "Aktuelle GPS-Position nicht verfügbar oder Karte nicht bereit.",
          durationSeconds: 3);
    }
  }

  void _swapStartAndEnd() {
    if (!mounted) return;

    if (_startLatLng == null && _endLatLng == null) {
      showSnackbar("Kein Start- oder Zielpunkt zum Tauschen vorhanden.", // Aufruf der Mixin-Methode
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
        _startMarker = createMarker( // Aufruf der Mixin-Methode
          _startLatLng!,
          Colors.green,
          Icons.flag_circle,
          "Start: ${_startSearchController.text.isNotEmpty ? _startSearchController.text : 'Gesetzter Punkt'}",
        );
      } else {
        _startMarker = null;
      }

      if (_endLatLng != null) {
        _endMarker = createMarker( // Aufruf der Mixin-Methode
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
      _isRouteActiveForCardSwitch = false;

      if (_startLatLng != null && _endLatLng != null) {
        _calculateAndDisplayRoute();
      } else {
        _routePolyline = null;
      }
    });

    showSnackbar("Start und Ziel getauscht.", durationSeconds: 2); // Aufruf der Mixin-Methode
  }


  double _distanceToSegment(
      LatLng p, LatLng a, LatLng b, Distance distanceCalc) {
    final double l2 = pow(distanceCalc(a, b), 2).toDouble();
    if (l2 == 0.0) return distanceCalc(p, a);

    final double distAP = distanceCalc(p, a);
    final double distBP = distanceCalc(p, b);
    final double distAB = sqrt(l2);

    if (distAP == 0) return 0.0;
    if (distBP == 0) return 0.0;
    if (distAB == 0) return distAP;

    double cosPAB = (pow(distAP, 2) + pow(distAB, 2) - pow(distBP, 2)) /
        (2 * distAP * distAB);
    if (cosPAB < 0) {
      return distAP;
    }

    double cosPBA = (pow(distBP, 2) + pow(distAB, 2) - pow(distAP, 2)) /
        (2 * distBP * distAB);
    if (cosPBA < 0) {
      return distBP;
    }

    final double s = (distAP + distBP + distAB) / 2;
    final double areaArgCandidate =
        s * (s - distAP) * (s - distBP) * (s - distAB);
    final double areaArg = areaArgCandidate < 0 ? 0 : areaArgCandidate;

    final double area = sqrt(areaArg);
    return (2 * area) / distAB;
  }

  double _calculateDistanceToPolyline(LatLng p, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1)
      return _distanceCalculatorInstance(p, polyline.first);

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final LatLng a = polyline[i];
      final LatLng b = polyline[i + 1];
      final double distanceToCurrentSegment =
          _distanceToSegment(p, a, b, _distanceCalculatorInstance);
      if (distanceToCurrentSegment < minDistance) {
        minDistance = distanceToCurrentSegment;
      }
    }
    return minDistance;
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

    double currentSearchCardHeight = _isRouteActiveForCardSwitch
        ? kCompactCardHeight // Konstante aus Mixin/hier
        : _fullSearchCardHeight > 0 ? _fullSearchCardHeight : (kSearchInputRowHeight * 2) + kDividerAndSwapButtonHeight + (kCardInternalVerticalPadding * 2) + (_routeDistance != null ? kRouteInfoHeight : 0);


    double instructionCardTop = kSearchCardTopPadding +
        currentSearchCardHeight + 
        kInstructionCardSpacing;

    double searchResultsTopPosition = instructionCardTop;
    bool instructionCardVisible = _currentDisplayedManeuver != null &&
        _currentDisplayedManeuver!.turnType != TurnType.depart &&
        !(_currentManeuvers.length <= 2 &&
            _currentDisplayedManeuver!.turnType == TurnType.arrive);

    if (instructionCardVisible) {
      searchResultsTopPosition += 65.0 + kInstructionCardSpacing;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campground Navigator"),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Test TTS',
            onPressed: isUiReady
                ? () {
                    _ttsService.testSpeak();
                  }
                : null,
          ),
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
                    showSnackbar("Follow-GPS Modus deaktiviert.", // Aufruf der Mixin-Methode
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
                  if(_routePolyline != null && !_startFocusNode.hasFocus && !_endFocusNode.hasFocus) {
                      setStateIfMounted(() {
                          _isRouteActiveForCardSwitch = true;
                      });
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
                final locationProvider =
                    Provider.of<LocationProvider>(context, listen: false);
                if (locationProvider.selectedLocation != null &&
                    _currentGpsPosition == null) {
                  _initializeGpsOrMock(locationProvider.selectedLocation!);
                } else {
                  _performInitialMapMove();
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _fullSearchCardKey.currentContext != null) {
                    final RenderBox? renderBox = _fullSearchCardKey.currentContext!.findRenderObject() as RenderBox?;
                     if (renderBox != null && renderBox.hasSize) {
                        setStateIfMounted(() { // setStateIfMounted verwenden
                          _fullSearchCardHeight = renderBox.size.height;
                        });
                     }
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'dev.tom52538.campsitenav.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (isUiReady && _routePolyline != null)
                PolylineLayer(polylines: [_routePolyline!]),
              if (isUiReady && activeMarkers.isNotEmpty)
                MarkerLayer(markers: activeMarkers),
            ],
          ),
          Positioned(
            top: kSearchCardTopPadding,
            left: kSearchCardHorizontalMargin,
            right: kSearchCardHorizontalMargin,
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: child,
                  );
                },
                child: _isRouteActiveForCardSwitch && isUiReady
                    ? buildCompactRouteInfoCard(key: const ValueKey('compactCard')) // Aufruf der Mixin-Methode
                    : buildSearchInputCard(key: const ValueKey('searchInputCard')), // Aufruf der Mixin-Methode
              ),
            ),
          ),
          if (instructionCardVisible && isUiReady)
            Positioned(
                top: instructionCardTop,
                left: kSearchCardHorizontalMargin,
                right: kSearchCardHorizontalMargin,
                child: Center(
                  child: TurnInstructionCard(
                    maneuver: _currentDisplayedManeuver!,
                    maxWidth: kSearchCardMaxWidth + 50,
                  ),
                )),
          if (_showSearchResults && _searchResults.isNotEmpty && isUiReady)
            Positioned(
              top: searchResultsTopPosition,
              left: kSearchCardHorizontalMargin,
               right: kSearchCardHorizontalMargin,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  constraints: const BoxConstraints(
                      maxWidth: kSearchCardMaxWidth),
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
                            leading: Icon(getIconForFeatureType(feature.type)), // Aufruf der Mixin-Methode
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
}