import 'package:flutter_test/flutter_test.dart';
import 'package:oauth2_client/authorization_response.dart';

void main() {

  final String authCode = 'test_code';
  final String state = 'test_state';

  group('Authorization Response.', () {

    test('Valid response', () {

      final String url = 'myurlscheme:/oauth2?code=' + authCode + '&state=' + state;
      final AuthorizationResponse resp = AuthorizationResponse.fromRedirectUri(url, state);

      expect(resp.code, authCode);
      expect(resp.state, state);
      expect(resp.isAccessGranted(), true);

    });

    test('Error response', () {

      final String url = 'myurlscheme:/oauth2?error=ERR';
      final AuthorizationResponse resp = AuthorizationResponse.fromRedirectUri(url, state);

      expect(resp.error, 'ERR');
      expect(resp.isAccessGranted(), false);

    });

    test('Bad response (no code param)', () {

      final String url = 'myurlscheme:/oauth2?state=' + state;

      expect(() => AuthorizationResponse.fromRedirectUri(url, state), throwsException);

    });

    test('Bad response (no state param)', () {

      final String url = 'myurlscheme:/oauth2?code=' + authCode;

      expect(() => AuthorizationResponse.fromRedirectUri(url, state), throwsException);

    });

    test('Bad response (wrong state param)', () {

      final String url = 'myurlscheme:/oauth2?code=' + authCode + '&state=WRONGSTATE';

      expect(() => AuthorizationResponse.fromRedirectUri(url, state), throwsException);

    });

  });

}