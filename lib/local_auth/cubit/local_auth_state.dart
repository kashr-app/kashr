part of 'local_auth_cubit.dart';

@immutable
sealed class LocalAuthState {}

class LocalAuthInitial extends LocalAuthState {}

class LocalAuthLoading extends LocalAuthState {
  final String? message;
  LocalAuthLoading([this.message]);
}

class LocalAuthSuccess extends LocalAuthState {}

class LocalAuthLoggedOut extends LocalAuthState {}

class LocalAuthError extends LocalAuthState {
  final String message;
  final LocalAuthExceptionCode? code;
  LocalAuthError(this.message, {this.code});
}
