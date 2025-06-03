// lib/models/search_types.dart - ZENTRALE TYPE DEFINITIONEN
import 'package:flutter/material.dart'; // ✅ FIX: Flutter Import für Curves

/// Zentrale Type-Definitionen für das Premium Search System
/// Smartphone-optimiert für Resort-Navigation

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
        return 10; // Höchste Priorität
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
        return '#4F46E5'; // Indigo
      case SearchResultType.accommodation:
        return '#8B5CF6'; // Violet
      case SearchResultType.dining:
        return '#F59E0B'; // Amber
      case SearchResultType.family:
        return '#EC4899'; // Pink
      case SearchResultType.beach:
        return '#06B6D4'; // Cyan
      case SearchResultType.amenity:
        return '#10B981'; // Emerald
      case SearchResultType.emergency:
        return '#EF4444'; // Red
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
        return 0.65; // 65% Karte sichtbar
      case SearchInterfaceState.collapsed:
        return 0.85; // 85% Karte sichtbar
      case SearchInterfaceState.hidden:
        return 0.95; // 95% Karte sichtbar
      case SearchInterfaceState.navigationMode:
        return 0.90; // 90% Karte sichtbar (Turn-by-Turn overlay)
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
}