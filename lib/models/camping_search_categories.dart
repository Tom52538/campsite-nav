// lib/models/camping_search_categories.dart
enum CampingPOICategory {
  accommodation, // Unterkünfte (Parzellen, Häuser, etc.)
  amenity, // Services (Rezeption, Information)
  sanitary, // Sanitär (WC, Dusche, etc.)
  food, // Gastronomie (Restaurant, Café, Bar)
  shopping, // Einkaufen (Shop, Supermarkt)
  recreation, // Freizeit (Spielplatz, Pool, Sport)
  parking, // Parkplätze
  utility, // Versorgung (Müll, Wasser, Strom)
  medical, // Medizinisch (Erste Hilfe)
  transport, // Transport (Bus, etc.)
}

class CampingSearchCategory {
  final CampingPOICategory category;
  final String displayName;
  final String icon;
  final List<String> keywords;
  final List<String> osmTypes;
  final int priority; // Höher = wichtiger bei Suchergebnissen

  const CampingSearchCategory({
    required this.category,
    required this.displayName,
    required this.icon,
    required this.keywords,
    required this.osmTypes,
    required this.priority,
  });
}

// ✅ Definierte Camping-Kategorien mit deutschen Keywords
class CampingSearchCategories {
  static const List<CampingSearchCategory> categories = [
    // 1. UNTERKÜNFTE - Höchste Priorität für Nummern-Suche
    CampingSearchCategory(
      category: CampingPOICategory.accommodation,
      displayName: "Unterkünfte",
      icon: "🏠",
      keywords: [
        // Nummern
        'nr', 'nummer', 'no', 'house', 'haus', 'platz', 'pitch', 'stelle',
        'parzelle',
        // Unterkunftstypen
        'unterkunft', 'accommodation', 'chalet', 'bungalow', 'lodge', 'cabin',
        'ferienhaus',
        'comfort', 'wellness', 'luxury', 'premium', 'standard', 'basic',
        // Deutsche Camping-Begriffe
        'stellplatz', 'wohnwagen', 'wohnmobil', 'zelt', 'caravan', 'mobilheim'
      ],
      osmTypes: [
        'accommodation',
        'building',
        'house',
        'pitch',
        'camp_pitch',
        'holiday_home',
        'chalet',
        'bungalow',
        'lodge',
        'cabin',
        'comfort',
        'wellness',
        'luxury',
        'premium'
      ],
      priority: 10,
    ),

    // 2. SANITÄR - Sehr wichtig auf Campingplätzen
    CampingSearchCategory(
      category: CampingPOICategory.sanitary,
      displayName: "Sanitär",
      icon: "🚿",
      keywords: [
        'wc',
        'toilet',
        'toilette',
        'toiletten',
        'klo',
        'sanitär',
        'sanitary',
        'bad',
        'bäder',
        'waschraum',
        'dusche',
        'duschen',
        'shower',
        'showers',
        'waschhaus',
        'sanitärhaus',
        'sanitärgebäude'
      ],
      osmTypes: [
        'toilets',
        'sanitary',
        'shower',
        'bathroom',
        'restroom',
        'sanitary_dump_station',
        'washing'
      ],
      priority: 9,
    ),

    // 3. SERVICES - Rezeption, Information
    CampingSearchCategory(
      category: CampingPOICategory.amenity,
      displayName: "Service",
      icon: "ℹ️",
      keywords: [
        'rezeption',
        'reception',
        'empfang',
        'anmeldung',
        'check-in',
        'büro',
        'office',
        'verwaltung',
        'administration',
        'info',
        'information',
        'tourist-info',
        'auskunft',
        'service',
        'servicepoint',
        'servicestelle'
      ],
      osmTypes: [
        'reception',
        'information',
        'office',
        'tourist_information',
        'amenity',
        'service_point',
        'admin'
      ],
      priority: 8,
    ),

    // 4. GASTRONOMIE
    CampingSearchCategory(
      category: CampingPOICategory.food,
      displayName: "Gastronomie",
      icon: "🍽️",
      keywords: [
        'restaurant',
        'restaurants',
        'gastronomie',
        'cafe',
        'café',
        'kaffee',
        'coffee',
        'bar',
        'bars',
        'kneipe',
        'pub',
        'snack',
        'snackbar',
        'imbiss',
        'bistro',
        'essen',
        'food',
        'dining',
        'küche'
      ],
      osmTypes: [
        'restaurant',
        'cafe',
        'bar',
        'pub',
        'fast_food',
        'food_court',
        'snack_bar',
        'bistro'
      ],
      priority: 7,
    ),

    // 5. EINKAUFEN
    CampingSearchCategory(
      category: CampingPOICategory.shopping,
      displayName: "Einkaufen",
      icon: "🛒",
      keywords: [
        'shop',
        'laden',
        'geschäft',
        'store',
        'supermarkt',
        'market',
        'markt',
        'minimarkt',
        'kiosk',
        'convenience',
        'lebensmittel',
        'einkaufen',
        'shopping',
        'verkauf'
      ],
      osmTypes: [
        'shop',
        'supermarket',
        'convenience',
        'kiosk',
        'marketplace',
        'retail'
      ],
      priority: 6,
    ),

    // 6. FREIZEIT
    CampingSearchCategory(
      category: CampingPOICategory.recreation,
      displayName: "Freizeit",
      icon: "⚽",
      keywords: [
        'spielplatz',
        'playground',
        'kinder',
        'children',
        'kids',
        'spiel',
        'spielbereich',
        'spielwiese',
        'pool',
        'schwimmbad',
        'schwimmen',
        'swimming',
        'sport',
        'sportplatz',
        'tennis',
        'fußball',
        'volleyball',
        'animation',
        'unterhaltung',
        'entertainment',
        'sauna',
        'wellness',
        'fitness'
      ],
      osmTypes: [
        'playground',
        'swimming_pool',
        'sports_centre',
        'pitch',
        'tennis',
        'football',
        'volleyball',
        'basketball',
        'fitness_centre',
        'sauna'
      ],
      priority: 5,
    ),

    // 7. PARKPLÄTZE
    CampingSearchCategory(
      category: CampingPOICategory.parking,
      displayName: "Parkplätze",
      icon: "🅿️",
      keywords: [
        'parking',
        'parkplatz',
        'parkplätze',
        'parken',
        'stellplatz',
        'auto',
        'car',
        'fahrzeug',
        'garage',
        'tiefgarage'
      ],
      osmTypes: ['parking', 'parking_space', 'garage'],
      priority: 4,
    ),

    // 8. VERSORGUNG
    CampingSearchCategory(
      category: CampingPOICategory.utility,
      displayName: "Versorgung",
      icon: "⚡",
      keywords: [
        'müll',
        'mülltonne',
        'abfall',
        'waste',
        'disposal',
        'wasser',
        'water',
        'trinkwasser',
        'drinking_water',
        'strom',
        'electricity',
        'stromanschluss',
        'power',
        'entsorgung',
        'waste_disposal',
        'recycling'
      ],
      osmTypes: [
        'waste_disposal',
        'waste_basket',
        'recycling',
        'drinking_water',
        'water_point',
        'power'
      ],
      priority: 3,
    ),

    // 9. MEDIZINISCH
    CampingSearchCategory(
      category: CampingPOICategory.medical,
      displayName: "Medizin",
      icon: "🏥",
      keywords: [
        'erste hilfe',
        'first aid',
        'medical',
        'medizin',
        'krankenhaus',
        'hospital',
        'arzt',
        'doctor',
        'apotheke',
        'pharmacy',
        'notfall',
        'emergency'
      ],
      osmTypes: [
        'hospital',
        'clinic',
        'pharmacy',
        'first_aid',
        'emergency',
        'medical'
      ],
      priority: 2,
    ),

    // 10. TRANSPORT
    CampingSearchCategory(
      category: CampingPOICategory.transport,
      displayName: "Transport",
      icon: "🚌",
      keywords: [
        'bus',
        'bushaltestelle',
        'bus_stop',
        'haltestelle',
        'transport',
        'öpnv',
        'public_transport',
        'taxi',
        'shuttle'
      ],
      osmTypes: ['bus_stop', 'bus_station', 'taxi', 'public_transport'],
      priority: 1,
    ),
  ];

