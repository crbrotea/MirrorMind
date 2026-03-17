import 'dart:ui';

/// Represents the color palette associated with a specific emotion.
class EmotionColor {
  final Color primary;
  final Color secondary;
  final Color glow;

  const EmotionColor({
    required this.primary,
    required this.secondary,
    required this.glow,
  });
}

/// Emotion color palettes keyed by emotion name.
///
/// The glow color is derived from the primary color at 0.5 alpha.
const Map<String, EmotionColor> emotionColors = {
  'anxiety': EmotionColor(
    primary: Color(0xFF2C3E6B),
    secondary: Color(0xFF1A2744),
    glow: Color(0x802C3E6B),
  ),
  'sadness': EmotionColor(
    primary: Color(0xFF6B7B8D),
    secondary: Color(0xFF3D4A57),
    glow: Color(0x806B7B8D),
  ),
  'anger': EmotionColor(
    primary: Color(0xFF8B2500),
    secondary: Color(0xFF5C1A00),
    glow: Color(0x808B2500),
  ),
  'joy': EmotionColor(
    primary: Color(0xFFD4A017),
    secondary: Color(0xFFA67C00),
    glow: Color(0x80D4A017),
  ),
  'calm': EmotionColor(
    primary: Color(0xFF4A7C59),
    secondary: Color(0xFF2D5A3A),
    glow: Color(0x804A7C59),
  ),
  'fear': EmotionColor(
    primary: Color(0xFF4A2D6B),
    secondary: Color(0xFF2D1A44),
    glow: Color(0x804A2D6B),
  ),
  'hope': EmotionColor(
    primary: Color(0xFFD4752E),
    secondary: Color(0xFFA65A1E),
    glow: Color(0x80D4752E),
  ),
  'neutral': EmotionColor(
    primary: Color(0xFF4A5568),
    secondary: Color(0xFF2D3748),
    glow: Color(0x804A5568),
  ),
};

/// Stage display labels in Spanish.
const Map<String, String> stageLabels = {
  'welcome': 'Bienvenida',
  'mirror': 'Espejo',
  'shift': 'Transformación',
  'arrive': 'Llegada',
  'complete': 'Completado',
};

/// Emotion display names in Spanish.
const Map<String, String> emotionDisplayNames = {
  'anxiety': 'Ansiedad',
  'sadness': 'Tristeza',
  'anger': 'Ira',
  'joy': 'Alegría',
  'calm': 'Calma',
  'fear': 'Miedo',
  'hope': 'Esperanza',
  'love': 'Amor',
  'neutral': 'Neutral',
  'frustration': 'Frustración',
};

/// Ordered list of session stages.
const List<String> stageOrder = [
  'welcome',
  'mirror',
  'shift',
  'arrive',
  'complete',
];

/// Breathing phase labels in Spanish.
const Map<String, String> phaseLabels = {
  'inhale': 'Inhala',
  'hold': 'Mantén',
  'exhale': 'Exhala',
  'rest': 'Descansa',
};

/// Breathing technique labels in Spanish.
String techniqueLabel(String technique) {
  switch (technique) {
    case 'box':
      return 'Respiración cuadrada';
    case 'calm':
      return 'Respiración calmante';
    default:
      return 'Suspiro fisiológico';
  }
}

/// WebSocket base URL. Override via environment variable if needed.
const String wsBaseUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'ws://localhost:8080/ws',
);

/// REST API base URL.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

/// Audio capture sample rate in Hz.
const int sampleRateCapture = 16000;

/// Audio playback sample rate in Hz.
const int sampleRatePlayback = 24000;

/// Duration in milliseconds before a transcript message fades out.
const int transcriptFadeMs = 5000;

/// Duration in milliseconds for the image crossfade transition.
const int crossfadeDurationMs = 3000;

/// The emotion used when no emotion has been detected yet.
const String defaultEmotion = 'neutral';

/// The stage used at the beginning of a session.
const String defaultStage = 'welcome';

/// The app-wide background color.
const Color backgroundColor = Color(0xFF0A0A1A);
