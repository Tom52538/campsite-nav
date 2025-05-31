// lib/screens/map_screen/map_screen_route_handler.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
// import 'package:camping_osm_navi/models/routing_graph.dart'; // REMOVED
// import 'package:camping_osm_navi/models/graph_node.dart'; // REMOVED
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/services/routing_service.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'map_screen_controller.dart';

class MapScreenRouteHandler {
  final MapScreenController controller;
  final BuildContext context;

  static const Distance _distanceCalculator = Distance();
  static const double maneuverReachedThreshold = 15.0;

  // ✅ NEU: Für schöne UI-Updates
  double? _currentDistanceToManeuver;

  MapScreenRouteHandler(this.controller, this.context);

  // REMOVED calculateRouteIfPossible
  // REMOVED _findNearestNode

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

    // 2. Prüfe auf Off-Route und führe ggf. Rerouting durch // REMOVED Rerouting Block
    // if (!controller.isRerouting && controller.endLatLng != null) {
    //   final isOffRoute = RoutingService.isOffRoute(newGpsPosition, routePoints);
    //
    //   if (isOffRoute && controller.shouldTriggerReroute()) {
    //     _performRerouting(newGpsPosition);
    //   }
    // }
  }

  // REMOVED _performRerouting

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

        // ✅ NEU: Distanz für UI speichern
        _currentDistanceToManeuver = distanceToManeuver;

        // ✅ NEU: Erweiterte Sprachanweisungen mit Distanzangaben
        controller.ttsService.speakNavigationInstruction(
            nextManeuverToDisplay, distanceToManeuver);

        break;
      }
    }
  }

  // ✅ NEU: Getter für aktuelle Distanz (für UI)
  double? get currentDistanceToManeuver => _currentDistanceToManeuver;

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

  void clearRoute({bool showConfirmation = false /*, bool clearMarkers = false // REMOVED clearMarkers */}) {
    if (showConfirmation) {
      _showConfirmationDialog(
          "Route löschen",
          "Möchten Sie die aktuelle Route wirklich löschen?",
          // () => _performClearRoute(clearMarkers)); // MODIFIED
          () => _performClearRoute());
    } else {
      // _performClearRoute(clearMarkers); // MODIFIED
      _performClearRoute();
    }
  }

  // void _performClearRoute(bool clearMarkers) { // MODIFIED
  void _performClearRoute() {
    controller.resetRouteAndNavigation();
    // if (clearMarkers) { // REMOVED - startMarker and endMarker are gone from controller
    //   controller.startMarker = null;
    //   controller.endMarker = null;
    // }
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

  // REMOVED handleMapTap
}
