// lib/screens/map_screen/map_screen_search_handler.dart (DEBUG VERSION)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/camping_search_categories.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'map_screen_controller.dart';

class MapScreenSearchHandler {
  final MapScreenController controller;
  final BuildContext context;

  // ✅ FIX: Timer für verzögertes Ausblenden
  Timer? _hideResultsTimer;

  MapScreenSearchHandler(this.controller, this.context) {
    _initializeSearchListeners();
  }

  void _initializeSearchListeners() {
    if (kDebugMode) {
      print("🔍 [DEBUG] SearchHandler: Initialisiere Listener");
    }

    controller.startSearchController.addListener(_onStartSearchChanged);
    controller.endSearchController.addListener(_onEndSearchChanged);
    controller.startFocusNode.addListener(_onStartFocusChanged);
    controller.endFocusNode.addListener(_onEndFocusChanged);
  }

  void _onStartSearchChanged() {
    if (kDebugMode) {
      print(
          "🔍 [DEBUG] Start Search Changed: '${controller.startSearchController.text}', Focus: ${controller.startFocusNode.hasFocus}");
    }

    if (controller.startFocusNode.hasFocus &&
        controller.startSearchController.text != "Aktueller Standort") {
      _performCampingIntelligentSearch(controller.startSearchController.text);
    }
  }

  void _onEndSearchChanged() {
    if (kDebugMode) {
      print(
          "🔍 [DEBUG] End Search Changed: '${controller.endSearchController.text}', Focus: ${controller.endFocusNode.hasFocus}");
    }

    if (controller.endFocusNode.hasFocus) {
      _performCampingIntelligentSearch(controller.endSearchController.text);
    }
  }

  void _onStartFocusChanged() {
    if (kDebugMode) {
      print(
          "🔍 [DEBUG] Start Focus Changed: ${controller.startFocusNode.hasFocus}");
    }

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
    if (kDebugMode) {
      print(
          "🔍 [DEBUG] End Focus Changed: ${controller.endFocusNode.hasFocus}");
      print("🔍 [DEBUG] Current Active Field: ${controller.activeSearchField}");
      print(
          "🔍 [DEBUG] Route Active: ${controller.isRouteActiveForCardSwitch}");
    }

    if (controller.endFocusNode.hasFocus) {
      if (kDebugMode) {
        print("🔍 [DEBUG] End Field gained focus - setting active");
      }
      controller.setActiveSearchField(ActiveSearchField.end);
      controller.setRouteActiveForCardSwitch(false);
      _performCampingIntelligentSearch(controller.endSearchController.text);
    } else {
      if (kDebugMode) {
        print("🔍 [DEBUG] End Field lost focus - clearing if was active");
      }
      if (controller.activeSearchField == ActiveSearchField.end) {
        controller.setActiveSearchField(ActiveSearchField.none);
      }
      _hideSearchResultsAfterDelay();
    }
  }

  // ✅ FIX: Fehlende Methode hinzugefügt
  void _hideSearchResultsAfterDelay() {
    if (kDebugMode) {
      print("🔍 [DEBUG] Hide results timer started");
    }

    _hideResultsTimer?.cancel();
    _hideResultsTimer = Timer(const Duration(milliseconds: 1500), () {
      // ✅ FIX: Längere Verzögerung!
      if (kDebugMode) {
        print(
            "🔍 [DEBUG] Timer executed - Start Focus: ${controller.startFocusNode.hasFocus}, End Focus: ${controller.endFocusNode.hasFocus}");
      }

      if (!controller.startFocusNode.hasFocus &&
          !controller.endFocusNode.hasFocus) {
        if (kDebugMode) {
          print("🔍 [DEBUG] Hiding search results - no focus");
        }
        controller.setShowSearchResults(false);
        // Behalte POIs sichtbar wenn sie aktiv sind
        if (controller.visibleSearchResults.isEmpty) {
          controller.clearVisibleSearchResults();
        }
      } else {
        if (kDebugMode) {
          print("🔍 [DEBUG] NOT hiding - still has focus");
        }
      }
    });
  }

