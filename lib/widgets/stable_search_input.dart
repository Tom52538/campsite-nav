// lib/widgets/stable_search_input.dart - NEUE STABILE TEXTFIELD KOMPONENTE
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';

enum SearchFieldType { start, destination }

class StableSearchInput extends StatefulWidget {
  final SearchFieldType fieldType;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<SearchableFeature> searchResults;
  final Function(String) onTextChanged;
  final Function(SearchableFeature) onFeatureSelected;
  final VoidCallback? onCurrentLocationPressed;
  final bool showResults;

  const StableSearchInput({
    super.key,
    required this.fieldType,
    required this.controller,
    required this.focusNode,
    required this.searchResults,
    required this.onTextChanged,
    required this.onFeatureSelected,
    required this.showResults,
    this.onCurrentLocationPressed,
  });

  @override
  State<StableSearchInput> createState() => _StableSearchInputState();
}

class _StableSearchInputState extends State<StableSearchInput> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        _hasFocus = widget.focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInputField(),
        if (_hasFocus && widget.showResults && widget.searchResults.isNotEmpty)
          _buildSearchResults(),
      ],
    );
  }

  Widget _buildInputField() {
    final isStart = widget.fieldType == SearchFieldType.start;

    return Container(
      decoration: BoxDecoration(
        border: _hasFocus
            ? Border.all(
                color: Theme.of(context).colorScheme.primary, width: 2.0)
            : Border.all(color: Colors.grey.shade300, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
        color: _hasFocus
            ? Theme.of(context).colorScheme.primary.withAlpha(20)
            : Colors.white,
      ),
      child: Row(
        children: [
          // Icon
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              isStart ? Icons.trip_origin : Icons.flag_outlined,
              color: _hasFocus
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade600,
              size: 20,
            ),
          ),

          // TextField
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: widget.onTextChanged,
              decoration: InputDecoration(
                hintText: isStart ? "Startpunkt eingeben" : "Ziel eingeben",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey.shade500),
              ),
              style: const TextStyle(fontSize: 16),
              // ✅ KRITISCH: Keyboard-freundliche Konfiguration
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
            ),
          ),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clear Button
              if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  color: Colors.grey.shade600,
                  onPressed: () {
                    widget.controller.clear();
                    widget.onTextChanged('');
                  },
                ),

              // Current Location Button (nur für Start)
              if (isStart && widget.onCurrentLocationPressed != null)
                IconButton(
                  icon: const Icon(Icons.my_location, size: 20),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: widget.onCurrentLocationPressed,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.searchResults.length,
        itemBuilder: (context, index) {
          final feature = widget.searchResults[index];
          return ListTile(
            dense: true,
            leading: Icon(
              _getIconForFeatureType(feature.type),
              size: 20,
              color: _getColorForPOIType(feature.type),
            ),
            title: Text(
              feature.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              feature.type,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            onTap: () {
              widget.onFeatureSelected(feature);
              // ✅ KRITISCH: Kein automatischer unfocus!
              // widget.focusNode.unfocus(); // ENTFERNT
            },
          );
        },
      ),
    );
  }

  IconData _getIconForFeatureType(String type) {
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
      default:
        return Icons.location_pin;
    }
  }

  Color _getColorForPOIType(String type) {
    switch (type.toLowerCase()) {
      case 'building':
      case 'accommodation':
        return Colors.brown;
      case 'shop':
        return Colors.purple;
      case 'amenity':
        return Colors.green;
      case 'tourism':
        return Colors.orange;
      case 'restaurant':
      case 'cafe':
        return Colors.red;
      case 'reception':
      case 'information':
        return Colors.teal;
      case 'toilets':
      case 'sanitary':
        return Colors.cyan;
      case 'playground':
        return Colors.pink;
      case 'parking':
        return Colors.indigo;
      default:
        return Colors.grey.shade600;
    }
  }
}
