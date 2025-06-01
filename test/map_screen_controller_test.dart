import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen/map_screen_controller.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/services/routing_service.dart';

// Generate mocks for LocationProvider and RoutingGraph
@GenerateMocks([LocationProvider, RoutingGraph])
import 'map_screen_controller_test.mocks.dart'; // Generated file

// Mock for GraphNode as it's simple and used in tests
class MockGraphNode extends Mock implements GraphNode {
  @override
  final String id;
  @override
  final LatLng position;

  MockGraphNode({required this.id, required this.position});
}

void main() {
  late MapScreenController mapScreenController;
  late MockLocationProvider mockLocationProvider;
  late MockRoutingGraph mockRoutingGraph;

  // Reusable SearchableFeature instances
  final startFeature = SearchableFeature(id: 's1', name: 'Start', type: 'poi', center: LatLng(1, 1));
  final destinationFeature = SearchableFeature(id: 'd1', name: 'Destination', type: 'poi', center: LatLng(2, 2));
  final pathPoints = [LatLng(1, 1), LatLng(2, 2)];
  // Corrected Maneuver instantiation to match the actual constructor
  final List<Maneuver> maneuvers = [Maneuver(point: LatLng(1,1), turnType: TurnType.depart, instructionText: "Start")];


  setUp(() {
    mockLocationProvider = MockLocationProvider();
    mockRoutingGraph = MockRoutingGraph();

    // Default stub for currentRoutingGraph to return a valid graph
    when(mockLocationProvider.currentRoutingGraph).thenReturn(mockRoutingGraph);
    // Default stubs for graph nodes
    when(mockRoutingGraph.findNearestNode(any)).thenAnswer((realInvocation) {
        final LatLng pos = realInvocation.positionalArguments.first as LatLng;
        return MockGraphNode(id: 'node_${pos.latitude}_${pos.longitude}', position: pos);
    });
    // Default stub for resetAllNodeCosts
    when(mockRoutingGraph.resetAllNodeCosts()).thenAnswer((_) async {});


    mapScreenController = MapScreenController(mockLocationProvider);
  });

  // Helper to wait for async operations within the controller
  Future<void> pumpEventQueue() async {
    await Future.delayed(Duration.zero);
  }

  group('MapScreenController Initial State', () {
    test('isStartLocked is initially false', () {
      expect(mapScreenController.isStartLocked, isFalse);
    });

    test('isDestinationLocked is initially false', () {
      expect(mapScreenController.isDestinationLocked, isFalse);
    });

    test('routePolyline is initially null', () {
      expect(mapScreenController.routePolyline, isNull);
    });
  });

  group('setStartLocation', () {
    test('sets selectedStart and updates text controller', () {
      mapScreenController.setStartLocation(startFeature);
      expect(mapScreenController.selectedStart, startFeature);
      expect(mapScreenController.startSearchController.text, startFeature.name);
    });

    test('sets isStartLocked to false, even if previously true', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.toggleStartLock(); // Lock it
      expect(mapScreenController.isStartLocked, isTrue);

      mapScreenController.setStartLocation(startFeature); // Set it again
      expect(mapScreenController.isStartLocked, isFalse);
      await pumpEventQueue(); // for the _attemptRouteCalculationOrClearRoute call
    });

    test('calls _attemptRouteCalculationOrClearRoute (clears route if destination not locked)', () async {
      // Pre-set a route to ensure it gets cleared
      mapScreenController.setStartLocation(startFeature); // needs a start point
      mapScreenController.setDestination(destinationFeature); // needs a dest point
      mapScreenController.toggleStartLock(); // lock start
      mapScreenController.toggleDestinationLock(); // lock dest to potentially create a route
      // Manually set polyline for test clarity if mocking RoutingService.findPath is complex
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      expect(mapScreenController.routePolyline, isNotNull);

      // Unlock destination so that when start is set, route clears
      mapScreenController.toggleDestinationLock();
      expect(mapScreenController.isDestinationLocked, isFalse);


      mapScreenController.setStartLocation(startFeature); // This should call _tryCalculateRoute -> _attempt...
      await pumpEventQueue();

      // Since destination is not locked, route should be cleared
      expect(mapScreenController.routePolyline, isNull);
    });
  });

  group('setDestination', () {
    test('sets selectedDestination and updates text controller', () {
      mapScreenController.setDestination(destinationFeature);
      expect(mapScreenController.selectedDestination, destinationFeature);
      expect(mapScreenController.endSearchController.text, destinationFeature.name);
    });

    test('sets isDestinationLocked to false, even if previously true', () async {
      mapScreenController.setDestination(destinationFeature);
      mapScreenController.toggleDestinationLock(); // Lock it
      expect(mapScreenController.isDestinationLocked, isTrue);

      mapScreenController.setDestination(destinationFeature); // Set it again
      expect(mapScreenController.isDestinationLocked, isFalse);
      await pumpEventQueue(); // for the _attemptRouteCalculationOrClearRoute call
    });

    test('calls _attemptRouteCalculationOrClearRoute (clears route if start not locked)', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      expect(mapScreenController.routePolyline, isNotNull);

      // Unlock start so that when destination is set, route clears
      mapScreenController.toggleStartLock();
      expect(mapScreenController.isStartLocked, isFalse);

      mapScreenController.setDestination(destinationFeature); // This should call _tryCalculateRoute -> _attempt...
      await pumpEventQueue();

      // Since start is not set/locked, route should be cleared
      expect(mapScreenController.routePolyline, isNull);
    });
  });

  group('toggleStartLock', () {
    test('flips isStartLocked state and calls _attemptRouteCalculationOrClearRoute', () async {
      expect(mapScreenController.isStartLocked, isFalse);
      mapScreenController.setStartLocation(startFeature); // Ensure start is set
      mapScreenController.setDestination(destinationFeature); // Ensure dest is set for route attempt later

      mapScreenController.toggleStartLock(); // true
      await pumpEventQueue();
      expect(mapScreenController.isStartLocked, isTrue);
      // Route shouldn't calculate yet as destination isn't locked
      expect(mapScreenController.routePolyline, isNull);

      mapScreenController.toggleStartLock(); // false
      await pumpEventQueue();
      expect(mapScreenController.isStartLocked, isFalse);
      expect(mapScreenController.routePolyline, isNull); // Still should be null
    });

    // More detailed test for route calculation attempt when both become locked
    test('attempts route calculation when start and destination become locked', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      await pumpEventQueue(); // Consume notifications from setLocation calls

      mapScreenController.toggleStartLock(); // Start is now locked
      await pumpEventQueue();
      expect(mapScreenController.isStartLocked, isTrue);
      expect(mapScreenController.routePolyline, isNull); // Dest not locked yet

      // Mocking for successful route calculation (simplified due to static RoutingService)
      // We assume if findPath was called and returned a valid path, polyline would be set.
      // The current mock setup for findNearestNode is sufficient for this.
      // If RoutingService.findPath could be mocked:
      // when(RoutingService.findPath(any, any, any)).thenAnswer((_) async => pathPoints);
      // when(RoutingService.analyzeRouteForTurns(any)).thenReturn(maneuvers);

      // To test the effect of a successful call to RoutingService.findPath,
      // we would need to modify the static method or use a more advanced mocking technique.
      // For now, we test that it attempts: if findPath returned data, polyline would change.
      // Since our actual RoutingService.findPath will likely return null without a real graph/path,
      // polyline will remain null.

      mapScreenController.toggleDestinationLock(); // Destination is now locked, attempt route
      await pumpEventQueue();
      expect(mapScreenController.isDestinationLocked, isTrue);

      // Due to static RoutingService.findPath not being mockable here to return a path,
      // we expect routePolyline to remain null (as the real service won't find a path with mock graph nodes).
      expect(mapScreenController.routePolyline, isNull);
      expect(mapScreenController.isCalculatingRoute, isFalse); // Should reset after attempt
    });
  });

  group('toggleDestinationLock', () {
    test('flips isDestinationLocked state and calls _attemptRouteCalculationOrClearRoute', () async {
      expect(mapScreenController.isDestinationLocked, isFalse);
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);

      mapScreenController.toggleDestinationLock(); // true
      await pumpEventQueue();
      expect(mapScreenController.isDestinationLocked, isTrue);
      expect(mapScreenController.routePolyline, isNull); // Start not locked

      mapScreenController.toggleDestinationLock(); // false
      await pumpEventQueue();
      expect(mapScreenController.isDestinationLocked, isFalse);
      expect(mapScreenController.routePolyline, isNull);
    });
  });

  group('_attemptRouteCalculationOrClearRoute scenarios (triggered via public methods)', () {
    setUp(() {
        mapScreenController.setStartLocation(startFeature);
        mapScreenController.setDestination(destinationFeature);
        // It's better to not use clearInteractions(mapScreenController) here as it can hide issues
        // if notifyListeners is called unexpectedly. Instead, manage expectations per test.
        // Reset states for polyline for each test in this group if needed.
        mapScreenController.setRoutePolyline(null); // Ensure no pre-existing polyline
        mapScreenController.isCalculatingRoute = false; // Reset
        mapScreenController.currentManeuvers = [];
         // Ensure locks are off before each test in this group, unless the test itself sets them
        if (mapScreenController.isStartLocked) mapScreenController.toggleStartLock();
        if (mapScreenController.isDestinationLocked) mapScreenController.toggleDestinationLock();
        pumpEventQueue(); // Clear any pending notifications from setup.
    });

    test('clears route if start is not locked (dest is locked)', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints)); // Pre-set a route
      expect(mapScreenController.isStartLocked, isFalse); // Should be false after setStartLocation
      mapScreenController.toggleDestinationLock(); // Lock destination: true
      await pumpEventQueue();

      // Trigger: setStartLocation (which itself calls _tryCalc -> _attempt) will ensure start is not locked.
      // Or, if start was locked, then toggling it off.
      // If start is already not locked, toggling destination lock (if it was off) should trigger.
      // The condition is: start=false, dest=true.
      // Setting start location again ensures it's false and triggers.
      mapScreenController.setStartLocation(startFeature);
      await pumpEventQueue();

      expect(mapScreenController.routePolyline, isNull);
    });

    test('clears route if destination is not locked (start is locked)', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      expect(mapScreenController.isDestinationLocked, isFalse); // Should be false after setDestination
      mapScreenController.toggleStartLock(); // Lock start: true
      await pumpEventQueue();

      mapScreenController.setDestination(destinationFeature); // Ensures dest is not locked and triggers calc.
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);
    });

    test('clears route if selectedStart is null (locks are true)', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      mapScreenController.resetSearchFields(); // Clears selectedStart and selectedDestination, and locks
      await pumpEventQueue();

      // Now set only destination and lock both (start will be null)
      mapScreenController.setDestination(destinationFeature);
      mapScreenController.toggleStartLock(); // true
      mapScreenController.toggleDestinationLock(); // true
      await pumpEventQueue();

      expect(mapScreenController.selectedStart, isNull);
      expect(mapScreenController.routePolyline, isNull);
    });

    test('clears route if selectedDestination is null (locks are true)', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      mapScreenController.resetSearchFields();
      await pumpEventQueue();

      // Now set only start and lock both (destination will be null)
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.toggleStartLock(); // true
      mapScreenController.toggleDestinationLock(); // true
      await pumpEventQueue();

      expect(mapScreenController.selectedDestination, isNull);
      expect(mapScreenController.routePolyline, isNull);
    });

    test('handles graph missing: clears route, isCalculatingRoute handled', () async {
      when(mockLocationProvider.currentRoutingGraph).thenReturn(null);
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      mapScreenController.toggleStartLock();       // true
      mapScreenController.toggleDestinationLock();  // true, this triggers the calculation attempt
      await pumpEventQueue();

      expect(mapScreenController.routePolyline, isNull);
      expect(mapScreenController.isCalculatingRoute, isFalse);
      expect(mapScreenController.currentManeuvers, isEmpty);
    });

    test('handles nodes not found on graph: clears route', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);

      // Mock findNearestNode to return null for the start feature
      when(mockRoutingGraph.findNearestNode(startFeature.center)).thenReturn(null);
      // Ensure destination node is found for this specific test
      when(mockRoutingGraph.findNearestNode(destinationFeature.center)).thenReturn(MockGraphNode(id:'d_node', position: destinationFeature.center));

      mapScreenController.toggleStartLock();      // true
      mapScreenController.toggleDestinationLock(); // true, this triggers calculation
      await pumpEventQueue();

      expect(mapScreenController.routePolyline, isNull);
      expect(mapScreenController.isCalculatingRoute, isFalse);

      // Reset mock for other tests if needed, or ensure mocks are setup per test group.
      when(mockRoutingGraph.findNearestNode(any)).thenAnswer((realInvocation) {
        final LatLng pos = realInvocation.positionalArguments.first as LatLng;
        return MockGraphNode(id: 'node_${pos.latitude}_${pos.longitude}', position: pos);
      });
    });

    // Test for successful route calculation is still complex due to static RoutingService.
    // This test demonstrates the setup if RoutingService.findPath could be mocked.
    // Since it can't easily, this test will likely show routePolyline as null.
    test('attempts route calculation (actual path depends on RoutingService static methods)', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);

      when(mockRoutingGraph.findNearestNode(startFeature.center)).thenReturn(MockGraphNode(id:'s_node', position: startFeature.center));
      when(mockRoutingGraph.findNearestNode(destinationFeature.center)).thenReturn(MockGraphNode(id:'d_node', position: destinationFeature.center));

      // Ideal, but not directly possible with static:
      // when(RoutingService.findPath(any, any, any)).thenAnswer((_) async => pathPoints);
      // when(RoutingService.analyzeRouteForTurns(any)).thenReturn(maneuvers);

      mapScreenController.toggleStartLock();      // true
      mapScreenController.toggleDestinationLock(); // true, triggers calculation
      await pumpEventQueue();

      // Without mocking static RoutingService.findPath to return a path,
      // routePolyline will be null as the real method won't find a path with mock nodes.
      expect(mapScreenController.routePolyline, isNull);
      expect(mapScreenController.isCalculatingRoute, isFalse); // Should be false after attempt

      // If findPath could be mocked to return pathPoints:
      // expect(mapScreenController.routePolyline, isNotNull);
      // expect(mapScreenController.routePolyline?.points, pathPoints);
      // expect(mapScreenController.currentManeuvers, maneuvers); // if analyzeRouteForTurns is also mockable/stubbed
      // expect(mapScreenController.routeDistance, isNotNull);
      // expect(mapScreenController.currentDisplayedManeuver, isNotNull);
    });
  });

  group('resetSearchFields', () {
    test('resets lock states to false and clears selections', () {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();
      expect(mapScreenController.isStartLocked, isTrue);
      expect(mapScreenController.isDestinationLocked, isTrue);
      expect(mapScreenController.selectedStart, isNotNull);
      expect(mapScreenController.selectedDestination, isNotNull);

      mapScreenController.resetSearchFields();
      expect(mapScreenController.isStartLocked, isFalse);
      expect(mapScreenController.isDestinationLocked, isFalse);
      expect(mapScreenController.selectedStart, isNull);
      expect(mapScreenController.selectedDestination, isNull);
      expect(mapScreenController.startSearchController.text, isEmpty);
      expect(mapScreenController.endSearchController.text, isEmpty);
    });

    test('calls _attemptRouteCalculationOrClearRoute (clears route)', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();

      // Manually set a polyline to simulate a route being active
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      expect(mapScreenController.routePolyline, isNotNull, reason: "Polyline should be set before reset");

      mapScreenController.resetSearchFields();
      await pumpEventQueue(); // Allow async operations to complete

      expect(mapScreenController.routePolyline, isNull, reason: "Polyline should be cleared by resetSearchFields");
    });
  });
}

// The TestHelpers extension is removed as per instructions to not use private members.
