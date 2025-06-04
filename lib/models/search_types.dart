// lib/models/search_types.dart - ENHANCED WITH RESPONSIVE UTILITIES
import 'package:flutter/material.dart';

/// Zentrale Type-Definitionen für das Premium Search System
/// Smartphone-optimiert für Resort-Navigation mit OVERFLOW-SCHUTZ

/// Such-Feld Typen für Start/Ziel Unterscheidung
enum SearchFieldType {
  start('start'),
  destination('destination');

  const SearchFieldType(this.value);
  final String value;

  /// User-friendly Labels für UI
  String get displayName {
    switch (this) {
      case SearchFieldType.start:
        return 'Startpunkt';
      case SearchFieldType.destination:
        return 'Ziel';
    }
  }

  /// Icons für Smartphone UI
  String get emoji {
    switch (this) {
      case SearchFieldType.start:
        return '🎯';
      case SearchFieldType.destination:
        return '🏁';
    }
  }
}

/// Ergebnis-Typen für intelligente Priorisierung
enum SearchResultType {
  accommodation('accommodation'),
  parking('parking'),
  dining('dining'),
  family('family'),
  beach('beach'),
  amenity('amenity'),
  emergency('emergency');

  const SearchResultType(this.value);
  final String value;

  /// Priorität für Resort-Gäste (höher = wichtiger)
  int get priority {
    switch (this) {
      case SearchResultType.parking:
        return 10;
      case SearchResultType.accommodation:
        return 9;
      case SearchResultType.family:
        return 8;
      case SearchResultType.dining:
        return 7;
      case SearchResultType.beach:
        return 6;
      case SearchResultType.amenity:
        return 5;
      case SearchResultType.emergency:
        return 4;
    }
  }

  /// Farben für visuelle Unterscheidung
  String get colorHex {
    switch (this) {
      case SearchResultType.parking:
        return '#4F46E5';
      case SearchResultType.accommodation:
        return '#8B5CF6';
      case SearchResultType.dining:
        return '#F59E0B';
      case SearchResultType.family:
        return '#EC4899';
      case SearchResultType.beach:
        return '#06B6D4';
      case SearchResultType.amenity:
        return '#10B981';
      case SearchResultType.emergency:
        return '#EF4444';
    }
  }
}

/// Interface States für Smartphone UX
enum SearchInterfaceState {
  /// Komplette Eingabe-Interface sichtbar
  expanded('expanded'),

  /// Minimierte Ansicht mit Quick-Actions
  collapsed('collapsed'),

  /// Vollständig ausgeblendet für maximale Karten-Sicht
  hidden('hidden'),

  /// Route-Info Overlay (Navigation aktiv)
  navigationMode('navigation');

  const SearchInterfaceState(this.value);
  final String value;

  /// Bestimmt Karten-Sichtbarkeit (0.0 - 1.0)
  double get mapVisibility {
    switch (this) {
      case SearchInterfaceState.expanded:
        return 0.65;
      case SearchInterfaceState.collapsed:
        return 0.85;
      case SearchInterfaceState.hidden:
        return 0.95;
      case SearchInterfaceState.navigationMode:
        return 0.90;
    }
  }

  /// Animation Dauer für State-Transitions
  Duration get transitionDuration {
    switch (this) {
      case SearchInterfaceState.expanded:
        return const Duration(milliseconds: 300);
      case SearchInterfaceState.collapsed:
        return const Duration(milliseconds: 250);
      case SearchInterfaceState.hidden:
        return const Duration(milliseconds: 400);
      case SearchInterfaceState.navigationMode:
        return const Duration(milliseconds: 500);
    }
  }
}

/// Search Context für intelligente Ergebnisse
enum SearchContext {
  /// Normaler Resort-Gast
  guest('guest'),

  /// Ankommender Gast (Check-in Fokus)
  arrival('arrival'),

  /// Abreisender Gast (Check-out Fokus)
  departure('departure'),

  /// Notfall-Situation
  emergency('emergency');

  const SearchContext(this.value);
  final String value;

  /// Such-Priorisierung basierend auf Kontext
  List<SearchResultType> get prioritizedTypes {
    switch (this) {
      case SearchContext.guest:
        return [
          SearchResultType.parking,
          SearchResultType.dining,
          SearchResultType.family,
          SearchResultType.beach,
          SearchResultType.amenity,
        ];
      case SearchContext.arrival:
        return [
          SearchResultType.accommodation,
          SearchResultType.parking,
          SearchResultType.amenity,
          SearchResultType.dining,
        ];
      case SearchContext.departure:
        return [
          SearchResultType.parking,
          SearchResultType.accommodation,
          SearchResultType.amenity,
        ];
      case SearchContext.emergency:
        return [
          SearchResultType.emergency,
          SearchResultType.amenity,
          SearchResultType.parking,
        ];
    }
  }
}

