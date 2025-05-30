// lib/screens/map_screen.dart - KOMPLETT NEU MIT STABILEN TEXTFIELDS
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector_map_tiles;
import 'package:latlong2/latlong.dart';

import 'package:camping_osm_navi/models/location_info.dart';
import 'package:camping_osm_navi/providers/location_provider.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/widgets/search_container.dart';
import 'package:camping_osm_navi/widgets/stable_search_input.dart';
import 'package:camping_osm_navi/services/search_manager.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  // Map Controller
  final MapController _mapController = MapController();

  // Search Controllers
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  // Search Manager
  late SearchManager _searchManager;

  // State
  bool _isLoading = false;
  String _maptilerUrlTemplate = '';
  LocationInfo? _lastProcessedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchManager = SearchManager();
    _initializeApp();
  }

  void _initializeApp() {
    final apiKey = dotenv.env['MAPTILER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      if (kDebugMode) {
        print("WARNUNG: MAPTILER_API_KEY nicht in .env gefunden!");
      }
      _maptilerUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    } else {
      _maptilerUrlTemplate =
          'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$apiKey';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final newLocationInfo = locationProvider.selectedLocation;

    // Check if location changed
    if (newLocationInfo != null &&
        (_lastProcessedLocation == null ||
            newLocationInfo.id != _lastProcessedLocation!.id)) {
      _handleLocationChange(newLocationInfo);
      _lastProcessedLocation = newLocationInfo;
    }

    // Initialize search with features
    if (locationProvider.currentSearchableFeatures.isNotEmpty) {
      _searchManager.initialize(locationProvider.currentSearchableFeatures);
    }
  }

  void _handleLocationChange(LocationInfo newLocation) {
    // Reset search fields
    _startController.clear();
    _destinationController.clear();
    _searchManager.clearSearch();

    // Center map on new location
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(newLocation.initialCenter, 17.0);
        }
      });
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // ✅ KRITISCH: Keine Keyboard-Interferenz mehr!
    // Lassen wir das System das Keyboard verwalten
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startController.dispose();
    _destinationController.dispose();
    _startFocusNode.dispose();
    _destinationFocusNode.dispose();
    _searchManager.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final selectedLocation = locationProvider.selectedLocation;
    final isLoading = locationProvider.isLoadingLocationData;
    final mapTheme = locationProvider.mapTheme;
    final isGraphReady = locationProvider.currentRoutingGraph != null;
    final isReady = !isLoading && isGraphReady && mapTheme != null;

    return Scaffold(
      appBar: _buildAppBar(locationProvider),
      body: Stack(
        children: [
          // Map - KEINE GestureDetector Interferenz!
          _buildMap(isReady, mapTheme, selectedLocation),

          // Search Container - Über der Map
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ListenableBuilder(
                listenable: _searchManager,
                builder: (context, child) {
                  return SearchContainer(
                    startController: _startController,
                    destinationController: _destinationController,
                    startFocusNode: _startFocusNode,
                    destinationFocusNode: _destinationFocusNode,
                    searchResults: _searchManager.currentResults,
                    onTextChanged: _onTextChanged,
                    onFeatureSelected: _onFeatureSelected,
                    onCurrentLocationPressed: _onCurrentLocationPressed,
                    onSwapPressed: _onSwapPressed,
                    showSearchResults: _searchManager.hasResults,
                  );
                },
              ),
            ),
          ),

          // Loading Overlay
          if (isLoading) _buildLoadingOverlay(selectedLocation),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(selectedLocation),
    );
  }

  AppBar _buildAppBar(LocationProvider locationProvider) {
    final availableLocations = locationProvider.availableLocations;
    final selectedLocation = locationProvider.selectedLocation;
    final isLoading = locationProvider.isLoadingLocationData;

    return AppBar(
      title: const Text("Campground Navigator"),
      backgroundColor: Colors.deepOrange,
      foregroundColor: Colors.white,
      actions: [
        // Location Dropdown
        if (availableLocations.isNotEmpty && selectedLocation != null)
          _buildLocationDropdown(
              availableLocations, selectedLocation, isLoading),

        // Settings/Debug Button
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            _showSettingsDialog();
          },
        ),
      ],
    );
  }

  Widget _buildLocationDropdown(
      List<LocationInfo> locations, LocationInfo selected, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LocationInfo>(
          value: selected,
          icon: const Icon(Icons.public, color: Colors.white),
          dropdownColor: Colors.deepOrange[700],
          style: const TextStyle(color: Colors.white),
          items: locations
              .map<DropdownMenuItem<LocationInfo>>(
                (LocationInfo location) => DropdownMenuItem<LocationInfo>(
                  value: location,
                  child: Text(
                    location.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: !isLoading ? _onLocationSelectedFromDropdown : null,
          hint: const Text("Standort wählen",
              style: TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }

  Widget _buildMap(
      bool isReady, dynamic mapTheme, LocationInfo? selectedLocation) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: selectedLocation?.initialCenter ??
            const LatLng(51.02518780487824, 5.858832278816441),
        initialZoom: 17.0,
        minZoom: 13.0,
        maxZoom: 20.0,
        // ✅ KRITISCH: Keine onTap/onMapEvent Callbacks die unfocus triggern!
        onMapReady: _onMapReady,
      ),
      children: [
        _buildMapLayer(isReady, mapTheme),
        // TODO: Hier können später Marker, Routen etc. hinzugefügt werden
      ],
    );
  }

  Widget _buildMapLayer(bool isReady, dynamic mapTheme) {
    final bool vectorConditionsMet = isReady &&
        _maptilerUrlTemplate.isNotEmpty &&
        _maptilerUrlTemplate.contains('key=');

    if (vectorConditionsMet) {
      return vector_map_tiles.VectorTileLayer(
        theme: mapTheme,
        fileCacheTtl: const Duration(days: 7),
        tileProviders: vector_map_tiles.TileProviders({
          'openmaptiles': vector_map_tiles.NetworkVectorTileProvider(
            urlTemplate: _maptilerUrlTemplate,
            maximumZoom: 14,
          ),
        }),
        maximumZoom: 20,
      );
    } else {
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.camping_osm_navi',
      );
    }
  }

  Widget _buildLoadingOverlay(LocationInfo? selectedLocation) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                "Lade Kartendaten für ${selectedLocation?.name ?? '...'}...",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons(LocationInfo? selectedLocation) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Manual keyboard hide button (für Tests)
        FloatingActionButton.small(
          heroTag: "hideKeyboard",
          onPressed: () {
            FocusScope.of(context).unfocus();
          },
          tooltip: 'Keyboard ausblenden',
          backgroundColor: Colors.red,
          child: const Icon(Icons.keyboard_hide, color: Colors.white),
        ),
        const SizedBox(height: 8),

        // Center map button
        FloatingActionButton(
          heroTag: "centerMap",
          onPressed: () {
            final center = selectedLocation?.initialCenter ??
                const LatLng(51.02518780487824, 5.858832278816441);
            _mapController.move(center, 17.0);
          },
          tooltip: 'Karte zentrieren',
          child: const Icon(Icons.my_location),
        ),
      ],
    );
  }

  // Event Handlers
  void _onTextChanged(String text, SearchFieldType fieldType) {
    if (kDebugMode) {
      print('[MapScreen] Text changed: $text for field: $fieldType');
    }
    _searchManager.search(text, fieldType);
  }

  void _onFeatureSelected(
      SearchableFeature feature, SearchFieldType fieldType) {
    if (kDebugMode) {
      print(
          '[MapScreen] Feature selected: ${feature.name} for field: $fieldType');
    }

    if (fieldType == SearchFieldType.start) {
      _startController.text = feature.name;
    } else {
      _destinationController.text = feature.name;
    }

    // ✅ KRITISCH: Kein unfocus nach Feature-Auswahl!
    // Benutzer kann weiter tippen/korrigieren

    _searchManager.clearSearch();

    // Center map on selected feature
    _mapController.move(feature.center, 18.0);

    _showSnackbar('${feature.name} ausgewählt');
  }

  void _onCurrentLocationPressed() {
    if (kDebugMode) {
      print('[MapScreen] Current location pressed');
    }
    _startController.text = "Aktuelle Position";
    _searchManager.clearSearch();
    _showSnackbar('Aktuelle Position als Start gesetzt');
  }

  void _onSwapPressed() {
    if (kDebugMode) {
      print('[MapScreen] Swap pressed');
    }
    final tempText = _startController.text;
    _startController.text = _destinationController.text;
    _destinationController.text = tempText;
    _showSnackbar('Start und Ziel getauscht');
  }

  void _onLocationSelectedFromDropdown(LocationInfo? newLocation) {
    if (newLocation != null) {
      Provider.of<LocationProvider>(context, listen: false)
          .selectLocation(newLocation);
    }
  }

  void _onMapReady() {
    if (kDebugMode) {
      print('[MapScreen] Map ready');
    }
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.selectedLocation != null) {
      _mapController.move(
          locationProvider.selectedLocation!.initialCenter, 17.0);
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Einstellungen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.clear_all),
                title: const Text('Suchfelder leeren'),
                onTap: () {
                  Navigator.pop(context);
                  _startController.clear();
                  _destinationController.clear();
                  _searchManager.clearSearch();
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard_hide),
                title: const Text('Keyboard ausblenden'),
                onTap: () {
                  Navigator.pop(context);
                  FocusScope.of(context).unfocus();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackbar(String message, {int durationSeconds = 2}) {
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: durationSeconds),
        ),
      );
    }
  }
}
