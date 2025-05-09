// lib/providers/location_provider.dart

import 'package:flutter/foundation.dart';
import 'package:camping_osm_navi/models/location_info.dart';

class LocationProvider with ChangeNotifier {
  final List<LocationInfo> _availableLocations =
      appLocations; // Aus location_info.dart
  LocationInfo? _selectedLocation;

  LocationProvider() {
    // Initialisiere den ersten Standort als ausgewählt, falls verfügbar
    if (_availableLocations.isNotEmpty) {
      _selectedLocation = _availableLocations.first;
    }
  }

  List<LocationInfo> get availableLocations => _availableLocations;
  LocationInfo? get selectedLocation => _selectedLocation;

  /// Aktualisiert den ausgewählten Standort und benachrichtigt Listener.
  void selectLocation(LocationInfo? newLocation) {
    if (newLocation != null && newLocation != _selectedLocation) {
      _selectedLocation = newLocation;
      if (kDebugMode) {
        print("[LocationProvider] Standort gewechselt zu: ${newLocation.name}");
      }
      notifyListeners(); // Benachrichtigt alle Widgets, die auf diesen Provider hören
    }
  }
}
