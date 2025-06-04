// lib/widgets/smartphone_search_system.dart - CONST CONSTRUCTOR FIX
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';

// ✅ ColorValues Extension für smartphone_search_system.dart
extension ColorValues on Color {
  Color withValues({double? alpha, int? r, int? g, int? b}) {
    return Color.fromARGB(alpha != null ? (alpha * 255).round().toInt() : a,
        (r ?? this.r).toInt(), (g ?? this.g).toInt(), (b ?? this.b).toInt());
  }
}

// Placeholder for SmartphoneBreakpoints if not defined/imported
class SmartphoneBreakpoints {
  static const double small = 360; // Example value

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < small;
  }
}

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
  bool _isStartUsingGPS = false;

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
    if (mounted) {
      setState(() {});
    }
  }

  void _evaluateInitialState() {
    _hasActiveRoute = widget.controller.routePolyline != null;
  }

  void _initializeStartField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.currentGpsPosition != null) {
        _setGPSAsStartSilent();
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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 50;
    final isSmallScreen = SmartphoneBreakpoints.isSmallScreen(context);

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
            _buildGoogleStandardSearchFields(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleStandardSearchFields(bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildGoogleStartField(isSmallScreen),
        SizedBox(height: isSmallScreen ? 6 : 8),
        _buildSwapButton(isSmallScreen),
        SizedBox(height: isSmallScreen ? 6 : 8),
        _buildSimpleDestinationField(isSmallScreen),
      ],
    );
  }

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
          _buildGPSButton(iconSize),
          Container(
            width: 1,
            height: fieldHeight * 0.6,
            color: Colors.grey.shade300,
          ),
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
              readOnly: _isStartUsingGPS,
              onTap: _isStartUsingGPS ? _switchToManualStart : null,
            ),
          ),
          if (!_isStartUsingGPS &&
              widget.controller.startSearchController.text.isNotEmpty)
            _buildClearButton(iconSize, true),
          _buildMapSelectionButton(iconSize, SearchFieldType.start),
        ],
      ),
    );
  }

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
          } else {
            widget.controller.endSearchController.clear();
          }
          if (mounted) {
            setState(() {});
          }
        },
        padding: EdgeInsets.zero,
      ),
    );
  }

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.flag_outlined,
              size: iconSize,
              color: Colors.grey.shade600,
            ),
          ),
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
          if (widget.controller.endSearchController.text.isNotEmpty)
            _buildClearButton(iconSize, false),
          _buildMapSelectionButton(iconSize, SearchFieldType.destination),
        ],
      ),
    );
  }

  void _setGPSAsStart() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    if (widget.controller.currentGpsPosition != null) {
      widget.controller.setCurrentLocationAsStart();
      _isStartUsingGPS = true;
      if (mounted) {
        setState(() {});
      }
      _showSnackbar("GPS-Position als Startpunkt gesetzt");
    } else {
      _showSnackbar("GPS-Position nicht verfügbar", isError: true);
    }
  }

  void _setGPSAsStartSilent() {
    if (widget.controller.currentGpsPosition != null) {
      widget.controller.setCurrentLocationAsStart();
      _isStartUsingGPS = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _switchToManualStart() {
    if (_isStartUsingGPS) {
      _isStartUsingGPS = false;
      widget.controller.startSearchController.clear();
      if (mounted) {
        setState(() {});
      }
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
    widget.controller.swapStartAndDestination();
    _isStartUsingGPS = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            backgroundColor: isError ? Colors.red : Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      } catch (e) {
        print("SnackBar Error: $message"); // ignore: avoid_print
      }
    }
  }

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
              // ✅ FIX: CONST CONSTRUCTOR hinzugefügt
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
