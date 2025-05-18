// lib/services/routing_service.dart
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:flutter/foundation.dart';
import 'package:camping_osm_navi/models/maneuver.dart';

class RoutingService {
  static const double averageWalkingSpeedKmh = 4.5;
  static const Distance _distanceCalculator = Distance();

  static Future<List<LatLng>?> findPath(
      RoutingGraph graph, GraphNode startNode, GraphNode endNode) async {
    try {
      return _dijkstra(graph, startNode, endNode);
    } catch (e) {
      // Linter: unused_catch_stack (stacktrace entfernt)
      if (kDebugMode) {
        // print("Fehler während Dijkstra: $e");
      }
      return null;
    }
  }

  static List<LatLng>? _dijkstra(
      RoutingGraph graph, GraphNode startNode, GraphNode endNode) {
    final priorityQueue =
        PriorityQueue<GraphNode>((a, b) => a.gCost.compareTo(b.gCost));

    startNode.gCost = 0;
    priorityQueue.add(startNode);

    final Set<String> visitedNodes = {};

    while (priorityQueue.isNotEmpty) {
      GraphNode currentNode;
      try {
        if (priorityQueue.isEmpty) {
          break;
        }
        currentNode = priorityQueue.removeFirst();
      } catch (e) {
        if (kDebugMode) {
          // print("Fehler beim Holen aus PriorityQueue in Dijkstra: $e");
        }
        continue;
      }

      if (visitedNodes.contains(currentNode.id)) {
        continue;
      }
      visitedNodes.add(currentNode.id);

      if (currentNode.id == endNode.id) {
        return _reconstructPath(endNode);
      }

      for (final edge in currentNode.edges) {
        final GraphNode neighborNode = edge.toNode;

        if (visitedNodes.contains(neighborNode.id)) {
          continue;
        }

        final double tentativeGCost = currentNode.gCost + edge.weight;

        if (tentativeGCost < neighborNode.gCost) {
          neighborNode.parent = currentNode;
          neighborNode.gCost = tentativeGCost;
          priorityQueue.add(neighborNode);
        }
      }
    }

    if (kDebugMode) {
      // print("Dijkstra: Zielknoten ${endNode.id} nicht erreichbar von ${startNode.id}.");
    }
    return null;
  }

  static List<LatLng>? _reconstructPath(GraphNode endNode) {
    final List<LatLng> path = [];
    GraphNode? currentNode = endNode;
    int safetyBreak = 0;
    const int maxPathLength = 10000;

    while (currentNode != null && safetyBreak < maxPathLength) {
      path.add(currentNode.position);
      currentNode = currentNode.parent;
      safetyBreak++;
    }

    if (safetyBreak >= maxPathLength && kDebugMode) {
      // print("WARNUNG: Pfadrekonstruktion abgebrochen (maximale Länge erreicht). Möglicherweise Kreis im Parent-Graph?");
    }

    if (path.isEmpty) {
      return null;
    } else {
      return path.reversed.toList();
    }
  }

  static double calculateTotalDistance(List<LatLng> routePoints) {
    double totalDistance = 0.0;
    if (routePoints.length < 2) {
      return totalDistance;
    }
    for (int i = 0; i < routePoints.length - 1; i++) {
      totalDistance += _distanceCalculator(routePoints[i], routePoints[i + 1]);
    }
    return totalDistance;
  }

  static int estimateWalkingTimeMinutes(double totalDistanceMeters,
      {double speedKmh = averageWalkingSpeedKmh}) {
    if (totalDistanceMeters <= 0 || speedKmh <= 0) {
      return 0;
    }
    final double distanceKm = totalDistanceMeters / 1000.0;
    final double timeHours = distanceKm / speedKmh;
    final double timeMinutes = timeHours * 60;
    return timeMinutes.round();
  }

