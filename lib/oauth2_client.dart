import 'package:http/http.dart' as http;
import 'package:oauth2_client/access_token_response.dart';
import 'package:oauth2_client/authorization_response.dart';
import 'package:meta/meta.dart';
import 'package:oauth2_client/src/oauth2_utils.dart';
import 'package:oauth2_client/src/web_auth.dart';
import 'package:random_string/random_string.dart';

/// Base class that implements OAuth2 authorization flows.
///
/// It currently supports the following grants:
/// * Authorization Code
/// * Client Credentials
///
/// For the Authorization Code grant, PKCE is used by default. If you need to disable it, pass the 'enablePKCE' param to false.
///
/// You can use directly this class, but normally you want to extend it and implement your own client.
/// When instantiating the client, pass your custom uri scheme in the [customUriScheme] field.
/// Normally you would use something like <customUriScheme>:/oauth for the [redirectUri] field.
/// For Android only you must add an intent filter in your AndroidManifest.xml file to enable the custom uri handling.
/// <activity android:name="com.linusu.flutter_web_auth.CallbackActivity" >
///   <intent-filter android:label="flutter_web_auth">
///     <action android:name="android.intent.action.VIEW" />
///     <category android:name="android.intent.category.DEFAULT" />
///     <category android:name="android.intent.category.BROWSABLE" />
///     <data android:scheme="com.teranet.app" />
///   </intent-filter>
/// </activity>
class OAuth2Client {
  String redirectUri;
  String customUriScheme;

  String tokenUrl;
  String refreshUrl;
  String authorizeUrl;
  Map<String, String> _accessTokenRequestHeaders;

  WebAuth webAuthClient;

  OAuth2Client(
      {@required this.authorizeUrl,
      @required this.tokenUrl,
      this.refreshUrl,
      @required this.redirectUri,
      @required this.customUriScheme}) {
    webAuthClient = WebAuth();
  }

  /// Requests an Access Token to the OAuth2 endpoint using the Authorization Code Flow.
  Future<AccessTokenResponse> getTokenWithAuthCodeFlow({
    @required String clientId,
    @required List<String> scopes,
    String clientSecret,
    bool enablePKCE = true,
    String state,
    String codeVerifier,
    httpClient,
    webAuthClient,
  }) async {
    AccessTokenResponse tknResp;

    String codeChallenge;

    if (enablePKCE) {
      if (codeVerifier == null) codeVerifier = randomAlphaNumeric(80);

      codeChallenge = OAuth2Utils.generateCodeChallenge(codeVerifier);
    }

    AuthorizationResponse authResp = await requestAuthorization(
        webAuthClient: webAuthClient,
        clientId: clientId,
        scopes: scopes,
        codeChallenge: codeChallenge,
        state: state);

    if (authResp.isAccessGranted()) {
      tknResp = await requestAccessToken(
          httpClient: httpClient,
          code: authResp.code,
          clientId: clientId,
          clientSecret: clientSecret,
          codeVerifier: codeVerifier);
    }

    return tknResp;
  }

  /// Requests an Access Token to the OAuth2 endpoint using the Client Credentials flow.
  Future<AccessTokenResponse> getTokenWithClientCredentialsFlow({
    @required String clientId,
    @required String clientSecret,
    List<String> scopes,
    httpClient,
    realm,
    resource
  }) async {
    if (httpClient == null) httpClient = http.Client();

    Map<String, String> params = {
      'grant_type': 'client_credentials',
      'client_id': clientId,
      'client_secret': clientSecret,
      'realm': realm,
      'resource': resource
    };

    if (scopes != null) params['scope'] = scopes.join('+');

    http.Response response = await httpClient.post(tokenUrl, body: params);

    return AccessTokenResponse.fromHttpResponse(response);
  }

  /// Requests an Authorization Code to be used in the Authorization Code grant.
  Future<AuthorizationResponse> requestAuthorization({
    @required String clientId,
    List<String> scopes,
    String codeChallenge,
    String state,
    webAuthClient,
  }) async {
    if (webAuthClient == null) webAuthClient = this.webAuthClient;

    if (state == null) state = randomAlphaNumeric(25);

    final String authorizeUrl = getAuthorizeUrl(
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: scopes,
        state: state,
        codeChallenge: codeChallenge);

    // Present the dialog to the user
    final result = await webAuthClient.authenticate(
        url: authorizeUrl, callbackUrlScheme: customUriScheme);

    return AuthorizationResponse.fromRedirectUri(result, state);
  }

  /// Requests and Access Token using the provided Authorization [code].
  Future<AccessTokenResponse> requestAccessToken(
      {@required String code,
      @required String clientId,
      String clientSecret,
      String codeVerifier,
      httpClient}) async {
    if (httpClient == null) httpClient = http.Client();

    final Map body = getTokenUrlParams(
        code: code,
        redirectUri: redirectUri,
        clientId: clientId,
        clientSecret: clientSecret,
        codeVerifier: codeVerifier);

    http.Response response = await httpClient.post(tokenUrl,
        body: body, headers: _accessTokenRequestHeaders);
    return AccessTokenResponse.fromHttpResponse(response);
  }

  /// Refreshes an Access Token issuing a refresh_token grant to the OAuth2 server.
  Future<AccessTokenResponse> refreshToken(String refreshToken,
      {httpClient}) async {
    if (httpClient == null) httpClient = http.Client();

    http.Response response = await httpClient.post(_getRefreshUrl(),
        body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken});

    return AccessTokenResponse.fromHttpResponse(response);
  }

  /// Generates the url to be used for fetching the authorization code.
  String getAuthorizeUrl(
      {@required String clientId,
      String redirectUri,
      List<String> scopes,
      String state,
      String codeChallenge}) {
    final Map<String, String> params = {
      'response_type': 'code',
      'client_id': clientId
    };

    if (redirectUri != null && redirectUri.isNotEmpty)
      params['redirect_uri'] = redirectUri;

    if (scopes != null && scopes.isNotEmpty) params['scope'] = scopes.join('+');

    if (state != null && state.isNotEmpty) params['state'] = state;

    if (codeChallenge != null && codeChallenge.isNotEmpty) {
      params['code_challenge'] = codeChallenge;
      params['code_challenge_method'] = 'S256';
    }

    return OAuth2Utils.addParamsToUrl(authorizeUrl, params);
  }

  String _getRefreshUrl() {
    return refreshUrl ?? tokenUrl;
  }

  /// Returns the parameters needed for the authorization code request
  Map<String, String> getTokenUrlParams(
      {@required String code,
      String redirectUri,
      String clientId,
      String clientSecret,
      String codeVerifier}) {
    Map<String, String> params = {
      'grant_type': 'authorization_code',
      'code': code
    };

    if (redirectUri != null && redirectUri.isNotEmpty)
      params['redirect_uri'] = redirectUri;

    if (clientId != null && clientId.isNotEmpty) params['client_id'] = clientId;

    if (clientSecret != null && clientSecret.isNotEmpty)
      params['client_secret'] = clientSecret;

    if (codeVerifier != null && codeVerifier.isNotEmpty)
      params['code_verifier'] = codeVerifier;

    return params;
  }

  set accessTokenRequestHeaders(Map<String, String> headers) {
    _accessTokenRequestHeaders = headers;
  }
}
