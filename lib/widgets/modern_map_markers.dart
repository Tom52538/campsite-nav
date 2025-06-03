// lib/widgets/modern_map_markers.dart - GOOGLE MAPS STYLE MARKERS
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ModernMapMarkers {
  // ✅ GOOGLE MAPS STYLE START MARKER (Grüner Punkt)
  static Marker createStartMarker(LatLng position, {String? label}) {
    return Marker(
      width: 24.0,
      height: 24.0,
      point: position,
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(24, 24),
        painter: StartMarkerPainter(label: label),
      ),
    );
  }

  // ✅ GOOGLE MAPS STYLE DESTINATION MARKER (Rote Pinnadel)
  static Marker createDestinationMarker(LatLng position, {String? label}) {
    return Marker(
      width: 36.0,
      height: 48.0,
      point: position,
      alignment: Alignment.bottomCenter,
      child: CustomPaint(
        size: const Size(36, 48),
        painter: DestinationMarkerPainter(label: label),
      ),
    );
  }

  // ✅ MODERNE GPS POSITION MARKER
  static Marker createGpsMarker(LatLng position) {
    return Marker(
      width: 20.0,
      height: 20.0,
      point: position,
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.shade600,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha(60),
              blurRadius: 8,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.navigation,
          size: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  // ✅ POI MARKER (für Parkplätze, Restaurants etc.)
  static Marker createPOIMarker(
    LatLng position, 
    String category, 
    {String? label, VoidCallback? onTap}
  ) {
    return Marker(
      width: 32.0,
      height: 32.0,
      point: position,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          size: const Size(32, 32),
          painter: POIMarkerPainter(category: category, label: label),
        ),
      ),
    );
  }
}

// ✅ START MARKER PAINTER (Grüner Google-Style Punkt)
class StartMarkerPainter extends CustomPainter {
  final String? label;

  StartMarkerPainter({this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Schatten
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(
      center.translate(0, 1), 
      size.width / 2, 
      shadowPaint
    );

    // Weißer Rand
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, size.width / 2, borderPaint);

    // Grüner Kern
    final corePaint = Paint()
      ..color = Colors.green.shade600
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, (size.width / 2) - 3, corePaint);

    // Weißer Punkt in der Mitte
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ✅ DESTINATION MARKER PAINTER (Rote Google-Style Pinnadel)
class DestinationMarkerPainter extends CustomPainter {
  final String? label;

  DestinationMarkerPainter({this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final pinWidth = size.width;
    final pinHeight = size.height * 0.7; // 70% für die Pinnadel
    final radius = pinWidth * 0.4;
    
    // Schatten
    final shadowPath = Path();
    final shadowCenter = Offset(pinWidth / 2, pinHeight / 2);
    shadowPath.addOval(Rect.fromCircle(center: shadowCenter, radius: radius + 2));
    shadowPath.moveTo(pinWidth / 2, pinHeight);
    shadowPath.lineTo(pinWidth / 2 + 3, size.height + 1);
    shadowPath.lineTo(pinWidth / 2 - 3, size.height + 1);
    shadowPath.close();

    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawPath(shadowPath, shadowPaint);

    // Pinnadel Path
    final pinPath = Path();
    final center = Offset(pinWidth / 2, pinHeight / 2);
    
    // Kreis
    pinPath.addOval(Rect.fromCircle(center: center, radius: radius));
    
    // Spitze
    pinPath.moveTo(pinWidth / 2, pinHeight);
    pinPath.lineTo(pinWidth / 2 + 8, pinHeight - 12);
    pinPath.lineTo(pinWidth / 2 - 8, pinHeight - 12);
    pinPath.close();

    // Weißer Rand
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawPath(pinPath, borderPaint);

    // Rote Füllung
    final fillPaint = Paint()
      ..color = Colors.red.shade600
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(pinPath, fillPaint);

    // Weißer Punkt in der Mitte
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ✅ POI MARKER PAINTER (Kategorien-spezifische Marker)
class POIMarkerPainter extends CustomPainter {
  final String category;
  final String? label;

  POIMarkerPainter({required this.category, this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Kategorie-Farbe
    final categoryColor = _getCategoryColor(category);
    
    // Schatten
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawCircle(center.translate(0, 1), radius, shadowPaint);

    // Weißer Rand
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, borderPaint);

    // Kategorie-Farbe
    final corePaint = Paint()
      ..color = categoryColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius - 2, corePaint);

    // Icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: _getCategoryIcon(category),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'parking':
        return Colors.indigo.shade600;
      case 'restaurant':
      case 'food':
        return Colors.orange.shade600;
      case 'playground':
      case 'family':
        return Colors.pink.shade600;
      case 'beach':
      case 'pool':
        return Colors.cyan.shade600;
      case 'shop':
        return Colors.purple.shade600;
      case 'toilets':
      case 'sanitary':
        return Colors.teal.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'parking':
        return '🅿️';
      case 'restaurant':
      case 'food':
        return '🍽️';
      case 'playground':
      case 'family':
        return '🎠';
      case 'beach':
      case 'pool':
        return '🏖️';
      case 'shop':
        return '🛒';
      case 'toilets':
      case 'sanitary':
        return '🚿';
      default:
        return '📍';
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ✅ MODERNE ROUTE POLYLINE (Google Maps Style)
class ModernRoutePolyline {
  static Polyline createModernRoute(List<LatLng> points) {
    return Polyline(
      points: points,
      strokeWidth: 6.0, // Dickere Linie
      color: Colors.blue.shade600,
      borderStrokeWidth: 2.0, // Weißer Rand
      borderColor: Colors.white,
      useStrokeWidthInMeter: false,
    );
  }

  // ✅ ROUTE MIT GRADIENT EFFECT (Advanced)
  static List<Polyline> createGradientRoute(List<LatLng> points) {
    if (points.length < 2) return [];

    return [
      // Schatten-Layer (unten)
      Polyline(
        points: points,
        strokeWidth: 8.0,
        color: Colors.black.withAlpha(20),
      ),
      // Weißer Rand-Layer (mitte)
      Polyline(
        points: points,
        strokeWidth: 7.0,
        color: Colors.white,
      ),
      // Hauptroute-Layer (oben)
      Polyline(
        points: points,
        strokeWidth: 5.0,
        color: Colors.blue.shade600,
      ),
    ];
  }

  // ✅ NAVIGATIONS-ROUTE (während aktiver Navigation)
  static Polyline createNavigationRoute(List<LatLng> points) {
    return Polyline(
      points: points,
      strokeWidth: 7.0,
      color: Colors.blue.shade700,
      borderStrokeWidth: 2.5,
      borderColor: Colors.white,
      useStrokeWidthInMeter: false,
    );
  }

  // ✅ VERBLEIBENDE ROUTE (grau für zurückgelegte Strecke)
  static Polyline createCompletedRoute(List<LatLng> points) {
    return Polyline(
      points: points,
      strokeWidth: 4.0,
      color: Colors.grey.shade400,
      borderStrokeWidth: 1.0,
      borderColor: Colors.white,
    );
  }
}
