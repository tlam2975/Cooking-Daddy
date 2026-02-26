import 'dart:async';
import 'package:flutter/material.dart';
import 'notification.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;

  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;

  // Start timer and schedule notification
  Future<void> startTimer({
    required int seconds,
    required String recipeName,
    required int stepNumber,
  }) async {
    _remainingSeconds = seconds;
    _isRunning = true;
    notifyListeners();

    // CRITICAL: Schedule notification IMMEDIATELY (not after countdown)
    await NotificationService.scheduleTimerNotification(
      seconds: seconds,
      recipeName: recipeName,
      stepNumber: stepNumber,
    );

    print('✅ Timer started: $seconds seconds');

    // Start countdown for UI only
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        stopTimer();
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _remainingSeconds = 0;

    // Cancel any scheduled notifications
    NotificationService.cancelScheduledNotifications();

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    NotificationService.cancelScheduledNotifications();
    super.dispose();
  }
}