  // ✅ Kategorie-Matching für intelligente Suche
  static CampingSearchCategory? matchCategory(String query) {
    final cleanQuery = query.trim().toLowerCase();

    // Durchsuche alle Kategorien nach Keywords
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

  // ✅ OSM-Type zu Kategorie Mapping
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

  // ✅ Prioritäts-basierte Sortierung
  static List<CampingSearchCategory> getSortedCategories() {
    final sorted = List<CampingSearchCategory>.from(categories);
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
  }

  // ✅ Numerische Unterkunft-Erkennung (erweitert)
  static bool isAccommodationNumberSearch(String query) {
    final cleanQuery = query.trim().toLowerCase();

    // Reine Zahlen
    if (RegExp(r'^\d+$').hasMatch(cleanQuery)) return true;

    // Zahlen mit Buchstaben (247a, 15b)
    if (RegExp(r'^\d+[a-z]$').hasMatch(cleanQuery)) return true;

    // Deutsche Muster
    if (RegExp(r'^(nr|no|nummer|haus|platz|stelle|parzelle)\.?\s*\d+[a-z]?$')
        .hasMatch(cleanQuery)) return true;

    // Englische Muster
    if (RegExp(r'^(house|pitch|site|lot)\.?\s*\d+[a-z]?$').hasMatch(cleanQuery))
      return true;

    return false;
  }

  // ✅ Quick-Search Shortcuts für häufige Anfragen
  static const Map<String, String> quickSearchShortcuts = {
    '🚿': 'wc', // Sanitär-Emoji → WC Suche
    '🍽️': 'restaurant', // Essen-Emoji → Restaurant Suche
    '🅿️': 'parkplatz', // Parking-Emoji → Parkplatz Suche
    'ℹ️': 'rezeption', // Info-Emoji → Rezeption Suche
    '⚽': 'spielplatz', // Sport-Emoji → Spielplatz Suche
  };
}
