import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;

  // Sound URL for order ringtone (high quality chime / alert tone)
  static const String orderAlertSoundUrl =
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'; // pleasant notification chime

  static const String loudRingtoneUrl =
      'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3'; // distinct incoming order alert

  Future<void> init() async {
    try {
      _player = AudioPlayer();
      await _player?.setVolume(1.0);
    } catch (e) {
      debugPrint('[NotificationSoundService] init info: $e');
    }
  }

  /// Play order alert sound with haptic feedback
  Future<void> playOrderAlert({bool loop = false}) async {
    try {
      if (_player == null) {
        _player = AudioPlayer();
      }
      
      // Haptic feedback
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}

      await _player?.setVolume(1.0);
      if (loop) {
        await _player?.setReleaseMode(ReleaseMode.loop);
      } else {
        await _player?.setReleaseMode(ReleaseMode.release);
      }

      await _player?.play(UrlSource(loudRingtoneUrl));
      _isPlaying = true;
      debugPrint('[NotificationSoundService] 🔔 Playing incoming order ringtone/chime');
    } catch (e) {
      debugPrint('[NotificationSoundService] play sound info: $e');
    }
  }

  /// Stop currently playing sound
  Future<void> stopSound() async {
    try {
      if (_player != null && _isPlaying) {
        await _player?.stop();
        _isPlaying = false;
        debugPrint('[NotificationSoundService] 🔕 Stopped order ringtone');
      }
    } catch (e) {
      debugPrint('[NotificationSoundService] stop sound info: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
