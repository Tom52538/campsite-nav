// lib/services/routing_service.dart

import 'package:collection/collection.dart'; // Wird jetzt verwendet
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:flutter/foundation.dart';

class RoutingService {
  /// Findet den kürzesten Pfad zwischen zwei Knoten im Graphen mithilfe des Dijkstra-Algorithmus.
  ///
  /// Gibt eine Liste von LatLng-Koordinaten zurück, die den Pfad repräsentieren,
  /// oder null, wenn kein Pfad gefunden wurde.
  static Future<List<LatLng>?> findPath(
      RoutingGraph graph, GraphNode startNode, GraphNode endNode) async {
    // Hinweis: Für sehr große Graphen könnte man dies mit compute() auslagern.
    // return compute(_dijkstra, {'graph': graph, 'startNodeId': startNode.id, 'endNodeId': endNode.id});

    // Direkte Ausführung für dieses Projekt:
    try {
      return _dijkstra(graph, startNode, endNode);
    } catch (e) {
      if (kDebugMode) {
        print("Fehler während Dijkstra: $e");
      }
      return null; // Fehler -> kein Pfad
    }
  }

  // Die eigentliche Dijkstra-Logik
  static List<LatLng>? _dijkstra(
      RoutingGraph graph, GraphNode startNode, GraphNode endNode) {
    // Prioritätswarteschlange für Knoten, sortiert nach Kosten (gCost)
    // Verwendet GraphNode direkt, da gCost dort definiert ist.
    final priorityQueue =
        PriorityQueue<GraphNode>((a, b) => a.gCost.compareTo(b.gCost));

    // WICHTIG: Es wird davon ausgegangen, dass resetAllNodeCosts()
    // VOR dem Aufruf von findPath in main.dart aufgerufen wurde!
    // Ansonsten hier nochmals alle Kosten zurücksetzen:
    // graph.resetAllNodeCosts(); // Nicht ideal, da potenziell redundant

    // Startknoten initialisieren
    startNode.gCost = 0;
    priorityQueue.add(startNode);

    // Set zum Verfolgen von bereits vollständig besuchten Knoten (optional, kann Performance leicht verbessern)
    final Set<String> visitedNodes = {};

    while (priorityQueue.isNotEmpty) {
      // Knoten mit den geringsten Kosten aus der Queue holen
      GraphNode currentNode;
      try {
        // .removeFirst() kann Exception werfen, wenn die Queue modifiziert wird, während man iteriert
        // was bei unserem PriorityQueue-Workaround passieren *könnte*. Sicherer ist, es zu prüfen.
        if (priorityQueue.isEmpty) break;
        currentNode = priorityQueue.removeFirst();
      } catch (e) {
        if (kDebugMode) print("Fehler beim Holen aus PriorityQueue: $e");
        continue; // Nächste Iteration versuchen
      }

      // Wenn wir diesen Knoten schon final besucht haben, überspringen
      // (Nützlich wegen des PriorityQueue-Workarounds, wo Knoten mehrfach drin sein können)
      if (visitedNodes.contains(currentNode.id)) {
        continue;
      }
      visitedNodes.add(currentNode.id);

      // Ziel erreicht?
      if (currentNode.id == endNode.id) {
        // Pfad erfolgreich gefunden und rekonstruieren
        return _reconstructPath(endNode);
      }

      // Nachbarn untersuchen
      for (final edge in currentNode.edges) {
        final GraphNode neighborNode = edge.toNode;

        // Überspringe Nachbarn, die schon final besucht wurden
        if (visitedNodes.contains(neighborNode.id)) {
          continue;
        }

        final double tentativeGCost = currentNode.gCost + edge.weight;

        // Besseren Weg zum Nachbarn gefunden?
        if (tentativeGCost < neighborNode.gCost) {
          neighborNode.parent = currentNode; // Vorgänger setzen
          neighborNode.gCost = tentativeGCost;

          // Nachbarn zur Queue hinzufügen oder aktualisieren
          // Da wir kein decrease-key haben, entfernen wir (falls vorhanden) und fügen neu hinzu.
          // Das ist nicht optimal performant, aber funktional.
          // Eine Prüfung mit contains() vorher ist für die Logik nicht zwingend nötig,
          // aber das explizite Entfernen *kann* helfen, die Queue kleiner zu halten.
          bool alreadyInQueue = priorityQueue.contains(neighborNode);
          if (alreadyInQueue) {
            try {
              // Versuch, die alte Version zu entfernen (kann fehlschlagen, wenn nicht mehr drin)
              priorityQueue.remove(neighborNode);
            } catch (e) {
              // Ignorieren, wenn Entfernen fehlschlägt
            }
          }
          priorityQueue
              .add(neighborNode); // Neu hinzufügen mit aktualisierten Kosten
        }
      }
    }

    // Schleife beendet, ohne das Ziel zu erreichen
    if (kDebugMode) {
      print(
          "Dijkstra: Zielknoten ${endNode.id} nicht erreichbar von ${startNode.id}.");
    }
    return null;
  }

  /// Rekonstruiert den Pfad vom Zielknoten rückwärts zum Startknoten.
  static List<LatLng>? _reconstructPath(GraphNode endNode) {
    final List<LatLng> path = [];
    GraphNode? currentNode = endNode; // Start beim Ziel

    int safetyBreak = 0; // Um Endlosschleifen bei Fehlern zu vermeiden
    const int maxPathLength = 10000; // Annahme: Kein Pfad ist länger

    while (currentNode != null && safetyBreak < maxPathLength) {
      path.add(currentNode.position);
      currentNode = currentNode.parent; // Gehe zum Vorgänger
      safetyBreak++;
    }

    if (safetyBreak >= maxPathLength && kDebugMode) {
      print(
          "WARNUNG: Pfadrekonstruktion abgebrochen (maximale Länge erreicht). Möglicherweise Kreis im Parent-Graph?");
    }

    // Der Pfad ist jetzt von Ziel -> Start, also umdrehen
    if (path.isEmpty) {
      return null; // Sollte nicht passieren, wenn endNode nicht null war
    } else {
      return path.reversed.toList();
    }
  }
}
