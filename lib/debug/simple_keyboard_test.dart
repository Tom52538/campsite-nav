// lib/debug/simple_keyboard_test.dart - EINFACHER DEBUG TEST
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SimpleKeyboardTest extends StatefulWidget {
  const SimpleKeyboardTest({super.key});

  @override
  State<SimpleKeyboardTest> createState() => _SimpleKeyboardTestState();
}

class _SimpleKeyboardTestState extends State<SimpleKeyboardTest>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _status = "App gestartet";
  bool _keyboardVisible = false;
  bool _hasFocus = false;
  String _currentText = "";
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
        _status = _hasFocus ? "✅ Focus ERHALTEN" : "❌ Focus VERLOREN";
      });
      if (kDebugMode) {
        print("FOCUS: ${_hasFocus ? 'GAINED' : 'LOST'}");
      }
    });

    _controller.addListener(() {
      setState(() {
        _currentText = _controller.text;
        _status = "📝 Text: '$_currentText'";
      });
      if (kDebugMode) {
        print("TEXT: '$_currentText'");
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final isVisible = keyboardHeight > 50;

        if (isVisible != _keyboardVisible) {
          setState(() {
            _keyboardVisible = isVisible;
            _status = isVisible
                ? "⌨️ Tastatur GEÖFFNET (${keyboardHeight.toInt()}px)"
                : "⌨️ Tastatur GESCHLOSSEN";
          });
          if (kDebugMode) {
            print(
                "KEYBOARD: ${isVisible ? 'OPENED' : 'CLOSED'} - Height: ${keyboardHeight.toInt()}");
          }
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _testFocus() {
    _tapCount++;
    setState(() {
      _status = "🔧 Focus-Test #$_tapCount gestartet";
    });
    FocusScope.of(context).requestFocus(_focusNode);
    if (kDebugMode) {
      print("MANUAL FOCUS REQUEST #$_tapCount");
    }
  }

  void _testUnfocus() {
    setState(() {
      _status = "🔧 Unfocus-Test";
    });
    FocusScope.of(context).unfocus();
    if (kDebugMode) {
      print("MANUAL UNFOCUS");
    }
  }

  void _onTap() {
    _tapCount++;
    setState(() {
      _status = "👆 TextField TAP #$_tapCount";
    });
    if (kDebugMode) {
      print("TEXTFIELD TAP #$_tapCount");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboard Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // STATUS DISPLAY
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _keyboardVisible ? Colors.green[100] : Colors.red[100],
                border: Border.all(
                  color: _keyboardVisible ? Colors.green : Colors.red,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS: $_status',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '⌨️ Tastatur: ${_keyboardVisible ? "SICHTBAR" : "VERSTECKT"}'),
                  Text('🎯 Focus: ${_hasFocus ? "JA" : "NEIN"}'),
                  Text('📝 Text: "$_currentText"'),
                  Text('👆 Taps: $_tapCount'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // TEST BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testFocus,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('FOCUS',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testUnfocus,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('UNFOCUS',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // TEST TEXTFIELD
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onTap: _onTap,
                decoration: const InputDecoration(
                  labelText: 'TIPPE HIER ZUM TESTEN',
                  labelStyle:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 20),

            // INSTRUCTIONS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TEST-ANLEITUNG:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Tippe auf das TextField'),
                  Text('2. Schaue ob Status sich ändert'),
                  Text('3. Teste FOCUS/UNFOCUS Buttons'),
                  Text('4. Tippe Text wenn Tastatur da ist'),
                  Text('5. Berichte was du siehst!'),
                ],
              ),
            ),

            const Spacer(),

            // RESULT SUMMARY
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ERGEBNIS: ${_keyboardVisible && _hasFocus ? "✅ FUNKTIONIERT!" : "❌ PROBLEM ERKANNT"}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
