// Conditional export pattern for cross-platform audio encoding
// This exports the appropriate AudioEncoder implementation based on platform
export 'audio_encoder_stub.dart' // Default stub for unsupported platforms
    if (dart.library.io) 'audio_encoder_io.dart' // Android/iOS implementation
    if (dart.library.js_interop) 'audio_encoder_web.dart'; // Web implementation