/// Smartphone Touch Targets (Design System)
class SmartphoneTouchTargets {
  /// Minimum Touch Target (iOS/Android Standards)
  static const double minimumSize = 44.0;

  /// Comfortable Touch Target
  static const double comfortableSize = 48.0;

  /// Large Touch Target (Accessibility)
  static const double largeSize = 56.0;

  /// Thumb-reachable Zone (Portrait Smartphone)
  static const double thumbReachableHeight = 120.0;

  // ✅ NEU: Overflow-sichere Größen
  /// Ultra Compact für kleine Bildschirme
  static const double ultraCompactSize = 36.0;

  /// Safe Minimum für Touch ohne Overflow
  static const double safeMinimumSize = 40.0;
}

/// Smartphone Screen Breakpoints
class SmartphoneBreakpoints {
  /// Kleine Smartphones (iPhone SE, etc.)
  static const double small = 375.0;

  /// Standard Smartphones
  static const double medium = 414.0;

  /// Große Smartphones (iPhone Pro Max, etc.)
  static const double large = 428.0;

  /// Tablet (Landscape minimal)
  static const double tablet = 768.0;

  // ✅ NEU: Responsive Helpers
  /// Prüft ob kleiner Bildschirm
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < small;
  }

  /// Prüft ob Medium Bildschirm
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= small && width < large;
  }

  /// Prüft ob großer Bildschirm
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= large;
  }

  /// Gibt responsive Padding zurück
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isSmallScreen(context)) {
      return const EdgeInsets.all(8.0);
    } else if (isMediumScreen(context)) {
      return const EdgeInsets.all(12.0);
    } else {
      return const EdgeInsets.all(16.0);
    }
  }

  /// Gibt responsive Schriftgröße zurück
  static double getResponsiveFontSize(BuildContext context,
      {required double baseSize}) {
    if (isSmallScreen(context)) {
      return baseSize - 2;
    } else if (isLargeScreen(context)) {
      return baseSize + 2;
    }
    return baseSize;
  }
}

/// Animation Curves für Premium Feel
class PremiumCurves {
  /// iOS-like Smooth Curve
  static const Curve smooth = Curves.easeInOutCubic;

  /// Android Material Curve
  static const Curve material = Curves.fastOutSlowIn;

  /// Bounce Effect für Feedback
  static const Curve bounce = Curves.elasticOut;

  /// Quick Snap für Dismissals
  static const Curve snap = Curves.easeOutExpo;

  // ✅ NEU: Overflow-sichere Animationen
  /// Sanfte Größenänderung ohne Overflow
  static const Curve resize = Curves.easeInOutQuart;

  /// Schnelle Anpassung für Keyboard
  static const Curve keyboard = Curves.easeOutCubic;
}

// ✅ NEU: Responsive Layout Helper
class ResponsiveLayoutHelper {
  /// Berechnet sichere Höhe für Container
  static double calculateSafeHeight(
    BuildContext context, {
    required bool isRouteMode,
    required bool isKeyboardVisible,
    double? keyboardHeight,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final effectiveKeyboardHeight =
        keyboardHeight ?? MediaQuery.of(context).viewInsets.bottom;

    if (isRouteMode) {
      // Route Mode: Minimal
      return SmartphoneBreakpoints.isSmallScreen(context) ? 100 : 120;
    }

    if (isKeyboardVisible) {
      // Keyboard sichtbar: Kompakter
      final availableHeight = screenHeight - effectiveKeyboardHeight - 100;
      return (availableHeight * 0.6).clamp(120, 200);
    }

    // Normal Mode: Responsive
    if (SmartphoneBreakpoints.isSmallScreen(context)) {
      return (screenHeight * 0.25).clamp(140, 180);
    } else {
      return (screenHeight * 0.3).clamp(160, 220);
    }
  }

  /// Gibt responsive Elementgröße zurück
  static double getResponsiveElementSize(
    BuildContext context, {
    required double smallSize,
    required double mediumSize,
    required double largeSize,
  }) {
    if (SmartphoneBreakpoints.isSmallScreen(context)) {
      return smallSize;
    } else if (SmartphoneBreakpoints.isMediumScreen(context)) {
      return mediumSize;
    } else {
      return largeSize;
    }
  }

  /// Prüft ob Layout kompakt sein sollte
  static bool shouldUseCompactLayout(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 50;

    return SmartphoneBreakpoints.isSmallScreen(context) ||
        isKeyboardVisible ||
        screenHeight < 600;
  }
}
