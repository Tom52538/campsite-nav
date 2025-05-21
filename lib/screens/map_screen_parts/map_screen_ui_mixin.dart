// lib/screens/map_screen_parts/map_screen_ui_mixin.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/screens/map_screen.dart'; // Um auf MapScreenState zuzugreifen
import 'package:camping_osm_navi/widgets/turn_instruction_card.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';


// UI Konstanten, die vorher static const in MapScreen waren
const double kSearchCardTopPadding = 8.0;
const double kSearchInputRowHeight = 40.0;
const double kDividerAndSwapButtonHeight = 28.0;
const double kRouteInfoHeight = 30.0;
const double kCardInternalVerticalPadding = 4.0;
const double kSearchCardMaxWidth = 360.0;
const double kSearchCardHorizontalMargin = 10.0;
const double kInstructionCardSpacing = 5.0;
const double kCompactCardHeight = 60.0;
const double kMarkerWidth = 40.0;
const double kMarkerHeight = 40.0;


mixin MapScreenUIMixin on State<MapScreen> {
  // Diese Referenzen müssen im MapScreenState vorhanden sein und hier zugänglich gemacht werden.
  // Wir greifen über 'this' (was auf MapScreenState verweist) darauf zu.
  // Sicherstellen, dass MapScreenState die benötigten Member hat.

  // Methoden, die auf MapScreenState-Member zugreifen, werden hier definiert
  // z.B. _startSearchController, _endSearchController, _startFocusNode, _endFocusNode, etc.
  // Und Methoden wie _selectFeatureAndSetPoint, _calculateAndDisplayRoute etc.

  // Wichtig: Damit das Mixin auf die Member von MapScreenState zugreifen kann,
  // müssen diese im MapScreenState public sein (nicht mit _ beginnen, wenn sie hier direkt genutzt werden sollen)
  // oder über Getter/explizite Methoden im MapScreenState bereitgestellt werden.
  // Für den Anfang gehen wir davon aus, dass wir über `this` (als Instanz von MapScreenState)
  // auf die benötigten Variablen und Methoden zugreifen können.

  // Expliziter Zugriff auf die State-Klasse für Klarheit
  MapScreenState get state => this as MapScreenState;


  Widget buildSearchInputCard({required Key key}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && state._fullSearchCardKey.currentContext != null) {
        final RenderBox? renderBox = state._fullSearchCardKey.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize && state._fullSearchCardHeight != renderBox.size.height) {
          state.setStateIfMounted(() {
            state._fullSearchCardHeight = renderBox.size.height;
          });
        }
      }
    });
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
            key: state._fullSearchCardKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: state._startFocusNode.hasFocus
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)
                      : Border.all(color: Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(6.0),
                  color: state._startFocusNode.hasFocus
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
                          controller: state._startSearchController,
                          focusNode: state._startFocusNode,
                          decoration: InputDecoration(
                            hintText: "Startpunkt wählen",
                            prefixIcon: const Icon(Icons.trip_origin),
                            suffixIcon: state._startSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    iconSize: 20,
                                    onPressed: () {
                                      state._startSearchController.clear();
                                      state.setStateIfMounted(() {
                                        state._startLatLng = null;
                                        state._startMarker = null;
                                        state._routePolyline = null;
                                        state._routeDistance = null;
                                        state._routeTimeMinutes = null;
                                        state._currentManeuvers = [];
                                        state._currentDisplayedManeuver = null;
                                        state._followGps = false;
                                        state._isRouteActiveForCardSwitch = false;
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
                                  if (state._currentGpsPosition != null) {
                                    final String locationName = state._useMockLocation
                                        ? "Mock Position (${Provider.of<LocationProvider>(context, listen: false).selectedLocation?.name ?? ''})"
                                        : "Aktueller Standort";
                                    state.setStateIfMounted(() {
                                      state._startLatLng = state._currentGpsPosition;
                                      if (state._startLatLng != null) {
                                        state._startMarker = createMarker( // Verwende createMarker aus diesem Mixin
                                            state._startLatLng!,
                                            Colors.green,
                                            Icons.flag_circle,
                                            "Start: $locationName");
                                      }
                                      state._startSearchController.text = locationName;
                                      if (state._startFocusNode.hasFocus) state._startFocusNode.unfocus();
                                      state._showSearchResults = false;
                                      state._activeSearchField = ActiveSearchField.none;
                                      state._followGps = false;
                                      if (state._endLatLng != null) {
                                          state._calculateAndDisplayRoute(); // Methode aus MapScreenState (oder später RouteMixin)
                                      } else {
                                        state._isRouteActiveForCardSwitch = false;
                                      }
                                    });
                                  } else {
                                    showSnackbar("Aktuelle Position nicht verfügbar."); // Verwende showSnackbar aus diesem Mixin
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
                            height: 1, thickness: 0.5, indent: 20, endIndent: 5)),
                    Tooltip(
                      message: "Start und Ziel tauschen",
                      child: IconButton(
                        icon: Icon(Icons.swap_vert,
                            color: Theme.of(context).colorScheme.primary),
                        iconSize: 20,
                        padding: const EdgeInsets.all(4.0),
                        constraints: const BoxConstraints(),
                        onPressed: (state._startLatLng != null || state._endLatLng != null)
                            ? state._swapStartAndEnd // Methode aus MapScreenState (oder später RouteMixin)
                            : null,
                      ),
                    ),
                    const Expanded(
                        child: Divider(
                            height: 1, thickness: 0.5, indent: 5, endIndent: 20)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: state._endFocusNode.hasFocus
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)
                      : Border.all(color: Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(6.0),
                  color: state._endFocusNode.hasFocus
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((255 * 0.05).round())
                      : null,
                ),
                child: SizedBox(
                  height: kSearchInputRowHeight,
                  child: TextField(
                    controller: state._endSearchController,
                    focusNode: state._endFocusNode,
                    decoration: InputDecoration(
                      hintText: "Ziel wählen",
                      prefixIcon: const Icon(Icons.flag_outlined),
                      suffixIcon: state._endSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              iconSize: 20,
                              onPressed: () {
                                state._endSearchController.clear();
                                state.setStateIfMounted(() {
                                  state._endLatLng = null;
                                  state._endMarker = null;
                                  state._routePolyline = null;
                                  state._routeDistance = null;
                                  state._routeTimeMinutes = null;
                                  state._currentManeuvers = [];
                                  state._currentDisplayedManeuver = null;
                                  state._followGps = false;
                                  state._isRouteActiveForCardSwitch = false;
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
              if (state._routeDistance != null && state._routeTimeMinutes != null)
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
                                text: "~ ${state._routeTimeMinutes ?? '?'} min",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: " / ${formatDistance(state._routeDistance)}", // Verwende formatDistance aus diesem Mixin
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
                      state._endSearchController.text.isNotEmpty
                          ? "Ziel: ${state._endSearchController.text}"
                          : "Aktive Route",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (state._routeDistance != null && state._routeTimeMinutes != null)
                      Text(
                        "~ ${state._routeTimeMinutes ?? '?'} min / ${formatDistance(state._routeDistance)}", // formatDistance
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
                    state._isRouteActiveForCardSwitch = false;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                 color: Theme.of(context).colorScheme.error,
                tooltip: "Route abbrechen",
                onPressed: () => state._clearRoute(showConfirmation: true, clearMarkers: true), // _clearRoute aus MapScreenState
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker createMarker( // Renamed from _createMarker
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

  void showSnackbar(String message, {int durationSeconds = 3}) { // Renamed from _showSnackbar
    if (!mounted) { // mounted ist im State verfügbar
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

  void showErrorDialog(String message) { // Renamed from _showErrorDialog
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

 void showConfirmationDialog( // Renamed from _showConfirmationDialog
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

  String formatDistance(double? distanceMeters) { // Renamed from _formatDistance
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