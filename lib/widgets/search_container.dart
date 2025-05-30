// lib/widgets/search_container.dart - NEUE SUCH-CONTAINER KOMPONENTE
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';
import 'package:camping_osm_navi/widgets/stable_search_input.dart';

class SearchContainer extends StatefulWidget {
  final TextEditingController startController;
  final TextEditingController destinationController;
  final FocusNode startFocusNode;
  final FocusNode destinationFocusNode;
  final List<SearchableFeature> searchResults;
  final Function(String, SearchFieldType) onTextChanged;
  final Function(SearchableFeature, SearchFieldType) onFeatureSelected;
  final VoidCallback? onCurrentLocationPressed;
  final VoidCallback? onSwapPressed;
  final bool showSearchResults;
  final Widget? routeInfo;

  const SearchContainer({
    super.key,
    required this.startController,
    required this.destinationController,
    required this.startFocusNode,
    required this.destinationFocusNode,
    required this.searchResults,
    required this.onTextChanged,
    required this.onFeatureSelected,
    required this.showSearchResults,
    this.onCurrentLocationPressed,
    this.onSwapPressed,
    this.routeInfo,
  });

  @override
  State<SearchContainer> createState() => _SearchContainerState();
}

class _SearchContainerState extends State<SearchContainer> {
  SearchFieldType? _activeField;

  @override
  void initState() {
    super.initState();
    widget.startFocusNode.addListener(_onStartFocusChanged);
    widget.destinationFocusNode.addListener(_onDestinationFocusChanged);
  }

  @override
  void dispose() {
    widget.startFocusNode.removeListener(_onStartFocusChanged);
    widget.destinationFocusNode.removeListener(_onDestinationFocusChanged);
    super.dispose();
  }

  void _onStartFocusChanged() {
    if (mounted) {
      setState(() {
        _activeField =
            widget.startFocusNode.hasFocus ? SearchFieldType.start : null;
      });
    }
  }

  void _onDestinationFocusChanged() {
    if (mounted) {
      setState(() {
        _activeField = widget.destinationFocusNode.hasFocus
            ? SearchFieldType.destination
            : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Start Input
          StableSearchInput(
            fieldType: SearchFieldType.start,
            controller: widget.startController,
            focusNode: widget.startFocusNode,
            searchResults: _activeField == SearchFieldType.start
                ? widget.searchResults
                : [],
            onTextChanged: (text) =>
                widget.onTextChanged(text, SearchFieldType.start),
            onFeatureSelected: (feature) =>
                widget.onFeatureSelected(feature, SearchFieldType.start),
            onCurrentLocationPressed: widget.onCurrentLocationPressed,
            showResults: widget.showSearchResults,
          ),

          // Swap Button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton(
                    onPressed: widget.onSwapPressed,
                    icon: const Icon(Icons.swap_vert),
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: const EdgeInsets.all(8.0),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),

          // Destination Input
          StableSearchInput(
            fieldType: SearchFieldType.destination,
            controller: widget.destinationController,
            focusNode: widget.destinationFocusNode,
            searchResults: _activeField == SearchFieldType.destination
                ? widget.searchResults
                : [],
            onTextChanged: (text) =>
                widget.onTextChanged(text, SearchFieldType.destination),
            onFeatureSelected: (feature) =>
                widget.onFeatureSelected(feature, SearchFieldType.destination),
            showResults: widget.showSearchResults,
          ),

          // Route Info
          if (widget.routeInfo != null) ...[
            const SizedBox(height: 12.0),
            widget.routeInfo!,
          ],
        ],
      ),
    );
  }
}
