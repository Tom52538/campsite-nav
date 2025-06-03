// lib/models/camping_search_categories.dart - ROOMPOT RESORT OPTIMIERT
enum CampingPOICategory {
  accommodation, // Unterkünfte (Parzellen, Häuser, etc.)
  amenity, // Services (Rezeption, Information)
  sanitary, // Sanitär (WC, Dusche, etc.)
  food, // Gastronomie (Restaurant, Café, Bar)
  shopping, // Einkaufen (Shop, Supermarkt)
  recreation, // Freizeit (Spielplatz, Pool, Sport)
  parking, // Parkplätze - ROOMPOT FOKUS!
  utility, // Versorgung (Müll, Wasser, Strom)
  medical, // Medizinisch (Erste Hilfe)
  transport, // Transport (Bus, etc.)
  waterSports, // NEU: Wassersport (für Beach Resort) - FIXED: camelCase
  family, // NEU: Familien-Aktivitäten
}

class CampingSearchCategory {
  final CampingPOICategory category;
  final String displayName;
  final String icon;
  final List<String> keywords;
  final List<String> osmTypes;
  final int priority; // Höher = wichtiger bei Suchergebnissen
  final bool isRoompotPriority; // NEU: Markiert Resort-spezifische Kategorien

  const CampingSearchCategory({
    required this.category,
    required this.displayName,
    required this.icon,
    required this.keywords,
    required this.osmTypes,
    required this.priority,
    this.isRoompotPriority = false, // NEU
  });
}

