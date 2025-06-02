Camping OSM Navigation App
Eine Flutter-basierte Navigationsapp speziell für Campingplätze, die präzise Indoor-Navigation mit OpenStreetMap-Daten und Vector-Tiles ermöglicht.
🏕️ Überblick
Diese App bietet detaillierte Navigation auf Campingplätzen mit Routing zwischen Stellplätzen, Sanitäranlagen, Restaurants und anderen Einrichtungen. Die Navigation funktioniert sowohl mit echtem GPS als auch mit Mock-Standorten für Tests.
✨ Hauptfunktionen
🗺️ Erweiterte Kartendarstellung

Vector-Tiles von MapTiler für detaillierte, skalierbare Karten
Fallback auf OpenStreetMap-Raster-Tiles bei Verbindungsproblemen
Adaptive Zoom-Level mit optimierter Performance
Style-Caching für bessere Ladezeiten

🧭 Intelligente Navigation

A-basiertes Routing* auf campingplatz-spezifischen Wegen
Echtzeit-Sprachnavigation mit deutschen Anweisungen
Turn-by-Turn Wegbeschreibungen mit visuellen Karten
Automatische Routenneuberechnung bei Abweichungen
GPS-Tracking mit Follow-Modus

🔍 Erweiterte Suchfunktion

Intelligente Kategorie-Erkennung (Sanitär, Gastronomie, Unterkünfte)
Nummern-basierte Suche für Stellplätze (z.B. "247", "Nr. 15a")
Emoji-Shortcuts (🚿 → WC, 🍽️ → Restaurant)
Mehrsprachige Keywords (Deutsch/Englisch)
Typ-basierte Filterung nach OSM-Kategorien

🎯 Benutzerfreundliche Oberfläche

Kompakte Routenanzeige während der Navigation
Lock-System für Start- und Zielpunkte
Kartenauswahl-Modus für präzise Punktauswahl
Responsive Design für verschiedene Bildschirmgrößen
Keyboard-optimierte Eingabefelder

🔊 Sprachausgabe (TTS)

Distanzbasierte Ansagen (100m, 50m, sofort)
Deutsche Sprachanweisungen mit natürlicher Aussprache
Intelligente Wiederholungsfilterung
Routenstatus-Updates (verbleibende Zeit/Distanz)

🏗️ Technische Architektur
Kern-Komponenten
lib/
├── models/          # Datenmodelle (SearchableFeature, RoutingGraph, Maneuver)
├── services/        # Business Logic (Routing, TTS, GeoJSON-Parser)
├── providers/       # State Management (LocationProvider)
├── screens/         # UI-Screens (MapScreen + Submodule)
├── widgets/         # Wiederverwendbare UI-Komponenten
└── debug/           # Debug-Tools (optional)
State Management

Provider Pattern für LocationProvider
ChangeNotifier für MapScreenController
Mixin-basierte UI-Komponenten für Modularität

Datenverarbeitung

GeoJSON-Parser für Campingplatz-Geometrien
Graph-basiertes Routing mit gewichteten Kanten
Feature-Extraktion für Suchfunktionen
Style-Caching für Vector-Tiles

📍 Unterstützte Standorte

Testgelände Sittard (NL)
Camping Resort Kamperland (NL)
Umgebung Gangelt (DE)

Jeder Standort hat individuelle:

GeoJSON-Geometrien für präzises Routing
MapTiler-Styles für optimale Darstellung
Feature-Kategorisierung für intelligente Suche

🚀 Installation & Setup
Voraussetzungen

Flutter SDK ≥ 3.4.0
MapTiler API Key (kostenlos unter maptiler.com)

Installation
bash# Repository klonen
git clone <repository-url>
cd camping_osm_navi

# Dependencies installieren
flutter pub get

# Environment-Datei erstellen
cp .env.example .env
# MapTiler API Key in .env eintragen:
# MAPTILER_API_KEY=your_api_key_here

# App starten
flutter run
Entwicklungstools
bash# Code-Generierung (falls Mockito verwendet)
flutter packages pub run build_runner build

# Lints ausführen
flutter analyze

# Tests ausführen
flutter test
📱 Nutzung
Grundlegende Navigation

Standort auswählen über Dropdown in der AppBar
Startpunkt setzen (aktueller Standort oder Suche)
Ziel suchen über intelligente Suchfunktion
Route berechnen durch Sperren beider Punkte
Navigation starten mit GPS-Follow-Modus

Erweiterte Funktionen

Routenübersicht: Zoom-Out-Button für Gesamtroute
Mock-GPS: Teste Navigation ohne echtes GPS
Spracheinstellungen: TTS-Test über Lautsprecher-Icon
Kartenauswahl: Direkte Punktauswahl auf der Karte

Suchbeispiele
"247"           → Stellplatz 247
"nr 15a"        → Stellplatz 15a
"wc"            → Sanitäranlagen
"restaurant"    → Gastronomie
"🚿"           → Sanitär (Emoji-Shortcut)
"rezeption"     → Information/Service
🔧 Technische Details
Dependencies

flutter_map: Kartendarstellung
vector_map_tiles: Vector-Tile-Rendering
geolocator: GPS-Funktionalität
flutter_tts: Sprachausgabe
provider: State Management
latlong2: Koordinaten-Berechnungen
collection: Datenstrukturen (PriorityQueue)

Performance-Optimierungen

Lazy Loading von Kartenstyles
Memory-Caching für wiederkehrende Requests
Debounced Search für flüssige Eingabe
Efficient Routing mit A*-Algorithmus
Minimal Re-renders durch gezieltes State Management

Mobile-spezifische Features

Responsive UI für verschiedene Bildschirmgrößen
Touch-optimierte Karteninteraktion
Keyboard-friendly Eingabefelder
Battery-efficient GPS-Nutzung

🐛 Debugging & Entwicklung
Logging

Debug-Prints in Development-Mode
Structured Logging für Services
Error Handling mit Stacktraces
Performance Monitoring für kritische Pfade

Testing
bash# Unit Tests
flutter test

# Integration Tests (falls implementiert)
flutter test integration_test/

# Performance Tests
flutter drive --target=test_driver/app.dart
📋 Roadmap
Geplante Features

 Offline-Modus mit heruntergeladenen Tiles
 Favoriten-System für häufige Ziele
 Routenhistorie und -sharing
 Accessibility-Verbesserungen
 Multi-Language Support
 Push-Notifications für Navigation

Technische Verbesserungen

 Unit Test Coverage auf >80%
 CI/CD Pipeline für automatisierte Builds
 Error Reporting mit Crashlytics
 Analytics für Nutzungsstatistiken

🤝 Entwicklung
Code-Standards

Dart/Flutter Lints für konsistente Formatierung
Modular Architecture mit klarer Trennung
Documentation für öffentliche APIs
Error Handling auf allen Ebenen

Beitragen

Fork das Repository
Feature-Branch erstellen (git checkout -b feature/amazing-feature)
Änderungen committen (git commit -m 'Add amazing feature')
Branch pushen (git push origin feature/amazing-feature)
Pull Request erstellen
