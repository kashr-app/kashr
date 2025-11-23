import 'package:dio/dio.dart';
import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:logger/logger.dart';

/// Dio interceptor that handles authentication errors by automatically
/// logging out the user when a 401 (Unauthorized) response is received.
///
/// This ensures that when the Comdirect API token expires, the user is
/// prompted to re-authenticate.
class AuthInterceptor extends Interceptor {
  final ComdirectAuthCubit authCubit;
  final log = Logger();

  AuthInterceptor(this.authCubit);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      log.w('401 Unauthorized - logging out user');
      authCubit.logout();
    }
    handler.next(err);
  }
}
