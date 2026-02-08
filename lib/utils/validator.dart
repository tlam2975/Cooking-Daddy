class Validators {
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return true;

    final urlPattern = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
    );
    return urlPattern.hasMatch(url);
  }

  static bool isValidTimer(String? time) {
    if (time == null || time.isEmpty) return true;

    final pattern = RegExp(r'^\d{1,2}:\d{2}$');
    if (!pattern.hasMatch(time)) return false;

    final parts = time.split(':');
    final minutes = int.tryParse(parts[0]) ?? -1;
    final seconds = int.tryParse(parts[1]) ?? -1;

    return minutes >= 0 && seconds >= 0 && seconds < 60;
  }

  static String? validateRecipeName(String? value) {
    if (!isNotEmpty(value)) {
      return 'Recipe name is required';
    }
    return null;
  }

  static String? validateInstruction(String? value) {
    if (!isNotEmpty(value)) {
      return 'Instruction is required';
    }
    return null;
  }

  static String? validateUrl(String? value) {
    if (value != null && value.isNotEmpty && !isValidUrl(value)) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  static String? validateTimerFormat(String? value) {
    if (value != null && value.isNotEmpty && !isValidTimer(value)) {
      return 'Format should be MM:SS (e.g., 03:30)';
    }
    return null;
  }
}
