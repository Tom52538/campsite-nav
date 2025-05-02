// lib/models/graph_node.dart

import 'package:latlong2/latlong.dart';
import 'graph_edge.dart'; // Import für GraphEdge hinzufügen

/// Repräsentiert einen Knoten im Routing-Graphen.
/// Ein Knoten entspricht einem Punkt (LatLng) auf einem Weg.
class GraphNode {
  final LatLng position;
  // Eindeutige ID basierend auf der Position (für einfachen Vergleich/Lookup)
  final String id;
  // Kanten, die *von* diesem Knoten ausgehen
  final List<GraphEdge> edges = [];

  // Zusätzliche Felder für A*-Algorithmus (werden später benötigt)
  double gCost = double.infinity; // Kosten vom Startknoten zu diesem Knoten
  double hCost =
      double.infinity; // Heuristische Kosten von diesem Knoten zum Zielknoten
  double get fCost => gCost + hCost; // Gesamtkosten
  GraphNode? parent; // Vorgängerknoten auf dem kürzesten Pfad

  // KORREKTUR: Methode ist jetzt public (kein Unterstrich)
  GraphNode({required this.position}) : id = createId(position);

  // Eindeutige ID aus LatLng erstellen (für Map-Keys und Vergleiche)
  // KORREKTUR: Methode ist jetzt public (kein Unterstrich) und static
  static String createId(LatLng pos) {
    // Rundung, um kleine Ungenauigkeiten zu vermeiden
    return '${pos.latitude.toStringAsFixed(7)}_${pos.longitude.toStringAsFixed(7)}';
  }

  void addEdge(GraphEdge edge) {
    edges.add(edge);
  }

  // Methode zum Zurücksetzen der Kosten für eine neue Suche
  void resetCosts() {
    gCost = double.infinity;
    hCost = double.infinity;
    parent = null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphNode &&
          runtimeType == other.runtimeType &&
          id == other.id; // Vergleich über ID

  @override
  int get hashCode => id.hashCode; // HashCode basierend auf ID

  @override
  String toString() {
    return 'GraphNode{id: $id, position: $position}';
  }
}
