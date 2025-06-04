// lib/widgets/smartphone_search_system.dart - TRANSPARENT OVERLAY VERSION - ZERO WARNINGS
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';

/// Premium Smartphone Search System - TRANSPARENT MAP-FRIENDLY VERSION
///
/// MISSION: Maximale Karten-Sicht mit funktionaler Suche
///
/// FEATURES:
/// - Semi-transparenter Hintergrund (Karte bleibt sichtbar)
/// - Kompakte Größe (nur 30% der Bildschirmhöhe)
/// - Auto-Hide nach Route-Berechnung
/// - Glasmorphism-Design für Premium Look
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
  late AnimationController _stateController;
  late AnimationController _routeInfoController;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  late Animation<double> _masterAnimation;
  late Animation<double> _stateAnimation;
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
    _stateController.dispose();
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

    _stateController = AnimationController(
      duration: const Duration(milliseconds: 350),
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

    _stateAnimation = CurvedAnimation(
      parent: _stateController,
      curve: PremiumCurves.material,
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
      end: const Offset(0, -1.5), // Weiter nach oben verschieben
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

    final oldState = _currentState;
    _currentState = newState;

    _executeStateTransition(oldState, newState);
  }

  void _executeStateTransition(
      SearchInterfaceState from, SearchInterfaceState to) {
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
    _stateController.reverse();
  }

  void _transitionToCollapsed() {
    _fadeController.forward();
    _routeInfoController.reverse();
    _stateController.animateTo(0.6);
  }

  void _transitionToHidden() {
    _slideController.forward();
    _fadeController.reverse();
    _routeInfoController.reverse();
    _stateController.forward();
  }

  void _transitionToNavigationMode() {
    _slideController.forward();
    _fadeController.reverse();
    _routeInfoController.forward();
    _stateController.forward();
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

  void _setCurrentLocationAsStart() {
    _onUserInteraction();
    widget.controller.setCurrentLocationAsStart();
    _dismissKeyboard();

    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }
  }

  void _activateMapSelection(SearchFieldType fieldType) {
    _onUserInteraction();
    widget.controller.activateMapSelection(fieldType);
    _dismissKeyboard();

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
    _dismissKeyboard();
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

  void _dismissKeyboard() {
    if (widget.controller.startFocusNode.hasFocus) {
      widget.controller.startFocusNode.unfocus();
    }
    if (widget.controller.endFocusNode.hasFocus) {
      widget.controller.endFocusNode.unfocus();
    }
  }

  // Responsive Design - KOMPAKTE WERTE FÜR WENIGER PLATZ
  double get _horizontalMargin => _isSmallScreen ? 8.0 : 12.0;
  double get _verticalMargin => _isSmallScreen ? 6.0 : 8.0;
  double get _cardPadding => _isSmallScreen ? 10.0 : 12.0;
  double get _inputHeight => _isSmallScreen ? 38.0 : 42.0; // REDUZIERT
  double get _headerFontSize => _isSmallScreen ? 13.0 : 14.0; // REDUZIERT
  double get _bodyFontSize => _isSmallScreen ? 11.0 : 12.0; // REDUZIERT

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _masterAnimation,
        _stateAnimation,
        _routeInfoAnimation,
        _fadeAnimation,
        _slideAnimation,
      ]),
      builder: (context, child) {
        return Stack(
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
                    child: _buildTransparentSearchInterface(),
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
                height: 60, // REDUZIERT
                child: GestureDetector(
                  onTap: _onExpandRequest,
                  child: Container(
                    color: Colors.transparent,
                    child: _buildMinimalExpandHint(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // HAUPT-WIDGET: Semi-transparentes Glasmorphism Design
  Widget _buildTransparentSearchInterface() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _horizontalMargin,
        vertical: _verticalMargin,
      ),
      decoration: BoxDecoration(
        // GLASMORPHISM EFFECT - Semi-transparent mit Blur
        color: Colors.white.withValues(alpha: 0.85), // 85% Transparenz
        borderRadius: BorderRadius.circular(16.0), // Weniger rund
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          // Subtiler Schatten
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
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Blur-Effekt
          child: Container(
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(alpha: 0.1), // Zusätzlicher Overlay
            ),
            child: Padding(
              padding: EdgeInsets.all(_cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // KOMPAKTER Context Header
                  _buildCompactContextualHeader(),

                  SizedBox(height: _verticalMargin),

                  // KOMPAKTE Search Input Rows
                  _buildCompactSearchInputRow(SearchFieldType.start),

                  SizedBox(height: _verticalMargin * 0.7), // Weniger Abstand

                  // MINI Swap Button
                  _buildMiniSwapButton(),

                  SizedBox(height: _verticalMargin * 0.7),

                  _buildCompactSearchInputRow(SearchFieldType.destination),

                  // KOMPAKTE Quick Access Section
                  if (_currentState == SearchInterfaceState.expanded)
                    _buildCompactQuickAccessSection(),
                ],
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
          padding: const EdgeInsets.all(6), // REDUZIERT
          decoration: BoxDecoration(
            color: contextColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            contextIcon,
            color: contextColor,
            size: 16, // REDUZIERT
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

        // KOMPAKTE POI Badge
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 3), // REDUZIERT
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Text(
            '214 POIs',
            style: TextStyle(
              fontSize: 10, // SEHR KLEIN
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSearchInputRow(SearchFieldType fieldType) {
    return Container(
      height: _inputHeight, // REDUZIERTE HÖHE
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7), // Semi-transparent
        borderRadius: BorderRadius.circular(10.0), // Weniger rund
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // KOMPAKTES Type Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  fieldType.emoji,
                  style: const TextStyle(fontSize: 10), // REDUZIERT
                ),
              ),
            ),
          ),

          // KOMPAKTES Text Input
          Expanded(
            child: TextField(
              controller: fieldType == SearchFieldType.start
                  ? widget.controller.startSearchController
                  : widget.controller.endSearchController,
              focusNode: fieldType == SearchFieldType.start
                  ? widget.controller.startFocusNode
                  : widget.controller.endFocusNode,
              style: TextStyle(
                fontSize: _isSmallScreen ? 13 : 14, // REDUZIERT
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: fieldType == SearchFieldType.start ? 'Start' : 'Ziel',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: _isSmallScreen ? 12 : 13, // REDUZIERT
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),

          // KOMPAKTE Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fieldType == SearchFieldType.start)
                _buildCompactButton(
                  Icons.my_location,
                  Colors.blue,
                  _setCurrentLocationAsStart,
                ),
              _buildCompactButton(
                Icons.location_searching,
                Colors.orange,
                () => _activateMapSelection(fieldType),
              ),
              _buildCompactLockButton(fieldType),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactButton(
      IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, // REDUZIERT
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16, // REDUZIERT
          ),
        ),
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
          width: 32, // REDUZIERT
          height: 32,
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
            size: 14, // REDUZIERT
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSwapButton() {
    return SizedBox(
      height: 20, // SEHR REDUZIERT
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
                  width: 30, // SEHR KLEIN
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
                    size: 16, // REDUZIERT
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
          // Minimaler Header
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

          // KOMPAKTE Quick Access Buttons
          SizedBox(
            height: 50, // REDUZIERT
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
                              // MINI Emoji
                              Text(
                                action.$1,
                                style:
                                    const TextStyle(fontSize: 16), // REDUZIERT
                              ),

                              const SizedBox(height: 2),

                              // MINI Label
                              Text(
                                action.$3,
                                style: TextStyle(
                                  fontSize: 9, // SEHR KLEIN
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
