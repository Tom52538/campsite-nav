// lib/widgets/simple_search_container.dart - ROOMPOT RESORT OPTIMIERT
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/camping_search_categories.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';

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

class _SimpleSearchContainerState extends State<SimpleSearchContainer>
    with TickerProviderStateMixin {
  late AnimationController _collapseController;
  late AnimationController _routeInfoController;
  late AnimationController _quickAccessController; // NEU: Quick-Access Animation
  late Animation<double> _collapseAnimation;
  late Animation<double> _routeInfoAnimation;
  late Animation<double> _quickAccessAnimation; // NEU

  @override
  void initState() {
    super.initState();

    _collapseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _routeInfoController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // NEU: Quick-Access Animation Controller
    _quickAccessController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );

    _routeInfoAnimation = CurvedAnimation(
      parent: _routeInfoController,
      curve: Curves.easeOutBack,
    );

    _quickAccessAnimation = CurvedAnimation(
      parent: _quickAccessController,
      curve: Curves.elasticOut,
    );

    // Starte Quick-Access Animation beim Load
    _quickAccessController.forward();
  }

  @override
  void didUpdateWidget(SimpleSearchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showRouteInfoAndFadeFields != oldWidget.showRouteInfoAndFadeFields) {
      if (widget.showRouteInfoAndFadeFields) {
        _collapseController.forward();
        _routeInfoController.forward();
      } else {
        _collapseController.reverse();
        _routeInfoController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _collapseController.dispose();
    _routeInfoController.dispose();
    _quickAccessController.dispose();
    super.dispose();
  }

  void _setStartLocation(SearchableFeature feature) {
    widget.controller.setStartLocation(feature);
    FocusScope.of(context).unfocus();
  }

  void _setDestination(SearchableFeature feature) {
    widget.controller.setDestination(feature);
    FocusScope.of(context).unfocus();
  }

  void _setCurrentAsStart() {
    widget.controller.setCurrentLocationAsStart();
    FocusScope.of(context).unfocus();
  }

  void _activateMapSelection(SearchFieldType fieldType) {
    widget.controller.activateMapSelection(fieldType);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tap on the map to select ${fieldType == SearchFieldType.start ? 'start' : 'destination'}.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _swapStartAndDestination() {
    widget.controller.swapStartAndDestination();
    FocusScope.of(context).unfocus();
  }

  void _expandSearchFields() {
    widget.controller.setRouteInfoAndFadeFields(false);
  }

  // ✅ NEU: Quick-Access Funktionen für Roompot Resort
  void _performQuickSearch(String searchTerm, String categoryName) {
    // Suche Features basierend auf dem Search Term
    final results = _filterFeaturesBySearchTerm(searchTerm);
    
    if (results.isNotEmpty) {
      // Zeige Snackbar mit Anzahl der Ergebnisse
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$categoryName: ${results.length} Optionen gefunden'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade600,
        ),
      );

      // Wenn nur ein Ergebnis: Automatisch als Ziel setzen
      if (results.length == 1) {
        _setDestination(results.first);
      } else {
        // Mehrere Ergebnisse: Fülle Suchfeld und zeige Optionen
        widget.controller.endSearchController.text = searchTerm;
        widget.controller.endFocusNode.requestFocus();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Keine $categoryName gefunden'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange.shade600,
        ),
      );
    }
  }

  List<SearchableFeature> _filterFeaturesBySearchTerm(String searchTerm) {
    return widget.allFeatures.where((feature) {
      final name = feature.name.toLowerCase();
      final type = feature.type.toLowerCase();
      final term = searchTerm.toLowerCase();
      
      return name.contains(term) || 
             type.contains(term) ||
             _matchesCategory(feature, searchTerm);
    }).toList();
  }

  bool _matchesCategory(SearchableFeature feature, String searchTerm) {
    final category = CampingSearchCategories.matchCategory(searchTerm);
    if (category == null) return false;
    
    return category.osmTypes.any((osmType) => 
        feature.type.toLowerCase().contains(osmType.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_collapseAnimation, _routeInfoAnimation, _quickAccessAnimation]),
      builder: (context, child) {
        return Stack(
          children: [
            // Full search fields (hidden when route is active)
            AnimatedOpacity(
              opacity: widget.showRouteInfoAndFadeFields ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                height: widget.showRouteInfoAndFadeFields ? 0.0 : null,
                child: widget.showRouteInfoAndFadeFields
                    ? const SizedBox.shrink()
                    : _buildFullSearchInterface(),
              ),
            ),

            // Compact route info (shown when route is active)
            if (widget.showRouteInfoAndFadeFields)
              AnimatedOpacity(
                opacity: _routeInfoAnimation.value,
                duration: const Duration(milliseconds: 300),
                child: Transform.scale(
                  scale: 0.8 + (0.2 * _routeInfoAnimation.value),
                  child: _buildCompactRouteDisplay(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFullSearchInterface() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ NEU: ROOMPOT QUICK-ACCESS BUTTONS
            AnimatedBuilder(
              animation: _quickAccessAnimation,
              child: _buildRoompotQuickAccess(),
              builder: (context, child) {
                return Transform.scale(
                  scale: _quickAccessAnimation.value,
                  child: Opacity(
                    opacity: _quickAccessAnimation.value,
                    child: child,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Start Input Row
            Row(
              children: [
                Expanded(
                  child: CampsiteSearchInput(
                    fieldType: SearchFieldType.start,
                    controller: widget.controller.startSearchController,
                    focusNode: widget.controller.startFocusNode,
                    allFeatures: widget.allFeatures,
                    onFeatureSelected: _setStartLocation,
                    onCurrentLocationTap: _setCurrentAsStart,
                    onMapSelectionTap: () =>
                        _activateMapSelection(SearchFieldType.start),
                  ),
                ),
                const SizedBox(width: 8),
                _buildLockButton(true),
              ],
            ),

            const SizedBox(height: 12),

            // Swap Button and Dividers
            Row(
              children: [
                const Expanded(child: Divider(height: 1, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.swap_vert, color: Colors.grey),
                    tooltip: 'Swap start and destination',
                    onPressed: _swapStartAndDestination,
                  ),
                ),
                const Expanded(child: Divider(height: 1, thickness: 1)),
              ],
            ),

            const SizedBox(height: 12),

            // Destination Input Row
            Row(
              children: [
                Expanded(
                  child: CampsiteSearchInput(
                    fieldType: SearchFieldType.destination,
                    controller: widget.controller.endSearchController,
                    focusNode: widget.controller.endFocusNode,
                    allFeatures: widget.allFeatures,
                    onFeatureSelected: _setDestination,
                    onMapSelectionTap: () =>
                        _activateMapSelection(SearchFieldType.destination),
                  ),
                ),
                const SizedBox(width: 8),
                _buildLockButton(false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEU: ROOMPOT RESORT QUICK-ACCESS BUTTONS
  Widget _buildRoompotQuickAccess() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.flash_on, color: Colors.blue.shade600, size: 18),
              const SizedBox(width: 6),
              Text(
                'Resort Quick-Access',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '214 POIs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Quick-Access Button Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAccessButton(
                icon: '🅿️',
                label: 'Parkplatz',
                subtitle: '81 Plätze',
                onTap: () => _performQuickSearch('parkplatz', 'Parkplätze'),
                color: Colors.indigo,
              ),
              _buildQuickAccessButton(
                icon: '👨‍👩‍👧‍👦',
                label: 'Familie',
                subtitle: '8 Spielplätze',
                onTap: () => _performQuickSearch('spielplatz', 'Familien-Bereiche'),
                color: Colors.pink,
              ),
              _buildQuickAccessButton(
                icon: '🏖️',
                label: 'Beach',
                subtitle: 'Wassersport',
                onTap: () => _performQuickSearch('beach pool', 'Strand & Pool'),
                color: Colors.cyan,
              ),
              _buildQuickAccessButton(
                icon: '🍽️',
                label: 'Essen',
                subtitle: 'Restaurants',
                onTap: () => _performQuickSearch('restaurant', 'Restaurants'),
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessButton({
    required String icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withAlpha(40),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Label
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Subtitle
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: color.shade600,
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
  }

  Widget _buildLockButton(bool isStart) {
    final isLocked = isStart ? widget.isStartLocked : widget.isDestinationLocked;
    final onPressed = isStart
        ? widget.controller.toggleStartLock
        : widget.controller.toggleDestinationLock;

    return Container(
      decoration: BoxDecoration(
        color: isLocked ? Colors.green.withAlpha(30) : Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLocked ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(
          isLocked ? Icons.lock : Icons.lock_open_outlined,
          color: isLocked ? Colors.green : Colors.grey,
        ),
        tooltip: isLocked
            ? "${isStart ? 'Start' : 'Destination'} locked"
            : "${isStart ? 'Start' : 'Destination'} unlocked",
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCompactRouteDisplay() {
    return CompactRouteWidget(
      destinationName: widget.controller.endSearchController.text,
      remainingDistance: widget.controller.remainingRouteDistance,
      totalDistance: widget.controller.routeDistance,
      remainingTime: widget.controller.remainingRouteTimeMinutes,
      totalTime: widget.controller.routeTimeMinutes,
      isNavigating: widget.controller.followGps && widget.controller.currentGpsPosition != null,
      onEditPressed: _expandSearchFields,
      onClosePressed: () {
        widget.controller.resetRouteAndNavigation();
        widget.controller.resetSearchFields();
      },
    );
  }
}
