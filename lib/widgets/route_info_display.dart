// lib/widgets/route_info_display.dart - KORRIGIERT
import 'package:flutter/material.dart';

class RouteInfoDisplay extends StatelessWidget {
  final double? routeDistance;
  final int? routeTimeMinutes;
  final double? remainingRouteDistance;
  final int? remainingRouteTimeMinutes;
  final bool isCompact;

  // Für Rückwärtskompatibilität mit dem bestehenden Code
  final double? distanceInMeters;
  final int? timeInMinutes;

  const RouteInfoDisplay({
    super.key,
    this.routeDistance,
    this.routeTimeMinutes,
    this.remainingRouteDistance,
    this.remainingRouteTimeMinutes,
    this.isCompact = false,
    this.distanceInMeters,
    this.timeInMinutes,
  });

  @override
  Widget build(BuildContext context) {
    // Prüfe beide Möglichkeiten für Rückwärtskompatibilität
    final double? displayDistance =
        remainingRouteDistance ?? routeDistance ?? distanceInMeters;
    final int? displayTime =
        remainingRouteTimeMinutes ?? routeTimeMinutes ?? timeInMinutes;

    if (displayDistance == null || displayTime == null) {
      return const SizedBox.shrink();
    }

    final String prefix = remainingRouteDistance != null ? "Rest: " : "";
    final String timeText = "$prefix~$displayTime min";

    if (isCompact) {
      return _buildCompactInfo(context, timeText, displayDistance);
    } else {
      return _buildDetailedInfo(context, timeText, displayDistance);
    }
  }

  Widget _buildCompactInfo(
      BuildContext context, String timeText, double distance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_walk,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _formatDistance(distance),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedInfo(
      BuildContext context, String timeText, double distance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Route Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(timeText),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.straighten,
                  size: 20,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(_formatDistance(distance)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return "${distanceInMeters.round()}m";
    } else {
      return "${(distanceInMeters / 1000).toStringAsFixed(1)}km";
    }
  }
}
