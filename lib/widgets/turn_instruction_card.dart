// lib/widgets/turn_instruction_card.dart
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/maneuver.dart';

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
  }
}

Color getColorForTurnType(TurnType turnType) {
  switch (turnType) {
    case TurnType.depart:
      return Colors.green;
    case TurnType.arrive:
      return Colors.red;
    case TurnType.uTurnLeft:
    case TurnType.uTurnRight:
      return Colors.orange;
    case TurnType.sharpLeft:
    case TurnType.sharpRight:
      return Colors.deepOrange;
    default:
      return Colors.blue;
  }
}

class TurnInstructionCard extends StatelessWidget {
  final Maneuver maneuver;
  final double maxWidth;
  final double? distanceToManeuver; // ✅ NEU: Distanzanzeige

  const TurnInstructionCard({
    super.key,
    required this.maneuver,
    this.maxWidth = 410,
    this.distanceToManeuver, // ✅ NEU
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Card(
        elevation: 8.0, // ✅ Mehr Tiefe
        shadowColor: Colors.black.withValues(alpha: 0.3), // ✅ Schönere Schatten
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0), // ✅ Rundere Ecken
          side: BorderSide(
            color:
                getColorForTurnType(maneuver.turnType).withValues(alpha: 0.3),
            width: 2.0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            gradient: LinearGradient(
              // ✅ Schöner Gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                getColorForTurnType(maneuver.turnType).withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ NEU: Animiertes Icon Container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 60.0,
                  height: 60.0,
                  decoration: BoxDecoration(
                    color: getColorForTurnType(maneuver.turnType)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30.0),
                    border: Border.all(
                      color: getColorForTurnType(maneuver.turnType),
                      width: 2.0,
                    ),
                  ),
                  child: Icon(
                    getIconForTurnType(maneuver.turnType),
                    size: 32.0, // ✅ Größeres Icon
                    color: getColorForTurnType(maneuver.turnType),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ NEU: Distanzanzeige
                      if (distanceToManeuver != null &&
                          distanceToManeuver! > 15)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: getColorForTurnType(maneuver.turnType)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            _formatDistance(distanceToManeuver!),
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: getColorForTurnType(maneuver.turnType),
                            ),
                          ),
                        ),
                      if (distanceToManeuver != null &&
                          distanceToManeuver! > 15)
                        const SizedBox(height: 4.0),

                      // ✅ Verbesserter Anweisungstext
                      Text(
                        maneuver.instructionText ?? '',
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.left,
                      ),

                      // ✅ NEU: Sofortige Ausführung Hinweis
                      if (distanceToManeuver != null &&
                          distanceToManeuver! <= 15)
                        Container(
                          margin: const EdgeInsets.only(top: 4.0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Text(
                            "JETZT",
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      int roundedDistance = (distanceMeters / 10).round() * 10;
      return "${roundedDistance}m";
    } else {
      return "${(distanceMeters / 1000).toStringAsFixed(1)}km";
    }
  }
}

// ✅ NEU: Wunderschöne Camping-spezifische Icons als Custom Widgets
class CampingNavigationIcon extends StatelessWidget {
  final TurnType turnType;
  final double size;
  final Color color;

  const CampingNavigationIcon({
    super.key,
    required this.turnType,
    this.size = 32.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CampingIconPainter(turnType, color),
    );
  }
}

class _CampingIconPainter extends CustomPainter {
  final TurnType turnType;
  final Color color;

  _CampingIconPainter(this.turnType, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (turnType) {
      case TurnType.depart:
        // Camping-Zelt Icon
        _drawTent(canvas, size, paint);
        break;
      case TurnType.arrive:
        // Camping-Flagge Icon
        _drawFlag(canvas, size, paint);
        break;
      case TurnType.turnLeft:
      case TurnType.turnRight:
        // Schöner Pfeil
        _drawArrow(canvas, size, paint);
        break;
      default:
        // Fallback: Kreis mit Pfeil
        _drawArrow(canvas, size, paint);
    }
  }

  void _drawTent(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);

    // Zelt-Form
    path.moveTo(center.dx - size.width * 0.3, center.dy + size.height * 0.2);
    path.lineTo(center.dx, center.dy - size.height * 0.2);
    path.lineTo(center.dx + size.width * 0.3, center.dy + size.height * 0.2);
    path.close();

    paint.style = PaintingStyle.fill;
    paint.color = paint.color.withValues(alpha: 0.3);
    canvas.drawPath(path, paint);

    paint.style = PaintingStyle.stroke;
    paint.color = color;
    canvas.drawPath(path, paint);
  }

  void _drawFlag(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);

    // Flaggenmast
    canvas.drawLine(
      Offset(center.dx - size.width * 0.2, center.dy - size.height * 0.3),
      Offset(center.dx - size.width * 0.2, center.dy + size.height * 0.3),
      paint,
    );

    // Flagge
    final flagPath = Path();
    flagPath.moveTo(
        center.dx - size.width * 0.2, center.dy - size.height * 0.3);
    flagPath.lineTo(
        center.dx + size.width * 0.2, center.dy - size.height * 0.1);
    flagPath.lineTo(center.dx + size.width * 0.1, center.dy);
    flagPath.lineTo(
        center.dx - size.width * 0.2, center.dy - size.height * 0.05);
    flagPath.close();

    paint.style = PaintingStyle.fill;
    paint.color = paint.color.withValues(alpha: 0.7);
    canvas.drawPath(flagPath, paint);
  }

  void _drawArrow(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final arrowPath = Path();

    // Pfeil-Körper
    arrowPath.moveTo(
        center.dx - size.width * 0.1, center.dy - size.height * 0.3);
    arrowPath.lineTo(
        center.dx - size.width * 0.1, center.dy + size.height * 0.1);
    arrowPath.lineTo(
        center.dx + size.width * 0.1, center.dy + size.height * 0.1);
    arrowPath.lineTo(
        center.dx + size.width * 0.1, center.dy - size.height * 0.3);

    // Pfeilspitze
    arrowPath.lineTo(
        center.dx + size.width * 0.2, center.dy - size.height * 0.3);
    arrowPath.lineTo(center.dx, center.dy - size.height * 0.4);
    arrowPath.lineTo(
        center.dx - size.width * 0.2, center.dy - size.height * 0.3);
    arrowPath.close();

    paint.style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
