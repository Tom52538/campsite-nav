// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:vector_map_tiles/vector_map_tiles.dart'; // Stellt MaptilerVectorTileProvider bereit
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';
import 'package:camping_osm_navi/services/tts_service.dart';

import 'map_screen_parts/map_screen_ui_mixin.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

enum ActiveSearchField { none, start, end }

class MapScreenState extends State<MapScreen> with MapScreenUIMixin {
  final MapController mapController = MapController();
  late TtsService ttsService;

  Polyline? routePolyline;
  Marker? currentLocationMarker;
  Marker? startMarker;
  Marker? endMarker;
  LatLng? currentGpsPosition;
  LatLng? endLatLng;

  bool isCalculatingRoute = false;
  StreamSubscription<Position>? positionStreamSubscription;
  List<SearchableFeature> searchResults = [];
  bool showSearchResults = false;

  bool useMockLocation = true;
  bool isMapReady = false;

  LocationInfo? lastProcessedLocation;

  double? routeDistance;
  int? routeTimeMinutes;
  double? remainingRouteDistance;
  int? remainingRouteTimeMinutes;

  List<Maneuver> currentManeuvers = [];
  Maneuver? currentDisplayedManeuver;
  bool followGps = false;
  static const double _followGpsZoomLevel = 17.5;
  static const double _navigationStartZoomDelaySeconds = 2.5;

  bool _isInRouteOverviewMode = false;

  static const LatLng fallbackInitialCenter =
      LatLng(51.02518780487824, 5.858832278816441);
  static const double centerOnGpsMaxDistanceMeters = 5000;

  final TextEditingController startSearchController = TextEditingController();
  final TextEditingController endSearchController = TextEditingController();
  final FocusNode startFocusNode = FocusNode();
  final FocusNode endFocusNode = FocusNode();
  LatLng? startLatLng;
  ActiveSearchField activeSearchField = ActiveSearchField.none;

  static const double _maneuverReachedThreshold = 15.0;
  static const double _significantGpsChangeThreshold = 2.0;

  static const double _offRouteThreshold = 25.0;
  final Distance distanceCalculatorInstance = const Distance();

  bool isRouteActiveForCardSwitch = false;
  final GlobalKey fullSearchCardKey = GlobalKey();
  double fullSearchCardHeight = 0;

