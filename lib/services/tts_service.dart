// lib/services/tts_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  String? _currentLanguage; // Um die Sprache zu speichern

  TtsService() {
    _flutterTts = FlutterTts();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    // Sprachkonfiguration (Beispiel: Deutsch)
    // Die Verfügbarkeit hängt von den auf dem Gerät installierten Sprachen ab.
    // Es ist ratsam, die verfügbaren Sprachen zu prüfen und dem Benutzer ggf. eine Auswahl zu ermöglichen.
    _currentLanguage = "de-DE"; // Standardmäßig auf Deutsch setzen
    await _setLanguage(_currentLanguage!);

    // Optional: Weitere Konfigurationen (Sprechrate, Lautstärke, Tonhöhe)
    // await _flutterTts.setSpeechRate(0.5); // 0.0 (langsam) bis 1.0 (normal)
    // await _flutterTts.setVolume(1.0);    // 0.0 (stumm) bis 1.0 (max)
    // await _flutterTts.setPitch(1.0);     // 0.5 (tief) bis 2.0 (hoch)

    // Handler für den Initialisierungsstatus (optional, aber gut für Debugging)
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
      _isInitialized = false; // Bei Fehler als nicht initialisiert markieren
    });

    // Versuche, die Engine zu initialisieren (wichtig für einige Plattformen)
    // und die Sprache zu setzen
    try {
      // Warte, bis die Engine bereit ist. Dies ist besonders für Web wichtig.
      // Ein kleiner Delay kann helfen, sicherzustellen, dass die Engine bereit ist.
      // Für Mobilgeräte ist es oft nicht nötig, aber schadet auch nicht.
      if (kIsWeb) {
         await Future.delayed(const Duration(milliseconds: 500));
      }
      await _flutterTts.awaitSpeakCompletion(true); // Wichtig für sequentielle Ansagen
      _isInitialized = true;
      if (kDebugMode) {
        print("[TtsService] TTS erfolgreich initialisiert und Sprache auf '$_currentLanguage' gesetzt.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("[TtsService] Fehler bei der TTS-Initialisierung oder Spracheinstellung: $e");
      }
      _isInitialized = false;
    }
  }

  Future<void> _setLanguage(String languageCode) async {
    try {
      List<dynamic> languages = await _flutterTts.getLanguages;
      if (kDebugMode) {
        // print("[TtsService] Verfügbare Sprachen: $languages");
      }
      if (languages.map((lang) => lang.toString().toLowerCase()).contains(languageCode.toLowerCase())) {
        await _flutterTts.setLanguage(languageCode);
        _currentLanguage = languageCode; // Sprache merken
        if (kDebugMode) {
          print("[TtsService] Sprache auf '$languageCode' gesetzt.");
        }
      } else {
        if (kDebugMode) {
          print("[TtsService] Sprache '$languageCode' nicht verfügbar. Fallback auf Standard-Sprache der Engine.");
        }
        // Optional: Versuche eine generischere Variante wie "de"
        if (languageCode.contains('-')) {
            String baseLanguage = languageCode.split('-').first;
            if (languages.map((lang) => lang.toString().toLowerCase()).contains(baseLanguage.toLowerCase())) {
                 await _flutterTts.setLanguage(baseLanguage);
                _currentLanguage = baseLanguage;
                 if (kDebugMode) {
                    print("[TtsService] Fallback-Sprache auf '$baseLanguage' gesetzt.");
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


  Future<void> speak(String text) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print("[TtsService] TTS nicht initialisiert. Versuche erneute Initialisierung.");
      }
      await _initializeTts(); // Erneuten Initialisierungsversuch starten
      if (!_isInitialized) { // Immer noch nicht initialisiert?
          if (kDebugMode) {
            print("[TtsService] TTS konnte nicht initialisiert werden. Ansage abgebrochen: $text");
          }
          return;
      }
    }

    if (text.isNotEmpty) {
      // Überprüfe und setze die gewünschte Sprache vor jeder Ansage,
      // falls sie sich geändert haben könnte oder die Initialisierung fehlschlug.
      if (_currentLanguage != null && (await _flutterTts.getLanguages).contains(_currentLanguage) ) {
          // Manchmal muss die Sprache erneut gesetzt werden, besonders auf iOS nach einiger Inaktivität
          await _flutterTts.setLanguage(_currentLanguage!);
      } else if (_currentLanguage != null) {
          // Versuche, die Sprache erneut zu setzen, falls sie nicht mehr als aktiv erkannt wird
          await _setLanguage(_currentLanguage!);
      }


      var result = await _flutterTts.speak(text);
      if (result == 1) {
        if (kDebugMode) {
          // print("[TtsService] Ansage erfolgreich gestartet: $text");
        }
      } else {
        if (kDebugMode) {
          print("[TtsService] Fehler beim Starten der Ansage für: $text");
        }
      }
    } else {
      if (kDebugMode) {
        print("[TtsService] Leerer Text für Ansage empfangen.");
      }
    }
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

  // Testfunktion, die du z.B. über einen Button aufrufen könntest
  Future<void> testSpeak() async {
    await speak("Dies ist eine Testansage auf Deutsch.");
  }
}