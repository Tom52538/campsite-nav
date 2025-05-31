// lib/screens/map_screen/map_screen_gps_handler.dart - AUTO-CENTER BEI GPS AKTIVIERUNG
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

  // ✅ NEU: Flag um zu tracken ob GPS gerade aktiviert wurde
  bool _gpsJustActivated = false;

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

    // ✅ NEUE LOGIK: GPS wurde gerade aktiviert (Mock-Modus)
    final wasGpsActive = controller.currentGpsPosition != null;

    controller.updateCurrentGpsPosition(location.initialCenter);
    controller.updateCurrentLocationMarker();

    // ✅ AUTO-CENTER: Wenn GPS gerade aktiviert wurde, zentriere auf Position
    if (!wasGpsActive) {
      _autoMoveToGpsPosition(location.initialCenter);
      if (kDebugMode) {
        print(
            "Mock-GPS aktiviert und Karte automatisch zentriert auf: ${location.name}");
      }
    } else {
      if (kDebugMode) {
        print("Mock-GPS Position aktualisiert: ${location.name}");
      }
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

    // ✅ NEUE LOGIK: Merke dass GPS gerade aktiviert wird
    final wasGpsActive = controller.currentGpsPosition != null;
    if (!wasGpsActive) {
      _gpsJustActivated = true;
      if (kDebugMode) {
        print(
            "Echtes GPS wird aktiviert - Auto-Center wird beim ersten Signal ausgeführt");
      }
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

      // ✅ AUTO-CENTER: Wenn GPS gerade aktiviert wurde, zentriere automatisch
      if (_gpsJustActivated) {
        _autoMoveToGpsPosition(newGpsLatLng);
        _gpsJustActivated = false; // Reset flag nach erstem Auto-Center
        if (kDebugMode) {
          print(
              "Echtes GPS aktiviert und Karte automatisch zentriert auf: ${newGpsLatLng.latitude}, ${newGpsLatLng.longitude}");
        }
      }

      // Notify about GPS change for navigation updates
      _onGpsPositionChanged(newGpsLatLng);

      if (controller.followGps) {
        controller.mapController
            .move(newGpsLatLng, MapScreenController.followGpsZoomLevel);
      }
    }
  }

  // ✅ NEUE METHODE: Auto-Zentrierung mit Animation
  void _autoMoveToGpsPosition(LatLng gpsPosition) {
    // Aktiviere Follow-GPS automatisch
    controller.setFollowGps(true);

    // Bewege Karte zur GPS-Position mit Animation
    controller.mapController
        .move(gpsPosition, MapScreenController.followGpsZoomLevel);

    if (kDebugMode) {
      print(
          "Karte automatisch auf GPS-Position zentriert: ${gpsPosition.latitude}, ${gpsPosition.longitude}");
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
          MapScreenController.followGpsZoomLevel);

      if (kDebugMode) {
        print("Follow-GPS Modus manuell aktiviert.");
      }
    }
  }

  void toggleMockLocation(LocationInfo selectedLocation) {
    // ✅ NEUE LOGIK: Reset GPS-activation flag beim Umschalten
    _gpsJustActivated = false;

    controller.toggleMockLocation();
    initializeGpsOrMock(selectedLocation);
  }

  // ✅ NEUE METHODE: Explizite GPS-Aktivierung für UI-Button
  void activateGps(LocationInfo selectedLocation) {
    if (kDebugMode) {
      print("GPS explizit über UI aktiviert");
    }

    // Setze Flag für Auto-Center
    if (controller.useMockLocation) {
      // Für Mock: sofort zentrieren
      final wasGpsActive = controller.currentGpsPosition != null;
      if (!wasGpsActive) {
        _autoMoveToGpsPosition(selectedLocation.initialCenter);
      }
    } else {
      // Für echtes GPS: Flag setzen für nächstes Signal
      _gpsJustActivated = true;
    }

    initializeGpsOrMock(selectedLocation);
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}
