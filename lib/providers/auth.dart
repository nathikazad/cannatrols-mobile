// auth.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';

final supabaseProvider = Provider((ref) => Supabase.instance.client);

final authProvider = ChangeNotifierProvider((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AuthNotifier(supabase);
});

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends ChangeNotifier {
  final SupabaseClient _supabase;
  AuthState _state;

  AuthNotifier(this._supabase) : _state = AuthState() {
    checkAuthStatus();
  }

  AuthState get state => _state;

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      final user = response.user;
      if (user == null) throw 'No user returned from Supabase';
      
      _setState(_state.copyWith(user: user, isLoading: false));
    } catch (e) {
      _setState(_state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> signUp(String email, String password) async {
    _state = _state.copyWith(isLoading: true, error: null);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      final user = response.user;
      if (user == null) throw 'No user returned from Supabase';
      
      _state = _state.copyWith(user: user, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  String _generateRandomString() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signInWithApple(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      // Generate secure nonce for Apple Sign In
      final rawNonce = _generateRandomString();
      final nonce = _sha256ofString(rawNonce);
      
      // Request credential for Apple Sign In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw 'No identity token returned from Apple';
      }
      
      // Create sign in data for Supabase
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      
      final user = response.user;
      if (user == null) {
        throw 'No user returned from Supabase';
      }
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      _setState(_state.copyWith(user: user, isLoading: false));
    } catch (error) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      _setState(_state.copyWith(error: error.toString(), isLoading: false));
    }
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      // Initialize Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        throw 'Google Sign In was canceled';
      }
      
      // Get auth details from request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      
      if (accessToken == null || idToken == null) {
        throw 'Could not get auth tokens from Google Sign In';
      }
      
      // Sign in with Supabase using the Google token
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      
      final user = response.user;
      if (user == null) {
        throw 'No user returned from Supabase';
      }
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      _setState(_state.copyWith(user: user, isLoading: false));
    } catch (error) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      _setState(_state.copyWith(error: error.toString(), isLoading: false));
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _setState(AuthState());  // Use _setState instead of direct assignment
  }

  Future<void> checkAuthStatus() async {
    _state = _state.copyWith(isLoading: true);
    try {
      final currentUser = _supabase.auth.currentUser;
      _state = _state.copyWith(user: currentUser, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}