// lib/screens/map_screen.dart - MODERNE GOOGLE MAPS STYLE VERSION
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
import 'map_screen_parts/horizontal_poi_strip.dart';
import 'map_screen/map_screen_controller.dart';
import 'map_screen/map_screen_gps_handler.dart';
import 'map_screen/map_screen_route_handler.dart';
import 'map_screen/map_screen_search_handler.dart';

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
  late MapScreenSearchHandler searchHandler;

  final GlobalKey fullSearchCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

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

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 50;

        controller.updateKeyboardVisibility(isKeyboardVisible, keyboardHeight);

        // Smart auto-zoom only for active search
        if (isKeyboardVisible &&
            controller.visibleSearchResults.isNotEmpty &&
            (controller.startFocusNode.hasFocus ||
                controller.endFocusNode.hasFocus)) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && controller.visibleSearchResults.isNotEmpty) {
              controller.autoZoomToPOIsWithKeyboard(context);
            }
          });
        }
      }
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
    WidgetsBinding.instance.removeObserver(this);
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
        if (!controller.compactSearchMode) _buildModernSearchCard(isUiReady),
        if (controller.compactSearchMode) _buildCompactSearchBar(isUiReady),

        // Navigation instructions
        _buildInstructionCard(isUiReady),

        // Smart search results
        if (!controller.isKeyboardVisible) _buildSearchResults(isUiReady),
        if (controller.showHorizontalPOIStrip) _buildHorizontalPOIStrip(),

        // Loading states
        _buildLoadingOverlays(isUiReady, isLoading, selectedLocation),
      ],
    );
  }

  // ✅ MODERN GOOGLE MAPS STYLE SEARCH CARD
  Widget _buildModernSearchCard(bool isUiReady) {
    if (!isUiReady) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Start field
              _buildModernTextField(
                controller: controller.startSearchController,
                focusNode: controller.startFocusNode,
                icon: Icons.trip_origin,
                iconColor: Colors.green,
                hint: "Von wo startest du?",
                isStart: true,
              ),

              // Elegant separator with swap button
              Container(
                height: 40,
                child: Stack(
                  children: [
                    // Line
                    Positioned(
                      left: 24,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.red],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Swap button
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.swap_vert, size: 18),
                          onPressed: () => searchHandler.swapStartAndEnd(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Destination field
              _buildModernTextField(
                controller: controller.endSearchController,
                focusNode: controller.endFocusNode,
                icon: Icons.flag,
                iconColor: Colors.red,
                hint: "Wohin möchtest du?",
                isStart: false,
              ),

              // Route info if available
              if (controller.routeDistance != null) _buildRouteInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required Color iconColor,
    required String hint,
    required bool isStart,
  }) {
    final bool hasFocus = focusNode.hasFocus;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasFocus ? iconColor : Colors.grey.shade300,
          width: hasFocus ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color:
            hasFocus ? iconColor.withValues(alpha: 0.05) : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: hasFocus
                  ? iconColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Icon(
              icon,
              color: hasFocus ? iconColor : Colors.grey.shade600,
              size: 20,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 16),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                controller.clear();
                if (isStart) {
                  this.controller.setStartLatLng(null);
                  this.controller.startMarker = null;
                } else {
                  this.controller.setEndLatLng(null);
                  this.controller.endMarker = null;
                }
                routeHandler.clearRoute();
              },
            ),
          if (isStart)
            IconButton(
              icon: Icon(Icons.my_location, color: iconColor, size: 20),
              onPressed: () => searchHandler.setStartToCurrentLocation(),
              tooltip: "Aktueller Standort",
            ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    final distance =
        controller.remainingRouteDistance ?? controller.routeDistance;
    final time =
        controller.remainingRouteTimeMinutes ?? controller.routeTimeMinutes;

    if (distance == null || time == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.green.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_walk, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            "${time}min • ${formatDistance(distance)}",
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey.shade600, size: 18),
            onPressed: () => routeHandler.clearRoute(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSearchBar(bool isUiReady) {
    if (!isUiReady) return const SizedBox.shrink();

    final activeController =
        this.controller.activeSearchField == ActiveSearchField.start
            ? this.controller.startSearchController
            : this.controller.endSearchController;

    final activeFocusNode =
        this.controller.activeSearchField == ActiveSearchField.start
            ? this.controller.startFocusNode
            : this.controller.endFocusNode;

    final hintText =
        this.controller.activeSearchField == ActiveSearchField.start
            ? "Startpunkt eingeben..."
            : "Ziel eingeben...";

    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                this.controller.activeSearchField == ActiveSearchField.start
                    ? Icons.trip_origin
                    : Icons.flag,
                color: Colors.deepOrange,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: activeController,
                  focusNode: activeFocusNode,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (activeController.text.isNotEmpty)
                IconButton(
                  icon:
                      Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
                  onPressed: () {
                    activeController.clear();
                    routeHandler.clearRoute();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalPOIStrip() {
    return HorizontalPOIStrip(
      features: controller.visibleSearchResults,
      keyboardHeight: controller.keyboardHeight,
      isVisible: controller.showHorizontalPOIStrip,
      onFeatureTap: (feature) {
        if (controller.activeSearchField == ActiveSearchField.start) {
          controller.startSearchController.text = feature.name;
          controller.setStartLatLng(feature.center);
          controller.updateStartMarker();
        } else {
          controller.endSearchController.text = feature.name;
          controller.setEndLatLng(feature.center);
          controller.updateEndMarker();
        }

        // Keep keyboard open for further editing
        Future.delayed(const Duration(milliseconds: 200), () {
          routeHandler.calculateRouteIfPossible();
          controller.mapController.move(feature.center, 18.0);
        });
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
            ? (tapPosition, point) {
                // Smart tap handling - only unfocus when tapping empty map areas
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
    // Only handle route creation, never unfocus
    routeHandler.handleMapTap(tapPosition, point);
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
    if (controller.startMarker != null) {
      activeMarkers.add(controller.startMarker!);
    }
    if (controller.endMarker != null) {
      activeMarkers.add(controller.endMarker!);
    }

    if (controller.visibleSearchResults.isNotEmpty &&
        !controller.showHorizontalPOIStrip) {
      final currentZoom = controller.mapController.camera.zoom;

      for (final feature in controller.visibleSearchResults) {
        activeMarkers.add(_createSearchResultMarker(feature, currentZoom));
      }
    }

    return MarkerLayer(markers: activeMarkers);
  }

  Marker _createSearchResultMarker(
      SearchableFeature feature, double currentZoom) {
    return Marker(
      width: _getMarkerWidthForFeature(feature),
      height: _getMarkerHeightForFeature(feature),
      point: feature.center,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _showPOIActions(feature),
        child: Container(
          decoration: BoxDecoration(
            color: _getBackgroundColorForPOIType(feature.type),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: _getColorForPOIType(feature.type),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                getIconForFeatureType(feature.type),
                size: _getIconSizeForZoom(currentZoom),
                color: _getColorForPOIType(feature.type),
              ),
              if (_shouldShowTextForZoom(currentZoom)) ...[
                const SizedBox(width: 4.0),
                Flexible(
                  child: Text(
                    feature.name,
                    style: TextStyle(
                      fontSize: _getFontSizeForZoom(currentZoom),
                      fontWeight: FontWeight.bold,
                      color: _getColorForPOIType(feature.type),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _getMarkerWidthForFeature(SearchableFeature feature) {
    if (_isAccommodationType(feature.type)) {
      return 160.0;
    }
    return 140.0;
  }

  double _getMarkerHeightForFeature(SearchableFeature feature) {
    return 35.0;
  }

  double _getIconSizeForZoom(double zoom) {
    if (zoom < 16.0) return 14.0;
    if (zoom < 18.0) return 16.0;
    return 18.0;
  }

  bool _shouldShowTextForZoom(double zoom) {
    return zoom >= 16.0;
  }

  double _getFontSizeForZoom(double zoom) {
    if (zoom < 17.0) return 10.0;
    if (zoom < 18.0) return 11.0;
    return 12.0;
  }

  bool _isAccommodationType(String type) {
    final accommodationTypes = [
      'accommodation',
      'building',
      'house',
      'pitch',
      'camp_pitch',
      'holiday_home',
      'chalet',
      'bungalow',
      'lodge',
      'cabin'
    ];
    return accommodationTypes.contains(type.toLowerCase()) ||
        type.toLowerCase().contains('comfort') ||
        type.toLowerCase().contains('wellness');
  }

  Color _getBackgroundColorForPOIType(String type) {
    return _getColorForPOIType(type).withValues(alpha: 0.1);
  }

  Color _getColorForPOIType(String type) {
    switch (type.toLowerCase()) {
      case 'industrial':
        return Colors.deepPurple;
      case 'bus_stop':
        return Colors.blue;
      case 'parking':
        return Colors.indigo;
      case 'building':
      case 'accommodation':
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
            : _calculateCurrentSearchCardHeight()) +
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

  double _calculateCurrentSearchCardHeight() {
    return controller.fullSearchCardHeight > 0
        ? controller.fullSearchCardHeight
        : 200; // Default height
  }

  Widget _buildSearchResults(bool isUiReady) {
    if (!controller.showSearchResults ||
        controller.searchResults.isEmpty ||
        !isUiReady ||
        controller.isRouteActiveForCardSwitch) {
      return const SizedBox.shrink();
    }

    double searchResultsTopPosition =
        8 + _calculateCurrentSearchCardHeight() + 16;

    final bool instructionCardVisible = controller.currentDisplayedManeuver !=
            null &&
        controller.currentDisplayedManeuver!.turnType != TurnType.depart &&
        !(controller.currentManeuvers.length <= 2 &&
            controller.currentDisplayedManeuver!.turnType == TurnType.arrive);

    if (instructionCardVisible) {
      searchResultsTopPosition += 80.0 + 16;
    }

    return Positioned(
      top: searchResultsTopPosition,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      "${controller.searchResults.length} Ergebnisse",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              // Results
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: controller.searchResults.length,
                  itemBuilder: (context, index) {
                    final feature = controller.searchResults[index];
                    return _buildSearchResultTile(feature, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(SearchableFeature feature, int index) {
    final color = _getColorForPOIType(feature.type);
    final isAccommodation = _isAccommodationType(feature.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => searchHandler.selectFeatureAndSetPoint(feature),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon with category indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  getIconForFeatureType(feature.type),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getReadableFeatureType(feature.type),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Distance indicator (if available)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getReadableFeatureType(String type) {
    switch (type.toLowerCase()) {
      case 'accommodation':
      case 'building':
        return 'Unterkunft';
      case 'shop':
        return 'Geschäft';
      case 'restaurant':
        return 'Restaurant';
      case 'cafe':
        return 'Café';
      case 'bar':
        return 'Bar';
      case 'toilets':
      case 'sanitary':
        return 'Sanitär';
      case 'parking':
        return 'Parkplatz';
      case 'playground':
        return 'Spielplatz';
      case 'reception':
        return 'Rezeption';
      case 'information':
        return 'Information';
      default:
        return type;
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
        _updateSearchCardHeight();
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
