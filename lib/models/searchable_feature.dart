// lib/models/searchable_feature.dart

import 'package:latlong2/latlong.dart';

/// Repräsentiert ein Feature auf der Karte, das durchsucht werden kann.
class SearchableFeature {
  final dynamic id;
  final String name;
  final String type;
  final LatLng center;

  // Convenience getters für Kompatibilität
  double get lat => center.latitude;
  double get lon => center.longitude;

  SearchableFeature({
    required this.id,
    required this.name,
    required this.type,
    required this.center,
  });

  // Alternative Konstruktor für lat/lon
  SearchableFeature.fromLatLon({
    required this.id,
    required this.name,
    required this.type,
    required double lat,
    required double lon,
  }) : center = LatLng(lat, lon);

  @override
  String toString() {
    return 'SearchableFeature{id: $id, name: $name, type: $type, center: $center}';
  }

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
