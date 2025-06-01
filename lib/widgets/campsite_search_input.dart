// lib/widgets/campsite_search_input.dart
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart'; // Assuming this path is correct

// Assuming SearchFieldType is defined elsewhere, e.g., lib/models/search_field_type.dart
// or move the enum from stable_search_input.dart here / to a model file.
enum SearchFieldType { start, destination }

class CampsiteSearchInput extends StatefulWidget {
  final SearchFieldType fieldType;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(SearchableFeature) onFeatureSelected;
  final VoidCallback? onCurrentLocationTap;
  final VoidCallback? onMapSelectionTap;
  final List<SearchableFeature> allFeatures; // From LocationProvider

  const CampsiteSearchInput({
    super.key,
    required this.fieldType,
    required this.controller,
    required this.focusNode,
    required this.onFeatureSelected,
    this.onCurrentLocationTap,
    this.onMapSelectionTap,
    required this.allFeatures,
  });

  @override
  State<CampsiteSearchInput> createState() => _CampsiteSearchInputState();
}

class _CampsiteSearchInputState extends State<CampsiteSearchInput> {
  bool _showResults = false;
  List<SearchableFeature> _filteredFeatures = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        _filteredFeatures = _filterFeatures(widget.controller.text);
        _showResults = widget.controller.text.isNotEmpty && widget.focusNode.hasFocus;
      });
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        if (widget.focusNode.hasFocus) {
          _showResults = widget.controller.text.isNotEmpty;
          if (widget.controller.text.isNotEmpty) {
             _filteredFeatures = _filterFeatures(widget.controller.text);
          }
        } else {
          // Delay hiding results to allow tap event on list to register
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && !widget.focusNode.hasFocus) {
              setState(() {
                _showResults = false;
              });
            }
          });
        }
      });
    }
  }

  List<SearchableFeature> _filterFeatures(String query) {
    if (query.length < 2) return [];

    // Smart Result Limiting from the issue description
    final results = widget.allFeatures.where((feature) {
      final name = feature.name.toLowerCase();
      final type = feature.type.toLowerCase(); // Assuming SearchableFeature has a 'type' property
      final q = query.toLowerCase();
      return name.contains(q) || type.contains(q);
    }).toList();

    // Prioritization: Exakte Treffer zuerst
    results.sort((a, b) {
      final aExact = a.name.toLowerCase().startsWith(query.toLowerCase());
      final bExact = b.name.toLowerCase().startsWith(query.toLowerCase());

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return a.name.compareTo(b.name);
    });

    return results.take(8).toList(); // Max 8 für Mobile
  }

  IconData _getIconForType(String type) {
    // Example icons, adapt as needed from existing StableSearchInput or project assets
    switch (type.toLowerCase()) {
      case 'parking':
        return Icons.local_parking;
      case 'building':
      case 'accommodation':
        return Icons.business;
      case 'shop':
        return Icons.store;
      case 'amenity':
        return Icons.place;
      case 'tourism':
        return Icons.attractions;
      // Add more cases as per your project's feature types
      default:
        return Icons.location_pin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2), // changes position of shadow
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Icon(
                  widget.fieldType == SearchFieldType.start ? Icons.trip_origin : Icons.flag,
                  color: Colors.grey.shade700,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  decoration: InputDecoration(
                    hintText: widget.fieldType == SearchFieldType.start ? 'Startpunkt' : 'Zielpunkt',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (text) { /* Handled by listener */ },
                ),
              ),
              if (widget.onCurrentLocationTap != null && widget.fieldType == SearchFieldType.start)
                IconButton(
                  icon: Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Aktueller Standort',
                  onPressed: widget.onCurrentLocationTap,
                ),
              if (widget.onMapSelectionTap != null)
                IconButton(
                  icon: Icon(Icons.map_outlined, color: Theme.of(context).colorScheme.secondary),
                  tooltip: 'Auf Karte auswählen',
                  onPressed: widget.onMapSelectionTap,
                ),
               // Clear button
              if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  color: Colors.grey.shade600,
                  onPressed: () {
                    widget.controller.clear();
                    // _onTextChanged will be called by listener, which will update state
                  },
                ),
            ],
          ),
        ),
        if (_showResults && _filteredFeatures.isNotEmpty)
          _buildSimpleResultsList(),
      ],
    );
  }

  Widget _buildSimpleResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 200), // Max height for the list
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredFeatures.length,
        itemBuilder: (context, index) {
          final feature = _filteredFeatures[index];
          return ListTile(
            leading: Icon(_getIconForType(feature.type)),
            title: Text(feature.name),
            subtitle: Text(feature.type), // Assuming SearchableFeature has a 'type' property
            dense: true,
            onTap: () {
              widget.onFeatureSelected(feature);
              // Hide results after selection
              // No need to call controller.clear() or focusNode.unfocus() here,
              // as the parent (SimpleSearchContainer) will handle this.
              if (mounted) {
                setState(() {
                  _showResults = false;
                });
              }
            },
          );
        },
      ),
    );
  }
}
