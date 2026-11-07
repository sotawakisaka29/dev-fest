import 'package:flutter_test/flutter_test.dart';
import 'package:my_map_app/core/models/app_photo.dart';
import 'package:my_map_app/core/services/auth_service.dart';
import 'package:my_map_app/core/services/google_photos_service.dart';

void main() {
  group('PickerSession parsing test', () {
    test('PickerSession correctly parses pollingConfig and fields', () {
      final json = {
        'id': 'session_12345',
        'pickerUri': 'https://photos.google.com/picker/test_session',
        'mediaItemsSet': false,
        'pollingConfig': {'pollInterval': '10s', 'timeoutIn': '120s'},
      };

      final session = PickerSession.fromJson(json);

      expect(session.id, 'session_12345');
      expect(
        session.pickerUri,
        'https://photos.google.com/picker/test_session',
      );
      expect(session.mediaItemsSet, false);
      expect(session.pollIntervalSeconds, 10);
      expect(session.timeoutSeconds, 120);
    });

    test(
      'PickerSession falls back to default intervals if pollingConfig is null',
      () {
        final json = {
          'id': 'session_fallback',
          'pickerUri': 'https://photos.google.com/picker/fallback',
          'mediaItemsSet': true,
        };

        final session = PickerSession.fromJson(json);

        expect(session.id, 'session_fallback');
        expect(session.mediaItemsSet, true);
        expect(session.pollIntervalSeconds, 5);
        expect(session.timeoutSeconds, 300);
      },
    );
  });

  group('GooglePhotosPickerResult test', () {
    test('success result correctly holds photos', () {
      final photos = [
        const AppPhoto(
          id: 'photo_1',
          label: 'DSC_0001.JPG',
          url: 'https://lh3.googleusercontent.com/test=w600-h600',
          isFromGooglePhotos: true,
        ),
      ];

      final result = GooglePhotosPickerResult.success(photos);

      expect(result.isSuccess, true);
      expect(result.photos.length, 1);
      expect(result.photos.first.label, 'DSC_0001.JPG');
      expect(result.errorType, isNull);
    });

    test('failure result correctly holds errorType and message', () {
      const result = GooglePhotosPickerResult.failure(
        errorType: GooglePhotosErrorType.userCancelled,
        message: '写真選択がキャンセルされました。',
      );

      expect(result.isSuccess, false);
      expect(result.photos, isEmpty);
      expect(result.errorType, GooglePhotosErrorType.userCancelled);
      expect(result.message, '写真選択がキャンセルされました。');
    });
  });

  group('AppPhoto copyWith test', () {
    test('AppPhoto preserves fields and updates correctly', () {
      const original = AppPhoto(
        id: 'orig_id',
        label: 'orig_label',
        url: 'https://example.com/orig',
        localPath: '/tmp/orig.jpg',
        isFromGooglePhotos: false,
      );

      final updated = original.copyWith(
        label: 'updated_label',
        isFromGooglePhotos: true,
      );

      expect(updated.id, 'orig_id');
      expect(updated.label, 'updated_label');
      expect(updated.url, 'https://example.com/orig');
      expect(updated.localPath, '/tmp/orig.jpg');
      expect(updated.isFromGooglePhotos, true);
    });
  });

  group('AuthService parseScopesFromTokenInfo test', () {
    test('correctly parses scopes from valid tokeninfo response', () {
      const jsonResponse = '''
      {
        "issued_to": "test_client_id.apps.googleusercontent.com",
        "audience": "test_client_id.apps.googleusercontent.com",
        "user_id": "1234567890",
        "scope": "openid https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/photospicker.mediaitems.readonly https://www.googleapis.com/auth/userinfo.profile",
        "expires_in": 3599,
        "email": "user@example.com",
        "verified_email": true
      }
      ''';

      final scopes = AuthService.parseScopesFromTokenInfo(jsonResponse);

      expect(scopes.contains('openid'), isTrue);
      expect(
        scopes.contains('https://www.googleapis.com/auth/userinfo.email'),
        isTrue,
      );
      expect(scopes.contains(AuthService.photoPickerScope), isTrue);
      expect(scopes.contains('https://www.googleapis.com/auth/drive'), isFalse);
    });

    test('returns empty set if scope field is missing or empty', () {
      const jsonNoScope = '{"email": "user@example.com"}';
      expect(AuthService.parseScopesFromTokenInfo(jsonNoScope), isEmpty);

      const invalidJson = 'invalid_json_format';
      expect(AuthService.parseScopesFromTokenInfo(invalidJson), isEmpty);
    });
  });
}
