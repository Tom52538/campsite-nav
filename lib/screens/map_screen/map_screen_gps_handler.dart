// lib/screens/map_screen/map_screen_gps_handler.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:camping_osm_navi/models/location_info.dart';
import 'map_screen_controller.dart';

class MapScreenGpsHandler {
  final MapScreenController controller;
  StreamSubscription<Position>? _positionStreamSubscription;

  static const double _significantGpsChangeThreshold = 2.0;
  static const Distance _distanceCalculator = Distance();

  MapScreenGpsHandler(this.controller);

  void initializeGpsOrMock(LocationInfo location) {
    if (controller.useMockLocation) {
      _initializeMockGps(location);
    } else {
      _initializeGpsReal();
    }
  }

  void _initializeMockGps(LocationInfo location) {
    _positionStreamSubscription?.cancel();
    controller.updateCurrentGpsPosition(location.initialCenter);
    controller.updateCurrentLocationMarker();

    if (kDebugMode) {
      print("Mock-GPS aktiv an Position: ${location.name}");
    }
  }

  Future<void> _initializeGpsReal() async {
    _positionStreamSubscription?.cancel();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        print("Standortdienste sind deaktiviert.");
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print("Standortberechtigung verweigert.");
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print("Standortberechtigung dauerhaft verweigert.");
      }
      return;
    }

    const LocationSettings locationSettings =
        LocationSettings(accuracy: LocationAccuracy.bestForNavigation);

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position newGpsPos) {
        _handleNewGpsPosition(newGpsPos);
      },
      onError: (error) {
        if (kDebugMode) {
          print("Fehler beim Empfangen des GPS-Signals: $error");
        }
      },
    );
  }

  void _handleNewGpsPosition(Position newGpsPos) {
    final newGpsLatLng = LatLng(newGpsPos.latitude, newGpsPos.longitude);
    double distanceToCurrent = 0;

    if (controller.currentGpsPosition != null) {
      distanceToCurrent = _distanceCalculator.distance(
          newGpsLatLng, controller.currentGpsPosition!);
    }

    final bool significantPositionChange =
        controller.currentGpsPosition == null ||
            distanceToCurrent > _significantGpsChangeThreshold;

    if (significantPositionChange) {
      controller.updateCurrentGpsPosition(newGpsLatLng);
      controller.updateCurrentLocationMarker();

      // Notify about GPS change for navigation updates
      _onGpsPositionChanged(newGpsLatLng);

      if (controller.followGps) {
        controller.mapController
            .move(newGpsLatLng, MapScreenController._followGpsZoomLevel);
      }
    }
  }

  void _onGpsPositionChanged(LatLng newPosition) {
    // This will be called by RouteHandler for navigation updates
    // We use a callback pattern to avoid circular dependencies
    if (_onGpsChangeCallback != null) {
      _onGpsChangeCallback!(newPosition);
    }
  }

  // Callback for GPS changes - set by RouteHandler
  void Function(LatLng)? _onGpsChangeCallback;

  void setOnGpsChangeCallback(void Function(LatLng) callback) {
    _onGpsChangeCallback = callback;
  }

  bool canCenterOnGps(LatLng? selectedLocationCenter) {
    if (controller.currentGpsPosition == null) {
      if (kDebugMode) {
        print("Aktuelle GPS-Position ist unbekannt.");
      }
      return false;
    }

    if (selectedLocationCenter != null) {
      final distanceToCenter = _distanceCalculator.distance(
          controller.currentGpsPosition!, selectedLocationCenter);

      if (distanceToCenter > MapScreenController.centerOnGpsMaxDistanceMeters) {
        if (kDebugMode) {
          print("Du bist zu weit vom Campingplatz entfernt, um zu zentrieren.");
        }
        return false;
      }
    }

    return true;
  }

  void centerOnGps() {
    if (controller.currentGpsPosition != null) {
      controller.setFollowGps(true);
      controller.mapController.move(controller.currentGpsPosition!,
          MapScreenController._followGpsZoomLevel);

      if (kDebugMode) {
        print("Follow-GPS Modus aktiviert.");
      }
    }
  }

  void toggleMockLocation(LocationInfo selectedLocation) {
    controller.toggleMockLocation();
    initializeGpsOrMock(selectedLocation);
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}
