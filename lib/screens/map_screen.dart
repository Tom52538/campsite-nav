// lib/screens/map_screen.dart - ALLE FEHLER BEHOBEN
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;
import 'package:latlong2/latlong.dart';

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';
import 'package:camping_osm_navi/widgets/smartphone_search_system.dart';

import 'map_screen_parts/map_screen_ui_mixin.dart';
import 'map_screen/map_screen_controller.dart';
import 'map_screen/map_screen_gps_handler.dart';
import 'map_screen/map_screen_route_handler.dart';

class PremiumCurves {
  static const Curve smooth = Curves.easeInOut;
}

class RouteProgressIndicator extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;

  const RouteProgressIndicator({
    super.key,
    required this.progress,
    required this.color,
    this.height = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: color.withValues(alpha: 0.3),
      valueColor: AlwaysStoppedAnimation<Color>(color),
      minHeight: height,
    );
  }
}

// ✅ FIX: KORRIGIERTE ColorValues Extension mit expliziter int-Konvertierung
extension ColorValues on Color {
  Color withValues({double? alpha, int? r, int? g, int? b}) {
    return Color.fromARGB(
        alpha != null
            ? (alpha * 255).round().toInt() // ✅ KORREKT: .toInt() explizit
            : this.a.toInt(), // ✅ FIX: this.a.toInt() statt nur a
        (r ?? this.r).toInt(), // ✅ FIX: Explizite int-Konvertierung
        (g ?? this.g).toInt(), // ✅ FIX: Explizite int-Konvertierung
        (b ?? this.b).toInt() // ✅ FIX: Explizite int-Konvertierung
        );
  }
}

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

  SearchContext _currentSearchContext = SearchContext.guest;

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
    _detectInitialContext();
  }

  void _initializeApp() {
    final apiKey = dotenv.env['MAPTILER_API_KEY'];
    controller.initializeMaptilerUrl(apiKey);
  }

  void _detectInitialContext() {
    final now = DateTime.now();
    if (now.hour >= 15 && now.hour <= 18) {
      _currentSearchContext = SearchContext.arrival;
    } else if (now.hour >= 8 && now.hour <= 11) {
      _currentSearchContext = SearchContext.departure;
    } else {
      _currentSearchContext = SearchContext.guest;
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _currentSearchContext != SearchContext.guest) {
        setState(() {
          _currentSearchContext = SearchContext.guest;
        });
      }
    });
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
      floatingActionButton: isUiReady
          ? ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 240.0,
              ),
              child: SingleChildScrollView(
                child: _buildFloatingActionButtons(true),
              ),
            )
          : null,
    );
  }

  AppBar _buildAppBar(List<LocationInfo> availableLocations,
      LocationInfo? selectedLocation, bool isLoading, bool isUiReady) {
    return AppBar(
      title: const Text("Campground Navigator"),
      actions: [
        if (kDebugMode)
          PopupMenuButton<SearchContext>(
            icon: Icon(_getContextIcon(_currentSearchContext), size: 18),
            onSelected: (context) {
              setState(() {
                _currentSearchContext = context;
              });
            },
            itemBuilder: (context) => SearchContext.values.map((context) {
              return PopupMenuItem(
                value: context,
                child: Row(
                  children: [
                    Icon(_getContextIcon(context), size: 16),
                    const SizedBox(width: 6),
                    Text(context.value, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        IconButton(
          icon: const Icon(Icons.volume_up, size: 20),
          tooltip: 'Test TTS',
          onPressed: isUiReady ? controller.ttsService.testSpeak : null,
        ),
        IconButton(
          icon: Icon(
            controller.showPOILabels ? Icons.search : Icons.search_off,
            color: controller.showPOILabels ? Colors.white : Colors.white70,
            size: 20,
          ),
          tooltip:
              controller.showPOILabels ? 'Search active' : 'Search inactive',
          onPressed: isUiReady
              ? () {
                  setState(() {
                    controller.togglePOILabels();
                  });
                }
              : null,
        ),
        if (availableLocations.isNotEmpty && selectedLocation != null)
          _buildCompactLocationDropdown(
              availableLocations, selectedLocation, isLoading),
        _buildCompactMockLocationToggle(isLoading),
      ],
    );
  }

  Widget _buildCompactLocationDropdown(
      List<LocationInfo> locations, LocationInfo selected, bool isLoading) {
    return PopupMenuButton<LocationInfo>(
      onSelected: _onLocationSelectedFromDropdown,
      enabled: !isLoading,
      itemBuilder: (context) => locations
          .map<PopupMenuItem<LocationInfo>>(
            (LocationInfo location) => PopupMenuItem<LocationInfo>(
              value: location,
              child: Text(
                _shortenLocationName(location.name),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList(),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _shortenLocationName(selected.name),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMockLocationToggle(bool isLoading) {
    return Tooltip(
      message: controller.useMockLocation ? "Real GPS" : "Mock GPS",
      child: IconButton(
        icon: Icon(
          controller.useMockLocation ? Icons.location_on : Icons.location_off,
          size: 20,
        ),
        color: controller.useMockLocation ? Colors.orangeAccent : Colors.white,
        onPressed: !isLoading ? _toggleMockLocation : null,
      ),
    );
  }

  String _shortenLocationName(String name) {
    final abbreviations = {
      'Roompot Beach Resort Kamperland': 'Kamperland',
      'Testgelände Sittard': 'Sittard',
      'Umgebung Zuhause (Gangelt)': 'Gangelt',
    };
    if (abbreviations.containsKey(name)) {
      return abbreviations[name]!;
    }
    return name.length > 8 ? '${name.substring(0, 8)}...' : name;
  }

  IconData _getContextIcon(SearchContext context) {
    switch (context) {
      case SearchContext.arrival:
        return Icons.celebration;
      case SearchContext.departure:
        return Icons.flight_takeoff;
      case SearchContext.emergency:
        return Icons.emergency;
      case SearchContext.guest:
        return Icons.explore;
    }
  }

  Widget _buildBody(bool isUiReady, dynamic mapTheme,
      LocationInfo? selectedLocation, bool isLoading) {
    final locationProvider = Provider.of<LocationProvider>(context);

    return Stack(
      children: [
        _buildMap(isUiReady, mapTheme, selectedLocation),
        _buildInstructionCard(isUiReady),
        _buildLoadingOverlays(isUiReady, isLoading, selectedLocation),
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: _buildModernSearchInterface(locationProvider),
        ),
        if (controller.followGps &&
            controller.routePolyline != null &&
            controller.remainingRouteDistance != null &&
            controller.routeDistance != null &&
            controller.routeDistance! > 0)
          _buildRouteProgressIndicator(),
      ],
    );
  }

  Widget _buildModernSearchInterface(LocationProvider locationProvider) {
    final interfaceState = controller.searchInterfaceState;
    return AnimatedContainer(
      duration: interfaceState.transitionDuration,
      curve: PremiumCurves.smooth,
      child: SmartphoneSearchSystem(
        controller: controller,
        allFeatures: locationProvider.currentSearchableFeatures,
        isStartLocked: controller.isStartLocked,
        isDestinationLocked: controller.isDestinationLocked,
        showRouteInfoAndFadeFields: controller.showRouteInfoAndFadeFields,
        context: _currentSearchContext,
        enableSmartTransitions: true,
        enableHapticFeedback: true,
        autoHideDelay: _getAutoHideDelayForContext(_currentSearchContext),
      ),
    );
  }

  Duration _getAutoHideDelayForContext(SearchContext context) {
    switch (context) {
      case SearchContext.emergency:
        return const Duration(milliseconds: 500);
      case SearchContext.arrival:
        return const Duration(milliseconds: 2500);
      case SearchContext.departure:
        return const Duration(milliseconds: 1200);
      case SearchContext.guest:
        return const Duration(milliseconds: 1500);
    }
  }

  Widget _buildRouteProgressIndicator() {
    final progress = controller.routeDistance! > 0
        ? (1.0 -
                (controller.remainingRouteDistance! /
                    controller.routeDistance!))
            .clamp(0.0, 1.0)
        : 0.0;
    final topOffset = _getProgressIndicatorTopOffset();
    return Positioned(
      top: topOffset,
      left: 20,
      right: 20,
      child: RouteProgressIndicator(
        progress: progress,
        color: _getProgressColorForContext(_currentSearchContext),
        height: 6.0,
      ),
    );
  }

  double _getProgressIndicatorTopOffset() {
    switch (controller.searchInterfaceState) {
      case SearchInterfaceState.navigationMode:
        return 80;
      case SearchInterfaceState.expanded:
        return 200;
      case SearchInterfaceState.collapsed:
        return 120;
      case SearchInterfaceState.hidden:
        return 20;
    }
  }

  Color _getProgressColorForContext(SearchContext context) {
    switch (context) {
      case SearchContext.emergency:
        return Colors.red;
      case SearchContext.arrival:
        return Colors.green;
      case SearchContext.departure:
        return Colors.orange;
      case SearchContext.guest:
        return Colors.blue;
    }
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
  }

  Widget _buildMapLayer(bool isUiReady, dynamic mapTheme) {
    final bool vectorConditionsMet = isUiReady &&
        controller.maptilerUrlTemplate.isNotEmpty &&
        controller.maptilerUrlTemplate.contains('key=') &&
        mapTheme != null;

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
    if (controller.startMarker != null) {
      activeMarkers.add(controller.startMarker!);
    }
    if (controller.destinationMarker != null) {
      activeMarkers.add(controller.destinationMarker!);
    }
    return MarkerLayer(markers: activeMarkers);
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
    final double instructionCardTop = _getInstructionCardTopOffset();
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

  double _getInstructionCardTopOffset() {
    switch (controller.searchInterfaceState) {
      case SearchInterfaceState.navigationMode:
        return 95.0;
      case SearchInterfaceState.expanded:
        return 240.0;
      case SearchInterfaceState.collapsed:
        return 140.0;
      case SearchInterfaceState.hidden:
        return 80.0;
    }
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
        color: Colors.black.withValues(alpha: 0.2),
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
        color: Colors.black.withValues(alpha: 0.7),
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
              tooltip: controller.isInRouteOverviewMode
                  ? "Back to navigation"
                  : "Show full route",
              backgroundColor:
                  controller.isInRouteOverviewMode ? Colors.blue : Colors.white,
              foregroundColor:
                  controller.isInRouteOverviewMode ? Colors.white : Colors.blue,
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
            tooltip:
                controller.followGps ? 'GPS tracking active' : 'Center on GPS',
            backgroundColor: controller.followGps
                ? _getProgressColorForContext(_currentSearchContext)
                : Colors.white,
            foregroundColor:
                controller.followGps ? Colors.white : Colors.grey.shade700,
            child: Icon(
              controller.followGps ? Icons.navigation : Icons.near_me,
            ),
          ),
        if (isUiReady && controller.routePolyline != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: FloatingActionButton.small(
              heroTag: "shareRouteBtn",
              onPressed: _shareRoute,
              tooltip: "Share route",
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              child: const Icon(Icons.share),
            ),
          ),
        if (kDebugMode && isUiReady)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: FloatingActionButton.small(
              heroTag: "contextSwitchBtn",
              onPressed: _cycleSearchContext,
              tooltip: "Switch context: ${_currentSearchContext.value}",
              backgroundColor:
                  _getProgressColorForContext(_currentSearchContext),
              foregroundColor: Colors.white,
              child: Icon(_getContextIcon(_currentSearchContext)),
            ),
          ),
      ],
    );
  }

  void _cycleSearchContext() {
    const contexts = SearchContext.values;
    final currentIndex = contexts.indexOf(_currentSearchContext);
    final nextIndex = (currentIndex + 1) % contexts.length;
    setState(() {
      _currentSearchContext = contexts[nextIndex];
    });
    showSnackbar("Context: ${_currentSearchContext.value}", durationSeconds: 2);
  }

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
    controller.toggleMockLocation();
    gpsHandler.activateGps(selectedLocation);
    showSnackbar(
        controller.useMockLocation
            ? "Mock-GPS activated and map centered."
            : "Real GPS activated and map centered.",
        durationSeconds: 3);
  }

  void _centerOnGps() {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final selectedLocation = locationProvider.selectedLocation;

    if (gpsHandler.canCenterOnGps(selectedLocation?.initialCenter)) {
      gpsHandler.centerOnGps();
      showSnackbar("Follow-GPS mode activated.", durationSeconds: 2);
    } else {
      if (controller.currentGpsPosition == null && selectedLocation != null) {
        showSnackbar(
            controller.useMockLocation
                ? "Mock GPS will be activated and map centered..."
                : "Real GPS will be activated, please wait...",
            durationSeconds: 3);
        gpsHandler.activateGps(selectedLocation);
      } else {
        showSnackbar(controller.currentGpsPosition == null
            ? "Current GPS position is unknown."
            : "You are too far from the campground to center.");
      }
    }
  }

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
      shareText += "\nDistance: ${controller.formatDistance(distance)}";
      shareText += "\nWalking time: about $time minutes";
    }
    if (kDebugMode) {
      print("SHARE_ROUTE_TEXT: $shareText");
    }
    showSnackbar("Route info prepared for sharing (see console for debug).",
        durationSeconds: 5);
  }

  void showSnackbar(String message, {int durationSeconds = 3}) {
    if (mounted && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          try {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                duration: Duration(seconds: durationSeconds),
                backgroundColor:
                    _getProgressColorForContext(_currentSearchContext),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
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
