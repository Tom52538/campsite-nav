import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/widgets.dart';

// Importiere das Original, um @visibleForTesting nutzen zu können
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/models/graph_node.dart'; // Corrected import for GraphNode
import 'package:camping_osm_navi/models/graph_edge.dart'; // Added import for GraphEdge
import 'package:camping_osm_navi/models/routing_graph.dart';
// import 'package:camping_osm_navi/services/routing_service.dart'; // Wird im Test nicht direkt verwendet

// Generiere Mocks. Stellen Sie sicher, dass 'flutter pub run build_runner build' ausgeführt wurde.
@GenerateMocks([LocationProvider, RoutingGraph])
import 'map_screen_controller_test.mocks.dart';

class MockGraphNode extends Mock implements GraphNode {
  @override
  final String id;
  @override
  final LatLng position;

  MockGraphNode({required this.id, required this.position});

  @override
  List<GraphEdge> get edges => []; // Changed type

  @override
  double get fCost => gCost + hCost; // Changed name and calculation based on renamed fields

  @override
  double gCost = 0; // Renamed

  @override
  double hCost = 0; // Renamed

  @override
  GraphNode? parent; // Renamed

  @override
  void addEdge(GraphEdge edge) {} // Changed signature

  // removeEdge is removed

  @override
  void resetCosts() {} // Added
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  late MapScreenController mapScreenController;
  late MockLocationProvider mockLocationProvider;
  late MockRoutingGraph mockRoutingGraph;

  final startFeature = SearchableFeature(
      id: 's1', name: 'Start', type: 'poi', center: const LatLng(1, 1));
  final destinationFeature = SearchableFeature(
      id: 'd1', name: 'Destination', type: 'poi', center: const LatLng(2, 2));
  final pathPoints = [const LatLng(1, 1), const LatLng(2, 2)];

  setUp(() {
    mockLocationProvider = MockLocationProvider();
    mockRoutingGraph = MockRoutingGraph();

    when(mockLocationProvider.currentRoutingGraph).thenReturn(mockRoutingGraph);
    when(mockRoutingGraph.findNearestNode(any)).thenAnswer((realInvocation) {
      final LatLng pos = realInvocation.positionalArguments.first as LatLng;
      return MockGraphNode(
          id: 'node_${pos.latitude}_${pos.longitude}', position: pos);
    });
    // Der Fehler "body_might_complete_normally_nullable" für die obige Zeile ist unklar,
    // da die Funktion immer einen MockGraphNode zurückgibt.
    // Es könnte ein Linter-Problem oder eine tieferliegende Typ-Inkompatibilität sein,
    // die nach der Mock-Generierung verschwindet.

    when(mockRoutingGraph.resetAllNodeCosts()).thenAnswer((_) async {});

    mapScreenController = MapScreenController(mockLocationProvider);
  });

  Future<void> pumpEventQueue() async {
    await Future.delayed(Duration.zero);
  }

  group('MapScreenController Initial State', () {
    test('isStartLocked is initially false', () {
      expect(mapScreenController.isStartLocked, isFalse);
    });
    // ... weitere Tests ...
  });

  group('setStartLocation', () {
    test('sets _selectedStart and updates text controller', () {
      mapScreenController.setStartLocation(startFeature);
      expect(mapScreenController.selectedStart, startFeature);
      expect(mapScreenController.startSearchController.text, startFeature.name);
    });
    // ... weitere Tests ...
  });

  group('setDestination', () {
    test('sets _selectedDestination and updates text controller', () {
      mapScreenController.setDestination(destinationFeature);
      expect(mapScreenController.selectedDestination, destinationFeature);
      expect(mapScreenController.endSearchController.text,
          destinationFeature.name);
    });
    // ... weitere Tests ...
  });

  group('toggleStartLock', () {
    test('flips _isStartLocked state', () {
      expect(mapScreenController.isStartLocked, isFalse);
      mapScreenController.toggleStartLock();
      expect(mapScreenController.isStartLocked, isTrue);
      mapScreenController.toggleStartLock();
      expect(mapScreenController.isStartLocked, isFalse);
    });
    // ... weitere Tests ...
  });

  group('toggleDestinationLock', () {
    test('flips _isDestinationLocked state', () {
      expect(mapScreenController.isDestinationLocked, isFalse);
      mapScreenController.toggleDestinationLock();
      expect(mapScreenController.isDestinationLocked, isTrue);
      mapScreenController.toggleDestinationLock();
      expect(mapScreenController.isDestinationLocked, isFalse);
    });
    // ... weitere Tests ...
  });

  group('_attemptRouteCalculationOrClearRoute scenarios', () {
    setUp(() {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      // clearInteractions(mapScreenController); // Removed incorrect usage
    });

    test('clears route if start is not locked', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      mapScreenController.toggleDestinationLock();
      await mapScreenController.sendUpdatedRouteCalculationOrClearRoute();
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);
    });
    // ... weitere Tests ...
  });

  group('resetSearchFields', () {
    test('resets lock states to false', () {
      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();
      expect(mapScreenController.isStartLocked, isTrue);
      expect(mapScreenController.isDestinationLocked, isTrue);

      mapScreenController.resetSearchFields();
      expect(mapScreenController.isStartLocked, isFalse);
      expect(mapScreenController.isDestinationLocked, isFalse);
    });

    test('calls _attemptRouteCalculationOrClearRoute (clears route)', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      expect(mapScreenController.routePolyline, isNotNull);

      mapScreenController.resetSearchFields();
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);
    });
  });
  // Weitere Tests hier einfügen, falls vorhanden...
}

// TestHelpers Extension
// Diese Extension dient dazu, interne Zustände oder Methoden für Testzwecke zugänglich zu machen.
// Der direkte Zugriff auf private Member (`_selectedStart`) ist normalerweise nicht empfohlen,
// aber für Tests manchmal ein pragmatischer Ansatz.
// Die Methode `_attemptRouteCalculationOrClearRoute` wird über `@visibleForTesting` zugänglich gemacht.
extension TestHelpers on MapScreenController {
  void clearStartSelection() {
    // Diese Methode ist Teil des ursprünglichen Tests. Sie manipuliert den internen Zustand.
    // Eine robustere Lösung wäre, dies über öffentliche Methoden des Controllers zu steuern.
    // Für den Moment wird sie beibehalten, um die Teststruktur nicht zu stark zu verändern.
    startSearchController.clear();
    // Um _selectedStart zu nullen, müsste man entweder resetSearchFields() verwenden
    // und _selectedDestination danach wieder setzen, oder _selectedStart
    // im Controller selbst (ggf. @visibleForTesting) modifizierbar machen.
    // Derzeit setzt resetSearchFields() beide auf null und die Locks auf false.
    // Wenn nur _selectedStart null sein soll, ist das knifflig ohne direkte Manipulation.
  }

  void clearDestinationSelection() {
    endSearchController.clear();
    // Siehe Kommentare bei clearStartSelection()
  }

  Future<void> sendUpdatedRouteCalculationOrClearRoute() async {
    // Ruft die @visibleForTesting Methode im MapScreenController auf.
    // Dies ist der vorgesehene Weg, um die private Logik testbar zu machen.
    await this.attemptRouteCalculationOrClearRoute();
  }
}
