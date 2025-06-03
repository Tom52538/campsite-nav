// lib/widgets/campsite_search_input.dart - PREMIUM SMARTPHONE-OPTIMIERT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/camping_search_categories.dart';
import 'package:camping_osm_navi/widgets/stable_search_input.dart';

/// Premium Campsite Search Input - Smartphone-First Design
/// 
/// Features:
/// - Touch-optimierte Größen (44px+ targets)
/// - Intelligente Keyboard-Behandlung
/// - Resort-spezifische Quick-Actions
/// - Automatisches Verschwinden nach Eingabe
/// - Accessibility-optimiert
class CampsiteSearchInput extends StatefulWidget {
  final SearchFieldType fieldType;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<SearchableFeature> allFeatures;
  final Function(SearchableFeature) onFeatureSelected;
  final VoidCallback? onCurrentLocationTap;
  final VoidCallback? onMapSelectionTap;
  final bool showQuickAccess;
  final SearchContext context;
  final bool autoDismissOnSelection;

  const CampsiteSearchInput({
    super.key,
    required this.fieldType,
    required this.controller,
    required this.focusNode,
    required this.allFeatures,
    required this.onFeatureSelected,
    this.onCurrentLocationTap,
    this.onMapSelectionTap,
    this.showQuickAccess = true,
    this.context = SearchContext.guest,
    this.autoDismissOnSelection = true,
  });

  @override
  State<CampsiteSearchInput> createState() => _CampsiteSearchInputState();
}

