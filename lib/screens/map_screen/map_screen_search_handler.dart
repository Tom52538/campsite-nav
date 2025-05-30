// lib/screens/map_screen/map_screen_search_handler.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'map_screen_controller.dart';

class MapScreenSearchHandler {
  final MapScreenController controller;
  final BuildContext context;

  MapScreenSearchHandler(this.controller, this.context) {
    _initializeSearchListeners();
  }

  void _initializeSearchListeners() {
    controller.startSearchController.addListener(_onStartSearchChanged);
    controller.endSearchController.addListener(_onEndSearchChanged);
    controller.startFocusNode.addListener(_onStartFocusChanged);
    controller.endFocusNode.addListener(_onEndFocusChanged);
  }

  void _onStartSearchChanged() {
    if (controller.startFocusNode.hasFocus &&
        controller.startSearchController.text != "Aktueller Standort") {
      _filterFeatures(controller.startSearchController.text);
    }
  }

  void _onEndSearchChanged() {
    if (controller.endFocusNode.hasFocus) {
      _filterFeatures(controller.endSearchController.text);
    }
  }

  void _onStartFocusChanged() {
    if (controller.startFocusNode.hasFocus) {
      controller.setActiveSearchField(ActiveSearchField.start);
      controller.setRouteActiveForCardSwitch(false);
      if (controller.startSearchController.text != "Aktueller Standort") {
        _filterFeatures(controller.startSearchController.text);
      }
    } else {
      if (controller.activeSearchField == ActiveSearchField.start) {
        controller.setActiveSearchField(ActiveSearchField.none);
      }
      _hideSearchResultsAfterDelay();
    }
  }

  void _onEndFocusChanged() {
    if (controller.endFocusNode.hasFocus) {
      controller.setActiveSearchField(ActiveSearchField.end);
      controller.setRouteActiveForCardSwitch(false);
      _filterFeatures(controller.endSearchController.text);
    } else {
      if (controller.activeSearchField == ActiveSearchField.end) {
        controller.setActiveSearchField(ActiveSearchField.none);
      }
      _hideSearchResultsAfterDelay();
    }
  }

  void _filterFeatures(String query) {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final allFeatures = locationProvider.currentSearchableFeatures;

    if (query.isEmpty) {
      controller.setSearchResults(allFeatures);
      controller.setShowSearchResults(true);
      return;
    }

    final filteredResults = allFeatures
        .where((feature) =>
            feature.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    controller.setSearchResults(filteredResults);
    controller.setShowSearchResults(true);
  }

  void _hideSearchResultsAfterDelay() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!controller.startFocusNode.hasFocus &&
          !controller.endFocusNode.hasFocus) {
        controller.setShowSearchResults(false);
      }
    });
  }

  void selectFeatureAndSetPoint(SearchableFeature feature) {
    final point = feature.center;

    if (controller.activeSearchField == ActiveSearchField.start) {
      controller.startSearchController.text = feature.name;
      controller.setStartLatLng(point);
      controller.updateStartMarker();
      controller.startFocusNode.unfocus();
    } else if (controller.activeSearchField == ActiveSearchField.end) {
      controller.endSearchController.text = feature.name;
      controller.setEndLatLng(point);
      controller.updateEndMarker();
      controller.endFocusNode.unfocus();
    }

    controller.setShowSearchResults(false);

    // Trigger route calculation if both points are set
    if (_onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  void setStartToCurrentLocation() {
    if (controller.currentGpsPosition == null) {
      if (kDebugMode) {
        print("Aktuelle Position unbekannt.");
      }
      return;
    }

    controller.startSearchController.text = "Aktueller Standort";
    controller.setStartLatLng(controller.currentGpsPosition);
    controller.startMarker = null; // Kein Marker für die aktuelle Position
    controller.startFocusNode.unfocus();

    // Trigger route calculation if both points are set
    if (_onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  void swapStartAndEnd() {
    controller.swapStartAndEnd();

    // Trigger route calculation if both points are set
    if (_onRouteCalculationNeeded != null) {
      _onRouteCalculationNeeded!();
    }
  }

  void clearSearchField(bool isStartField) {
    if (isStartField) {
      controller.startSearchController.clear();
      controller.setStartLatLng(null);
      controller.startMarker = null;
    } else {
      controller.endSearchController.clear();
      controller.setEndLatLng(null);
      controller.endMarker = null;
    }

    // Clear route if needed
    if (_onRouteClearNeeded != null) {
      _onRouteClearNeeded!();
    }
  }

  // Callback for when route calculation is needed - set by RouteHandler
  void Function()? _onRouteCalculationNeeded;
  void Function()? _onRouteClearNeeded;

  void setRouteCalculationCallback(void Function() callback) {
    _onRouteCalculationNeeded = callback;
  }

  void setRouteClearCallback(void Function() callback) {
    _onRouteClearNeeded = callback;
  }

  void dispose() {
    controller.startSearchController.removeListener(_onStartSearchChanged);
    controller.endSearchController.removeListener(_onEndSearchChanged);
    controller.startFocusNode.removeListener(_onStartFocusChanged);
    controller.endFocusNode.removeListener(_onEndFocusChanged);
  }
}
