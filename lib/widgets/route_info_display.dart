import 'package:flutter/material.dart';
import 'dart:math' as math;

class RouteInfoDisplay extends StatelessWidget {
  final double? distanceInMeters;
  final int? timeInMinutes;

  const RouteInfoDisplay({
    super.key,
    required this.distanceInMeters,
    required this.timeInMinutes,
  });

  @override
  Widget build(BuildContext context) {
    if (distanceInMeters == null || timeInMinutes == null || distanceInMeters == 0) {
      return const SizedBox.shrink();
    }

    String formattedDistance;
    if (distanceInMeters! < 1000) {
      formattedDistance = '${distanceInMeters!.round()} m';
    } else {
      formattedDistance = '${(distanceInMeters! / 1000).toStringAsFixed(1)} km';
    }

    String formattedTime = '${timeInMinutes} min';
    // Simple formatting for now, can be expanded for hours if needed.

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Material( // Using Material for elevation and theming
        elevation: 4.0,
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor, // Use theme's card color
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.route_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '$formattedDistance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                '·', // Separator
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 4),
              Text(
                '$formattedTime',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
