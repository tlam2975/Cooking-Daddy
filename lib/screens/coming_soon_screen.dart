import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared placeholder for features that don't exist yet.
/// Used both as a bottom-nav tab (no app bar) and as a standalone
/// pushed route (with an app bar + back button).
class ComingSoonScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool showAppBar;

  const ComingSoonScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.showAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );

    if (!showAppBar) return content;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: content,
    );
  }
}
