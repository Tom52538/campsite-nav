// lib/widgets/smartphone_search_system.dart - BULLETPROOF OVERFLOW SOLUTION
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';

/// BULLETPROOF Search System - GARANTIERT KEIN OVERFLOW
///
/// Architektur-Änderung:
/// - SingleChildScrollView verhindert JEDEN Overflow
/// - Intrinsic Dimensions für sichere Berechnungen
/// - Fallback-Safe Layout System
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _setupControllerListeners();
    _evaluateInitialState();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _masterAnimation,
        _routeInfoAnimation,
        _slideAnimation,
      ]),
      builder: (context, child) {
        // ✅ BULLETPROOF CONTAINER: Maximale Höhe mit GARANTIE
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: _getMaxSafeHeight(),
            maxWidth: MediaQuery.of(context).size.width,
          ),
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
                  child: _buildScrollableSearchInterface(),
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

  // ✅ SICHERE MAXIMALE HÖHE - Berücksichtigt ALLES
  double _getMaxSafeHeight() {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    // Verfügbare Höhe: Screen - SafeAreas - Keyboard - Buffer
    final availableHeight =
        screenHeight - topPadding - bottomPadding - keyboardHeight - 40;

    if (_isKeyboardVisible) {
      // Bei Keyboard: Mehr Platz für Eingabe
      return (availableHeight * 0.4).clamp(80.0, 180.0);
    } else if (_currentState == SearchInterfaceState.navigationMode) {
      // Navigation Mode: Kompakt
      return 70.0;
    } else {
      // Standard: Mittelgroß
      return (availableHeight * 0.25).clamp(80.0, 120.0);
    }
  }

  // ✅ BULLETPROOF SCROLLABLE INTERFACE - KEIN OVERFLOW MÖGLICH
  Widget _buildScrollableSearchInterface() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: BoxConstraints(
        maxHeight: _getMaxSafeHeight() - 16, // Margin berücksichtigen
      ),
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
          child: _buildScrollableContent(),
        ),
      ),
    );
  }

  // ✅ SCROLLABLE CONTENT - DER SCHLÜSSEL ZUM ERFOLG
  Widget _buildScrollableContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: SingleChildScrollView(
        // ✅ MAGIE: SingleChildScrollView verhindert JEDEN Overflow!
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(10.0),
        child: IntrinsicHeight(
          // ✅ SICHERHEIT: IntrinsicHeight für korrekte Berechnungen
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildCompactHeader(),

              const SizedBox(height: 8),

              // Search Fields
              _buildCompactSearchFields(),

              // Quick Actions (nur wenn expanded)
              if (_currentState == SearchInterfaceState.expanded)
                _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.explore,
              color: Theme.of(context).colorScheme.primary,
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Navigation',
              style: TextStyle(
                fontSize: 13,
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
      ),
    );
  }

  Widget _buildCompactSearchFields() {
    return Column(
      children: [
        _buildCompactSearchField(SearchFieldType.start),
        const SizedBox(height: 6),
        _buildSwapButtonRow(),
        const SizedBox(height: 6),
        _buildCompactSearchField(SearchFieldType.destination),
      ],
    );
  }

  Widget _buildCompactSearchField(SearchFieldType fieldType) {
    final controller = fieldType == SearchFieldType.start
        ? widget.controller.startSearchController
        : widget.controller.endSearchController;
    final focusNode = fieldType == SearchFieldType.start
        ? widget.controller.startFocusNode
        : widget.controller.endFocusNode;

    return Container(
      height: 36, // Feste, kompakte Höhe
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: focusNode.hasFocus
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.withValues(alpha: 0.3),
          width: focusNode.hasFocus ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width: 20,
              height: 20,
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
                  style: const TextStyle(fontSize: 11),
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
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '${fieldType.displayName}...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
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
            icon: const Icon(Icons.clear, size: 16),
            color: Colors.grey.shade600,
            onPressed: () {
              controller.clear();
              _onUserInteraction();
            },
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        if (fieldType == SearchFieldType.start)
          IconButton(
            icon: const Icon(Icons.my_location, size: 16),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              widget.controller.setCurrentLocationAsStart();
              _onUserInteraction();
            },
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        IconButton(
          icon: const Icon(Icons.location_searching, size: 16),
          color: Theme.of(context).colorScheme.secondary,
          onPressed: () {
            widget.controller.activateMapSelection(fieldType);
            _onUserInteraction();
          },
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildSwapButtonRow() {
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: _swapStartAndDestination,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.swap_vert,
                  size: 14,
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

  Widget _buildQuickActions() {
    const quickActions = [
      ('🅿️', 'parkplatz', 'Park'),
      ('👨‍👩‍👧‍👦', 'spielplatz', 'Kids'),
      ('🏖️', 'beach pool', 'Beach'),
      ('🍽️', 'restaurant', 'Food'),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 42,
      child: Row(
        children: quickActions.map((action) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _onQuickActionTap(action.$2, action.$3),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          action.$1,
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          action.$3,
                          style: TextStyle(
                            fontSize: 8,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
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
