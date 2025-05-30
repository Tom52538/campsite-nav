// lib/services/search_manager.dart - NEUE SUCH-MANAGER SERVICE
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/camping_search_categories.dart';
import 'package:camping_osm_navi/widgets/stable_search_input.dart';

class SearchManager extends ChangeNotifier {
  List<SearchableFeature> _allFeatures = [];
  List<SearchableFeature> _currentResults = [];
  String _currentQuery = '';
  SearchFieldType? _activeField;
  Timer? _searchTimer;

  // Getters
  List<SearchableFeature> get currentResults => _currentResults;
  String get currentQuery => _currentQuery;
  SearchFieldType? get activeField => _activeField;
  bool get hasResults => _currentResults.isNotEmpty;

  // Initialize with features
  void initialize(List<SearchableFeature> features) {
    _allFeatures = features;
    notifyListeners();
  }

  // Set active search field
  void setActiveField(SearchFieldType? field) {
    if (_activeField != field) {
      _activeField = field;
      notifyListeners();
    }
  }

  // Perform search with debouncing
  void search(String query, SearchFieldType fieldType) {
    _currentQuery = query;
    _activeField = fieldType;

    // Cancel previous search
    _searchTimer?.cancel();

    if (query.isEmpty) {
      _currentResults.clear();
      notifyListeners();
      return;
    }

    // Debounce search for 300ms
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    if (query != _currentQuery) return; // Query changed, ignore

    try {
      final results = _performAdvancedSearch(_allFeatures, query);
      _currentResults = results.take(10).toList(); // Limit to 10 results
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[SearchManager] Error during search: $e');
      }
      _currentResults.clear();
      notifyListeners();
    }
  }

  List<SearchableFeature> _performAdvancedSearch(
      List<SearchableFeature> features, String query) {
    final cleanQuery = query.trim().toLowerCase();

    // 1. Check for emoji shortcuts
    final shortcutQuery = CampingSearchCategories.quickSearchShortcuts[query];
    if (shortcutQuery != null) {
      return _performAdvancedSearch(features, shortcutQuery);
    }

    // 2. Accommodation number search (highest priority)
    if (CampingSearchCategories.isAccommodationNumberSearch(cleanQuery)) {
      final accommodationResults =
          _searchAccommodationByNumber(features, cleanQuery);
      if (accommodationResults.isNotEmpty) {
        return accommodationResults;
      }
    }

    // 3. Category matching
    final matchedCategory = CampingSearchCategories.matchCategory(cleanQuery);
    if (matchedCategory != null) {
      final categoryResults = _searchByCategory(features, matchedCategory);
      if (categoryResults.isNotEmpty) {
        return _prioritizeCategoryResults(categoryResults, matchedCategory);
      }
    }

    // 4. OSM type matching
    final osmResults = _searchByOsmType(features, cleanQuery);
    if (osmResults.isNotEmpty) {
      return osmResults;
    }

    // 5. Name search (fallback)
    return _searchByName(features, cleanQuery);
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

  // Clear search
  void clearSearch() {
    _searchTimer?.cancel();
    _currentQuery = '';
    _currentResults.clear();
    _activeField = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
