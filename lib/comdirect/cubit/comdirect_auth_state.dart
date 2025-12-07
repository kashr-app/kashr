part of 'comdirect_auth_cubit.dart';

@immutable
sealed class ComdirectAuthState {}

class AuthInitial extends ComdirectAuthState {}

class AuthLoading extends ComdirectAuthState {
  final String? message;
  AuthLoading([this.message]);
}

class WaitingForTANConfirmation extends ComdirectAuthState {}

class AuthError extends ComdirectAuthState {
  final String message;
  AuthError(this.message);
}

class AuthSuccess extends ComdirectAuthState {
  final TokenDTO apiToken;
  final ComdirectAPI api;
  final Dio dioClient;
  AuthSuccess(this.apiToken, this.api, this.dioClient);
}
