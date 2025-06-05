// lib/widgets/campsite_search_input.dart - MIT ENHANCED USER JOURNEY LOGGING
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camping_osm_navi/models/search_types.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/camping_search_categories.dart';
import 'package:camping_osm_navi/services/user_journey_logger.dart'; // ✅ NEUES LOGGING

/// Premium Campsite Search Input mit detailliertem User Journey Logging
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
  Timer? _debounceTimer;

  // ✅ LOGGING: Performance Tracking
  DateTime? _searchStartTime;

  @override
  void initState() {
    super.initState();

    // ✅ LOGGING: Search Interface bereit
    UserJourneyLogger.searchInterfaceReady(widget.allFeatures.length);

    developer.log('[POI-DEBUG] === CAMPSITE SEARCH INPUT INIT ===');
    developer
        .log('[POI-DEBUG] Available features: ${widget.allFeatures.length}');

    if (widget.allFeatures.isNotEmpty) {
      for (int i = 0; i < widget.allFeatures.take(5).length; i++) {
        final f = widget.allFeatures[i];
        developer.log('[POI-DEBUG] Feature $i: "${f.name}" (${f.type})');
      }
    } else {
      developer.log('[POI-DEBUG] ❌ NO FEATURES AVAILABLE!');
      // ✅ LOGGING: Fehler wenn keine Features
      UserJourneyLogger.error(
          "SEARCH_INPUT", "Keine POIs verfügbar für Suche", {
        'expected_features': '>0',
        'actual_features': 0,
      });
    }

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
    if (widget.fieldType == SearchFieldType.destination &&
        widget.showQuickAccess) {
      _quickAccessController.forward();
    }

    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _quickAccessController.dispose();
    _resultsController.dispose();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();

    developer.log('[POI-DEBUG] Text changed: "$query"');

    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _showResults = false;
        _isSearching = false;
      });
      _resultsController.reverse();
      return;
    }

    // ✅ LOGGING: Suche gestartet
    _searchStartTime = DateTime.now();
    UserJourneyLogger.searchStarted(query, widget.fieldType.value);

    setState(() {
      _isSearching = true;
    });

    final delay = query.length <= 2
        ? const Duration(milliseconds: 100)
        : const Duration(milliseconds: 300);

    _debounceTimer = Timer(delay, () {
      if (mounted) {
        _performActualSearch(query);
      }
    });
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus && widget.controller.text.isNotEmpty) {
      _showSearchResults();
    } else if (!widget.focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !widget.focusNode.hasFocus) {
          _hideSearchResults();
        }
      });
    }
  }

  void _performActualSearch(String query) {
    developer.log('[POI-DEBUG] === PERFORMING SEARCH ===');
    developer.log('[POI-DEBUG] Query: "$query"');
    developer
        .log('[POI-DEBUG] Available features: ${widget.allFeatures.length}');

    if (widget.allFeatures.isEmpty) {
      developer.log('[POI-DEBUG] ❌ No features available for search!');

      // ✅ LOGGING: Keine Features
      UserJourneyLogger.searchNoResults(query);

      setState(() {
        _searchResults.clear();
        _showResults = false;
        _isSearching = false;
      });
      return;
    }

    final cleanQuery = query.toLowerCase().trim();
    final results = <SearchableFeature>[];

    // ✅ STEP 1: Direkte Namenssuche (höchste Priorität)
    for (final feature in widget.allFeatures) {
      if (feature.name.toLowerCase().contains(cleanQuery)) {
        results.add(feature);
        developer.log('[POI-DEBUG] Name match: "${feature.name}"');
      }
    }

    // ✅ STEP 2: Type-Suche (wenn weniger als 5 Ergebnisse)
    if (results.length < 5) {
      for (final feature in widget.allFeatures) {
        if (feature.type.toLowerCase().contains(cleanQuery) &&
            !results.any((r) => r.id == feature.id)) {
          results.add(feature);
          developer.log(
              '[POI-DEBUG] Type match: "${feature.name}" (${feature.type})');
        }
      }
    }

    // ✅ STEP 3: Spezielle Parkplatz-Suche
    if (cleanQuery.contains('park') || cleanQuery.contains('p')) {
      for (final feature in widget.allFeatures) {
        if ((feature.type.toLowerCase().contains('parking') ||
                feature.name.toLowerCase().contains('parkplatz')) &&
            !results.any((r) => r.id == feature.id)) {
          results.add(feature);
          developer.log('[POI-DEBUG] Parking match: "${feature.name}"');
        }
      }
    }

    // ✅ STEP 4: Nummer-Suche für Accommodations
    if (RegExp(r'\d+').hasMatch(cleanQuery)) {
      final numberMatch = RegExp(r'\d+').firstMatch(cleanQuery);
      if (numberMatch != null) {
        final number = numberMatch.group(0);
        for (final feature in widget.allFeatures) {
          if (feature.name.contains(number!) &&
              !results.any((r) => r.id == feature.id)) {
            results.add(feature);
            developer.log(
                '[POI-DEBUG] Number match: "${feature.name}" for number $number');
          }
        }
      }
    }

    // ✅ STEP 5: Emoji Shortcuts
    final shortcutQuery = CampingSearchCategories.quickSearchShortcuts[query];
    if (shortcutQuery != null) {
      developer
          .log('[POI-DEBUG] Emoji shortcut detected: $query -> $shortcutQuery');

      // ✅ LOGGING: Quick Action
      UserJourneyLogger.logQuickAction(query, shortcutQuery);

      _performActualSearch(shortcutQuery);
      return;
    }

    // ✅ STEP 6: Category-based search
    final category = CampingSearchCategories.matchCategory(cleanQuery);
    if (category != null && results.length < 8) {
      for (final feature in widget.allFeatures) {
        // OSM Type Matching
        for (final osmType in category.osmTypes) {
          if (feature.type.toLowerCase().contains(osmType.toLowerCase()) &&
              !results.any((r) => r.id == feature.id)) {
            results.add(feature);
            developer.log(
                '[POI-DEBUG] Category OSM match: "${feature.name}" (${feature.type})');
            break;
          }
        }

        // Keyword Matching
        final featureName = feature.name.toLowerCase();
        for (final keyword in category.keywords) {
          if (featureName.contains(keyword.toLowerCase()) &&
              !results.any((r) => r.id == feature.id)) {
            results.add(feature);
            developer.log(
                '[POI-DEBUG] Category keyword match: "${feature.name}" for "$keyword"');
            break;
          }
        }
      }
    }

    developer.log('[POI-DEBUG] Total results found: ${results.length}');

    // ✅ Sortiere nach Relevanz
    results.sort((a, b) {
      final aExact = a.name.toLowerCase() == cleanQuery;
      final bExact = b.name.toLowerCase() == cleanQuery;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return a.name.length.compareTo(b.name.length);
    });

    // ✅ LOGGING: Suchergebnisse mit Performance-Tracking
    if (_searchStartTime != null) {
      final searchDuration =
          DateTime.now().difference(_searchStartTime!).inMilliseconds;

      if (results.isNotEmpty) {
        UserJourneyLogger.searchCompleted(
            query, results.length, searchDuration);
        UserJourneyLogger.performanceMetric(
            "Search", searchDuration, "SUCCESS");
      } else {
        UserJourneyLogger.searchNoResults(query);
        UserJourneyLogger.performanceMetric(
            "Search", searchDuration, "NO_RESULTS");
      }
    }

    setState(() {
      _searchResults = results.take(8).toList();
      _showResults = _searchResults.isNotEmpty;
      _isSearching = false;
    });

    if (_showResults) {
      _showSearchResults();
      developer.log('[POI-DEBUG] ✅ Showing ${_searchResults.length} results');
    } else {
      _hideSearchResults();
      developer.log('[POI-DEBUG] ❌ No results to show');
    }
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
    developer.log('[POI-DEBUG] Feature selected: "${feature.name}"');

    // ✅ LOGGING: Restaurant/Feature ausgewählt
    if (feature.type.toLowerCase().contains('restaurant') ||
        feature.type.toLowerCase().contains('cafe') ||
        feature.type.toLowerCase().contains('bar')) {
      UserJourneyLogger.restaurantSelected(feature.name, feature.type,
          feature.center.latitude, feature.center.longitude);
    } else {
      UserJourneyLogger.buttonPressed(
          "Feature Selection", "POI gewählt: ${feature.name}");
    }

    // Haptic Feedback für Premium Feel
    HapticFeedback.lightImpact();

    widget.onFeatureSelected(feature);

    if (widget.autoDismissOnSelection) {
      widget.focusNode.unfocus();
      _hideSearchResults();
    }
  }

  void _onQuickActionTap(String searchTerm, String categoryName) {
    developer
        .log('[POI-DEBUG] Quick action tapped: "$searchTerm" ($categoryName)');

    // ✅ LOGGING: Quick Action verwendet
    UserJourneyLogger.logQuickAction(searchTerm, categoryName);

    HapticFeedback.selectionClick();

    widget.controller.text = searchTerm;
    _performActualSearch(searchTerm);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$categoryName wird gesucht...'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen =
        MediaQuery.of(context).size.width < SmartphoneBreakpoints.small;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium Search Input Field
        _buildPremiumSearchField(isSmallScreen),

        // Quick Access Buttons (nur für Destination)
        if (widget.fieldType == SearchFieldType.destination &&
            widget.showQuickAccess)
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
              // ✅ LOGGING: Clear Button gedrückt
              UserJourneyLogger.buttonPressed(
                  "Clear Search", "Suchfeld geleert");

              widget.controller.clear();
              _hideSearchResults();
            },
            constraints: const BoxConstraints(
              minWidth: SmartphoneTouchTargets.minimumSize,
              minHeight: SmartphoneTouchTargets.minimumSize,
            ),
          ),

        // Current Location (nur für Start)
        if (widget.fieldType == SearchFieldType.start &&
            widget.onCurrentLocationTap != null)
          IconButton(
            icon: const Icon(Icons.my_location, size: 20),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              // ✅ LOGGING: Current Location Button
              UserJourneyLogger.buttonPressed(
                  "Current Location", "GPS Position als Start");
              widget.onCurrentLocationTap!();
            },
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
            onPressed: () {
              // ✅ LOGGING: Map Selection Button
              UserJourneyLogger.buttonPressed(
                  "Map Selection", "Karten-Selektion aktiviert");
              widget.onMapSelectionTap!();
            },
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
    const quickActions = [
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
                        // Icon
                        Container(
                          width: isSmallScreen ? 28 : 32,
                          height: isSmallScreen ? 28 : 32,
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              action.$1,
                              style:
                                  TextStyle(fontSize: isSmallScreen ? 16 : 18),
                            ),
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 4 : 6),

                        // Label
                        Text(
                          action.$3,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
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
    if (_searchResults.isEmpty &&
        widget.controller.text.isNotEmpty &&
        !_isSearching) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, color: Colors.grey.shade400, size: 32),
              const SizedBox(height: 8),
              Text(
                'Keine Ergebnisse für "${widget.controller.text}"',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Versuchen Sie: "parkplatz", "restaurant", oder eine Nummer',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

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

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onFeatureSelected(feature),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: SmartphoneTouchTargets.comfortableSize,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Category Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          _getColorForFeatureType(feature.type).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        _getIconForFeatureType(feature.type),
                        size: 18,
                        color: _getColorForFeatureType(feature.type),
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
                            fontSize: isSmallScreen ? 15 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feature.type,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Selection Arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForFeatureType(String type) {
    switch (type.toLowerCase()) {
      case 'parking':
        return Icons.local_parking;
      case 'accommodation':
      case 'building':
        return Icons.business;
      case 'restaurant':
      case 'cafe':
        return Icons.restaurant;
      case 'shop':
        return Icons.store;
      case 'playground':
        return Icons.child_friendly;
      case 'toilets':
      case 'sanitary':
        return Icons.wc;
      case 'tourism':
        return Icons.attractions;
      case 'amenity':
        return Icons.place;
      default:
        return Icons.location_on;
    }
  }

  Color _getColorForFeatureType(String type) {
    switch (type.toLowerCase()) {
      case 'parking':
        return Colors.indigo;
      case 'accommodation':
      case 'building':
        return Colors.brown;
      case 'restaurant':
      case 'cafe':
        return Colors.orange;
      case 'shop':
        return Colors.purple;
      case 'playground':
        return Colors.pink;
      case 'toilets':
      case 'sanitary':
        return Colors.cyan;
      case 'tourism':
        return Colors.green;
      case 'amenity':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
