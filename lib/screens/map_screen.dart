// lib/screens/map_screen.dart - MODERNE GOOGLE MAPS STYLE VERSION
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Ensure this import is present for LatLng
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;
import 'package:latlong2/latlong.dart';

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
// import 'package:camping_osm_navi/models/searchable_feature.dart'; // REMOVED
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';

import 'map_screen_parts/map_screen_ui_mixin.dart';
// import 'map_screen_parts/horizontal_poi_strip.dart'; // REMOVED
import 'map_screen/map_screen_controller.dart';
import 'map_screen/map_screen_gps_handler.dart';
import 'map_screen/map_screen_route_handler.dart';
// import 'map_screen/map_screen_search_handler.dart'; // REMOVED

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen>
    with MapScreenUiMixin, WidgetsBindingObserver {
  late MapScreenController controller;
  late MapScreenGpsHandler gpsHandler;
  late MapScreenRouteHandler routeHandler;
  // late MapScreenSearchHandler searchHandler; // REMOVED

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    controller = MapScreenController();
    gpsHandler = MapScreenGpsHandler(controller);
    routeHandler = MapScreenRouteHandler(controller, context);
    // searchHandler = MapScreenSearchHandler(controller, context); // REMOVED

    // Setup callbacks between handlers
    gpsHandler.setOnGpsChangeCallback(routeHandler.updateNavigationOnGpsChange);
    // searchHandler
    //     .setRouteCalculationCallback(routeHandler.calculateRouteIfPossible); // REMOVED
    // searchHandler.setRouteClearCallback(() => routeHandler.clearRoute()); // REMOVED

    _initializeApp();
  }

  void _initializeApp() {
    final apiKey = dotenv.env['MAPTILER_API_KEY'];
    controller.initializeMaptilerUrl(apiKey);

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _updateSearchCardHeight();
    // });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 50;

        controller.updateKeyboardVisibility(isKeyboardVisible, keyboardHeight);

        // Smart auto-zoom only for active search // REMOVED Block
        // if (isKeyboardVisible &&
        //     controller.visibleSearchResults.isNotEmpty &&
        //     (controller.startFocusNode.hasFocus ||
        //         controller.endFocusNode.hasFocus)) {
        //   Future.delayed(const Duration(milliseconds: 300), () {
        //     if (mounted && controller.visibleSearchResults.isNotEmpty) {
        //       controller.autoZoomToPOIsWithKeyboard(context);
        //     }
        //   });
        // }
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
    WidgetsBinding.instance.removeObserver(this);
    gpsHandler.dispose();
    // searchHandler.dispose(); // REMOVED
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
        IconButton(
          icon: Icon(
            controller.showPOILabels ? Icons.search : Icons.search_off,
            color: controller.showPOILabels ? Colors.white : Colors.white70,
          ),
          tooltip: controller.showPOILabels
              ? 'Search-Navigation aktiv'
              : 'Search-Navigation inaktiv',
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
        // Map without any focus interference
        _buildMap(isUiReady, mapTheme, selectedLocation),

        // Modern Google Maps style search interface
        // if (!controller.compactSearchMode) _buildModernSearchCard(isUiReady), // REMOVED
        // if (controller.compactSearchMode) _buildCompactSearchBar(isUiReady), // REMOVED

        // Navigation instructions
        _buildInstructionCard(isUiReady),

        // Smart search results
        // if (!controller.isKeyboardVisible) _buildSearchResults(isUiReady), // REMOVED
        // if (controller.showHorizontalPOIStrip) _buildHorizontalPOIStrip(), // REMOVED

        // Loading states
        _buildLoadingOverlays(isUiReady, isLoading, selectedLocation),
      ],
    );
  }

  // REMOVED _buildModernSearchCard, _buildModernTextField, _buildRouteInfo
  // REMOVED _buildCompactSearchBar
  // REMOVED _buildHorizontalPOIStrip

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
        onTap: isUiReady
            ? (tapPosition, point) {
                // 'point' is LatLng
                _handleSmartMapTap(tapPosition, point);
              }
            : null,
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

  void _handleSmartMapTap(TapPosition tapPosition, LatLng point) {
    // LatLng type for point
    // Only handle route creation, never unfocus
    // routeHandler.handleMapTap(tapPosition, point); // REMOVED as handleMapTap was removed
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

  Widget _buildMarkerLayer() {
    final List<Marker> activeMarkers = [];

    if (controller.currentLocationMarker != null) {
      activeMarkers.add(controller.currentLocationMarker!);
    }
    if (controller.startMarker != null) { // This state is already removed from controller, but kept for safety, will be caught by analyzer if truly unused
      activeMarkers.add(controller.startMarker!);
    }
    if (controller.endMarker != null) { // This state is already removed from controller, but kept for safety, will be caught by analyzer if truly unused
      activeMarkers.add(controller.endMarker!);
    }

    // if (controller.visibleSearchResults.isNotEmpty && // REMOVED - visibleSearchResults and showHorizontalPOIStrip are removed from controller
    //     !controller.showHorizontalPOIStrip) {
    //   final currentZoom = controller.mapController.camera.zoom;
    //
    //   for (final feature in controller.visibleSearchResults) {
    //     activeMarkers.add(_createSearchResultMarker(feature, currentZoom));
    //   }
    // }

    return MarkerLayer(markers: activeMarkers);
  }

  // REMOVED _createSearchResultMarker and its helper methods:
  // _getMarkerWidthForFeature, _getMarkerHeightForFeature, _getIconSizeForZoom,
  // _shouldShowTextForZoom, _getFontSizeForZoom, _isAccommodationType,
  // _getBackgroundColorForPOIType, _getColorForPOIType, _showPOIActions

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

    final double instructionCardTop = 8 +
        (controller.compactSearchMode
            ? 60
            // : _calculateCurrentSearchCardHeight()) + // REMOVED
            : 200.0) + // Default height
        16;

    return Positioned(
      top: instructionCardTop,
      left: 16,
      right: 16,
      child: TurnInstructionCard(
        maneuver: controller.currentDisplayedManeuver!,
        maxWidth: MediaQuery.of(context).size.width - 32,
        distanceToManeuver: routeHandler.currentDistanceToManeuver,
      ),
    );
  }

  // REMOVED _calculateCurrentSearchCardHeight
  // REMOVED _buildSearchResults
  // REMOVED _buildSearchResultTile
  // REMOVED _getReadableFeatureType (as it was only used by _buildSearchResultTile)

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
        // Per diagnostic: Use .withValues()
        color: Colors.black.withValues(alpha: 0.3),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildReroutingOverlay() {
    return Positioned.fill(
      child: Container(
        // Per diagnostic: Use .withValues()
        color: Colors.black.withValues(alpha: 0.2),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 8),
              Text("Route wird neu berechnet...",
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(LocationInfo? selectedLocation) {
    return Positioned.fill(
      child: Container(
        // Per diagnostic: Use .withValues()
        color: Colors.black.withValues(alpha: 0.7),
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
      if (mounted) {
        // _updateSearchCardHeight(); // REMOVED
      }
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
    }
  }

  // Public methods für Handler
  // void setStartToCurrentLocation() { // REMOVED
  //   // searchHandler.setStartToCurrentLocation();
  // }

  // void calculateAndDisplayRoute() {
  //   // routeHandler.calculateRouteIfPossible(); // REMOVED
  // }

  void clearRoute({bool showConfirmation = false, bool clearMarkers = false}) {
    routeHandler.clearRoute(
        showConfirmation: showConfirmation, clearMarkers: clearMarkers);
  }

  // void swapStartAndEnd() { // REMOVED
  //   // searchHandler.swapStartAndEnd();
  // }
}
