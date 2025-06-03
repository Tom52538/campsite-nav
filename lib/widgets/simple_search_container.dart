// lib/widgets/simple_search_container.dart - VOLLSTÄNDIG NEU & SMARTPHONE OPTIMIERT
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/search_types.dart'; // ✅ FIX: Eindeutiger Import
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

class _SimpleSearchContainerState extends State<SimpleSearchContainer> {
  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Delegiere an das neue SmartphoneSearchSystem
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

/// Development Helper für Testing verschiedener Search Modes
class SearchSystemTester extends StatefulWidget {
  final MapScreenController controller;
  final List<SearchableFeature> allFeatures;

  const SearchSystemTester({
    super.key,
    required this.controller,
    required this.allFeatures,
  });

  @override
  State<SearchSystemTester> createState() => _SearchSystemTesterState();
}

class _SearchSystemTesterState extends State<SearchSystemTester> {
  SearchContext _currentContext = SearchContext.guest;
  SearchInterfaceState _testState = SearchInterfaceState.expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Context Switcher
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.amber.shade100,
          child: Row(
            children: [
              const Text('Context: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<SearchContext>(
                value: _currentContext,
                onChanged: (context) {
                  if (context != null) {
                    setState(() {
                      _currentContext = context;
                    });
                  }
                },
                items: SearchContext.values.map((context) {
                  return DropdownMenuItem(
                    value: context,
                    child: Text(context.value),
                  );
                }).toList(),
              ),
              const SizedBox(width: 16),
              const Text('State: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<SearchInterfaceState>(
                value: _testState,
                onChanged: (state) {
                  if (state != null) {
                    setState(() {
                      _testState = state;
                    });
                    widget.controller.setSearchInterfaceState(state);
                  }
                },
                items: SearchInterfaceState.values.map((state) {
                  return DropdownMenuItem(
                    value: state,
                    child: Text(state.value),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        
        // Main Search System
        Expanded(
          child: SmartphoneSearchSystem(
            controller: widget.controller,
            allFeatures: widget.allFeatures,
            isStartLocked: widget.controller.isStartLocked,
            isDestinationLocked: widget.controller.isDestinationLocked,
            showRouteInfoAndFadeFields: widget.controller.showRouteInfoAndFadeFields,
            context: _currentContext,
          ),
        ),
      ],
    );
  }
}