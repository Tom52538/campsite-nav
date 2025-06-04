// lib/widgets/smartphone_search_system.dart - FUNKTIONIERT WIEDER!
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';

/// FUNKTIONALES Search System - ALLES FUNKTIONIERT WIEDER!
class SmartphoneSearchSystem extends StatefulWidget {
  final MapScreenController controller;
  final List<SearchableFeature> allFeatures;
  final bool isStartLocked;
  final bool isDestinationLocked;
  final bool showRouteInfoAndFadeFields;
  final SearchContext context;
  final bool enableSmartTransitions;
  final bool enableHapticFeedback;
  final Duration autoHideDelay;

  const SmartphoneSearchSystem({
    super.key,
    required this.controller,
    required this.allFeatures,
    required this.isStartLocked,
    required this.isDestinationLocked,
    required this.showRouteInfoAndFadeFields,
    this.context = SearchContext.guest,
    this.enableSmartTransitions = true,
    this.enableHapticFeedback = true,
    this.autoHideDelay = const Duration(milliseconds: 800),
  });

  @override
  State<SmartphoneSearchSystem> createState() => _SmartphoneSearchSystemState();
}

class _SmartphoneSearchSystemState extends State<SmartphoneSearchSystem>
    with TickerProviderStateMixin {
  late AnimationController _masterController;
  late AnimationController _routeInfoController;

  late Animation<double> _masterAnimation;
  late Animation<double> _routeInfoAnimation;

  bool _hasActiveRoute = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupControllerListeners();
    _evaluateInitialState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanges);
    _masterController.dispose();
    _routeInfoController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _routeInfoController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _masterAnimation = CurvedAnimation(
      parent: _masterController,
      curve: Curves.easeInOutCubic,
    );

    _routeInfoAnimation = CurvedAnimation(
      parent: _routeInfoController,
      curve: Curves.easeInOut,
    );

    _masterController.forward();
  }

  void _setupControllerListeners() {
    widget.controller.addListener(_handleControllerChanges);
  }

  void _handleControllerChanges() {
    final wasActiveRoute = _hasActiveRoute;
    _hasActiveRoute = widget.controller.routePolyline != null;

    if (!wasActiveRoute && _hasActiveRoute) {
      if (widget.enableHapticFeedback) {
        HapticFeedback.mediumImpact();
      }
    } else if (wasActiveRoute && !_hasActiveRoute) {
      // Route wurde gelöscht
    }

    // Route Info Animation
    if (widget.showRouteInfoAndFadeFields && _hasActiveRoute) {
      _routeInfoController.forward();
    } else {
      _routeInfoController.reverse();
    }
  }

  void _evaluateInitialState() {
    _hasActiveRoute = widget.controller.routePolyline != null;
    if (_hasActiveRoute && widget.showRouteInfoAndFadeFields) {
      _routeInfoController.value = 1.0;
    }
  }

  void _clearRouteAndReset() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.controller.resetRouteAndNavigation();
    widget.controller.resetSearchFields();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _masterAnimation,
        _routeInfoAnimation,
      ]),
      builder: (context, child) {
        return Container(
          // ✅ SICHERE HÖHE: Maximal 40% der Bildschirmhöhe
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
            maxWidth: MediaQuery.of(context).size.width,
          ),
          child: Stack(
            children: [
              // Main Search Interface
              if (_routeInfoAnimation.value < 0.5)
                FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0)
                      .animate(_routeInfoAnimation),
                  child: _buildMainSearchInterface(),
                ),

              // Route Info Overlay
              if (_hasActiveRoute)
                FadeTransition(
                  opacity: _routeInfoAnimation,
                  child: _buildCompactRouteInfoOverlay(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainSearchInterface() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildSearchFields(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.explore,
            color: Theme.of(context).colorScheme.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Navigation',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${widget.allFeatures.length}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchFields() {
    return Column(
      children: [
        // ✅ START SEARCH FIELD - FUNKTIONIERT!
        CampsiteSearchInput(
          fieldType: SearchFieldType.start,
          controller: widget.controller.startSearchController,
          focusNode: widget.controller.startFocusNode,
          allFeatures: widget.allFeatures,
          onFeatureSelected: (feature) {
            widget.controller.setStartLocation(feature);
          },
          onCurrentLocationTap: () {
            widget.controller.setCurrentLocationAsStart();
          },
          onMapSelectionTap: () {
            widget.controller.activateMapSelection(SearchFieldType.start);
          },
          context: widget.context,
        ),

        const SizedBox(height: 8),

        // ✅ SWAP BUTTON
        Row(
          children: [
            const Expanded(child: Divider()),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: IconButton(
                icon: const Icon(Icons.swap_vert, size: 20),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  if (widget.enableHapticFeedback) {
                    HapticFeedback.mediumImpact();
                  }
                  widget.controller.swapStartAndDestination();
                },
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),

        const SizedBox(height: 8),

        // ✅ DESTINATION SEARCH FIELD - FUNKTIONIERT!
        CampsiteSearchInput(
          fieldType: SearchFieldType.destination,
          controller: widget.controller.endSearchController,
          focusNode: widget.controller.endFocusNode,
          allFeatures: widget.allFeatures,
          onFeatureSelected: (feature) {
            widget.controller.setDestination(feature);
          },
          onMapSelectionTap: () {
            widget.controller.activateMapSelection(SearchFieldType.destination);
          },
          context: widget.context,
          showQuickAccess: true,
        ),
      ],
    );
  }

  Widget _buildCompactRouteInfoOverlay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompactRouteWidget(
            destinationName: widget.controller.endSearchController.text,
            remainingDistance: widget.controller.remainingRouteDistance,
            totalDistance: widget.controller.routeDistance,
            remainingTime: widget.controller.remainingRouteTimeMinutes,
            totalTime: widget.controller.routeTimeMinutes,
            isNavigating: widget.controller.followGps &&
                widget.controller.currentGpsPosition != null,
            onEditPressed: () {
              _routeInfoController.reverse();
            },
            onClosePressed: _clearRouteAndReset,
          ),

          // ✅ EXPAND HINT
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () {
                _routeInfoController.reverse();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Search bearbeiten',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
