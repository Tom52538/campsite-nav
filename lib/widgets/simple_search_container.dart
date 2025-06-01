// lib/widgets/simple_search_container.dart
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart'; // Assuming this path
import 'package:camping_osm_navi/widgets/campsite_search_input.dart'; // Assuming this path

class SimpleSearchContainer extends StatefulWidget {
  final MapScreenController controller; // Controller from MapScreen
  final List<SearchableFeature> allFeatures; // All POIs for autocomplete
  final Widget? routeInfo; // Optional: To display route information
  final bool isStartLocked;
  final bool isDestinationLocked;

  const SimpleSearchContainer({
    super.key,
    required this.controller,
    required this.allFeatures,
    this.routeInfo,
    required this.isStartLocked,
    required this.isDestinationLocked,
  });

  @override
  State<SimpleSearchContainer> createState() => _SimpleSearchContainerState();
}

class _SimpleSearchContainerState extends State<SimpleSearchContainer> {
  void _setStartLocation(SearchableFeature feature) {
    widget.controller.setStartLocation(feature);
    // Optionally, unfocus or clear the other field if needed
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
    // Consider providing feedback to the user that map selection is active
    // e.g., using a SnackBar or a message in the UI
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Tippen Sie auf die Karte, um ${fieldType == SearchFieldType.start ? 'Start' : 'Ziel'} auszuwählen.')),
    );
  }

  void _swapStartAndDestination() {
    widget.controller.swapStartAndDestination();
    // Unfocus after swapping to prevent keyboard issues or if needed
    FocusScope.of(context).unfocus();
  }

  // Placeholder for _hasRoute() and _buildRouteInfo() if needed later
  // bool _hasRoute() {
  //   return widget.controller.routePolyline != null;
  // }

  // Widget _buildRouteInfo() {
  //   if (widget.routeInfo != null) return widget.routeInfo!;
  //   return Text('Route: ${widget.controller.routeDistance?.toStringAsFixed(1)} km, ${widget.controller.routeTimeMinutes} min');
  // }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
              IconButton(
                icon: Icon(widget.isStartLocked
                    ? Icons.lock
                    : Icons.lock_open_outlined), // Korrigiert
                tooltip: widget.isStartLocked
                    ? "Startpunkt entsperren"
                    : "Startpunkt sperren",
                onPressed: () => widget.controller.toggleStartLock(),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Swap Button and Dividers
          Row(
            children: [
              const Expanded(child: Divider(height: 1, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.swap_vert, color: Colors.grey),
                  tooltip: 'Start und Ziel tauschen',
                  onPressed: _swapStartAndDestination,
                ),
              ),
              const Expanded(child: Divider(height: 1, thickness: 1)),
            ],
          ),

          const SizedBox(height: 8),

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
              IconButton(
                icon: Icon(widget.isDestinationLocked
                    ? Icons.lock
                    : Icons.lock_open_outlined), // Korrigiert
                tooltip: widget.isDestinationLocked
                    ? "Zielpunkt entsperren"
                    : "Zielpunkt sperren",
                onPressed: () => widget.controller.toggleDestinationLock(),
              ),
            ],
          ),

          // Optional: Route Info (if provided or conditions met)
          if (widget.routeInfo !=
              null /*|| _hasRoute()*/) // _hasRoute() part is commented out as per note
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: widget.routeInfo!, // _buildRouteInfo() is commented out
            ),
        ],
      ),
    );
  }
}