  // ✅ ERWEITERT: Camping-spezifische intelligente Suche
  void _performCampingIntelligentSearch(String query) {
    if (kDebugMode) {
      print("🔍 [DEBUG] Performing search for: '$query'");
    }

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final allFeatures = locationProvider.currentSearchableFeatures;

    if (kDebugMode) {
      print("🔍 [DEBUG] Available features: ${allFeatures.length}");
    }

    if (query.isEmpty) {
      // Search-First Prinzip: Keine Suche = keine POIs
      controller.setSearchResults([]);
      controller.setShowSearchResults(false);
      controller.clearVisibleSearchResults();
      _logSearchActivity("Leere Suche - alle POIs ausgeblendet");
      return;
    }

    // ✅ Emoji-Shortcuts prüfen
    final shortcutQuery = CampingSearchCategories.quickSearchShortcuts[query];
    if (shortcutQuery != null) {
      if (kDebugMode) {
        print("🔍 [DEBUG] Using emoji shortcut: $query -> $shortcutQuery");
      }
      _performCampingIntelligentSearch(shortcutQuery);
      return;
    }

    final filteredResults =
        _performAdvancedCategoryFiltering(allFeatures, query);

    if (kDebugMode) {
      print("🔍 [DEBUG] Filtered results: ${filteredResults.length}");
    }

    // Standard-Suchergebnisse für Dropdown
    controller.setSearchResults(filteredResults);
    controller.setShowSearchResults(true);

    // ✅ Search-First Navigation: Sichtbare POIs setzen
    controller.setVisibleSearchResults(filteredResults);

    if (kDebugMode) {
      print(
          "🔍 [DEBUG] Search state set - Results visible: ${controller.showSearchResults}");
    }

    _logSearchActivity("Suche '$query': ${filteredResults.length} Ergebnisse");
  }

  // ✅ NEU: Erweiterte Kategorie-basierte Filterung
  List<SearchableFeature> _performAdvancedCategoryFiltering(
      List<SearchableFeature> allFeatures, String query) {
    final String cleanQuery = query.trim().toLowerCase();

    // 1. UNTERKUNFT-NUMMER (höchste Priorität)
    if (CampingSearchCategories.isAccommodationNumberSearch(cleanQuery)) {
      final accommodationResults =
          _searchAccommodationByNumber(allFeatures, cleanQuery);
      if (accommodationResults.isNotEmpty) {
        _logSearchActivity(
            "Unterkunft-Nummer gefunden: ${accommodationResults.length}");
        return accommodationResults;
      }
    }

    // 2. KATEGORIE-MATCHING
    final matchedCategory = CampingSearchCategories.matchCategory(cleanQuery);
    if (matchedCategory != null) {
      final categoryResults = _searchByCategory(allFeatures, matchedCategory);
      if (categoryResults.isNotEmpty) {
        _logSearchActivity(
            "Kategorie '${matchedCategory.displayName}' gefunden: ${categoryResults.length}");
        return _prioritizeCategoryResults(categoryResults, matchedCategory);
      }
    }

    // 3. OSM-TYPE MATCHING
    final osmResults = _searchByOsmType(allFeatures, cleanQuery);
    if (osmResults.isNotEmpty) {
      _logSearchActivity("OSM-Type gefunden: ${osmResults.length}");
      return osmResults;
    }

    // 4. FALLBACK: Name-Suche
    final nameResults = _searchByName(allFeatures, cleanQuery);
    _logSearchActivity("Name-Suche Fallback: ${nameResults.length}");
    return nameResults;
  }

  // ✅ Verbesserte Unterkunft-Nummern-Suche
  List<SearchableFeature> _searchAccommodationByNumber(
      List<SearchableFeature> features, String query) {
    // Extrahiere alle Zahlen aus der Anfrage
    final numberMatches = RegExp(r'\d+').allMatches(query);
    if (numberMatches.isEmpty) return [];

    final searchNumbers = numberMatches.map((m) => m.group(0)!).toList();

    final results = <SearchableFeature>[];

    for (final searchNum in searchNumbers) {
      // ✅ KORRIGIERT: num → searchNum
      final numberResults = features.where((feature) {
        if (!_isAccommodationType(feature.type)) return false;

        final name = feature.name.toLowerCase();

        // Verschiedene Matching-Strategien
        return name == searchNum || // Exakte Nummer
            name.contains(' $searchNum ') || // Nummer mit Leerzeichen
            name.startsWith('$searchNum ') || // Nummer am Anfang
            name.endsWith(' $searchNum') || // Nummer am Ende
            RegExp(r'\b' + searchNum + r'\b').hasMatch(name) || // Wortgrenze
            RegExp(r'^' + searchNum + r'[a-z]?$')
                .hasMatch(name); // Mit Buchstabe (247a)
      }).toList();

      results.addAll(numberResults);
    }

    // Duplikate entfernen und nach Relevanz sortieren
    final uniqueResults = results.toSet().toList();
    uniqueResults.sort((a, b) {
      // Exakte Treffer zuerst
      final aExact = searchNumbers.any((searchNum) =>
          a.name.toLowerCase() == searchNum); // ✅ KORRIGIERT: num → searchNum
      final bExact = searchNumbers.any((searchNum) =>
          b.name.toLowerCase() == searchNum); // ✅ KORRIGIERT: num → searchNum
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return a.name.compareTo(b.name);
    });

    return uniqueResults;
  }