// ✅ ROOMPOT-OPTIMIERTE Camping-Kategorien
class CampingSearchCategories {
  static const List<CampingSearchCategory> categories = [
    
    // 🅿️ PARKPLÄTZE - HÖCHSTE PRIORITÄT FÜR ROOMPOT (81 POIs!)
    CampingSearchCategory(
      category: CampingPOICategory.parking,
      displayName: "Parkplätze",
      icon: "🅿️",
      keywords: [
        'parking', 'parkplatz', 'parkplätze', 'parken',
        'stellplatz', 'auto', 'car', 'fahrzeug', 'garage',
        'tiefgarage', 'parkhaus', 'parkzone', 'p1', 'p2', 'p3',
        // ROOMPOT-SPEZIFISCH:
        'guest parking', 'visitor parking', 'holiday parking',
        'resort parking', 'beach parking', 'villa parking'
      ],
      osmTypes: [
        'parking', 'parking_space', 'garage', 'parking_entrance',
        'amenity=parking', 'leisure=parking'
      ],
      priority: 10, // HÖCHSTE PRIORITÄT
      isRoompotPriority: true,
    ),

    // 🎠 FAMILIEN & SPIELPLÄTZE - ROOMPOT FOKUS
    CampingSearchCategory(
      category: CampingPOICategory.family,
      displayName: "Familie & Kinder",
      icon: "👨‍👩‍👧‍👦",
      keywords: [
        'spielplatz', 'playground', 'kinder', 'children', 'kids',
        'spiel', 'spielbereich', 'spielwiese', 'kinderspielplatz',
        'familie', 'family', 'kinderbetreuung', 'animation',
        // ROOMPOT-SPEZIFISCH:
        'kids club', 'kinderclub', 'miniclub', 'playground area',
        'family area', 'kinderbereich', 'spielzone'
      ],
      osmTypes: [
        'playground', 'leisure=playground', 'amenity=playground',
        'tourism=attraction', 'leisure=recreation_ground'
      ],
      priority: 9,
      isRoompotPriority: true,
    ),

    // 🏊 WASSERSPORT & STRAND - BEACH RESORT SPEZIFISCH
    CampingSearchCategory(
      category: CampingPOICategory.waterSports,
      displayName: "Wassersport & Strand",
      icon: "🏄‍♂️",
      keywords: [
        'pool', 'schwimmbad', 'schwimmen', 'swimming', 'beach', 'strand',
        'wassersport', 'water sport', 'surfing', 'surfen', 'sailing',
        'segeln', 'diving', 'tauchen', 'water', 'wasser',
        // ROOMPOT BEACH RESORT SPEZIFISCH:
        'beach access', 'strandzugang', 'water village', 'aqua park',
        'swimming pool', 'outdoor pool', 'indoor pool', 'spa'
      ],
      osmTypes: [
        'swimming_pool', 'leisure=swimming_pool', 'natural=beach',
        'leisure=beach_resort', 'sport=swimming', 'sport=diving',
        'sport=sailing', 'amenity=spa'
      ],
      priority: 8,
      isRoompotPriority: true,
    ),

    // 🏠 UNTERKÜNFTE - Erweitert für Resort
    CampingSearchCategory(
      category: CampingPOICategory.accommodation,
      displayName: "Unterkünfte",
      icon: "🏠",
      keywords: [
        // Standard Keywords
        'nr', 'nummer', 'no', 'house', 'haus', 'platz', 'pitch', 'stelle',
        'parzelle', 'unterkunft', 'accommodation',
        // ROOMPOT RESORT SPEZIFISCH:
        'villa', 'chalet', 'bungalow', 'lodge', 'cabin', 'ferienhaus',
        'holiday home', 'vacation rental', 'comfort', 'wellness', 
        'luxury', 'premium', 'standard', 'basic', 'beach house',
        'mobilheim', 'caravan', 'wohnwagen', 'wohnmobil'
      ],
      osmTypes: [
        'accommodation', 'building', 'house', 'pitch', 'camp_pitch',
        'holiday_home', 'chalet', 'bungalow', 'lodge', 'cabin',
        'tourism=chalet', 'tourism=holiday_home'
      ],
      priority: 7,
      isRoompotPriority: true,
    ),

    // 🍽️ GASTRONOMIE - Resort-Restaurants
    CampingSearchCategory(
      category: CampingPOICategory.food,
      displayName: "Restaurants & Bars",
      icon: "🍽️",
      keywords: [
        'restaurant', 'restaurants', 'gastronomie', 'cafe', 'café',
        'kaffee', 'coffee', 'bar', 'bars', 'kneipe', 'pub',
        'snack', 'snackbar', 'imbiss', 'bistro', 'essen', 'food',
        // ROOMPOT SPEZIFISCH:
        'beach bar', 'poolbar', 'resort restaurant', 'main restaurant',
        'buffet', 'à la carte', 'takeaway', 'pizza', 'grill'
      ],
      osmTypes: [
        'restaurant', 'cafe', 'bar', 'pub', 'fast_food',
        'food_court', 'snack_bar', 'bistro', 'amenity=restaurant',
        'amenity=cafe', 'amenity=bar'
      ],
      priority: 6,
      isRoompotPriority: true,
    ),

    // 🚿 SANITÄR - Wichtig für Resort-Gäste
    CampingSearchCategory(
      category: CampingPOICategory.sanitary,
      displayName: "Sanitär & WC",
      icon: "🚿",
      keywords: [
        'wc', 'toilet', 'toilette', 'toiletten', 'klo', 'sanitär',
        'sanitary', 'bad', 'bäder', 'waschraum', 'dusche', 'duschen',
        'shower', 'showers', 'waschhaus', 'sanitärhaus', 'sanitärgebäude',
        // ROOMPOT SPEZIFISCH:
        'restroom', 'bathroom', 'wash facility', 'shower block'
      ],
      osmTypes: [
        'toilets', 'sanitary', 'shower', 'bathroom', 'restroom',
        'amenity=toilets', 'amenity=shower', 'sanitary_dump_station'
      ],
      priority: 5,
    ),

    // ℹ️ SERVICES - Rezeption & Info
    CampingSearchCategory(
      category: CampingPOICategory.amenity,
      displayName: "Service & Info",
      icon: "ℹ️",
      keywords: [
        'rezeption', 'reception', 'empfang', 'anmeldung', 'check-in',
        'büro', 'office', 'verwaltung', 'administration', 'info',
        'information', 'tourist-info', 'auskunft', 'service',
        // ROOMPOT SPEZIFISCH:
        'guest services', 'concierge', 'resort office', 'help desk'
      ],
      osmTypes: [
        'reception', 'information', 'office', 'tourist_information',
        'amenity=information', 'tourism=information'
      ],
      priority: 4,
    ),

    // 🛒 EINKAUFEN - Resort Shops
    CampingSearchCategory(
      category: CampingPOICategory.shopping,
      displayName: "Shopping",
      icon: "🛒",
      keywords: [
        'shop', 'laden', 'geschäft', 'store', 'supermarkt', 'market',
        'markt', 'minimarkt', 'kiosk', 'convenience', 'lebensmittel',
        'einkaufen', 'shopping', 'verkauf',
        // ROOMPOT SPEZIFISCH:
        'resort shop', 'holiday shop', 'beach shop', 'souvenir'
      ],
      osmTypes: [
        'shop', 'supermarket', 'convenience', 'kiosk', 'marketplace',
        'shop=convenience', 'shop=supermarket'
      ],
      priority: 3,
    ),

    // ⚽ FREIZEIT & SPORT
    CampingSearchCategory(
      category: CampingPOICategory.recreation,
      displayName: "Sport & Freizeit",
      icon: "⚽",
      keywords: [
        'sport', 'sportplatz', 'tennis', 'fußball', 'volleyball',
        'basketball', 'animation', 'unterhaltung', 'entertainment',
        'fitness', 'gym', 'wellness', 'spa',
        // ROOMPOT SPEZIFISCH:
        'sports center', 'activity center', 'recreation', 'leisure'
      ],
      osmTypes: [
        'sports_centre', 'pitch', 'tennis', 'football', 'volleyball',
        'basketball', 'fitness_centre', 'leisure=sports_centre'
      ],
      priority: 2,
    ),

    // ⚡ VERSORGUNG
    CampingSearchCategory(
      category: CampingPOICategory.utility,
      displayName: "Versorgung",
      icon: "⚡",
      keywords: [
        'müll', 'mülltonne', 'abfall', 'waste', 'disposal',
        'wasser', 'water', 'trinkwasser', 'drinking_water',
        'strom', 'electricity', 'stromanschluss', 'power'
      ],
      osmTypes: [
        'waste_disposal', 'waste_basket', 'drinking_water',
        'water_point', 'power', 'amenity=waste_disposal'
      ],
      priority: 1,
    ),
  ];

