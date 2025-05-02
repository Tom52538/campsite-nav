// lib/services/geojson_parser_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';

class GeojsonParserService {
  // Konstante für die Distanzberechnung
  static const Distance _distance = Distance();

  // Set von Highway-Typen, die für das Routing berücksichtigt werden sollen
  static const Set<String> _routableHighwayTypes = {
    'service',
    'footway',
    'cycleway',
    'path', // 'path' könnte auch relevant sein, falls vorhanden
    'track',
    'unclassified',
    'tertiary',
    'residential',
    'living_street',
    'pedestrian',
    'platform' // Bushaltestellen-Plattformen könnten auch begehbar sein
  };

  // Hauptmethode zum Parsen der GeoJSON-Daten und Erstellen des Graphen
  static RoutingGraph parseGeoJson(String geoJsonString) {
    final RoutingGraph graph = RoutingGraph();
    final decodedJson = jsonDecode(geoJsonString);

    if (kDebugMode) {
      print("Starte GeoJSON Parsing für Routing-Graph...");
    }

    if (decodedJson is Map<String, dynamic> &&
        decodedJson['type'] == 'FeatureCollection' &&
        decodedJson['features'] is List) {
      List features = decodedJson['features'];
      int processedWays = 0;

      for (var feature in features) {
        if (feature is Map<String, dynamic> &&
            feature['geometry'] is Map<String, dynamic>) {
          final geometry = feature['geometry'];
          final properties = Map<String, dynamic>.from(
              feature['properties'] ?? <String, dynamic>{});
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];

          // Nur LineString-Features verarbeiten, die einen relevanten Highway-Typ haben
          if (type == 'LineString' &&
              properties['highway'] != null &&
              _routableHighwayTypes.contains(properties['highway'])) {
            if (coordinates is List && coordinates.length >= 2) {
              processedWays++;
              bool isOneway = properties['oneway'] == 'yes';
              GraphNode? previousNode;

              for (var coord in coordinates) {
                if (coord is List &&
                    coord.length >= 2 &&
                    coord[0] is num &&
                    coord[1] is num) {
                  try {
                    final LatLng currentLatLng =
                        LatLng(coord[1].toDouble(), coord[0].toDouble());
                    // Knoten für die aktuelle Position hinzufügen (oder bestehenden holen)
                    final GraphNode currentNode = graph.addNode(currentLatLng);

                    // Wenn es einen vorherigen Knoten gab, eine Kante hinzufügen
                    if (previousNode != null) {
                      final double weight = _distance(
                          previousNode.position, currentNode.position);
                      // Nur Kanten mit einer Distanz > 0 hinzufügen (vermeidet Kanten zu sich selbst)
                      if (weight > 0) {
                        graph.addEdge(previousNode, currentNode, weight,
                            oneway: isOneway);
                      }
                    }
                    // Aktuellen Knoten für den nächsten Schritt merken
                    previousNode = currentNode;
                  } catch (e) {
                    if (kDebugMode) {
                      print(
                          "Fehler beim Verarbeiten einer Koordinate im LineString: $e");
                    }
                  }
                }
              }
            }
          }
        }
      }
      if (kDebugMode) {
        print(
            "Routing-Graph Parsing abgeschlossen. ${graph.nodes.length} Knoten erstellt aus $processedWays Wegen.");
      }
    } else {
      if (kDebugMode) {
        print("Fehler: GeoJSON ist keine gültige FeatureCollection.");
      }
      // Wir geben trotzdem einen leeren Graphen zurück, anstatt einen Fehler zu werfen
    }
    return graph;
  }
}