  @override
  void initState() {
    super.initState();
    ttsService = TtsService();
    startSearchController.addListener(_onStartSearchChanged);
    endSearchController.addListener(_onEndSearchChanged);
    startFocusNode.addListener(_onStartFocusChanged);
    endFocusNode.addListener(_onEndFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (fullSearchCardKey.currentContext != null) {
        final RenderBox? renderBox =
            fullSearchCardKey.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null && mounted) {
          setStateIfMounted(() {
            fullSearchCardHeight = renderBox.size.height;
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final newLocationInfo = locationProvider.selectedLocation;

    if (newLocationInfo != null &&
        (lastProcessedLocation == null ||
            newLocationInfo.id != lastProcessedLocation!.id)) {
      _handleLocationChangeUIUpdates(newLocationInfo);
      lastProcessedLocation = newLocationInfo;
    }
  }

  @override
  void dispose() {
    mapController.dispose();
    positionStreamSubscription?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final selectedLocationFromUI = locationProvider.selectedLocation;
    final availableLocationsFromUI = locationProvider.availableLocations;

    final bool isLoading = locationProvider.isLoadingLocationData;
    final vtr.Theme? mapTheme = locationProvider.mapTheme;
    final bool isUiReady = !isLoading &&
        locationProvider.currentRoutingGraph != null &&
        mapTheme != null;

    final apiKey = dotenv.env['MAPTILER_API_KEY'];

    List<Marker> activeMarkers = [];
    if (currentLocationMarker != null) {
      activeMarkers.add(currentLocationMarker!);
    }
    if (startMarker != null) {
      activeMarkers.add(startMarker!);
    }
    if (endMarker != null) {
      activeMarkers.add(endMarker!);
    }

    double currentSearchCardHeight = isRouteActiveForCardSwitch
        ? kCompactCardHeight
        : fullSearchCardHeight > 0
            ? fullSearchCardHeight
            : (kSearchInputRowHeight * 2) +
                kDividerAndSwapButtonHeight +
                (kCardInternalVerticalPadding * 2) +
                (routeDistance != null ? kRouteInfoHeight : 0);

    double instructionCardTop = kSearchCardTopPadding +
        currentSearchCardHeight +
        kInstructionCardSpacing;

    double searchResultsTopPosition = instructionCardTop;
    bool instructionCardVisible = currentDisplayedManeuver != null &&
        currentDisplayedManeuver!.turnType != TurnType.depart &&
        !(currentManeuvers.length <= 2 &&
            currentDisplayedManeuver!.turnType == TurnType.arrive);

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
            onPressed: isUiReady ? ttsService.testSpeak : null,
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
            message: useMockLocation
                ? "Echtes GPS aktivieren"
                : "Mock-Position aktivieren",
            child: IconButton(
              icon: Icon(
                  useMockLocation ? Icons.location_on : Icons.location_off),
              color: useMockLocation ? Colors.orangeAccent : Colors.white,
              onPressed: isUiReady ? _toggleMockLocation : null,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
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
                            MapEventSource.flingAnimationController)) {
                  if (followGps) {
                    setStateIfMounted(() {
                      followGps = false;
                      showSnackbar("Follow-GPS Modus deaktiviert.",
                          durationSeconds: 2);
                    });
                  }
                }

                if (mapEvent is MapEventMove &&
                    (mapEvent.source == MapEventSource.dragStart ||
                        mapEvent.source ==
                            MapEventSource.flingAnimationController) &&
                    (startFocusNode.hasFocus || endFocusNode.hasFocus)) {
                  if (startFocusNode.hasFocus) {
                    startFocusNode.unfocus();
                  }
                  if (endFocusNode.hasFocus) {
                    endFocusNode.unfocus();
                  }
                  // KORREKTUR: curly_braces_in_flow_control_structures
                  if (routePolyline != null) {
                    setStateIfMounted(() {
                      isRouteActiveForCardSwitch = true;
                    });
                  }
                }
              },
              onMapReady: () {
                if (!mounted) return;
                setState(() => isMapReady = true);
                final locationProvider =
                    Provider.of<LocationProvider>(context, listen: false);
                if (locationProvider.selectedLocation != null &&
                    currentGpsPosition == null) {
                  _initializeGpsOrMock(locationProvider.selectedLocation!);
                } else {
                  _performInitialMapMove();
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && fullSearchCardKey.currentContext != null) {
                    final RenderBox? renderBox =
                        fullSearchCardKey.currentContext!.findRenderObject()
                            as RenderBox?;
                    if (renderBox != null && renderBox.hasSize) {
                      setStateIfMounted(() {
                        fullSearchCardHeight = renderBox.size.height;
                      });
                    }
                  }
                });
              },
            ),
            children: [
              if (isUiReady)
                VectorTileLayer(
                  theme: mapTheme,
                  fileCacheTtl: const Duration(days: 7),
                  tileProviders: TileProviders({
                    // KORREKTER Klassenname und Import (package:vector_map_tiles/vector_map_tiles.dart)
                    'maptiler':
                        MaptilerVectorTileProvider(apiKey: apiKey ?? ''),
                  }),
                )
              else
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
              if (isUiReady && routePolyline != null)
                PolylineLayer(polylines: [routePolyline!]),
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
                child: isRouteActiveForCardSwitch && isUiReady
                    ? buildCompactRouteInfoCard(
                        key: const ValueKey('compactCard'))
                    : buildSearchInputCard(
                        key: const ValueKey('searchInputCard')),
              ),
            ),
          ),
          if (instructionCardVisible && isUiReady && !_isInRouteOverviewMode)
            Positioned(
                top: instructionCardTop,
                left: kSearchCardHorizontalMargin,
                right: kSearchCardHorizontalMargin,
                child: Center(
                  child: TurnInstructionCard(
                    maneuver: currentDisplayedManeuver!,
                    maxWidth: kSearchCardMaxWidth + 50,
                  ),
                )),
          if (showSearchResults &&
              searchResults.isNotEmpty &&
              isUiReady &&
              !isRouteActiveForCardSwitch)
            Positioned(
              top: searchResultsTopPosition,
              left: kSearchCardHorizontalMargin,
              right: kSearchCardHorizontalMargin,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: kSearchCardMaxWidth),
                  child: Card(
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0)),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.3),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final feature = searchResults[index];
                          return ListTile(
                            leading: Icon(getIconForFeatureType(feature.type)),
                            title: Text(feature.name),
                            subtitle: Text("Typ: ${feature.type}"),
                            onTap: () => selectFeatureAndSetPoint(feature),
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (isCalculatingRoute && isUiReady)
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
          if (isUiReady && routePolyline != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: "toggleOverviewBtn",
                onPressed: _toggleRouteOverview,
                tooltip: _isInRouteOverviewMode
                    ? 'Zur Navigationsansicht wechseln'
                    : 'Routenübersicht anzeigen',
                child: Icon(_isInRouteOverviewMode
                    ? Icons.zoom_in_map
                    : Icons.map_outlined),
              ),
            ),
          if (isUiReady &&
              (routePolyline != null ||
                  startMarker != null ||
                  endMarker != null))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: "clearAllBtn",
                onPressed: () =>
                    clearRoute(showConfirmation: true, clearMarkers: true),
                tooltip: 'Route, Start & Ziel löschen',
                child: const Icon(Icons.delete_forever_outlined),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.small(
              heroTag: "centerBtn",
              onPressed: isUiReady ? _centerOnGps : null,
              tooltip: followGps && !_isInRouteOverviewMode
                  ? 'Follow-GPS Modus aktiv'
                  : 'Follow-GPS Modus aktivieren',
              backgroundColor:
                  followGps ? Colors.greenAccent[700] : Colors.deepOrangeAccent,
              child: Icon(followGps ? Icons.navigation : Icons.my_location),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // --- Platzhalter für die restlichen Methoden von MapScreenState ---
  // (Diese sind identisch zur vorherigen Version und werden hier nicht wiederholt,
  //  sollten aber im vollständigen Code vorhanden sein:
  // _onStartSearchChanged, _onEndSearchChanged, _updateSearchResults,
  // _onStartFocusChanged, _onEndFocusChanged, _onLocationSelectedFromDropdown,
  // _handleLocationChangeUIUpdates, _toggleMockLocation, _initializeGpsOrMock,
  // _performInitialMapMove, setStateIfMounted, selectFeatureAndSetPoint,
  // _initializeGpsReal, _updateCurrentManeuverOnGpsUpdate,
  // calculateAndDisplayRoute, _handleMapTap, _setPointFromMapTap, clearRoute,
  // _centerOnGps, _toggleRouteOverview, _showRouteOverview, swapStartAndEnd,
  // _distanceToSegment, _calculateDistanceToPolyline
  // )

  void _onStartSearchChanged() {
    if (!mounted) return;
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final query = startSearchController.text.toLowerCase().trim();
    _updateSearchResults(query, locationProvider.currentSearchableFeatures);
    setStateIfMounted(() {
      showSearchResults = startFocusNode.hasFocus &&
          query.isNotEmpty &&
          searchResults.isNotEmpty;
    });
  }

  void _onEndSearchChanged() {
    if (!mounted) return;
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final query = endSearchController.text.toLowerCase().trim();
    _updateSearchResults(query, locationProvider.currentSearchableFeatures);
    setStateIfMounted(() {
      showSearchResults =
          endFocusNode.hasFocus && query.isNotEmpty && searchResults.isNotEmpty;
    });
  }

  void _updateSearchResults(String query, List<SearchableFeature> features) {
    if (query.isNotEmpty && features.isNotEmpty) {
      searchResults = features.where((feature) {
        return feature.name.toLowerCase().contains(query) ||
            feature.type.toLowerCase().contains(query);
      }).toList();
    } else {
      searchResults = [];
    }
  }

  void _onStartFocusChanged() {
    if (!mounted) return;
    final bool hasFocus = startFocusNode.hasFocus;
    setStateIfMounted(() {
      if (hasFocus) {
        activeSearchField = ActiveSearchField.start;
        isRouteActiveForCardSwitch = false;
        _isInRouteOverviewMode = false;
        showSearchResults =
            startSearchController.text.isNotEmpty && searchResults.isNotEmpty;
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted &&
              !startFocusNode.hasFocus &&
              activeSearchField == ActiveSearchField.start) {
            setStateIfMounted(() {
              showSearchResults = false;
              if (!endFocusNode.hasFocus && routePolyline != null) {
                isRouteActiveForCardSwitch = true;
              }
            });
          }
        });
      }
    });
  }

  void _onEndFocusChanged() {
    if (!mounted) return;
    final bool hasFocus = endFocusNode.hasFocus;
    setStateIfMounted(() {
      if (hasFocus) {
        activeSearchField = ActiveSearchField.end;
        isRouteActiveForCardSwitch = false;
        showSearchResults =
            endSearchController.text.isNotEmpty && searchResults.isNotEmpty;
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted &&
              !endFocusNode.hasFocus &&
              activeSearchField == ActiveSearchField.end) {
            setStateIfMounted(() {
              showSearchResults = false;
              if (!startFocusNode.hasFocus && routePolyline != null) {
                isRouteActiveForCardSwitch = true;
              }
            });
          }
        });
      }
    });
  }

  void _onLocationSelectedFromDropdown(LocationInfo? newLocationParam) {
    if (newLocationParam == null) return;
    Provider.of<LocationProvider>(context, listen: false)
        .selectLocation(newLocationParam);
  }

  void _handleLocationChangeUIUpdates(LocationInfo newLocation) {
    if (!mounted) return;
    final bool isActualChange = lastProcessedLocation != null &&
        lastProcessedLocation!.id != newLocation.id;
    setState(() {
      routePolyline = null;
      startMarker = null;
      endMarker = null;
      startLatLng = null;
      endLatLng = null;
      startSearchController.clear();
      endSearchController.clear();
      searchResults = [];
      showSearchResults = false;
      activeSearchField = ActiveSearchField.none;
      routeDistance = null;
      routeTimeMinutes = null;
      remainingRouteDistance = null;
      remainingRouteTimeMinutes = null;
      currentManeuvers = [];
      currentDisplayedManeuver = null;
      followGps = false;
      isRouteActiveForCardSwitch = false;
      _isInRouteOverviewMode = false;
    });
    if (isMapReady && mounted) {
      mapController.move(newLocation.initialCenter, 17.0);
    }
    if (isActualChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showSnackbar("Standort geändert zu: ${newLocation.name}",
              durationSeconds: 3);
        }
      });
    }
    if (kDebugMode) {
      print(
          "[MapScreen._handleLocationChangeUIUpdates] Standort UI Updates für ${newLocation.name}. GeoJSON: ${newLocation.geojsonAssetPath}");
    }
    _initializeGpsOrMock(newLocation);
  }

  void _toggleMockLocation() {
    if (!mounted) return;
    final currentLocationInfo =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    setState(() {
      useMockLocation = !useMockLocation;
      followGps = !useMockLocation && routePolyline != null;
      if (followGps) {
        _isInRouteOverviewMode = false;
      }

      if (!useMockLocation &&
          startSearchController.text.toLowerCase().contains("mock position")) {
        startLatLng = null;
        startMarker = null;
        startSearchController.clear();
        routePolyline = null;
        routeDistance = null;
        routeTimeMinutes = null;
        remainingRouteDistance = null;
        remainingRouteTimeMinutes = null;
        currentManeuvers = [];
        currentDisplayedManeuver = null;
        isRouteActiveForCardSwitch = false;
        _isInRouteOverviewMode = false;
      }
      if (currentLocationInfo != null) {
        _initializeGpsOrMock(currentLocationInfo);
      }
    });
    showSnackbar(
        useMockLocation
            ? "Mock-Position (${currentLocationInfo?.name ?? 'Fallback'}) aktiviert."
            : "Echtes GPS aktiviert. Follow-Modus ${followGps ? "an" : "aus"}.",
        durationSeconds: 4);
  }

  void _initializeGpsOrMock(LocationInfo location) {
    positionStreamSubscription?.cancel();
    LatLng? oldGpsPos = currentGpsPosition;

    setStateIfMounted(() {
      currentGpsPosition = null;
      currentLocationMarker = null;
    });
    final LatLng activeInitialCenterForMock = location.initialCenter;

    if (useMockLocation) {
      setStateIfMounted(() {
        followGps = false;
        _isInRouteOverviewMode = routePolyline != null;
      });
      if (kDebugMode) {
        print(
            "[MapScreen._initializeGpsOrMock] Mock-Modus AKTIV. Setze Position auf initialCenter von ${location.name}: $activeInitialCenterForMock.");
      }
      if (mounted) {
        setState(() {
          currentGpsPosition = activeInitialCenterForMock;
          currentLocationMarker = createMarker(
              activeInitialCenterForMock,
              Colors.orangeAccent,
              Icons.pin_drop,
              "Mock Position (${location.name})");
          if (startSearchController.text == "Aktueller Standort" ||
              (startSearchController.text
                      .toLowerCase()
                      .contains("mock position") &&
                  oldGpsPos != currentGpsPosition)) {
            startLatLng = activeInitialCenterForMock;
            if (startLatLng != null) {
              startMarker = createMarker(startLatLng!, Colors.green,
                  Icons.flag_circle, "Start: Mock Position (${location.name})");
            }
            startSearchController.text = "Mock Position (${location.name})";
          }
          if (routePolyline != null &&
              endLatLng != null &&
              currentGpsPosition != null) {
            remainingRouteDistance =
                distanceCalculatorInstance(currentGpsPosition!, endLatLng!);
            remainingRouteTimeMinutes =
                RoutingService.estimateWalkingTimeMinutes(
                    remainingRouteDistance!);
          }
        });
        if (isMapReady && mounted) {
          if (_isInRouteOverviewMode && routePolyline != null) {
            _showRouteOverview();
          } else {
            mapController.move(activeInitialCenterForMock, _followGpsZoomLevel);
          }
        }
        if (startLatLng != null && endLatLng != null) {
          calculateAndDisplayRoute();
        }
      }
    } else {
      if (kDebugMode) {
        print(
            "[MapScreen._initializeGpsOrMock] Echtes GPS AKTIV. Starte Initialisierung für ${location.name}...");
      }
      _initializeGpsReal(location);
    }
  }

  void _performInitialMapMove() {
    if (!mounted || !isMapReady) return;
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final location = locationProvider.selectedLocation;
    if (location == null) return;

    LatLng? targetToMoveToNullSafe;
    if (useMockLocation) {
      targetToMoveToNullSafe = currentGpsPosition ?? location.initialCenter;
    } else {
      if (currentGpsPosition != null) {
        const distance = Distance();
        if (distance(currentGpsPosition!, location.initialCenter) <=
            centerOnGpsMaxDistanceMeters) {
          targetToMoveToNullSafe = currentGpsPosition;
        } else {
          targetToMoveToNullSafe = location.initialCenter;
        }
      } else {
        targetToMoveToNullSafe = location.initialCenter;
      }
    }

    if (mounted && targetToMoveToNullSafe != null) {
      mapController.move(
          targetToMoveToNullSafe,
          (followGps && !useMockLocation && !_isInRouteOverviewMode)
              ? _followGpsZoomLevel
              : 17.0);
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void selectFeatureAndSetPoint(SearchableFeature feature) {
    if (kDebugMode) {
      print(
          "[MapScreen.selectFeatureAndSetPoint] Feature ${feature.name} für Feld $activeSearchField ausgewählt.");
    }
    if (!mounted) return;

    TextEditingController? controllerToUpdate;
    FocusNode focusToUnset;
    FocusNode? nextFocus;
    bool isStartField = activeSearchField == ActiveSearchField.start;

    if (isStartField) {
      controllerToUpdate = startSearchController;
      focusToUnset = startFocusNode;
      nextFocus = endSearchController.text.isEmpty ? endFocusNode : null;
      setStateIfMounted(() {
        startLatLng = feature.center;
        startMarker = createMarker(feature.center, Colors.green,
            Icons.flag_circle, "Start: ${feature.name}");
      });
    } else if (activeSearchField == ActiveSearchField.end) {
      controllerToUpdate = endSearchController;
      focusToUnset = endFocusNode;
      nextFocus = startSearchController.text.isEmpty ? startFocusNode : null;
      setStateIfMounted(() {
        endLatLng = feature.center;
        endMarker = createMarker(feature.center, Colors.red, Icons.flag_circle,
            "Ziel: ${feature.name}");
      });
    } else {
      return;
    }

    controllerToUpdate.value = TextEditingValue(
      text: feature.name,
      selection:
          TextSelection.fromPosition(TextPosition(offset: feature.name.length)),
    );

    setStateIfMounted(() {
      showSearchResults = false;
      searchResults = [];
      followGps = false;
      _isInRouteOverviewMode = false;
    });

    focusToUnset.unfocus();

    if (nextFocus != null) {
      FocusScope.of(context).requestFocus(nextFocus);
      setStateIfMounted(() {
        isRouteActiveForCardSwitch = false;
      });
    } else {
      activeSearchField = ActiveSearchField.none;
      if (routePolyline != null) {
        setStateIfMounted(() {
          isRouteActiveForCardSwitch = true;
        });
      }
    }

    if (startLatLng != null && endLatLng != null) {
      calculateAndDisplayRoute();
    } else if (isMapReady && mounted) {
      LatLng? pointToCenter = startLatLng ?? endLatLng;
      if (pointToCenter != null) {
        mapController.move(pointToCenter, 18.0);
      }
    }
  }

  Future<void> _initializeGpsReal(LocationInfo location) async {
    if (kDebugMode) {
      print(
          "[MapScreen._initializeGpsReal] GPS Initialisierung für ${location.name}");
    }
    if (!mounted) return;

    late LocationPermission permission;
    bool serviceEnabled;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showErrorDialog("GPS ist deaktiviert.");
          setStateIfMounted(() => followGps = false);
        }
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showErrorDialog("GPS-Berechtigung verweigert.");
            setStateIfMounted(() => followGps = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showErrorDialog("GPS-Berechtigung dauerhaft verweigert.");
          setStateIfMounted(() => followGps = false);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog("Fehler GPS-Berechtigungen: $e");
        setStateIfMounted(() => followGps = false);
      }
      return;
    }

    final LatLng centerForDistanceCheck = location.initialCenter;
    positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      final bool isFirstFix = currentGpsPosition == null;
      LatLng newGpsPos = LatLng(position.latitude, position.longitude);

      bool significantPositionChange = true;
      if (currentGpsPosition != null) {
        if (distanceCalculatorInstance(currentGpsPosition!, newGpsPos) <
            _significantGpsChangeThreshold) {
          significantPositionChange = false;
        }
      }

      if (significantPositionChange) {
        currentGpsPosition = newGpsPos;
        setStateIfMounted(() {
          currentLocationMarker = createMarker(
              newGpsPos, Colors.blueAccent, Icons.circle, "Meine Position");
          if (startSearchController.text == "Aktueller Standort") {
            startLatLng = currentGpsPosition;
            if (startLatLng != null) {
              startMarker = createMarker(startLatLng!, Colors.green,
                  Icons.flag_circle, "Start: Aktueller Standort");
            }
          }
          if (routePolyline != null &&
              endLatLng != null &&
              currentGpsPosition != null) {
            remainingRouteDistance =
                distanceCalculatorInstance(currentGpsPosition!, endLatLng!);
            remainingRouteTimeMinutes =
                RoutingService.estimateWalkingTimeMinutes(
                    remainingRouteDistance!);
          }
        });
      }

      if (followGps &&
          !_isInRouteOverviewMode &&
          isMapReady &&
          mounted &&
          currentGpsPosition != null &&
          significantPositionChange) {
        mapController.move(currentGpsPosition!, _followGpsZoomLevel);
      } else if (isFirstFix &&
          currentGpsPosition != null &&
          isMapReady &&
          mounted &&
          significantPositionChange) {
        final double meters = distanceCalculatorInstance(
            currentGpsPosition!, centerForDistanceCheck);
        if (meters <= centerOnGpsMaxDistanceMeters) {
          if (!_isInRouteOverviewMode && followGps) {
            mapController.move(currentGpsPosition!, _followGpsZoomLevel);
          } else if (!_isInRouteOverviewMode && !followGps) {
            mapController.move(currentGpsPosition!, 17.0);
          }
        } else {
          showSnackbar(
              "Echte GPS-Position zu weit entfernt vom aktuellen Standort.",
              durationSeconds: 4);
        }
      }

      if (routePolyline != null &&
          currentManeuvers.isNotEmpty &&
          significantPositionChange &&
          currentGpsPosition != null) {
        _updateCurrentManeuverOnGpsUpdate(currentGpsPosition!);
      }

      if (routePolyline != null &&
          routePolyline!.points.isNotEmpty &&
          !isCalculatingRoute &&
          currentGpsPosition != null &&
          significantPositionChange) {
        final double distanceToRoute = _calculateDistanceToPolyline(
            currentGpsPosition!, routePolyline!.points);
        if (distanceToRoute > _offRouteThreshold) {
          if (kDebugMode) {
            print(
                "[MapScreen._initializeGpsReal] VON ROUTE ABGEKOMMEN! Distanz: ${distanceToRoute.toStringAsFixed(1)}m. Schwellenwert: $_offRouteThreshold m. Berechne neu...");
          }
          showSnackbar("Von Route abgekommen. Neue Route wird berechnet...",
              durationSeconds: 3);

          startLatLng = currentGpsPosition;
          startSearchController.text = "Aktueller Standort (neu)";
          if (startLatLng != null) {
            startMarker = createMarker(startLatLng!, Colors.green,
                Icons.flag_circle, "Start: ${startSearchController.text}");
          }
          isRouteActiveForCardSwitch = false;
          _isInRouteOverviewMode = false;
          calculateAndDisplayRoute();
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print("[MapScreen._initializeGpsReal] Fehler GPS-Empfang: $error");
      }
      showErrorDialog("Fehler GPS-Empfang: $error");
      if (mounted) {
        setStateIfMounted(() => followGps = false);
      }
    });
  }

  void _updateCurrentManeuverOnGpsUpdate(LatLng currentPosition) {
    if (currentManeuvers.isEmpty ||
        routePolyline == null ||
        routePolyline!.points.isEmpty) {
      return;
    }

    if (currentDisplayedManeuver == null) {
      Maneuver initialManeuver = currentManeuvers.first;
      if (currentManeuvers.length > 1 &&
          initialManeuver.turnType == TurnType.depart) {
        if (currentManeuvers[1].turnType != TurnType.arrive ||
            currentManeuvers.length == 2) {
          initialManeuver = currentManeuvers[1];
        } else if (currentManeuvers.length > 2 &&
            currentManeuvers[1].turnType == TurnType.arrive) {
          initialManeuver = currentManeuvers[1];
        }
      }
      setStateIfMounted(() {
        currentDisplayedManeuver = initialManeuver;
        if (currentDisplayedManeuver?.instructionText != null) {
          ttsService.speak(currentDisplayedManeuver!.instructionText!);
        }
      });
      if (currentDisplayedManeuver == null) return;
    }

    if (currentDisplayedManeuver!.turnType == TurnType.arrive) {
      return;
    }

    int displayedManeuverIndex =
        currentManeuvers.indexOf(currentDisplayedManeuver!);

    if (displayedManeuverIndex == -1) {
      if (currentManeuvers.isNotEmpty) {
        Maneuver newFallbackManeuver = currentManeuvers.first;
        if (currentManeuvers.length > 1 &&
            newFallbackManeuver.turnType == TurnType.depart) {
          if (currentManeuvers[1].turnType != TurnType.arrive ||
              currentManeuvers.length == 2) {
            newFallbackManeuver = currentManeuvers[1];
          } else if (currentManeuvers.length > 2 &&
              currentManeuvers[1].turnType == TurnType.arrive) {
            newFallbackManeuver = currentManeuvers[1];
          }
        }
        if (currentDisplayedManeuver != newFallbackManeuver) {
          setStateIfMounted(() {
            currentDisplayedManeuver = newFallbackManeuver;
            if (currentDisplayedManeuver?.instructionText != null) {
              ttsService.speak(currentDisplayedManeuver!.instructionText!);
            }
          });
        }
      }
      return;
    }

    final double distanceToDisplayedManeuverPoint = distanceCalculatorInstance(
      currentPosition,
      currentDisplayedManeuver!.point,
    );

    if (distanceToDisplayedManeuverPoint < _maneuverReachedThreshold) {
      final int nextManeuverIndex = displayedManeuverIndex + 1;

      if (nextManeuverIndex < currentManeuvers.length) {
        Maneuver newPotentialManeuver = currentManeuvers[nextManeuverIndex];

        if (newPotentialManeuver.turnType == TurnType.arrive) {
          if (routePolyline != null && routePolyline!.points.isNotEmpty) {
            final LatLng actualDestinationPoint = routePolyline!.points.last;
            final double distanceToActualDestination =
                distanceCalculatorInstance(
              currentPosition,
              actualDestinationPoint,
            );

            if (distanceToActualDestination < _maneuverReachedThreshold) {
              if (newPotentialManeuver != currentDisplayedManeuver) {
                setStateIfMounted(() {
                  currentDisplayedManeuver = newPotentialManeuver;
                  if (currentDisplayedManeuver?.instructionText != null) {
                    ttsService
                        .speak(currentDisplayedManeuver!.instructionText!);
                  }
                });
              }
            }
          }
        } else {
          if (newPotentialManeuver != currentDisplayedManeuver) {
            setStateIfMounted(() {
              currentDisplayedManeuver = newPotentialManeuver;
              if (currentDisplayedManeuver?.instructionText != null) {
                ttsService.speak(currentDisplayedManeuver!.instructionText!);
              }
            });
          }
        }
      }
    }
  }

  Future<void> calculateAndDisplayRoute() async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final RoutingGraph? currentGraphValue =
        locationProvider.currentRoutingGraph;
    final bool isLoadingData = locationProvider.isLoadingLocationData;
    final bool isDataReadyForRouting =
        !isLoadingData && currentGraphValue != null;
    final selectedLocationFromProvider = locationProvider.selectedLocation;

    if (!mounted) return;

    setStateIfMounted(() {
      routePolyline = null;
      routeDistance = null;
      routeTimeMinutes = null;
      remainingRouteDistance = null;
      remainingRouteTimeMinutes = null;
      currentManeuvers = [];
      currentDisplayedManeuver = null;
      isRouteActiveForCardSwitch = false;
      _isInRouteOverviewMode = false;
    });

    if (!isDataReadyForRouting) {
      showErrorDialog(
          "Kartendaten für ${selectedLocationFromProvider?.name ?? ''} nicht bereit.");
      setStateIfMounted(() {
        isCalculatingRoute = false;
        followGps = false;
      });
      return;
    }

    if (currentGraphValue == null || currentGraphValue.nodes.isEmpty) {
      showErrorDialog(
          "Routing-Daten für ${selectedLocationFromProvider?.name ?? ''} nicht verfügbar.");
      setStateIfMounted(() {
        isCalculatingRoute = false;
        followGps = false;
      });
      return;
    }

    if (startLatLng == null || endLatLng == null) {
      setStateIfMounted(() {
        routePolyline = null;
        isCalculatingRoute = false;
        followGps = false;
      });
      return;
    }

    setStateIfMounted(() => isCalculatingRoute = true);

    try {
      currentGraphValue.resetAllNodeCosts();
      final GraphNode? foundStartNode =
          currentGraphValue.findNearestNode(startLatLng!);
      final GraphNode? foundEndNode =
          currentGraphValue.findNearestNode(endLatLng!);

      if (foundStartNode == null || foundEndNode == null) {
        showErrorDialog("Start/Ziel nicht auf Wegenetz gefunden.");
        setStateIfMounted(() {
          routePolyline = null;
          followGps = false;
          isRouteActiveForCardSwitch = false;
        });
      } else if (foundStartNode.id == foundEndNode.id) {
        showSnackbar("Start- und Zielpunkt sind identisch.");
        setStateIfMounted(() {
          currentDisplayedManeuver = Maneuver(
              point: startLatLng!,
              turnType: TurnType.arrive,
              instructionText: "Start- und Zielpunkt sind identisch.");
          if (currentDisplayedManeuver?.instructionText != null) {
            ttsService.speak(currentDisplayedManeuver!.instructionText!);
          }
          routeDistance = 0;
          routeTimeMinutes = 0;
          remainingRouteDistance = 0;
          remainingRouteTimeMinutes = 0;
          routePolyline = Polyline(
              points: [startLatLng!, endLatLng!],
              strokeWidth: 0.1,
              color: Colors.transparent);
          isRouteActiveForCardSwitch = true;
        });
        if (isMapReady && mounted) {
          mapController.move(startLatLng!, mapController.camera.zoom);
        }
      } else {
        final List<LatLng>? routePointsResult = await RoutingService.findPath(
            currentGraphValue, foundStartNode, foundEndNode);
        if (!mounted) return;
        setStateIfMounted(() {
          if (routePointsResult != null && routePointsResult.isNotEmpty) {
            routePolyline = Polyline(
                points: routePointsResult,
                strokeWidth: 5.0,
                color: Colors.deepPurpleAccent);

            routeDistance =
                RoutingService.calculateTotalDistance(routePointsResult);
            routeTimeMinutes =
                RoutingService.estimateWalkingTimeMinutes(routeDistance!);

            remainingRouteDistance = routeDistance;
            remainingRouteTimeMinutes = routeTimeMinutes;

            currentManeuvers =
                RoutingService.analyzeRouteForTurns(routePointsResult);

            if (currentManeuvers.isNotEmpty) {
              currentDisplayedManeuver = currentManeuvers.first;
              if (currentManeuvers.length > 1 &&
                  currentManeuvers.first.turnType == TurnType.depart) {
                if (currentManeuvers[1].turnType != TurnType.arrive ||
                    currentManeuvers.length == 2) {
                  currentDisplayedManeuver = currentManeuvers[1];
                } else if (currentManeuvers.length > 2 &&
                    currentManeuvers[1].turnType == TurnType.arrive) {
                  currentDisplayedManeuver = currentManeuvers[1];
                }
                if (currentManeuvers.first.instructionText != null) {
                  ttsService.speak(currentManeuvers.first.instructionText!);
                }
              } else if (currentManeuvers.first.turnType != TurnType.depart) {
                currentDisplayedManeuver = currentManeuvers.first;
                if (currentDisplayedManeuver?.instructionText != null) {
                  ttsService.speak(currentDisplayedManeuver!.instructionText!);
                }
              }
            } else {
              currentDisplayedManeuver = null;
            }

            isRouteActiveForCardSwitch = true;
            _isInRouteOverviewMode = true;

            if (!useMockLocation) {
              followGps = true;
            } else {
              followGps = false;
              if (currentGpsPosition != null && endLatLng != null) {
                remainingRouteDistance =
                    distanceCalculatorInstance(currentGpsPosition!, endLatLng!);
                remainingRouteTimeMinutes =
                    RoutingService.estimateWalkingTimeMinutes(
                        remainingRouteDistance!);
              }
            }

            showSnackbar("Route berechnet.", durationSeconds: 3);

            if (isMapReady && mounted) {
              try {
                List<LatLng> pointsForBounds = List.from(routePointsResult);
                if (currentGpsPosition != null &&
                    startLatLng == currentGpsPosition) {
                  pointsForBounds.add(currentGpsPosition!);
                }
                if (startFocusNode.hasFocus) {
                  startFocusNode.unfocus();
                }
                if (endFocusNode.hasFocus) {
                  endFocusNode.unfocus();
                }

                mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(pointsForBounds),
                    padding: const EdgeInsets.only(
                        top: kCompactCardHeight + kSearchCardTopPadding + 20,
                        bottom: 80.0,
                        left: 30.0,
                        right: 30.0),
                  ),
                );

                Future.delayed(
                    Duration(seconds: _navigationStartZoomDelaySeconds.toInt()),
                    () {
                  if (mounted && routePolyline != null) {
                    setStateIfMounted(() {
                      _isInRouteOverviewMode = false;
                    });
                    LatLng targetZoomPoint;
                    if (!useMockLocation && currentGpsPosition != null) {
                      targetZoomPoint = currentGpsPosition!;
                    } else if (startLatLng != null) {
                      targetZoomPoint = startLatLng!;
                    } else {
                      targetZoomPoint = routePointsResult.first;
                    }
                    mapController.move(targetZoomPoint, _followGpsZoomLevel);
                    if (!useMockLocation) {
                      setStateIfMounted(() {
                        followGps = true;
                      });
                    }
                  }
                });
              } catch (e) {
                if (kDebugMode) {
                  print(
                      "[MapScreen.calculateAndDisplayRoute] Fehler beim Anpassen der Kartenansicht an die Route: $e");
                  if (endLatLng != null) {
                    mapController.move(endLatLng!, mapController.camera.zoom);
                  }
                }
              }
            }
          } else {
            routePolyline = null;
            currentDisplayedManeuver = null;
            followGps = false;
            isRouteActiveForCardSwitch = false;
            _isInRouteOverviewMode = false;
            showErrorDialog("Keine Route gefunden.");
          }
        });
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
            "[MapScreen.calculateAndDisplayRoute] FEHLER bei Routenberechnung: $e");
        print("[MapScreen.calculateAndDisplayRoute] Stacktrace: $stacktrace");
      }
      showErrorDialog("Fehler Routenberechnung: $e");
      setStateIfMounted(() {
        routePolyline = null;
        followGps = false;
        isRouteActiveForCardSwitch = false;
        _isInRouteOverviewMode = false;
      });
    } finally {
      if (mounted) {
        setStateIfMounted(() => isCalculatingRoute = false);
      }
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    if (kDebugMode) {
      print(
          "[MapScreen._handleMapTap] Tap bei: ${latLng.latitude.toStringAsFixed(6)},${latLng.longitude.toStringAsFixed(6)}. Aktives Feld vor Tap: $activeSearchField");
    }
    if (!mounted) return;
    setStateIfMounted(() {
      followGps = false;
      _isInRouteOverviewMode = false;
    });

    bool hadFocus = startFocusNode.hasFocus || endFocusNode.hasFocus;
    if (startFocusNode.hasFocus) {
      startFocusNode.unfocus();
    }
    if (endFocusNode.hasFocus) {
      endFocusNode.unfocus();
    }

    if (hadFocus || showSearchResults) {
      setStateIfMounted(() {
        showSearchResults = false;
      });
    }
    if (routePolyline != null) {
      setStateIfMounted(() {
        isRouteActiveForCardSwitch = true;
      });
    }

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.isLoadingLocationData ||
        locationProvider.currentRoutingGraph == null) {
      showSnackbar("Kartendaten werden noch geladen.", durationSeconds: 2);
      return;
    }
    if (isCalculatingRoute) {
      return;
    }

    ActiveSearchField fieldToSetByTapDecision = activeSearchField;

    if (fieldToSetByTapDecision == ActiveSearchField.none) {
      if (startLatLng == null && startSearchController.text.isEmpty) {
        fieldToSetByTapDecision = ActiveSearchField.start;
      } else if (endLatLng == null && endSearchController.text.isEmpty) {
        fieldToSetByTapDecision = ActiveSearchField.end;
      } else {
        fieldToSetByTapDecision = ActiveSearchField.end;
      }
    }
    if (kDebugMode) {
      print(
          "[MapScreen._handleMapTap] Feld, das durch Tap gesetzt wird: $fieldToSetByTapDecision");
    }
    setStateIfMounted(() {
      isRouteActiveForCardSwitch = false;
    });

    _setPointFromMapTap(latLng, fieldToSetByTapDecision);
  }

  void _setPointFromMapTap(LatLng latLng, ActiveSearchField fieldToSet) {
    String pointName = (fieldToSet == ActiveSearchField.start)
        ? "Start (Karte)"
        : "Ziel (Karte)";
    TextEditingController relevantController =
        (fieldToSet == ActiveSearchField.start)
            ? startSearchController
            : endSearchController;

    if (kDebugMode) {
      print(
          "[MapScreen._setPointFromMapTap] Setze Punkt für $fieldToSet: ${latLng.latitude.toStringAsFixed(6)},${latLng.longitude.toStringAsFixed(6)}");
    }

    void performUpdateAndRoute() {
      if (!mounted) return;
      setStateIfMounted(() {
        followGps = false;
        _isInRouteOverviewMode = false;
        if (fieldToSet == ActiveSearchField.start) {
          startLatLng = latLng;
          startMarker =
              createMarker(latLng, Colors.green, Icons.flag_circle, pointName);
          relevantController.text = pointName;
        } else {
          endLatLng = latLng;
          endMarker =
              createMarker(latLng, Colors.red, Icons.flag_circle, pointName);
          relevantController.text = pointName;
        }
        routePolyline = null;
        routeDistance = null;
        routeTimeMinutes = null;
        remainingRouteDistance = null;
        remainingRouteTimeMinutes = null;
        currentManeuvers = [];
        currentDisplayedManeuver = null;
        isRouteActiveForCardSwitch = false;
      });

      if (startLatLng != null && endLatLng != null) {
        calculateAndDisplayRoute();
      }
    }

    bool isOverwriting = (fieldToSet == ActiveSearchField.start &&
            startLatLng != null &&
            startSearchController.text.isNotEmpty) ||
        (fieldToSet == ActiveSearchField.end &&
            endLatLng != null &&
            endSearchController.text.isNotEmpty);

    if (isOverwriting) {
      showConfirmationDialog(
          "Neuen ${fieldToSet == ActiveSearchField.start ? 'Start' : 'Ziel'}punkt setzen?",
          "Aktuellen ${fieldToSet == ActiveSearchField.start ? 'Start' : 'Ziel'}punkt '${fieldToSet == ActiveSearchField.start ? startSearchController.text : endSearchController.text}' verwerfen und neuen Punkt auf Karte setzen?",
          performUpdateAndRoute);
    } else {
      performUpdateAndRoute();
    }
  }

  void clearRoute({bool showConfirmation = true, bool clearMarkers = true}) {
    if (kDebugMode) {
      print(
          "[MapScreen.clearRoute] Aufgerufen mit showConfirmation: $showConfirmation, clearMarkers: $clearMarkers");
    }
    void doClearAction() {
      if (!mounted) return;
      setStateIfMounted(() {
        routePolyline = null;
        routeDistance = null;
        routeTimeMinutes = null;
        remainingRouteDistance = null;
        remainingRouteTimeMinutes = null;
        currentManeuvers = [];
        currentDisplayedManeuver = null;
        followGps = false;
        isRouteActiveForCardSwitch = false;
        _isInRouteOverviewMode = false;
        if (clearMarkers) {
          startMarker = null;
          startLatLng = null;
          startSearchController.clear();
          endMarker = null;
          endLatLng = null;
          endSearchController.clear();
          activeSearchField = ActiveSearchField.none;
          showSearchResults = false;
          if (kDebugMode) {
            print("[MapScreen.clearRoute] Alle Marker und Suchfelder geleert.");
          }
        } else {
          if (kDebugMode) {
            print(
                "[MapScreen.clearRoute] Nur Route gelöscht, Marker und Suchfelder beibehalten.");
          }
        }
      });
      showSnackbar(
          clearMarkers
              ? "Route, Start- und Zielpunkt gelöscht."
              : "Route gelöscht.",
          durationSeconds: 2);
    }

    final bool somethingToDelete = routePolyline != null ||
        (clearMarkers &&
            (startMarker != null ||
                endMarker != null ||
                startSearchController.text.isNotEmpty ||
                endSearchController.text.isNotEmpty));

    if (showConfirmation && somethingToDelete) {
      showConfirmationDialog(
          clearMarkers ? "Alles löschen?" : "Route löschen?",
          clearMarkers
              ? "Route, Start- und Zielpunkt wirklich löschen?"
              : "Route wirklich löschen?",
          doClearAction);
    } else if (somethingToDelete) {
      doClearAction();
    } else {
      if (kDebugMode) {
        print("[MapScreen.clearRoute] Nichts zu löschen.");
      }
    }
  }

  void _centerOnGps() {
    if (!mounted) return;
    final selectedLocationFromProvider =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;

    if (useMockLocation) {
      showSnackbar("Follow-Modus ist nur mit echtem GPS verfügbar.",
          durationSeconds: 3);
      LatLng? centerTarget = currentGpsPosition ??
          selectedLocationFromProvider?.initialCenter ??
          fallbackInitialCenter;
      if (centerTarget != null && isMapReady) {
        mapController.move(centerTarget, _followGpsZoomLevel);
        setStateIfMounted(() {
          _isInRouteOverviewMode = false;
        });
      }
      return;
    }

    if (currentGpsPosition != null && isMapReady) {
      setStateIfMounted(() {
        followGps = !followGps;
        if (followGps) {
          _isInRouteOverviewMode = false;
        }
      });
      if (kDebugMode) {
        print(
            "[MapScreen._centerOnGps] Follow-GPS Modus umgeschaltet auf: $followGps");
      }

      if (followGps && !_isInRouteOverviewMode) {
        mapController.move(currentGpsPosition!, _followGpsZoomLevel);
        showSnackbar("Follow-GPS Modus aktiviert.", durationSeconds: 2);
      } else if (!followGps) {
        showSnackbar("Follow-GPS Modus deaktiviert.", durationSeconds: 2);
      } else if (_isInRouteOverviewMode) {
        setStateIfMounted(() {
          _isInRouteOverviewMode = false;
        });
        mapController.move(currentGpsPosition!, _followGpsZoomLevel);
        showSnackbar("Zur Navigationsansicht gewechselt.", durationSeconds: 2);
      }
    } else {
      showSnackbar(
          "Aktuelle GPS-Position nicht verfügbar oder Karte nicht bereit.",
          durationSeconds: 3);
      if (kDebugMode) {
        print(
            "[MapScreen._centerOnGps] Follow-GPS nicht möglich. currentGpsPosition: $currentGpsPosition, isMapReady: $isMapReady");
      }
    }
  }

  void _toggleRouteOverview() {
    if (!mounted || routePolyline == null) {
      showSnackbar("Keine aktive Route zur Ansicht vorhanden.",
          durationSeconds: 2);
      return;
    }

    setStateIfMounted(() {
      _isInRouteOverviewMode = !_isInRouteOverviewMode;
      if (_isInRouteOverviewMode) {
        followGps = false;
        _showRouteOverview();
      } else {
        LatLng targetZoomPoint;
        if (!useMockLocation && currentGpsPosition != null) {
          targetZoomPoint = currentGpsPosition!;
          followGps = true;
        } else if (startLatLng != null) {
          targetZoomPoint = startLatLng!;
        } else {
          targetZoomPoint = routePolyline!.points.first;
        }
        mapController.move(targetZoomPoint, _followGpsZoomLevel);
        if (!useMockLocation && currentGpsPosition != null) {
          setStateIfMounted(() {
            followGps = true;
          });
        }
      }
    });
    showSnackbar(
        _isInRouteOverviewMode
            ? "Routenübersicht aktiviert."
            : "Navigationsansicht aktiviert.",
        durationSeconds: 2);
  }

  void _showRouteOverview() {
    if (routePolyline != null &&
        routePolyline!.points.isNotEmpty &&
        isMapReady &&
        mounted) {
      List<LatLng> pointsForBounds = List.from(routePolyline!.points);
      if (currentGpsPosition != null && startLatLng == currentGpsPosition) {
        pointsForBounds.add(currentGpsPosition!);
      }
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pointsForBounds),
          padding: const EdgeInsets.only(
              top: kCompactCardHeight + kSearchCardTopPadding + 20,
              bottom: 80.0,
              left: 30.0,
              right: 30.0),
        ),
      );
    }
  }

  void swapStartAndEnd() {
    if (!mounted) return;
    if (kDebugMode) {
      print("[MapScreen.swapStartAndEnd] Tausche Start und Ziel.");
    }

    if (startLatLng == null && endLatLng == null) {
      showSnackbar("Kein Start- oder Zielpunkt zum Tauschen vorhanden.",
          durationSeconds: 3);
      return;
    }

    setStateIfMounted(() {
      final LatLng? tempLatLng = startLatLng;
      startLatLng = endLatLng;
      endLatLng = tempLatLng;

      final String tempStartText = startSearchController.text;
      startSearchController.text = endSearchController.text;
      endSearchController.text = tempStartText;

      if (startLatLng != null) {
        startMarker = createMarker(
          startLatLng!,
          Colors.green,
          Icons.flag_circle,
          "Start: ${startSearchController.text.isNotEmpty ? startSearchController.text : 'Gesetzter Punkt'}",
        );
      } else {
        startMarker = null;
      }

      if (endLatLng != null) {
        endMarker = createMarker(
          endLatLng!,
          Colors.red,
          Icons.flag_circle,
          "Ziel: ${endSearchController.text.isNotEmpty ? endSearchController.text : 'Gesetzter Punkt'}",
        );
      } else {
        endMarker = null;
      }

      routeDistance = null;
      routeTimeMinutes = null;
      remainingRouteDistance = null;
      remainingRouteTimeMinutes = null;
      currentManeuvers = [];
      currentDisplayedManeuver = null;
      followGps = false;
      isRouteActiveForCardSwitch = false;
      _isInRouteOverviewMode = false;

      if (startLatLng != null && endLatLng != null) {
        calculateAndDisplayRoute();
      } else {
        routePolyline = null;
      }
    });

    showSnackbar("Start und Ziel getauscht.", durationSeconds: 2);
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
    double cosPBA = (pow(distBP, 2) + pow(distAB, 2) - pow(distAP, 2)) /
        (2 * distBP * distAB);

    if (cosPAB < 0) return distAP;
    if (cosPBA < 0) return distBP;

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
      return distanceCalculatorInstance(p, polyline.first);

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final LatLng a = polyline[i];
      final LatLng b = polyline[i + 1];
      final double distanceToCurrentSegment =
          _distanceToSegment(p, a, b, distanceCalculatorInstance);
      if (distanceToCurrentSegment < minDistance) {
        minDistance = distanceToCurrentSegment;
      }
    }
    return minDistance;
  }
}
