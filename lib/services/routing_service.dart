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

  static const double slightTurnThreshold = 35.0;
  static const double normalTurnThreshold = 75.0;
  static const double sharpTurnThreshold = 135.0;
  static const double uTurnAngleThreshold = 165.0;

  // ✅ NEU: Rerouting Konstanten
  static const double offRouteThresholdMeters = 30.0;
  static const int rerouteDelaySeconds = 3;

  static Future<List<LatLng>?> findPath(
      RoutingGraph graph, GraphNode startNode, GraphNode endNode) async {
    try {
      return _dijkstra(graph, startNode, endNode);
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print("[RoutingService.findPath] Fehler während Dijkstra: $e");
        print("[RoutingService.findPath] Stacktrace: $stacktrace");
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
          print(
              "[RoutingService._dijkstra] Fehler beim Holen aus PriorityQueue: $e");
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
      // print warning if needed
    }

    if (path.isEmpty) {
      return null;
    } else {
      final reversedPath = path.reversed.toList();
      return reversedPath;
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

  // ✅ NEU: Echtzeit-Aktualisierung von Zeit und Entfernung
  static ({double remainingDistance, int remainingTimeMinutes})?
      calculateRemainingRouteInfo(
          LatLng currentPosition, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return null;

    // Finde nächstgelegenen Punkt auf der Route
    int nearestPointIndex =
        _findNearestPointOnRoute(currentPosition, routePoints);
    if (nearestPointIndex == -1) return null;

    // Berechne verbleibende Distanz ab nächstem Routenpunkt
    double remainingDistance = 0.0;
    for (int i = nearestPointIndex; i < routePoints.length - 1; i++) {
      remainingDistance +=
          _distanceCalculator(routePoints[i], routePoints[i + 1]);
    }

    // Addiere Distanz von aktueller Position zum nächsten Routenpunkt
    if (nearestPointIndex < routePoints.length) {
      remainingDistance +=
          _distanceCalculator(currentPosition, routePoints[nearestPointIndex]);
    }

    int remainingTimeMinutes = estimateWalkingTimeMinutes(remainingDistance);

    return (
      remainingDistance: remainingDistance,
      remainingTimeMinutes: remainingTimeMinutes
    );
  }

  // ✅ NEU: Off-Route Erkennung
  static bool isOffRoute(LatLng currentPosition, List<LatLng> routePoints,
      {double thresholdMeters = offRouteThresholdMeters}) {
    if (routePoints.isEmpty) return false;

    double minDistanceToRoute = double.infinity;

    // Prüfe Distanz zu allen Routensegmenten
    for (int i = 0; i < routePoints.length - 1; i++) {
      double distanceToSegment = _distanceToLineSegment(
          currentPosition, routePoints[i], routePoints[i + 1]);
      minDistanceToRoute = min(minDistanceToRoute, distanceToSegment);
    }

    return minDistanceToRoute > thresholdMeters;
  }

  // ✅ NEU: Automatische Routenneuberechnung
  static Future<List<LatLng>?> recalculateRoute(
      RoutingGraph graph, LatLng currentPosition, LatLng destination) async {
    // Finde nächste Knoten für aktuelle Position und Ziel
    final startNode = graph.findNearestNode(currentPosition);
    final endNode = graph.findNearestNode(destination);

    if (startNode == null || endNode == null) {
      if (kDebugMode) {
        print(
            "[RoutingService.recalculateRoute] Start- oder Endknoten nicht gefunden");
      }
      return null;
    }

    // Graph-Kosten zurücksetzen vor neuer Berechnung
    graph.resetAllNodeCosts();

    if (kDebugMode) {
      print(
          "[RoutingService.recalculateRoute] Neuberechnung von ${startNode.id} zu ${endNode.id}");
    }

    return await findPath(graph, startNode, endNode);
  }

  // ✅ HILFSMETHODEN
  static int _findNearestPointOnRoute(
      LatLng currentPosition, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return -1;

    double minDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < routePoints.length; i++) {
      double distance = _distanceCalculator(currentPosition, routePoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  static double _distanceToLineSegment(
      LatLng point, LatLng lineStart, LatLng lineEnd) {
    // Vereinfachte Implementierung: Distanz zum nächsten Endpunkt
    double distToStart = _distanceCalculator(point, lineStart);
    double distToEnd = _distanceCalculator(point, lineEnd);
    return min(distToStart, distToEnd);
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

      if (p1 == p2 || p2 == p3) {
        continue;
      }

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
        final maneuver = Maneuver(
            point: p2,
            turnType: turnType,
            instructionText: _getInstructionTextForTurnType(turnType));
        maneuvers.add(maneuver);
      }
    }

    maneuvers.add(Maneuver(
        point: routePoints.last,
        turnType: TurnType.arrive,
        instructionText: _getInstructionTextForTurnType(TurnType.arrive)));

    return maneuvers;
  }
}
