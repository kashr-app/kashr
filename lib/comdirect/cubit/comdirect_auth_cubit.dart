import 'dart:convert';

import 'package:finanalyzer/comdirect/auth_interceptor.dart';
import 'package:finanalyzer/comdirect/comdirect_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:meta/meta.dart';
import 'package:finanalyzer/comdirect/comdirect_auth_api.dart';
import 'package:finanalyzer/comdirect/comdirect_model.dart';
import 'package:uuid/v4.dart';

part 'comdirect_auth_state.dart';

final requestIdFormat = DateFormat("HHmmssSSS");

class ComdirectAuthCubit extends Cubit<ComdirectAuthState> {
  final log = Logger();

  ComdirectAuthCubit() : super(AuthInitial());

  Future<void> login(Credentials credentials) async {
    try {
      final dio = Dio();

      final comdirectAuthAPI = ComdirectAuthAPI(dio);
      final authTokenResponse = await comdirectAuthAPI.createLoginAuthToken(
        CreateLoginAuthTokenReqDTO(
          clientId: credentials.clientId,
          clientSecret: credentials.clientSecret,
          grantType: 'password',
          username: credentials.username,
          password: credentials.password,
        ),
      );
      emit(AuthLoading("Creating session..."));

      final requestId = requestIdFormat.format(DateTime.now());
      final sessionId = const UuidV4()
          .generate()
          .replaceAll("-", "")
          .substring(0, 32);
      final clientRequestInfo = ClientRequestInfoDTO(
        clientRequestId: ClientRequestId(
          sessionId: sessionId,
          requestId: requestId,
        ),
      );

      final loginAuthHeader = "Bearer ${authTokenResponse.accessToken}";
      final clientRequestInfoHeader = jsonEncode(clientRequestInfo);
      log.i(clientRequestInfoHeader);
      dio.options.headers.clear();
      dio.options.headers["Content-Type"] = "application/json";
      dio.options.headers["Accept"] = "application/json";
      dio.options.headers["Authorization"] = loginAuthHeader;
      dio.options.headers["x-http-request-info"] = clientRequestInfoHeader;

      final session = (await comdirectAuthAPI.getSessionStatus()).firstOrNull;
      if (session == null) {
        log.e("No session found");
        emit(AuthError("No session found"));
        return;
      }
      log.i("Session created");

      emit(AuthLoading("Validating session..."));
      final sessionValidateResponse = await comdirectAuthAPI.postSessionValidate(
        // note that we do not use the sessionId that we generated but the identifier created by comdirect
        sessionId: session.identifier,
        session: session.copyWith(sessionTanActive: true, activated2FA: true),
      );

      final tanChallengeStr = sessionValidateResponse.response.headers.value(
        "x-once-authentication-info",
      );
      if (tanChallengeStr == null) {
        emit(AuthError("No tan challenge found"));
        return;
      }
      final tanChallenge = TanChallenge.fromJson(jsonDecode(tanChallengeStr));
      if (tanChallenge.typ != "P_TAN_PUSH" || tanChallenge.link == null) {
        const msg =
            "ERROR: tan challenge type is not supported. Only Push Tan is supported.";
        log.e("tanChallenge.typ: ${tanChallenge.typ}");
        log.e("tanChallenge.link: ${tanChallenge.link}");
        emit(AuthError(msg));
        return;
      }

      emit(WaitingForTANConfirmation());

      final href = tanChallenge.link!.href;
      final authId = href.substring(href.lastIndexOf("/"), href.length);
      var tanErrorMsg = await _waitForTAN(authId, comdirectAuthAPI);
      if (tanErrorMsg != null) {
        emit(AuthError(tanErrorMsg));
        return;
      }

      log.i("Tan confirmed. Activating session-tan...");
      emit(AuthLoading("Tan confirmed. Activating session-tan..."));
      await comdirectAuthAPI.activateSession(
        tanChallengeIdWrapper: jsonEncode(
          TanChallengeIdWrapper(id: tanChallenge.id),
        ),
        sessionId: session.identifier,
        session: session,
      );

      log.i("2FA successfull");
      emit(AuthLoading("2FA successfull. Getting api token..."));
      dio.options.headers.clear();
      final tokenCreatedAt = DateTime.now().millisecondsSinceEpoch;
      final apiToken = await comdirectAuthAPI.createApiToken(
        ApiAccessTokenReqDTO(
          clientId: credentials.clientId,
          clientSecret: credentials.clientSecret,
          grantType: 'cd_secondary',
          token: authTokenResponse.accessToken,
        ),
      );
      await apiToken.store(tokenCreatedAt);

      final dioApi = Dio();
      dioApi.options.headers.clear();
      dioApi.options.headers["Content-Type"] = "application/json";
      dioApi.options.headers["Accept"] = "application/json";
      dioApi.options.headers["Authorization"] =
          "Bearer ${apiToken.accessToken}";
      dioApi.options.headers["x-http-request-info"] = clientRequestInfoHeader;

      dioApi.interceptors.add(AuthInterceptor(this));

      final api = ComdirectAPI(dioApi);

      emit(AuthSuccess(apiToken, api, dioApi));
    } catch (e, s) {
      log.e('Faild to authenticate', error: e, stackTrace: s);
      emit(AuthError('Failed to authenticate: $e'));
    }
  }

