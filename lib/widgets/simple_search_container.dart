// lib/widgets/simple_search_container.dart - COMPLETE FILE
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';

class SimpleSearchContainer extends StatefulWidget {
  final MapScreenController controller;
  final List<SearchableFeature> allFeatures;
  final Widget? routeInfo;
  final bool isStartLocked;
  final bool isDestinationLocked;
  final bool showRouteInfoAndFadeFields;

  const SimpleSearchContainer({
    super.key,
    required this.controller,
    required this.allFeatures,
    this.routeInfo,
    required this.isStartLocked,
    required this.isDestinationLocked,
    required this.showRouteInfoAndFadeFields,
  });

  @override
  State<SimpleSearchContainer> createState() => _SimpleSearchContainerState();
}

class _SimpleSearchContainerState extends State<SimpleSearchContainer>
    with TickerProviderStateMixin {
  late AnimationController _collapseController;
  late AnimationController _routeInfoController;
  late Animation<double> _collapseAnimation;
  late Animation<double> _routeInfoAnimation;

  @override
  void initState() {
    super.initState();

    // Animation Controller for collapsing search fields
    _collapseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Animation Controller for showing route info
    _routeInfoController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );

    _routeInfoAnimation = CurvedAnimation(
      parent: _routeInfoController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(SimpleSearchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger animations based on state changes
    if (widget.showRouteInfoAndFadeFields != oldWidget.showRouteInfoAndFadeFields) {
      if (widget.showRouteInfoAndFadeFields) {
        _collapseController.forward();
        _routeInfoController.forward();
      } else {
        _collapseController.reverse();
        _routeInfoController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _collapseController.dispose();
    _routeInfoController.dispose();
    super.dispose();
  }

  void _setStartLocation(SearchableFeature feature) {
    widget.controller.setStartLocation(feature);
    FocusScope.of(context).unfocus();
  }

  void _setDestination(SearchableFeature feature) {
    widget.controller.setDestination(feature);
    FocusScope.of(context).unfocus();
  }

  void _setCurrentAsStart() {
    widget.controller.setCurrentLocationAsStart();
    FocusScope.of(context).unfocus();
  }

  void _activateMapSelection(SearchFieldType fieldType) {
    widget.controller.activateMapSelection(fieldType);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tap on the map to select ${fieldType == SearchFieldType.start ? 'start' : 'destination'}.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _swapStartAndDestination() {
    widget.controller.swapStartAndDestination();
    FocusScope.of(context).unfocus();
  }

  void _expandSearchFields() {
    // Activate edit mode
    widget.controller.showRouteInfoAndFadeFields = false;
    widget.controller.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_collapseAnimation, _routeInfoAnimation]),
      builder: (context, child) {
        return Stack(
          children: [
            // Full search fields (hidden when route is active)
            AnimatedOpacity(
              opacity: widget.showRouteInfoAndFadeFields ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                height: widget.showRouteInfoAndFadeFields ? 0.0 : null,
                child: widget.showRouteInfoAndFadeFields
                    ? const SizedBox.shrink()
                    : _buildFullSearchInterface(),
              ),
            ),

            // Compact route info (shown when route is active)
            if (widget.showRouteInfoAndFadeFields)
              AnimatedOpacity(
                opacity: _routeInfoAnimation.value,
                duration: const Duration(milliseconds: 300),
                child: Transform.scale(
                  scale: 0.8 + (0.2 * _routeInfoAnimation.value),
                  child: _buildCompactRouteDisplay(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFullSearchInterface() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start Input Row
            Row(
              children: [
                Expanded(
                  child: CampsiteSearchInput(
                    fieldType: SearchFieldType.start,
                    controller: widget.controller.startSearchController,
                    focusNode: widget.controller.startFocusNode,
                    allFeatures: widget.allFeatures,
                    onFeatureSelected: _setStartLocation,
                    onCurrentLocationTap: _setCurrentAsStart,
                    onMapSelectionTap: () =>
                        _activateMapSelection(SearchFieldType.start),
                  ),
                ),
                const SizedBox(width: 8),
                _buildLockButton(true),
              ],
            ),

            const SizedBox(height: 12),

            // Swap Button and Dividers
            Row(
              children: [
                const Expanded(child: Divider(height: 1, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.swap_vert, color: Colors.grey),
                    tooltip: 'Swap start and destination',
                    onPressed: _swapStartAndDestination,
                  ),
                ),
                const Expanded(child: Divider(height: 1, thickness: 1)),
              ],
            ),

            const SizedBox(height: 12),

            // Destination Input Row
            Row(
              children: [
                Expanded(
                  child: CampsiteSearchInput(
                    fieldType: SearchFieldType.destination,
                    controller: widget.controller.endSearchController,
                    focusNode: widget.controller.endFocusNode,
                    allFeatures: widget.allFeatures,
                    onFeatureSelected: _setDestination,
                    onMapSelectionTap: () =>
                        _activateMapSelection(SearchFieldType.destination),
                  ),
                ),
                const SizedBox(width: 8),
                _buildLockButton(false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockButton(bool isStart) {
    final isLocked = isStart ? widget.isStartLocked : widget.isDestinationLocked;
    final onPressed = isStart
        ? widget.controller.toggleStartLock
        : widget.controller.toggleDestinationLock;

    return Container(
      decoration: BoxDecoration(
        color: isLocked ? Colors.green.withAlpha(30) : Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLocked ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(
          isLocked ? Icons.lock : Icons.lock_open_outlined,
          color: isLocked ? Colors.green : Colors.grey,
        ),
        tooltip: isLocked
            ? "${isStart ? 'Start' : 'Destination'} locked"
            : "${isStart ? 'Start' : 'Destination'} unlocked",
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCompactRouteDisplay() {
    return CompactRouteWidget(
      destinationName: widget.controller.endSearchController.text,
      remainingDistance: widget.controller.remainingRouteDistance,
      totalDistance: widget.controller.routeDistance,
      remainingTime: widget.controller.remainingRouteTimeMinutes,
      totalTime: widget.controller.routeTimeMinutes,
      isNavigating: widget.controller.followGps && widget.controller.currentGpsPosition != null,
      onEditPressed: _expandSearchFields,
      onClosePressed: () {
        widget.controller.resetRouteAndNavigation();
        widget.controller.resetSearchFields();
      },
    );
  }
}
