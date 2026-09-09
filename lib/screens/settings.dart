import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../data/repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// NOTE: Account/Theme section labels are hardcoded Vietnamese for now —
/// not yet wired to easy_localization, same to-do flagged on
/// sign_in_screen.dart. Language section keeps its existing .tr() keys
/// since that logic isn't changing. The old random-quote header was
/// dropped — it didn't fit the revamped design and there's no mockup
/// reference for this screen, flagging that as a judgment call.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthRepository _authRepository = AuthRepository();

  @override
  Widget build(BuildContext context) {
    final user = _authRepository.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cài đặt',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 20),

              _sectionCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 28,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Chưa đăng nhập',
                            style: AppTextStyles.cardTitle,
                          ),
                          if (user?.email != null)
                            Text(user!.email!, style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _authRepository.signOut(),
                      // AuthGate's authStateChanges listener handles
                      // navigation back to SignInScreen automatically.
                      child: Text(
                        'Đăng xuất',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text('Giao diện', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              _sectionCard(
                child: Column(
                  children: ThemePreset.values.map(_presetTile).toList(),
                ),
              ),

              const SizedBox(height: 24),
              Text('language'.tr(), style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              _sectionCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.language,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  title: Text(
                    context.locale.languageCode == 'en'
                        ? 'english'.tr()
                        : 'vietnamese'.tr(),
                    style: AppTextStyles.cardTitle,
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  onTap: _showLanguageDialog,
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text('copyright'.tr(), style: AppTextStyles.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _presetTile(ThemePreset preset) {
    final isSelected = ThemeController.instance.preset == preset;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ThemeController.instance.setPreset(preset),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: preset.previewColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(preset.label, style: AppTextStyles.body)),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('language'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'en',
                groupValue: context.locale.languageCode,
                onChanged: (value) {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              title: Text('english'.tr()),
              onTap: () {
                context.setLocale(const Locale('en'));
                Navigator.pop(context);
                setState(() {});
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'vi',
                groupValue: context.locale.languageCode,
                onChanged: (value) {
                  context.setLocale(const Locale('vi'));
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              title: Text('vietnamese'.tr()),
              onTap: () {
                context.setLocale(const Locale('vi'));
                Navigator.pop(context);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
