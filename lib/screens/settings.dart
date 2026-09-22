import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../data/repositories/auth_repository.dart';
import '../services/recipe_sync_status.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

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
                'settings'.tr(),
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
                            user?.displayName ?? 'not_signed_in'.tr(),
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
                        'sign_out'.tr(),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text('theme'.tr(), style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              _sectionCard(
                child: Column(
                  children: ThemePreset.values.map(_presetTile).toList(),
                ),
              ),

              const SizedBox(height: 24),
              Text('sync_status'.tr(), style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              _sectionCard(child: const _SyncStatusSummary()),

              const SizedBox(height: 24),
              Text('diagnostics'.tr(), style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              _sectionCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.terminal_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  title: Text('app_logs'.tr(), style: AppTextStyles.cardTitle),
                  subtitle: Text(
                    'app_logs_description'.tr(),
                    style: AppTextStyles.caption,
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () => Navigator.pushNamed(context, '/appLogs'),
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
            Expanded(
              child: Text(preset.labelKey.tr(), style: AppTextStyles.body),
            ),
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

class _SyncStatusSummary extends StatelessWidget {
  const _SyncStatusSummary();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: RecipeSyncStatusController.instance,
      builder: (context, _) {
        final status = RecipeSyncStatusController.instance;
        final lastSyncedAt = status.lastSyncedAt;
        final stateLabel = switch (status.state) {
          RecipeSyncState.idle => 'sync_not_started'.tr(),
          RecipeSyncState.savedLocally => 'saved_locally'.tr(),
          RecipeSyncState.syncing => 'syncing_recipes'.tr(),
          RecipeSyncState.synced =>
            lastSyncedAt == null
                ? 'sync_complete'.tr()
                : 'last_sync_at'.tr(args: [_formatTime(context, lastSyncedAt)]),
          RecipeSyncState.failed =>
            lastSyncedAt == null
                ? 'sync_failed'.tr()
                : 'sync_failed_last_sync'.tr(
                    args: [_formatTime(context, lastSyncedAt)],
                  ),
        };

        final error = status.errorDescription;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              status.state == RecipeSyncState.failed
                  ? Icons.cloud_off_outlined
                  : Icons.cloud_done_outlined,
              color: status.state == RecipeSyncState.failed
                  ? Colors.red.shade700
                  : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stateLabel, style: AppTextStyles.body),
                  if (status.state == RecipeSyncState.failed &&
                      error != null) ...[
                    const SizedBox(height: 6),
                    SelectableText(
                      error,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatTime(BuildContext context, DateTime value) {
    return DateFormat.Hm(context.locale.toString()).format(value);
  }
}
