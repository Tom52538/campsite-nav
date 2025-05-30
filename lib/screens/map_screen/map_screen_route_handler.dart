// lib/screens/map_screen/map_screen_route_handler.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/graph_node.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'map_screen_controller.dart';

class MapScreenRouteHandler {
  final MapScreenController controller;
  final BuildContext context;

  static const Distance _distanceCalculator = Distance();
  static const double maneuverReachedThreshold = 15.0;

  MapScreenRouteHandler(this.controller, this.context);

  Future<void> calculateRouteIfPossible() async {
    if (controller.startLatLng == null || controller.endLatLng == null) {
      return;
    }

    controller.setCalculatingRoute(true);

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final graph = locationProvider.currentRoutingGraph;

    if (graph == null) {
      if (kDebugMode) {
        print("Routing-Graph ist nicht geladen.");
      }
      controller.setCalculatingRoute(false);
      return;
    }

    final startNode = _findNearestNode(controller.startLatLng!, graph);
    final endNode = _findNearestNode(controller.endLatLng!, graph);

    if (startNode == null || endNode == null) {
      if (kDebugMode) {
        print("Start- oder Endpunkt liegt außerhalb des Wegnetzes.");
      }
      controller.setCalculatingRoute(false);
      return;
    }

    final List<LatLng>? pathPoints =
        await RoutingService.findPath(graph, startNode, endNode);

    if (pathPoints != null && pathPoints.isNotEmpty) {
      final maneuvers = RoutingService.analyzeRouteForTurns(pathPoints);
      final polyline =
          Polyline(points: pathPoints, color: Colors.blue, strokeWidth: 5.0);

      controller.setCurrentManeuvers(maneuvers);
      controller.setRoutePolyline(polyline);
      controller.updateRouteMetrics(pathPoints);

      // ✅ NEU: TTS für neue Route zurücksetzen
      controller.ttsService.resetForNewRoute();

      updateCurrentManeuverOnGpsUpdate(
          controller.currentGpsPosition ?? pathPoints.first);

      if (kDebugMode) {
        print(
            "Route berechnet. Distanz: ${controller.routeDistance?.toStringAsFixed(2)}m");
      }

      controller.setRouteActiveForCardSwitch(true);
      _toggleRouteOverview(zoomOut: true, delaySeconds: 0.5);
    } else {
      if (kDebugMode) {
        print("Keine Route zwischen den Punkten gefunden.");
      }
      controller.resetRouteAndNavigation();
    }

    controller.setCalculatingRoute(false);
  }

  GraphNode? _findNearestNode(LatLng point, RoutingGraph graph) {
    GraphNode? nearestNode;
    double minDistance = double.infinity;

    for (var node in graph.nodes.values) {
      final d = _distanceCalculator.distance(point, node.position);
      if (d < minDistance) {
        minDistance = d;
        nearestNode = node;
      }
    }
    return nearestNode;
  }

  void updateNavigationOnGpsChange(LatLng newGpsPosition) {
    if (controller.routePolyline == null ||
        controller.routePolyline!.points.isEmpty) {
      return;
    }

    final routePoints = controller.routePolyline!.points;

    // 1. Aktualisiere verbleibende Zeit/Distanz
    final remainingInfo =
        RoutingService.calculateRemainingRouteInfo(newGpsPosition, routePoints);

    if (remainingInfo != null) {
      controller.updateRemainingRouteInfo(
          remainingInfo.remainingDistance, remainingInfo.remainingTimeMinutes);
    }

    // 2. Prüfe auf Off-Route und führe ggf. Rerouting durch
    if (!controller.isRerouting && controller.endLatLng != null) {
      final isOffRoute = RoutingService.isOffRoute(newGpsPosition, routePoints);

      if (isOffRoute && controller.shouldTriggerReroute()) {
        _performRerouting(newGpsPosition);
      }
    }
  }

