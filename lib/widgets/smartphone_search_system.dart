// lib/widgets/smartphone_search_system.dart - SCHRITT 1: GOOGLE MAPS START-FELD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';

/// SCHRITT 1: Google Maps Standard Start-Feld Implementation
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
  bool _isStartUsingGPS = false; // Track GPS vs Manual start

  @override
  void initState() {
    super.initState();
    _setupControllerListeners();
    _evaluateInitialState();
    _initializeStartField();
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

  // ✅ SCHRITT 1: Initialisiere Start-Feld mit GPS (Google Standard)
  void _initializeStartField() {
    // Auto-set GPS location if available - AFTER build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.currentGpsPosition != null) {
        _setGPSAsStartSilent(); // Silent version without snackbar
      }
    });
  }

  void _clearRouteAndReset() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.controller.resetRouteAndNavigation();
    widget.controller.resetSearchFields();
    _isStartUsingGPS = false;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 50;
    final isSmallScreen =
        MediaQuery.of(context).size.width < SmartphoneBreakpoints.small;

    final maxHeight = _calculateMaxHeight(
        screenHeight, keyboardHeight, isKeyboardVisible, isSmallScreen);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        minHeight: 60,
      ),
      child: IntrinsicHeight(
        child: widget.showRouteInfoAndFadeFields && _hasActiveRoute
            ? _buildRouteInfoMode()
            : _buildSearchMode(isSmallScreen),
      ),
    );
  }

  double _calculateMaxHeight(double screenHeight, double keyboardHeight,
      bool isKeyboardVisible, bool isSmallScreen) {
    if (widget.showRouteInfoAndFadeFields && _hasActiveRoute) {
      return isSmallScreen ? 100 : 120;
    }

    if (isKeyboardVisible) {
      final availableHeight = screenHeight - keyboardHeight - 100;
      return (availableHeight * 0.6).clamp(120, 200);
    }

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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
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

            // Search Fields
            _buildGoogleStandardSearchFields(isSmallScreen),
          ],
        ),
      ),
    );
  }

  // ✅ SCHRITT 1: Google Maps Standard Search Fields
  Widget _buildGoogleStandardSearchFields(bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ START FIELD - Google Maps Style
        _buildGoogleStartField(isSmallScreen),

        SizedBox(height: isSmallScreen ? 6 : 8),

        // Swap Button
        _buildSwapButton(isSmallScreen),

        SizedBox(height: isSmallScreen ? 6 : 8),

        // ✅ DESTINATION FIELD - Simple for now (will be enhanced in Step 2)
        _buildSimpleDestinationField(isSmallScreen),
      ],
    );
  }

  // ✅ SCHRITT 1: Google Maps Standard Start Field
  Widget _buildGoogleStartField(bool isSmallScreen) {
    final fieldHeight = isSmallScreen ? 40.0 : 44.0;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final fontSize = isSmallScreen ? 13.0 : 14.0;

    return Container(
      height: fieldHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.controller.startFocusNode.hasFocus
              ? Colors.blue.shade400
              : Colors.grey.shade300,
          width: widget.controller.startFocusNode.hasFocus ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
        color: widget.controller.startFocusNode.hasFocus
            ? Colors.blue.withValues(alpha: 0.05)
            : Colors.white,
      ),
      child: Row(
        children: [
          // ✅ GPS Button (Google Maps Standard)
          _buildGPSButton(iconSize),

          // ✅ Divider
          Container(
            width: 1,
            height: fieldHeight * 0.6,
            color: Colors.grey.shade300,
          ),

          // ✅ Start Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.trip_origin,
              size: iconSize,
              color: _isStartUsingGPS
                  ? Colors.blue.shade600
                  : Colors.grey.shade600,
            ),
          ),

          // ✅ TextField
          Expanded(
            child: TextField(
              controller: widget.controller.startSearchController,
              focusNode: widget.controller.startFocusNode,
              style: TextStyle(
                fontSize: fontSize,
                color: _isStartUsingGPS ? Colors.blue.shade700 : Colors.black,
                fontWeight:
                    _isStartUsingGPS ? FontWeight.w500 : FontWeight.normal,
              ),
              decoration: InputDecoration(
                hintText: _isStartUsingGPS ? null : 'Startpunkt eingeben...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              readOnly: _isStartUsingGPS, // ✅ Readonly when using GPS
              onTap: _isStartUsingGPS ? _switchToManualStart : null,
            ),
          ),

          // ✅ Clear Button (when manual input)
          if (!_isStartUsingGPS &&
              widget.controller.startSearchController.text.isNotEmpty)
            _buildClearButton(iconSize, true),

          // ✅ Map Selection Button
          _buildMapSelectionButton(iconSize, SearchFieldType.start),
        ],
      ),
    );
  }

  // ✅ GPS Button (Blue when active)
  Widget _buildGPSButton(double iconSize) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _setGPSAsStart,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isStartUsingGPS
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.my_location,
            size: iconSize,
            color:
                _isStartUsingGPS ? Colors.blue.shade600 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // ✅ Clear Button
  Widget _buildClearButton(double iconSize, bool isStart) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(Icons.clear, size: iconSize - 2),
        color: Colors.grey.shade600,
        onPressed: () {
          if (isStart) {
            widget.controller.startSearchController.clear();
            _isStartUsingGPS = false;
            setState(() {});
          } else {
            widget.controller.endSearchController.clear();
          }
        },
        padding: EdgeInsets.zero,
      ),
    );
  }

  // ✅ Map Selection Button
  Widget _buildMapSelectionButton(double iconSize, SearchFieldType fieldType) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(Icons.location_searching, size: iconSize - 2),
        color: Colors.grey.shade600,
        onPressed: () => _activateMapSelection(fieldType),
        padding: EdgeInsets.zero,
        tooltip: 'Auf Karte auswählen',
      ),
    );
  }

  // ✅ Swap Button
  Widget _buildSwapButton(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 24 : 28,
      child: Row(
        children: [
          const Expanded(child: Divider()),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              icon: Icon(Icons.swap_vert, size: isSmallScreen ? 16 : 18),
              onPressed: () {
                if (widget.enableHapticFeedback) {
                  HapticFeedback.mediumImpact();
                }
                _swapStartAndDestination();
              },
              padding: EdgeInsets.zero,
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  // ✅ Simple Destination Field (will be enhanced in Step 2)
  Widget _buildSimpleDestinationField(bool isSmallScreen) {
    final fieldHeight = isSmallScreen ? 40.0 : 44.0;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final fontSize = isSmallScreen ? 13.0 : 14.0;

    return Container(
      height: fieldHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.controller.endFocusNode.hasFocus
              ? Colors.blue.shade400
              : Colors.grey.shade300,
          width: widget.controller.endFocusNode.hasFocus ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
        color: widget.controller.endFocusNode.hasFocus
            ? Colors.blue.withValues(alpha: 0.05)
            : Colors.white,
      ),
      child: Row(
        children: [
          // Destination Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.flag_outlined,
              size: iconSize,
              color: Colors.grey.shade600,
            ),
          ),

          // TextField
          Expanded(
            child: TextField(
              controller: widget.controller.endSearchController,
              focusNode: widget.controller.endFocusNode,
              style: TextStyle(fontSize: fontSize),
              decoration: InputDecoration(
                hintText: 'Ziel eingeben...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Clear Button
          if (widget.controller.endSearchController.text.isNotEmpty)
            _buildClearButton(iconSize, false),

          // Map Selection Button
          _buildMapSelectionButton(iconSize, SearchFieldType.destination),
        ],
      ),
    );
  }

  // ✅ SCHRITT 1: Core Functions

  void _setGPSAsStart() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    if (widget.controller.currentGpsPosition != null) {
      // Set GPS as start location
      widget.controller.startSearchController.text = "Mein Standort";
      _isStartUsingGPS = true;

      // Create GPS feature
      final gpsFeature = SearchableFeature(
        id: "gps_location",
        name: "Mein Standort",
        type: "GPS Position",
        center: widget.controller.currentGpsPosition!,
      );

      widget.controller.setStartLocation(gpsFeature);
      setState(() {});

      // Show feedback
      _showSnackbar("GPS-Position als Startpunkt gesetzt");
    } else {
      _showSnackbar("GPS-Position nicht verfügbar", isError: true);
    }
  }

  // ✅ Silent version for initialization
  void _setGPSAsStartSilent() {
    if (widget.controller.currentGpsPosition != null) {
      widget.controller.startSearchController.text = "Mein Standort";
      _isStartUsingGPS = true;

      final gpsFeature = SearchableFeature(
        id: "gps_location",
        name: "Mein Standort",
        type: "GPS Position",
        center: widget.controller.currentGpsPosition!,
      );

      widget.controller.setStartLocation(gpsFeature);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _switchToManualStart() {
    if (_isStartUsingGPS) {
      _isStartUsingGPS = false;
      widget.controller.startSearchController.clear();
      setState(() {});
    }
  }

  void _activateMapSelection(SearchFieldType fieldType) {
    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    widget.controller.activateMapSelection(fieldType);
    _showSnackbar(
        "Tippen Sie auf die Karte um ${fieldType.displayName} zu wählen");
  }

  void _swapStartAndDestination() {
    // Reset GPS state when swapping
    _isStartUsingGPS = false;
    widget.controller.swapStartAndDestination();
    setState(() {});
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ✅ Route Info Mode (unchanged)
  Widget _buildRouteInfoMode() {
    return Container(
      margin: const EdgeInsets.all(8),
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
              widget.controller.setRouteInfoAndFadeFields(false);
            },
            onClosePressed: _clearRouteAndReset,
          ),
          const SizedBox(height: 6),
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
