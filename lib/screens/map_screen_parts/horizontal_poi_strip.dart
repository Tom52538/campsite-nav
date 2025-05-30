// lib/screens/map_screen_parts/horizontal_poi_strip.dart
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen_parts/map_screen_ui_mixin.dart';

class HorizontalPOIStrip extends StatelessWidget with MapScreenUiMixin {
  final List<SearchableFeature> features;
  final Function(SearchableFeature) onFeatureTap;
  final double keyboardHeight;
  final bool isVisible;

  const HorizontalPOIStrip({
    super.key,
    required this.features,
    required this.onFeatureTap,
    this.keyboardHeight = 0,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || features.isEmpty) return const SizedBox.shrink();

    // Position über der Tastatur oder am unteren Bildschirmrand
    final bottomPadding = keyboardHeight > 0 ? keyboardHeight + 10 : 100;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPadding,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ✅ Header mit Ergebnis-Count und Hinweis
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    "${features.length} gefunden",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.swipe_horizontal,
                      size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    "scrollen",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            // ✅ Horizontale POI-Liste
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: features.length,
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return _buildCompactPOICard(feature, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPOICard(SearchableFeature feature, int index) {
    final color = _getColorForPOIType(feature.type);
    final isAccommodation = _isAccommodationType(feature.type);

    return GestureDetector(
      onTap: () => onFeatureTap(feature),
      child: AnimatedContainer(
        duration:
            Duration(milliseconds: 100 + (index * 50)), // Gestaffelte Animation
        width: isAccommodation ? 130 : 110, // Unterkünfte breiter
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color,
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Icon mit Kategorie-Badge für Unterkünfte
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    getIconForFeatureType(feature.type),
                    size: 22,
                    color: color,
                  ),
                  if (isAccommodation && _extractNumber(feature.name) != null)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Text(
                          _extractNumber(feature.name)!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // ✅ Name mit intelligenter Kürzung
              Text(
                _shortenPOIName(feature.name),
                style: TextStyle(
                  fontSize: isAccommodation ? 11 : 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.1,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Intelligente Name-Kürzung für bessere Lesbarkeit
  String _shortenPOIName(String name) {
    // Entferne redundante Wörter
    String shortened = name
        .replaceAll(
            RegExp(r'\b(Camping|Resort|Hotel|Restaurant|Café|Bar|Shop)\b',
                caseSensitive: false),
            '')
        .trim();

    // Falls zu lang, kürze intelligent
    if (shortened.length > 20) {
      final words = shortened.split(' ');
      if (words.length > 2) {
        return '${words.first} ${words[1]}';
      } else {
        return shortened.substring(0, 17) + '...';
      }
    }

    return shortened.isNotEmpty ? shortened : name;
  }

  // ✅ Extrahiere Nummer aus Unterkunfts-Namen
  String? _extractNumber(String name) {
    final match =
        RegExp(r'\b(\d+[a-z]?)\b', caseSensitive: false).firstMatch(name);
    return match?.group(1);
  }

  // ✅ Prüfe ob es eine Unterkunft ist
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
        type.toLowerCase().contains('wellness');
  }

  // ✅ Erweiterte Farb-Zuordnung
  Color _getColorForPOIType(String type) {
    switch (type.toLowerCase()) {
      // Gastronomie - Warme Farben
      case 'restaurant':
      case 'cafe':
        return const Color(0xFFE57373); // Warmes Rot

      case 'bar':
      case 'pub':
      case 'fast_food':
      case 'snack_bar':
        return const Color(0xFFFFB74D); // Orange

      // Unterkünfte - Erdtöne
      case 'accommodation':
      case 'building':
      case 'house':
      case 'pitch':
      case 'camp_pitch':
        return const Color(0xFF8D6E63); // Braun

      // Services - Blautöne
      case 'reception':
      case 'information':
      case 'amenity':
        return const Color(0xFF42A5F5); // Blau

      // Einkaufen - Lila
      case 'shop':
      case 'supermarket':
      case 'convenience':
        return const Color(0xFFAB47BC); // Lila

      // Transport - Grün
      case 'bus_stop':
      case 'parking':
        return const Color(0xFF66BB6A); // Grün

      // Sanitär - Cyan
      case 'toilets':
      case 'sanitary':
      case 'shower':
        return const Color(0xFF26C6DA); // Cyan

      // Freizeit - Pink
      case 'playground':
      case 'swimming_pool':
      case 'sports_centre':
        return const Color(0xFFEC407A); // Pink

      // Fallback
      default:
        return const Color(0xFF78909C); // Grau-Blau
    }
  }
}
