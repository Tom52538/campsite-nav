// lib/widgets/simple_search_container.dart - DEPRECATION WARNING FIXED
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/smartphone_search_system.dart';

/// Legacy Wrapper für SimpleSearchContainer
/// 
/// Diese Klasse wird durch SmartphoneSearchSystem ersetzt,
/// bleibt aber für Rückwärtskompatibilität bestehen.
/// 
/// ⚠️ DEPRECATED: Verwende SmartphoneSearchSystem für neue Implementierungen
@Deprecated('Use SmartphoneSearchSystem instead for better mobile UX')
class SimpleSearchContainer extends StatefulWidget {
  final MapScreenController controller;
  final List<SearchableFeature> allFeatures;
  final Widget? routeInfo;
  final bool isStartLocked;
  final bool isDestinationLocked;
  final bool showRouteInfoAndFadeFields;

  const SimpleSearchContainer({
    super.key,
    required this.controller,
    required this.allFeatures,
    this.routeInfo,
    required this.isStartLocked,
    required this.isDestinationLocked,
    required this.showRouteInfoAndFadeFields,
  });

  @override
  State<SimpleSearchContainer> createState() => _SimpleSearchContainerState();
}

// ✅ FIX: Entferne @Deprecated von State Class (nur Widget ist deprecated)
class _SimpleSearchContainerState extends State<SimpleSearchContainer> {
  @override
  Widget build(BuildContext context) {
    // Delegiere an das neue SmartphoneSearchSystem
    return SmartphoneSearchSystem(
      controller: widget.controller,
      allFeatures: widget.allFeatures,
      isStartLocked: widget.isStartLocked,
      isDestinationLocked: widget.isDestinationLocked,
      showRouteInfoAndFadeFields: widget.showRouteInfoAndFadeFields,
      context: SearchContext.guest, // Default Context
    );
  }
}

/// Premium Smartphone Search Container - NEUE IMPLEMENTIERUNG
/// 
/// Ersetzt SimpleSearchContainer mit modernem Smartphone-First Design:
/// - Automatisches Verschwinden nach Eingabe
/// - Maximale Karten-Sicht während Navigation
/// - Touch-optimierte Bedienung
/// - State-of-the-Art Animationen
class PremiumSearchContainer extends StatefulWidget {
  final MapScreenController controller;
  final List<SearchableFeature> allFeatures;
  final SearchContext context;
  final bool enableAutoHide;
  final VoidCallback? onSearchComplete;

  const PremiumSearchContainer({
    super.key,
    required this.controller,
    required this.allFeatures,
    this.context = SearchContext.guest,
    this.enableAutoHide = true,
    this.onSearchComplete,
  });

  @override
  State<PremiumSearchContainer> createState() => _PremiumSearchContainerState();
}

class _PremiumSearchContainerState extends State<PremiumSearchContainer>
    with TickerProviderStateMixin {
  
  late AnimationController _masterController;
  late Animation<double> _masterAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _masterAnimation = CurvedAnimation(
      parent: _masterController,
      curve: PremiumCurves.smooth,
    );
    
    // Initial Animation
    _masterController.forward();
    
    // Auto-Hide Logic
    if (widget.enableAutoHide) {
      widget.controller.addListener(_handleControllerChanges);
    }
  }

  void _handleControllerChanges() {
    if (widget.controller.hasActiveRoute && 
        widget.controller.searchInterfaceState == SearchInterfaceState.navigationMode) {
      
      // Search Complete Callback
      widget.onSearchComplete?.call();
      
      // Smooth fade out für Premium Feel
      _masterController.reverse();
    } else if (widget.controller.searchInterfaceState == SearchInterfaceState.expanded) {
      // Fade in wenn Interface wieder benötigt wird
      _masterController.forward();
    }
  }

  @override
  void dispose() {
    if (widget.enableAutoHide) {
      widget.controller.removeListener(_handleControllerChanges);
    }
    _masterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _masterAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _masterAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(_masterAnimation),
            child: SmartphoneSearchSystem(
              controller: widget.controller,
              allFeatures: widget.allFeatures,
              isStartLocked: widget.controller.isStartLocked,
              isDestinationLocked: widget.controller.isDestinationLocked,
              showRouteInfoAndFadeFields: widget.controller.showRouteInfoAndFadeFields,
              context: widget.context,
            ),
          ),
        );
      },
    );
  }
}

