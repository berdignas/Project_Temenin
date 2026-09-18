import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;

  // High quality chime / notification ringtone URLs
  static const String notificationChimeUrl =
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';

  static const String loudAlertRingtoneUrl =
      'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3';

  Future<void> init() async {
    try {
      _player ??= AudioPlayer();
      await _player?.setVolume(1.0);
    } catch (e) {
      debugPrint('[NotificationSoundService] init error: $e');
    }
  }

  /// Play notification chime sound with haptic feedback
  Future<void> playNotificationSound({bool loop = false, bool isLoudAlert = false}) async {
    try {
      _player ??= AudioPlayer();

      // Trigger tactile haptic feedback
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}

      await _player?.setVolume(1.0);
      if (loop) {
        await _player?.setReleaseMode(ReleaseMode.loop);
      } else {
        await _player?.setReleaseMode(ReleaseMode.release);
      }

      final url = isLoudAlert ? loudAlertRingtoneUrl : notificationChimeUrl;
      await _player?.stop();
      await _player?.play(UrlSource(url));
      _isPlaying = true;
      debugPrint('[NotificationSoundService] 🔔 Playing notification sound/chime: $url');
    } catch (e) {
      debugPrint('[NotificationSoundService] play sound error: $e');
    }
  }

  /// Stop currently playing sound
  Future<void> stopSound() async {
    try {
      if (_player != null && _isPlaying) {
        await _player?.stop();
        _isPlaying = false;
        debugPrint('[NotificationSoundService] 🔕 Stopped notification sound');
      }
    } catch (e) {
      debugPrint('[NotificationSoundService] stop sound error: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
