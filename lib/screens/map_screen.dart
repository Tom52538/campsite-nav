// lib/screens/map_screen.dart - KEYBOARD FIX VERSION
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

        if (isKeyboardVisible &&
            controller.visibleSearchResults.isNotEmpty &&
            (controller.startFocusNode.hasFocus ||
                controller.endFocusNode.hasFocus)) {
          Future.delayed(const Duration(milliseconds: 400), () {
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
        // ✅ FIX 1: Kein GestureDetector um die Map - Hauptproblem gelöst!
        _buildMap(isUiReady, mapTheme, selectedLocation),

        // UI-Elemente können weiterhin Focus haben
        if (!controller.compactSearchMode) _buildSearchCard(isUiReady),
        if (controller.compactSearchMode) _buildCompactSearchBar(isUiReady),
        _buildInstructionCard(isUiReady),
        if (!controller.isKeyboardVisible) _buildSearchResults(isUiReady),
        if (controller.showHorizontalPOIStrip) _buildHorizontalPOIStrip(),
        _buildLoadingOverlays(isUiReady, isLoading, selectedLocation),
      ],
    );
  }

  Widget _buildCompactSearchBar(bool isUiReady) {
    if (!isUiReady) return const SizedBox.shrink();

    final activeController =
        controller.activeSearchField == ActiveSearchField.start
            ? controller.startSearchController
            : controller.endSearchController;

    final activeFocusNode =
        controller.activeSearchField == ActiveSearchField.start
            ? controller.startFocusNode
            : controller.endFocusNode;

    final hintText = controller.activeSearchField == ActiveSearchField.start
        ? "Startpunkt eingeben..."
        : "Ziel eingeben...";

    return Positioned(
      top: kSearchCardTopPadding,
      left: kSearchCardHorizontalMargin,
      right: kSearchCardHorizontalMargin,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: activeController,
                focusNode: activeFocusNode,
                decoration: InputDecoration(
                  hintText: hintText,
                  prefixIcon: Icon(
                    controller.activeSearchField == ActiveSearchField.start
                        ? Icons.trip_origin
                        : Icons.flag_outlined,
                    color: Colors.deepOrange,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (activeController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  activeController.clear();
                  routeHandler.clearRoute();
                },
              ),
            IconButton(
              icon: const Icon(Icons.keyboard_hide, color: Colors.deepOrange),
              onPressed: () {
                FocusScope.of(context).unfocus();
              },
            ),
          ],
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

        // ✅ FIX 2: Kein automatischer unfocus bei POI-Auswahl
        // FocusScope.of(context).unfocus(); // ENTFERNT

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
                // ✅ FIX 3: Smarte Map-Tap Behandlung
                _handleMapTap(tapPosition, point);
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

  // ✅ FIX 4: Neue smarte Map-Tap Behandlung
  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    // Nur unfocus wenn TextField aktiv ist UND wirklich auf leere Map geklickt
    if (controller.startFocusNode.hasFocus ||
        controller.endFocusNode.hasFocus) {
      // Prüfe ob auf POI/Marker geklickt wurde
      bool hitPOI = false;

      // Prüfe Distanz zu sichtbaren POIs
      for (final feature in controller.visibleSearchResults) {
        const Distance distance = Distance();
        final distanceToFeature = distance.distance(point, feature.center);
        if (distanceToFeature < 50) {
          // 50m Toleranz
          hitPOI = true;
          break;
        }
      }

      // Nur unfocus wenn NICHT auf POI geklickt
      if (!hitPOI) {
        FocusScope.of(context).unfocus();
      }
    }

    // Normale Map-Tap Behandlung für Route-Erstellung
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

  Widget _buildCompactCard() {
    return buildCompactRouteInfoCard(
      context,
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
      context,
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
      setStartToCurrentLocation: setStartToCurrentLocation,
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
        (controller.compactSearchMode
            ? 60
            : _calculateCurrentSearchCardHeight()) +
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

  double _calculateDefaultCardHeight() {
    return (kSearchInputRowHeight * 2) +
        kDividerAndSwapButtonHeight +
        (kCardInternalVerticalPadding * 2) +
        (controller.routeDistance != null ? kRouteInfoHeight : 0);
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

  // ✅ FIX 5: Map-Events ohne automatischen unfocus - Problem behoben!
  void _handleMapEvent(MapEvent mapEvent) {
    if (mapEvent is MapEventMove &&
        (mapEvent.source == MapEventSource.dragStart ||
            mapEvent.source == MapEventSource.flingAnimationController)) {
      if (controller.followGps) {
        controller.setFollowGps(false);
        showSnackbar("Follow-GPS Modus deaktiviert.", durationSeconds: 2);
      }
    }

    // ❌ ENTFERNT: Automatischer unfocus bei Map-Drag - Das war der Hauptverursacher!
    // if (mapEvent is MapEventMove &&
    //     (mapEvent.source == MapEventSource.dragStart ||
    //         mapEvent.source == MapEventSource.flingAnimationController) &&
    //     (controller.startFocusNode.hasFocus ||
    //         controller.endFocusNode.hasFocus)) {
    //   FocusScope.of(context).unfocus();
    // }
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
    } else {
      if (kDebugMode) {
        print("SNACKBAR (no context): $message");
      }
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
