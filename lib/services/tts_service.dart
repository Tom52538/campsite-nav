// lib/services/tts_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camping_osm_navi/models/maneuver.dart';

class TtsService {
  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  String? _currentLanguage;
  String _deviceLanguage = 'en'; // Fallback

  // TTS state for route updates
  String? _lastSpokenInstruction;
  DateTime? _lastInstructionTime;
  static const int minSecondsBetweenInstructions = 5;

  // Distance thresholds for announcements
  static const double advanceWarningDistance = 100.0;
  static const double immediateWarningDistance = 50.0;
  static const double executeDistance = 15.0;

  TtsService() {
    _flutterTts = FlutterTts();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    // Get device language
    await _detectDeviceLanguage();
    
    // Set TTS language based on device language
    await _setLanguage(_getPreferredTtsLanguage());

    _flutterTts.setStartHandler(() {
      if (kDebugMode) {
        debugPrint("[TtsService] TTS started");
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (kDebugMode) {
        debugPrint("[TtsService] TTS completed");
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (kDebugMode) {
        debugPrint("[TtsService] TTS Error: $msg");
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
        debugPrint("[TtsService] TTS successfully initialized with language '$_currentLanguage'");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[TtsService] Error during TTS initialization: $e");
      }
      _isInitialized = false;
    }
  }

  Future<void> _detectDeviceLanguage() async {
    try {
      // Get device locale
      final deviceLocale = PlatformDispatcher.instance.locale;
      _deviceLanguage = deviceLocale.languageCode;
      
      if (kDebugMode) {
        debugPrint("[TtsService] Device language detected: $_deviceLanguage (${deviceLocale.toString()})");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[TtsService] Could not detect device language, using English fallback: $e");
      }
      _deviceLanguage = 'en';
    }
  }

  String _getPreferredTtsLanguage() {
    switch (_deviceLanguage) {
      case 'de':
        return 'de-DE';
      case 'en':
        return 'en-US';
      case 'fr':
        return 'fr-FR';
      case 'es':
        return 'es-ES';
      case 'it':
        return 'it-IT';
      case 'nl':
        return 'nl-NL';
      default:
        return 'en-US'; // Fallback to English
    }
  }

  Future<void> _setLanguage(String languageCode) async {
    try {
      List<dynamic> languages = await _flutterTts.getLanguages;
      
      if (languages.map((lang) => lang.toString().toLowerCase())
          .contains(languageCode.toLowerCase())) {
        await _flutterTts.setLanguage(languageCode);
        _currentLanguage = languageCode;
        if (kDebugMode) {
          debugPrint("[TtsService] Language set to '$languageCode'");
        }
      } else {
        // Try base language (e.g., 'de' instead of 'de-DE')
        if (languageCode.contains('-')) {
          String baseLanguage = languageCode.split('-').first;
          if (languages.map((lang) => lang.toString().toLowerCase())
              .contains(baseLanguage.toLowerCase())) {
            await _flutterTts.setLanguage(baseLanguage);
            _currentLanguage = baseLanguage;
            if (kDebugMode) {
              debugPrint("[TtsService] Fallback language set to '$baseLanguage'");
            }
            return;
          }
        }
        
        // Final fallback to English
        await _flutterTts.setLanguage('en-US');
        _currentLanguage = 'en-US';
        if (kDebugMode) {
          debugPrint("[TtsService] Language '$languageCode' not available, using English fallback");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[TtsService] Error setting language: $e");
      }
    }
  }

  Future<void> speakNavigationInstruction(Maneuver maneuver, double distanceToManeuver) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        debugPrint("[TtsService] TTS not initialized. Attempting re-initialization.");
      }
      await _initializeTts();
      if (!_isInitialized) {
        if (kDebugMode) {
          debugPrint("[TtsService] TTS could not be initialized. Announcement cancelled.");
        }
        return;
      }
    }

    String instruction = _buildDistanceBasedInstruction(maneuver, distanceToManeuver);

    if (_shouldSpeakInstruction(instruction)) {
      await _speakWithLogging(instruction);
      _lastSpokenInstruction = instruction;
      _lastInstructionTime = DateTime.now();
    }
  }

  String _buildDistanceBasedInstruction(Maneuver maneuver, double distanceToManeuver) {
    // Special handling for start and destination
    if (maneuver.turnType == TurnType.depart) {
      return _getLocalizedText('route_started');
    }

    if (maneuver.turnType == TurnType.arrive) {
      return _getLocalizedText('destination_reached');
    }

    // Distance-based announcements for normal maneuvers
    String baseInstruction = _getLocalizedInstruction(maneuver.turnType);

    if (distanceToManeuver > advanceWarningDistance) {
      return "";
    } else if (distanceToManeuver > immediateWarningDistance) {
      int roundedDistance = (distanceToManeuver / 10).round() * 10;
      return _getLocalizedText('in_distance', {'distance': roundedDistance.toString(), 'instruction': baseInstruction});
    } else if (distanceToManeuver > executeDistance) {
      return _getLocalizedText('in_50_meters', {'instruction': baseInstruction});
    } else {
      return _getLocalizedText('now_action', {'instruction': baseInstruction});
    }
  }

  String _getLocalizedInstruction(TurnType turnType) {
    final key = 'turn_${turnType.name}';
    return _getLocalizedText(key);
  }

  String _getLocalizedText(String key, [Map<String, String>? variables]) {
    final translations = _getTranslations();
    
    // Safe string extraction with explicit null checks
    String text;
    
    // Try current language first
    final currentLangTranslations = translations[_deviceLanguage];
    if (currentLangTranslations != null && currentLangTranslations.containsKey(key)) {
      text = currentLangTranslations[key]!;
    } 
    // Fallback to English
    else if (translations['en'] != null && translations['en']!.containsKey(key)) {
      text = translations['en']![key]!;
    }
    // Last fallback: Key itself
    else {
      text = key;
    }
    
    // Replace variables in text
    if (variables != null) {
      variables.forEach((variable, value) {
        text = text.replaceAll('{$variable}', value);
      });
    }
    
    return text;
  }

  Map<String, Map<String, String>> _getTranslations() {
    return {
      'de': {
        'route_started': 'Route gestartet',
        'destination_reached': 'Sie haben Ihr Ziel erreicht',
        'in_distance': 'In {distance} Metern {instruction}',
        'in_50_meters': 'In 50 Metern {instruction}',
        'now_action': 'Jetzt {instruction}',
        'turn_slightLeft': 'leicht links halten',
        'turn_slightRight': 'leicht rechts halten',
        'turn_turnLeft': 'links abbiegen',
        'turn_turnRight': 'rechts abbiegen',
        'turn_sharpLeft': 'scharf links abbiegen',
        'turn_sharpRight': 'scharf rechts abbiegen',
        'turn_uTurnLeft': 'wenden',
        'turn_uTurnRight': 'wenden',
        'turn_straight': 'geradeaus weiterfahren',
        'turn_depart': 'Route starten',
        'turn_arrive': 'Ziel erreicht',
        'test_message': 'Dies ist eine Testansage auf Deutsch.',
      },
      'en': {
        'route_started': 'Route started',
        'destination_reached': 'You have reached your destination',
        'in_distance': 'In {distance} meters {instruction}',
        'in_50_meters': 'In 50 meters {instruction}',
        'now_action': 'Now {instruction}',
        'turn_slightLeft': 'keep slightly left',
        'turn_slightRight': 'keep slightly right',
        'turn_turnLeft': 'turn left',
        'turn_turnRight': 'turn right',
        'turn_sharpLeft': 'turn sharp left',
        'turn_sharpRight': 'turn sharp right',
        'turn_uTurnLeft': 'make a U-turn',
        'turn_uTurnRight': 'make a U-turn',
        'turn_straight': 'continue straight',
        'turn_depart': 'start route',
        'turn_arrive': 'destination reached',
        'test_message': 'This is a test announcement in English.',
      },
      'fr': {
        'route_started': 'Itinéraire commencé',
        'destination_reached': 'Vous avez atteint votre destination',
        'in_distance': 'Dans {distance} mètres {instruction}',
        'in_50_meters': 'Dans 50 mètres {instruction}',
        'now_action': 'Maintenant {instruction}',
        'turn_slightLeft': 'gardez légèrement à gauche',
        'turn_slightRight': 'gardez légèrement à droite',
        'turn_turnLeft': 'tournez à gauche',
        'turn_turnRight': 'tournez à droite',
        'turn_sharpLeft': 'tournez fortement à gauche',
        'turn_sharpRight': 'tournez fortement à droite',
        'turn_uTurnLeft': 'faites demi-tour',
        'turn_uTurnRight': 'faites demi-tour',
        'turn_straight': 'continuez tout droit',
        'turn_depart': 'commencer l\'itinéraire',
        'turn_arrive': 'destination atteinte',
        'test_message': 'Ceci est un message de test en français.',
      },
      'es': {
        'route_started': 'Ruta iniciada',
        'destination_reached': 'Has llegado a tu destino',
        'in_distance': 'En {distance} metros {instruction}',
        'in_50_meters': 'En 50 metros {instruction}',
        'now_action': 'Ahora {instruction}',
        'turn_slightLeft': 'mantente ligeramente a la izquierda',
        'turn_slightRight': 'mantente ligeramente a la derecha',
        'turn_turnLeft': 'gira a la izquierda',
        'turn_turnRight': 'gira a la derecha',
        'turn_sharpLeft': 'gira fuertemente a la izquierda',
        'turn_sharpRight': 'gira fuertemente a la derecha',
        'turn_uTurnLeft': 'da la vuelta',
        'turn_uTurnRight': 'da la vuelta',
        'turn_straight': 'continúa recto',
        'turn_depart': 'iniciar ruta',
        'turn_arrive': 'destino alcanzado',
        'test_message': 'Este es un mensaje de prueba en español.',
      },
      'nl': {
        'route_started': 'Route gestart',
        'destination_reached': 'U heeft uw bestemming bereikt',
        'in_distance': 'Over {distance} meter {instruction}',
        'in_50_meters': 'Over 50 meter {instruction}',
        'now_action': 'Nu {instruction}',
        'turn_slightLeft': 'houd licht links aan',
        'turn_slightRight': 'houd licht rechts aan',
        'turn_turnLeft': 'ga linksaf',
        'turn_turnRight': 'ga rechtsaf',
        'turn_sharpLeft': 'ga scherp linksaf',
        'turn_sharpRight': 'ga scherp rechtsaf',
        'turn_uTurnLeft': 'keer om',
        'turn_uTurnRight': 'keer om',
        'turn_straight': 'ga rechtdoor',
        'turn_depart': 'route starten',
        'turn_arrive': 'bestemming bereikt',
        'test_message': 'Dit is een testbericht in het Nederlands.',
      },
      'it': {
        'route_started': 'Percorso iniziato',
        'destination_reached': 'Hai raggiunto la tua destinazione',
        'in_distance': 'Tra {distance} metri {instruction}',
        'in_50_meters': 'Tra 50 metri {instruction}',
        'now_action': 'Ora {instruction}',
        'turn_slightLeft': 'mantieni leggermente a sinistra',
        'turn_slightRight': 'mantieni leggermente a destra',
        'turn_turnLeft': 'gira a sinistra',
        'turn_turnRight': 'gira a destra',
        'turn_sharpLeft': 'gira bruscamente a sinistra',
        'turn_sharpRight': 'gira bruscamente a destra',
        'turn_uTurnLeft': 'fai inversione',
        'turn_uTurnRight': 'fai inversione',
        'turn_straight': 'continua dritto',
        'turn_depart': 'inizia percorso',
        'turn_arrive': 'destinazione raggiunta',
        'test_message': 'Questo è un messaggio di prova in italiano.',
      },
    };
  }

  bool _shouldSpeakInstruction(String instruction) {
    if (instruction.isEmpty) return false;
    if (_lastSpokenInstruction == null) return true;
    if (_lastSpokenInstruction == instruction) return false;

    if (_lastInstructionTime != null) {
      final timeSinceLastInstruction = DateTime.now().difference(_lastInstructionTime!);
      if (timeSinceLastInstruction.inSeconds < minSecondsBetweenInstructions) {
        return false;
      }
    }

    return true;
  }

  Future<void> _speakWithLogging(String instruction) async {
    if (kDebugMode) {
      debugPrint("[TtsService] Speaking: '$instruction'");
    }

    if (_currentLanguage != null) {
      await _flutterTts.setLanguage(_currentLanguage!);
    }

    var result = await _flutterTts.speak(instruction);
    if (result != 1 && kDebugMode) {
      debugPrint("[TtsService] Error starting announcement for: $instruction");
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await _initializeTts();
      if (!_isInitialized) {
        if (kDebugMode) {
          debugPrint("[TtsService] TTS could not be initialized. Announcement cancelled: $text");
        }
        return;
      }
    }

    if (text.isNotEmpty) {
      await _speakWithLogging(text);
    }
  }

  Future<void> speakImmediate(String text) async {
    _lastSpokenInstruction = null;
    await speak(text);
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    var result = await _flutterTts.stop();
    if (result == 1 && kDebugMode) {
      debugPrint("[TtsService] TTS stopped");
    }
  }

  Future<void> testSpeak() async {
    final testMessage = _getLocalizedText('test_message');
    await speak(testMessage);
  }

  void resetForNewRoute() {
    _lastSpokenInstruction = null;
    _lastInstructionTime = null;
    if (kDebugMode) {
      debugPrint("[TtsService] TTS reset for new route");
    }
  }
}