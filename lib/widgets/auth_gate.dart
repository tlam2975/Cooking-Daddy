import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/repositories/auth_repository.dart';
import '../screens/auth/sign_in_screen.dart';
import '../services/recipe_sync_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

/// Root widget: signed-out -> SignInScreen, signed-in -> MainShell.
///
class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final AuthRepository _authRepository = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authRepository.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.hasData) {
          return _SyncGate(user: snapshot.data!);
        }
        return const SignInScreen();
      },
    );
  }
}

class _SyncGate extends StatefulWidget {
  final User user;

  const _SyncGate({required this.user});

  @override
  State<_SyncGate> createState() => _SyncGateState();
}

class _SyncGateState extends State<_SyncGate> {
  final RecipeSyncService _syncService = RecipeSyncService();
  late Future<void> _syncFuture;

  @override
  void initState() {
    super.initState();
    _syncFuture = _syncService.sync(widget.user.uid);
  }

  @override
  void didUpdateWidget(covariant _SyncGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _syncFuture = _syncService.sync(widget.user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _syncFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('Đang đồng bộ công thức...', style: AppTextStyles.body),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('Recipe sync failed: ${snapshot.error}');
        }

        return const MainShell();
      },
    );
  }
}
