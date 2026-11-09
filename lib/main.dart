import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/map/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase の初期化（最大3秒のタイムアウトを設定し、ネイティブ未準備時の起動フリーズを防止）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint(
          'Firebase initialization timed out. Starting app with local fallback.',
        );
        return Firebase.app(); // タイムアウト時は既存インスタンスまたは例外へ
      },
    );
    debugPrint('Firebase initialized successfully.');
  } catch (e) {
    debugPrint('Firebase initialization skipped, timed out, or not ready: $e');
  }

  runApp(const MyMapApp());
}

class MyMapApp extends StatelessWidget {
  const MyMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Map',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _RootAuthGate(),
    );
  }
}

/// 初回起動時にログイン画面を表示し、Googleログインまたは「ゲストとして参加」後にマップ画面へ遷移するゲート
class _RootAuthGate extends StatefulWidget {
  const _RootAuthGate();

  @override
  State<_RootAuthGate> createState() => _RootAuthGateState();
}

class _RootAuthGateState extends State<_RootAuthGate> {
  final AuthService _authService = AuthService.instance;
  StreamSubscription<AppUser>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.authStateChanges.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.hasActiveSession) {
      return LoginScreen(
        isInitialGate: true,
        currentUserName: _authService.currentUser.displayName,
        onSignInCompleted: (_) {
          if (mounted) setState(() {});
        },
        onGuestSelected: () {
          if (mounted) setState(() {});
        },
      );
    }

    return const MapScreen();
  }
}
