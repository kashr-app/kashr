import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logger/logger.dart';
import 'package:meta/meta.dart';

part 'local_auth_state.dart';

class LocalAuthCubit extends Cubit<LocalAuthState> {
  final Logger log;
  LocalAuthCubit(this.log) : super(LocalAuthInitial());

  final LocalAuthentication auth = LocalAuthentication();

  Future<void> authenticate() async {
    emit(LocalAuthLoading());
    try {
      final isAuthenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to proceed',
        biometricOnly: true,
      );
      if (isAuthenticated) {
        emit(LocalAuthSuccess());
        return;
      } else {
        emit(LocalAuthError("Authentcation failed. Please try again"));
      }
    } catch (e) {
      log.e("LocalAuthError", error: e);
      emit(LocalAuthError("ERROR: $e"));
    }
  }

  void logout() {
    log.i("logout");
    emit(LocalAuthLoggedOut());
  }

  void reset() {
    log.i("reset");
    emit(LocalAuthInitial());
  }
}
