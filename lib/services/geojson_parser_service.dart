// lib/services/geojson_parser_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';

class GeojsonParserService {
  static const Distance _distance = Distance();
  static const Set<String> _routableHighwayTypes = {
    'service',
    'footway',
    'cycleway',
    'path',
    'track',
    'unclassified',
    'tertiary',
    'residential',
    'living_street',
    'pedestrian',
    'platform'
  };

  // Die alte Methode - kann vorerst bleiben, wird aber vom LocationProvider nicht mehr genutzt
  static RoutingGraph parseGeoJson(String geoJsonString) {
    final RoutingGraph graph = RoutingGraph();
    final decodedJson = jsonDecode(geoJsonString);

    if (kDebugMode) {
      print(
          "[GeojsonParserService] Starte GeoJSON Parsing für Routing-Graph (alte Methode)...");
    }

    if (decodedJson is Map<String, dynamic> &&
        decodedJson['type'] == 'FeatureCollection' &&
        decodedJson['features'] is List) {
      List featuresJson = decodedJson['features'];
      int processedWays = 0;

      for (var feature in featuresJson) {
        if (feature is Map<String, dynamic> &&
            feature['geometry'] is Map<String, dynamic>) {
          final geometry = feature['geometry'];
          final properties = Map<String, dynamic>.from(
              feature['properties'] ?? <String, dynamic>{});
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];

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
                    final GraphNode currentNode = graph.addNode(currentLatLng);
                    if (previousNode != null) {
                      final double weight = _distance(
                          previousNode.position, currentNode.position);
                      if (weight > 0) {
                        graph.addEdge(previousNode, currentNode, weight,
                            oneway: isOneway);
                      }
                    }
                    previousNode = currentNode;
                  } catch (e) {
                    if (kDebugMode) {
                      print(
                          "[GeojsonParserService] Fehler beim Verarbeiten einer Koordinate im LineString (alte Methode): $e");
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
            "[GeojsonParserService] Routing-Graph Parsing (alte Methode) abgeschlossen. ${graph.nodes.length} Knoten erstellt aus $processedWays Wegen.");
      }
    } else {
      if (kDebugMode) {
        print(
            "[GeojsonParserService] Fehler (alte Methode): GeoJSON ist keine gültige FeatureCollection.");
      }
    }
    return graph;
  }

  // NEUE METHODE, die Graph und Features zurückgibt
  static ({RoutingGraph graph, List<SearchableFeature> features})
      parseGeoJsonToGraphAndFeatures(String geoJsonString) {
    if (kDebugMode) {
      print("[GeojsonParserService] Starte parseGeoJsonToGraphAndFeatures...");
    }

    final RoutingGraph graph = RoutingGraph();
    final List<SearchableFeature> searchableFeatures = [];
    final dynamic decodedJson =
        jsonDecode(geoJsonString); // Einmal decodieren für beide Operationen

    // --- Logik zur Erstellung des RoutingGraphen ---
    if (decodedJson is Map<String, dynamic> &&
        decodedJson['type'] == 'FeatureCollection' &&
        decodedJson['features'] is List) {
      List featuresJsonList = decodedJson['features'];
      int processedWays = 0;

      for (var featureData in featuresJsonList) {
        if (featureData is Map<String, dynamic> &&
            featureData['geometry'] is Map<String, dynamic>) {
          final geometry = featureData['geometry'];
          final properties = Map<String, dynamic>.from(
              featureData['properties'] ?? <String, dynamic>{});
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];

          // Graph-Erstellung
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
                    final GraphNode currentNode = graph.addNode(currentLatLng);
                    if (previousNode != null) {
                      final double weight = _distance(
                          previousNode.position, currentNode.position);
                      if (weight > 0) {
                        graph.addEdge(previousNode, currentNode, weight,
                            oneway: isOneway);
                      }
                    }
                    previousNode = currentNode;
                  } catch (e) {
                    if (kDebugMode) {
                      print(
                          "[GeojsonParserService] Fehler Koordinate (Graph): $e");
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
            "[GeojsonParserService] Graph-Teil: ${graph.nodes.length} Knoten aus $processedWays Wegen.");
      }
    } else {
      if (kDebugMode) {
        print(
            "[GeojsonParserService] Fehler: GeoJSON ist keine gültige FeatureCollection für Graphen.");
      }
    }
    // --- Ende Logik zur Erstellung des RoutingGraphen ---

    // --- Logik zur Extraktion der SearchableFeatures (aus _internalExtractSearchableFeatures) ---
    // Rufe die private Hilfsmethode auf, die den bereits dekodierten JSON verwendet
    searchableFeatures.addAll(_internalExtractSearchableFeatures(decodedJson));
    // --- Ende Logik zur Extraktion der SearchableFeatures ---

    if (kDebugMode) {
      print(
          "[GeojsonParserService] parseGeoJsonToGraphAndFeatures abgeschlossen. Graph-Knoten: ${graph.nodes.length}, Features: ${searchableFeatures.length}");
    }
    return (graph: graph, features: searchableFeatures);
  }

  // NEUE PRIVATE STATISCHE HILFSMETHODE
  // (Logik aus MapScreenState._extractSearchableFeaturesFromGeoJson wurde hierher verschoben und angepasst)
  static List<SearchableFeature> _internalExtractSearchableFeatures(
      dynamic decodedJson) {
    final List<SearchableFeature> features = [];

    if (kDebugMode) {
      print(
          "[GeojsonParserService] Starte _internalExtractSearchableFeatures...");
    }

    if (decodedJson is Map<String, dynamic> &&
        decodedJson['type'] == 'FeatureCollection' &&
        decodedJson['features'] is List) {
      int featureCount = 0;
      for (final featureJson in decodedJson['features'] as List) {
        featureCount++;
        if (featureJson is Map<String, dynamic>) {
          final properties = featureJson['properties'] as Map<String, dynamic>?;
          final geometry = featureJson