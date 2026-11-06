import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ユーザー認証状態の管理クラス
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.isAnonymous = false,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isAnonymous;

  static const AppUser demoUser = AppUser(
    uid: 'demo_user_123',
    displayName: 'DevFest ゲスト',
    email: 'guest@example.com',
    isAnonymous: true,
  );
}

/// Firebase Authentication & Googleサインインをカプセル化するサービス（MVP機能③）
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/photoslibrary',
      'https://www.googleapis.com/auth/photoslibrary.readonly',
    ],
  );

  /// ログイン中のGoogleSignInAccountを取得（Google Photos APIリクエスト等で使用）
  GoogleSignInAccount? get currentGoogleUser => _googleSignIn.currentUser;

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _auth {
    if (!isFirebaseInitialized) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// 現在のユーザー情報を取得
  AppUser get currentUser {
    final firebaseUser = _auth?.currentUser;
    if (firebaseUser != null) {
      return AppUser(
        uid: firebaseUser.uid,
        displayName:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'ユーザー',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        isAnonymous: firebaseUser.isAnonymous,
      );
    }
    return AppUser.demoUser;
  }

  /// ユーザー認証状態ストリーム
  Stream<AppUser> get authStateChanges {
    final auth = _auth;
    if (auth == null) {
      return Stream.value(currentUser);
    }
    return auth.authStateChanges().map((firebaseUser) {
      if (firebaseUser != null) {
        return AppUser(
          uid: firebaseUser.uid,
          displayName:
              firebaseUser.displayName ??
              firebaseUser.email?.split('@').first ??
              'ユーザー',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
          isAnonymous: firebaseUser.isAnonymous,
        );
      }
      return AppUser.demoUser;
    });
  }

  /// Googleアカウントによるサインイン
  Future<AppUser> signInWithGoogle() async {
    try {
      if (!isFirebaseInitialized) {
        debugPrint('Firebase is not initialized yet. Using demo fallback.');
        return const AppUser(
          uid: 'google_demo_uid_12345',
          displayName: 'Google Test User',
          email: 'google.test@example.com',
        );
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // ユーザーがログインフローをキャンセルした場合
        throw Exception('Googleログインがキャンセルされました。');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Firebaseログインに失敗しました。');
      }

      return AppUser(
        uid: user.uid,
        displayName:
            user.displayName ?? googleUser.displayName ?? 'Google User',
        email: user.email ?? googleUser.email,
        photoUrl: user.photoURL ?? googleUser.photoUrl,
      );
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    if (_auth != null) {
      await _auth!.signOut();
    }
  }
}
