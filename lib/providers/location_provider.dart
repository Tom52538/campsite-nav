import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:camping_osm_navi/models/routing_graph.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';

import '../models/location_info.dart';

class LocationProvider with ChangeNotifier {
  LocationInfo? _selectedLocation;
  LocationInfo? get selectedLocation => _selectedLocation;

  List<LocationInfo> _availableLocations = [];
  List<LocationInfo> get availableLocations => _availableLocations;

  bool _isLoadingLocationData = true;
  bool get isLoadingLocationData => _isLoadingLocationData;

  vmt.Theme? _mapTheme;
  vmt.Theme? get mapTheme => _mapTheme;

  RoutingGraph? _currentRoutingGraph;
  RoutingGraph? get currentRoutingGraph => _currentRoutingGraph;

  List<SearchableFeature> _currentSearchableFeatures = [];
  List<SearchableFeature> get currentSearchableFeatures => _currentSearchableFeatures;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  bool _isFollowing = true;
  bool get isFollowing => _isFollowing;

  Stream<Position>? _positionStream;
  Stream<Position>? get positionStream => _positionStream;
  BuildContext? _context;

  void selectLocation(LocationInfo location) {
    _selectedLocation = location;
    notifyListeners();
  }

  Future<void> initialize(BuildContext context) async {
    _context = context;
    _checkPermission();
    _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    )).map((Position position) {
      _currentPosition = position;
      if (_isFollowing) {
        notifyListeners();
      }
      return position;
    });
    notifyListeners();
  }

  void toggleFollowing() {
    _isFollowing = !_isFollowing;
    notifyListeners();
  }

  Future<void> _checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Handle service not enabled
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionSnackbar();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionSnackbar();
    }
  }

  void _showPermissionSnackbar() {
    if (_context != null && ScaffoldMessenger.maybeOf(_context!) != null) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        const SnackBar(
          content: Text('Standortberechtigung wurde verweigert.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
