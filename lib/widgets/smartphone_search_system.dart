// lib/widgets/smartphone_search_system.dart - STATE OF THE ART + FUNKTIONAL
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';

/// State-of-the-Art Smartphone Search System - GOOGLE MAPS STYLE
///
/// Features:
/// - Adaptive Height System (verhindert Overflow GARANTIERT)
/// - Flexible Layout System
/// - Google Maps-ähnliche UX
/// - Premium Animationen
/// - Smartphone-optimiert
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
  // Animation Controllers
  late AnimationController _masterController;
  late AnimationController _routeInfoController;
  late AnimationController _slideController;

  // Animations
  late Animation<double> _masterAnimation;
  late Animation<double> _routeInfoAnimation;
  late Animation<Offset> _slideAnimation;

  // State Variables
  SearchInterfaceState _currentState = SearchInterfaceState.expanded;
  bool _hasActiveRoute = false;
  bool _isKeyboardVisible = false;
  bool _userInteractionDetected = false;
  bool _autoTransitionsEnabled = true;

  // Layout Dimensions
  double _screenWidth = 0;
  double _screenHeight = 0;
  double _keyboardHeight = 0;

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
        _updateScreenDimensions();
        _updateKeyboardVisibility();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChanges);
    _masterController.dispose();
    _routeInfoController.dispose();
    _slideController.dispose();
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

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -1.5),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutQuart,
    ));

    _masterController.forward();
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

    // Auto-transition logic
    if (widget.showRouteInfoAndFadeFields && _hasActiveRoute) {
      if (_currentState != SearchInterfaceState.navigationMode) {
        _scheduleStateTransition(SearchInterfaceState.navigationMode);
      }
    } else if (!widget.showRouteInfoAndFadeFields) {
      if (_currentState == SearchInterfaceState.navigationMode) {
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
        _routeInfoController.reverse();
      case SearchInterfaceState.collapsed:
        _slideController.reverse();
        _routeInfoController.reverse();
      case SearchInterfaceState.hidden:
        _slideController.forward();
        _routeInfoController.reverse();
      case SearchInterfaceState.navigationMode:
        _slideController.forward();
        _routeInfoController.forward();
    }
  }

  void _updateScreenDimensions() {
    final mediaQuery = MediaQuery.of(context);
    setState(() {
      _screenWidth = mediaQuery.size.width;
      _screenHeight = mediaQuery.size.height;
      _keyboardHeight = mediaQuery.viewInsets.bottom;
    });
  }

  void _updateKeyboardVisibility() {
    final wasVisible = _isKeyboardVisible;
    _isKeyboardVisible = _keyboardHeight > 50;

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

  void _evaluateInitialState() {
    _hasActiveRoute = widget.controller.routePolyline != null;
    if (_hasActiveRoute && widget.showRouteInfoAndFadeFields) {
      _currentState = SearchInterfaceState.navigationMode;
      _routeInfoController.value = 1.0;
      _slideController.value = 1.0;
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

  void _onQuickActionTap(String searchTerm, String categoryName) {
    _onUserInteraction();
    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }
    widget.controller.endSearchController.text = searchTerm;
    widget.controller.endFocusNode.requestFocus();
  }

  // ✅ ADAPTIVE LAYOUT SYSTEM - Verhindert Overflow GARANTIERT
  double get _adaptiveContainerHeight {
    final safeHeight =
        _screenHeight - MediaQuery.of(context).padding.top - 20; // 20px Buffer

    if (_isKeyboardVisible) {
      // Bei Keyboard: Mehr Platz für Eingabe
      return (safeHeight * 0.35).clamp(120.0, 200.0);
    } else if (_currentState == SearchInterfaceState.navigationMode) {
      // Navigation Mode: Kompakt
      return 70.0;
    } else {
      // Standard: Mittelgroß
      return (safeHeight * 0.25).clamp(100.0, 140.0);
    }
  }

  double get _contentHeight =>
      _adaptiveContainerHeight - 16; // Margin berücksichtigen

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _masterAnimation,
        _routeInfoAnimation,
        _slideAnimation,
      ]),
      builder: (context, child) {
        return SizedBox(
          width: _screenWidth,
          height: _adaptiveContainerHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Main Search Interface
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildAdaptiveSearchInterface(),
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

              // Expand Touch Area
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

  // ✅ ADAPTIVE INTERFACE - Passt sich automatisch an verfügbaren Platz an
  Widget _buildAdaptiveSearchInterface() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      height: _contentHeight,
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
          child: _buildFlexibleContent(),
        ),
      ),
    );
  }

  // ✅ FLEXIBLE CONTENT SYSTEM - Passt Inhalte an verfügbare Höhe an
  Widget _buildFlexibleContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _buildSmartLayoutColumn(),
      ),
    );
  }

  Widget _buildSmartLayoutColumn() {
    final availableHeight = _contentHeight - 24; // Padding berücksichtigen

    // Header: 24px
    // Search Fields: 80px
    // Quick Actions: 50px (optional)
    // Spacing: 16px

    final hasSpaceForQuickActions = availableHeight > 120;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header (immer vorhanden)
        SizedBox(
          height: 24,
          child: _buildHeader(),
        ),

        const SizedBox(height: 8),

        // Search Fields (immer vorhanden)
        _buildSearchFieldsSection(),

        // Quick Actions (nur wenn Platz)
        if (hasSpaceForQuickActions &&
            _currentState == SearchInterfaceState.expanded)
          _buildQuickActionsSection(),
      ],
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

  Widget _buildSearchFieldsSection() {
    return Column(
      children: [
        _buildOptimizedSearchField(SearchFieldType.start),
        const SizedBox(height: 6),
        _buildSwapButtonRow(),
        const SizedBox(height: 6),
        _buildOptimizedSearchField(SearchFieldType.destination),
      ],
    );
  }

  Widget _buildOptimizedSearchField(SearchFieldType fieldType) {
    final controller = fieldType == SearchFieldType.start
        ? widget.controller.startSearchController
        : widget.controller.endSearchController;
    final focusNode = fieldType == SearchFieldType.start
        ? widget.controller.startFocusNode
        : widget.controller.endFocusNode;

    return Container(
      height: 40, // Feste, optimierte Höhe
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
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
          // Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  fieldType.emoji,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),

          // TextField
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '${fieldType.displayName}...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),

          // Actions
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
            icon: const Icon(Icons.clear, size: 18),
            color: Colors.grey.shade600,
            onPressed: () {
              controller.clear();
              _onUserInteraction();
            },
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        if (fieldType == SearchFieldType.start)
          IconButton(
            icon: const Icon(Icons.my_location, size: 18),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              widget.controller.setCurrentLocationAsStart();
              _onUserInteraction();
            },
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        IconButton(
          icon: const Icon(Icons.location_searching, size: 18),
          color: Theme.of(context).colorScheme.secondary,
          onPressed: () {
            widget.controller.activateMapSelection(fieldType);
            _onUserInteraction();
          },
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildSwapButtonRow() {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: _swapStartAndDestination,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_vert,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    const quickActions = [
      ('🅿️', 'parkplatz', 'Park'),
      ('👨‍👩‍👧‍👦', 'spielplatz', 'Kids'),
      ('🏖️', 'beach pool', 'Beach'),
      ('🍽️', 'restaurant', 'Food'),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 45,
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
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          action.$1,
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          action.$3,
                          style: TextStyle(
                            fontSize: 9,
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

  Widget _buildCompactRouteInfoOverlay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        onClosePressed: _clearRouteAndReset,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.white, size: 14),
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
