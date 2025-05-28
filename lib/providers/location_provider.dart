import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_info.dart';

class LocationProvider with ChangeNotifier {
  LocationInfo? _currentLocation;
  bool _isFollowing = true;
  Stream<Position>? _positionStream;

  LocationInfo? get currentLocation => _currentLocation;
  bool get isFollowing => _isFollowing;
  Stream<Position>? get positionStream => _positionStream;

  Future<bool> initialize() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).map((Position position) {
      _currentLocation = LocationInfo(
        latlng: LatLng(position.latitude, position.longitude),
        accuracy: position.accuracy,
        speed: position.speed,
      );
      if (_isFollowing) {
        notifyListeners();
      }
      return position;
    });

    notifyListeners();
    return true;
  }

  void toggleFollowing() {
    _isFollowing = !_isFollowing;
    notifyListeners();
  }
}
