import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 追加権限（スコープ）要求の結果区分
enum ScopeRequestResult { granted, cancelled, denied, failed }

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

  /// Google Photos Picker API 用の最小権限スコープ
  static const String photoPickerScope =
      'https://www.googleapis.com/auth/photospicker.mediaitems.readonly';

  // 6系iOSプラグインのスコープ合算バグ (flutter/flutter#157639) を防ぐため、
  // デフォルトで暗黙的に要求される email / profile は明示指定せず、空のスコープで初期化する
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// ログイン中のGoogleSignInAccountを取得（Google Photos APIリクエスト等で使用）
  GoogleSignInAccount? get currentGoogleUser => _googleSignIn.currentUser;

  /// Photo Picker スコープの追加認可を要求する（段階的認可・詳細結果返却）
  Future<ScopeRequestResult> requestPhotoPickerScopeDetailed() async {
    try {
      final user = _googleSignIn.currentUser;
      if (user == null) {
        return ScopeRequestResult.failed;
      }

      final bool granted = await _googleSignIn.requestScopes([
        photoPickerScope,
      ]);
      if (granted) {
        return ScopeRequestResult.granted;
      }

      // iOSプラグインの既知の不具合 (flutter/flutter#157639) に対するフォールバック:
      // プラグインが false を返した場合でも、アクセストークンを直接検証してスコープが付与されているか確認
      final token = await getGoogleAccessToken();
      if (token != null &&
          await verifyAccessTokenHasScope(token, photoPickerScope)) {
        return ScopeRequestResult.granted;
      }

      return ScopeRequestResult.denied;
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' ||
          e.code == '-5' ||
          e.message?.toLowerCase().contains('cancel') == true) {
        return ScopeRequestResult.cancelled;
      }
      debugPrint('Photo Picker scope request platform error: ${e.code}');
      return ScopeRequestResult.failed;
    } catch (e) {
      debugPrint('Photo Picker scope request failed: $e');
      return ScopeRequestResult.failed;
    }
  }

  /// Photo Picker スコープの追加認可を要求する（段階的認可・既存互換）
  Future<bool> requestPhotoPickerScope() async {
    final result = await requestPhotoPickerScopeDetailed();
    return result == ScopeRequestResult.granted;
  }

  /// アクセストークンが対象スコープを保持しているかGoogle tokeninfo APIで確認する（秘密情報はログに出力しない）
  Future<bool> verifyAccessTokenHasScope(
    String accessToken,
    String scope,
  ) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('https://oauth2.googleapis.com/tokeninfo');
      final request = await client.postUrl(uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );
      request.write('access_token=${Uri.encodeQueryComponent(accessToken)}');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        return parseScopesFromTokenInfo(body).contains(scope);
      }
      return false;
    } catch (e) {
      debugPrint('Token scope verification network error');
      return false;
    } finally {
      client.close();
    }
  }

  /// tokeninfo レスポンス文字列から付与スコープ一覧を抽出（テスト可能）
  static Set<String> parseScopesFromTokenInfo(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final scopeStr = json['scope'] as String?;
      if (scopeStr != null && scopeStr.isNotEmpty) {
        return scopeStr.split(' ').toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  /// 現在のGoogle認証アクセストークンを取得する（秘密情報はログに出力しない）
  Future<String?> getGoogleAccessToken() async {
    final user = _googleSignIn.currentUser;
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.accessToken;
  }

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
