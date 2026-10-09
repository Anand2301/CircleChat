import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/signalr_service.dart';
import '../../core/storage/token_storage.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(isLoading: true)) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
      return;
    }

    try {
      final data = await ApiClient.get(ApiConstants.usersMe);
      final user = UserModel.fromJson(data);
      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
      try {
        await SignalRService.instance.connect();
      } catch (_) {}
    } catch (_) {
      await TokenStorage.clear();
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await ApiClient.post(
        ApiConstants.authLogin,
        body: {'email': email, 'password': password},
        requiresAuth: false,
      );

      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final user = UserModel.fromJson(data['user']);

      await TokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: user.id,
      );

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
      try {
        await SignalRService.instance.connect();
      } catch (_) {}
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to connect to server: ${e.toString()}');
      return false;
    }
  }

  Future<bool> register({
    required String invitationCode,
    required String fullName,
    required String displayName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await ApiClient.post(
        ApiConstants.authRegister,
        body: {
          'invitationCode': invitationCode,
          'fullName': fullName,
          'displayName': displayName,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
        },
        requiresAuth: false,
      );

      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final user = UserModel.fromJson(data['user']);

      await TokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: user.id,
      );

      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
      try {
        await SignalRService.instance.connect();
      } catch (_) {}
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to complete registration.');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await ApiClient.post(ApiConstants.authLogout, body: {'refreshToken': refreshToken});
      }
    } catch (_) {}

    await SignalRService.instance.disconnect();
    await TokenStorage.clear();
    state = AuthState(isAuthenticated: false);
  }

  void updateUserProfile(UserModel updatedUser) {
    state = state.copyWith(user: updatedUser);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
