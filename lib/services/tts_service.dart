// lib/services/tts_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camping_osm_navi/models/maneuver.dart';

class TtsService {
  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  String? _currentLanguage;

  // ✅ NEU: Erweiterte Sprachanweisungen
  String? _lastSpokenInstruction;
  DateTime? _lastInstructionTime;
  static const int minSecondsBetweenInstructions = 5;

  // Distanz-Schwellenwerte für Ansagen
  static const double advanceWarningDistance = 100.0; // 100m Vorwarnung
  static const double immediateWarningDistance = 50.0; // 50m Warnung
  static const double executeDistance = 15.0; // Ausführen

  TtsService() {
    _flutterTts = FlutterTts();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    _currentLanguage = "de-DE";
    await _setLanguage(_currentLanguage!);

    _flutterTts.setStartHandler(() {
      if (kDebugMode) {
        print("[TtsService] TTS gestartet");
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (kDebugMode) {
        print("[TtsService] TTS abgeschlossen");
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (kDebugMode) {
        print("[TtsService] TTS Fehler: $msg");
      }
      _isInitialized = false;
    });

    try {
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await _flutterTts.awaitSpeakCompletion(true);
      _isInitialized = true;
      if (kDebugMode) {
        print(
            "[TtsService] TTS erfolgreich initialisiert und Sprache auf '$_currentLanguage' gesetzt.");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "[TtsService] Fehler bei der TTS-Initialisierung oder Spracheinstellung: $e");
      }
      _isInitialized = false;
    }
  }

  Future<void> _setLanguage(String languageCode) async {
    try {
      List<dynamic> languages = await _flutterTts.getLanguages;
      if (languages
          .map((lang) => lang.toString().toLowerCase())
          .contains(languageCode.toLowerCase())) {
        await _flutterTts.setLanguage(languageCode);
        _currentLanguage = languageCode;
        if (kDebugMode) {
          print("[TtsService] Sprache auf '$languageCode' gesetzt.");
        }
      } else {
        if (kDebugMode) {
          print(
              "[TtsService] Sprache '$languageCode' nicht verfügbar. Fallback auf Standard-Sprache der Engine.");
        }
        if (languageCode.contains('-')) {
          String baseLanguage = languageCode.split('-').first;
          if (languages
              .map((lang) => lang.toString().toLowerCase())
              .contains(baseLanguage.toLowerCase())) {
            await _flutterTts.setLanguage(baseLanguage);
            _currentLanguage = baseLanguage;
            if (kDebugMode) {
              print(
                  "[TtsService] Fallback-Sprache auf '$baseLanguage' gesetzt.");
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("[TtsService] Fehler beim Setzen der Sprache: $e");
      }
    }
  }

  // ✅ NEU: Erweiterte Sprachanweisungen mit Distanzangaben
  Future<void> speakNavigationInstruction(
      Maneuver maneuver, double distanceToManeuver) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print(
            "[TtsService] TTS nicht initialisiert. Versuche erneute Initialisierung.");
      }
      await _initializeTts();
      if (!_isInitialized) {
        if (kDebugMode) {
          print(
              "[TtsService] TTS konnte nicht initialisiert werden. Ansage abgebrochen.");
        }
        return;
      }
    }

    String instruction =
        _buildDistanceBasedInstruction(maneuver, distanceToManeuver);

    // Verhindere zu häufige Wiederholungen
    if (_shouldSpeakInstruction(instruction)) {
      await _speakWithLogging(instruction);
      _lastSpokenInstruction = instruction;
      _lastInstructionTime = DateTime.now();
    }
  }

  String _buildDistanceBasedInstruction(
      Maneuver maneuver, double distanceToManeuver) {
    // Spezialbehandlung für Start und Ziel
    if (maneuver.turnType == TurnType.depart) {
      return "Route gestartet";
    }

    if (maneuver.turnType == TurnType.arrive) {
      return "Sie haben Ihr Ziel erreicht";
    }

    // Distanzbasierte Ansagen für normale Manöver
    String baseInstruction = _getGermanInstruction(maneuver.turnType);

    if (distanceToManeuver > advanceWarningDistance) {
      // Noch weit weg - keine Ansage
      return "";
    } else if (distanceToManeuver > immediateWarningDistance) {
      // 100m Vorwarnung
      int roundedDistance =
          (distanceToManeuver / 10).round() * 10; // Auf 10m runden
      return "In $roundedDistance Metern $baseInstruction";
    } else if (distanceToManeuver > executeDistance) {
      // 50m Warnung
      return "In 50 Metern $baseInstruction";
    } else {
      // Jetzt ausführen
      return "Jetzt $baseInstruction";
    }
  }

  String _getGermanInstruction(TurnType turnType) {
    switch (turnType) {
      case TurnType.slightLeft:
        return "leicht links halten";
      case TurnType.slightRight:
        return "leicht rechts halten";
      case TurnType.turnLeft:
        return "links abbiegen";
      case TurnType.turnRight:
        return "rechts abbiegen";
      case TurnType.sharpLeft:
        return "scharf links abbiegen";
      case TurnType.sharpRight:
        return "scharf rechts abbiegen";
      case TurnType.uTurnLeft:
        return "wenden";
      case TurnType.uTurnRight:
        return "wenden";
      case TurnType.straight:
        return "geradeaus weiterfahren";
      case TurnType.depart:
        return "Route starten";
      case TurnType.arrive:
        return "Ziel erreicht";
    }
  }

  bool _shouldSpeakInstruction(String instruction) {
    if (instruction.isEmpty) return false;

    // Erste Ansage immer erlauben
    if (_lastSpokenInstruction == null) return true;

    // Gleiche Ansage nicht wiederholen
    if (_lastSpokenInstruction == instruction) return false;

    // Mindestabstand zwischen Ansagen
    if (_lastInstructionTime != null) {
      final timeSinceLastInstruction =
          DateTime.now().difference(_lastInstructionTime!);
      if (timeSinceLastInstruction.inSeconds < minSecondsBetweenInstructions) {
        return false;
      }
    }

    return true;
  }

  Future<void> _speakWithLogging(String instruction) async {
    if (kDebugMode) {
      print("[TtsService] Spreche: '$instruction'");
    }

    if (_currentLanguage != null) {
      await _flutterTts.setLanguage(_currentLanguage!);
    }

    var result = await _flutterTts.speak(instruction);
    if (result != 1 && kDebugMode) {
      print("[TtsService] Fehler beim Starten der Ansage für: $instruction");
    }
  }

  // ✅ Behält alte Methode für Kompatibilität
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print(
            "[TtsService] TTS nicht initialisiert. Versuche erneute Initialisierung.");
      }
      await _initializeTts();
      if (!_isInitialized) {
        if (kDebugMode) {
          print(
              "[TtsService] TTS konnte nicht initialisiert werden. Ansage abgebrochen: $text");
        }
        return;
      }
    }

    if (text.isNotEmpty) {
      await _speakWithLogging(text);
    } else {
      if (kDebugMode) {
        print("[TtsService] Leerer Text für Ansage empfangen.");
      }
    }
  }

  // ✅ NEU: Sofortige wichtige Ansagen (für Rerouting etc.)
  Future<void> speakImmediate(String text) async {
    _lastSpokenInstruction = null; // Reset, damit wichtige Ansagen durchkommen
    await speak(text);
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    var result = await _flutterTts.stop();
    if (result == 1) {
      if (kDebugMode) {
        print("[TtsService] TTS gestoppt");
      }
    }
  }

  Future<void> testSpeak() async {
    await speak("Dies ist eine Testansage auf Deutsch.");
  }

  // ✅ NEU: Reset für neue Route
  void resetForNewRoute() {
    _lastSpokenInstruction = null;
    _lastInstructionTime = null;
    if (kDebugMode) {
      print("[TtsService] TTS für neue Route zurückgesetzt");
    }
  }
}