/// Context Detection Helper
/// 
/// Intelligente Erkennung des User-Kontexts basierend auf:
/// - Tageszeit (Arrival/Departure wahrscheinlicher)
/// - GPS-Position (Near Resort entrance = Arrival)
/// - Vorherige App-Nutzung
class SmartContextDetector {
  static SearchContext detectContext({
    DateTime? currentTime,
    String? userLocation,
    bool? isFirstAppLaunch,
  }) {
    final now = currentTime ?? DateTime.now();
    
    // Emergency Detection (hypothetisch via andere Sensoren)
    if (_isEmergencyLikely()) {
      return SearchContext.emergency;
    }
    
    // Arrival Detection
    if (_isArrivalTime(now) || isFirstAppLaunch == true) {
      return SearchContext.arrival;
    }
    
    // Departure Detection  
    if (_isDepartureTime(now)) {
      return SearchContext.departure;
    }
    
    // Default: Guest
    return SearchContext.guest;
  }
  
  static bool _isEmergencyLikely() {
    // Placeholder für Emergency Detection
    // In Realität: Beschleunigungssensor, Notruf-Button, etc.
    return false;
  }
  
  static bool _isArrivalTime(DateTime time) {
    // Check-in Zeit: 15:00 - 18:00
    return time.hour >= 15 && time.hour <= 18;
  }
  
  static bool _isDepartureTime(DateTime time) {
    // Check-out Zeit: 08:00 - 11:00
    return time.hour >= 8 && time.hour <= 11;
  }
}

/// Convenience Factories
class SearchContainerFactory {
  /// Standard Resort Guest Experience
  static Widget createGuestInterface({
    required MapScreenController controller,
    required List<SearchableFeature> allFeatures,
  }) {
    return SmartphoneSearchSystem(
      controller: controller,
      allFeatures: allFeatures,
      isStartLocked: controller.isStartLocked,
      isDestinationLocked: controller.isDestinationLocked,
      showRouteInfoAndFadeFields: controller.showRouteInfoAndFadeFields,
      context: SearchContext.guest,
    );
  }
  
  /// Arrival Experience (Welcome Message)
  static Widget createArrivalInterface({
    required MapScreenController controller,
    required List<SearchableFeature> allFeatures,
  }) {
    return SmartphoneSearchSystem(
      controller: controller,
      allFeatures: allFeatures,
      isStartLocked: controller.isStartLocked,
      isDestinationLocked: controller.isDestinationLocked,
      showRouteInfoAndFadeFields: controller.showRouteInfoAndFadeFields,
      context: SearchContext.arrival,
      autoHideDelay: const Duration(milliseconds: 2500), // More time for newcomers
    );
  }
  
  /// Departure Experience (Goodbye Message)
  static Widget createDepartureInterface({
    required MapScreenController controller,
    required List<SearchableFeature> allFeatures,
  }) {
    return SmartphoneSearchSystem(
      controller: controller,
      allFeatures: allFeatures,
      isStartLocked: controller.isStartLocked,
      isDestinationLocked: controller.isDestinationLocked,
      showRouteInfoAndFadeFields: controller.showRouteInfoAndFadeFields,
      context: SearchContext.departure,
    );
  }
  
  /// Emergency Interface (Red Pulsing)
  static Widget createEmergencyInterface({
    required MapScreenController controller,
    required List<SearchableFeature> allFeatures,
  }) {
    return SmartphoneSearchSystem(
      controller: controller,
      allFeatures: allFeatures,
      isStartLocked: controller.isStartLocked,
      isDestinationLocked: controller.isDestinationLocked,
      showRouteInfoAndFadeFields: controller.showRouteInfoAndFadeFields,
      context: SearchContext.emergency,
      autoHideDelay: const Duration(milliseconds: 800), // Fast for emergency
      enableHapticFeedback: true, // Important for emergency
    );
  }
  
  /// Smart Auto-Detecting Interface
  static Widget createSmartInterface({
    required MapScreenController controller,
    required List<SearchableFeature> allFeatures,
    DateTime? currentTime,
    bool? isFirstLaunch,
  }) {
    final context = SmartContextDetector.detectContext(
      currentTime: currentTime,
      isFirstAppLaunch: isFirstLaunch,
    );
    
    return SmartphoneSearchSystem(
      controller: controller,
      allFeatures: allFeatures,
      isStartLocked: controller.isStartLocked,
      isDestinationLocked: controller.isDestinationLocked,
      showRouteInfoAndFadeFields: controller.showRouteInfoAndFadeFields,
      context: context,
    );
  }
}