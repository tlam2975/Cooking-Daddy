import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three selectable color moods. Each has a real light palette below;
/// dark palettes aren't designed yet (see `_Palettes.dark`) — no dark-mode
/// UI is exposed until those are approved.
enum ThemePreset {
  warm('Ấm áp'),
  sage('Xanh bạc hà'),
  ocean('Biển');

  final String label;
  const ThemePreset(this.label);
}

/// Light vs dark variant of whichever preset is active. Only `light` has
/// real values right now — `dark` is a stub so persistence, the notifier,
/// and the lookup logic don't need to change again once dark palettes
/// are designed.
enum AppThemeMode { light, dark }

/// A concrete set of color values for one preset+mode combination.
/// Field names mirror the original static AppColors class so call sites
/// (AppColors.primary etc.) don't need to change — only stop being const.
class AppColorScheme {
  final Color primary;
  final Color primaryLight;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color successLight;

  const AppColorScheme({
    required this.primary,
    required this.primaryLight,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.successLight,
  });
}

/// Registry of implemented palettes.
/// TODO(dark-mode): design and add entries to `dark` for each preset.
/// ThemeController._resolve() already falls back to `light` when a dark
/// entry is missing, so adding entries here is the only change needed.
class _Palettes {
  _Palettes._();

  static const Map<ThemePreset, AppColorScheme> light = {
    ThemePreset.warm: AppColorScheme(
      primary: Color(0xFFE8604C),
      primaryLight: Color(0xFFFCE0D8),
      background: Color(0xFFFCF3EC),
      surface: Colors.white,
      border: Color(0xFFF1E4D8),
      textPrimary: Color(0xFF2B2420),
      textSecondary: Color(0xFF8C8079),
      success: Color(0xFF4CAF7D),
      successLight: Color(0xFFE1F3E9),
    ),
    ThemePreset.sage: AppColorScheme(
      primary: Color(0xFF6B8E5A),
      primaryLight: Color(0xFFDDE9D3),
      background: Color(0xFFF3F6EE),
      surface: Colors.white,
      border: Color(0xFFE2E8D8),
      textPrimary: Color(0xFF2E3826),
      textSecondary: Color(0xFF7A8A6E),
      success: Color(0xFF4CAF7D),
      successLight: Color(0xFFE1F3E9),
    ),
    ThemePreset.ocean: AppColorScheme(
      primary: Color(0xFF3D7A82),
      primaryLight: Color(0xFFD3E7E8),
      background: Color(0xFFEFF7F6),
      surface: Colors.white,
      border: Color(0xFFD8E4E2),
      textPrimary: Color(0xFF1F3A3D),
      textSecondary: Color(0xFF6E8A8A),
      success: Color(0xFF4CAF7D),
      successLight: Color(0xFFE1F3E9),
    ),
  };

  static const Map<ThemePreset, AppColorScheme> dark = {};
}

/// Preview color for preset pickers, independent of current mode.
extension ThemePresetPreview on ThemePreset {
  Color get previewColor => _Palettes.light[this]!.primary;
}

/// Global, app-wide theme state. No state-management package is used
/// elsewhere in the app, so this is a plain singleton ChangeNotifier.
/// Wrap the root MaterialApp in an AnimatedBuilder listening to
/// ThemeController.instance so the whole tree rebuilds on change.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _presetPrefsKey = 'theme_preset';

  ThemePreset _preset = ThemePreset.warm;
  final AppThemeMode _mode = AppThemeMode.light; // no toggle yet — see enum doc

  ThemePreset get preset => _preset;
  AppThemeMode get mode => _mode;

  AppColorScheme get colors => _resolve(_preset, _mode);

  AppColorScheme _resolve(ThemePreset preset, AppThemeMode mode) {
    if (mode == AppThemeMode.dark) {
      final darkMatch = _Palettes.dark[preset];
      if (darkMatch != null) return darkMatch;
      // Falls back to light until dark palettes exist — see TODO above.
    }
    return _Palettes.light[preset]!;
  }

  /// Call once at app startup (before runApp) to restore the saved preset.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_presetPrefsKey);
    if (saved != null) {
      _preset = ThemePreset.values.firstWhere(
        (p) => p.name == saved,
        orElse: () => ThemePreset.warm,
      );
      notifyListeners();
    }
  }

  Future<void> setPreset(ThemePreset preset) async {
    if (preset == _preset) return;
    _preset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetPrefsKey, preset.name);
  }
}
