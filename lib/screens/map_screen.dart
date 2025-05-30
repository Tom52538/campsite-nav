// lib/screens/map_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';

import 'map_screen_parts/map_screen_ui_mixin.dart';
import 'map_screen/map_screen_controller.dart';
import 'map_screen/map_screen_gps_handler.dart';
import 'map_screen/map_screen_route_handler.dart';
import 'map_screen/map_screen_search_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> with MapScreenUiMixin {
  late MapScreenController controller;
  late MapScreenGpsHandler gpsHandler;
  late MapScreenRouteHandler routeHandler;
  late MapScreenSearchHandler searchHandler;

  final GlobalKey fullSearchCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    controller = MapScreenController();
    gpsHandler = MapScreenGpsHandler(controller);
    routeHandler = MapScreenRouteHandler(controller, context);
    searchHandler = MapScreenSearchHandler(controller, context);

    // Setup callbacks between handlers
    gpsHandler.setOnGpsChangeCallback(routeHandler.updateNavigationOnGpsChange);
    searchHandler
        .setRouteCalculationCallback(routeHandler.calculateRouteIfPossible);
    searchHandler.setRouteClearCallback(() => routeHandler.clearRoute());

    _initializeApp();
  }

  void _initializeApp() {
    final apiKey = dotenv.env['MAPTILER_API_KEY'];
    controller.initializeMaptilerUrl(apiKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSearchCardHeight();
    });
  }

  void _updateSearchCardHeight() {
    if (fullSearchCardKey.currentContext != null) {
      final RenderBox? renderBox =
          fullSearchCardKey.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox != null && mounted) {
        controller.setFullSearchCardHeight(renderBox.size.height);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final newLocationInfo = locationProvider.selectedLocation;

    if (newLocationInfo != null &&
        (controller.lastProcessedLocation == null ||
            newLocationInfo.id != controller.lastProcessedLocation!.id)) {
      _handleLocationChange(newLocationInfo);
      controller.lastProcessedLocation = newLocationInfo;
    }
  }

  void _handleLocationChange(LocationInfo newLocation) {
    controller.resetRouteAndNavigation();
    controller.resetSearchFields();
    controller.performInitialMapMove(
        newLocation: newLocation, context: context);
    gpsHandler.initializeGpsOrMock(newLocation);
  }

  @override
  void dispose() {
    gpsHandler.dispose();
    searchHandler.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return _buildMapScreen();
      },
    );
  }

  Widget _buildMapScreen() {
    final locationProvider = Provider.of<LocationProvider>(context);
    final selectedLocationFromUI = locationProvider.selectedLocation;
    final availableLocationsFromUI = locationProvider.availableLocations;

    final isLoading = locationProvider.isLoadingLocationData;
    final mapThemeFromProvider = locationProvider.mapTheme;
    final isGraphReady = locationProvider.currentRoutingGraph != null;
    final isUiReady =
        !isLoading && isGraphReady && mapThemeFromProvider != null;

    return Scaffold(
      appBar: _buildAppBar(availableLocationsFromUI, selectedLocationFromUI,
          isLoading, isUiReady),
      body: _buildBody(
          isUiReady, mapThemeFromProvider, selectedLocationFromUI, isLoading),
      floatingActionButton: _buildFloatingActionButtons(isUiReady),
    );
  }

  AppBar _buildAppBar(List<LocationInfo> availableLocations,
      LocationInfo? selectedLocation, bool isLoading, bool isUiReady) {
    return AppBar(
      title: const Text("Campground Navigator"),
      actions: [
        IconButton(
          icon: const Icon(Icons.volume_up),
          tooltip: 'Test TTS',
          onPressed: isUiReady ? controller.ttsService.testSpeak : null,
        ),
        // ✅ NEU: POI Toggle
        IconButton(
          icon: Icon(
            controller.showPOILabels ? Icons.label : Icons.label_off,
            color: controller.showPOILabels ? Colors.white : Colors.white70,
          ),
          tooltip: 'POI-Labels ein/ausblenden',
          onPressed: isUiReady
              ? () {
                  setState(() {
                    controller.togglePOILabels();
                  });
                }
              : null,
        ),
        if (availableLocations.isNotEmpty && selectedLocation != null)
          _buildLocationDropdown(
              availableLocations, selectedLocation, isLoading),
        _buildMockLocationToggle(isLoading),
      ],
    );
  }

  Widget _buildLocationDropdown(
      List<LocationInfo> locations, LocationInfo selected, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LocationInfo>(
          value: selected,
          icon: const Icon(Icons.public, color: Colors.white),
          dropdownColor: Colors.deepOrange[700],
          style: const TextStyle(color: Colors.white),
          items: locations
              .map<DropdownMenuItem<LocationInfo>>(
                (LocationInfo location) => DropdownMenuItem<LocationInfo>(
                  value: location,
                  child: Text(
                    location.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: !isLoading ? _onLocationSelectedFromDropdown : null,
          hint: const Text("Standort wählen",
              style: TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }

  Widget _buildMockLocationToggle(bool isLoading) {
    return Tooltip(
      message: controller.useMockLocation
          ? "Echtes GPS aktivieren"
          : "Mock-Position aktivieren",
      child: IconButton(
        icon: Icon(controller.useMockLocation
            ? Icons.location_on
            : Icons.location_off),
        color: controller.useMockLocation ? Colors.orangeAccent : Colors.white,
        onPressed: !isLoading ? _toggleMockLocation : null,
      ),
    );
  }

  Widget _buildBody(bool isUiReady, dynamic mapTheme,
      LocationInfo? selectedLocation, bool isLoading) {
    return Stack(
      children: [
        _buildMap(isUiReady, mapTheme, selectedLocation),
        _buildSearchCard(isUiReady),
        _buildInstructionCard(isUiReady),
        _buildSearchResults(isUiReady),
        _buildLoadingOverlays(isUiReady, isLoading, selectedLocation),
      ],
    );
  }

  Widget _buildMap(
      bool isUiReady, dynamic mapTheme, LocationInfo? selectedLocation) {
    return FlutterMap(
      mapController: controller.mapController,
      options: MapOptions(
        initialCenter: selectedLocation?.initialCenter ??
            MapScreenController.fallbackInitialCenter,
        initialZoom: 17.0,
        minZoom: 13.0,
        maxZoom: 20.0,
        onTap: isUiReady ? routeHandler.handleMapTap : null,
        onMapEvent: _handleMapEvent,
        onMapReady: _onMapReady,
      ),
      children: [
        _buildMapLayer(isUiReady, mapTheme),
        if (isUiReady && controller.routePolyline != null)
          PolylineLayer(polylines: [controller.routePolyline!]),
        if (isUiReady) _buildMarkerLayer(),
      ],
    );
  }

  Widget _buildMapLayer(bool isUiReady, dynamic mapTheme) {
    final bool vectorConditionsMet = isUiReady &&
        controller.maptilerUrlTemplate.isNotEmpty &&
        controller.maptilerUrlTemplate.contains('key=');

    if (vectorConditionsMet) {
      return vector_map_tiles.VectorTileLayer(
        theme: mapTheme,
        fileCacheTtl: const Duration(days: 7),
        tileProviders: vector_map_tiles.TileProviders({
          'openmaptiles': vector_map_tiles.NetworkVectorTileProvider(
            urlTemplate: controller.maptilerUrlTemplate,
            maximumZoom: 14,
          ),
        }),
        maximumZoom: 20,
      );
    } else {
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.camping_osm_navi',
      );
    }
  }

  // ✅ Intelligente POI-Anzeige mit Zoom-Level und Kollisionserkennung
  Widget _buildMarkerLayer() {
    final List<Marker> activeMarkers = [];

    // Bestehende Marker (GPS, Start, Ziel)
    if (controller.currentLocationMarker != null) {
      activeMarkers.add(controller.currentLocationMarker!);
    }
    if (controller.startMarker != null) {
      activeMarkers.add(controller.startMarker!);
    }
    if (controller.endMarker != null) {
      activeMarkers.add(controller.endMarker!);
    }

    // ✅ Intelligente POI-Anzeige
    if (controller.showPOILabels) {
      final locationProvider = Provider.of<LocationProvider>(context);
      final allFeatures = locationProvider.currentSearchableFeatures;

      // Zoom-Level abhängige Filterung
      final currentZoom = controller.mapController.camera.zoom;
      final filteredFeatures =
          _filterPOIsByImportanceAndZoom(allFeatures, currentZoom);

      // Kollisionserkennung
      final nonOverlappingFeatures = _removeOverlappingPOIs(filteredFeatures);

      for (final feature in nonOverlappingFeatures) {
        activeMarkers.add(
          Marker(
            width: 100.0,
            height: 12.0,
            point: feature.center,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _showPOIActions(feature),
              child: Text(
                feature.name,
                style: TextStyle(
                  fontSize: _getFontSizeForZoom(currentZoom),
                  fontWeight: FontWeight.w500,
                  color: _getColorForPOIType(feature.type),
                  shadows: [
                    Shadow(
                      color: Colors.white,
                      blurRadius: 1.5,
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
    }

    return MarkerLayer(markers: activeMarkers);
  }

  // ✅ Zoom-abhängige Filterung
  List<SearchableFeature> _filterPOIsByImportanceAndZoom(
      List<SearchableFeature> features, double zoom) {
    if (zoom < 16.0) {
      // Nur wichtigste POIs bei niedrigem Zoom
      return features
          .where((f) =>
              f.type == 'bus_stop' ||
              (f.type == 'industrial' && f.name.isNotEmpty) ||
              f.type == 'parking')
          .toList();
    } else if (zoom < 18.0) {
      // Mittlere Wichtigkeit
      return features
          .where((f) => f.name.isNotEmpty && f.name.length > 3)
          .toList();
    } else {
      // Alle POIs bei hohem Zoom
      return features;
    }
  }

  // ✅ Kollisionserkennung
  List<SearchableFeature> _removeOverlappingPOIs(
      List<SearchableFeature> features) {
    final List<SearchableFeature> result = [];
    const double minDistanceMeters = 100.0; // ✅ Vergrößert: 100m statt 50m

    for (final feature in features) {
      bool tooClose = false;
      for (final existing in result) {
        final distance = MapScreenController.distanceCalculatorInstance
            .distance(feature.center, existing.center);
        if (distance < minDistanceMeters) {
          tooClose = true;
          break;
        }
      }
      if (!tooClose) {
        result.add(feature);
      }
    }
    return result;
  }

  // ✅ Zoom-abhängige Schriftgröße
  double _getFontSizeForZoom(double zoom) {
    if (zoom < 16.0) return 8.0;
    if (zoom < 18.0) return 9.0;
    return 10.0;
  }

  // ✅ NEU: POI-Aktionen beim Antippen
  void _showPOIActions(SearchableFeature feature) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  getIconForFeatureType(feature.type),
                  color: _getColorForPOIType(feature.type),
                ),
                title: Text(feature.name),
                subtitle: Text('Typ: ${feature.type}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.green),
                title: const Text('Als Startpunkt verwenden'),
                onTap: () {
                  Navigator.pop(context);
                  controller.startSearchController.text = feature.name;
                  controller.setStartLatLng(feature.center);
                  controller.updateStartMarker();
                  routeHandler.calculateRouteIfPossible();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.red),
                title: const Text('Als Ziel verwenden'),
                onTap: () {
                  Navigator.pop(context);
                  controller.endSearchController.text = feature.name;
                  controller.setEndLatLng(feature.center);
                  controller.updateEndMarker();
                  routeHandler.calculateRouteIfPossible();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.center_focus_strong, color: Colors.blue),
                title: const Text('Karte zentrieren'),
                onTap: () {
                  Navigator.pop(context);
                  controller.mapController.move(feature.center, 18.0);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ NEU: Farbzuordnung für POI-Typen
  Color _getColorForPOIType(String type) {
    switch (type.toLowerCase()) {
      case 'industrial':
        return Colors.deepPurple;
      case 'bus_stop':
        return Colors.blue;
      case 'parking':
        return Colors.indigo;
      case 'building':
        return Colors.brown;
      case 'shop':
        return Colors.purple;
      case 'amenity':
        return Colors.green;
      case 'tourism':
        return Colors.orange;
      case 'restaurant':
      case 'cafe':
        return Colors.red;
      case 'reception':
      case 'information':
        return Colors.teal;
      case 'toilets':
      case 'sanitary':
        return Colors.cyan;
      case 'playground':
        return Colors.pink;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildSearchCard(bool isUiReady) {
    return Positioned(
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
          child: controller.isRouteActiveForCardSwitch && isUiReady
              ? _buildCompactCard()
              : _buildFullSearchCard(),
        ),
      ),
    );
  }

  double _calculateDefaultCardHeight() {
    return (kSearchInputRowHeight * 2) +
        kDividerAndSwapButtonHeight +
        (kCardInternalVerticalPadding * 2) +
        (controller.routeDistance != null ? kRouteInfoHeight : 0);
  }

  Widget _buildCompactCard() {
    return buildCompactRouteInfoCard(
      key: const ValueKey('compactCard'),
      remainingRouteDistance: controller.remainingRouteDistance,
      routeDistance: controller.routeDistance,
      remainingRouteTimeMinutes: controller.remainingRouteTimeMinutes,
      routeTimeMinutes: controller.routeTimeMinutes,
      routePolyline: controller.routePolyline,
      endSearchController: controller.endSearchController,
      setStateIfMounted: (fn) => setState(fn),
      isRouteActiveForCardSwitch: controller.isRouteActiveForCardSwitch,
      clearRoute: routeHandler.clearRoute,
    );
  }

  Widget _buildFullSearchCard() {
    return buildSearchInputCard(
      key: const ValueKey('searchInputCard'),
      fullSearchCardKey: fullSearchCardKey,
      fullSearchCardHeight: controller.fullSearchCardHeight,
      setStateIfMounted: (fn) => setState(fn),
      startSearchController: controller.startSearchController,
      startFocusNode: controller.startFocusNode,
      startLatLng: controller.startLatLng,
      startMarker: controller.startMarker,
      routePolyline: controller.routePolyline,
      routeDistance: controller.routeDistance,
      routeTimeMinutes: controller.routeTimeMinutes,
      remainingRouteDistance: controller.remainingRouteDistance,
      remainingRouteTimeMinutes: controller.remainingRouteTimeMinutes,
      currentManeuvers: controller.currentManeuvers,
      currentDisplayedManeuver: controller.currentDisplayedManeuver,
      followGps: controller.followGps,
      isRouteActiveForCardSwitch: controller.isRouteActiveForCardSwitch,
      currentGpsPosition: controller.currentGpsPosition,
      useMockLocation: controller.useMockLocation,
      endSearchController: controller.endSearchController,
      endFocusNode: controller.endFocusNode,
      endLatLng: controller.endLatLng,
      endMarker: controller.endMarker,
      swapStartAndEnd: searchHandler.swapStartAndEnd,
      calculateAndDisplayRoute: routeHandler.calculateRouteIfPossible,
      clearRoute: routeHandler.clearRoute,
      showSnackbar: showSnackbar,
    );
  }

  Widget _buildInstructionCard(bool isUiReady) {
    final bool instructionCardVisible = controller.currentDisplayedManeuver !=
            null &&
        controller.currentDisplayedManeuver!.turnType != TurnType.depart &&
        !(controller.currentManeuvers.length <= 2 &&
            controller.currentDisplayedManeuver!.turnType == TurnType.arrive);

    if (!instructionCardVisible ||
        !isUiReady ||
        controller.isInRouteOverviewMode) {
      return const SizedBox.shrink();
    }

    final double instructionCardTop = kSearchCardTopPadding +
        _calculateCurrentSearchCardHeight() +
        kInstructionCardSpacing;

    return Positioned(
      top: instructionCardTop,
      left: kSearchCardHorizontalMargin,
      right: kSearchCardHorizontalMargin,
      child: Center(
        child: TurnInstructionCard(
          maneuver: controller.currentDisplayedManeuver!,
          maxWidth: kSearchCardMaxWidth + 50,
          distanceToManeuver: routeHandler.currentDistanceToManeuver,
        ),
      ),
    );
  }

  double _calculateCurrentSearchCardHeight() {
    return controller.isRouteActiveForCardSwitch
        ? kCompactCardHeight
        : controller.fullSearchCardHeight > 0
            ? controller.fullSearchCardHeight
            : _calculateDefaultCardHeight();
  }

  Widget _buildSearchResults(bool isUiReady) {
    if (!controller.showSearchResults ||
        controller.searchResults.isEmpty ||
        !isUiReady ||
        controller.isRouteActiveForCardSwitch) {
      return const SizedBox.shrink();
    }

    double searchResultsTopPosition = kSearchCardTopPadding +
        _calculateCurrentSearchCardHeight() +
        kInstructionCardSpacing;

    final bool instructionCardVisible = controller.currentDisplayedManeuver !=
            null &&
        controller.currentDisplayedManeuver!.turnType != TurnType.depart &&
        !(controller.currentManeuvers.length <= 2 &&
            controller.currentDisplayedManeuver!.turnType == TurnType.arrive);

    if (instructionCardVisible) {
      searchResultsTopPosition += 65.0 + kInstructionCardSpacing;
    }

    return Positioned(
      top: searchResultsTopPosition,
      left: kSearchCardHorizontalMargin,
      right: kSearchCardHorizontalMargin,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: kSearchCardMaxWidth),
          child: Card(
            elevation: 4.0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: controller.searchResults.length,
                itemBuilder: (context, index) {
                  final feature = controller.searchResults[index];
                  return ListTile(
                    leading: Icon(getIconForFeatureType(feature.type)),
                    title: Text(feature.name),
                    subtitle: Text("Typ: ${feature.type}"),
                    onTap: () =>
                        searchHandler.selectFeatureAndSetPoint(feature),
                    dense: true,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlays(
      bool isUiReady, bool isLoading, LocationInfo? selectedLocation) {
    return Stack(
      children: [
        if (controller.isCalculatingRoute && isUiReady)
          _buildCalculatingOverlay(),
        if (controller.isRerouting && isUiReady) _buildReroutingOverlay(),
        if (isLoading) _buildLoadingOverlay(selectedLocation),
      ],
    );
  }

  Widget _buildCalculatingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(70),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildReroutingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(50),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 8),
              Text(
                "Route wird neu berechnet...",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(LocationInfo? selectedLocation) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(180),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                "Lade Kartendaten für ${selectedLocation?.name ?? '...'}...",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons(bool isUiReady) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isUiReady && controller.routePolyline != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.small(
              heroTag: "toggleOverviewBtn",
              onPressed: routeHandler.toggleRouteOverview,
              tooltip: "Ganze Route anzeigen",
              child: Icon(
                controller.isInRouteOverviewMode
                    ? Icons.my_location
                    : Icons.zoom_out_map,
              ),
            ),
          ),
        if (isUiReady)
          FloatingActionButton(
            heroTag: "centerGpsBtn",
            onPressed: _centerOnGps,
            tooltip: 'Auf GPS zentrieren',
            child: Icon(
              controller.followGps ? Icons.navigation : Icons.near_me,
              color: controller.followGps ? Colors.blue : Colors.black,
            ),
          ),
      ],
    );
  }

  // Event Handlers
  void _handleMapEvent(MapEvent mapEvent) {
    if (mapEvent is MapEventMove &&
        (mapEvent.source == MapEventSource.dragStart ||
            mapEvent.source == MapEventSource.flingAnimationController)) {
      if (controller.followGps) {
        controller.setFollowGps(false);
        showSnackbar("Follow-GPS Modus deaktiviert.", durationSeconds: 2);
      }
    }

    if (mapEvent is MapEventMove &&
        (mapEvent.source == MapEventSource.dragStart ||
            mapEvent.source == MapEventSource.flingAnimationController) &&
        (controller.startFocusNode.hasFocus ||
            controller.endFocusNode.hasFocus)) {
      controller.unfocusSearchFieldsAndCollapse();
    }
  }

  void _onMapReady() {
    if (!mounted) return;
    controller.setMapReady();

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.selectedLocation != null &&
        controller.currentGpsPosition == null) {
      gpsHandler.initializeGpsOrMock(locationProvider.selectedLocation!);
    } else {
      controller.performInitialMapMove(context: context);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateSearchCardHeight();
    });
  }

  void _onLocationSelectedFromDropdown(LocationInfo? newLocation) {
    if (newLocation != null) {
      Provider.of<LocationProvider>(context, listen: false)
          .selectLocation(newLocation);
    }
  }

  void _toggleMockLocation() {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final selectedLocation = locationProvider.selectedLocation;
    if (selectedLocation == null) {
      showSnackbar("Kein Standort ausgewählt, kann Modus nicht wechseln.");
      return;
    }

    gpsHandler.toggleMockLocation(selectedLocation);
  }

  void _centerOnGps() {
    final selectedLocation =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;

    if (gpsHandler.canCenterOnGps(selectedLocation?.initialCenter)) {
      gpsHandler.centerOnGps();
      showSnackbar("Follow-GPS Modus aktiviert.", durationSeconds: 2);
    } else {
      if (controller.currentGpsPosition == null) {
        showSnackbar("Aktuelle GPS-Position ist unbekannt.");
      } else {
        showSnackbar(
            "Du bist zu weit vom Campingplatz entfernt, um zu zentrieren.");
      }
    }
  }

  @override
  void showSnackbar(String message, {int durationSeconds = 3}) {
    if (mounted && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          try {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                duration: Duration(seconds: durationSeconds),
              ),
            );
          } catch (e) {
            if (kDebugMode) {
              print("SNACKBAR: $message");
            }
          }
        }
      });
    } else {
      if (kDebugMode) {
        print("SNACKBAR (no context): $message");
      }
    }
  }

  // Public methods for UI Mixin compatibility
  void setStartToCurrentLocation() {
    searchHandler.setStartToCurrentLocation();
  }

  void calculateAndDisplayRoute() {
    routeHandler.calculateRouteIfPossible();
  }

  void clearRoute({bool showConfirmation = false, bool clearMarkers = false}) {
    routeHandler.clearRoute(
        showConfirmation: showConfirmation, clearMarkers: clearMarkers);
  }

  void swapStartAndEnd() {
    searchHandler.swapStartAndEnd();
  }
}
