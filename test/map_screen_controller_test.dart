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
  final List<Maneuver> maneuvers = [Maneuver(turnType: TurnType.depart, instruction: "Start", streetName: "Street", distanceMeters: 0, point: LatLng(1,1))];


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
    test('sets _selectedStart and updates text controller', () {
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
    });

    test('calls _attemptRouteCalculationOrClearRoute (clears route if destination not locked)', () async {
      // Pre-set a route
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      expect(mapScreenController.routePolyline, isNotNull);

      mapScreenController.setStartLocation(startFeature);
      await pumpEventQueue(); // Allow async operations in _attemptRouteCalculationOrClearRoute to complete

      // Since destination is not set/locked, route should be cleared
      expect(mapScreenController.routePolyline, isNull);
    });
  });

  group('setDestination', () {
    test('sets _selectedDestination and updates text controller', () {
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
    });

    test('calls _attemptRouteCalculationOrClearRoute (clears route if start not locked)', () async {
      // Pre-set a route
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      expect(mapScreenController.routePolyline, isNotNull);

      mapScreenController.setDestination(destinationFeature);
      await pumpEventQueue();

      // Since start is not set/locked, route should be cleared
      expect(mapScreenController.routePolyline, isNull);
    });
  });

  group('toggleStartLock', () {
    test('flips _isStartLocked state', () {
      expect(mapScreenController.isStartLocked, isFalse);
      mapScreenController.toggleStartLock();
      expect(mapScreenController.isStartLocked, isTrue);
      mapScreenController.toggleStartLock();
      expect(mapScreenController.isStartLocked, isFalse);
    });

    test('calls _attemptRouteCalculationOrClearRoute', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      // Route should be null as nothing is locked yet
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);

      mapScreenController.toggleStartLock(); // Lock start
      // Still no route as destination isn't locked
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);

      // Mock successful path finding for when both are locked
      // For RoutingService static methods, we can't directly use mockito's `when` in the typical way
      // without a helper or refactor. We'll test by side effect: if findPath would return a path,
      // routePolyline should be set.
      // This part of the test relies on overriding the static method's behavior or pre-setting results if possible.
      // For this test, we will assume RoutingService.findPath cannot be directly mocked easily.
      // Instead, we will mock the graph and assume if graph returns nodes, and if findPath (unmocked)
      // were to succeed, then a polyline would be set.
      // A more robust way would be to inject RoutingService or use a test helper.

      mapScreenController.toggleDestinationLock(); // Lock destination - now try to calculate
      await pumpEventQueue();

      // Since we can't easily mock static RoutingService.findPath to return a path here,
      // we'll check that isCalculatingRoute was true then false, and that resetRouteAndNavigation was NOT called
      // if we assume findPath would have returned null (default behavior without actual routing data).
      // If findPath returns null, polyline should be null.
      expect(mapScreenController.routePolyline, isNull); // Expected if findPath returns null
      expect(mapScreenController.isCalculatingRoute, isFalse); // Should reset after attempt
    });
  });

  group('toggleDestinationLock', () {
    test('flips _isDestinationLocked state', () {
      expect(mapScreenController.isDestinationLocked, isFalse);
      mapScreenController.toggleDestinationLock();
      expect(mapScreenController.isDestinationLocked, isTrue);
      mapScreenController.toggleDestinationLock();
      expect(mapScreenController.isDestinationLocked, isFalse);
    });

     test('calls _attemptRouteCalculationOrClearRoute', () async {
      mapScreenController.setStartLocation(startFeature);
      mapScreenController.setDestination(destinationFeature);
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);

      mapScreenController.toggleDestinationLock(); // Lock dest
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);

      mapScreenController.toggleStartLock(); // Lock start - now try to calculate
      await pumpEventQueue();

      expect(mapScreenController.routePolyline, isNull);
      expect(mapScreenController.isCalculatingRoute, isFalse);
    });
  });

  group('_attemptRouteCalculationOrClearRoute scenarios', () {
    setUp(() {
        // Ensure selected locations are set for these tests
        mapScreenController.setStartLocation(startFeature);
        mapScreenController.setDestination(destinationFeature);
        // Clear any listeners that might have been added by default setup of controller
        // to ensure verify(notifyListeners()).called(X) is accurate for the specific test.
        clearInteractions(mapScreenController);
    });

    test('clears route if start is not locked', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints)); // Pre-set a route
      mapScreenController.toggleDestinationLock(); // Lock destination
      // Start is not locked by default after setStartLocation

      await mapScreenController.sendUpdatedRouteCalculationOrClearRoute(); // Manually trigger if needed, or rely on toggle
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);
    });

    test('clears route if destination is not locked', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      mapScreenController.toggleStartLock(); // Lock start
      // Destination is not locked

      await mapScreenController.sendUpdatedRouteCalculationOrClearRoute();
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);
    });

    test('clears route if _selectedStart is null', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      mapScreenController.clearStartSelection(); // Helper to nullify start
      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();

      await mapScreenController.sendUpdatedRouteCalculationOrClearRoute();
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);
    });

    test('clears route if _selectedDestination is null', () async {
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      mapScreenController.clearDestinationSelection(); // Helper to nullify dest
      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();

      await mapScreenController.sendUpdatedRouteCalculationOrClearRoute();
      await pumpEventQueue();
      expect(mapScreenController.routePolyline, isNull);
    });

    test('handles graph missing: clears route, isCalculatingRoute handled', () async {
      when(mockLocationProvider.currentRoutingGraph).thenReturn(null);
      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();

      // isCalculating should be true during the call, then false
      // We can listen to notifyListeners to check intermediate states if necessary,
      // but for simplicity, check final state and that resetRouteAndNavigation was called.
      // The actual call to _attempt is async, so we await.

      // Need to call the method that triggers _attemptRouteCalculationOrClearRoute,
      // for example, by toggling a lock again or directly if we make it public for testing.
      // For now, let's assume toggling lock is the entry point.
      mapScreenController.toggleStartLock(); // This will make it false, then true again.
      mapScreenController.toggleStartLock(); // Back to original state, but triggers the call.

      await pumpEventQueue(); // Wait for the async _attemptRouteCalculationOrClearRoute

      expect(mapScreenController.routePolyline, isNull);
      expect(mapScreenController.isCalculatingRoute, isFalse); // Should be false after attempt
      // Verify resetRouteAndNavigation was called - check polyline and other route properties
      expect(mapScreenController.currentManeuvers, isEmpty);
    });

    test('handles nodes not found on graph: clears route', () async {
      when(mockRoutingGraph.findNearestNode(startFeature.center)).thenReturn(null); // Start node not found
      when(mockRoutingGraph.findNearestNode(destinationFeature.center)).thenReturn(MockGraphNode(id:'d', position: destinationFeature.center));

      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();
      await pumpEventQueue();

      expect(mapScreenController.routePolyline, isNull);
      expect(mapScreenController.isCalculatingRoute, isFalse);
    });

    // Test for successful route calculation is more complex due to static RoutingService.
    // It would be structured like this if RoutingService could be easily mocked:
    /*
    test('successful route calculation: sets polyline, maneuvers, metrics', () async {
      // Setup mocks for graph and RoutingService
      when(mockRoutingGraph.findNearestNode(startFeature.center)).thenReturn(MockGraphNode(id:'s', position: startFeature.center));
      when(mockRoutingGraph.findNearestNode(destinationFeature.center)).thenReturn(MockGraphNode(id:'d', position: destinationFeature.center));

      // This is the tricky part with static methods.
      // If RoutingService was injectable:
      // when(mockRoutingService.findPath(any, any, any)).thenAnswer((_) async => pathPoints);
      // when(mockRoutingService.analyzeRouteForTurns(any)).thenReturn(maneuvers);

      // For now, we can't directly mock static methods of RoutingService without more setup.
      // So, this specific test for success might be limited or need a different approach.
      // We can verify that setCalculatingRoute was true then false, and that other methods like
      // setRoutePolyline were called IF findPath returned a non-null value.
      // This test will be more of an integration test for the controller's logic flow assuming RoutingService works.

      mapScreenController.toggleStartLock();
      mapScreenController.toggleDestinationLock();
      await pumpEventQueue();

      // Assertions would depend on ability to mock RoutingService.findPath
      // If findPath returns null (as it would if not properly mocked to return a path):
      expect(mapScreenController.routePolyline, isNull);
      expect(mapScreenController.isCalculatingRoute, isFalse);

      // If we could mock findPath to return pathPoints:
      // expect(mapScreenController.routePolyline, isNotNull);
      // expect(mapScreenController.routePolyline?.points, pathPoints);
      // expect(mapScreenController.currentManeuvers, isNotEmpty);
      // expect(mapScreenController.routeDistance, isNotNull);
      // expect(mapScreenController.currentDisplayedManeuver, isNotNull);
    });
    */
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
      // Assume route calculation might have occurred and set a polyline
      // For this test, let's manually set one to ensure it's cleared.
      mapScreenController.setRoutePolyline(Polyline(points: pathPoints));
      expect(mapScreenController.routePolyline, isNotNull);


      mapScreenController.resetSearchFields();
      await pumpEventQueue();

      expect(mapScreenController.routePolyline, isNull);
    });
  });
}

// Helper methods in MapScreenController for testing purposes if needed:
// (These would ideally be added to MapScreenController itself if useful for testing)
extension TestHelpers on MapScreenController {
  void clearStartSelection() {
    _selectedStart = null; // Accessing private member for test setup
    startSearchController.clear();
  }
  void clearDestinationSelection() {
    _selectedDestination = null; // Accessing private member for test setup
    endSearchController.clear();
  }
  // To call _attemptRouteCalculationOrClearRoute directly for some test scenarios
  Future<void> sendUpdatedRouteCalculationOrClearRoute() async {
    await _attemptRouteCalculationOrClearRoute();
  }
}