  Future<void> _performRerouting(LatLng currentPosition) async {
    if (controller.isRerouting || controller.endLatLng == null) return;

    controller.setRerouting(true);

    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      final graph = locationProvider.currentRoutingGraph;

      if (graph != null) {
        final newRoutePoints = await RoutingService.recalculateRoute(
            graph, currentPosition, controller.endLatLng!);

        if (newRoutePoints != null && newRoutePoints.isNotEmpty) {
          final newPolyline = Polyline(
              points: newRoutePoints, color: Colors.blue, strokeWidth: 5.0);

          controller.setRoutePolyline(newPolyline);
          controller.setCurrentManeuvers(
              RoutingService.analyzeRouteForTurns(newRoutePoints));
          controller.updateRouteMetrics(newRoutePoints);
          updateCurrentManeuverOnGpsUpdate(currentPosition);

          // ✅ NEU: Rerouting Ansage
          controller.ttsService.speakImmediate("Route wird neu berechnet");

          if (kDebugMode) {
            print("Route neu berechnet");
          }
        } else {
          if (kDebugMode) {
            print("Neue Route konnte nicht berechnet werden");
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Fehler beim Rerouting: $e");
      }
    } finally {
      controller.setRerouting(false);
    }
  }

  void updateCurrentManeuverOnGpsUpdate(LatLng currentPos) {
    if (controller.currentManeuvers.isEmpty) return;

    int startIndex = 0;
    if (controller.currentDisplayedManeuver != null) {
      startIndex = controller.currentManeuvers.indexWhere((m) =>
          m.point.latitude ==
              controller.currentDisplayedManeuver!.point.latitude &&
          m.point.longitude ==
              controller.currentDisplayedManeuver!.point.longitude &&
          m.turnType == controller.currentDisplayedManeuver!.turnType);
    }
    if (startIndex == -1) {
      startIndex = 0;
    }

    for (int i = startIndex; i < controller.currentManeuvers.length; i++) {
      final Maneuver potentialNextManeuver = controller.currentManeuvers[i];
      final LatLng maneuverPoint = potentialNextManeuver.point;

      final double distanceToManeuver =
          _distanceCalculator.distance(currentPos, maneuverPoint);

      if (i < controller.currentManeuvers.length - 1 &&
          distanceToManeuver < maneuverReachedThreshold) {
        continue;
      } else {
        Maneuver nextManeuverToDisplay = potentialNextManeuver;

        bool isNewDisplay = controller.currentDisplayedManeuver == null ||
            (nextManeuverToDisplay.point.latitude !=
                    controller.currentDisplayedManeuver!.point.latitude ||
                nextManeuverToDisplay.point.longitude !=
                    controller.currentDisplayedManeuver!.point.longitude ||
                nextManeuverToDisplay.turnType !=
                    controller.currentDisplayedManeuver!.turnType);

        if (isNewDisplay) {
          controller.updateCurrentDisplayedManeuver(nextManeuverToDisplay);
        }

        // ✅ NEU: Erweiterte Sprachanweisungen mit Distanzangaben
        controller.ttsService.speakNavigationInstruction(
            nextManeuverToDisplay, distanceToManeuver);

        break;
      }
    }
  }

  void _toggleRouteOverview({bool? zoomOut, double delaySeconds = 0.0}) {
    Future.delayed(Duration(milliseconds: (delaySeconds * 1000).toInt()), () {
      if (controller.routePolyline == null ||
          controller.routePolyline!.points.isEmpty) {
        return;
      }

      bool shouldZoomOut = zoomOut ?? !controller.isInRouteOverviewMode;

      if (shouldZoomOut) {
        controller.mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(controller.routePolyline!.points),
            padding: const EdgeInsets.all(50.0),
          ),
        );
        controller.setRouteOverviewMode(true);
        controller.setFollowGps(false);
      } else {
        _centerOnGps();
        controller.setRouteOverviewMode(false);
      }
    });
  }

  void _centerOnGps() {
    if (controller.currentGpsPosition != null) {
      controller.setFollowGps(true);
      controller.mapController.move(controller.currentGpsPosition!,
          MapScreenController.followGpsZoomLevel);
    }
  }

  void toggleRouteOverview() {
    _toggleRouteOverview();
  }

  void clearRoute({bool showConfirmation = false, bool clearMarkers = false}) {
    if (showConfirmation) {
      _showConfirmationDialog(
          "Route löschen",
          "Möchten Sie die aktuelle Route wirklich löschen?",
          () => _performClearRoute(clearMarkers));
    } else {
      _performClearRoute(clearMarkers);
    }
  }

  void _performClearRoute(bool clearMarkers) {
    controller.resetRouteAndNavigation();
    if (clearMarkers) {
      controller.startMarker = null;
      controller.endMarker = null;
    }
  }

  void _showConfirmationDialog(
      String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text("Abbrechen"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text("Bestätigen"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  void handleMapTap(TapPosition tapPos, LatLng latlng) {
    if (controller.isCalculatingRoute) return;

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final graph = locationProvider.currentRoutingGraph;
    if (graph == null) return;

    final nearestNode = _findNearestNode(latlng, graph);
    if (nearestNode == null) {
      if (kDebugMode) {
        print("Kein Weg in der Nähe gefunden.");
      }
      return;
    }

    final pointOnGraph = nearestNode.position;
    const pointName = "Punkt auf Karte";

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Als Startpunkt'),
                onTap: () {
                  Navigator.pop(context);
                  controller.startSearchController.text = pointName;
                  controller.setStartLatLng(pointOnGraph);
                  controller.updateStartMarker();
                  calculateRouteIfPossible();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Als Ziel'),
                onTap: () {
                  Navigator.pop(context);
                  controller.endSearchController.text = pointName;
                  controller.setEndLatLng(pointOnGraph);
                  controller.updateEndMarker();
                  calculateRouteIfPossible();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
