class TimeFormatter {
  static String formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60; //integer division 125 ~/ 60 = 2
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static int parseTimeToSeconds(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;

    return (minutes * 60) + seconds;
  }

  static String formatMinutesSeconds(int minutes, int seconds) {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
