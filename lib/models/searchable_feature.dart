// lib/models/searchable_feature.dart

import 'package:latlong2/latlong.dart'; // Stellt sicher, dass das latlong2 Paket importiert ist

/// Repräsentiert ein Feature auf der Karte, das durchsucht werden kann.
class SearchableFeature {
  final dynamic id; // Eindeutige ID (z.B. OSM-ID)
  final String name; // Anzeigename des Features (z.B. aus 'name' Tag)
  final String type; // Typ des Features (z.B. 'building', 'amenity', 'highway')
  final LatLng center; // Koordinaten zum Zentrieren der Karte

  SearchableFeature({
    required this.id,
    required this.name,
    required this.type,
    required this.center,
  });

  @override
  String toString() {
    return 'SearchableFeature{id: $id, name: $name, type: $type, center: $center}';
  }

  // Optional: Gleichheit und HashCode überschreiben, wenn nötig
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchableFeature &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
