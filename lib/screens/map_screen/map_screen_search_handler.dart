// lib/screens/map_screen/map_screen_search_handler.dart - KEYBOARD FIX VERSION
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/camping_search_categories.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'map_screen_controller.dart';

class MapScreenSearchHandler {
  final MapScreenController controller;
  final BuildContext context;

  Timer? _hideResultsTimer;

  MapScreenSearchHandler(this.controller, this.context) {
    _initializeSearchListeners();
  }

  void _initializeSearchListeners() {
    controller.startSearchController.addListener(_onStartSearchChanged);
    controller.endSearchController.addListener(_onEndSearchChanged);
    controller.startFocusNode.addListener(_onStartFocusChanged);
    controller.endFocusNode.addListener(_onEndFocusChanged);
  }

  void _onStartSearchChanged() {
    if (controller.startFocusNode.hasFocus &&
        controller.startSearchController.text != "Aktueller Standort") {
      _performCampingIntelligentSearch(controller.startSearchController.text);
    }
  }

  void _onEndSearchChanged() {
    if (controller.endFocusNode.hasFocus) {
      _performCampingIntelligentSearch(controller.endSearchController.text);
    }
  }

  void _onStartFocusChanged() {
    if (controller.startFocusNode.hasFocus) {
      controller.setActiveSearchField(ActiveSearchField.start);
      controller.setRouteActiveForCardSwitch(false);
      if (controller.startSearchController.text != "Aktueller Standort") {
        _performCampingIntelligentSearch(controller.startSearchController.text);
      }
    } else {
      if (controller.activeSearchField == ActiveSearchField.start) {
        controller.setActiveSearchField(ActiveSearchField.none);
      }
      _hideSearchResultsAfterDelay();
    }
  }

  void _onEndFocusChanged() {
    if (controller.endFocusNode.hasFocus) {
      controller.setActiveSearchField(ActiveSearchField.end);
      controller.setRouteActiveForCardSwitch(false);
      _performCampingIntelligentSearch(controller.endSearchController.text);
    } else {
      if (controller.activeSearchField == ActiveSearchField.end) {
        controller.setActiveSearchField(ActiveSearchField.none);
      }
      // ✅ FIX 6: Längere Verzögerung für Hide Timer
      _hideSearchResultsAfterDelay();
    }
  }

  void _hideSearchResultsAfterDelay() {
    _hideResultsTimer?.cancel();
    // ✅ FIX 7: 30 Sekunden statt 1.5 Sekunden - viel weniger aggressiv
    _hideResultsTimer = Timer(const Duration(seconds: 30), () {
      if (!controller.startFocusNode.hasFocus &&
          !controller.endFocusNode.hasFocus) {
        controller.setShowSearchResults(false);
        // ✅ FIX 8: POIs bleiben sichtbar auch ohne Focus
        // controller.clearVisibleSearchResults(); // ENTFERNT
      }
    });
  }

  void _performCampingIntelligentSearch(String query) {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final allFeatures = locationProvider.currentSearchableFeatures;

    if (query.isEmpty) {
      controller.setSearchResults([]);
      controller.setShowSearchResults(false);
      controller.clearVisibleSearchResults();
      return;
    }

    // Emoji-Shortcuts prüfen
    final shortcutQuery = CampingSearchCategories.quickSearchShortcuts[query];
    if (shortcutQuery != null) {
      _performCampingIntelligentSearch(shortcutQuery);
      return;
    }

    final filteredResults =
        _performAdvancedCategoryFiltering(allFeatures, query);

    controller.setSearchResults(filteredResults);
    controller.setShowSearchResults(true);
    controller.setVisibleSearchResults(filteredResults);
  }

  List<SearchableFeature> _performAdvancedCategoryFiltering(
      List<SearchableFeature> allFeatures, String query) {
    final String cleanQuery = query.trim().toLowerCase();

    // 1. UNTERKUNFT-NUMMER (höchste Priorität)
    if (CampingSearchCategories.isAccommodationNumberSearch(cleanQuery)) {
      final accommodationResults =
          _searchAccommodationByNumber(allFeatures, cleanQuery);
      if (accommodationResults.isNotEmpty) {
        return accommodationResults;
      }
    }

    // 2. KATEGORIE-MATCHING
    final matchedCategory = CampingSearchCategories.matchCategory(cleanQuery);
    if (matchedCategory != null) {
      final categoryResults = _searchByCategory(allFeatures, matchedCategory);
      if (categoryResults.isNotEmpty) {
        return _prioritizeCategoryResults(categoryResults, matchedCategory);
      }
    }

    // 3. OSM-TYPE MATCHING
    final osmResults = _searchByOsmType(allFeatures, cleanQuery);
    if (osmResults.isNotEmpty) {
      return osmResults;
    }

    // 4. FALLBACK: Name-Suche
    final nameResults = _searchByName(allFeatures, cleanQuery);
    return nameResults;
  }

