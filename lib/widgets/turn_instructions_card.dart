// lib/widgets/turn_instruction_card.dart
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/maneuver.dart'; // Import für Maneuver und TurnType
import 'package:camping_osm_navi/screens/map_screen.dart'; // Import für MapScreen Konstanten

// Helper-Funktion für Icons, hierher verschoben
IconData getIconForTurnType(TurnType turnType) {
  // public gemacht
  switch (turnType) {
    case TurnType.depart:
      return Icons.navigation;
    case TurnType.slightLeft:
      return Icons.turn_slight_left;
    case TurnType.slightRight:
      return Icons.turn_slight_right;
    case TurnType.turnLeft:
      return Icons.turn_left;
    case TurnType.turnRight:
      return Icons.turn_right;
    case TurnType.sharpLeft:
      return Icons.turn_sharp_left;
    case TurnType.sharpRight:
      return Icons.turn_sharp_right;
    case TurnType.uTurnLeft:
    case TurnType.uTurnRight:
      return Icons.u_turn_left;
    case TurnType.straight:
      return Icons.straight;
    case TurnType.arrive:
      return Icons.flag_circle_outlined;
    default:
      return Icons.help_outline;
  }
}

class TurnInstructionCard extends StatelessWidget {
  final Maneuver maneuver;

  const TurnInstructionCard({super.key, required this.maneuver});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
          maxWidth: MapScreen.searchCardMaxWidth +
              50), // Verwendet Konstante aus MapScreen
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                getIconForTurnType(
                    maneuver.turnType), // Aufruf der public Funktion
                size: 36.0,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  maneuver.instructionText ?? '',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
