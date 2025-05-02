// lib/models/graph_edge.dart

import 'graph_node.dart';

/// Repräsentiert eine Kante (Verbindung) zwischen zwei Knoten im Routing-Graphen.
/// Eine Kante entspricht einem direkten Wegsegment.
class GraphEdge {
  final GraphNode fromNode; // Startknoten der Kante
  final GraphNode toNode; // Endknoten der Kante
  final double weight; // Kosten der Kante (z.B. Distanz in Metern)

  GraphEdge(
      {required this.fromNode, required this.toNode, required this.weight});

  @override
  String toString() {
    return 'GraphEdge{from: ${fromNode.id}, to: ${toNode.id}, weight: ${weight.toStringAsFixed(2)}}';
  }
}
