// lib/models/routing_graph.dart

import 'graph_node.dart';
import 'package:latlong2/latlong.dart';

/// Repräsentiert den gesamten Routing-Graphen, bestehend aus Knoten und Kanten.
class RoutingGraph {
  // Speichert alle Knoten des Graphen, zugreifbar über ihre eindeutige ID.
  final Map<String, GraphNode> nodes = {};

  // Fügt einen Knoten hinzu oder gibt den existierenden Knoten für eine Position zurück.
  GraphNode addNode(LatLng position) {
    final nodeId = GraphNode.createId(position);
    // Nur hinzufügen, wenn nicht bereits vorhanden
    nodes.putIfAbsent(nodeId, () => GraphNode(position: position));
    return nodes[nodeId]!;
  }

  // Fügt eine Kante zwischen zwei Knoten hinzu.
  // Berücksichtigt optional Einbahnstraßen (standardmäßig in beide Richtungen).
  void addEdge(GraphNode fromNode, GraphNode toNode, double weight,
      {bool oneway = false}) {
    // Stelle sicher, dass beide Knoten im Graphen existieren (sollte durch addNode passieren)
    if (nodes.containsKey(fromNode.id) && nodes.containsKey(toNode.id)) {
      // Kante von fromNode -> toNode hinzufügen
      fromNode.addEdge(
          GraphEdge(fromNode: fromNode, toNode: toNode, weight: weight));

      // Wenn keine Einbahnstraße, auch Kante von toNode -> fromNode hinzufügen
      if (!oneway) {
        toNode.addEdge(
            GraphEdge(fromNode: toNode, toNode: fromNode, weight: weight));
      }
    } else {
      // Optional: Fehlerbehandlung oder Log, falls Knoten nicht gefunden wurden
      print(
          "Warnung: Knoten nicht im Graph gefunden beim Hinzufügen der Kante.");
    }
  }

  // Findet den nächstgelegenen Knoten im Graphen zu einem gegebenen Punkt.
  GraphNode? findNearestNode(LatLng point) {
    GraphNode? nearestNode;
    double minDistance = double.infinity;
    const Distance distance = Distance(); // Für Distanzberechnungen

    nodes.values.forEach((node) {
      final double dist = distance(point, node.position);
      if (dist < minDistance) {
        minDistance = dist;
        nearestNode = node;
      }
    });
    return nearestNode;
  }

  // Setzt die Kosten aller Knoten zurück (wichtig vor jeder neuen Routenberechnung)
  void resetAllNodeCosts() {
    nodes.values.forEach((node) => node.resetCosts());
  }

  @override
  String toString() {
    return 'RoutingGraph{nodes: ${nodes.length}}';
  }
}
