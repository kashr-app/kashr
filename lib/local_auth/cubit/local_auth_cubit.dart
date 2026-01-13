import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kashr/local_auth/auth_delay.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logger/logger.dart';
import 'package:meta/meta.dart';

part 'local_auth_state.dart';

class LocalAuthCubit extends Cubit<LocalAuthState> {
  final Logger log;
  final GoRouter router;
  final SettingsCubit settingsCubit;
  LocalAuthCubit(this.log, this.router, this.settingsCubit)
    : super(LocalAuthInitial());

  final LocalAuthentication auth = LocalAuthentication();
  DateTime? _hiddenAt;
  String? _savedLocation;

  Future<void> authenticate() async {
    emit(LocalAuthLoading());
    try {
      final isAuthenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to proceed',
      );
      if (isAuthenticated) {
        emit(LocalAuthSuccess());
        return;
      } else {
        emit(LocalAuthError("Authentcation failed. Please try again"));
      }
    } on LocalAuthException catch (e, s) {
      log.d("LocalAuthException", error: e, stackTrace: s);
      emit(LocalAuthError(e.code.name, code: e.code));
    } catch (e) {
      log.e("LocalAuthError", error: e);
      emit(LocalAuthError("ERROR: $e"));
    }
  }

  void logout() {
    final currentLocation = router.routerDelegate.currentConfiguration.uri
        .toString();
    log.i("logout, saving location: $currentLocation");
    _savedLocation = currentLocation;
    emit(LocalAuthLoggedOut());
  }

  void onAppHidden() {
    log.d("App hidden at ${DateTime.now()}");
    _hiddenAt = DateTime.now();
  }

  void onAppShow() {
    final authDelay = settingsCubit.state.authDelay;
    if (_isAuthTimeout(authDelay)) {
      log.d("Local authenticaation timeout, logging out.");
      logout();
    }
  }

  bool _isAuthTimeout(AuthDelayOption authDelay) {
    if (authDelay == AuthDelayOption.disabled) {
      return false;
    }

    if (_hiddenAt == null) {
      return false;
    }

    final duration = authDelay.duration;
    if (duration == null) {
      return false;
    }

    final elapsed = DateTime.now().difference(_hiddenAt!);
    final shouldAuth = elapsed >= duration;
    log.d(
      "Auth check: elapsed=${elapsed.inSeconds}s, "
      "threshold=${duration.inSeconds}s, shouldAuth=$shouldAuth",
    );
    return shouldAuth;
  }

  String? popSavedLocation() {
    final location = _savedLocation;
    _savedLocation = null;
    log.d("Popping saved location: $location");
    return location;
  }

  /// Saves a location to return to after authentication.
  ///
  /// Used when a user deep links to a protected route while unauthenticated.
  void saveLocationForLater(String location) {
    log.d("Saving location for later: $location");
    _savedLocation = location;
  }
}