class _CampsiteSearchInputState extends State<CampsiteSearchInput>
    with TickerProviderStateMixin {
  
  late AnimationController _quickAccessController;
  late AnimationController _resultsController;
  late Animation<double> _quickAccessAnimation;
  late Animation<double> _resultsAnimation;
  
  List<SearchableFeature> _searchResults = [];
  bool _showResults = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    
    _quickAccessController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _resultsController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _quickAccessAnimation = CurvedAnimation(
      parent: _quickAccessController,
      curve: PremiumCurves.smooth,
    );
    
    _resultsAnimation = CurvedAnimation(
      parent: _resultsController,
      curve: PremiumCurves.material,
    );
    
    // Quick Access nur für Destination anzeigen
    if (widget.fieldType == SearchFieldType.destination && widget.showQuickAccess) {
      _quickAccessController.forward();
    }
    
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _quickAccessController.dispose();
    _resultsController.dispose();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _showResults = false;
        _isSearching = false;
      });
      _resultsController.reverse();
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Debounced Search für Performance
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && widget.controller.text.trim() == query) {
        _performIntelligentSearch(query);
      }
    });
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus && widget.controller.text.isNotEmpty) {
      _showSearchResults();
    } else if (!widget.focusNode.hasFocus) {
      _hideSearchResults();
    }
  }

  void _performIntelligentSearch(String query) {
    final results = _getIntelligentSearchResults(query);
    
    setState(() {
      _searchResults = results.take(8).toList(); // Max 8 für Smartphone
      _showResults = results.isNotEmpty;
      _isSearching = false;
    });

    if (_showResults) {
      _showSearchResults();
    } else {
      _hideSearchResults();
    }
  }

  List<SearchableFeature> _getIntelligentSearchResults(String query) {
    final cleanQuery = query.toLowerCase().trim();
    
    // 1. Emoji Shortcuts
    final shortcutQuery = CampingSearchCategories.quickSearchShortcuts[query];
    if (shortcutQuery != null) {
      return _getIntelligentSearchResults(shortcutQuery);
    }

    // 2. Accommodation Number Search (höchste Priorität)
    if (CampingSearchCategories.isAccommodationNumberSearch(cleanQuery)) {
      return _searchAccommodationByNumber(cleanQuery);
    }

    // 3. Category-based Search
    final category = CampingSearchCategories.matchCategory(cleanQuery);
    if (category != null) {
      return _searchByCategory(category);
    }

    // 4. Fuzzy Name Search
    return _fuzzyNameSearch(cleanQuery);
  }

  List<SearchableFeature> _searchAccommodationByNumber(String query) {
    final numberMatches = RegExp(r'\d+').allMatches(query);
    if (numberMatches.isEmpty) return [];

    final searchNumbers = numberMatches.map((m) => m.group(0)!).toList();
    final results = <SearchableFeature>[];

    for (final searchNum in searchNumbers) {
      final matches = widget.allFeatures.where((feature) {
        if (!_isAccommodationType(feature.type)) return false;
        
        final name = feature.name.toLowerCase();
        return name.contains(searchNum);
      }).toList();
      
      results.addAll(matches);
    }

    // Sortiere nach Exaktheit
    results.sort((a, b) => a.name.length.compareTo(b.name.length));
    return results.toSet().toList();
  }

  List<SearchableFeature> _searchByCategory(CampingSearchCategory category) {
    final results = widget.allFeatures.where((feature) {
      // OSM Type Matching
      for (final osmType in category.osmTypes) {
        if (feature.type.toLowerCase().contains(osmType.toLowerCase())) {
          return true;
        }
      }
      
      // Keyword Matching
      final featureName = feature.name.toLowerCase();
      for (final keyword in category.keywords) {
        if (featureName.contains(keyword.toLowerCase())) {
          return true;
        }
      }
      
      return false;
    }).toList();

    // Priorität-basierte Sortierung
    results.sort((a, b) {
      final aExactType = category.osmTypes.contains(a.type.toLowerCase());
      final bExactType = category.osmTypes.contains(b.type.toLowerCase());
      
      if (aExactType && !bExactType) return -1;
      if (!aExactType && bExactType) return 1;
      
      return a.name.compareTo(b.name);
    });

    return results;
  }

  List<SearchableFeature> _fuzzyNameSearch(String query) {
    final results = widget.allFeatures.where((feature) {
      final name = feature.name.toLowerCase();
      final type = feature.type.toLowerCase();
      
      // Exakte Matches
      if (name.contains(query) || type.contains(query)) {
        return true;
      }
      
      // Fuzzy Matching für Typos
      return _fuzzyMatch(name, query) || _fuzzyMatch(type, query);
    }).toList();

    // Relevanz-Sortierung
    results.sort((a, b) {
      final aScore = _calculateRelevanceScore(a, query);
      final bScore = _calculateRelevanceScore(b, query);
      return bScore.compareTo(aScore);
    });

    return results;
  }

  bool _fuzzyMatch(String text, String query) {
    if (query.length < 3) return false;
    
    // Einfaches Fuzzy Matching für 1-2 Charaktere Unterschied
    int differences = 0;
    int minLength = [text.length, query.length].reduce((a, b) => a < b ? a : b);
    
    for (int i = 0; i < minLength; i++) {
      if (text[i] != query[i]) {
        differences++;
        if (differences > 2) return false;
      }
    }
    
    return differences <= 2;
  }

  int _calculateRelevanceScore(SearchableFeature feature, String query) {
    int score = 0;
    final name = feature.name.toLowerCase();
    
    // Exact start match
    if (name.startsWith(query)) score += 100;
    
    // Contains match
    if (name.contains(query)) score += 50;
    
    // Resort priority
    final category = CampingSearchCategories.getCategoryByOsmType(feature.type);
    if (category?.isRoompotPriority == true) score += 25;
    
    // Context priority
    final resultType = _getSearchResultType(feature.type);
    if (widget.context.prioritizedTypes.contains(resultType)) {
      score += 10;
    }
    
    return score;
  }

  SearchResultType _getSearchResultType(String type) {
    if (type.toLowerCase().contains('parking')) return SearchResultType.parking;
    if (type.toLowerCase().contains('accommodation') || 
        type.toLowerCase().contains('building')) {
      return SearchResultType.accommodation;
    }
    if (type.toLowerCase().contains('restaurant') || 
        type.toLowerCase().contains('cafe')) {
      return SearchResultType.dining;
    }
    if (type.toLowerCase().contains('playground')) return SearchResultType.family;
    if (type.toLowerCase().contains('beach') || 
        type.toLowerCase().contains('pool')) {
      return SearchResultType.beach;
    }
    
    return SearchResultType.amenity;
  }

  bool _isAccommodationType(String type) {
    final accommodationTypes = [
      'accommodation', 'building', 'house', 'pitch', 'camp_pitch',
      'holiday_home', 'chalet', 'bungalow', 'lodge', 'cabin'
    ];
    return accommodationTypes.any((t) => type.toLowerCase().contains(t));
  }

  void _showSearchResults() {
    if (_searchResults.isNotEmpty) {
      _resultsController.forward();
    }
  }

  void _hideSearchResults() {
    _resultsController.reverse();
  }

  void _onFeatureSelected(SearchableFeature feature) {
    // Haptic Feedback für Premium Feel
    HapticFeedback.lightImpact();
    
    widget.onFeatureSelected(feature);
    
    if (widget.autoDismissOnSelection) {
      widget.focusNode.unfocus();
      _hideSearchResults();
    }
  }

  void _onQuickActionTap(String searchTerm, String categoryName) {
    HapticFeedback.selectionClick();
    
    widget.controller.text = searchTerm;
    _performIntelligentSearch(searchTerm);
    
    // Quick feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$categoryName suchen...'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < SmartphoneBreakpoints.small;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium Search Input Field
        _buildPremiumSearchField(isSmallScreen),
        
        // Quick Access Buttons (nur für Destination)
        if (widget.fieldType == SearchFieldType.destination && widget.showQuickAccess)
          _buildQuickAccessSection(isSmallScreen),
        
        // Search Results
        _buildSearchResults(isSmallScreen),
      ],
    );
  }

  Widget _buildPremiumSearchField(bool isSmallScreen) {
    return Container(
      height: SmartphoneTouchTargets.comfortableSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: widget.focusNode.hasFocus 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey.shade300,
          width: widget.focusNode.hasFocus ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (widget.focusNode.hasFocus)
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withAlpha(25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          // Field Type Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  widget.fieldType.emoji,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          
          // Text Input
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: TextStyle(
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '${widget.fieldType.displayName} eingeben...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: isSmallScreen ? 14 : 15,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),
          
          // Action Buttons
          _buildActionButtons(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Indicator
        if (_isSearching)
          Container(
            width: SmartphoneTouchTargets.minimumSize,
            height: SmartphoneTouchTargets.minimumSize,
            padding: const EdgeInsets.all(12),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        
        // Clear Button
        if (!_isSearching && widget.controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            color: Colors.grey.shade600,
            onPressed: () {
              widget.controller.clear();
              _hideSearchResults();
            },
            constraints: const BoxConstraints(
              minWidth: SmartphoneTouchTargets.minimumSize,
              minHeight: SmartphoneTouchTargets.minimumSize,
            ),
          ),
        
        // Current Location (nur für Start)
        if (widget.fieldType == SearchFieldType.start && widget.onCurrentLocationTap != null)
          IconButton(
            icon: const Icon(Icons.my_location, size: 20),
            color: Theme.of(context).colorScheme.primary,
            onPressed: widget.onCurrentLocationTap,
            tooltip: 'Aktueller Standort',
            constraints: const BoxConstraints(
              minWidth: SmartphoneTouchTargets.minimumSize,
              minHeight: SmartphoneTouchTargets.minimumSize,
            ),
          ),
        
        // Map Selection
        if (widget.onMapSelectionTap != null)
          IconButton(
            icon: const Icon(Icons.location_searching, size: 20),
            color: Theme.of(context).colorScheme.secondary,
            onPressed: widget.onMapSelectionTap,
            tooltip: 'Auf Karte wählen',
            constraints: const BoxConstraints(
              minWidth: SmartphoneTouchTargets.minimumSize,
              minHeight: SmartphoneTouchTargets.minimumSize,
            ),
          ),
      ],
    );
  }

  Widget _buildQuickAccessSection(bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _quickAccessAnimation,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _quickAccessAnimation,
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            child: _buildQuickAccessButtons(isSmallScreen),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessButtons(bool isSmallScreen) {
    final quickActions = [
      ('🅿️', 'parkplatz', 'Parkplatz'),
      ('👨‍👩‍👧‍👦', 'spielplatz', 'Familie'),
      ('🏖️', 'beach pool', 'Beach'),
      ('🍽️', 'restaurant', 'Essen'),
    ];

    return SizedBox(
      height: isSmallScreen ? 60 : 70,
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
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          action.$1,
                          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action.$3,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 9 : 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
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
    );
  }

  Widget _buildSearchResults(bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _resultsAnimation,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _resultsAnimation,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildResultsList(isSmallScreen),
          ),
        );
      },
    );
  }

  Widget _buildResultsList(bool isSmallScreen) {
    if (_searchResults.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade200,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final feature = _searchResults[index];
        final resultType = _getSearchResultType(feature.type);
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onFeatureSelected(feature),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: SmartphoneTouchTargets.comfortableSize,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Category Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(int.parse('0xFF${resultType.colorHex.substring(1)}')).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        _getIconForResultType(resultType),
                        size: 16,
                        color: Color(int.parse('0xFF${resultType.colorHex.substring(1)}')),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Feature Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          feature.name,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feature.type,
                          style: TextStyle(
                            fontSize: isSmallScreen ?