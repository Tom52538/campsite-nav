import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/location_info.dart';
import '../models/maneuver.dart';
import '../models/searchable_feature.dart';
import '../providers/location_provider.dart';
import '../services/geojson_parser_service.dart';
import '../services/routing_service.dart';
import '../services/style_caching_service.dart';
import '../services/tts_service.dart';
import '../widgets/turn_instruction_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final MapController _mapController;
  final TtsService _ttsService = TtsService();
  final List<SearchableFeature> _searchableFeatures = [];

  final List<Polygon> _polygons = [];
  final List<Polyline> _polylines = [];
  final List<Marker> _markers = [];
  final List<LatLng> _routePoints = [];

  LatLng? _startPoint;
  LatLng? _endPoint;
  Maneuver? _currentManeuver;

  RoutingService? _routingService;
  bool _isLoading = true;
  bool _isGpsMocked = false;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _mockGpsTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final bool permissionsGranted = await locationProvider.initialize();

    if (!permissionsGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Standortberechtigung wurde verweigert. Die App kann nicht alle Funktionen ausführen.'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      _positionSubscription =
          locationProvider.positionStream?.listen((position) {
        final locationInfo = LocationInfo(
          latlng: LatLng(position.latitude, position.longitude),
          accuracy: position.accuracy,
          speed: position.speed,
        );
        if (mounted) {
          _updateRoute(locationInfo.latlng);
          if (locationProvider.isFollowing) {
            _animatedMapMove(locationInfo.latlng, 18.0);
          }
        }
      });
    }

    final geoJsonService = GeoJsonParserService();
    await geoJsonService.loadGeoJson(context);

    setState(() {
      _searchableFeatures.addAll(geoJsonService.getSearchableFeatures());
      _routingService = RoutingService(geoJsonService.getRoutingGraph());
      _polygons.addAll(geoJsonService.getPolygons());
      _polylines.addAll(geoJsonService.getPolylines());
      _markers.addAll(geoJsonService.getMarkers());
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mockGpsTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _updateRoute(LatLng currentPosition) {
    if (_routingService == null || _endPoint == null) return;

    final route = _routingService!.getRoute(currentPosition, _endPoint!);
    if (route.isNotEmpty) {
      setState(() {
        _routePoints.clear();
        _routePoints.addAll(route);
        _updateManeuver(currentPosition, route);
      });
    }
  }

  void _updateManeuver(LatLng currentPosition, List<LatLng> route) {
    if (route.length < 2) return;

    final maneuver = _routingService!.getManeuver(currentPosition, route);
    if (maneuver != _currentManeuver) {
      setState(() {
        _currentManeuver = maneuver;
      });
      _ttsService.speak(maneuver.instruction);
    }
  }

  void _toggleGpsMocking() {
    setState(() {
      _isGpsMocked = !_isGpsMocked;
      if (_isGpsMocked) {
        _positionSubscription?.cancel();
        _initializeMockGps();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mock GPS aktiviert")),
        );
      } else {
        _mockGpsTimer?.cancel();
        _initializeGpsReal();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mock GPS deaktiviert")),
        );
      }
    });
  }

  void _initializeMockGps() {
    if (_routePoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Für Mock-GPS muss zuerst eine Route geplant sein.")),
        );
      }
      setState(() {
        _isGpsMocked = false;
      });
      return;
    }
    int currentPointIndex = 0;
    _mockGpsTimer = Timer.periodic(const Duration(seconds: 2), (Timer t) {
      if (currentPointIndex < _routePoints.length) {
        final mockPosition = _routePoints[currentPointIndex];
        Provider.of<LocationProvider>(context, listen: false)
            .toggleFollowing(); // Mock-Positionen sollen die Karte steuern
        _updateRoute(mockPosition);
        if (Provider.of<LocationProvider>(context, listen: false).isFollowing) {
          _animatedMapMove(mockPosition, 18.0);
        }
        Provider.of<LocationProvider>(context, listen: false).toggleFollowing();
        currentPointIndex++;
      } else {
        t.cancel();
        setState(() {
          _isGpsMocked = false;
        });
      }
    });
  }

  void _initializeGpsReal() async {
    _positionSubscription?.cancel();
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final hasPermission = await locationProvider.initialize();
    if (hasPermission) {
      _positionSubscription =
          locationProvider.positionStream?.listen((position) {
        final locationInfo = LocationInfo(
            latlng: LatLng(position.latitude, position.longitude),
            accuracy: position.accuracy,
            speed: position.speed);
        if (mounted) {
          _updateRoute(locationInfo.latlng);
          if (locationProvider.isFollowing) {
            _animatedMapMove(locationInfo.latlng, 18.0);
          }
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Standortberechtigung wurde verweigert.")),
        );
      }
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!_mapController.ready) return;

    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween =
        Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    final animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _showSearchDialog() async {
    final selected = await showSearch<SearchableFeature>(
      context: context,
      delegate: FeatureSearchDelegate(_searchableFeatures),
    );

    if (selected != null) {
      setState(() {
        _endPoint = selected.location;
        _markers.removeWhere((m) => m.key == const Key('end_marker'));
        _markers.add(
          Marker(
            key: const Key('end_marker'),
            width: 80.0,
            height: 80.0,
            point: _endPoint!,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
          ),
        );
      });
      final currentPosition =
          Provider.of<LocationProvider>(context, listen: false)
              .currentLocation
              ?.latlng;
      if (currentPosition != null) {
        _updateRoute(currentPosition);
      }
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Camping OSM Navi'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _showSearchDialog,
        ),
        IconButton(
          icon: Icon(_isGpsMocked ? Icons.gps_fixed : Icons.gps_not_fixed),
          onPressed: _toggleGpsMocking,
        ),
      ],
    );
  }

  Widget _buildMap(LocationInfo? currentLocation) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: currentLocation?.latlng ?? const LatLng(51.5, -0.09),
        initialZoom: 18.0,
        minZoom: 10.0,
        maxZoom: 22.0,
      ),
      children: [
        _buildTileLayer(),
        PolygonLayer(polygons: _polygons),
        PolylineLayer(polylines: [
          Polyline(
              points: _routePoints,
              strokeWidth: 4.0,
              color: Colors.blue,
              isDotted: true),
          ..._polylines
        ]),
        MarkerLayer(markers: [
          if (currentLocation != null)
            Marker(
              width: 80.0,
              height: 80.0,
              point: currentLocation.latlng,
              child: _LocationMarker(accuracy: currentLocation.accuracy),
            ),
          ..._markers,
        ]),
      ],
    );
  }

  TileLayer _buildTileLayer() {
    if (kIsWeb) {
      // Für Web immer OSM-Rasterkacheln verwenden, da Caching hier nicht unterstützt wird
      return TileLayer(
        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        subdomains: const ['a', 'b', 'c'],
      );
    }
    // Für andere Plattformen den StyleCachingService verwenden
    return TileLayer(
      tileProvider: StyleCachingService.instance.tileProvider,
      urlTemplate: StyleCachingService.instance.styleUrl,
    );
  }

  Widget _buildFloatingActionButtons(LocationProvider locationProvider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: "btn_follow",
          onPressed: () {
            locationProvider.toggleFollowing();
          },
          child: Icon(locationProvider.isFollowing
              ? Icons.my_location
              : Icons.location_disabled),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: "btn_zoom_in",
          onPressed: () {
            _mapController.move(
                _mapController.camera.center, _mapController.camera.zoom + 1);
          },
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: "btn_zoom_out",
          onPressed: () {
            _mapController.move(
                _mapController.camera.center, _mapController.camera.zoom - 1);
          },
          child: const Icon(Icons.remove),
        ),
      ],
    );
  }
}

class FeatureSearchDelegate extends SearchDelegate<SearchableFeature> {
  final List<SearchableFeature> features;

  FeatureSearchDelegate(this.features);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, features.first);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = features
        .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(results[index].name),
          onTap: () {
            close(context, results[index]);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = features
        .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(results[index].name),
          onTap: () {
            query = results[index].name;
            showResults(context);
          },
        );
      },
    );
  }
}

class _LocationMarker extends StatelessWidget {
  final double accuracy;
  const _LocationMarker({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20 + accuracy,
            height: 20 + accuracy,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
