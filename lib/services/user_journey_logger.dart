// lib/services/user_journey_logger.dart - ENHANCED USER JOURNEY LOGGING - FIXED UNUSED VARIABLE
import 'package:flutter/foundation.dart';

/// Strukturiertes Logging-System für User Journey Tracking
///
/// Verfolgt komplette Benutzer-Flows von App-Start bis Navigation
/// mit detaillierten Performance-Metriken und Fehler-Detection
class UserJourneyLogger {
  static DateTime? _sessionStartTime;
  static int _stepCounter = 0;
  static final List<String> _journeySteps = [];

  // ✅ INIT & SESSION MANAGEMENT
  static void startSession() {
    _sessionStartTime = DateTime.now();
    _stepCounter = 0;
    _journeySteps.clear();
    _logWithIcon("🚀", "SESSION", "User Journey Session gestartet", {
      'timestamp': _sessionStartTime!.toIso8601String(),
      'platform': kIsWeb ? 'WEB' : 'MOBILE',
    });
  }

  static void endSession() {
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      _logWithIcon("🏁", "SESSION", "Session beendet", {
        'duration': '${duration.inSeconds}s',
        'total_steps': _stepCounter,
        'journey_flow': _journeySteps.join(' → '),
      });
    }
  }

  // ✅ APP LIFECYCLE
  static void appStarted(int totalPOIs, String locationName) {
    _logStep("APP-START", "App gestartet");
    _logWithIcon("🏃", "INIT", "App erfolgreich initialisiert", {
      'location': locationName,
      'total_pois': totalPOIs,
      'mock_gps': 'aktiviert',
    });
  }

  static void mapReady(String styleUrl, bool vectorTiles) {
    _logStep("MAP-READY", "Karte geladen");
    _logWithIcon("🗺️", "MAP", "Karte erfolgreich geladen", {
      'vector_tiles': vectorTiles ? 'JA' : 'NEIN',
      'style_source': vectorTiles ? 'MapTiler' : 'OpenStreetMap',
    });
  }

  static void searchInterfaceReady(int availableFeatures) {
    _logStep("SEARCH-READY", "Such-Interface bereit");
    _logWithIcon("🔍", "UI", "Such-System initialisiert", {
      'available_features': availableFeatures,
      'search_categories': 'Restaurant, Parkplatz, Familie, etc.',
    });
  }

  // ✅ RESTAURANT SEARCH FLOW
  static void searchStarted(String query, String fieldType) {
    _logStep("SEARCH-START", "Suche begonnen");
    final startTime = DateTime.now().millisecondsSinceEpoch;
    _logWithIcon("🔍", "SEARCH", "Benutzer startet Suche", {
      'query': query,
      'field_type': fieldType,
      'search_start_time': startTime,
    });
  }

  static void searchCompleted(
      String query, int resultsFound, int searchTimeMs) {
    _logStep("SEARCH-RESULTS", "$resultsFound Ergebnisse");
    _logWithIcon("📋", "SEARCH", "Suchergebnisse erhalten", {
      'query': query,
      'results_count': resultsFound,
      'search_time_ms': '${searchTimeMs}ms',
      'performance': searchTimeMs < 500
          ? 'FAST'
          : searchTimeMs < 1000
              ? 'OK'
              : 'SLOW',
    });
  }

  static void searchNoResults(String query) {
    _logStep("SEARCH-EMPTY", "Keine Ergebnisse");
    _logWithIcon("❌", "SEARCH", "Keine Suchergebnisse gefunden", {
      'query': query,
      'suggestion': 'Versuchen Sie: restaurant, parkplatz, oder Nummer',
    });
  }

  static void restaurantSelected(
      String restaurantName, String type, double lat, double lng) {
    _logStep("RESTAURANT-SELECTED", restaurantName);
    _logWithIcon("✅", "SELECTION", "Restaurant ausgewählt", {
      'name': restaurantName,
      'type': type,
      'coordinates':
          'lat: ${lat.toStringAsFixed(4)}, lng: ${lng.toStringAsFixed(4)}',
      'marker_created': 'JA',
    });
  }

  // ✅ ROUTE CALCULATION
  static void routeCalculationStarted(
      String startName, String destinationName) {
    _logStep("ROUTE-CALC-START", "Route wird berechnet");
    _logWithIcon("🔄", "ROUTING", "Route-Berechnung gestartet", {
      'start': startName,
      'destination': destinationName,
      'algorithm': 'A* Pathfinding',
    });
  }

  static void routeCalculated(
      double distanceMeters, int timeMinutes, int routePoints, int maneuvers) {
    _logStep(
        "ROUTE-SUCCESS", "${distanceMeters.round()}m in ${timeMinutes}min");
    _logWithIcon("🗺️", "ROUTING", "Route erfolgreich berechnet", {
      'distance': '${distanceMeters.round()}m',
      'time_estimate': '~${timeMinutes} min',
      'route_points': routePoints,
      'turn_instructions': maneuvers,
      'route_visible': 'Blaue Linie auf Karte',
    });
  }

  static void routeCalculationFailed(String reason) {
    _logStep("ROUTE-FAILED", "Route-Fehler");
    _logWithIcon("❌", "ROUTING", "Route-Berechnung fehlgeschlagen", {
      'reason': reason,
      'fallback': 'Prüfen Sie Start- und Zielpunkt',
    });
  }

  // ✅ NAVIGATION
  static void navigationStarted(bool followGPS, String ttsLanguage) {
    _logStep("NAVIGATION-START", "Navigation aktiv");
    _logWithIcon("🧭", "NAVIGATION", "Navigation gestartet", {
      'follow_gps': followGPS ? 'AKTIV' : 'INAKTIV',
      'tts_language': ttsLanguage,
      'voice_instructions': 'BEREIT',
      'map_tracking': followGPS ? 'FOLGT GPS' : 'MANUELL',
    });
  }

  static void gpsPositionUpdate(double lat, double lng, double accuracy) {
    // Nur jede 5. GPS-Update loggen (zu viel sonst)
    if (_stepCounter % 5 == 0) {
      _logWithIcon("📍", "GPS", "GPS Position aktualisiert", {
        'latitude': lat.toStringAsFixed(6),
        'longitude': lng.toStringAsFixed(6),
        'accuracy': '±${accuracy.round()}m',
        'type': 'MOCK GPS',
      });
    }
  }

  static void turnInstructionIssued(String instruction, double distanceToTurn) {
    _logStep("TURN-INSTRUCTION", instruction);
    _logWithIcon("➡️", "TTS", "Abbiegehinweis ausgegeben", {
      'instruction': instruction,
      'distance_to_turn': '${distanceToTurn.round()}m',
      'display': 'Turn Card sichtbar',
      'voice': 'TTS ausgelöst',
    });
  }

  // ✅ USER INTERACTIONS
  static void buttonPressed(String buttonName, String action) {
    _logWithIcon("👆", "UI", "Button gedrückt", {
      'button': buttonName,
      'action': action,
      'haptic_feedback': 'aktiv',
    });
  }

  static void swapStartDestination() {
    _logStep("SWAP", "Start/Ziel getauscht");
    _logWithIcon("🔄", "UI", "Start und Ziel vertauscht", {
      'action': 'Benutzer tauschte Start/Ziel',
      'route_recalculation': 'erforderlich',
    });
  }

  static void clearRoute() {
    _logStep("CLEAR-ROUTE", "Route gelöscht");
    _logWithIcon("🗑️", "UI", "Route zurückgesetzt", {
      'action': 'Benutzer löschte Route',
      'markers_removed': 'JA',
      'interface_reset': 'Such-Modus aktiv',
    });
  }

  // ✅ ERRORS & ISSUES
  static void error(String component, String errorMessage,
      [Map<String, dynamic>? context]) {
    _logStep("ERROR", "Fehler in $component");
    _logWithIcon("❌", "ERROR", "Fehler aufgetreten", {
      'component': component,
      'error': errorMessage,
      'context': context?.toString() ?? 'keine Details',
      'user_impact': 'Funktionalität eingeschränkt',
    });
  }

  static void warning(String component, String warningMessage) {
    _logWithIcon("⚠️", "WARNING", "Warnung", {
      'component': component,
      'warning': warningMessage,
      'user_impact': 'minimal',
    });
  }

  // ✅ PERFORMANCE TRACKING
  static void performanceMetric(
      String operation, int durationMs, String status) {
    String performanceRating;
    if (durationMs < 100) {
      performanceRating = 'EXCELLENT';
    } else if (durationMs < 500) {
      performanceRating = 'GOOD';
    } else if (durationMs < 1000) {
      performanceRating = 'OK';
    } else {
      performanceRating = 'SLOW';
    }

    _logWithIcon("⏱️", "PERFORMANCE", "$operation Performance", {
      'operation': operation,
      'duration_ms': '${durationMs}ms',
      'status': status,
      'rating': performanceRating,
    });
  }

  // ✅ INTERNAL HELPERS
  static void _logStep(String stepId, String description) {
    _stepCounter++;
    _journeySteps.add(stepId);
  }

  static void _logWithIcon(
      String icon, String category, String message, Map<String, dynamic> data) {
    if (!kDebugMode) return;

    // ✅ FIX: Verwende DateTime.now() direkt ohne separate Variable
    final stepNum = _stepCounter.toString().padLeft(2, '0');

    // ✅ STRUCTURED LOG OUTPUT
    print("$icon [$stepNum] [USER-JOURNEY] [$category] $message");

    // ✅ DETAILED DATA
    data.forEach((key, value) {
      print("    📊 $key: $value");
    });

    // ✅ SEPARATOR for readability
    if (category == "ERROR" ||
        category == "ROUTING" ||
        category == "NAVIGATION") {
      print("    " + "─" * 50);
    }
  }

  // ✅ CONVENIENCE METHODS
  static void logQuickAction(String emoji, String categoryName) {
    _logStep("QUICK-ACTION", categoryName);
    _logWithIcon("⚡", "UI", "Quick-Action verwendet", {
      'emoji': emoji,
      'category': categoryName,
      'search_triggered': 'automatisch',
    });
  }

  static void logContextSwitch(String oldContext, String newContext) {
    _logWithIcon("🎭", "CONTEXT", "Context gewechselt", {
      'from': oldContext,
      'to': newContext,
      'ui_adaptation': 'Interface angepasst',
    });
  }

  // ✅ SUMMARY REPORT
  static void generateJourneySummary() {
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      _logWithIcon("📊", "SUMMARY", "User Journey Zusammenfassung", {
        'session_duration':
            '${duration.inMinutes}m ${duration.inSeconds % 60}s',
        'total_steps': _stepCounter,
        'success_flow': _journeySteps.contains('ROUTE-SUCCESS') ? 'JA' : 'NEIN',
        'navigation_started':
            _journeySteps.contains('NAVIGATION-START') ? 'JA' : 'NEIN',
        'errors_occurred':
            _journeySteps.where((s) => s.contains('ERROR')).length,
        'key_milestones': _journeySteps
            .where((s) => [
                  'RESTAURANT-SELECTED',
                  'ROUTE-SUCCESS',
                  'NAVIGATION-START'
                ].contains(s))
            .join(', '),
      });
    }
  }
}
