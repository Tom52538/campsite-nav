// lib/widgets/turn_instruction_card.dart
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/maneuver.dart';
// Import für MapScreen Konstanten, falls sie hier direkt gebraucht würden.
// Aktuell wird MapScreen.searchCardMaxWidth in map_screen.dart verwendet und an das Widget übergeben.
// Wenn du hier direkt auf MapScreen zugreifen müsstest:
// import 'package:camping_osm_navi/screens/map_screen.dart';

IconData getIconForTurnType(TurnType turnType) {
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
    // Kein default mehr nötig, da alle Enum-Werte abgedeckt sind.
    // Flutter/Dart wird warnen, wenn ein neuer Enum-Wert hinzugefügt wird und hier fehlt.
  }
}

class TurnInstructionCard extends StatelessWidget {
  final Maneuver maneuver;
  final double maxWidth; // Hinzugefügt, um von außen zu steuern

  const TurnInstructionCard({
    super.key,
    required this.maneuver,
    this.maxWidth = 410, // Standardwert (MapScreen.searchCardMaxWidth + 50)
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
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
                getIconForTurnType(maneuver.turnType),
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
