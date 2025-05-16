// lib/models/maneuver.dart
import 'package:latlong2/latlong.dart';

enum TurnType {
  straight,
  slightLeft,
  slightRight,
  turnLeft,
  turnRight,
  sharpLeft,
  sharpRight,
  uTurnLeft,
  uTurnRight,
  arrive,
  depart,
}

class Maneuver {
  final LatLng point;
  final TurnType turnType;
  final String? instructionText;

  Maneuver({required this.point, required this.turnType, this.instructionText});

  @override
  String toString() {
    return 'Maneuver{point: $point, turnType: $turnType, instruction: "$instructionText"}';
  }
}
