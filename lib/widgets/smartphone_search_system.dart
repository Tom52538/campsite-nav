// lib/widgets/smartphone_search_system.dart - OVERFLOW KOMPLETT BEHOBEN
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';

/// OVERFLOW-FREIES Search System - Dynamische Höhenberechnung
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

class _SmartphoneSearchSystemState extends State<SmartphoneSearchSystem> {
  bool _hasActiveRoute = false;

  @override
  void initState() {
    super.initState();
    _setupControllerListeners();
    _evaluateInitialState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanges);
    super.dispose();
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
    }
  }

  void _evaluateInitialState() {
    _hasActiveRoute = widget.controller.routePolyline != null;
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
    // ✅ LÖSUNG: Responsive Container statt feste Höhe
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 50;
    final isSmallScreen =
        MediaQuery.of(context).size.width < SmartphoneBreakpoints.small;

    // Dynamische Höhenberechnung
    final maxHeight = _calculateMaxHeight(
        screenHeight, keyboardHeight, isKeyboardVisible, isSmallScreen);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        minHeight: 60, // Minimum für CompactRouteWidget
      ),
      child: IntrinsicHeight(
        child: widget.showRouteInfoAndFadeFields && _hasActiveRoute
            ? _buildRouteInfoMode()
            : _buildSearchMode(isSmallScreen),
      ),
    );
  }

  // ✅ INTELLIGENTE HÖHENBERECHNUNG
  double _calculateMaxHeight(double screenHeight, double keyboardHeight,
      bool isKeyboardVisible, bool isSmallScreen) {
    if (widget.showRouteInfoAndFadeFields && _hasActiveRoute) {
      // Route Info Mode: Minimal
      return isSmallScreen ? 100 : 120;
    }

    if (isKeyboardVisible) {
      // Keyboard sichtbar: Kompakter
      final availableHeight =
          screenHeight - keyboardHeight - 100; // 100px für andere UI Elemente
      return (availableHeight * 0.6).clamp(120, 200);
    }

    // Normal Mode: Responsive basierend auf Bildschirmgröße
    if (isSmallScreen) {
      return (screenHeight * 0.25).clamp(140, 180);
    } else {
      return (screenHeight * 0.3).clamp(160, 220);
    }
  }

  Widget _buildSearchMode(bool isSmallScreen) {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // ✅ KRITISCH: Minimale Größe
          children: [
            // Header - Kompakter
            Row(
              children: [
                Icon(
                  Icons.explore,
                  color: Theme.of(context).colorScheme.primary,
                  size: isSmallScreen ? 14 : 16,
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                const Expanded(
                  child: Text(
                    'Navigation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.allFeatures.length}',
                    style: const TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ),
              ],
            ),

            SizedBox(height: isSmallScreen ? 8 : 12),

            // Search Fields - Noch kompakter
            _buildUltraCompactSearchFields(isSmallScreen),
          ],
        ),
      ),
    );
  }

  // ✅ ULTRA-KOMPAKTE SEARCH FIELDS
  Widget _buildUltraCompactSearchFields(bool isSmallScreen) {
    final fieldHeight = isSmallScreen ? 36.0 : 40.0;
    final iconSize = isSmallScreen ? 14.0 : 16.0;
    final fontSize = isSmallScreen ? 13.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min, // ✅ KRITISCH
      children: [
        // Start Field
        _buildUltraCompactField(
            SearchFieldType.start, fieldHeight, iconSize, fontSize),

        // Swap Button - Minimaler
        SizedBox(
          height: isSmallScreen ? 24 : 28,
          child: Row(
            children: [
              const Expanded(child: Divider()),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  icon: Icon(Icons.swap_vert, size: iconSize),
                  onPressed: () {
                    if (widget.enableHapticFeedback) {
                      HapticFeedback.mediumImpact();
                    }
                    widget.controller.swapStartAndDestination();
                  },
                  padding: EdgeInsets.zero,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),

        // Destination Field
        _buildUltraCompactField(
            SearchFieldType.destination, fieldHeight, iconSize, fontSize),
      ],
    );
  }

  // ✅ ULTRA-KOMPAKTES EINZELFELD
  Widget _buildUltraCompactField(SearchFieldType fieldType, double height,
      double iconSize, double fontSize) {
    final controller = fieldType == SearchFieldType.start
        ? widget.controller.startSearchController
        : widget.controller.endSearchController;
    final focusNode = fieldType == SearchFieldType.start
        ? widget.controller.startFocusNode
        : widget.controller.endFocusNode;

    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Icon - Kompakter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              fieldType == SearchFieldType.start
                  ? Icons.trip_origin
                  : Icons.flag_outlined,
              size: iconSize,
              color: Colors.grey.shade600,
            ),
          ),

          // TextField - Kompakter
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(fontSize: fontSize),
              decoration: InputDecoration(
                hintText: '${fieldType.displayName}...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Actions - Kompakter
          if (controller.text.isNotEmpty)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: Icon(Icons.clear, size: iconSize),
                onPressed: () => controller.clear(),
                padding: EdgeInsets.zero,
              ),
            ),

          if (fieldType == SearchFieldType.start)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: Icon(Icons.my_location, size: iconSize),
                onPressed: () => widget.controller.setCurrentLocationAsStart(),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoMode() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ KRITISCH
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
              widget.controller.setRouteInfoAndFadeFields(false);
            },
            onClosePressed: _clearRouteAndReset,
          ),

          const SizedBox(height: 6), // Reduziert

          // Edit Button - Kompakter
          GestureDetector(
            onTap: () {
              widget.controller.setRouteInfoAndFadeFields(false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Bearbeiten',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