  static String _getInstructionTextForTurnType(TurnType turnType) {
    switch (turnType) {
      case TurnType.depart:
        return "Route starten";
      case TurnType.slightLeft:
        return "Leicht links halten";
      case TurnType.slightRight:
        return "Leicht rechts halten";
      case TurnType.turnLeft:
        return "Links abbiegen";
      case TurnType.turnRight:
        return "Rechts abbiegen";
      case TurnType.sharpLeft:
        return "Scharf links abbiegen";
      case TurnType.sharpRight:
        return "Scharf rechts abbiegen";
      case TurnType.uTurnLeft:
        return "Bitte wenden (linksherum)";
      case TurnType.uTurnRight:
        return "Bitte wenden (rechtsherum)";
      case TurnType.straight:
        return "Geradeaus weiter";
      case TurnType.arrive:
        return "Sie haben Ihr Ziel erreicht";
    }
  }

  static List<Maneuver> analyzeRouteForTurns(List<LatLng> routePoints) {
    if (routePoints.length < 2) {
      return [];
    }

    final List<Maneuver> maneuvers = [];
    maneuvers.add(Maneuver(
        point: routePoints.first,
        turnType: TurnType.depart,
        instructionText: _getInstructionTextForTurnType(TurnType.depart)));

    if (routePoints.length < 3) {
      if (routePoints.length == 2) {
        maneuvers.add(Maneuver(
            point: routePoints.last,
            turnType: TurnType.arrive,
            instructionText: _getInstructionTextForTurnType(TurnType.arrive)));
      }
      return maneuvers;
    }

    for (int i = 0; i < routePoints.length - 2; i++) {
      final LatLng p1 = routePoints[i];
      final LatLng p2 = routePoints[i + 1];
      final LatLng p3 = routePoints[i + 2];

      double dx1 = p2.longitude - p1.longitude;
      double dy1 = p2.latitude - p1.latitude;
      double angle1 = atan2(dy1, dx1);

      double dx2 = p3.longitude - p2.longitude;
      double dy2 = p3.latitude - p2.latitude;
      double angle2 = atan2(dy2, dx2);

      double angleDiff = angle2 - angle1;
      while (angleDiff <= -pi) {
        angleDiff += 2 * pi;
      }
      while (angleDiff > pi) {
        angleDiff -= 2 * pi;
      }
      double angleDegrees = angleDiff * 180 / pi;

      TurnType turnType = TurnType.straight;

      const double slightTurnThreshold = 35.0;
      const double normalTurnThreshold = 75.0;
      const double sharpTurnThreshold = 135.0;
      const double uTurnAngleThreshold = 165.0;

      if (angleDegrees > slightTurnThreshold &&
          angleDegrees <= normalTurnThreshold) {
        turnType = TurnType.slightRight;
      } else if (angleDegrees > normalTurnThreshold &&
          angleDegrees <= sharpTurnThreshold) {
        turnType = TurnType.turnRight;
      } else if (angleDegrees > sharpTurnThreshold &&
          angleDegrees < uTurnAngleThreshold) {
        turnType = TurnType.sharpRight;
      } else if (angleDegrees >= uTurnAngleThreshold ||
          angleDegrees <= -uTurnAngleThreshold) {
        if (angleDegrees > 0) {
          turnType = TurnType.uTurnRight;
        } else {
          turnType = TurnType.uTurnLeft;
        }
      } else if (angleDegrees < -slightTurnThreshold &&
          angleDegrees >= -normalTurnThreshold) {
        turnType = TurnType.slightLeft;
      } else if (angleDegrees < -normalTurnThreshold &&
          angleDegrees >= -sharpTurnThreshold) {
        turnType = TurnType.turnLeft;
      } else if (angleDegrees < -sharpTurnThreshold &&
          angleDegrees > -uTurnAngleThreshold) {
        turnType = TurnType.sharpLeft;
      }

      if (turnType != TurnType.straight) {
        maneuvers.add(Maneuver(
            point: p2,
            turnType: turnType,
            instructionText: _getInstructionTextForTurnType(turnType)));
      }
    }

    maneuvers.add(Maneuver(
        point: routePoints.last,
        turnType: TurnType.arrive,
        instructionText: _getInstructionTextForTurnType(TurnType.arrive)));

    if (kDebugMode) {
      // print("[RoutingService] Analyzed route for turns: ${maneuvers.length} maneuvers found.");
      // for (var maneuver in maneuvers) {
      //   print(maneuver);
      // }
    }
    return maneuvers;
  }
}
