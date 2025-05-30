// lib/debug/keyboard_debug_screen.dart - VOLLSTÄNDIGE DEBUG ROUTINE
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardDebugScreen extends StatefulWidget {
  const KeyboardDebugScreen({super.key});

  @override
  State<KeyboardDebugScreen> createState() => _KeyboardDebugScreenState();
}

class _KeyboardDebugScreenState extends State<KeyboardDebugScreen>
    with WidgetsBindingObserver {
  final TextEditingController _testController1 = TextEditingController();
  final TextEditingController _testController2 = TextEditingController();
  final FocusNode _testFocus1 = FocusNode();
  final FocusNode _testFocus2 = FocusNode();

  final List<String> _debugLogs = [];
  double _keyboardHeight = 0;
  bool _isKeyboardVisible = false;
  int _tapCounter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _log("🔧 INIT: KeyboardDebugScreen initialisiert");

    // Focus Listener
    _testFocus1.addListener(() {
      _log("🎯 FOCUS1: ${_testFocus1.hasFocus ? 'GAINED' : 'LOST'}");
    });

    _testFocus2.addListener(() {
      _log("🎯 FOCUS2: ${_testFocus2.hasFocus ? 'GAINED' : 'LOST'}");
    });

    // Text Controller Listener
    _testController1.addListener(() {
      _log("📝 TEXT1: '${_testController1.text}'");
    });

    _testController2.addListener(() {
      _log("📝 TEXT2: '${_testController2.text}'");
    });
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = "[$timestamp] $message";

    if (kDebugMode) {
      print(logMessage);
    }

    setState(() {
      _debugLogs.add(logMessage);
      if (_debugLogs.length > 50) {
        _debugLogs.removeAt(0);
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        final newKeyboardHeight = mediaQuery.viewInsets.bottom;
        final newIsVisible = newKeyboardHeight > 50;

        if (newKeyboardHeight != _keyboardHeight ||
            newIsVisible != _isKeyboardVisible) {
          _log(
              "⌨️ KEYBOARD: height=${newKeyboardHeight.toInt()}, visible=$newIsVisible");

          setState(() {
            _keyboardHeight = newKeyboardHeight;
            _isKeyboardVisible = newIsVisible;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _testController1.dispose();
    _testController2.dispose();
    _testFocus1.dispose();
    _testFocus2.dispose();
    super.dispose();
  }

  void _clearLogs() {
    setState(() {
      _debugLogs.clear();
    });
    _log("🧹 LOGS: Cleared");
  }

  void _testFocusRequest(int fieldNumber) {
    _log("🔧 TEST: Manual focus request for field $fieldNumber");
    if (fieldNumber == 1) {
      FocusScope.of(context).requestFocus(_testFocus1);
    } else {
      FocusScope.of(context).requestFocus(_testFocus2);
    }
  }

  void _testUnfocus() {
    _log("🔧 TEST: Manual unfocus");
    FocusScope.of(context).unfocus();
  }

  void _testSystemKeyboard() {
    _log("🔧 TEST: System keyboard channel test");
    try {
      SystemChannels.textInput.invokeMethod('TextInput.show');
      _log("✅ SUCCESS: System keyboard show called");
    } catch (e) {
      _log("❌ ERROR: System keyboard show failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboard Debug'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '⌨️ Keyboard: ${_isKeyboardVisible ? "VISIBLE" : "HIDDEN"} (${_keyboardHeight.toInt()}px)'),
                Text('🎯 Focus1: ${_testFocus1.hasFocus}'),
                Text('🎯 Focus2: ${_testFocus2.hasFocus}'),
                Text('📝 Text1: "${_testController1.text}"'),
                Text('📝 Text2: "${_testController2.text}"'),
              ],
            ),
          ),

          // Test Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _testFocusRequest(1),
                      child: const Text('Focus Field 1'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _testFocusRequest(2),
                      child: const Text('Focus Field 2'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _testUnfocus,
                      child: const Text('Unfocus'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _testSystemKeyboard,
                      child: const Text('System KB'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _clearLogs,
                      child: const Text('Clear Logs'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Test TextFields
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // TEST FIELD 1 - MINIMAL
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _testController1,
                    focusNode: _testFocus1,
                    decoration: const InputDecoration(
                      labelText: 'TEST FIELD 1 - MINIMAL',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onTap: () {
                      _tapCounter++;
                      _log("👆 TAP1: Tap #$_tapCounter");
                    },
                    onChanged: (text) {
                      _log("📝 CHANGE1: '$text'");
                    },
                    onSubmitted: (text) {
                      _log("✅ SUBMIT1: '$text'");
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // TEST FIELD 2 - WIE IN ORIGINALER APP
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _testController2,
                    focusNode: _testFocus2,
                    decoration: const InputDecoration(
                      labelText: 'TEST FIELD 2 - ORIGINAL CONFIG',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    enabled: true,
                    readOnly: false,
                    canRequestFocus: true,
                    enableInteractiveSelection: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onTap: () {
                      _tapCounter++;
                      _log("👆 TAP2: Tap #$_tapCounter");
                    },
                    onChanged: (text) {
                      _log("📝 CHANGE2: '$text'");
                    },
                    onSubmitted: (text) {
                      _log("✅ SUBMIT2: '$text'");
                    },
                    onTapOutside: (event) {
                      _log("🚫 TAP_OUTSIDE2: Event received");
                    },
                  ),
                ),
              ],
            ),
          ),

          // Debug Logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DEBUG LOGS:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _debugLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            _debugLogs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
