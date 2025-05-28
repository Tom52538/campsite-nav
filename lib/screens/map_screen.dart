// lib/screens/map_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:vector_map_tiles/vector_map_tiles.dart'
    as vector_map_tiles; // Alias hinzugefügt
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';
import 'package:camping_osm_navi/services/tts_service.dart';

import 'map_screen_parts/map_screen_ui_mixin.dart';

// NEUER IMPORT HINZUFÜGEN
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with MapScreenUiMixin {
  final MapController mapController = MapController();
  StreamSubscription<Position>? positionStreamSubscription;

  // ... (Restlicher Code bleibt gleich)

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);

    // Ihre vorhandene Karten-Konfiguration
    // Achten Sie auf die `TileLayer` oder `VectorTileLayer` Definitionen.
    // Wenn Sie eine Fallback-OSM-Schicht haben, ändern Sie dort den TileProvider.

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter:
                  const LatLng(50.9375, 6.9603), // Beispielkoordinaten
              initialZoom: 10.0,
              onTap: _handleMapTap,
            ),
            children: [
              // Prüfen Sie, wo Ihr TileLayer oder VectorTileLayer definiert ist.
              // Hier ist ein Beispiel für den Fallback-OSM-Layer:
              // Wenn styleUrl des Vector-Themes nicht vorhanden ist oder lädt,
              // sollte dieser Fallback-Layer verwendet werden.
              if (locationProvider.selectedTestLocation != null &&
                  locationProvider.selectedTestLocation!.theme != null &&
                  locationProvider.selectedTestLocation!.themeLoaded)
                vector_map_tiles.VectorTileLayer(
                  theme: locationProvider.selectedTestLocation!.theme!,
                  // Verwenden Sie den CancellableNetworkTileProvider hier
                  // oder prüfen Sie, ob vector_map_tiles selbst eine
                  // Option für den TileProvider hat, die dies unterstützt.
                  // Da vector_map_tiles ein eigenes TileProvider-System hat,
                  // ist dieser hier primär für den Fallback-OSM-Layer relevant.
                  // Wenn vector_map_tiles keine direkte Integration hat,
                  // ist die Verbesserung hier begrenzt, außer für den Fallback.
                  backgroundPaint: Paint()..color = Colors.grey[200]!,
                  tileProviders: vector_map_tiles.TileProviders({
                    'maptiler': vector_map_tiles.NetworkTileProvider(
                        url:
                            'https://tiles.maptiler.com/data/v3/{z}/{x}/{y}.pbf?key=${dotenv.env['MAPTILER_API_KEY']}'),
                  }),
                )
              else
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.camping_osm_navi',
                  // HIER ÄNDERN: Verwenden Sie den CancellableNetworkTileProvider
                  tileProvider:
                      CancellableNetworkTileProvider(), // <-- Wichtig!
                ),
              // ... (Restliche Layer wie MarkerLayer, PolylineLayer, etc.)
            ],
          ),
          // ... (Rest der UI)
        ],
      ),
    );
  }

  // ... (Rest der Klasse)
}
