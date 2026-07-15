import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum SpeechState { idle, listening, processing, finished, error }

class SpeechService extends ChangeNotifier {
  static final SpeechService instance = SpeechService._init();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  SpeechState _state = SpeechState.idle;
  String _lastWords = "";
  String _errorMsg = "";

  SpeechService._init() {
    _initSpeech();
  }

  SpeechState get state => _state;
  String get lastWords => _lastWords;
  String get errorMsg => _errorMsg;
  bool get isListening => _speech.isListening;
  bool get isAvailable => _isAvailable;

  Future<void> _initSpeech() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint("Speech status: $status");
          if (status == 'listening') {
            _state = SpeechState.listening;
          } else if (status == 'notListening') {
            if (_state == SpeechState.listening) {
              _state = SpeechState.finished;
            }
          }
          notifyListeners();
        },
        onError: (errorNotification) {
          debugPrint("Speech error: $errorNotification");
          _state = SpeechState.error;
          _errorMsg = errorNotification.errorMsg;
          notifyListeners();
        },
      );
    } catch (e) {
      _isAvailable = false;
      debugPrint("Error initializing speech to text: $e");
    }
  }

  Future<bool> startListening(Function(String) onResult) async {
    _lastWords = "";
    _errorMsg = "";
    if (!_isAvailable) {
      await _initSpeech();
    }
    if (!_isAvailable) {
      // Intentar una simulación parcial con comandos de voz pregrabados en caso de emuladores sin micrófono
      if (kDebugMode) {
        _isAvailable = true;
      } else {
        _state = SpeechState.error;
        _errorMsg = "Servicio de dictado no disponible en este dispositivo.";
        notifyListeners();
        return false;
      }
    }

    _state = SpeechState.listening;
    notifyListeners();

    if (kDebugMode && !_speech.isAvailable) {
      // Mock para depuración en simuladores que carecen de hardware de micrófono físico
      await Future.delayed(const Duration(seconds: 3));
      _lastWords = "Vaca decaída no quiere comer y tiene fiebre alta";
      _state = SpeechState.finished;
      onResult(_lastWords);
      notifyListeners();
      return true;
    }

    await _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        if (result.finalResult) {
          _state = SpeechState.finished;
        }
        onResult(_lastWords);
        notifyListeners();
      },
    );
    return true;
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      _state = SpeechState.finished;
      notifyListeners();
    }
  }

  void reset() {
    _state = SpeechState.idle;
    _lastWords = "";
    _errorMsg = "";
    notifyListeners();
  }
}
