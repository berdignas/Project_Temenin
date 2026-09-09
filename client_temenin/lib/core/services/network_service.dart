import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      Connectivity().checkConnectivity().then((results) {
        _updateConnectionStatus(results);
      }).catchError((e) {
        debugPrint('⚠️ Initial connectivity check error: $e');
      });

      _subscription = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _updateConnectionStatus(results);
        },
        onError: (err) {
          debugPrint('⚠️ Connectivity stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('⚠️ NetworkService initialize error: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (isOnline.value != hasConnection) {
      isOnline.value = hasConnection;
      debugPrint('🌐 Network status changed: ${hasConnection ? 'ONLINE' : 'OFFLINE'}');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
