// lib/widgets/smartphone_search_system.dart - ULTRA-COMPACT VERSION
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';

/// Premium Smartphone Search System - ULTRA-COMPACT VERSION
///
/// MISSION: MINIMALE Interface-Größe für MAXIMALE Karten-Sicht
///
/// FEATURES:
/// - Nur 15% der Bildschirmhöhe (statt 50%)
/// - Ultra-transparenter Hintergrund (95% durchsichtig)
/// - Kollabierbare Quick-Actions
/// - Instant Auto-Hide nach Route-Berechnung
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
    this.autoHideDelay = const Duration(milliseconds: 800), // Schneller!
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _routeInfoController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _masterAnimation = CurvedAnimation(
      parent: _masterController,
      curve: Curves.easeInOut,
    );

    _routeInfoAnimation = CurvedAnimation(
      parent: _routeInfoController,
      curve: Curves.easeInOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -2.0), // Noch weiter weg
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutQuart,
    ));

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
      // Sofortiges Auto-Hide für maximale Karten-Sicht
      Future.delayed(widget.autoHideDelay, () {
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
        _slideController.reverse();
        _fadeController.forward();
        _routeInfoController.reverse();
      case SearchInterfaceState.collapsed:
        _fadeController.forward();
        _routeInfoController.reverse();
      case SearchInterfaceState.hidden:
        _slideController.forward();
        _fadeController.reverse();
        _routeInfoController.reverse();
      case SearchInterfaceState.navigationMode:
        _slideController.forward();
        _fadeController.reverse();
        _routeInfoController.forward();
    }

    setState(() {});
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
        Future.delayed(const Duration(seconds: 1), () {
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
    Future.delayed(const Duration(seconds: 3), () {
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

  // ✅ ULTRA-KOMPAKTE Dimensionen
  double get _horizontalMargin => 6.0; // Minimiert
  double get _verticalMargin => 4.0; // Minimiert
  double get _cardPadding => 8.0; // Minimiert
  double get _headerFontSize => 12.0; // Kleiner
  double get _bodyFontSize => 10.0; // Kleiner

  // ✅ KRITISCH: Nur 15% der Bildschirmhöhe!
  double get _maxSearchInterfaceHeight => _screenHeight > 0
      ? (_screenHeight * 0.15)
          .clamp(80.0, 150.0) // Nur 15%! Min 80px, Max 150px
      : 120.0; // Fallback

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
        return SizedBox(
          width: _screenWidth > 0
              ? _screenWidth
              : MediaQuery.of(context).size.width,
          height: _maxSearchInterfaceHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ✅ ULTRA-KOMPAKTES Main Interface
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildUltraCompactInterface(),
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
                    child: _buildCompactRouteInfoOverlay(),
                  ),
                ),

              // Touch Area für Expansion
              if (_currentState != SearchInterfaceState.expanded)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 40, // Kleinere Touch Area
                  child: GestureDetector(
                    onTap: _onExpandRequest,
                    child: Container(
                      color: Colors.transparent,
                      child: _buildExpandHint(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ✅ ULTRA-KOMPAKTES INTERFACE - Nur das Nötigste!
  Widget _buildUltraCompactInterface() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _horizontalMargin,
        vertical: _verticalMargin,
      ),
      constraints: BoxConstraints(
        maxHeight: _maxSearchInterfaceHeight - (_verticalMargin * 2),
        maxWidth: _screenWidth > 0
            ? _screenWidth - (_horizontalMargin * 2)
            : double.infinity,
      ),
      decoration: BoxDecoration(
        // ✅ ULTRA-TRANSPARENZ: 95% durchsichtig!
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12.0), // Kleinere Rundung
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 0.5, // Dünnerer Rand
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), // Subtiler
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Weniger Blur
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05), // Fast transparent
            ),
            child: Padding(
              padding: EdgeInsets.all(_cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ MINI Header - Nur Essentials
                  _buildMiniHeader(),

                  const SizedBox(height: 4), // Minimal spacing

                  // ✅ EINZEILIGES Search Interface
                  _buildSingleLineSearchInterface(),

                  // ✅ Quick Actions NUR bei Expanded State
                  if (_currentState == SearchInterfaceState.expanded)
                    _buildMiniQuickActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniHeader() {
    return SizedBox(
      height: 20, // Sehr kompakt
      child: Row(
        children: [
          // Context Icon
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.explore,
              color: Theme.of(context).colorScheme.primary,
              size: 10,
            ),
          ),

          const SizedBox(width: 6),

          // Kompakter Text
          Expanded(
            child: Text(
              'Navigation',
              style: TextStyle(
                fontSize: _headerFontSize,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                height: 1.0,
              ),
            ),
          ),

          // POI Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '214',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ EINZEILIGES Search Interface - Start & Ziel nebeneinander
  Widget _buildSingleLineSearchInterface() {
    return Container(
      height: 36, // Sehr kompakt
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Start Field - 40% der Breite
          Expanded(
            flex: 4,
            child: _buildInlineSearchField(SearchFieldType.start),
          ),

          // Separator
          Container(
            width: 1,
            height: 20,
            color: Colors.grey.withValues(alpha: 0.3),
          ),

          // Ziel Field - 40% der Breite
          Expanded(
            flex: 4,
            child: _buildInlineSearchField(SearchFieldType.destination),
          ),

          // Actions - 20% der Breite
          Expanded(
            flex: 2,
            child: _buildInlineActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineSearchField(SearchFieldType fieldType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: TextField(
        controller: fieldType == SearchFieldType.start
            ? widget.controller.startSearchController
            : widget.controller.endSearchController,
        focusNode: fieldType == SearchFieldType.start
            ? widget.controller.startFocusNode
            : widget.controller.endFocusNode,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: fieldType == SearchFieldType.start ? 'Start' : 'Ziel',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
          ),
          prefixIcon: Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            child: Text(
              fieldType.emoji,
              style: const TextStyle(fontSize: 8),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 20,
            minHeight: 16,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (text) {
          // Bei Eingabe: Interface erweitern für Search Results
          if (text.isNotEmpty &&
              _currentState != SearchInterfaceState.expanded) {
            _scheduleStateTransition(SearchInterfaceState.expanded);
          }
        },
      ),
    );
  }

  Widget _buildInlineActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Swap Button
        GestureDetector(
          onTap: _swapStartAndDestination,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.swap_vert,
              size: 12,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  // ✅ MINI Quick Actions - nur wenn Expanded
  Widget _buildMiniQuickActions() {
    const quickActions = [
      ('🅿️', 'parkplatz', 'P'),
      ('👨‍👩‍👧‍👦', 'spielplatz', 'F'),
      ('🏖️', 'beach pool', 'B'),
      ('🍽️', 'restaurant', 'R'),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 4),
      height: 30, // Sehr kompakt
      child: Row(
        children: quickActions.map((action) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: GestureDetector(
                onTap: () => _onQuickActionTap(action.$2, action.$3),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        action.$1,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        action.$3,
                        style: TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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

  Widget _buildExpandHint() {
    if (_currentState == SearchInterfaceState.navigationMode) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 10,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
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