  Future<void> refreshToken() async {
    try {
      final s = state;
      if (s is! AuthSuccess) {
        log.e('Cannot refresh token: not authenticated');
        emit(AuthError('Cannot refresh token: not authenticated'));
        return;
      }

      final currentToken = await TokenDTO.load();
      if (currentToken == null) {
        log.e('No valid token found to refresh');
        emit(AuthError('No valid token found to refresh'));
        return;
      }

      final credentials = await Credentials.load();
      if (credentials == null) {
        log.e('No credentials found');
        emit(AuthError('No credentials found'));
        return;
      }

      emit(AuthLoading("Refreshing token..."));

      final dio = Dio();
      final comdirectAuthAPI = ComdirectAuthAPI(dio);

      final tokenCreatedAt = DateTime.now().millisecondsSinceEpoch;
      final newToken = await comdirectAuthAPI.refreshToken(
        RefreshTokenReqDTO(
          clientId: credentials.clientId,
          clientSecret: credentials.clientSecret,
          grantType: 'refresh_token',
          refreshToken: currentToken.refreshToken,
        ),
      );
      await newToken.store(tokenCreatedAt);

      s.dioClient.options.headers["Authorization"] =
          "Bearer ${newToken.accessToken}";

      emit(AuthSuccess(newToken, s.api, s.dioClient));
      log.i('Token refreshed successfully');
    } catch (e, s) {
      log.e('Failed to refresh token', error: e, stackTrace: s);
      emit(AuthError('Failed to refresh token: $e'));
    }
  }

  /// Logs out the user by clearing the authentication state and invalidating
  /// the access token. Stored credentials are preserved for future logins.
  Future<void> logout() async {
    final s = state;
    if (s is AuthSuccess) {
      final accessToken = s.apiToken.accessToken;
      final dio = Dio();
      dio.options.headers.clear();
      dio.options.headers["Content-Type"] = "application/json";
      dio.options.headers["Accept"] = "application/json";
      dio.options.headers["Authorization"] = "Bearer $accessToken";
      final authApi = ComdirectAuthAPI(dio);
      try {
        final response = await authApi.revokeToken();
        if (response.response.statusCode == 204) {
          log.i('Access token successfully revoked');
        } else {
          log.w('Unexpected status code: ${response.response.statusCode}');
        }
      } on DioException catch (e, s) {
        log.e('Failed to revoke token', error: e, stackTrace: s);
      }
    } else {
      log.w(
        'AuthState is not AuthSuccess during logout, so there is not access token to invalidate.',
      );
    }
    await TokenDTO.delete();
    emit(AuthInitial());
    log.i('Logged out');
  }

  /// Returns null if the user successfully confirmed the tan or the error string (e.g. timeout);
  Future<String?> _waitForTAN(
    String authId,
    ComdirectAuthAPI comdirectAuthAPI,
  ) async {
    final startWaitingAt = DateTime.now().millisecondsSinceEpoch;
    const timeoutMillis =
        599000; // 599s because the expiration of the access token is 599s
    int consecutiveErrors = 0;
    const maxConsecutiveErrors = 5;

    while (DateTime.now().millisecondsSinceEpoch <
        startWaitingAt + timeoutMillis) {
      try {
        final authStatus = await comdirectAuthAPI.getAuthStatus(authId);
        consecutiveErrors = 0; // Reset error counter on successful request

        switch (authStatus.status) {
          case 'AUTHENTICATED':
            return null;
          case 'PENDING':
            // Sleep for 1s initially, then 3s after 8s
            final waitingTime =
                DateTime.now().millisecondsSinceEpoch - startWaitingAt;
            final sleepTime = waitingTime < 8000 ? 1000 : 3000;
            await Future.delayed(Duration(milliseconds: sleepTime));
          default:
            return 'Invalid authentication status: ${authStatus.status}';
        }
      } catch (e) {
        consecutiveErrors++;
        log.w(
          'Error polling TAN status (attempt $consecutiveErrors/$maxConsecutiveErrors): $e',
        );

        if (consecutiveErrors >= maxConsecutiveErrors) {
          final msg =
              'Failed to poll TAN status after $maxConsecutiveErrors attempts: $e';
          log.e(msg, error: e);
          return msg;
        }

        // Wait before retrying (exponential backoff)
        final retryDelay = Duration(milliseconds: 1000 * consecutiveErrors);
        await Future.delayed(retryDelay);
      }
    }
    log.w("TAN confirmation timed out");
    return 'TAN confirmation timed out';
  }
}
