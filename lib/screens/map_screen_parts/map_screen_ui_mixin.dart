// lib/screens/map_screen_parts/map_screen_ui_mixin.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// import 'package:camping_osm_navi/models/maneuver.dart'; // Entfernt
// import 'package:camping_osm_navi/models/searchable_feature.dart'; // Entfernt
import 'package:camping_osm_navi/screens/map_screen.dart';
// import 'package:camping_osm_navi/widgets/turn_instruction_card.dart'; // Entfernt
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';

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

mixin MapScreenUIMixin on State<MapScreen> {
  MapScreenState get state => this as MapScreenState;

  Widget buildSearchInputCard({required Key key}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && state.fullSearchCardKey.currentContext != null) {
        final RenderBox? renderBox = state.fullSearchCardKey.currentContext!
            .findRenderObject() as RenderBox?;
        if (renderBox != null &&
            renderBox.hasSize &&
            state.fullSearchCardHeight != renderBox.size.height) {
          state.setStateIfMounted(() {
            state.fullSearchCardHeight = renderBox.size.height;
          });
        }
      }
    });

    // Entscheide, welche Distanz/Zeit angezeigt wird
    final double? displayDistance =
        state.remainingRouteDistance ?? state.routeDistance;
    final int? displayTime =
        state.remainingRouteTimeMinutes ?? state.routeTimeMinutes;
    final String timeLabelPrefix =
        state.remainingRouteDistance != null ? "Rest: ~ " : "~ ";

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
            key: state.fullSearchCardKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: state.startFocusNode.hasFocus
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)
                      : Border.all(color: Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(6.0),
                  color: state.startFocusNode.hasFocus
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
                          controller: state.startSearchController,
                          focusNode: state.startFocusNode,
                          decoration: InputDecoration(
                            hintText: "Startpunkt wählen",
                            prefixIcon: const Icon(Icons.trip_origin),
                            suffixIcon: state
                                    .startSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    iconSize: 20,
                                    onPressed: () {
                                      state.startSearchController.clear();
                                      state.setStateIfMounted(() {
                                        state.startLatLng = null;
                                        state.startMarker = null;
                                        state.routePolyline = null;
                                        state.routeDistance = null;
                                        state.routeTimeMinutes = null;
                                        state.remainingRouteDistance = null;
                                        state.remainingRouteTimeMinutes = null;
                                        state.currentManeuvers = [];
                                        state.currentDisplayedManeuver = null;
                                        state.followGps = false;
                                        state.isRouteActiveForCardSwitch =
                                            false;
                                      });
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
                            if (state.currentGpsPosition != null) {
                              final String locationName = state.useMockLocation
                                  ? "Mock Position (${Provider.of<LocationProvider>(context, listen: false).selectedLocation?.name ?? ''})"
                                  : "Aktueller Standort";
                              state.setStateIfMounted(() {
                                state.startLatLng = state.currentGpsPosition;
                                if (state.startLatLng != null) {
                                  state.startMarker = createMarker(
                                      state.startLatLng!,
                                      Colors.green,
                                      Icons.flag_circle,
                                      "Start: $locationName");
                                }
                                state.startSearchController.text = locationName;
                                if (state.startFocusNode.hasFocus)
                                  state.startFocusNode.unfocus();
                                state.showSearchResults = false;
                                state.activeSearchField =
                                    ActiveSearchField.none;
                                state.followGps = false;
                                if (state.endLatLng != null) {
                                  state.calculateAndDisplayRoute();
                                } else {
                                  state.isRouteActiveForCardSwitch = false;
                                }
                              });
                            } else {
                              showSnackbar(
                                  "Aktuelle Position nicht verfügbar.");
                            }
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
                        onPressed: (state.startLatLng != null ||
                                state.endLatLng != null)
                            ? state.swapStartAndEnd
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
                  border: state.endFocusNode.hasFocus
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)
                      : Border.all(color: Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(6.0),
                  color: state.endFocusNode.hasFocus
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((255 * 0.05).round())
                      : null,
                ),
                child: SizedBox(
                  height: kSearchInputRowHeight,
                  child: TextField(
                    controller: state.endSearchController,
                    focusNode: state.endFocusNode,
                    decoration: InputDecoration(
                      hintText: "Ziel wählen",
                      prefixIcon: const Icon(Icons.flag_outlined),
                      suffixIcon: state.endSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              iconSize: 20,
                              onPressed: () {
                                state.endSearchController.clear();
                                state.setStateIfMounted(() {
                                  state.endLatLng = null;
                                  state.endMarker = null;
                                  state.routePolyline = null;
                                  state.routeDistance = null;
                                  state.routeTimeMinutes = null;
                                  state.remainingRouteDistance = null;
                                  state.remainingRouteTimeMinutes = null;
                                  state.currentManeuvers = [];
                                  state.currentDisplayedManeuver = null;
                                  state.followGps = false;
                                  state.isRouteActiveForCardSwitch = false;
                                });
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
                                text:
                                    "$timeLabelPrefix${displayTime ?? '?'} min",
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

  Widget buildCompactRouteInfoCard({required Key key}) {
    // Entscheide, welche Distanz/Zeit angezeigt wird
    final double? displayDistance =
        state.remainingRouteDistance ?? state.routeDistance;
    final int? displayTime =
        state.remainingRouteTimeMinutes ?? state.routeTimeMinutes;
    final String timeLabelPrefix =
        state.remainingRouteDistance != null && state.routePolyline != null
            ? "Rest: ~ "
            : "~ ";

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
                      state.endSearchController.text.isNotEmpty
                          ? "Ziel: ${state.endSearchController.text}"
                          : "Aktive Route",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayDistance != null && displayTime != null)
                      Text(
                        "$timeLabelPrefix${displayTime ?? '?'} min / ${formatDistance(displayDistance)}",
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
                  state.setStateIfMounted(() {
                    state.isRouteActiveForCardSwitch = false;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: Theme.of(context).colorScheme.error,
                tooltip: "Route abbrechen",
                onPressed: () => state.clearRoute(
                    showConfirmation: true, clearMarkers: true),
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
}
