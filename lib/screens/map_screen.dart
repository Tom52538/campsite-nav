// lib/screens/map_screen.dart - COMPLETE FILE
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;
import 'package:latlong2/latlong.dart';

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';
import 'package:camping_osm_navi/widgets/simple_search_container.dart';
// import 'package:camping_osm_navi/widgets/route_info_display.dart'; // Original, replaced by CompactRouteWidget logic
import 'package:camping_osm_navi/widgets/compact_route_widget.dart'; // ADDED IMPORT

import 'map_screen_parts/map_screen_ui_mixin.dart';
import 'map_screen/map_screen_controller.dart';
import 'map_screen/map_screen_gps_handler.dart';
import 'map_screen/map_screen_route_handler.dart';

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    controller = MapScreenController(locationProvider);
    gpsHandler = MapScreenGpsHandler(controller);
    routeHandler = MapScreenRouteHandler(controller, context);
    gpsHandler.setOnGpsChangeCallback(routeHandler.updateNavigationOnGpsChange);

    _initializeApp();
  }

  void _initializeApp() {
    final apiKey = dotenv.env['MAPTILER_API_KEY'];
    controller.initializeMaptilerUrl(apiKey);
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
              ? 'Search-Navigation active'
              : 'Search-Navigation inactive',
          onPressed: isUiReady
              ? () {
                  setState(() { // Ensure UI updates when toggling POI labels
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
          hint: const Text("Select location",
              style: TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }

  Widget _buildMockLocationToggle(bool isLoading) {
    return Tooltip(
      message: controller.useMockLocation
          ? "Activate real GPS"
          : "Activate mock position",
      child: IconButton(
        icon: Icon(controller.useMockLocation
            ? Icons.location_on
            : Icons.location_off),
        color: controller.useMockLocation ? Colors.orangeAccent : Colors.white,
        onPressed: !isLoading ? _toggleMockLocation : null,
      ),
    );
  }

  // ENHANCED: Body layout with intelligent UI positioning
  Widget _buildBody(bool isUiReady, dynamic mapTheme,
      LocationInfo? selectedLocation, bool isLoading) {
    final locationProvider = Provider.of<LocationProvider>(context);

    return Stack(
      children: [
        _buildMap(isUiReady, mapTheme, selectedLocation),
        _buildInstructionCard(isUiReady), // Positioned based on controller state
        _buildLoadingOverlays(isUiReady, isLoading, selectedLocation),

        // Top UI elements (Search or Compact Route Info)
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact route info (shown when route is active and fields should fade)
              if (controller.showRouteInfoAndFadeFields)
                _buildCompactRouteDisplayWidget(),

              // Full search fields (shown when not in compact mode)
              if (!controller.showRouteInfoAndFadeFields)
                SimpleSearchContainer(
                  controller: controller,
                  allFeatures: locationProvider.currentSearchableFeatures,
                  isStartLocked: controller.isStartLocked,
                  isDestinationLocked: controller.isDestinationLocked,
                  showRouteInfoAndFadeFields: controller.showRouteInfoAndFadeFields,
                ),
            ],
          ),
        ),

        // Route Progress Indicator (conditionally shown)
        if (controller.followGps &&
            controller.routePolyline != null &&
            controller.remainingRouteDistance != null &&
            controller.routeDistance != null &&
            controller.routeDistance! > 0) // Avoid division by zero
          Positioned(
            // Adjust top based on whether compact view is active
            top: controller.showRouteInfoAndFadeFields ? 80 : 10,
            left: 20,
            right: 20,
            child: RouteProgressIndicator(
              progress: (1.0 - (controller.remainingRouteDistance! / controller.routeDistance!))
                  .clamp(0.0, 1.0), // Ensure progress is between 0 and 1
              color: Colors.blue,
              height: 6.0,
            ),
          ),
      ],
    );
  }

  // NEW: CompactRouteWidget integration
  Widget _buildCompactRouteDisplayWidget() {
    // This widget is now directly part of _buildBody's logic
    // It's shown/hidden based on controller.showRouteInfoAndFadeFields
    return CompactRouteWidget(
      destinationName: controller.endSearchController.text,
      remainingDistance: controller.remainingRouteDistance,
      totalDistance: controller.routeDistance,
      remainingTime: controller.remainingRouteTimeMinutes,
      totalTime: controller.routeTimeMinutes,
      isNavigating: controller.followGps && controller.currentGpsPosition != null,
      onEditPressed: () {
        controller.showRouteInfoAndFadeFields = false; // Switch back to full search
        controller.notifyListeners();
      },
      onClosePressed: () {
        routeHandler.clearRoute(showConfirmation: true); // End navigation
      },
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
        onTap: isUiReady
            ? (tapPosition, point) => _handleSmartMapTap(tapPosition, point)
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
    if (controller.isMapSelectionActive) {
      controller.handleMapTapForSelection(point);
    }
    // Potentially other tap interactions if needed
  }

  Widget _buildMapLayer(bool isUiReady, dynamic mapTheme) {
    final bool vectorConditionsMet = isUiReady &&
        controller.maptilerUrlTemplate.isNotEmpty &&
        controller.maptilerUrlTemplate.contains('key=') &&
        mapTheme != null; // Ensure mapTheme is loaded

    if (vectorConditionsMet) {
      return vector_map_tiles.VectorTileLayer(
        theme: mapTheme,
        fileCacheTtl: const Duration(days: 7),
        tileProviders: vector_map_tiles.TileProviders({
          'openmaptiles': vector_map_tiles.NetworkVectorTileProvider(
            urlTemplate: controller.maptilerUrlTemplate,
            maximumZoom: 14, // Max zoom for vector tiles
          ),
        }),
        maximumZoom: 20, // Max zoom for map display
      );
    } else {
      // Fallback to raster tiles
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
    // Add other markers if necessary (e.g., start/end points, POIs)
    return MarkerLayer(markers: activeMarkers);
  }

  // ENHANCED: Instruction card positioning
  Widget _buildInstructionCard(bool isUiReady) {
    final bool instructionCardVisible = controller.currentDisplayedManeuver != null &&
        controller.currentDisplayedManeuver!.turnType != TurnType.depart &&
        !(controller.currentManeuvers.length <= 2 &&
            controller.currentDisplayedManeuver!.turnType == TurnType.arrive);

    if (!instructionCardVisible || !isUiReady || controller.isInRouteOverviewMode) {
      return const SizedBox.shrink();
    }

    // Position based on whether compact route info is shown
    final double instructionCardTop = controller.showRouteInfoAndFadeFields
        ? 90.0  // Below compact route info
        : 220.0; // Below full search inputs

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
        color: Colors.black.withOpacity(0.3), // Standardized opacity
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildReroutingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.2), // Standardized opacity
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 8),
              Text("Recalculating route...",
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
        color: Colors.black.withOpacity(0.7), // Standardized opacity
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                "Loading map data for ${selectedLocation?.name ?? '...'}...",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ENHANCED: Floating action buttons
  Widget _buildFloatingActionButtons(bool isUiReady) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Route Overview Toggle
        if (isUiReady && controller.routePolyline != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.small(
              heroTag: "toggleOverviewBtn",
              onPressed: routeHandler.toggleRouteOverview,
              tooltip: controller.isInRouteOverviewMode
                  ? "Back to navigation"
                  : "Show full route",
              backgroundColor: controller.isInRouteOverviewMode
                  ? Colors.blue
                  : Colors.white,
              foregroundColor: controller.isInRouteOverviewMode
                  ? Colors.white
                  : Colors.blue,
              child: Icon(
                controller.isInRouteOverviewMode
                    ? Icons.my_location // Or Icons.navigation if preferred
                    : Icons.zoom_out_map,
              ),
            ),
          ),

        // GPS Center Button
        if (isUiReady)
          FloatingActionButton(
            heroTag: "centerGpsBtn",
            onPressed: _centerOnGps,
            tooltip: controller.followGps
                ? 'GPS tracking active'
                : 'Center on GPS',
            backgroundColor: controller.followGps
                ? Colors.blue
                : Colors.white,
            foregroundColor: controller.followGps
                ? Colors.white
                : Colors.grey.shade700,
            child: Icon(
              controller.followGps ? Icons.navigation : Icons.near_me,
            ),
          ),

        // NEW: Route share button
        if (isUiReady && controller.routePolyline != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0), // Spacing from GPS button
            child: FloatingActionButton.small(
              heroTag: "shareRouteBtn",
              onPressed: _shareRoute,
              tooltip: "Share route",
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              child: const Icon(Icons.share),
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
        showSnackbar("Follow-GPS mode deactivated.", durationSeconds: 2);
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
      showSnackbar("No location selected, cannot switch mode.");
      return;
    }
    controller.toggleMockLocation(); // Toggles useMockLocation in controller
    gpsHandler.activateGps(selectedLocation); // Re-activates GPS with new mode
    showSnackbar(
        controller.useMockLocation
            ? "Mock-GPS activated and map centered."
            : "Real GPS activated and map centered.",
        durationSeconds: 3);
  }

  void _centerOnGps() {
    final selectedLocation =
        Provider.of<LocationProvider>(context, listen: false).selectedLocation;

    if (gpsHandler.canCenterOnGps(selectedLocation?.initialCenter)) {
      gpsHandler.centerOnGps(); // This also sets controller.followGps = true
      showSnackbar("Follow-GPS mode activated.", durationSeconds: 2);
    } else {
      if (controller.currentGpsPosition == null && selectedLocation != null) {
        showSnackbar(
            controller.useMockLocation
                ? "Mock GPS will be activated and map centered..."
                : "Real GPS will be activated, please wait...",
            durationSeconds: 3);
        gpsHandler.activateGps(selectedLocation); // Will attempt to center
      } else {
        showSnackbar(controller.currentGpsPosition == null
            ? "Current GPS position is unknown."
            : "You are too far from the campground to center.");
      }
    }
  }

  // NEW: Route sharing functionality
  void _shareRoute() {
    if (controller.routePolyline == null ||
        controller.endSearchController.text.isEmpty) {
      showSnackbar("No route available to share.");
      return;
    }

    final destination = controller.endSearchController.text;
    final distance = controller.routeDistance;
    final time = controller.routeTimeMinutes;

    String shareText = "Route to: $destination";
    if (distance != null && time != null) {
      shareText += "
Distance: ${controller.formatDistance(distance)}"; // Uses new helper
      shareText += "
Walking time: about $time minutes";
    }

    // Placeholder for actual sharing logic (e.g., using share_plus)
    if (kDebugMode) {
      print("SHARE_ROUTE_TEXT: $shareText");
    }
    showSnackbar("Route info prepared for sharing (see console for debug).", durationSeconds: 5);
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
              print("SNACKBAR_ERROR: $e, MESSAGE: $message");
            }
          }
        }
      });
    }
  }

  void clearRoute({bool showConfirmation = false}) {
    routeHandler.clearRoute(showConfirmation: showConfirmation);
  }
}
