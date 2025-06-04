// lib/widgets/smartphone_search_system.dart - FINAL LINT FIX VERSION
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';

/// Premium Smartphone Search System - FINAL LINT FIX
///
/// MISSION: Maximale Karten-Sicht mit stabiler Layout-Performance
///
/// FEATURES:
/// - Semi-transparenter Hintergrund (Karte bleibt sichtbar)
/// - Feste Höhen-Constraints (verhindert Layout-Crash)
/// - Vollständige POI-Suche mit begrenzter Höhe
/// - Auto-Hide nach Route-Berechnung
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
    this.autoHideDelay = const Duration(milliseconds: 1500),
  });

  @override
  State<SmartphoneSearchSystem> createState() => _SmartphoneSearchSystemState();
}

class _SmartphoneSearchSystemState extends State<SmartphoneSearchSystem>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _masterController;
  late AnimationController _routeInfoController;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  late Animation<double> _masterAnimation;
  late Animation<double> _routeInfoAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  SearchInterfaceState _currentState = SearchInterfaceState.expanded;
  bool _hasActiveRoute = false;
  bool _isKeyboardVisible = false;
  bool _userInteractionDetected = false;
  bool _autoTransitionsEnabled = true;

  double _screenWidth = 0;
  double _screenHeight = 0;
  bool _isSmallScreen = false;
  EdgeInsets _safeArea = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _setupControllerListeners();
    _evaluateInitialState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScreenDimensions();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateKeyboardVisibility();
        _updateScreenDimensions();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChanges);
    _masterController.dispose();
    _routeInfoController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _routeInfoController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _masterAnimation = CurvedAnimation(
      parent: _masterController,
      curve: PremiumCurves.smooth,
    );

    _routeInfoAnimation = CurvedAnimation(
      parent: _routeInfoController,
      curve: PremiumCurves.bounce,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: PremiumCurves.material,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -1.2),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: PremiumCurves.snap,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(_masterAnimation);

    _masterController.forward();
    _fadeController.forward();
  }

  void _setupControllerListeners() {
    widget.controller.addListener(_handleControllerChanges);
  }

  void _handleControllerChanges() {
    final wasActiveRoute = _hasActiveRoute;
    _hasActiveRoute = widget.controller.routePolyline != null;

    if (!wasActiveRoute && _hasActiveRoute) {
      _onRouteCalculated();
    } else if (wasActiveRoute && !_hasActiveRoute) {
      _onRouteCleared();
    }

    if (widget.showRouteInfoAndFadeFields !=
        (_currentState == SearchInterfaceState.navigationMode)) {
      if (widget.showRouteInfoAndFadeFields && _hasActiveRoute) {
        _scheduleStateTransition(SearchInterfaceState.navigationMode);
      } else {
        _scheduleStateTransition(SearchInterfaceState.expanded);
      }
    }
  }

  void _onRouteCalculated() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    if (widget.enableSmartTransitions && _autoTransitionsEnabled) {
      Duration delay = widget.autoHideDelay;

      switch (widget.context) {
        case SearchContext.emergency:
          delay = const Duration(milliseconds: 500);
        case SearchContext.arrival:
          delay = const Duration(milliseconds: 2000);
        case SearchContext.departure:
        case SearchContext.guest:
          delay = widget.autoHideDelay;
      }

      Future.delayed(delay, () {
        if (mounted && _hasActiveRoute && !_userInteractionDetected) {
          _scheduleStateTransition(SearchInterfaceState.navigationMode);
        }
      });
    }
  }

  void _onRouteCleared() {
    _scheduleStateTransition(SearchInterfaceState.expanded);
  }

  void _scheduleStateTransition(SearchInterfaceState newState) {
    if (_currentState == newState) return;

    _currentState = newState;
    _executeStateTransition(newState);
  }

  void _executeStateTransition(SearchInterfaceState to) {
    switch (to) {
      case SearchInterfaceState.expanded:
        _transitionToExpanded();
      case SearchInterfaceState.collapsed:
        _transitionToCollapsed();
      case SearchInterfaceState.hidden:
        _transitionToHidden();
      case SearchInterfaceState.navigationMode:
        _transitionToNavigationMode();
    }

    setState(() {});
  }

  void _transitionToExpanded() {
    _slideController.reverse();
    _fadeController.forward();
    _routeInfoController.reverse();
  }

  void _transitionToCollapsed() {
    _fadeController.forward();
    _routeInfoController.reverse();
  }

  void _transitionToHidden() {
    _slideController.forward();
    _fadeController.reverse();
    _routeInfoController.reverse();
  }

  void _transitionToNavigationMode() {
    _slideController.forward();
    _fadeController.reverse();
    _routeInfoController.forward();
  }

  void _updateKeyboardVisibility() {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final wasVisible = _isKeyboardVisible;
    _isKeyboardVisible = keyboardHeight > 50;

    if (wasVisible != _isKeyboardVisible) {
      if (_isKeyboardVisible) {
        _scheduleStateTransition(SearchInterfaceState.expanded);
        _userInteractionDetected = true;
      } else {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _userInteractionDetected = false;
          }
        });
      }
    }
  }

  void _updateScreenDimensions() {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    setState(() {
      _screenWidth = size.width;
      _screenHeight = size.height;
      _isSmallScreen = _screenWidth < SmartphoneBreakpoints.small;
      _safeArea = mediaQuery.padding;
    });
  }

  void _evaluateInitialState() {
    _hasActiveRoute = widget.controller.routePolyline != null;

    if (_hasActiveRoute && widget.showRouteInfoAndFadeFields) {
      _currentState = SearchInterfaceState.navigationMode;
      _routeInfoController.value = 1.0;
      _slideController.value = 1.0;
    } else {
      _currentState = SearchInterfaceState.expanded;
      _fadeController.value = 1.0;
    }
  }

  // Event Handlers
  void _onUserInteraction() {
    _userInteractionDetected = true;
    _autoTransitionsEnabled = false;
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _autoTransitionsEnabled = true;
      }
    });
  }

  void _onExpandRequest() {
    _onUserInteraction();
    _scheduleStateTransition(SearchInterfaceState.expanded);

    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  void _setStartLocation(SearchableFeature feature) {
    _onUserInteraction();
    widget.controller.setStartLocation(feature);

    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  void _setDestination(SearchableFeature feature) {
    _onUserInteraction();
    widget.controller.setDestination(feature);

    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  void _setCurrentLocationAsStart() {
    _onUserInteraction();
    widget.controller.setCurrentLocationAsStart();

    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }
  }

  void _activateMapSelection(SearchFieldType fieldType) {
    _onUserInteraction();
    widget.controller.activateMapSelection(fieldType);

    _scheduleStateTransition(SearchInterfaceState.hidden);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tippen Sie auf die Karte um ${fieldType.displayName} zu wählen',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 3),
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: _safeArea.bottom + 100,
            left: 16,
            right: 16,
          ),
        ),
      );
    }
  }

  void _swapStartAndDestination() {
    _onUserInteraction();

    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    widget.controller.swapStartAndDestination();
  }

  void _clearRouteAndReset() {
    _onUserInteraction();

    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    widget.controller.resetRouteAndNavigation();
    widget.controller.resetSearchFields();
    _scheduleStateTransition(SearchInterfaceState.expanded);
  }

  // Responsive Design
  double get _horizontalMargin => _isSmallScreen ? 8.0 : 12.0;
  double get _verticalMargin => _isSmallScreen ? 6.0 : 8.0;
  double get _cardPadding => _isSmallScreen ? 10.0 : 12.0;
  double get _headerFontSize => _isSmallScreen ? 13.0 : 14.0;
  double get _bodyFontSize => _isSmallScreen ? 11.0 : 12.0;

  // ✅ KRITISCH: Maximale Höhe für Layout-Stabilität
  double get _maxSearchInterfaceHeight => _screenHeight > 0
      ? (_screenHeight * 0.5)
          .clamp(200.0, 400.0) // 50% von Bildschirm, min 200px, max 400px
      : 300.0; // Fallback

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _masterAnimation,
        _routeInfoAnimation,
        _fadeAnimation,
        _slideAnimation,
      ]),
      builder: (context, child) {
        // ✅ FIX: Explizite Größen-Constraints für Stack
        return SizedBox(
          width: _screenWidth > 0
              ? _screenWidth
              : MediaQuery.of(context).size.width,
          height: _maxSearchInterfaceHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Search Interface - SEMI-TRANSPARENT
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildConstrainedSearchInterface(),
                    ),
                  ),
                ),
              ),

              // Route Info Overlay (Navigation Mode)
              if (_hasActiveRoute)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _routeInfoAnimation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.0)
                          .animate(_routeInfoAnimation),
                      child: _buildCompactRouteInfoOverlay(),
                    ),
                  ),
                ),

              // Minimaler Expand Hint
              if (_currentState != SearchInterfaceState.expanded)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: GestureDetector(
                    onTap: _onExpandRequest,
                    child: Container(
                      color: Colors.transparent,
                      child: _buildMinimalExpandHint(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ✅ HAUPTWIDGET: Mit expliziten Höhen-Constraints
  Widget _buildConstrainedSearchInterface() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _horizontalMargin,
        vertical: _verticalMargin,
      ),
      constraints: BoxConstraints(
        maxHeight: _maxSearchInterfaceHeight -
            (_verticalMargin * 2), // Abzüglich Margins
        maxWidth: _screenWidth > 0
            ? _screenWidth - (_horizontalMargin * 2)
            : double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
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
              padding: EdgeInsets.all(_cardPadding),
              child: SingleChildScrollView(
                // ✅ Scroll falls zu hoch
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // KOMPAKTER Context Header
                    _buildCompactContextualHeader(),

                    SizedBox(height: _verticalMargin),

                    // ✅ Search Input mit BEGRENZTER HÖHE
                    _buildConstrainedSearchInput(SearchFieldType.start),

                    SizedBox(height: _verticalMargin * 0.7),

                    // MINI Swap Button
                    _buildMiniSwapButton(),

                    SizedBox(height: _verticalMargin * 0.7),

                    // ✅ Search Input mit BEGRENZTER HÖHE
                    _buildConstrainedSearchInput(SearchFieldType.destination),

                    // KOMPAKTE Quick Access Section
                    if (_currentState == SearchInterfaceState.expanded)
                      _buildCompactQuickAccessSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactContextualHeader() {
    String contextMessage = '';
    IconData contextIcon = Icons.navigation;
    Color contextColor = Theme.of(context).colorScheme.primary;

    switch (widget.context) {
      case SearchContext.arrival:
        contextMessage = 'Willkommen!';
        contextIcon = Icons.celebration;
        contextColor = Colors.green;
      case SearchContext.departure:
        contextMessage = 'Gute Reise!';
        contextIcon = Icons.flight_takeoff;
        contextColor = Colors.orange;
      case SearchContext.emergency:
        contextMessage = 'Notfall';
        contextIcon = Icons.emergency;
        contextColor = Colors.red;
      case SearchContext.guest:
        contextMessage = 'Resort Navigation';
        contextIcon = Icons.explore;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: contextColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            contextIcon,
            color: contextColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            contextMessage,
            style: TextStyle(
              fontSize: _headerFontSize,
              fontWeight: FontWeight.w600,
              color: contextColor,
              height: 1.1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Text(
            '214 POIs',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // ✅ SEARCH INPUT mit EXPLIZITEN CONSTRAINTS
  Widget _buildConstrainedSearchInput(SearchFieldType fieldType) {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 120, // ✅ KRITISCH: Maximale Höhe für Search + Results
        maxWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Lock Button
          _buildCompactLockButton(fieldType),

          // Search Input mit BEGRENZTER HÖHE
          Expanded(
            child: SizedBox(
              height: 120, // ✅ KRITISCH: Explizite Höhe
              child: CampsiteSearchInput(
                fieldType: fieldType,
                controller: fieldType == SearchFieldType.start
                    ? widget.controller.startSearchController
                    : widget.controller.endSearchController,
                focusNode: fieldType == SearchFieldType.start
                    ? widget.controller.startFocusNode
                    : widget.controller.endFocusNode,
                allFeatures: widget.allFeatures,
                onFeatureSelected: fieldType == SearchFieldType.start
                    ? _setStartLocation
                    : _setDestination,
                onCurrentLocationTap: fieldType == SearchFieldType.start
                    ? _setCurrentLocationAsStart
                    : null,
                onMapSelectionTap: () => _activateMapSelection(fieldType),
                context: widget.context,
                autoDismissOnSelection: true,
                showQuickAccess: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLockButton(SearchFieldType fieldType) {
    final isLocked = fieldType == SearchFieldType.start
        ? widget.isStartLocked
        : widget.isDestinationLocked;

    final onPressed = fieldType == SearchFieldType.start
        ? widget.controller.toggleStartLock
        : widget.controller.toggleDestinationLock;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          _onUserInteraction();
          if (widget.enableHapticFeedback) {
            HapticFeedback.selectionClick();
          }
          onPressed();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isLocked
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLocked ? Colors.green : Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: Icon(
            isLocked ? Icons.lock : Icons.lock_open_outlined,
            color: isLocked ? Colors.green : Colors.grey.shade600,
            size: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSwapButton() {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: _swapStartAndDestination,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(15),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    color: Colors.grey,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQuickAccessSection() {
    const quickActions = [
      ('🅿️', 'parkplatz', 'Parking'),
      ('👨‍👩‍👧‍👦', 'spielplatz', 'Familie'),
      ('🏖️', 'beach pool', 'Beach'),
      ('🍽️', 'restaurant', 'Essen'),
    ];

    return Container(
      margin: EdgeInsets.only(top: _verticalMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              'Beliebte Ziele',
              style: TextStyle(
                fontSize: _bodyFontSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: Row(
              children: quickActions.map((action) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _onQuickActionTap(action.$2, action.$3),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                action.$1,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                action.$3,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _onQuickActionTap(String searchTerm, String categoryName) {
    _onUserInteraction();

    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }

    widget.controller.endSearchController.text = searchTerm;
    widget.controller.endFocusNode.requestFocus();
  }

  Widget _buildCompactRouteInfoOverlay() {
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: _horizontalMargin, vertical: _verticalMargin),
      child: CompactRouteWidget(
        destinationName: widget.controller.endSearchController.text,
        remainingDistance: widget.controller.remainingRouteDistance,
        totalDistance: widget.controller.routeDistance,
        remainingTime: widget.controller.remainingRouteTimeMinutes,
        totalTime: widget.controller.routeTimeMinutes,
        isNavigating: widget.controller.followGps &&
            widget.controller.currentGpsPosition != null,
        onEditPressed: () {
          _onUserInteraction();
          _scheduleStateTransition(SearchInterfaceState.expanded);
        },
        onClosePressed: () {
          _clearRouteAndReset();
        },
      ),
    );
  }

  Widget _buildMinimalExpandHint() {
    if (_currentState == SearchInterfaceState.navigationMode) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Bearbeiten',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