  List<SearchableFeature> _searchAccommodationByNumber(
      List<SearchableFeature> features, String query) {
    final numberMatches = RegExp(r'\d+').allMatches(query);
    if (numberMatches.isEmpty) return [];

    final searchNumbers = numberMatches.map((m) => m.group(0)!).toList();
    final results = <SearchableFeature>[];

    for (final searchNum in searchNumbers) {
      final numberResults = features.where((feature) {
        if (!_isAccommodationType(feature.type)) return false;

        final name = feature.name.toLowerCase();

        // Einfache String-Vergleiche statt komplexer RegExp
        return name == searchNum ||
            name.contains(' $searchNum ') ||
            name.startsWith('$searchNum ') ||
            name.endsWith(' $searchNum') ||
            name.contains('$searchNum-') ||
            name.contains('-$searchNum') ||
            name.startsWith('${searchNum}a') ||
            name.startsWith('${searchNum}b') ||
            name.startsWith('${searchNum}c');
      }).toList();

      results.addAll(numberResults);
    }

    final uniqueResults = results.toSet().toList();
    uniqueResults.sort((a, b) {
      final aExact =
          searchNumbers.any((searchNum) => a.name.toLowerCase() == searchNum);
      final bExact =
          searchNumbers.any((searchNum) => b.name.toLowerCase() == searchNum);
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return a.name.compareTo(b.name);
    });

    return uniqueResults;
  }

  List<SearchableFeature> _searchByCategory(
      List<SearchableFeature> features, CampingSearchCategory category) {
    return features.where((feature) {
      for (final osmType in category.osmTypes) {
        if (feature.type.toLowerCase() == osmType.toLowerCase() ||
            feature.type.toLowerCase().contains(osmType.toLowerCase()) ||
            osmType.toLowerCase().contains(feature.type.toLowerCase())) {
          return true;
        }
      }

      final featureName = feature.name.toLowerCase();
      for (final keyword in category.keywords) {
        if (featureName.contains(keyword.toLowerCase())) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  List<SearchableFeature> _searchByOsmType(
      List<SearchableFeature> features, String query) {
    return features
        .where((feature) =>
            feature.type.toLowerCase().contains(query) ||
            query.contains(feature.type.toLowerCase()))
        .toList();
  }

  List<SearchableFeature> _prioritizeCategoryResults(
      List<SearchableFeature> results, CampingSearchCategory category) {
    results.sort((a, b) {
      final aExactType = category.osmTypes.contains(a.type.toLowerCase());
      final bExactType = category.osmTypes.contains(b.type.toLowerCase());

      if (aExactType && !bExactType) return -1;
      if (!aExactType && bExactType) return 1;

      return a.name.compareTo(b.name);
    });

    return results;
  }

  List<SearchableFeature> _searchByName(
      List<SearchableFeature> features, String query) {
    final results = features
        .where((feature) => feature.name.toLowerCase().contains(query))
        .toList();

    results.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(query);
      final bStarts = b.name.toLowerCase().startsWith(query);

      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;

      return a.name.length.compareTo(b.name.length);
    });

    return results;
  }

  bool _isAccommodationType(String type) {
    final category = CampingSearchCategories.getCategoryByOsmType(type);
    return category?.category == CampingPOICategory.accommodation;
  }

  void selectFeatureAndSetPoint(SearchableFeature feature) {
    final point = feature.center;

    if (controller.activeSearchField == ActiveSearchField.start) {
      controller.startSearchController.text = feature.name;
      controller.setStartLatLng(point);
      controller.updateStartMarker();
      // ✅ FIX 9: Kein automatischer unfocus bei Feature-Auswahl
      // controller.startFocusNode.unfocus(); // ENTFERNT
    } else if (controller.activeSearchField == ActiveSearchField.end) {
      controller.endSearchController.text = feature.name;
      controller.setEndLatLng(point);
      controller.updateEndMarker();
      // ✅ FIX 10: Kein automatischer unfocus bei Feature-Auswahl
      // controller.endFocusNode.unfocus(); // ENTFERNT
    }

    controller.setShowSearchResults(false);
    controller.setVisibleSearchResults([feature]);

    if (_onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  void setStartToCurrentLocation() {
    if (controller.currentGpsPosition == null) {
      return;
    }

    controller.startSearchController.text = "Aktueller Standort";
    controller.setStartLatLng(controller.currentGpsPosition);
    controller.startMarker = null;
    controller.startFocusNode.unfocus();

    controller.clearVisibleSearchResults();

    if (_onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  void swapStartAndEnd() {
    controller.swapStartAndEnd();

    if (_onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  void clearSearchField(bool isStartField) {
    if (isStartField) {
      controller.startSearchController.clear();
      controller.setStartLatLng(null);
      controller.startMarker = null;
    } else {
      controller.endSearchController.clear();
      controller.setEndLatLng(null);
      controller.endMarker = null;
    }

    controller.clearVisibleSearchResults();

    if (_onRouteClearNeeded != null) {
      _onRouteClearNeeded!();
    }
  }

  void Function()? _onRouteCalculationNeeded;
  void Function()? _onRouteClearNeeded;

  void setRouteCalculationCallback(void Function() callback) {
    _onRouteCalculationNeeded = callback;
  }

  void setRouteClearCallback(void Function() callback) {
    _onRouteClearNeeded = callback;
  }

  void dispose() {
    _hideResultsTimer?.cancel();

    controller.startSearchController.removeListener(_onStartSearchChanged);
    controller.endSearchController.removeListener(_onEndSearchChanged);
    controller.startFocusNode.removeListener(_onStartFocusChanged);
    controller.endFocusNode.removeListener(_onEndFocusChanged);
  }
}
