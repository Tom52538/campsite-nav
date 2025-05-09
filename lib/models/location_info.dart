// lib/models/location_info.dart

import 'package:flutter/foundation.dart'; // Import für kDebugMode, falls hier verwendet, sonst optional
import 'package:latlong2/latlong.dart';

/// Speichert alle relevanten Informationen für einen einzelnen Standort (Campingplatz).
class LocationInfo {
  final String id; // Eindeutiger Identifikator, z.B. "sittard", "kamperland"
  final String name; // Anzeigename, z.B. "Testgelände Sittard"
  final String
      geojsonAssetPath; // Pfad zur GeoJSON-Datei im App-Asset-Verzeichnis
  final double initialLatitude; // Start-Breitengrad für die Kartenansicht
  final double initialLongitude; // Start-Längengrad für die Kartenansicht
  // Radius für die initiale Kartenansicht oder zur Definition des relevanten Bereichs.
  // Die genaue Verwendung (z.B. zur Ableitung eines Zoomlevels) muss ggf. noch definiert werden.
  final double radiusInMeters;

  const LocationInfo({
    // Konstruktor ist bereits const
    required this.id,
    required this.name,
    required this.geojsonAssetPath,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.radiusInMeters,
  });

  // Helper, um die initialen Koordinaten als LatLng-Objekt zu erhalten
  LatLng get initialCenter => LatLng(initialLatitude, initialLongitude);
}

// Globale Liste der verfügbaren Standorte
final List<LocationInfo> appLocations = [
  const LocationInfo(
    // NEU: const hinzugefügt
    id: "sittard",
    name: "Testgelände Sittard",
    geojsonAssetPath: "assets/data/export.geojson",
    initialLatitude: 51.02518780487824,
    initialLongitude: 5.858832278816441,
    radiusInMeters: 1000.0,
  ),
  const LocationInfo(
    // NEU: const hinzugefügt
    id: "kamperland",
    name: "Camping Resort Kamperland",
    geojsonAssetPath: "assets/data/export_kamperland.geojson",
    initialLatitude: 51.590186,
    initialLongitude: 3.722494,
    radiusInMeters: 1500.0,
  ),
];