  // ✅ Kategorie-basierte Suche
  List<SearchableFeature> _searchByCategory(
      List<SearchableFeature> features, CampingSearchCategory category) {
    return features.where((feature) {
      // OSM-Type matching
      for (final osmType in category.osmTypes) {
        if (feature.type.toLowerCase() == osmType.toLowerCase() ||
            feature.type.toLowerCase().contains(osmType.toLowerCase()) ||
            osmType.toLowerCase().contains(feature.type.toLowerCase())) {
          return true;
        }
      }

      // Name-Keyword matching (für falsch klassifizierte POIs)
      final featureName = feature.name.toLowerCase();
      for (final keyword in category.keywords) {
        if (featureName.contains(keyword.toLowerCase())) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  // ✅ OSM-Type direkte Suche
  List<SearchableFeature> _searchByOsmType(
      List<SearchableFeature> features, String query) {
    return features
        .where((feature) =>
            feature.type.toLowerCase().contains(query) ||
            query.contains(feature.type.toLowerCase()))
        .toList();
  }

  // ✅ Prioritäts-basierte Ergebnis-Sortierung
  List<SearchableFeature> _prioritizeCategoryResults(
      List<SearchableFeature> results, CampingSearchCategory category) {
    // Sortiere nach Kategorie-Priorität und Namens-Relevanz
    results.sort((a, b) {
      // Zuerst nach exakter Type-Übereinstimmung
      final aExactType = category.osmTypes.contains(a.type.toLowerCase());
      final bExactType = category.osmTypes.contains(b.type.toLowerCase());

      if (aExactType && !bExactType) return -1;
      if (!aExactType && bExactType) return 1;

      // Dann alphabetisch
      return a.name.compareTo(b.name);
    });

    return results;
  }

  // ✅ Standard Name-Suche (Fallback)
  List<SearchableFeature> _searchByName(
      List<SearchableFeature> features, String query) {
    final results = features
        .where((feature) => feature.name.toLowerCase().contains(query))
        .toList();

    // Sortiere nach Relevanz (kürzere Namen zuerst)
    results.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(query);
      final bStarts = b.name.toLowerCase().startsWith(query);

      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;

      return a.name.length.compareTo(b.name.length);
    });

    return results;
  }

  // ✅ Hilfsmethoden für Typ-Erkennung (erweitert)
  bool _isAccommodationType(String type) {
    final category = CampingSearchCategories.getCategoryByOsmType(type);
    return category?.category == CampingPOICategory.accommodation;
  }

  // ✅ Such-Aktivität Logging
  void _logSearchActivity(String message) {
    if (kDebugMode) {
      print("[CampingSearchHandler] $message");
    }
  }

  void selectFeatureAndSetPoint(SearchableFeature feature) {
    final point = feature.center;

    if (controller.activeSearchField == ActiveSearchField.start) {
      controller.startSearchController.text = feature.name;
      controller.setStartLatLng(point);
      controller.updateStartMarker();
      controller.startFocusNode.unfocus();
    } else if (controller.activeSearchField == ActiveSearchField.end) {
      controller.endSearchController.text = feature.name;
      controller.setEndLatLng(point);
      controller.updateEndMarker();
      controller.endFocusNode.unfocus();
    }

    controller.setShowSearchResults(false);

    // ✅ Feature weiterhin sichtbar lassen nach Auswahl
    controller.setVisibleSearchResults([feature]);

    // Trigger route calculation if both points are set
    if (_onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  void setStartToCurrentLocation() {
    if (controller.currentGpsPosition == null) {
      if (kDebugMode) {
        print("Aktuelle Position unbekannt.");
      }
      return;
    }

    controller.startSearchController.text = "Aktueller Standort";
    controller.setStartLatLng(controller.currentGpsPosition);
    controller.startMarker = null; // Kein Marker für die aktuelle Position
    controller.startFocusNode.unfocus();

    // ✅ Bei "Aktueller Standort" keine POIs anzeigen
    controller.clearVisibleSearchResults();

    // Trigger route calculation if both points are set
    if (_onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  void swapStartAndEnd() {
    controller.swapStartAndEnd();

    // Trigger route calculation if both points are set
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

    // ✅ POIs ausblenden beim Löschen der Suche
    controller.clearVisibleSearchResults();

    // Clear route if needed
    if (_onRouteClearNeeded != null) {
      _onRouteClearNeeded!();
    }
  }

  // Callback for when route calculation is needed - set by RouteHandler
  void Function()? _onRouteCalculationNeeded;
  void Function()? _onRouteClearNeeded;

  void setRouteCalculationCallback(void Function() callback) {
    _onRouteCalculationNeeded = callback;
  }

  void setRouteClearCallback(void Function() callback) {
    _onRouteClearNeeded = callback;
  }

  void dispose() {
    // ✅ FIX: Timer cleanup hinzugefügt
    _hideResultsTimer?.cancel();

    controller.startSearchController.removeListener(_onStartSearchChanged);
    controller.endSearchController.removeListener(_onEndSearchChanged);
    controller.startFocusNode.removeListener(_onStartFocusChanged);
    controller.endFocusNode.removeListener(_onEndFocusChanged);
  }
}
