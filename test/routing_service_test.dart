// test/routing_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/services/routing_service.dart';

void main() {
  group('RoutingService Tests', () {
    // --- Testfall 1: Einfacher Pfad ---
    test('Finds a simple path correctly', () async {
      // 1. Arrange: Erstelle einen einfachen Test-Graphen (A -> B -> C)
      final graph = RoutingGraph();
      // Verwende leicht unterschiedliche Koordinaten, um sicherzustellen, dass IDs eindeutig sind
      final nodeA = graph.addNode(const LatLng(51.000000, 5.800000)); // Start
      final nodeB = graph.addNode(const LatLng(51.000100, 5.800000)); // Mitte
      final nodeC = graph.addNode(const LatLng(51.000100, 5.800100)); // Ziel

      // Füge Kanten hinzu (Gewichtung hier z.B. 1 für Einfachheit)
      graph.addEdge(nodeA, nodeB, 1.0); // A nach B
      graph.addEdge(nodeB, nodeC, 1.0); // B nach C

      // WICHTIG: Setze Kosten zurück, bevor der Algorithmus läuft
      graph.resetAllNodeCosts();

      // 2. Act: Rufe die zu testende Methode auf
      final List<LatLng>? path =
          await RoutingService.findPath(graph, nodeA, nodeC);

      // 3. Assert: Überprüfe das Ergebnis
      expect(path, isNotNull,
          reason:
              "Pfad sollte nicht null sein."); // Prüft, ob ein Pfad gefunden wurde
      if (path != null) {
        expect(path, hasLength(3),
            reason: "Pfad sollte 3 Punkte haben (A, B, C)."); // Länge prüfen
        expect(path[0].latitude, equals(nodeA.position.latitude),
            reason: "Startpunkt Lat falsch.");
        expect(path[0].longitude, equals(nodeA.position.longitude),
            reason: "Startpunkt Lng falsch.");

        expect(path[1].latitude, equals(nodeB.position.latitude),
            reason: "Zwischenpunkt Lat falsch.");
        expect(path[1].longitude, equals(nodeB.position.longitude),
            reason: "Zwischenpunkt Lng falsch.");

        expect(path[2].latitude, equals(nodeC.position.latitude),
            reason: "Endpunkt Lat falsch.");
        expect(path[2].longitude, equals(nodeC.position.longitude),
            reason: "Endpunkt Lng falsch.");
      }
    });

    // --- Hier können später weitere Testfälle hinzugefügt werden ---
    // test('Returns null if no path exists', () async { ... });
    // test('Handles start and end node being the same', () async { ... });
  });
}
