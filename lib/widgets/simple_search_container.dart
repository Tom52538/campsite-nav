// lib/widgets/simple_search_container.dart - SMARTPHONE OPTIMIERT & COLOR FIXED
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/camping_search_categories.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/widgets/campsite_search_input.dart';
import 'package:camping_osm_navi/widgets/compact_route_widget.dart';
import 'package:camping_osm_navi/models/search_types.dart';

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
  late AnimationController _quickAccessController;
  late Animation<double> _collapseAnimation;
  late Animation<double> _routeInfoAnimation;
  late Animation<double> _quickAccessAnimation;

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

  void _performQuickSearch(String searchTerm, String categoryName) {
    final results = _filterFeaturesBySearchTerm(searchTerm);
    
    if (results.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$categoryName: ${results.length} gefunden'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade600,
        ),
      );

      if (results.length == 1) {
        _setDestination(results.first);
      } else {
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
    // ✅ SMARTPHONE-OPTIMIERTE MARGINS
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalMargin = screenWidth < 360 ? 12.0 : 16.0; // Kleiner margin für kleine Screens
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 16.0),
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
        padding: EdgeInsets.all(screenWidth < 360 ? 12.0 : 16.0), // Responsive padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ RESPONSIVE QUICK-ACCESS BUTTONS
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

            // ✅ MOBILE-OPTIMIERTER SWAP BUTTON
            _buildMobileSwapButton(),

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

  // ✅ SMARTPHONE-OPTIMIERTE QUICK-ACCESS BUTTONS
  Widget _buildRoompotQuickAccess() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375; // iPhone SE und ähnliche
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          // ✅ KOMPAKTER HEADER
          Row(
            children: [
              Icon(Icons.flash_on, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isSmallScreen ? 'Quick-Access' : 'Resort Quick-Access',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
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
          ),
          
          const SizedBox(height: 8),
          
          // ✅ RESPONSIVE BUTTON LAYOUT
          isSmallScreen ? _buildSmallScreenButtons() : _buildNormalScreenButtons(),
        ],
      ),
    );
  }

  // ✅ LAYOUT FÜR KLEINE SCREENS (2x2 Grid)
  Widget _buildSmallScreenButtons() {
    return Column(
      children: [
        // Erste Reihe
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessButton(
                icon: '🅿️',
                label: 'Parkplatz',
                subtitle: '81x',
                onTap: () => _performQuickSearch('parkplatz', 'Parkplätze'),
                color: Colors.indigo,
                isCompact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickAccessButton(
                icon: '👨‍👩‍👧‍👦',
                label: 'Familie',
                subtitle: '8x',
                onTap: () => _performQuickSearch('spielplatz', 'Familien-Bereiche'),
                color: Colors.pink,
                isCompact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Zweite Reihe
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessButton(
                icon: '🏖️',
                label: 'Beach',
                subtitle: 'Pool',
                onTap: () => _performQuickSearch('beach pool', 'Strand & Pool'),
                color: Colors.cyan,
                isCompact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickAccessButton(
                icon: '🍽️',
                label: 'Essen',
                subtitle: 'Food',
                onTap: () => _performQuickSearch('restaurant', 'Restaurants'),
                color: Colors.orange,
                isCompact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ✅ LAYOUT FÜR NORMALE SCREENS (1x4 Row)
  Widget _buildNormalScreenButtons() {
    return Row(
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
    );
  }

  Widget _buildQuickAccessButton({
    required String icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    bool isCompact = false,
  }) {
    // ✅ ENHANCED TOUCH TARGETS - Min 48px für Android, 44px für iOS
    final minSize = isCompact ? 44.0 : 48.0;
    
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 2.0 : 4.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(minHeight: minSize),
              padding: EdgeInsets.symmetric(
                vertical: isCompact ? 8 : 12, 
                horizontal: isCompact ? 4 : 8
              ),
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
                  // ✅ RESPONSIVE ICON SIZE
                  Container(
                    width: isCompact ? 28 : 32,
                    height: isCompact ? 28 : 32,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: TextStyle(fontSize: isCompact ? 16 : 18),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: isCompact ? 4 : 6),
                  
                  // ✅ RESPONSIVE TEXT SIZE - FIXED: MaterialColor verwendet
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isCompact ? 10 : 12,
                      fontWeight: FontWeight.w600,
                      color: _getMaterialColorShade(color, 700), // FIXED
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Subtitle - FIXED: MaterialColor verwendet
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isCompact ? 8 : 10,
                      color: _getMaterialColorShade(color, 600), // FIXED
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
  }

  // ✅ HELPER METHODE: MaterialColor shade Ersatz
  Color _getMaterialColorShade(Color baseColor, int shade) {
    // Approximiere MaterialColor shades basierend auf Base Color
    final hsl = HSLColor.fromColor(baseColor);
    switch (shade) {
      case 600:
        return hsl.withLightness((hsl.lightness * 0.8).clamp(0.0, 1.0)).toColor();
      case 700:
        return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
      default:
        return baseColor;
    }
  }

  // ✅ MOBILE-OPTIMIERTER SWAP BUTTON - FIXED: SizedBox statt Container für Whitespace
  Widget _buildMobileSwapButton() {
    return SizedBox( // FIXED: Container durch SizedBox ersetzt
      height: 44, // Standard Touch-Target
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: _swapStartAndDestination,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(
                    Icons.swap_vert, 
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildLockButton(bool isStart) {
    final isLocked = isStart ? widget.isStartLocked : widget.isDestinationLocked;
    final onPressed = isStart
        ? widget.controller.toggleStartLock
        : widget.controller.toggleDestinationLock;

    return Container(
      width: 48, // ✅ ENHANCED TOUCH TARGET
      height: 48,
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
          size: 20, // ✅ OPTIMIERTE ICON-GRÖSSE
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