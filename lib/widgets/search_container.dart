// lib/widgets/search_container.dart - NEUE SUCH-CONTAINER KOMPONENTE
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/searchable_feature.dart';

class SearchContainer extends StatefulWidget {
  final Widget? routeInfo;

  const SearchContainer({
    super.key,
    this.routeInfo,
  });

  @override
  State<SearchContainer> createState() => _SearchContainerState();
}

class _SearchContainerState extends State<SearchContainer> {
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
          // Route Info
          if (widget.routeInfo != null) widget.routeInfo!,
        ],
      ),
    );
  }
}
