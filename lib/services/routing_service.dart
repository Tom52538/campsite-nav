// [Start lib/services/routing_service.dart Überarbeitet für Linter]
import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:flutter/foundation.dart'; // Import für kDebugMode

class RoutingService {
  static Future<List<LatLng>?> findPath(
      RoutingGraph graph, GraphNode startNode, GraphNode endNode) async {
    try {
      // Für dieses Projekt kann _dijkstra direkt aufgerufen werden.
      // Für sehr große Graphen könnte man compute() in Betracht ziehen, um UI-Blockaden zu vermeiden:
      // return await compute(_dijkstraIsolate, {'graph': graph, 'startNodeId': startNode.id, 'endNodeId': endNode.id});
      return _dijkstra(graph, startNode, endNode);
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print("Fehler während Dijkstra: $e");
        print(stacktrace);
      }
      return null;
    }
  }

  // Isolate-Wrapper für Dijkstra (optional, falls Performance-Probleme auftreten)
  // static List<LatLng>? _dijkstraIsolate(Map<String, dynamic> params) {
  //   final RoutingGraph graph = params['graph'] as RoutingGraph;
  //   final String startNodeId = params['startNodeId'] as String;
  //   final String endNodeId = params['endNodeId'] as String;
  //   // Knoten im Isolate neu abrufen, da Objekte nicht direkt übergeben werden können, wenn sie komplexe Abhängigkeiten haben.
  //   // Diese Implementierung geht davon aus, dass der Graph selbst serialisierbar ist oder
  //   // dass wir die relevanten Teile des Graphen (Knoten-IDs, Kanten) übergeben und im Isolate rekonstruieren.
  //   // Für dieses Projekt ist die direkte Ausführung von _dijkstra wahrscheinlich ausreichend.
  //   final startNode = graph.nodes[startNodeId];
  //   final endNode = graph.nodes[endNodeId];

  //   if (startNode == null || endNode == null) {
  //     if (kDebugMode) {
  //       print("_dijkstraIsolate: Start- oder Endknoten nicht im Graphen gefunden.");
  //     }
  //     return null;
  //   }
  //   return _dijkstra(graph, startNode, endNode);
  // }


  static List<LatLng>? _dijkstra(
      RoutingGraph graph, GraphNode startNode, GraphNode endNode) {
    final priorityQueue = PriorityQueue<GraphNode>((a, b) => a.gCost.compareTo(b.gCost));
    
    // WICHTIG: Es wird davon ausgegangen, dass resetAllNodeCosts()
    // VOR dem Aufruf von findPath in main.dart aufgerufen wurde!
    // graph.resetAllNodeCosts(); // Nicht hier, da es in main.dart passieren sollte.

    startNode.gCost = 0;
    priorityQueue.add(startNode);
    
    final Set<String> visitedNodes = {}; // Um bereits final besuchte Knoten zu überspringen

    while (priorityQueue.isNotEmpty) {
      GraphNode currentNode;
      try {
        if (priorityQueue.isEmpty) break; // Sollte durch while-Bedingung abgedeckt sein
        currentNode = priorityQueue.removeFirst();
      } catch (e) {
        if (kDebugMode) {
          print("Fehler beim Holen aus PriorityQueue in Dijkstra: $e");
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
          
          // Standard-Workaround für PriorityQueue ohne decrease-key:
          // Entfernen (falls vorhanden) und neu hinzufügen, um die Priorität zu aktualisieren.
          // Das explizite Entfernen ist nicht immer nötig, wenn die Queue Duplikate mit unterschiedlichen Kosten verarbeiten kann
          // und immer das mit den niedrigsten Kosten zuerst nimmt. Die `collection` PriorityQueue macht das.
          // Ein erneutes Hinzufügen mit besseren Kosten wird korrekt behandelt.
          priorityQueue.add(neighborNode);
        }
      }
    }

    if (kDebugMode) {
      // Die folgende Zeile war die gemeldete Linter-Warnung (Zeile 135 im Screenshot, hier verschoben durch Kommentare)
      print("Dijkstra: Zielknoten ${endNode.id} nicht erreichbar von ${startNode.id}.");
    }
    return null;
  }

  static List<LatLng>? _reconstructPath(GraphNode endNode) {
    final List<LatLng> path = [];
    GraphNode? currentNode = endNode;
    int safetyBreak = 0;
    const int maxPathLength = 10000; // Annahme für maximale Pfadlänge

    while (currentNode != null && safetyBreak < maxPathLength) {
      path.add(currentNode.position);
      currentNode = currentNode.parent;
      safetyBreak++;
    }

    if (safetyBreak >= maxPathLength && kDebugMode) {
      print("WARNUNG: Pfadrekonstruktion abgebrochen (maximale Länge erreicht). Möglicherweise Kreis im Parent-Graph?");
    }

    if (path.isEmpty) {
      return null;
    } else {
      return path.reversed.toList();
    }
  }
}
// [Ende lib/services/routing_service.dart Überarbeitet für Linter]