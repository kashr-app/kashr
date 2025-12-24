import 'package:dio/dio.dart';
import 'package:kashr/comdirect/comdirect_model.dart';
import 'package:kashr/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:logger/logger.dart';

/// Dio interceptor that handles token refresh and authentication errors.
///
/// - Proactively refreshes tokens (checked on each request)
/// - Logs out the user on 401 errors
class AuthInterceptor extends Interceptor {
  final ComdirectAuthCubit authCubit;
  final Logger log;
  bool _isRefreshing = false;

  AuthInterceptor(this.authCubit, this.log);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token check for auth endpoints
    if (options.path.contains('/oauth/')) {
      return handler.next(options);
    }

    // Proactive token refresh: check if token needs refresh before request
    final token = await TokenDTO.load();
    if (token != null && await token.needsRefresh() && !_isRefreshing) {
      _isRefreshing = true;
      log.i('Token needs refresh - refreshing proactively');
      try {
        await authCubit.refreshToken();
        // Update the Authorization header with the new token
        final newToken = await TokenDTO.load();
        if (newToken != null) {
          options.headers['Authorization'] = 'Bearer ${newToken.accessToken}';
        }
      } catch (e) {
        log.e('Failed to refresh token proactively', error: e);
      } finally {
        _isRefreshing = false;
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      log.w('401 Unauthorized - logging out user');
      authCubit.logout();
    }
    handler.next(err);
  }
}
