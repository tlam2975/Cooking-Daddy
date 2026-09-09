import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/repositories/auth_repository.dart';
import '../../theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';

/// NOTE: text is hardcoded Vietnamese for now — not yet wired to
/// easy_localization (.tr()). Flagging as a to-do rather than doing it
/// silently, same as the rest of the app's localization gaps.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSigningIn = false;
  final AuthRepository _authRepository = AuthRepository();

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSigningIn = true);
    try {
      await _authRepository.signInWithGoogle();
      // On success, AuthGate's authStateChanges listener handles navigation
      // automatically — nothing to do here.
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      // User cancelled the Google account picker — not an error, stay quiet.
      // NOTE: some Android config errors (bad SHA fingerprint / serverClientId)
      // also surface as `canceled` — if this fires on every attempt, check
      // config before assuming it's really a user cancel.
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng nhập thất bại: ${e.description ?? e.code}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đăng nhập thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.soup_kitchen_outlined,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Cooking Daddy',
                style: AppTextStyles.greeting.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 8),
              Text(
                'login_to_save_and_sync_recipes'.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                  icon: _isSigningIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login, size: 20),
                  label: Text(
                    _isSigningIn ? 'Đang đăng nhập...' : 'Đăng nhập với Google',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
