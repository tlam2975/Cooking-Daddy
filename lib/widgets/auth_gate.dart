import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/repositories/auth_repository.dart';
import '../screens/auth/sign_in_screen.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

/// Root widget: signed-out -> SignInScreen, signed-in -> MainShell.
///
/// NOTE: the "pull down any Firestore recipes not present locally" step
/// from the Phase 1 plan is NOT included here yet — that needs
/// firestore_datasource.dart, which hasn't been built. Right now this only
/// gates on auth state, it doesn't sync anything yet.
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
          return const MainShell();
        }
        return const SignInScreen();
      },
    );
  }
}
