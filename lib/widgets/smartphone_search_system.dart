// lib/widgets/smartphone_search_system.dart - EINFACH UND FUNKTIONAL
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';

/// EINFACHES, FUNKTIONALES Search System
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
    // ✅ EINFACHE LÖSUNG: Feste Höhe, die GARANTIERT funktioniert
    return SizedBox(
      height: 160, // Feste, sichere Höhe
      child: widget.showRouteInfoAndFadeFields && _hasActiveRoute
          ? _buildRouteInfoMode()
          : _buildSearchMode(),
    );
  }

  Widget _buildSearchMode() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.explore,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Navigation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  style: const TextStyle(fontSize: 10, color: Colors.blue),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Fields - KOMPAKT
          _buildCompactSearchFields(),
        ],
      ),
    );
  }

  Widget _buildCompactSearchFields() {
    return Column(
      children: [
        // Start Field
        _buildSingleSearchField(SearchFieldType.start),

        const SizedBox(height: 8),

        // Swap Button
        Row(
          children: [
            const Expanded(child: Divider()),
            IconButton(
              icon: const Icon(Icons.swap_vert, size: 18),
              onPressed: () {
                if (widget.enableHapticFeedback) {
                  HapticFeedback.mediumImpact();
                }
                widget.controller.swapStartAndDestination();
              },
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const Expanded(child: Divider()),
          ],
        ),

        const SizedBox(height: 8),

        // Destination Field
        _buildSingleSearchField(SearchFieldType.destination),
      ],
    );
  }

  Widget _buildSingleSearchField(SearchFieldType fieldType) {
    final controller = fieldType == SearchFieldType.start
        ? widget.controller.startSearchController
        : widget.controller.endSearchController;
    final focusNode = fieldType == SearchFieldType.start
        ? widget.controller.startFocusNode
        : widget.controller.endFocusNode;

    return Container(
      height: 40, // Feste Höhe
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Icon
          Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              fieldType == SearchFieldType.start
                  ? Icons.trip_origin
                  : Icons.flag_outlined,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ),

          // TextField
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '${fieldType.displayName}...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Actions
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 16),
              onPressed: () => controller.clear(),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),

          if (fieldType == SearchFieldType.start)
            IconButton(
              icon: const Icon(Icons.my_location, size: 16),
              onPressed: () => widget.controller.setCurrentLocationAsStart(),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoMode() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
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
              // Zurück zum Search Mode
              widget.controller.setRouteInfoAndFadeFields(false);
            },
            onClosePressed: _clearRouteAndReset,
          ),

          const SizedBox(height: 8),

          // Edit Button
          GestureDetector(
            onTap: () {
              widget.controller.setRouteInfoAndFadeFields(false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Bearbeiten',
                    style: TextStyle(color: Colors.white, fontSize: 12),
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
