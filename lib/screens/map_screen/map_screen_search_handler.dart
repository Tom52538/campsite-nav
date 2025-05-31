// lib/screens/map_screen/map_screen_search_handler.dart - MISSING METHODS ADDED
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
    // Add text change listeners
    controller.startSearchController.addListener(() {
      final query = controller.startSearchController.text;
      if (controller.activeSearchField == ActiveSearchField.start) {
        _performCampingIntelligentSearch(query);
      }
    });

    controller.endSearchController.addListener(() {
      final query = controller.endSearchController.text;
      if (controller.activeSearchField == ActiveSearchField.end) {
        _performCampingIntelligentSearch(query);
      }
    });
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

  // ✅ MISSING METHOD 1: swapStartAndEnd
  void swapStartAndEnd() {
    controller.swapStartAndEnd();
  }

  // ✅ MISSING METHOD 2: setStartToCurrentLocation
  void setStartToCurrentLocation() {
    if (controller.currentGpsPosition != null) {
      controller.startSearchController.text = "Aktueller Standort";
      controller.setStartLatLng(controller.currentGpsPosition!);
      controller.updateStartMarker();

      // Trigger route calculation if end is set
      if (controller.endLatLng != null && _onRouteCalculationNeeded != null) {
        _onRouteCalculationNeeded!();
      }
    }
  }

  // ✅ MISSING METHOD 3: selectFeatureAndSetPoint
  void selectFeatureAndSetPoint(SearchableFeature feature) {
    if (controller.activeSearchField == ActiveSearchField.start) {
      controller.startSearchController.text = feature.name;
      controller.setStartLatLng(feature.center);
      controller.updateStartMarker();
    } else if (controller.activeSearchField == ActiveSearchField.end) {
      controller.endSearchController.text = feature.name;
      controller.setEndLatLng(feature.center);
      controller.updateEndMarker();
    }

    // Hide search results after selection
    controller.setShowSearchResults(false);
    controller.clearVisibleSearchResults();

    // Move map to selected feature
    controller.mapController.move(feature.center, 18.0);

    // Trigger route calculation if both points are set
    if (controller.startLatLng != null &&
        controller.endLatLng != null &&
        _onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  // Callback management (used by the methods above)
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
  }
}
