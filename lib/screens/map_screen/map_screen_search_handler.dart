// lib/screens/map_screen/map_screen_search_handler.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'map_screen_controller.dart';

class MapScreenSearchHandler {
  final MapScreenController controller;
  final BuildContext context;

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
      _performIntelligentSearch(controller.startSearchController.text);
    }
  }

  void _onEndSearchChanged() {
    if (controller.endFocusNode.hasFocus) {
      _performIntelligentSearch(controller.endSearchController.text);
    }
  }

  void _onStartFocusChanged() {
    if (controller.startFocusNode.hasFocus) {
      controller.setActiveSearchField(ActiveSearchField.start);
      controller.setRouteActiveForCardSwitch(false);
      if (controller.startSearchController.text != "Aktueller Standort") {
        _performIntelligentSearch(controller.startSearchController.text);
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
      _performIntelligentSearch(controller.endSearchController.text);
    } else {
      if (controller.activeSearchField == ActiveSearchField.end) {
        controller.setActiveSearchField(ActiveSearchField.none);
      }
      _hideSearchResultsAfterDelay();
    }
  }

  // ✅ NEU: Intelligente Such-Filterung
  void _performIntelligentSearch(String query) {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final allFeatures = locationProvider.currentSearchableFeatures;

    if (query.isEmpty) {
      // Keine Suche = keine POIs anzeigen (Search-First Prinzip)
      controller.setSearchResults([]);
      controller.setShowSearchResults(false);
      controller.clearVisibleSearchResults();
      if (kDebugMode) {
        print("[SearchHandler] Leere Suche - alle POIs ausgeblendet");
      }
      return;
    }

    final filteredResults = _filterBySearchType(allFeatures, query);

    // Standard-Suchergebnisse für Dropdown
    controller.setSearchResults(filteredResults);
    controller.setShowSearchResults(true);

    // ✅ NEU: Sichtbare POIs auf der Karte (Search-First Navigation)
    controller.setVisibleSearchResults(filteredResults);

    if (kDebugMode) {
      print(
          "[SearchHandler] Suche '$query': ${filteredResults.length} Ergebnisse gefunden");
    }
  }

  // ✅ NEU: Intelligente Filterlogik nach Such-Typ
  List<SearchableFeature> _filterBySearchType(
      List<SearchableFeature> allFeatures, String query) {
    final String cleanQuery = query.trim().toLowerCase();

    // 1. NUMERISCHE SUCHE - Unterkunft-Nummern
    if (_isNumericAccommodationSearch(cleanQuery)) {
      return _searchAccommodationByNumber(allFeatures, cleanQuery);
    }

    // 2. KATEGORIE-SUCHE - Sanitär, Gastronomie, etc.
    final categoryResults = _searchByCategory(allFeatures, cleanQuery);
    if (categoryResults.isNotEmpty) {
      return categoryResults;
    }

    // 3. NAME-SUCHE - Klassische Textsuche
    return _searchByName(allFeatures, cleanQuery);
  }

  // ✅ Prüfung auf numerische Unterkunft-Suche
  bool _isNumericAccommodationSearch(String query) {
    // Reine Zahlen oder Zahlen mit typischen Unterkunft-Präfixen
    return RegExp(r'^\d+$').hasMatch(query) ||
        RegExp(r'^(nr|no|nummer|house|haus|platz|pitch|stelle)\s*\.?\s*\d+$')
            .hasMatch(query) ||
        RegExp(r'^\d+[a-z]?$').hasMatch(query); // z.B. "247" oder "247a"
  }

  // ✅ Unterkunft nach Nummer suchen
  List<SearchableFeature> _searchAccommodationByNumber(
      List<SearchableFeature> features, String query) {
    // Extrahiere die Nummer aus verschiedenen Formaten
    final numberMatch = RegExp(r'\d+').firstMatch(query);
    if (numberMatch == null) return [];

    final searchNumber = numberMatch.group(0)!;

    final results = features.where((feature) {
      // Suche in accommodations und buildings mit Nummern
      if (!_isAccommodationType(feature.type)) return false;

      // Verschiedene Namensformate berücksichtigen
      final name = feature.name.toLowerCase();
      return name.contains(searchNumber) ||
          name == searchNumber ||
          name.endsWith(' $searchNumber') ||
          name.startsWith('$searchNumber ') ||
          RegExp(r'\b' + searchNumber + r'\b').hasMatch(name);
    }).toList();

    if (kDebugMode) {
      print(
          "[SearchHandler] Unterkunft-Suche '$searchNumber': ${results.length} gefunden");
    }

    return results;
  }

  // ✅ Kategorie-basierte Suche
  List<SearchableFeature> _searchByCategory(
      List<SearchableFeature> features, String query) {
    final Map<String, List<String>> categoryMappings = {
      'toilets': [
        'wc',
        'toilet',
        'toilette',
        'sanitär',
        'sanitary',
        'bad',
        'dusche',
        'shower'
      ],
      'parking': ['parking', 'parkplatz', 'stellplatz', 'auto', 'car'],
      'amenity': [
        'rezeption',
        'reception',
        'empfang',
        'büro',
        'office',
        'info',
        'information'
      ],
      'shop': ['shop', 'laden', 'geschäft', 'supermarkt', 'market', 'kiosk'],
      'restaurant': [
        'restaurant',
        'cafe',
        'bar',
        'gastronomie',
        'essen',
        'food',
        'snack'
      ],
      'playground': ['spielplatz', 'playground', 'kinder', 'children', 'spiel'],
      'industrial': [
        'technik',
        'technical',
        'service',
        'wartung',
        'maintenance'
      ],
      'tourism': ['sehenswürdigkeit', 'attraction', 'tourism', 'sightseeing'],
      'building': ['gebäude', 'building', 'haus', 'house'],
    };

    for (final category in categoryMappings.keys) {
      final keywords = categoryMappings[category]!;

      if (keywords.any((keyword) => query.contains(keyword))) {
        final results = features
            .where((feature) =>
                feature.type.toLowerCase() == category ||
                feature.type.toLowerCase().contains(category) ||
                (category == 'amenity' && _isAmenityType(feature.type)))
            .toList();

        if (results.isNotEmpty) {
          if (kDebugMode) {
            print(
                "[SearchHandler] Kategorie-Suche '$category': ${results.length} gefunden");
          }
          return results;
        }
      }
    }

    return [];
  }

  // ✅ Standard Name-Suche (Fallback)
  List<SearchableFeature> _searchByName(
      List<SearchableFeature> features, String query) {
    final results = features
        .where((feature) => feature.name.toLowerCase().contains(query))
        .toList();

    if (kDebugMode) {
      print("[SearchHandler] Name-Suche '$query': ${results.length} gefunden");
    }

    return results;
  }

  // ✅ Hilfsmethoden für Typ-Erkennung
  bool _isAccommodationType(String type) {
    final accommodationTypes = [
      'accommodation',
      'building',
      'house',
      'pitch',
      'camp_pitch',
      'holiday_home',
      'chalet',
      'bungalow',
      'lodge',
      'cabin'
    ];
    return accommodationTypes.contains(type.toLowerCase()) ||
        type.toLowerCase().contains('comfort') ||
        type.toLowerCase().contains('wellness') ||
        type.toLowerCase().contains('luxury');
  }

  bool _isAmenityType(String type) {
    final amenityTypes = [
      'reception',
      'information',
      'office',
      'service_point',
      'tourist_info',
      'admin'
    ];
    return amenityTypes.contains(type.toLowerCase());
  }

  void _hideSearchResultsAfterDelay() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!controller.startFocusNode.hasFocus &&
          !controller.endFocusNode.hasFocus) {
        controller.setShowSearchResults(false);
        // ✅ NEU: Auch sichtbare POIs ausblenden wenn kein Focus
        controller.clearVisibleSearchResults();
      }
    });
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

    // ✅ NEU: Feature weiterhin sichtbar lassen nach Auswahl
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

    // ✅ NEU: Bei "Aktueller Standort" keine POIs anzeigen
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

    // ✅ NEU: POIs ausblenden beim Löschen der Suche
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
    controller.startSearchController.removeListener(_onStartSearchChanged);
    controller.endSearchController.removeListener(_onEndSearchChanged);
    controller.startFocusNode.removeListener(_onStartFocusChanged);
    controller.endFocusNode.removeListener(_onEndFocusChanged);
  }
}
