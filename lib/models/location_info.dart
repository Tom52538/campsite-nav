// lib/models/location_info.dart

// Entfernt: import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Speichert alle relevanten Informationen für einen einzelnen Standort (Campingplatz).
class LocationInfo {
  final String id;
  final String name;
  final String geojsonAssetPath;
  final double initialLatitude;
  final double initialLongitude;
  final double radiusInMeters;

  const LocationInfo({
    required this.id,
    required this.name,
    required this.geojsonAssetPath,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.radiusInMeters,
  });

  LatLng get initialCenter => LatLng(initialLatitude, initialLongitude);
}

// Globale Liste der verfügbaren Standorte
final List<LocationInfo> appLocations = [
  const LocationInfo(
    id: "sittard",
    name: "Testgelände Sittard",
    geojsonAssetPath: "assets/data/export.geojson",
    initialLatitude: 51.02518780487824,
    initialLongitude: 5.858832278816441,
    radiusInMeters: 1000.0,
  ),
  const LocationInfo(
    id: "kamperland",
    name: "Camping Resort Kamperland",
    geojsonAssetPath: "assets/data/export_kamperland.geojson",
    initialLatitude: 51.590186,
    initialLongitude: 3.722494,
    radiusInMeters: 1500.0,
  ),
];
