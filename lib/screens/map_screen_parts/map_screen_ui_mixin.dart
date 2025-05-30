// lib/screens/map_screen_parts/map_screen_ui_mixin.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/screens/map_screen.dart';

// UI Konstanten
const double kSearchCardTopPadding = 8.0;
const double kSearchInputRowHeight = 40.0;
const double kDividerAndSwapButtonHeight = 28.0;
const double kRouteInfoHeight = 30.0;
const double kCardInternalVerticalPadding = 4.0;
const double kSearchCardMaxWidth = 360.0;
const double kSearchCardHorizontalMargin = 10.0;
const double kInstructionCardSpacing = 5.0;
const double kCompactCardHeight = 65.0;
const double kMarkerWidth = 40.0;
const double kMarkerHeight = 40.0;

// Mixin wird auf MapScreenState angewendet
mixin MapScreenUiMixin on State<MapScreen> {
  Widget buildSearchInputCard({
    required Key key,
    required GlobalKey fullSearchCardKey,
    required double fullSearchCardHeight,
    required void Function(void Function()) setStateIfMounted,
    required TextEditingController startSearchController,
    required FocusNode startFocusNode,
    required LatLng? startLatLng,
    required Marker? startMarker,
    required Polyline? routePolyline,
    required double? routeDistance,
    required int? routeTimeMinutes,
    required double? remainingRouteDistance,
    required int? remainingRouteTimeMinutes,
    required List currentManeuvers,
    required dynamic currentDisplayedManeuver,
    required bool followGps,
    required bool isRouteActiveForCardSwitch,
    required LatLng? currentGpsPosition,
    required bool useMockLocation,
    required TextEditingController endSearchController,
    required FocusNode endFocusNode,
    required LatLng? endLatLng,
    required Marker? endMarker,
    required void Function() swapStartAndEnd,
    required void Function() calculateAndDisplayRoute,
    required void Function({bool showConfirmation, bool clearMarkers})
        clearRoute,
    required void Function(String, {int durationSeconds}) showSnackbar,
  }) {
    final double? displayDistance = remainingRouteDistance ?? routeDistance;
    final int? displayTime = remainingRouteTimeMinutes ?? routeTimeMinutes;
    final String timeLabelPrefix =
        remainingRouteDistance != null ? "Rest: ~ " : "~ ";

    final String displayTimeString = displayTime?.toString() ?? '?';

    return Container(
      key: key,
      constraints: const BoxConstraints(maxWidth: kSearchCardMaxWidth),
      child: Card(
        elevation: 6.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8.0, vertical: kCardInternalVerticalPadding),
          child: Column(
            key: fullSearchCardKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: startFocusNode.hasFocus
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)
                      : Border.all(color: Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(6.0),
                  color: startFocusNode.hasFocus
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((255 * 0.05).round())
                      : null,
                ),
                child: SizedBox(
                  height: kSearchInputRowHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startSearchController,
                          focusNode: startFocusNode,
                          decoration: InputDecoration(
                            hintText: "Startpunkt wählen",
                            prefixIcon: const Icon(Icons.trip_origin),
                            suffixIcon: startSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    iconSize: 20,
                                    onPressed: () {
                                      startSearchController.clear();
                                      clearRoute();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 8.0),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: "Aktuellen Standort als Start verwenden",
                        child: IconButton(
                          icon: const Icon(Icons.my_location),
                          color: Theme.of(context).colorScheme.primary,
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            // ✅ KORRIGIERT: Direkte Verwendung der öffentlichen Methode
                            setStartToCurrentLocation();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: kDividerAndSwapButtonHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Expanded(
                        child: Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 20,
                            endIndent: 5)),
                    Tooltip(
                      message: "Start und Ziel tauschen",
                      child: IconButton(
                        icon: Icon(Icons.swap_vert,
                            color: Theme.of(context).colorScheme.primary),
                        iconSize: 20,
                        padding: const EdgeInsets.all(4.0),
                        constraints: const BoxConstraints(),
                        onPressed: (startLatLng != null || endLatLng != null)
                            ? swapStartAndEnd
                            : null,
                      ),
                    ),
                    const Expanded(
                        child: Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 5,
                            endIndent: 20)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: endFocusNode.hasFocus
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)
                      : Border.all(color: Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(6.0),
                  color: endFocusNode.hasFocus
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((255 * 0.05).round())
                      : null,
                ),
                child: SizedBox(
                  height: kSearchInputRowHeight,
                  child: TextField(
                    controller: endSearchController,
                    focusNode: endFocusNode,
                    decoration: InputDecoration(
                      hintText: "Ziel wählen",
                      prefixIcon: const Icon(Icons.flag_outlined),
                      suffixIcon: endSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              iconSize: 20,
                              onPressed: () {
                                endSearchController.clear();
                                clearRoute();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 8.0),
                    ),
                  ),
                ),
              ),
              if (displayDistance != null && displayTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                  child: SizedBox(
                    height: kRouteInfoHeight - 6.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_walk,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18),
                        const SizedBox(width: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "$timeLabelPrefix$displayTimeString min",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: " / ${formatDistance(displayDistance)}",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCompactRouteInfoCard({
    required Key key,
    required double? remainingRouteDistance,
    required double? routeDistance,
    required int? remainingRouteTimeMinutes,
    required int? routeTimeMinutes,
    required Polyline? routePolyline,
    required TextEditingController endSearchController,
    required void Function(void Function()) setStateIfMounted,
    required bool isRouteActiveForCardSwitch,
    required void Function({bool showConfirmation, bool clearMarkers})
        clearRoute,
  }) {
    final double? displayDistance = remainingRouteDistance ?? routeDistance;
    final int? displayTime = remainingRouteTimeMinutes ?? routeTimeMinutes;
    final String timeLabelPrefix =
        remainingRouteDistance != null && routePolyline != null
            ? "Rest: ~ "
            : "~ ";

    final String displayTimeString = displayTime?.toString() ?? '?';

    return Container(
      key: key,
      constraints: const BoxConstraints(maxWidth: kSearchCardMaxWidth),
      height: kCompactCardHeight,
      child: Card(
        elevation: 6.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      endSearchController.text.isNotEmpty
                          ? "Ziel: ${endSearchController.text}"
                          : "Aktive Route",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayDistance != null && displayTime != null)
                      Text(
                        "$timeLabelPrefix$displayTimeString min / ${formatDistance(displayDistance)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_location_alt_outlined),
                color: Theme.of(context).colorScheme.primary,
                tooltip: "Route bearbeiten",
                onPressed: () {
                  setStateIfMounted(() {
                    // This will be handled by the MapScreen state
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: Theme.of(context).colorScheme.error,
                tooltip: "Route abbrechen",
                onPressed: () =>
                    clearRoute(showConfirmation: true, clearMarkers: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker createMarker(
      LatLng position, Color color, IconData icon, String tooltip,
      {double size = 30.0}) {
    return Marker(
      width: kMarkerWidth,
      height: kMarkerHeight,
      point: position,
      alignment: Alignment.center,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: size),
      ),
    );
  }

  void showSnackbar(String message, {int durationSeconds = 3}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void showErrorDialog(String message) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Fehler"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.of(dialogContext).pop()),
          ],
        );
      },
    );
  }

  void showConfirmationDialog(
      String title, String content, VoidCallback onConfirm) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
                child: const Text("Abbrechen"),
                onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
                child: const Text("Bestätigen"),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onConfirm();
                }),
          ],
        );
      },
    );
  }

  String formatDistance(double? distanceMeters) {
    if (distanceMeters == null) {
      return "";
    }
    if (distanceMeters < 1000) {
      return "${distanceMeters.round()} m";
    } else {
      return "${(distanceMeters / 1000).toStringAsFixed(1)} km";
    }
  }

  IconData getIconForFeatureType(String type) {
    switch (type.toLowerCase()) {
      case 'parking':
        return Icons.local_parking;
      case 'building':
        return Icons.business;
      case 'shop':
        return Icons.store;
      case 'amenity':
        return Icons.place;
      case 'tourism':
        return Icons.attractions;
      case 'reception':
      case 'information':
        return Icons.room_service;
      case 'sanitary':
      case 'toilets':
        return Icons.wc;
      case 'restaurant':
      case 'cafe':
      case 'bar':
        return Icons.restaurant;
      case 'playground':
        return Icons.child_friendly;
      case 'pitch':
      case 'camp_pitch':
        return Icons.holiday_village;
      case 'water_point':
        return Icons.water_drop;
      case 'waste_disposal':
        return Icons.recycling;
      default:
        return Icons.location_pin;
    }
  }

  // ✅ NEU: Abstrakte Methode - muss von MapScreenState implementiert werden
  void setStartToCurrentLocation();
}
