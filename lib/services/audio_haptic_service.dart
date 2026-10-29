import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Layanan sensorik untuk efek audio lembaran kertas dan getaran haptic saat membalik halaman.
class AudioHapticService {
  static final AudioHapticService instance = AudioHapticService._internal();
  AudioHapticService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isAudioEnabled = true;
  bool isHapticEnabled = true;

  /// Memutar efek suara gesekan lembaran kertas.
  Future<void> playPageFlipSound() async {
    if (!isAudioEnabled) return;
    try {
      // Memutar file audio aset atau fallback suara sistem
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/page_flip.mp3'));
    } catch (_) {
      // Fallback feedback sistem jika aset audio belum dimuat
      await SystemSound.play(SystemSoundType.click);
    }
  }

  /// Menghasilkan getaran lembut (haptic feedback) saat menarik/melepas lembaran halaman.
  Future<void> triggerHaptic() async {
    if (!isHapticEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
