import 'package:flutter_test/flutter_test.dart';
import 'package:oauth2_client/access_token_response.dart';

void main() {
  final String accessToken = 'test_access_token';
  final String refreshToken = 'test_refresh_token';
  final List<String> scopes = ['scope1', 'scope2'];
  final int expiresIn = 3600;
  final String tokenType = 'Bearer';

  group('Access Token Response.', () {

    test('Valid response', () async {

      final Map<String, dynamic> respMap = {
        'access_token': accessToken,
        'token_type': tokenType,
        'refresh_token': refreshToken,
        'scope': scopes,
        'expires_in': expiresIn
      };

      final resp = AccessTokenResponse.fromMap(respMap);

      expect(resp.accessToken, accessToken);
      expect(resp.refreshToken, refreshToken);
      expect(resp.expiresIn, expiresIn);
      expect(resp.isValid(), false);
      expect(resp.isExpired(), false);
      expect(resp.isBearer(), true);

    });

   test('Token expiration', () async {

      final Map<String, dynamic> respMap = {
        'access_token': accessToken,
        'token_type': tokenType,
        'refresh_token': refreshToken,
        'scope': scopes,
        'expires_in': 1
      };

      final resp = AccessTokenResponse.fromMap(respMap);

      await Future.delayed(const Duration(seconds: 2), () => "X");

      expect(resp.isExpired(), true);
      expect(resp.refreshNeeded(), true);
    });

    test('Error response', () async {

      final Map<String, dynamic> respMap = {
        'error': 'ERROR',
        'error_description': 'ERROR_DESC',
      };

      final resp = AccessTokenResponse.fromMap(respMap);

      expect(resp.isValid(), false);
    });

    test('Convert to map', () async {

      final Map<String, dynamic> respMap = {
        'access_token': accessToken,
        'token_type': tokenType,
        'refresh_token': refreshToken,
        'scope': scopes,
        'expires_in': expiresIn
      };

      DateTime now = DateTime.now();
      DateTime expirationDate = now.add(Duration(seconds: expiresIn));

      final resp = AccessTokenResponse.fromMap(respMap);

      expect(resp.toMap(), allOf(
        containsPair('access_token', accessToken),
        containsPair('token_type', tokenType),
        containsPair('refresh_token', refreshToken),
        containsPair('scope', scopes),
        containsPair('expiration_date', expirationDate.millisecondsSinceEpoch)
      ));

    });

  });

}