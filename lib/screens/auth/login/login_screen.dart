import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

/// ユーザー認証・アカウント管理画面（MVP必須機能③）
///
/// Firebase Authentication および Googleアカウント連携を管理する。
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.currentUserName,
    required this.onSignInCompleted,
    this.isInitialGate = false,
    this.onGuestSelected,
  });

  final String currentUserName;
  final ValueChanged<AppUser> onSignInCompleted;

  /// 初回起動時のログインゲート画面として表示するかどうか
  final bool isInitialGate;

  /// 初回ログイン画面で「ゲストとして参加」が押されたときのコールバック
  final VoidCallback? onGuestSelected;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService.instance;
  bool _isLoading = false;
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (!mounted) return;
      setState(() => _user = user);
      widget.onSignInCompleted(user);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ようこそ、${user.displayName} さん！')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ログインに失敗しました: ${e.toString().replaceAll("Exception: ", "")}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      final demo = AppUser.demoUser;
      setState(() => _user = demo);
      widget.onSignInCompleted(demo);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログアウトしました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ログアウトに失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleContinueAsGuest() {
    final guestUser = _authService.enterGuestMode();
    setState(() => _user = guestUser);
    widget.onSignInCompleted(guestUser);
    widget.onGuestSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isInitialGate
          ? null
          : AppBar(
              title: const Text(
                'アカウント・認証',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isInitialGate) ...[
                const Spacer(),
                const Text(
                  'ログイン',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(
                  Icons.map_outlined,
                  size: 56,
                  color: AppTheme.darkGrey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Memory Map',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ログインすると自分だけの思い出マップを作ります。\nゲストではサンプルを体験できます。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryGrey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.darkGrey,
                    foregroundColor: AppTheme.pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.pureWhite,
                          ),
                        )
                      : const Icon(Icons.login, size: 20),
                  label: const Text(
                    'Googleアカウントでログイン',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleContinueAsGuest,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline, size: 20),
                  label: const Text(
                    'ゲストとして参加',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ] else ...[
                // アカウント情報カード
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.lightGrey),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.darkGrey,
                        backgroundImage: _user.photoUrl != null
                            ? NetworkImage(_user.photoUrl!)
                            : null,
                        child: _user.photoUrl == null
                            ? const Icon(
                                Icons.person_outline,
                                color: AppTheme.pureWhite,
                                size: 28,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '現在のログインユーザー',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _user.displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                            if (_user.email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _user.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryGrey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '認証プロバイダ連携',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGrey,
                  ),
                ),
                const SizedBox(height: 12),
                if (_user.isAnonymous)
                  // ログイン前：Googleアカウントでログインボタン
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.darkGrey,
                      foregroundColor: AppTheme.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.pureWhite,
                            ),
                          )
                        : const Icon(Icons.login, size: 20),
                    label: const Text(
                      'Googleアカウントでログイン',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  // ログイン後：ログアウトボタン
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleSignOut,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('ログアウト / ゲストに戻る'),
                  ),
              ],

              const Spacer(),
              const Center(
                child: Text(
                  '個人データはグループ単位で安全に共有されます',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
