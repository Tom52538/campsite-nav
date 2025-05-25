// lib/models/location_info.dart

import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationInfo {
  final String id;
  final String name;
  final String geojsonAssetPath;
  final double initialLatitude;
  final double initialLongitude;
  final double radiusInMeters;
  final String styleId; // NEU
  final String styleUrl; // NEU

  const LocationInfo({
    required this.id,
    required this.name,
    required this.geojsonAssetPath,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.radiusInMeters,
    required this.styleId, // NEU
    required this.styleUrl, // NEU
  });

  LatLng get initialCenter => LatLng(initialLatitude, initialLongitude);
}

// Globale Liste der verfügbaren Standorte
// Wir verwenden einen besseren Stil von MapTiler: "dataviz"
final List<LocationInfo> appLocations = [
  LocationInfo(
    id: "sittard",
    name: "Testgelände Sittard",
    geojsonAssetPath: "assets/data/export.geojson",
    initialLatitude: 51.02518780487824,
    initialLongitude: 5.858832278816441,
    radiusInMeters: 1000.0,
    styleId: "maptiler_dataviz_sittard",
    styleUrl:
        "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
  ),
  LocationInfo(
    id: "kamperland",
    name: "Camping Resort Kamperland",
    geojsonAssetPath: "assets/data/export_kamperland.geojson",
    initialLatitude: 51.590186,
    initialLongitude: 3.722494,
    radiusInMeters: 1500.0,
    styleId: "maptiler_dataviz_kamperland",
    styleUrl:
        "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
  ),
  LocationInfo(
    id: "zuhause_gangelt",
    name: "Umgebung Zuhause (Gangelt)",
    geojsonAssetPath: "assets/data/zuhause_umgebung.geojson",
    initialLatitude: 51.001466,
    initialLongitude: 6.051130,
    radiusInMeters: 500.0,
    styleId: "maptiler_dataviz_gangelt",
    styleUrl:
        "https://api.maptiler.com/maps/dataviz/style.json?key=${dotenv.env['MAPTILER_API_KEY']}",
  ),
];
