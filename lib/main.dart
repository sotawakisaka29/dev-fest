import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
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
      title: '自分だけのGoogle Map',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MapScreen(),
    );
  }
}
