// lib/screens/map_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:vector_map_tiles/vector_map_tiles.dart'
    as vector_map_tiles; // Alias hinzugefügt
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

  static const Distance distanceCalculatorInstance = Distance();

  bool isRouteActiveForCardSwitch = false;
  final GlobalKey fullSearchCardKey = GlobalKey();
  double fullSearchCardHeight = 0;

  String _maptilerUrlTemplate = '';

  @override
  void initState() {
    super.initState();
    ttsService = TtsService();
    startSearchController.addListener(_onStartSearchChanged);
    endSearchController.addListener(_onEndSearchChanged);
    startFocusNode.addListener(_onStartFocusChanged);
    endFocusNode.addListener(_onEndFocusChanged);

    final apiKey = dotenv.env['MAPTILER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      if (kDebugMode) {
        print("WARNUNG: MAPTILER_API_KEY nicht in .env gefunden!");
      }
      _maptilerUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    } else {
      _maptilerUrlTemplate =
          'https://api.maptiler.com/maps/dataviz/{z}/{x}/{y}.pbf?key=$apiKey';
    }

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

    final isLoading = locationProvider.isLoadingLocationData;
    final mapThemeFromProvider = locationProvider.mapTheme; // Corrected usage
    final isGraphReady = locationProvider.currentRoutingGraph != null;

    final isUiReady =
        !isLoading && isGraphReady && mapThemeFromProvider != null;

    final List<Marker> activeMarkers = [];
    if (currentLocationMarker != null) {
      activeMarkers.add(currentLocationMarker!);
    }
    if (startMarker != null) {
      activeMarkers.add(startMarker!);
    }
    if (endMarker != null) {
      activeMarkers.add(endMarker!);
    }

    final double currentSearchCardHeight = isRouteActiveForCardSwitch
        ? kCompactCardHeight
        : fullSearchCardHeight > 0
            ? fullSearchCardHeight
            : (kSearchInputRowHeight * 2) +
                kDividerAndSwapButtonHeight +
                (kCardInternalVerticalPadding * 2) +
                (routeDistance != null ? kRouteInfoHeight : 0);

    final double instructionCardTop = kSearchCardTopPadding +
        currentSearchCardHeight +
        kInstructionCardSpacing;

    double searchResultsTopPosition = instructionCardTop;
    final bool instructionCardVisible = currentDisplayedManeuver != null &&
        currentDisplayedManeuver!.turnType != TurnType.depart &&
        !(currentManeuvers.length <= 2 &&
            currentDisplayedManeuver!.turnType == TurnType.arrive);

    if (instructionCardVisible) {
      searchResultsTopPosition += 65.0 + kInstructionCardSpacing;
    }

    Widget mapLayerWidget;
    final bool vectorConditionsMet = isUiReady &&
        _maptilerUrlTemplate.isNotEmpty &&
        _maptilerUrlTemplate.contains('key=');

    if (vectorConditionsMet) {
      if (kDebugMode) {
        print(
            "[DIAGNOSE] MapScreen build: Erzeuge VectorTileLayer für '${selectedLocationFromUI?.name ?? 'Unbekannt'}'");
      }
      mapLayerWidget = vector_map_tiles.VectorTileLayer(
        // Corrected usage with alias
        theme: mapThemeFromProvider,
        fileCacheTtl: const Duration(days: 7),
        tileProviders: vector_map_tiles.TileProviders({
          // Corrected usage with alias
          'maptiler_planet': vector_map_tiles.NetworkVectorTileProvider(
            // Corrected usage with alias
            urlTemplate: _maptilerUrlTemplate,
            maximumZoom: 14,
          ),
        }),
        maximumZoom: 20,
      );
    } else {
      if (kDebugMode) {
        print(
            "[DIAGNOSE] MapScreen build: Bedingungen für VectorTileLayer nicht erfüllt, erzeuge Fallback TileLayer (OSM). isUiReady=$isUiReady, template='$_maptilerUrlTemplate', styleNull=${mapThemeFromProvider == null}");
      }
      mapLayerWidget = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.camping_osm_navi',
      );
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
                  onChanged:
                      !isLoading ? _onLocationSelectedFromDropdown : null,
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
              onPressed: !isLoading ? _toggleMockLocation : null,
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
              maxZoom: 20.0,
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
                  _unfocusSearchFieldsAndCollapse();
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
              mapLayerWidget,
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
                            dense: true, // Hinzugefügt
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
                tooltip: "Ganze Route anzeigen",
                child: Icon(_isInRouteOverviewMode
                    ? Icons.my_location
                    : Icons.zoom_out_map),
              ),
            ),
          if (isUiReady)
            FloatingActionButton(
              heroTag: "centerGpsBtn",
              onPressed: _centerOnGps,
              tooltip: 'Auf GPS zentrieren',
              child: Icon(
                followGps ? Icons.navigation : Icons.near_me,
                color: followGps ? Colors.blue : Colors.black,
              ),
            ),
        ],
      ),
    );
  }

  void _unfocusSearchFieldsAndCollapse() {
    if (startFocusNode.hasFocus) {
      startFocusNode.unfocus();
    }
    if (endFocusNode.hasFocus) {
      endFocusNode.unfocus();
    }
    if (routePolyline != null) {
      setStateIfMounted(() {
        isRouteActiveForCardSwitch = true;
      });
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _onLocationSelectedFromDropdown(LocationInfo? newLocation) {
    if (newLocation != null) {
      Provider.of<LocationProvider>(context, listen: false)
          .selectLocation(newLocation);
    }
  }

  @override
  void showSnackbar(String message, {int durationSeconds = 3}) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          duration: Duration(seconds: durationSeconds)));
    }
  }

  void _handleLocationChangeUIUpdates(LocationInfo newLocation) {
    _resetRouteAndNavigation();
    _resetSearchFields();
    _performInitialMapMove(newLocation: newLocation);
    _initializeGpsOrMock(newLocation);
  }

  void _resetSearchFields() {
    startSearchController.clear();
    endSearchController.clear();
    setStateIfMounted(() {
      searchResults.clear();
      showSearchResults = false;
      startLatLng = null;
      endLatLng = null;
      startMarker = null;
      endMarker = null;
    });
  }

  void _resetRouteAndNavigation() {
    setStateIfMounted(() {
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
    });
  }

  void _performInitialMapMove({LocationInfo? newLocation}) {
    final locationToCenterOn = newLocation ??
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    if (isMapReady && locationToCenterOn != null) {
      mapController.move(locationToCenterOn.initialCenter, 17.0);
    }
  }

  void _initializeGpsOrMock(LocationInfo location) {
    if (useMockLocation) {
      _initializeMockGps(location);
    } else {
      _initializeGpsReal();
    }
  }

  void _initializeMockGps(LocationInfo location) {
    positionStreamSubscription?.cancel();
    setStateIfMounted(() {
      currentGpsPosition = location.initialCenter;
      _updateCurrentLocationMarker();
    });
    showSnackbar("Mock-GPS aktiv an Position: ${location.name}",
        durationSeconds: 2);
  }

  Future<void> _initializeGpsReal() async {
    positionStreamSubscription?.cancel();
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showSnackbar("Standortdienste sind deaktiviert.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        showSnackbar("Standortberechtigung verweigert.");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      showSnackbar("Standortberechtigung dauerhaft verweigert.");
      return;
    }

    const LocationSettings locationSettings =
        LocationSettings(accuracy: LocationAccuracy.bestForNavigation);

    positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position newGpsPos) {
      final newGpsLatLng = LatLng(newGpsPos.latitude, newGpsPos.longitude);
      double distanceToCurrent = 0;
      if (currentGpsPosition != null) {
        distanceToCurrent = distanceCalculatorInstance.distance(
            newGpsLatLng, currentGpsPosition!);
      }

      final bool significantPositionChange = currentGpsPosition == null ||
          distanceToCurrent > _significantGpsChangeThreshold;

      if (significantPositionChange) {
        setStateIfMounted(() {
          currentGpsPosition = newGpsLatLng;
          _updateCurrentLocationMarker();
        });

        if (currentManeuvers.isNotEmpty) {
          _updateCurrentManeuverOnGpsUpdate(newGpsLatLng);
        }

        if (followGps) {
          mapController.move(newGpsLatLng, _followGpsZoomLevel);
        }
      }
    }, onError: (error) {
      showSnackbar("Fehler beim Empfangen des GPS-Signals.");
    });
  }

  void _toggleMockLocation() {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final selectedLocation = locationProvider.selectedLocation;
    if (selectedLocation == null) {
      showSnackbar("Kein Standort ausgewählt, kann Modus nicht wechseln.");
      return;
    }

    setStateIfMounted(() {
      useMockLocation = !useMockLocation;
      followGps = false;
      _resetRouteAndNavigation();
      _initializeGpsOrMock(selectedLocation);
    });
  }

  void _centerOnGps() {
    if (currentGpsPosition == null) {
      showSnackbar("Aktuelle GPS-Position ist unbekannt.");
      return;
    }
    final selectedLocation =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;
    if (selectedLocation != null) {
      final distanceToCenter = distanceCalculatorInstance.distance(
          currentGpsPosition!, selectedLocation.initialCenter);
      if (distanceToCenter > centerOnGpsMaxDistanceMeters) {
        showSnackbar(
            "Du bist zu weit vom Campingplatz entfernt, um zu zentrieren.");
        return;
      }
    }

    setStateIfMounted(() {
      followGps = true;
    });

    mapController.move(currentGpsPosition!, _followGpsZoomLevel);
    showSnackbar("Follow-GPS Modus aktiviert.", durationSeconds: 2);
  }

  void _onStartSearchChanged() {
    if (startFocusNode.hasFocus &&
        startSearchController.text != "Aktueller Standort") {
      _filterFeatures(startSearchController.text);
    }
  }

  void _onEndSearchChanged() {
    if (endFocusNode.hasFocus) {
      _filterFeatures(endSearchController.text);
    }
  }

  void _onStartFocusChanged() {
    setStateIfMounted(() {
      if (startFocusNode.hasFocus) {
        activeSearchField = ActiveSearchField.start;
        isRouteActiveForCardSwitch = false;
        if (startSearchController.text != "Aktueller Standort") {
          _filterFeatures(startSearchController.text);
        }
      } else {
        if (activeSearchField == ActiveSearchField.start) {
          activeSearchField = ActiveSearchField.none;
        }
        _hideSearchResultsAfterDelay();
      }
    });
  }

  void _onEndFocusChanged() {
    setStateIfMounted(() {
      if (endFocusNode.hasFocus) {
        activeSearchField = ActiveSearchField.end;
        isRouteActiveForCardSwitch = false;
        _filterFeatures(endSearchController.text);
      } else {
        if (activeSearchField == ActiveSearchField.end) {
          activeSearchField = ActiveSearchField.none;
        }
        _hideSearchResultsAfterDelay();
      }
    });
  }

  void _filterFeatures(String query) {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final allFeatures = locationProvider.currentSearchableFeatures;

    if (query.isEmpty) {
      setStateIfMounted(() {
        searchResults = allFeatures;
        showSearchResults = true;
      });
      return;
    }
    setStateIfMounted(() {
      searchResults = allFeatures
          .where((feature) =>
              feature.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      showSearchResults = true;
    });
  }

  void _hideSearchResultsAfterDelay() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!startFocusNode.hasFocus && !endFocusNode.hasFocus) {
        setStateIfMounted(() {
          showSearchResults = false;
        });
      }
    });
  }

  void selectFeatureAndSetPoint(SearchableFeature feature) {
    final point = feature.center;

    setStateIfMounted(() {
      if (activeSearchField == ActiveSearchField.start) {
        startSearchController.text = feature.name;
        startLatLng = point;
        _updateStartMarker();
        startFocusNode.unfocus();
      } else if (activeSearchField == ActiveSearchField.end) {
        endSearchController.text = feature.name;
        endLatLng = point;
        _updateEndMarker();
        endFocusNode.unfocus();
      }
      showSearchResults = false;
      _calculateRouteIfPossible();
    });
  }

  void setStartToCurrentLocation() {
    if (currentGpsPosition == null) {
      showSnackbar("Aktuelle Position unbekannt.");
      return;
    }
    setStateIfMounted(() {
      startSearchController.text = "Aktueller Standort";
      startLatLng = currentGpsPosition;
      startMarker = null; // Kein Marker für die aktuelle Position
      _calculateRouteIfPossible();
      startFocusNode.unfocus();
    });
  }

  void swapStartAndEnd() {
    final tempName = startSearchController.text;
    final tempLatLng = startLatLng;

    setStateIfMounted(() {
      startSearchController.text = endSearchController.text;
      startLatLng = endLatLng;
      endSearchController.text = tempName;
      endLatLng = tempLatLng;
      _updateStartMarker();
      _updateEndMarker();
      _calculateRouteIfPossible();
    });
  }

  void _handleMapTap(TapPosition tapPos, LatLng latlng) {
    if (isCalculatingRoute) return;

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final graph = locationProvider.currentRoutingGraph;
    if (graph == null) return;

    final nearestNode = _findNearestNode(latlng, graph);
    if (nearestNode == null) {
      showSnackbar("Kein Weg in der Nähe gefunden.");
      return;
    }

    final pointOnGraph = nearestNode.position;
    final pointName = "Punkt auf Karte";

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Als Startpunkt'),
                onTap: () {
                  Navigator.pop(context);
                  setStateIfMounted(() {
                    startSearchController.text = pointName;
                    startLatLng = pointOnGraph;
                    _updateStartMarker();
                    _calculateRouteIfPossible();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Als Ziel'),
                onTap: () {
                  Navigator.pop(context);
                  setStateIfMounted(() {
                    endSearchController.text = pointName;
                    endLatLng = pointOnGraph;
                    _updateEndMarker();
                    _calculateRouteIfPossible();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _calculateRouteIfPossible() async {
    if (startLatLng == null || endLatLng == null) {
      return;
    }

    setStateIfMounted(() {
      isCalculatingRoute = true;
    });

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final graph = locationProvider.currentRoutingGraph;

    if (graph == null) {
      showSnackbar("Routing-Graph ist nicht geladen.");
      setStateIfMounted(() => isCalculatingRoute = false);
      return;
    }

    final startNode = _findNearestNode(startLatLng!, graph);
    final endNode = _findNearestNode(endLatLng!, graph);

    if (startNode == null || endNode == null) {
      showSnackbar("Start- oder Endpunkt liegt außerhalb des Wegnetzes.");
      setStateIfMounted(() => isCalculatingRoute = false);
      return;
    }

    final List<LatLng>? pathPoints =
        await RoutingService.findPath(graph, startNode, endNode);

    setStateIfMounted(() {
      if (pathPoints != null && pathPoints.isNotEmpty) {
        currentManeuvers = RoutingService.analyzeRouteForTurns(pathPoints);
        routePolyline =
            Polyline(points: pathPoints, color: Colors.blue, strokeWidth: 5.0);
        _updateRouteMetrics(pathPoints);
        _updateCurrentManeuverOnGpsUpdate(
            currentGpsPosition ?? pathPoints.first);

        showSnackbar(
            "Route berechnet. Distanz: ${routeDistance!.toStringAsFixed(2)}m");
        isRouteActiveForCardSwitch = true;
        _toggleRouteOverview(zoomOut: true, delaySeconds: 0.5);
      } else {
        showSnackbar("Keine Route zwischen den Punkten gefunden.");
        _resetRouteAndNavigation();
      }
      isCalculatingRoute = false;
    });
  }

  GraphNode? _findNearestNode(LatLng point, RoutingGraph graph) {
    GraphNode? nearestNode;
    double minDistance = double.infinity;
    for (var node in graph.nodes.values) {
      final d = distanceCalculatorInstance.distance(point, node.position);
      if (d < minDistance) {
        minDistance = d;
        nearestNode = node;
      }
    }
    return nearestNode;
  }

  void _updateCurrentLocationMarker() {
    if (currentGpsPosition != null) {
      setStateIfMounted(() {
        currentLocationMarker = Marker(
          width: 80.0,
          height: 80.0,
          point: currentGpsPosition!,
          child: const Icon(Icons.my_location, color: Colors.blueAccent),
        );
      });
    }
  }

  void _updateStartMarker() {
    if (startLatLng != null &&
        startSearchController.text != "Aktueller Standort") {
      setStateIfMounted(() {
        startMarker = Marker(
          point: startLatLng!,
          width: 80,
          height: 80,
          child: const Icon(Icons.play_circle_fill, color: Colors.green),
        );
      });
    } else {
      setStateIfMounted(() {
        startMarker = null;
      });
    }
  }

  void _updateEndMarker() {
    if (endLatLng != null) {
      setStateIfMounted(() {
        endMarker = Marker(
          point: endLatLng!,
          width: 80,
          height: 80,
          child: const Icon(Icons.flag_circle, color: Colors.red),
        );
      });
    } else {
      setStateIfMounted(() {
        endMarker = null;
      });
    }
  }

  void _updateRouteMetrics(List<LatLng> path) {
    if (path.isEmpty) return;
    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance +=
          distanceCalculatorInstance.distance(path[i], path[i + 1]);
    }
    setStateIfMounted(() {
      routeDistance = totalDistance;
      routeTimeMinutes = (totalDistance / 80).ceil();
    });
  }

  void _updateCurrentManeuverOnGpsUpdate(LatLng currentPos) {
    if (currentManeuvers.isEmpty) return;

    int startIndex = 0;
    if (currentDisplayedManeuver != null) {
      startIndex = currentManeuvers.indexWhere((m) =>
          m.point.latitude == currentDisplayedManeuver!.point.latitude &&
          m.point.longitude == currentDisplayedManeuver!.point.longitude &&
          m.turnType == currentDisplayedManeuver!.turnType);
    }
    if (startIndex == -1) {
      startIndex = 0;
    }

    for (int i = startIndex; i < currentManeuvers.length; i++) {
      final Maneuver potentialNextManeuver = currentManeuvers[i];
      final LatLng maneuverPoint = potentialNextManeuver.point;

      final double distanceToManeuver =
          distanceCalculatorInstance.distance(currentPos, maneuverPoint);

      if (i < currentManeuvers.length - 1 &&
          distanceToManeuver < _maneuverReachedThreshold) {
        continue;
      } else {
        Maneuver nextManeuverToDisplay = potentialNextManeuver;

        bool isNewDisplay = currentDisplayedManeuver == null ||
            (nextManeuverToDisplay.point.latitude !=
                    currentDisplayedManeuver!.point.latitude ||
                nextManeuverToDisplay.point.longitude !=
                    currentDisplayedManeuver!.point.longitude ||
                nextManeuverToDisplay.turnType !=
                    currentDisplayedManeuver!.turnType);

        if (isNewDisplay) {
          ttsService.speak(nextManeuverToDisplay.instructionText ?? '');
          setStateIfMounted(() {
            currentDisplayedManeuver = nextManeuverToDisplay;
          });
        }
        break;
      }
    }
  }

  void _toggleRouteOverview({bool? zoomOut, double delaySeconds = 0.0}) {
    Future.delayed(Duration(milliseconds: (delaySeconds * 1000).toInt()), () {
      if (!mounted) return;
      if (routePolyline == null || routePolyline!.points.isEmpty) return;

      bool shouldZoomOut = zoomOut ?? !_isInRouteOverviewMode;

      if (shouldZoomOut) {
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(routePolyline!.points),
            padding: const EdgeInsets.all(50.0),
          ),
        );
        setStateIfMounted(() {
          _isInRouteOverviewMode = true;
          followGps = false;
        });
      } else {
        _centerOnGps();
        setStateIfMounted(() {
          _isInRouteOverviewMode = false;
        });
      }
    });
  }

  Future<void> calculateAndDisplayRoute() async {
    await _calculateRouteIfPossible();
  }

  void _performClearRoute(bool clearMarkers) {
    _resetRouteAndNavigation();
    if (clearMarkers) {
      startMarker = null;
      endMarker = null;
    }
    setStateIfMounted(() {});
  }

  void clearRoute({bool showConfirmation = false, bool clearMarkers = false}) {
    if (showConfirmation) {
      showConfirmationDialog(
          "Route löschen", "Möchten Sie die aktuelle Route wirklich löschen?",
          () {
        _performClearRoute(clearMarkers);
      });
    } else {
      _performClearRoute(clearMarkers);
    }
  }
}
