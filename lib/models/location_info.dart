// lib/models/location_info.dart

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
// Diese Liste wird später verwendet, um dem Nutzer eine Auswahl anzubieten
// und die standortspezifischen Daten zu laden.
final List<LocationInfo> appLocations = [
  LocationInfo(
    id: "sittard",
    name: "Testgelände Sittard",
    geojsonAssetPath: "assets/data/export.geojson", // Aktuell verwendete Datei
    initialLatitude:
        51.02518780487824, // Aus MapScreenState.defaultInitialCenter
    initialLongitude:
        5.858832278816441, // Aus MapScreenState.defaultInitialCenter
    radiusInMeters: 1000.0, // Beispielradius, kann angepasst/genutzt werden
  ),
  LocationInfo(
    id: "kamperland",
    name: "Camping Resort Kamperland",
    geojsonAssetPath:
        "assets/data/export_kamperland.geojson", // Muss vom Nutzer hinzugefügt werden
    initialLatitude: 51.590186, // Gemäß Plan
    initialLongitude: 3.722494, // Gemäß Plan
    radiusInMeters: 1500.0, // Beispielradius, kann angepasst/genutzt werden
  ),
  // Hier könnten zukünftig weitere Standorte hinzugefügt werden
];
