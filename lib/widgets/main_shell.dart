import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../data/repositories/auth_repository.dart';
import '../screens/dashboard_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/home.dart';
import '../screens/settings.dart';
import '../screens/shopping_cart_screen.dart';
import '../services/app_navigation_controller.dart';
import '../services/recipe_sync_service.dart';
import '../services/recipe_sync_status.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Root shell with the main app tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final AuthRepository _authRepository = AuthRepository();
  final RecipeSyncService _syncService = RecipeSyncService();

  void _goToRecipesTab() {
    AppNavigationController.instance.selectRecipes();
  }

  Future<void> _retrySync() async {
    final user = _authRepository.currentUser;
    if (user == null) return;

    try {
      await _syncService.sync(user.uid);
    } catch (_) {
      if (!mounted) return;
      final error = RecipeSyncStatusController.instance.errorDescription;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? 'sync_failed'.tr()
                : 'sync_failed_details'.tr(args: [error]),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(onSearchTapped: _goToRecipesTab),
      const HomePage(),
      const ShoppingCartScreen(),
      const FavoritesScreen(),
      const SettingsScreen(),
    ];

    final navigation = AppNavigationController.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        navigation,
        RecipeSyncStatusController.instance,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: navigation.selectedTabIndex,
                  children: tabs,
                ),
              ),
              _SyncStatusBar(onRetry: _retrySync),
            ],
          ),
          bottomNavigationBar: _buildNavBar(),
        );
      },
    );
  }

  Widget _buildNavBar() {
    final selectedIndex = AppNavigationController.instance.selectedTabIndex;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.soft,
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'home'.tr(),
                selected: selectedIndex == 0,
                onTap: () => AppNavigationController.instance.selectTab(0),
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: 'recipes'.tr(),
                selected: selectedIndex == 1,
                onTap: () => AppNavigationController.instance.selectTab(1),
              ),
              _NavItem(
                icon: Icons.shopping_basket_outlined,
                activeIcon: Icons.shopping_basket,
                label: 'shopping'.tr(),
                selected: selectedIndex == 2,
                onTap: () => AppNavigationController.instance.selectTab(2),
              ),
              _NavItem(
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                label: 'favorites'.tr(),
                selected: selectedIndex == 3,
                onTap: () => AppNavigationController.instance.selectTab(3),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'settings'.tr(),
                selected: selectedIndex == 4,
                onTap: () => AppNavigationController.instance.selectTab(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusBar extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _SyncStatusBar({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final status = RecipeSyncStatusController.instance;
    final state = status.state;
    if (state == RecipeSyncState.idle || state == RecipeSyncState.synced) {
      return const SizedBox.shrink();
    }

    final isFailure = state == RecipeSyncState.failed;
    final isSyncing = state == RecipeSyncState.syncing;
    final color = isFailure ? Colors.red.shade700 : AppColors.primary;
    final background = isFailure ? Colors.red.shade50 : AppColors.primaryLight;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (isSyncing)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(
                isFailure ? Icons.cloud_off_outlined : Icons.cloud_done,
                color: color,
                size: 18,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _labelFor(status),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isFailure) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: onRetry, child: Text('retry'.tr())),
            ],
          ],
        ),
      ),
    );
  }

  String _labelFor(RecipeSyncStatusController status) {
    switch (status.state) {
      case RecipeSyncState.savedLocally:
        return 'saved_locally'.tr();
      case RecipeSyncState.syncing:
        return 'syncing_recipes'.tr();
      case RecipeSyncState.synced:
        return '';
      case RecipeSyncState.failed:
        final error = status.errorDescription;
        return error == null
            ? 'sync_failed'.tr()
            : 'sync_failed_details'.tr(args: [error]);
      case RecipeSyncState.idle:
        return '';
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: AppRadii.medium,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 23),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
