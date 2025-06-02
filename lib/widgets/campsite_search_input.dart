// lib/widgets/campsite_search_input.dart - COMPLETE FILE
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';

enum SearchFieldType { start, destination }

class CampsiteSearchInput extends StatefulWidget {
  final SearchFieldType fieldType;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(SearchableFeature) onFeatureSelected;
  final VoidCallback? onCurrentLocationTap;
  final VoidCallback? onMapSelectionTap;
  final List<SearchableFeature> allFeatures;

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

    // Smart Result Limiting
    final results = widget.allFeatures.where((feature) {
      final name = feature.name.toLowerCase();
      final type = feature.type.toLowerCase();
      final q = query.toLowerCase();
      return name.contains(q) || type.contains(q);
    }).toList();

    // Prioritization: Exact matches first
    results.sort((a, b) {
      final aExact = a.name.toLowerCase().startsWith(query.toLowerCase());
      final bExact = b.name.toLowerCase().startsWith(query.toLowerCase());

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return a.name.compareTo(b.name);
    });

    return results.take(8).toList(); // Max 8 for mobile
  }

  IconData _getIconForType(String type) {
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
      case 'reception':
      case 'information':
        return Icons.info;
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

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'building':
      case 'accommodation':
        return Colors.brown.shade600;
      case 'shop':
        return Colors.purple.shade600;
      case 'amenity':
        return Colors.green.shade600;
      case 'tourism':
        return Colors.orange.shade600;
      case 'restaurant':
      case 'cafe':
      case 'bar':
        return Colors.red.shade600;
      case 'reception':
      case 'information':
        return Colors.teal.shade600;
      case 'toilets':
      case 'sanitary':
        return Colors.cyan.shade600;
      case 'playground':
        return Colors.pink.shade600;
      case 'parking':
        return Colors.indigo.shade600;
      default:
        return Colors.grey.shade600;
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
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: widget.focusNode.hasFocus
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: widget.focusNode.hasFocus ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha((0.1 * 255).round()),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  widget.fieldType == SearchFieldType.start
                      ? Icons.trip_origin
                      : Icons.flag_outlined,
                  color: widget.focusNode.hasFocus
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  decoration: InputDecoration(
                    hintText: widget.fieldType == SearchFieldType.start
                        ? 'Enter starting point'
                        : 'Enter destination',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                  ),
                  style: const TextStyle(fontSize: 16),
                  // Keyboard-friendly configuration
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  onChanged: (text) { /* Handled by listener */ },
                ),
              ),
              // Action buttons row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current location button (only for start field)
                  if (widget.onCurrentLocationTap != null && widget.fieldType == SearchFieldType.start)
                    IconButton(
                      icon: Icon(
                        Icons.my_location,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      tooltip: 'Use current location',
                      onPressed: widget.onCurrentLocationTap,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),

                  // Map selection button
                  if (widget.onMapSelectionTap != null)
                    IconButton(
                      icon: Icon(
                        Icons.map_outlined,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),
                      tooltip: 'Select on map',
                      onPressed: widget.onMapSelectionTap,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),

                  // Clear button
                  if (widget.controller.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        // _onTextChanged will be called by listener
                      },
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_showResults && _filteredFeatures.isNotEmpty)
          _buildResultsList(),
      ],
    );
  }

  Widget _buildResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.15 * 255).round()),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 240), // Max height for the list
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _filteredFeatures.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade200,
          indent: 52,
        ),
        itemBuilder: (context, index) {
          final feature = _filteredFeatures[index];
          return ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getColorForType(feature.type).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconForType(feature.type),
                color: _getColorForType(feature.type),
                size: 20,
              ),
            ),
            title: Text(
              feature.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              feature.type,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: () {
              widget.onFeatureSelected(feature);
              // Hide results after selection
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
