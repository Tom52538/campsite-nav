// lib/widgets/smartphone_search_system.dart - STATE-OF-THE-ART SMARTPHONE-FIRST NAVIGATION
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/camping_search_categories.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';

/// Premium Smartphone Search System - STATE-OF-THE-ART ARCHITECTURE
/// 
/// MISSION: Nach Eingabe verschwinden → Maximale Karten-Sicht für Resort-Gäste
/// 
/// FEATURES:
/// - 4 Intelligence States: expanded, collapsed, hidden, navigation
/// - Auto-Transition nach Route-Berechnung
/// - Context-Aware für Arrival/Departure/Emergency/Guest
/// - Premium Animationen mit Haptic Feedback
/// - Touch-optimiert für One-handed Operation
/// - Accessibility Excellence (WCAG AA)
/// - Zero-Warnings Code Quality
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
  
  // Animation Controllers für Premium Feel
  late AnimationController _masterController;
  late AnimationController _stateController;
  late AnimationController _routeInfoController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  
  // Animations für verschiedene Übergänge
  late Animation<double> _masterAnimation;
  late Animation<double> _stateAnimation;
  late Animation<double> _routeInfoAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  // State Management
  SearchInterfaceState _currentState = SearchInterfaceState.expanded;
  SearchInterfaceState _previousState = SearchInterfaceState.expanded;
  bool _hasActiveRoute = false;
  bool _isKeyboardVisible = false;
  bool _userInteractionDetected = false;
  bool _autoTransitionsEnabled = true;
  
  // Performance & UX Tracking
  DateTime? _lastStateChange;
  DateTime? _lastUserInteraction;
  int _transitionCount = 0;
  
  // Responsive Design
  double _screenWidth = 0;
  double _screenHeight = 0;
  bool _isSmallScreen = false;
  bool _isLandscape = false;
  EdgeInsets _safeArea = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _setupControllerListeners();
    _evaluateInitialState();
    _logSystemInitialization();
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

  void _initializeAnimations() {
    // Master Controller für Overall System State
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // State Controller für Interface Transitions
    _stateController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    
    // Route Info Controller für Navigation Overlay
    _routeInfoController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Fade Controller für Smooth Visibility Changes
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    
    // Slide Controller für Slide Transitions
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Pulse Controller für Attention-grabbing Effects
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Configure Animations with Premium Curves
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
      end: const Offset(0, -1.2),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: PremiumCurves.snap,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(_masterAnimation);
    
    // Start with forward animation
    _masterController.forward();
    _fadeController.forward();
  }

  void _setupControllerListeners() {
    widget.controller.addListener(_handleControllerChanges);
    
    // Pulse animation repeating
    _pulseController.repeat(reverse: true);
  }

  void _handleControllerChanges() {
    final wasActiveRoute = _hasActiveRoute;
    _hasActiveRoute = widget.controller.routePolyline != null;
    
    // Route State Changes
    if (!wasActiveRoute && _hasActiveRoute) {
      _onRouteCalculated();
    } else if (wasActiveRoute && !_hasActiveRoute) {
      _onRouteCleared();
    }
    
    // Interface State Changes
    if (widget.showRouteInfoAndFadeFields != (_currentState == SearchInterfaceState.navigationMode)) {
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
    
    _logEvent('Route calculated - initiating smart transition');
    
    if (widget.enableSmartTransitions && _autoTransitionsEnabled) {
      // Smart delay based on user context
      Duration delay = widget.autoHideDelay;
      
      switch (widget.context) {
        case SearchContext.emergency:
          delay = const Duration(milliseconds: 500); // Fast for emergency
          break;
        case SearchContext.arrival:
          delay = const Duration(milliseconds: 2000); // More time for newcomers
          break;
        default:
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
    _logEvent('Route cleared - returning to expanded state');
    _scheduleStateTransition(SearchInterfaceState.expanded);
  }

  void _scheduleStateTransition(SearchInterfaceState newState) {
    if (_currentState == newState) return;
    
    _logStateTransition(_currentState, newState);
    
    final oldState = _currentState;
    _previousState = _currentState;
    _currentState = newState;
    _lastStateChange = DateTime.now();
    _transitionCount++;
    
    // Execute animation sequence
    _executeStateTransition(oldState, newState);
  }

  void _executeStateTransition(SearchInterfaceState from, SearchInterfaceState to) {
    switch (to) {
      case SearchInterfaceState.expanded:
        _transitionToExpanded();
        break;
      case SearchInterfaceState.collapsed:
        _transitionToCollapsed();
        break;
      case SearchInterfaceState.hidden:
        _transitionToHidden();
        break;
      case SearchInterfaceState.navigationMode:
        _transitionToNavigationMode();
        break;
    }
    
    setState(() {}); // Trigger rebuild with new state
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
    _stateController.animateTo(0.5);
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
      _logEvent('Keyboard visibility changed: $_isKeyboardVisible');
      
      if (_isKeyboardVisible) {
        // Force expanded state when keyboard is visible
        _scheduleStateTransition(SearchInterfaceState.expanded);
        _userInteractionDetected = true;
      } else {
        // Reset user interaction flag after keyboard hide
        Future.delayed(const Duration(seconds: 2), () {
          _userInteractionDetected = false;
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
      _isLandscape = _screenWidth > _screenHeight;
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
    _lastUserInteraction = DateTime.now();
    
    // Disable auto-transitions temporarily
    _autoTransitionsEnabled = false;
    Future.delayed(const Duration(seconds: 5), () {
      _autoTransitionsEnabled = true;
    });
  }

  void _onExpandRequest() {
    _onUserInteraction();
    _scheduleStateTransition(SearchInterfaceState.expanded);
    
    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  void _onCollapseRequest() {
    _onUserInteraction();
    _scheduleStateTransition(SearchInterfaceState.collapsed);
  }

  void _onHideRequest() {
    _onUserInteraction();
    _scheduleStateTransition(SearchInterfaceState.hidden);
  }

  // Feature Selection Handlers
  void _setStartLocation(SearchableFeature feature) {
    _onUserInteraction();
    widget.controller.setStartLocation(feature);
    _dismissKeyboard();
    
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    
    // Smart transition after selection
    if (widget.controller.endSearchController.text.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && widget.controller.hasActiveRoute) {
          _scheduleStateTransition(SearchInterfaceState.collapsed);
        }
      });
    }
  }

  void _setDestination(SearchableFeature feature) {
    _onUserInteraction();
    widget.controller.setDestination(feature);
    _dismissKeyboard();
    
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    
    // Smart transition after selection
    if (widget.controller.startSearchController.text.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && widget.controller.hasActiveRoute) {
          _scheduleStateTransition(SearchInterfaceState.collapsed);
        }
      });
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
    
    // Hide interface for map selection
    _scheduleStateTransition(SearchInterfaceState.hidden);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tippen Sie auf die Karte um ${fieldType.displayName} zu wählen',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: _safeArea.bottom + 80,
          left: 16,
          right: 16,
        ),
        action: SnackBarAction(
          label: 'Abbrechen',
          textColor: Colors.white,
          onPressed: () {
            widget.controller.handleMapTapForSelection(const LatLng(0, 0));
            _scheduleStateTransition(SearchInterfaceState.expanded);
          },
        ),
      ),
    );
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

  // Responsive Design Helpers
  double get _horizontalMargin => _isSmallScreen ? 12.0 : 16.0;
  double get _verticalMargin => _isSmallScreen ? 8.0 : 12.0;
  double get _cardPadding => _isSmallScreen ? 12.0 : 16.0;
  double get _headerFontSize => _isSmallScreen ? 14.0 : 16.0;
  double get _bodyFontSize => _isSmallScreen ? 12.0 : 14.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
              children: [
                // Main Search Interface
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
                        child: _buildMainSearchInterface(),
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
                        scale: Tween<double>(begin: 0.9, end: 1.0).animate(_routeInfoAnimation),
                        child: _buildRouteInfoOverlay(),
                      ),
                    ),
                  ),
                
                // Gesture Detection for Expansion
                if (_currentState != SearchInterfaceState.expanded)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: GestureDetector(
                      onTap: _onExpandRequest,
                      child: Container(
                        color: Colors.transparent,
                        child: _buildExpandHint(),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMainSearchInterface() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _horizontalMargin,
        vertical: _verticalMargin,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.08 * 255).round()),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Context-Aware Header
            _buildContextualHeader(),
            
            SizedBox(height: _verticalMargin),
            
            // Start Input Row
            _buildSearchInputRow(SearchFieldType.start),
            
            SizedBox(height: _verticalMargin),
            
            // Elegant Swap Button
            _buildSwapButton(),
            
            SizedBox(height: _verticalMargin),
            
            // Destination Input Row
            _buildSearchInputRow(SearchFieldType.destination),
            
            // Lock Status Indicator
            if (widget.isStartLocked || widget.isDestinationLocked)
              _buildLockStatusIndicator(),
            
            // Quick Access Section
            if (_currentState == SearchInterfaceState.expanded)
              _buildQuickAccessSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildContextualHeader() {
    String contextMessage = '';
    IconData contextIcon = Icons.navigation;
    Color contextColor = Theme.of(context).colorScheme.primary;
    
    switch (widget.context) {
      case SearchContext.arrival:
        contextMessage = 'Willkommen im Roompot Beach Resort!';
        contextIcon = Icons.celebration;
        contextColor = Colors.green;
        break;
      case SearchContext.departure:
        contextMessage = 'Gute Reise! Bis zum nächsten Mal.';
        contextIcon = Icons.flight_takeoff;
        contextColor = Colors.orange;
        break;
      case SearchContext.emergency:
        contextMessage = 'Notfall-Navigation';
        contextIcon = Icons.emergency;
        contextColor = Colors.red;
        break;
      case SearchContext.guest:
      default:
        contextMessage = 'Wohin möchten Sie im Resort?';
        contextIcon = Icons.explore;
        break;
    }
    
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.context == SearchContext.emergency 
                  ? _pulseAnimation.value 
                  : 1.0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: contextColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  contextIcon,
                  color: contextColor,
                  size: _isSmallScreen ? 18 : 20,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Text(
            contextMessage,
            style: TextStyle(
              fontSize: _headerFontSize,
              fontWeight: FontWeight.w600,
              color: contextColor,
              height: 1.2,
            ),
          ),
        ),
        
        // Resort POI Count Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withAlpha(40),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '214 POIs',
                style: TextStyle(
                  fontSize: _isSmallScreen ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchInputRow(SearchFieldType fieldType) {
    return Row(
      children: [
        Expanded(
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
            showQuickAccess: false, // Handled separately
          ),
        ),
        const SizedBox(width: 12),
        _buildLockButton(fieldType),
      ],
    );
  }

  Widget _buildLockButton(SearchFieldType fieldType) {
    final isLocked = fieldType == SearchFieldType.start 
        ? widget.isStartLocked 
        : widget.isDestinationLocked;
    
    final onPressed = fieldType == SearchFieldType.start
        ? widget.controller.toggleStartLock
        : widget.controller.toggleDestinationLock;
    
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          _onUserInteraction();
          if (widget.enableHapticFeedback) {
            HapticFeedback.selectionClick();
          }
          onPressed();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: SmartphoneTouchTargets.comfortableSize,
          height: SmartphoneTouchTargets.comfortableSize,
          decoration: BoxDecoration(
            color: isLocked 
                ? Colors.green.withAlpha(30) 
                : Colors.grey.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLocked ? Colors.green : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Icon(
            isLocked ? Icons.lock : Icons.lock_open_outlined,
            color: isLocked ? Colors.green : Colors.grey.shade600,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSwapButton() {
    return SizedBox(
      height: SmartphoneTouchTargets.minimumSize,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade300,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(25),
              child: InkWell(
                onTap: _swapStartAndDestination,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade50, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade300,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockStatusIndicator() {
    return Container(
      margin: EdgeInsets.only(top: _verticalMargin),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            size: 16,
            color: Colors.green.shade700,
          ),
          const Size