  // ✅ ROOMPOT-SPEZIFISCHE QUICK-SEARCH SHORTCUTS - FIXED: Keine Duplikate
  static const Map<String, String> roompotQuickSearchShortcuts = {
    // ROOMPOT-SPEZIFISCHE SHORTCUTS
    '🏖️': 'beach', // Strand-Zugang
    '🏊': 'pool', // Schwimmbäder
    '👨‍👩‍👧‍👦': 'family', // Familien-Bereiche
    '🏠': 'villa', // Unterkünfte
    '🛒': 'shop', // Resort Shopping
  };

  // ✅ STANDARD QUICK-SEARCH SHORTCUTS - FIXED: Separate Map
  static const Map<String, String> standardQuickSearchShortcuts = {
    '🚿': 'wc',
    '🍽️': 'restaurant', 
    '🅿️': 'parkplatz',
    'ℹ️': 'rezeption',
    '⚽': 'spielplatz',
  };

  // ✅ COMBINED SHORTCUTS - FIXED: Merge Maps ohne Duplikate
  static const Map<String, String> quickSearchShortcuts = {
    ...roompotQuickSearchShortcuts,
    ...standardQuickSearchShortcuts,
  };

  // ✅ ROOMPOT PRIORITY SEARCH - Zeigt wichtigste Kategorien zuerst
  static List<CampingSearchCategory> getRoompotPriorityCategories() {
    return categories.where((cat) => cat.isRoompotPriority).toList();
  }

  // ✅ Erweiterte Parkplatz-Suche (wichtig bei 81 Parkplätzen!)
  static List<String> getParkingSpecificKeywords() {
    return [
      // Parkplatz-Nummern
      'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8', 'p9', 'p10',
      // Bereiche
      'hauptparkplatz', 'main parking', 'central parking',
      'beach parking', 'villa parking', 'restaurant parking',
      // Typen
      'guest parking', 'visitor parking', 'disabled parking',
      'family parking', 'oversized parking'
    ];
  }

  // ✅ Bestehende Methoden bleiben unverändert
  static CampingSearchCategory? matchCategory(String query) {
    final cleanQuery = query.trim().toLowerCase();

    for (final category in categories) {
      for (final keyword in category.keywords) {
        if (cleanQuery.contains(keyword.toLowerCase()) ||
            keyword.toLowerCase().contains(cleanQuery)) {
          return category;
        }
      }
    }
    return null;
  }

  static CampingSearchCategory? getCategoryByOsmType(String osmType) {
    final cleanType = osmType.trim().toLowerCase();

    for (final category in categories) {
      for (final type in category.osmTypes) {
        if (cleanType == type.toLowerCase() ||
            cleanType.contains(type.toLowerCase()) ||
            type.toLowerCase().contains(cleanType)) {
          return category;
        }
      }
    }
    return null;
  }

  static List<CampingSearchCategory> getSortedCategories() {
    final sorted = List<CampingSearchCategory>.from(categories);
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
  }

  static bool isAccommodationNumberSearch(String query) {
    final cleanQuery = query.trim().toLowerCase();

    if (RegExp(r'^\d+$').hasMatch(cleanQuery)) return true;
    if (RegExp(r'^\d+[a-z]$').hasMatch(cleanQuery)) return true;
    if (RegExp(r'^(nr|no|nummer|haus|platz|stelle|parzelle|villa)\.?\s*\d+[a-z]?$')
        .hasMatch(cleanQuery)) return true;
    if (RegExp(r'^(house|pitch|site|lot|villa|chalet)\.?\s*\d+[a-z]?$')
        .hasMatch(cleanQuery)) return true;

    return false;
  }

  // ✅ NEUE ROOMPOT-SPEZIFISCHE METHODEN
  static bool isParkingSearch(String query) {
    final cleanQuery = query.trim().toLowerCase();
    final parkingKeywords = getParkingSpecificKeywords();
    
    return parkingKeywords.any((keyword) => 
        cleanQuery.contains(keyword) || keyword.contains(cleanQuery));
  }

  static bool isFamilySearch(String query) {
    final cleanQuery = query.trim().toLowerCase();
    final familyKeywords = ['family', 'familie', 'kinder', 'kids', 'children', 
                           'playground', 'spielplatz', 'animation'];
    
    return familyKeywords.any((keyword) => 
        cleanQuery.contains(keyword) || keyword.contains(cleanQuery));
  }

  static bool isWaterSportsSearch(String query) {
    final cleanQuery = query.trim().toLowerCase();
    final waterKeywords = ['pool', 'beach', 'strand', 'swimming', 'water', 
                          'wassersport', 'surf', 'sail'];
    
    return waterKeywords.any((keyword) => 
        cleanQuery.contains(keyword) || keyword.contains(cleanQuery));
  }
}