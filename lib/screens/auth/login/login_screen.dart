import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// ユーザー認証・アカウント管理画面（MVP必須機能③）
///
/// Firebase Authentication 接続前の骨格UIとして、ログイン状態の確認・切替を提供する。
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.currentUserName,
    required this.onSignInCompleted,
  });

  final String currentUserName;
  final ValueChanged<String> onSignInCompleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.lightGrey),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.darkGrey,
                      child: Icon(
                        Icons.person_outline,
                        color: AppTheme.pureWhite,
                        size: 28,
                      ),
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
                            currentUserName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '個人データは原則非公開・グループ単位で安全に共有されます',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '認証プロバイダ連携（Firebase Auth 接続枠）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGrey,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  onSignInCompleted('Google User (demo@example.com)');
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.login, size: 20),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Googleアカウントでログイン / 切替'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  onSignInCompleted('Guest Explorer');
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.person_pin_outlined, size: 20),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('デモユーザー（Guest Explorer）に切替'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
