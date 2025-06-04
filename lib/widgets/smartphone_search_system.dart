// lib/widgets/smartphone_search_system.dart - VOLLSTÄNDIG KORRIGIERT
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';

/// Premium Smartphone Search System - FUNKTIONSFÄHIGE VERSION
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
      end: const Offset(0, -2.0),
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

  double get _horizontalMargin => 8.0;
  double get _verticalMargin => 6.0;
  double get _cardPadding => 12.0;
  double get _headerFontSize => 14.0;

  double get _maxSearchInterfaceHeight =>
      _screenHeight > 0 ? (_screenHeight * 0.25).clamp(120.0, 200.0) : 150.0;

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
              // Main Interface
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildFunctionalInterface(),
                  ),
                ),
              ),

              // Route Info Overlay
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
                  height: 60,
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

  // ✅ FUNKTIONALE INTERFACE - Größer und Touch-freundlich
  Widget _buildFunctionalInterface() {
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
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Padding(
              padding: EdgeInsets.all(_cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildSearchFields(),
                  if (_currentState == SearchInterfaceState.expanded)
                    _buildQuickActions(),
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
              fontSize: _headerFontSize,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${widget.allFeatures.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  // ✅ GETRENNTE SEARCH FIELDS - Funktional und Touch-freundlich
  Widget _buildSearchFields() {
    return Column(
      children: [
        _buildSeparateSearchField(SearchFieldType.start),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Divider()),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                onTap: _swapStartAndDestination,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 8),
        _buildSeparateSearchField(SearchFieldType.destination),
      ],
    );
  }

  Widget _buildSeparateSearchField(SearchFieldType fieldType) {
    final controller = fieldType == SearchFieldType.start
        ? widget.controller.startSearchController
        : widget.controller.endSearchController;
    final focusNode = fieldType == SearchFieldType.start
        ? widget.controller.startFocusNode
        : widget.controller.endFocusNode;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: focusNode.hasFocus
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.withValues(alpha: 0.3),
          width: focusNode.hasFocus ? 2.0 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  fieldType.emoji,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '${fieldType.displayName} eingeben...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),
          _buildFieldActions(fieldType, controller),
        ],
      ),
    );
  }

  Widget _buildFieldActions(
      SearchFieldType fieldType, TextEditingController controller) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            color: Colors.grey.shade600,
            onPressed: () {
              controller.clear();
              _onUserInteraction();
            },
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        if (fieldType == SearchFieldType.start)
          IconButton(
            icon: const Icon(Icons.my_location, size: 20),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              widget.controller.setCurrentLocationAsStart();
              _onUserInteraction();
            },
            tooltip: 'Aktueller Standort',
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.location_searching, size: 20),
          color: Theme.of(context).colorScheme.secondary,
          onPressed: () {
            widget.controller.activateMapSelection(fieldType);
            _onUserInteraction();
          },
          tooltip: 'Auf Karte wählen',
          constraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    const quickActions = [
      ('🅿️', 'parkplatz', 'Parkplatz'),
      ('👨‍👩‍👧‍👦', 'spielplatz', 'Familie'),
      ('🏖️', 'beach pool', 'Beach'),
      ('🍽️', 'restaurant', 'Essen'),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 60,
      child: Row(
        children: quickActions.map((action) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _onQuickActionTap(action.$2, action.$3),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          action.$1,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action.$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
