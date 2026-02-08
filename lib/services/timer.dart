import 'dart:async';
import 'notification.dart';

class TimerService {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;

  final _controller = StreamController<int>.broadcast();
  Stream<int> get timeStream => _controller.stream;

  bool get isRunning => _isRunning;
  int get remainingSeconds => _remainingSeconds;

  void startTimer(int seconds, {String? stepName}) {
    if (_isRunning) {
      stopTimer();
    }

    _remainingSeconds = seconds;
    _isRunning = true;
    _controller.add(_remainingSeconds);

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _controller.add(_remainingSeconds);
      } else {
        stopTimer();
        _onTimerComplete(stepName);
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    _isRunning = false;
  }

  void resumeTimer({String? stepName}) {
    if (_remainingSeconds > 0 && !_isRunning) {
      startTimer(_remainingSeconds, stepName: stepName);
    }
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _remainingSeconds = 0;
  }

  void _onTimerComplete(String? stepName) {
    NotificationService.showTimerCompleteNotification(
      title: 'Timer Complete!',
      body: stepName != null
          ? 'Step "$stepName" is done!'
          : 'Your cooking timer is complete! \nComeback right now!',
    );
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
